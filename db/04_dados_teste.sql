/* =====================================================================
   04_dados_teste.sql : dados de demonstração
   - 2 administradores, 60 eleitores (NIF válidos), 3 eleições (o 07_dados_adicionais.sql acrescenta volume):
       1) Autárquicas 2025   (Lista, Apurada)    - histórica, com mandatos por Hondt
       2) Presidencial 2026  (Uninominal, Em Curso)
       3) Junta de Freguesia 2027 (Lista, Agendada)
   As passwords dos administradores são definidas pelo app/setup.js (bcrypt).
   Os eleitores NÃO têm password: entram com o NIF + código de uso único.
   Todos os nomes, listas e candidatos são fictícios.
   ===================================================================== */
USE eVoto;
GO
SET NOCOUNT ON;

CREATE TABLE #N (n INT PRIMARY KEY);
INSERT #N (n) SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects a CROSS JOIN sys.all_objects b;

/* ---- Administradores ------------------------------------------------ */
INSERT dbo.Administrador (email, nome, password_hash, nivel_acesso) VALUES
 (N'admin1@evoto.pt', N'Marta Figueiredo', 'PENDENTE', 2),
 (N'admin2@evoto.pt', N'Rui Cardoso',      'PENDENTE', 1);

EXEC sp_set_session_context N'autor', N'ADMIN:1';

/* ---- 60 eleitores com NIF válido (#E guarda o nº de ordem -> NIF) ---- */
CREATE TABLE #E (n INT PRIMARY KEY, nif NVARCHAR(9) COLLATE DATABASE_DEFAULT NOT NULL, nome NVARCHAR(150) COLLATE DATABASE_DEFAULT NOT NULL);

DECLARE @nomes TABLE (i INT, n NVARCHAR(30));
INSERT @nomes VALUES (0,N'Ana'),(1,N'Bruno'),(2,N'Carla'),(3,N'Diogo'),(4,N'Eva'),
                     (5,N'Filipe'),(6,N'Graça'),(7,N'Hugo'),(8,N'Inês'),(9,N'João');
DECLARE @apelidos TABLE (i INT, n NVARCHAR(30));
INSERT @apelidos VALUES (0,N'Almeida'),(1,N'Barros'),(2,N'Correia'),(3,N'Duarte'),(4,N'Esteves'),(5,N'Faria');

-- nomes próprios das pessoas que são candidatas
DECLARE @cand TABLE (n INT, nome NVARCHAR(150));
INSERT @cand VALUES (46,N'Teresa Moura'),(47,N'Paulo Sequeira'),(48,N'Inês Cardoso'),
                    (49,N'Helena Castro'),(50,N'Jorge Pimentel'),(51,N'Rita Valente'),
                    (52,N'Bruno Salgado'),(53,N'Marta Leite'),(54,N'Rui Lopes'),
                    (55,N'Cláudia Reis'),(56,N'Nuno Fontes'),(57,N'Alice Pinto'),
                    (58,N'Sofia Antunes'),(59,N'Miguel Tavares'),(60,N'Luís Brandão');

INSERT #E (n, nif, nome)
SELECT x.n,
       dbo.fn_NifCompletar(CONCAT('2', RIGHT(CONCAT('0000000', 3100000 + x.n * 7919), 7))),
       COALESCE(c.nome, CONCAT(fn.n, N' ', sn.n))
FROM #N x
JOIN @nomes fn    ON fn.i = (x.n - 1) % 10
JOIN @apelidos sn ON sn.i = (x.n - 1) / 10
LEFT JOIN @cand c ON c.n = x.n
WHERE x.n <= 60;

INSERT dbo.Eleitor (nif, nome, data_nascimento)
SELECT nif, nome, DATEADD(DAY, n * 211, '1960-01-01') FROM #E;

/* =====================================================================
   ELEIÇÃO 1 (Lista, a apurar): Autárquicas 2025 - Assembleia Municipal
   ===================================================================== */
DECLARE @e1 NVARCHAR(200) = N'Eleições Autárquicas 2025 - Assembleia Municipal';
INSERT dbo.Eleicao (nome, descricao, data_inicio, data_fim, tipo_escrutinio, id_admin_criador)
VALUES (@e1, N'Eleição dos 9 membros da Assembleia Municipal pelo método de Hondt.',
        DATEADD(DAY, -60, GETDATE()), DATEADD(DAY, -59, GETDATE()), 'Lista', 1);

INSERT dbo.Cargo (eleicao, cargo, num_mandatos) VALUES (@e1, N'Assembleia Municipal', 9);
INSERT dbo.Lista (eleicao, sigla, designacao) VALUES
 (@e1, N'PH', N'Partido Horizonte'), (@e1, N'AC', N'Aliança Cívica'),
 (@e1, N'MV', N'Movimento Verde'),   (@e1, N'IC', N'Independentes pelo Concelho');
INSERT dbo.Candidato (eleicao, nif, cargo, sigla_lista, posicao)
SELECT @e1, e.nif, N'Assembleia Municipal',
       CASE (e.n - 46) / 3 WHEN 0 THEN N'PH' WHEN 1 THEN N'AC' WHEN 2 THEN N'MV' ELSE N'IC' END,
       ((e.n - 46) % 3) + 1
FROM #E e WHERE e.n BETWEEN 46 AND 57;

INSERT dbo.Recenseamento (eleicao, nif) SELECT @e1, nif FROM #E;

UPDATE dbo.Eleicao SET estado = 'Em Curso' WHERE nome = @e1;

-- carga histórica: desliga a validação de calendário e a auditoria só durante a importação
DISABLE TRIGGER dbo.trg_RegistoVoto_Validar   ON dbo.RegistoVoto;
DISABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;

