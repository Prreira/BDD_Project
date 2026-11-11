/* =====================================================================
   07_dados_adicionais.sql : carga de volume para tornar a demonstração
   realista (dashboards, consultas e gráficos com dados suficientes)
   - passa de 60 para 300 eleitores (NIF válidos); 2 ficam inativos
   - Presidencial 2026 (Em Curso): +120 votos ao longo das últimas 22 horas
   - Eleição da Junta de Freguesia 2026 (Lista, Em Curso): 150 votos
   - Legislativas 2024 (Lista, Apurada, 17 mandatos por Hondt)
   - Presidencial 2021 (Uninominal, Apurada)
   - registos de autenticação
   Os valores "aleatórios" são determinísticos (CHECKSUM), por isso a carga é
   sempre igual. Todos os nomes e listas são fictícios.
   ===================================================================== */
USE eVoto;
GO
SET NOCOUNT ON;
EXEC sp_set_session_context N'autor', N'ADMIN:1';

CREATE TABLE #N (n INT PRIMARY KEY);
INSERT #N (n) SELECT TOP (400) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects a CROSS JOIN sys.all_objects b;

-- #K: nº de ordem -> NIF (mesma fórmula do 04_dados_teste.sql)
CREATE TABLE #K (n INT PRIMARY KEY, nif NVARCHAR(9) COLLATE DATABASE_DEFAULT NOT NULL);
INSERT #K (n, nif)
SELECT n, dbo.fn_NifCompletar(CONCAT('2', RIGHT(CONCAT('0000000', 3100000 + n * 7919), 7))) FROM #N WHERE n <= 300;

/* ---- 240 eleitores novos (61 a 300) ------------------------------------ */
DECLARE @pn TABLE (i INT, n NVARCHAR(30));
INSERT @pn VALUES (0,N'Afonso'),(1,N'Beatriz'),(2,N'Cátia'),(3,N'David'),(4,N'Elisa'),(5,N'Fábio'),(6,N'Gabriela'),
                  (7,N'Henrique'),(8,N'Isabel'),(9,N'Jaime'),(10,N'Karina'),(11,N'Leonor'),(12,N'Márcio'),
                  (13,N'Natália'),(14,N'Óscar'),(15,N'Patrícia'),(16,N'Ricardo'),(17,N'Sara'),(18,N'Tiago'),(19,N'Vera');
DECLARE @sn TABLE (i INT, n NVARCHAR(30));
INSERT @sn VALUES (0,N'Alves'),(1,N'Batista'),(2,N'Carvalho'),(3,N'Dias'),(4,N'Fernandes'),(5,N'Gomes'),(6,N'Henriques'),
                  (7,N'Jesus'),(8,N'Lima'),(9,N'Machado'),(10,N'Neves'),(11,N'Oliveira'),(12,N'Pires'),(13,N'Queirós'),
                  (14,N'Rocha'),(15,N'Santos'),(16,N'Teixeira'),(17,N'Urbano'),(18,N'Vaz'),(19,N'Xavier');

INSERT dbo.Eleitor (nif, nome, data_nascimento)
SELECT k.nif, CONCAT(p.n, N' ', s.n), DATEADD(DAY, (k.n * 173) % 21000, '1945-01-01')
FROM #K k
JOIN @pn p ON p.i = (k.n - 1) % 20
JOIN @sn s ON s.i = ((k.n - 1) / 20) % 20
WHERE k.n > 60;

DECLARE @e1 NVARCHAR(200) = N'Eleições Autárquicas 2025 - Assembleia Municipal';
DECLARE @e2 NVARCHAR(200) = N'Eleição Presidencial 2026';
DECLARE @e3 NVARCHAR(200) = N'Eleição da Junta de Freguesia 2027';

/* ---- recenseamento dos eleitores novos nas eleições existentes ----------
   (a Presidencial já está Em Curso: o gatilho de bloqueio é desligado só
   durante esta carga de dados) */
