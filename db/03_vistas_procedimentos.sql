/* =====================================================================
   03_vistas_procedimentos.sql : vistas (alimentam os dashboards) e
   procedimentos armazenados (autenticação por NIF + código, votação,
   estados e apuramento)
   ===================================================================== */
USE eVoto;
GO

/* ---------------------------------------------------------------------
   VISTAS
   --------------------------------------------------------------------- */

-- Resultados por lista (eleições por Lista) com mandatos já apurados
CREATE OR ALTER VIEW dbo.vw_ResultadosLista AS
SELECT  l.eleicao, l.sigla, l.designacao,
        COUNT(v.id_voto) AS votos,
        CAST(100.0 * COUNT(v.id_voto)
             / NULLIF(SUM(COUNT(v.id_voto)) OVER (PARTITION BY l.eleicao), 0) AS DECIMAL(5,2)) AS percentagem,
        ISNULL(ra.num_mandatos, 0) AS mandatos
FROM dbo.Lista l
LEFT JOIN dbo.Voto v ON v.eleicao = l.eleicao AND v.sigla_lista = l.sigla AND v.tipo_voto = 'Valido'
LEFT JOIN dbo.ResultadoApuramento ra ON ra.eleicao = l.eleicao AND ra.sigla_lista = l.sigla
GROUP BY l.eleicao, l.sigla, l.designacao, ra.num_mandatos;
GO

-- Resultados por candidato e cargo (eleições Uninominais)
CREATE OR ALTER VIEW dbo.vw_ResultadosCandidato AS
SELECT  c.eleicao, c.cargo, c.nif, el.nome,
        COUNT(v.id_voto) AS votos,
        CAST(100.0 * COUNT(v.id_voto)
             / NULLIF(SUM(COUNT(v.id_voto)) OVER (PARTITION BY c.eleicao, c.cargo), 0) AS DECIMAL(5,2)) AS percentagem
FROM dbo.Candidato c
JOIN dbo.Eleicao e  ON e.nome = c.eleicao AND e.tipo_escrutinio = 'Uninominal'
JOIN dbo.Eleitor el ON el.nif = c.nif
LEFT JOIN dbo.Voto v ON v.eleicao = c.eleicao AND v.cargo = c.cargo
                    AND v.nif_candidato = c.nif AND v.tipo_voto = 'Valido'
GROUP BY c.eleicao, c.cargo, c.nif, el.nome;
GO

-- Participação e abstenção por eleição
CREATE OR ALTER VIEW dbo.vw_ParticipacaoEleicao AS
SELECT  t.eleicao, t.estado, t.tipo_escrutinio, t.inscritos, t.votantes,
        t.inscritos - t.votantes AS abstencao,
        CAST(100.0 * t.votantes / NULLIF(t.inscritos, 0) AS DECIMAL(5,2)) AS taxa_participacao,
        t.votos_brancos, t.votos_nulos
FROM (
    SELECT e.nome AS eleicao, e.estado, e.tipo_escrutinio,
           (SELECT COUNT(*) FROM dbo.Recenseamento r WHERE r.eleicao = e.nome) AS inscritos,
           (SELECT COUNT(*) FROM dbo.RegistoVoto  rv WHERE rv.eleicao = e.nome) AS votantes,
           (SELECT COUNT(*) FROM dbo.Voto v WHERE v.eleicao = e.nome AND v.tipo_voto = 'Branco') AS votos_brancos,
           (SELECT COUNT(*) FROM dbo.Voto v WHERE v.eleicao = e.nome AND v.tipo_voto = 'Nulo')   AS votos_nulos
    FROM dbo.Eleicao e
) t;
GO

-- Afluência às urnas online: votantes por dia e hora (só indica QUANDO se
-- votou, nunca em quem; a hora está no RegistoVoto, não no Voto)
CREATE OR ALTER VIEW dbo.vw_AfluenciaHoraria AS
SELECT  rv.eleicao,
        CAST(rv.data_hora AS DATE)  AS dia,
        DATEPART(HOUR, rv.data_hora) AS hora,
        COUNT(*) AS votantes
