/* =====================================================================
   02_gatilhos.sql : gatilhos (triggers) e asserções do eVoto
   O SQL Server não tem CREATE ASSERTION; as regras que envolvem várias
   linhas/tabelas são implementadas com gatilhos, e as de uma só linha com
   restrições CHECK (ver 01_schema.sql, ex.: CK_Eleitor_Nif, CK_Voto_Destino).

   G1  trg_RegistoVoto_Validar      eleição Em Curso, dentro do prazo, eleitor ativo
   G2  trg_RegistoVoto_Imutavel     registos de voto não podem ser alterados/apagados
   G3  trg_RegistoVoto_Auditoria    regista que alguém votou (sem o sentido do voto)
   G4  trg_Voto_Validar             voto só em eleição Em Curso e coerente com o escrutínio
   G5  trg_Voto_Imutavel            votos não podem ser alterados/apagados
   G6  trg_<Tabela>_Bloqueio        cargos, listas, candidatos e recenseamento só
                                    mudam com a eleição Agendada
   G7  trg_Candidato_Coerencia      lista/posição conforme o tipo de escrutínio
   G8  trg_Eleicao_Estado           transições de estado válidas e dados congelados
   G9  trg_Eleicao_Auditoria        auditoria de criação/alteração/eliminação
   G10 trg_Eleitor_Idade            eleitor com pelo menos 18 anos
   ===================================================================== */
USE eVoto;
GO

/* G1 -------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_RegistoVoto_Validar
ON dbo.RegistoVoto AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.Eleicao e ON e.nome = i.eleicao
               WHERE e.estado <> 'Em Curso' OR GETDATE() < e.data_inicio OR GETDATE() > e.data_fim)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50001, N'A eleição não está aberta para votação.', 1;
    END;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.Eleitor el ON el.nif = i.nif WHERE el.ativo = 0)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50002, N'Um eleitor inativo não pode votar.', 1;
    END;
END;
GO

/* G2 -------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_RegistoVoto_Imutavel
ON dbo.RegistoVoto INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50003, N'Os registos de voto são imutáveis: não podem ser alterados nem eliminados.', 1;
END;
GO

/* G3 -------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_RegistoVoto_Auditoria
ON dbo.RegistoVoto AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.Auditoria (autor, acao, entidade, detalhe)
    SELECT CONCAT(N'NIF:', i.nif), N'VOTAR', N'Eleicao',
           CONCAT(i.eleicao, N' (o sentido do voto não é guardado)')
    FROM inserted i;
END;
GO

/* G4 -------------------------------------------------------------------
   Um voto válido numa eleição por Lista tem de indicar uma lista; numa
   eleição Uninominal tem de indicar um candidato. */
CREATE OR ALTER TRIGGER dbo.trg_Voto_Validar
ON dbo.Voto AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.Eleicao e ON e.nome = i.eleicao WHERE e.estado <> 'Em Curso')
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50004, N'Só é possível inserir votos numa eleição em curso.', 1;
    END;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.Eleicao e ON e.nome = i.eleicao
               WHERE i.tipo_voto = 'Valido'
                 AND ((e.tipo_escrutinio = 'Lista'      AND i.sigla_lista   IS NULL)
                   OR (e.tipo_escrutinio = 'Uninominal' AND i.nif_candidato IS NULL)))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50005, N'O destino do voto não corresponde ao tipo de escrutínio da eleição.', 1;
    END;
END;
GO

/* G5 -------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_Voto_Imutavel
ON dbo.Voto INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50006, N'Os votos são imutáveis: não podem ser alterados nem eliminados.', 1;
END;
GO

/* G6 -------------------------------------------------------------------
   A estrutura da eleição só pode mudar enquanto estiver Agendada. */
CREATE OR ALTER TRIGGER dbo.trg_Cargo_Bloqueio
ON dbo.Cargo AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM (SELECT eleicao FROM inserted UNION SELECT eleicao FROM deleted) x
               JOIN dbo.Eleicao e ON e.nome = x.eleicao WHERE e.estado <> 'Agendada')
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50007, N'A estrutura da eleição (cargos, listas, candidatos, recenseamento) só pode ser alterada enquanto estiver Agendada.', 1;
    END;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_Lista_Bloqueio
ON dbo.Lista AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM (SELECT eleicao FROM inserted UNION SELECT eleicao FROM deleted) x
               JOIN dbo.Eleicao e ON e.nome = x.eleicao WHERE e.estado <> 'Agendada')
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50007, N'A estrutura da eleição (cargos, listas, candidatos, recenseamento) só pode ser alterada enquanto estiver Agendada.', 1;
    END;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_Candidato_Bloqueio
ON dbo.Candidato AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM (SELECT eleicao FROM inserted UNION SELECT eleicao FROM deleted) x
               JOIN dbo.Eleicao e ON e.nome = x.eleicao WHERE e.estado <> 'Agendada')
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50007, N'A estrutura da eleição (cargos, listas, candidatos, recenseamento) só pode ser alterada enquanto estiver Agendada.', 1;
    END;