INSERT dbo.Recenseamento (eleicao, nif) SELECT @e3, nif FROM #K WHERE n > 60;
DISABLE TRIGGER dbo.trg_Recenseamento_Bloqueio ON dbo.Recenseamento;
INSERT dbo.Recenseamento (eleicao, nif) SELECT @e2, nif FROM #K WHERE n > 60;
ENABLE TRIGGER dbo.trg_Recenseamento_Bloqueio ON dbo.Recenseamento;

/* ---- 2 eleitores inativos ainda recenseados (para a consulta C13) ------ */
UPDATE dbo.Eleitor SET ativo = 0 WHERE nif IN (SELECT nif FROM #K WHERE n IN (299, 300));

/* =====================================================================
   Presidencial 2026 (Em Curso): +120 votos nas últimas 22 horas
   ===================================================================== */
SELECT k.n, k.nif,
       ABS(CAST(CHECKSUM(k.n, 5) AS BIGINT)) % 100 AS r,
       DATEADD(MINUTE, -(ABS(CAST(CHECKSUM(k.n, 11) AS BIGINT)) % 1300), GETDATE()) AS hora
INTO #VA FROM #K k WHERE k.n BETWEEN 61 AND 180;

DISABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;
INSERT dbo.RegistoVoto (eleicao, nif, data_hora) SELECT @e2, nif, hora FROM #VA;
ENABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;

INSERT dbo.Voto (eleicao, tipo_voto, cargo, nif_candidato)
SELECT @e2,
       CASE WHEN v.r < 86 THEN 'Valido' WHEN v.r < 94 THEN 'Branco' ELSE 'Nulo' END,
       N'Presidente da República',
       CASE WHEN v.r < 38 THEN (SELECT nif FROM #K WHERE n = 58)
            WHEN v.r < 70 THEN (SELECT nif FROM #K WHERE n = 59)
            WHEN v.r < 86 THEN (SELECT nif FROM #K WHERE n = 60) END
FROM #VA v;
DROP TABLE #VA;

/* =====================================================================
   Junta de Freguesia 2026 (Lista, Em Curso)
   ===================================================================== */
DECLARE @e6 NVARCHAR(200) = N'Eleição da Junta de Freguesia 2026';
INSERT dbo.Eleicao (nome, descricao, data_inicio, data_fim, tipo_escrutinio, id_admin_criador)
VALUES (@e6, N'Eleição dos 7 membros da Junta de Freguesia. Escolha uma lista.',
        DATEADD(DAY, -2, GETDATE()), DATEADD(DAY, 20, GETDATE()), 'Lista', 2);
INSERT dbo.Cargo (eleicao, cargo, num_mandatos) VALUES (@e6, N'Junta de Freguesia', 7);
INSERT dbo.Lista (eleicao, sigla, designacao) VALUES
 (@e6, N'PH', N'Partido Horizonte'), (@e6, N'AC', N'Aliança Cívica'), (@e6, N'MV', N'Movimento Verde');
INSERT dbo.Candidato (eleicao, nif, cargo, sigla_lista, posicao)
SELECT @e6, nif, N'Junta de Freguesia',
       CASE (n - 90) / 3 WHEN 0 THEN N'PH' WHEN 1 THEN N'AC' ELSE N'MV' END, ((n - 90) % 3) + 1
FROM #K WHERE n BETWEEN 90 AND 98;
INSERT dbo.Recenseamento (eleicao, nif) SELECT @e6, nif FROM #K;
UPDATE dbo.Eleicao SET estado = 'Em Curso' WHERE nome = @e6;

SELECT k.n, k.nif,
       ABS(CAST(CHECKSUM(k.n, 7) AS BIGINT)) % 100 AS r,
       DATEADD(MINUTE, -(ABS(CAST(CHECKSUM(k.n, 13) AS BIGINT)) % 2400), GETDATE()) AS hora
INTO #VB FROM #K k WHERE k.n BETWEEN 100 AND 249;

DISABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;
INSERT dbo.RegistoVoto (eleicao, nif, data_hora) SELECT @e6, nif, hora FROM #VB;
ENABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;
INSERT dbo.Voto (eleicao, tipo_voto, sigla_lista)
SELECT @e6, CASE WHEN v.r < 85 THEN 'Valido' WHEN v.r < 93 THEN 'Branco' ELSE 'Nulo' END,
       CASE WHEN v.r < 35 THEN N'PH' WHEN v.r < 65 THEN N'AC' WHEN v.r < 85 THEN N'MV' END
FROM #VB v;
DROP TABLE #VB;

/* =====================================================================
   Legislativas 2024 (Lista, Apurada, 17 mandatos por Hondt)
   ===================================================================== */
DECLARE @e4 NVARCHAR(200) = N'Eleições Legislativas 2024 - Assembleia Distrital';
INSERT dbo.Eleicao (nome, descricao, data_inicio, data_fim, tipo_escrutinio, id_admin_criador)
VALUES (@e4, N'Eleição dos 17 membros da Assembleia Distrital pelo método de Hondt.',
        DATEADD(DAY, -700, GETDATE()), DATEADD(DAY, -699, GETDATE()), 'Lista', 1);
INSERT dbo.Cargo (eleicao, cargo, num_mandatos) VALUES (@e4, N'Assembleia Distrital', 17);
INSERT dbo.Lista (eleicao, sigla, designacao) VALUES
 (@e4, N'PH', N'Partido Horizonte'), (@e4, N'AC', N'Aliança Cívica'), (@e4, N'MV', N'Movimento Verde'),
 (@e4, N'IC', N'Independentes pelo Concelho'), (@e4, N'LB', N'Liberdade e Bem-Estar');
INSERT dbo.Candidato (eleicao, nif, cargo, sigla_lista, posicao)
SELECT @e4, nif, N'Assembleia Distrital',
       CASE (n - 100) / 3 WHEN 0 THEN N'PH' WHEN 1 THEN N'AC' WHEN 2 THEN N'MV' WHEN 3 THEN N'IC' ELSE N'LB' END, ((n - 100) % 3) + 1
FROM #K WHERE n BETWEEN 100 AND 114;
INSERT dbo.Recenseamento (eleicao, nif) SELECT @e4, nif FROM #K WHERE n <= 280;
UPDATE dbo.Eleicao SET estado = 'Em Curso' WHERE nome = @e4;

SELECT k.n, k.nif,
       ABS(CAST(CHECKSUM(k.n, 5) AS BIGINT)) % 1000 AS r,
       DATEADD(MINUTE, ABS(CAST(CHECKSUM(k.n, 3) AS BIGINT)) % 720,
               DATEADD(HOUR, 8, CAST(CAST(DATEADD(DAY, -700, GETDATE()) AS DATE) AS DATETIME))) AS hora
INTO #VC FROM #K k WHERE k.n <= 280 AND ABS(CAST(CHECKSUM(k.n, 21) AS BIGINT)) % 100 < 78;

DISABLE TRIGGER dbo.trg_RegistoVoto_Validar   ON dbo.RegistoVoto;
DISABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;
INSERT dbo.RegistoVoto (eleicao, nif, data_hora) SELECT @e4, nif, hora FROM #VC;
ENABLE TRIGGER dbo.trg_RegistoVoto_Validar   ON dbo.RegistoVoto;
ENABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;

INSERT dbo.Voto (eleicao, tipo_voto, sigla_lista)
SELECT @e4, CASE WHEN v.r < 960 THEN 'Valido' WHEN v.r < 985 THEN 'Branco' ELSE 'Nulo' END,
       CASE WHEN v.r < 330 THEN N'PH' WHEN v.r < 600 THEN N'AC' WHEN v.r < 800 THEN N'MV'
            WHEN v.r < 920 THEN N'IC' WHEN v.r < 960 THEN N'LB' END
FROM #VC v;
DROP TABLE #VC;
UPDATE dbo.Eleicao SET estado = 'Encerrada' WHERE nome = @e4;
EXEC dbo.sp_ApurarEleicao @e4;

/* =====================================================================
   Presidencial 2021 (Uninominal, Apurada)
   ===================================================================== */
DECLARE @e5 NVARCHAR(200) = N'Eleição Presidencial 2021';
INSERT dbo.Eleicao (nome, descricao, data_inicio, data_fim, tipo_escrutinio, id_admin_criador)
VALUES (@e5, N'Eleição do Presidente da República (histórico).',
        DATEADD(DAY, -1800, GETDATE()), DATEADD(DAY, -1799, GETDATE()), 'Uninominal', 1);
INSERT dbo.Cargo (eleicao, cargo, num_mandatos) VALUES (@e5, N'Presidente da República', 1);
INSERT dbo.Candidato (eleicao, nif, cargo) SELECT @e5, nif, N'Presidente da República' FROM #K WHERE n BETWEEN 120 AND 122;
INSERT dbo.Recenseamento (eleicao, nif) SELECT @e5, nif FROM #K WHERE n <= 200;
UPDATE dbo.Eleicao SET estado = 'Em Curso' WHERE nome = @e5;

SELECT k.n, k.nif,
       ABS(CAST(CHECKSUM(k.n, 8) AS BIGINT)) % 1000 AS r,
       DATEADD(MINUTE, ABS(CAST(CHECKSUM(k.n, 4) AS BIGINT)) % 720,
               DATEADD(HOUR, 8, CAST(CAST(DATEADD(DAY, -1800, GETDATE()) AS DATE) AS DATETIME))) AS hora
INTO #VD FROM #K k WHERE k.n <= 200 AND ABS(CAST(CHECKSUM(k.n, 22) AS BIGINT)) % 100 < 70;

DISABLE TRIGGER dbo.trg_RegistoVoto_Validar   ON dbo.RegistoVoto;
DISABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;
INSERT dbo.RegistoVoto (eleicao, nif, data_hora) SELECT @e5, nif, hora FROM #VD;
ENABLE TRIGGER dbo.trg_RegistoVoto_Validar   ON dbo.RegistoVoto;
ENABLE TRIGGER dbo.trg_RegistoVoto_Auditoria ON dbo.RegistoVoto;

INSERT dbo.Voto (eleicao, tipo_voto, cargo, nif_candidato)
SELECT @e5, CASE WHEN v.r < 930 THEN 'Valido' WHEN v.r < 970 THEN 'Branco' ELSE 'Nulo' END,
       N'Presidente da República',
       CASE WHEN v.r < 430 THEN (SELECT nif FROM #K WHERE n = 120)
            WHEN v.r < 780 THEN (SELECT nif FROM #K WHERE n = 121)
            WHEN v.r < 930 THEN (SELECT nif FROM #K WHERE n = 122) END
FROM #VD v;
DROP TABLE #VD;
UPDATE dbo.Eleicao SET estado = 'Encerrada' WHERE nome = @e5;
EXEC dbo.sp_ApurarEleicao @e5;

/* ---- registos de autenticação (últimos 7 dias) -------------------------- */
INSERT dbo.LogAutenticacao (nif_tentativa, data_hora, sucesso, motivo_falha, etapa)
SELECT k.nif, DATEADD(MINUTE, -(ABS(CAST(CHECKSUM(k.n, 9) AS BIGINT)) % 10000), GETDATE()),
       CASE WHEN ABS(CAST(CHECKSUM(k.n, 2) AS BIGINT)) % 100 < 90 THEN 1 ELSE 0 END,
       CASE WHEN ABS(CAST(CHECKSUM(k.n, 2) AS BIGINT)) % 100 >= 90 THEN N'Código incorreto (tentativa 1)' END,
       CASE WHEN ABS(CAST(CHECKSUM(k.n, 2) AS BIGINT)) % 100 < 90 THEN 'Validacao' ELSE 'Validacao' END
FROM #K k WHERE k.n > 60;

DROP TABLE #K;
DROP TABLE #N;
GO

SELECT (SELECT COUNT(*) FROM dbo.Eleitor)     AS Eleitores,
       (SELECT COUNT(*) FROM dbo.Eleicao)     AS Eleicoes,
       (SELECT COUNT(*) FROM dbo.RegistoVoto) AS RegistosVoto,
       (SELECT COUNT(*) FROM dbo.Voto)        AS Votos,
       (SELECT COUNT(*) FROM dbo.ResultadoApuramento) AS Resultados;
GO