FROM dbo.RegistoVoto rv
GROUP BY rv.eleicao, CAST(rv.data_hora AS DATE), DATEPART(HOUR, rv.data_hora);
GO

-- Asserção de integridade: nº de votos = nº esperado
-- (1 por boletim; 1 por cargo nas uninominais)
CREATE OR ALTER VIEW dbo.vw_Integridade AS
SELECT  t.eleicao, t.estado, t.registos_voto, t.votos,
        CASE t.tipo WHEN 'Lista' THEN t.registos_voto ELSE t.registos_voto * t.cargos END AS votos_esperados
FROM (
    SELECT e.nome AS eleicao, e.estado, e.tipo_escrutinio AS tipo,
           (SELECT COUNT(*) FROM dbo.RegistoVoto rv WHERE rv.eleicao = e.nome) AS registos_voto,
           (SELECT COUNT(*) FROM dbo.Voto v WHERE v.eleicao = e.nome) AS votos,
           (SELECT COUNT(*) FROM dbo.Cargo c WHERE c.eleicao = e.nome) AS cargos
    FROM dbo.Eleicao e
) t;
GO

/* ---------------------------------------------------------------------
   AUTENTICAÇÃO DO ELEITOR: NIF + código de uso único
   O código é gerado pela própria base de dados (CRYPT_GEN_RANDOM) e
   devolvido à aplicação para ser apresentado no ecrã, sem serviços externos
   (SMS/email). Num sistema real, @devolver_codigo = 0 e um serviço de
   mensagens entregaria o código.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_GerarCodigoAcesso
    @nif NVARCHAR(9),
    @validade_min INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    IF dbo.fn_NifValido(@nif) = 0
    BEGIN
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa)
        VALUES (LEFT(ISNULL(@nif, N''), 20), 0, N'NIF com formato inválido', 'Codigo');
        THROW 50040, N'O NIF indicado não é válido.', 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Eleitor WHERE nif = @nif AND ativo = 1)
    BEGIN
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa)
        VALUES (@nif, 0, N'NIF inexistente ou eleitor inativo', 'Codigo');
        THROW 50041, N'Não foi encontrado um eleitor ativo com esse NIF.', 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Recenseamento WHERE nif = @nif)
    BEGIN
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa)
        VALUES (@nif, 0, N'Eleitor sem recenseamento', 'Codigo');
        THROW 50042, N'O eleitor não está recenseado em nenhuma eleição.', 1;
    END;

    IF (SELECT COUNT(*) FROM dbo.CodigoAcesso
        WHERE nif = @nif AND criado_em > DATEADD(MINUTE, -10, GETDATE())) >= 5
    BEGIN
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa)
        VALUES (@nif, 0, N'Limite de pedidos de código excedido', 'Codigo');
        THROW 50043, N'Excedeu o número de pedidos de código. Tente novamente dentro de alguns minutos.', 1;
    END;

    DECLARE @codigo CHAR(6) =
        RIGHT(CONCAT('000000', ABS(CAST(CAST(CRYPT_GEN_RANDOM(4) AS INT) AS BIGINT)) % 1000000), 6);
    DECLARE @salt BINARY(16) = CRYPT_GEN_RANDOM(16);
    DECLARE @expira DATETIME = DATEADD(MINUTE, @validade_min, GETDATE());

    BEGIN TRANSACTION;
        -- só o código mais recente é válido
        UPDATE dbo.CodigoAcesso SET estado = 'Anulado' WHERE nif = @nif AND estado = 'Pendente';
        INSERT dbo.CodigoAcesso (nif, salt, hash_codigo, expira_em)
        VALUES (@nif, @salt,
                HASHBYTES('SHA2_256', @salt + CAST(CONCAT(@nif, N':', @codigo) AS VARBINARY(100))),
                @expira);
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, etapa) VALUES (@nif, 1, 'Codigo');
    COMMIT TRANSACTION;

    SELECT @codigo AS codigo, @expira AS expira_em, @validade_min * 60 AS validade_segundos;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ValidarCodigoAcesso
    @nif NVARCHAR(9),
    @codigo NVARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @salt BINARY(16), @hash BINARY(32), @expira DATETIME, @tent TINYINT;

    SELECT TOP (1) @id = id_codigo, @salt = salt, @hash = hash_codigo, @expira = expira_em, @tent = tentativas
    FROM dbo.CodigoAcesso WHERE nif = @nif AND estado = 'Pendente'
    ORDER BY id_codigo DESC;

    IF @id IS NULL
    BEGIN
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa)
        VALUES (LEFT(ISNULL(@nif, N''), 20), 0, N'Sem código ativo', 'Validacao');
        THROW 50044, N'Não existe nenhum código ativo. Peça um novo código.', 1;
    END;

    IF GETDATE() > @expira
    BEGIN
        UPDATE dbo.CodigoAcesso SET estado = 'Expirado' WHERE id_codigo = @id;
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa)
        VALUES (@nif, 0, N'Código expirado', 'Validacao');
        THROW 50045, N'O código expirou. Peça um novo código.', 1;
    END;

    IF @hash <> HASHBYTES('SHA2_256', @salt + CAST(CONCAT(@nif, N':', @codigo) AS VARBINARY(100)))
    BEGIN
        SET @tent += 1;
        UPDATE dbo.CodigoAcesso SET tentativas = @tent,
               estado = CASE WHEN @tent >= 3 THEN 'Anulado' ELSE estado END
        WHERE id_codigo = @id;
        INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa)
        VALUES (@nif, 0, CONCAT(N'Código incorreto (tentativa ', @tent, N')'), 'Validacao');
        IF @tent >= 3 THROW 50046, N'Código incorreto. O código foi anulado; peça um novo código.', 1;
        DECLARE @msg NVARCHAR(200) = CONCAT(N'Código incorreto. Restam ', 3 - @tent, N' tentativa(s).');
        THROW 50047, @msg, 1;
    END;

    UPDATE dbo.CodigoAcesso SET estado = 'Usado' WHERE id_codigo = @id;
    INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, etapa) VALUES (@nif, 1, 'Validacao');

    SELECT nif, nome FROM dbo.Eleitor WHERE nif = @nif;
END;
GO

/* ---------------------------------------------------------------------
   VOTAÇÃO
   @escolhas é um JSON: [{"cargo":"...","tipo":"Valido|Branco|Nulo",
                          "sigla":"PH","nif":"123456789"}]
   Eleição por Lista: exatamente 1 escolha. Uninominal: 1 por cargo.
   RegistoVoto + Voto são gravados na mesma transação e não ficam ligados.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_RegistarVoto
    @nif      NVARCHAR(9),
    @eleicao  NVARCHAR(200),
    @escolhas NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tipo NVARCHAR(20);
    SELECT @tipo = tipo_escrutinio FROM dbo.Eleicao WHERE nome = @eleicao;

    IF @tipo IS NULL
       OR NOT EXISTS (SELECT 1 FROM dbo.Recenseamento WHERE eleicao = @eleicao AND nif = @nif)
        THROW 50020, N'Não consta do recenseamento desta eleição.', 1;
    IF EXISTS (SELECT 1 FROM dbo.RegistoVoto WHERE eleicao = @eleicao AND nif = @nif)
        THROW 50021, N'Já exerceu o seu direito de voto nesta eleição.', 1;
    IF ISJSON(@escolhas) <> 1
        THROW 50022, N'Boletim de voto inválido.', 1;

    DECLARE @esc TABLE (cargo NVARCHAR(100), tipo NVARCHAR(20), sigla NVARCHAR(15), nif NVARCHAR(9));
    INSERT @esc
    SELECT cargo, tipo, sigla, nif
    FROM OPENJSON(@escolhas) WITH (cargo NVARCHAR(100) '$.cargo', tipo NVARCHAR(20) '$.tipo',
                                   sigla NVARCHAR(15) '$.sigla', nif NVARCHAR(9) '$.nif');

    IF EXISTS (SELECT 1 FROM @esc WHERE tipo NOT IN (N'Valido', N'Branco', N'Nulo'))
        THROW 50022, N'Boletim de voto inválido.', 1;
    IF @tipo = 'Lista' AND (SELECT COUNT(*) FROM @esc) <> 1
        THROW 50023, N'Um boletim de lista tem de ter exatamente uma escolha.', 1;
    IF @tipo = 'Uninominal' AND
       ((SELECT COUNT(*) FROM @esc) <> (SELECT COUNT(*) FROM dbo.Cargo WHERE eleicao = @eleicao)
        OR (SELECT COUNT(DISTINCT cargo) FROM @esc) <> (SELECT COUNT(*) FROM @esc))
        THROW 50024, N'Tem de indicar uma escolha para cada cargo em disputa.', 1;

    BEGIN TRANSACTION;
        INSERT dbo.RegistoVoto (eleicao, nif) VALUES (@eleicao, @nif);

        INSERT dbo.Voto (eleicao, tipo_voto, cargo, sigla_lista, nif_candidato)
        SELECT @eleicao, e.tipo,
               CASE WHEN @tipo = 'Lista' THEN NULL ELSE e.cargo END,
               CASE WHEN @tipo = 'Lista' AND e.tipo = N'Valido' THEN e.sigla END,
               CASE WHEN @tipo = 'Uninominal' AND e.tipo = N'Valido' THEN e.nif END
        FROM @esc e;
    COMMIT TRANSACTION;

    -- comprovativo: apenas a hora e uma referência, nunca o sentido do voto
    SELECT rv.data_hora,
           LEFT(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256',
                CONCAT(rv.nif, N'|', rv.eleicao, N'|', CONVERT(VARCHAR(30), rv.data_hora, 126))), 2), 12) AS referencia
    FROM dbo.RegistoVoto rv WHERE rv.eleicao = @eleicao AND rv.nif = @nif;
END;
GO

/* ---------------------------------------------------------------------
   ESTADOS E APURAMENTO
   --------------------------------------------------------------------- */