END;
GO
CREATE OR ALTER TRIGGER dbo.trg_Recenseamento_Bloqueio
ON dbo.Recenseamento AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM (SELECT eleicao FROM inserted UNION SELECT eleicao FROM deleted) x
               JOIN dbo.Eleicao e ON e.nome = x.eleicao WHERE e.estado <> 'Agendada')
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50007, N'A estrutura da eleição (cargos, listas, candidatos, recenseamento) só pode ser alterada enquanto estiver Agendada.', 1;
    END;
END;
GO

/* G7 -------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_Candidato_Coerencia
ON dbo.Candidato AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.Eleicao e ON e.nome = i.eleicao
               WHERE (e.tipo_escrutinio = 'Lista'      AND i.sigla_lista IS NULL)
                  OR (e.tipo_escrutinio = 'Uninominal' AND i.sigla_lista IS NOT NULL))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50008, N'Numa eleição por Lista o candidato tem de pertencer a uma lista; numa uninominal não pode.', 1;
    END;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.Eleitor el ON el.nif = i.nif WHERE el.ativo = 0)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50009, N'Um eleitor inativo não pode ser candidato.', 1;
    END;
END;
GO

/* G8 -------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_Eleicao_Estado
ON dbo.Eleicao AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- transições permitidas: Agendada -> Em Curso -> Encerrada -> Apurada
    IF UPDATE(estado) AND EXISTS (
            SELECT 1 FROM inserted i JOIN deleted d ON d.nome = i.nome
            WHERE i.estado <> d.estado
              AND NOT ( (d.estado = 'Agendada' AND i.estado = 'Em Curso')
                     OR (d.estado = 'Em Curso' AND i.estado = 'Encerrada')
                     OR (d.estado = 'Encerrada' AND i.estado = 'Apurada') ))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50010, N'Transição de estado da eleição inválida.', 1;
    END;

    -- para iniciar são precisos: 1 cargo, 1 recenseado e pelo menos 2 opções de voto
    IF UPDATE(estado) AND EXISTS (
            SELECT 1 FROM inserted i JOIN deleted d ON d.nome = i.nome
            WHERE d.estado = 'Agendada' AND i.estado = 'Em Curso'
              AND ( NOT EXISTS (SELECT 1 FROM dbo.Cargo c WHERE c.eleicao = i.nome)
                 OR NOT EXISTS (SELECT 1 FROM dbo.Recenseamento r WHERE r.eleicao = i.nome)
                 OR (i.tipo_escrutinio = 'Lista'      AND (SELECT COUNT(*) FROM dbo.Lista l WHERE l.eleicao = i.nome) < 2)
                 OR (i.tipo_escrutinio = 'Uninominal' AND (SELECT COUNT(*) FROM dbo.Candidato k WHERE k.eleicao = i.nome) < 2) ))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50011, N'Para iniciar a eleição são precisos cargo, eleitores recenseados e pelo menos 2 listas/candidatos.', 1;
    END;

    -- dados estruturais congelados depois de a eleição arrancar
    IF EXISTS (
            SELECT 1 FROM inserted i JOIN deleted d ON d.nome = i.nome
            WHERE (d.estado <> 'Agendada' AND (i.data_inicio <> d.data_inicio OR i.tipo_escrutinio <> d.tipo_escrutinio))
               OR (d.estado IN ('Encerrada', 'Apurada') AND i.data_fim <> d.data_fim))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50012, N'Não é possível alterar o tipo ou as datas de uma eleição já iniciada/encerrada.', 1;
    END;
END;
GO

/* G9 -------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_Eleicao_Auditoria
ON dbo.Eleicao AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @autor NVARCHAR(40) = TRY_CAST(SESSION_CONTEXT(N'autor') AS NVARCHAR(40));

    INSERT dbo.Auditoria (autor, acao, entidade, detalhe)
    SELECT @autor, N'CRIAR_ELEICAO', N'Eleicao', CONCAT(N'Criada: ', i.nome)
    FROM inserted i WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.nome = i.nome)
    UNION ALL
    SELECT @autor, N'ATUALIZAR_ELEICAO', N'Eleicao',
           CASE WHEN i.estado <> d.estado
                THEN CONCAT(i.nome, N': ', d.estado, N' -> ', i.estado)
                ELSE CONCAT(i.nome, N': dados alterados') END
    FROM inserted i JOIN deleted d ON d.nome = i.nome
    UNION ALL
    SELECT @autor, N'ELIMINAR_ELEICAO', N'Eleicao', CONCAT(N'Eliminada: ', d.nome)
    FROM deleted d WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.nome = d.nome);
END;
GO

/* G10 ------------------------------------------------------------------*/
CREATE OR ALTER TRIGGER dbo.trg_Eleitor_Idade
ON dbo.Eleitor AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i WHERE DATEADD(YEAR, 18, i.data_nascimento) > CAST(GETDATE() AS DATE))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50013, N'O eleitor tem de ter pelo menos 18 anos.', 1;
    END;
END;
GO