INSERT dbo.RegistoVoto (eleicao, nif, data_hora)
SELECT @e1, e.nif, DATEADD(MINUTE, e.n * 17, DATEADD(HOUR, 8, CAST(CAST(DATEADD(DAY, -60, GETDATE()) AS DATE) AS DATETIME)))
FROM #E e WHERE e.n <= 48;

ENABLE TRIGGER dbo.trg_RegistoVoto_Validar   ON dbo.RegistoVoto;
ENABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;

-- 48 votos: PH 19, AC 15, MV 8, IC 3, 2 brancos, 1 nulo
INSERT dbo.Voto (eleicao, tipo_voto, sigla_lista)
SELECT @e1,
       CASE WHEN e.n <= 45 THEN 'Valido' WHEN e.n <= 47 THEN 'Branco' ELSE 'Nulo' END,
       CASE WHEN e.n <= 19 THEN N'PH' WHEN e.n <= 34 THEN N'AC' WHEN e.n <= 42 THEN N'MV' WHEN e.n <= 45 THEN N'IC' END
FROM #E e WHERE e.n <= 48;

UPDATE dbo.Eleicao SET estado = 'Encerrada' WHERE nome = @e1;
EXEC dbo.sp_ApurarEleicao @e1;

/* =====================================================================
   ELEIÇÃO 2 (Uninominal, Em Curso): Presidencial 2026
   ===================================================================== */
DECLARE @e2 NVARCHAR(200) = N'Eleição Presidencial 2026';
INSERT dbo.Eleicao (nome, descricao, data_inicio, data_fim, tipo_escrutinio, id_admin_criador)
VALUES (@e2, N'Eleição do Presidente da República. Vote uma única vez.',
        DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 180, GETDATE()), 'Uninominal', 1);

INSERT dbo.Cargo (eleicao, cargo, num_mandatos) VALUES (@e2, N'Presidente da República', 1);
INSERT dbo.Candidato (eleicao, nif, cargo) SELECT @e2, nif, N'Presidente da República' FROM #E WHERE n BETWEEN 58 AND 60;
INSERT dbo.Recenseamento (eleicao, nif) SELECT @e2, nif FROM #E;

UPDATE dbo.Eleicao SET estado = 'Em Curso' WHERE nome = @e2;

-- 22 votantes (eleitores 20 a 41), com todos os gatilhos ativos
INSERT dbo.RegistoVoto (eleicao, nif) SELECT @e2, nif FROM #E WHERE n BETWEEN 20 AND 41;

-- 22 votos: candidato 58 -> 9, 59 -> 7, 60 -> 3, 2 brancos, 1 nulo
INSERT dbo.Voto (eleicao, tipo_voto, cargo, nif_candidato)
SELECT @e2,
       CASE WHEN e.n - 19 <= 19 THEN 'Valido' WHEN e.n - 19 <= 21 THEN 'Branco' ELSE 'Nulo' END,
       N'Presidente da República',
       CASE WHEN e.n - 19 <= 9 THEN (SELECT nif FROM #E WHERE n = 58)
            WHEN e.n - 19 <= 16 THEN (SELECT nif FROM #E WHERE n = 59)
            WHEN e.n - 19 <= 19 THEN (SELECT nif FROM #E WHERE n = 60) END
FROM #E e WHERE e.n BETWEEN 20 AND 41;

/* =====================================================================
   ELEIÇÃO 3 (Lista, Agendada): Junta de Freguesia 2027
   ===================================================================== */
DECLARE @e3 NVARCHAR(200) = N'Eleição da Junta de Freguesia 2027';
INSERT dbo.Eleicao (nome, descricao, data_inicio, data_fim, tipo_escrutinio, id_admin_criador)
VALUES (@e3, N'Eleição dos 7 membros da Junta de Freguesia.',
        DATEADD(DAY, 20, GETDATE()), DATEADD(DAY, 21, GETDATE()), 'Lista', 2);
INSERT dbo.Cargo (eleicao, cargo, num_mandatos) VALUES (@e3, N'Junta de Freguesia', 7);
INSERT dbo.Lista (eleicao, sigla, designacao) VALUES
 (@e3, N'PH', N'Partido Horizonte'), (@e3, N'AC', N'Aliança Cívica');
INSERT dbo.Candidato (eleicao, nif, cargo, sigla_lista, posicao)
SELECT @e3, e.nif, N'Junta de Freguesia', CASE WHEN e.n <= 42 THEN N'PH' ELSE N'AC' END, ((e.n - 40) % 3) + 1
FROM #E e WHERE e.n BETWEEN 40 AND 45;
INSERT dbo.Recenseamento (eleicao, nif) SELECT @e3, nif FROM #E;

/* ---- alguns registos de autenticação de exemplo ---------------------- */
INSERT dbo.LogAutenticacao (nif_tentativa, data_hora, sucesso, motivo_falha, etapa)
SELECT nif, DATEADD(HOUR, -n, GETDATE()), CASE WHEN n % 5 = 0 THEN 0 ELSE 1 END,
       CASE WHEN n % 5 = 0 THEN N'Código incorreto (tentativa 1)' END,
       CASE WHEN n % 5 = 0 THEN 'Validacao' ELSE 'Codigo' END
FROM #E WHERE n BETWEEN 20 AND 30;

DROP TABLE #E;
DROP TABLE #N;
GO

SELECT (SELECT COUNT(*) FROM dbo.Eleitor)      AS Eleitores,
       (SELECT COUNT(*) FROM dbo.Eleicao)      AS Eleicoes,
       (SELECT COUNT(*) FROM dbo.RegistoVoto)  AS RegistosVoto,
       (SELECT COUNT(*) FROM dbo.Voto)         AS Votos,
       (SELECT COUNT(*) FROM dbo.ResultadoApuramento) AS Resultados;
GO