-- Abre/encerra as eleições de acordo com o calendário. Uma eleição Agendada
-- que ainda não cumpra os requisitos (G9) simplesmente continua Agendada.
CREATE OR ALTER PROCEDURE dbo.sp_AtualizarEstadosEleicoes
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @n NVARCHAR(200);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT nome FROM dbo.Eleicao
        WHERE estado = 'Agendada' AND GETDATE() >= data_inicio AND GETDATE() < data_fim;
    OPEN c;
    FETCH NEXT FROM c INTO @n;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            UPDATE dbo.Eleicao SET estado = 'Em Curso' WHERE nome = @n;
        END TRY
        BEGIN CATCH
            -- não cumpre os requisitos para arrancar: fica Agendada
        END CATCH;
        FETCH NEXT FROM c INTO @n;
    END;
    CLOSE c; DEALLOCATE c;

    UPDATE dbo.Eleicao SET estado = 'Encerrada' WHERE estado = 'Em Curso' AND GETDATE() >= data_fim;
END;
GO

-- Apuramento: só eleições Encerradas e com integridade verificada.
-- Eleições por Lista: método de Hondt sobre a soma dos mandatos dos cargos.
-- Uninominais: vence o candidato com mais votos em cada cargo (empate = sem vencedor).
CREATE OR ALTER PROCEDURE dbo.sp_ApurarEleicao
    @eleicao NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tipo NVARCHAR(20) = (SELECT tipo_escrutinio FROM dbo.Eleicao WHERE nome = @eleicao AND estado = 'Encerrada');
    IF @tipo IS NULL
        THROW 50030, N'Só é possível apurar uma eleição que esteja encerrada.', 1;
    IF EXISTS (SELECT 1 FROM dbo.vw_Integridade
               WHERE eleicao = @eleicao AND votos <> votos_esperados)
        THROW 50031, N'Integridade violada: o número de votos não corresponde ao número de votantes.', 1;

    BEGIN TRANSACTION;
        DELETE FROM dbo.ResultadoApuramento WHERE eleicao = @eleicao;

        -- linha global: total de boletins entregues
        INSERT dbo.ResultadoApuramento (eleicao, num_votos)
        SELECT @eleicao, COUNT(*) FROM dbo.RegistoVoto WHERE eleicao = @eleicao;

        IF @tipo = 'Lista'
        BEGIN
            DECLARE @M INT = (SELECT ISNULL(SUM(num_mandatos), 0) FROM dbo.Cargo WHERE eleicao = @eleicao);
            ;WITH v AS (
                SELECT l.sigla, COUNT(vt.id_voto) AS votos
                FROM dbo.Lista l
                LEFT JOIN dbo.Voto vt ON vt.eleicao = l.eleicao AND vt.sigla_lista = l.sigla AND vt.tipo_voto = 'Valido'
                WHERE l.eleicao = @eleicao GROUP BY l.sigla),
            k AS (SELECT TOP (@M) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects),
            q AS (SELECT v.sigla, v.votos, CAST(v.votos AS FLOAT) / k.n AS quociente
                  FROM v CROSS JOIN k WHERE v.votos > 0),
            escolhidos AS (SELECT TOP (@M) sigla FROM q ORDER BY quociente DESC, votos DESC, sigla)
            INSERT dbo.ResultadoApuramento (eleicao, sigla_lista, num_votos, num_mandatos)
            SELECT @eleicao, v.sigla, v.votos, (SELECT COUNT(*) FROM escolhidos s WHERE s.sigla = v.sigla)
            FROM v;
        END
        ELSE
        BEGIN
            INSERT dbo.ResultadoApuramento (eleicao, cargo, nif_candidato, num_votos)
            SELECT c.eleicao, c.cargo, c.nif, COUNT(vt.id_voto)
            FROM dbo.Candidato c
            LEFT JOIN dbo.Voto vt ON vt.eleicao = c.eleicao AND vt.cargo = c.cargo
                                 AND vt.nif_candidato = c.nif AND vt.tipo_voto = 'Valido'
            WHERE c.eleicao = @eleicao GROUP BY c.eleicao, c.cargo, c.nif;

            UPDATE r SET num_mandatos = 1
            FROM dbo.ResultadoApuramento r
            WHERE r.eleicao = @eleicao AND r.nif_candidato IS NOT NULL AND r.num_votos > 0
              AND r.num_votos = (SELECT MAX(x.num_votos) FROM dbo.ResultadoApuramento x
                                 WHERE x.eleicao = r.eleicao AND x.cargo = r.cargo AND x.nif_candidato IS NOT NULL)
              AND (SELECT COUNT(*) FROM dbo.ResultadoApuramento x
                   WHERE x.eleicao = r.eleicao AND x.cargo = r.cargo AND x.nif_candidato IS NOT NULL
                     AND x.num_votos = r.num_votos) = 1;
        END;

        UPDATE dbo.Eleicao SET estado = 'Apurada' WHERE nome = @eleicao;
    COMMIT TRANSACTION;

    SELECT cargo, sigla_lista, nif_candidato, num_votos, num_mandatos
    FROM dbo.ResultadoApuramento WHERE eleicao = @eleicao ORDER BY num_votos DESC;
END;
GO
