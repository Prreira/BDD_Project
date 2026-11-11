/* =====================================================================
   05_consultas.sql : interrogações SQL ao eVoto
   Cada consulta tem o enunciado (em linguagem natural) e a técnica usada.
   ===================================================================== */
USE eVoto;
GO

/* C1 ---------------------------------------------------------------------
   Enunciado: Eleições em curso, com o nº de cargos, de candidatos, de eleitores
   recenseados, de votos já registados e os dias que faltam para encerrar.
   Técnica: subconsultas correlacionadas + funções de data
   ------------------------------------------------------------------------ */
SELECT e.nome, e.tipo_escrutinio, e.data_fim,
       (SELECT COUNT(*) FROM dbo.Cargo c        WHERE c.eleicao = e.nome) AS cargos,
       (SELECT COUNT(*) FROM dbo.Candidato k    WHERE k.eleicao = e.nome) AS candidatos,
       (SELECT COUNT(*) FROM dbo.Recenseamento r WHERE r.eleicao = e.nome) AS recenseados,
       (SELECT COUNT(*) FROM dbo.RegistoVoto rv WHERE rv.eleicao = e.nome) AS votos_registados,
       DATEDIFF(DAY, GETDATE(), e.data_fim) AS dias_para_encerrar
FROM dbo.Eleicao e
WHERE e.estado = 'Em Curso';
GO

/* C2 ---------------------------------------------------------------------
   Enunciado: Resultado da eleição autárquica de 2025: votos, percentagem e
   mandatos de cada lista, ordenados pela classificação.
   Técnica: vista + função de janela RANK()
   ------------------------------------------------------------------------ */
SELECT RANK() OVER (ORDER BY r.votos DESC) AS classificacao,
       r.sigla, r.designacao, r.votos, r.percentagem, r.mandatos
FROM dbo.vw_ResultadosLista r
WHERE r.eleicao LIKE N'Eleições Autárquicas 2025%'
ORDER BY classificacao;
GO

/* C3 ---------------------------------------------------------------------
   Enunciado: Taxa de participação, abstenção, votos brancos e nulos de
   todas as eleições que já tenham arrancado.
   Técnica: vista com subconsultas correlacionadas
   ------------------------------------------------------------------------ */
SELECT eleicao, estado, inscritos, votantes, abstencao, taxa_participacao, votos_brancos, votos_nulos
FROM dbo.vw_ParticipacaoEleicao
WHERE estado IN ('Em Curso', 'Encerrada', 'Apurada')
ORDER BY taxa_participacao DESC;
GO

/* C4 ---------------------------------------------------------------------
   Enunciado: Eleitores recenseados na presidencial que ainda NÃO votaram
   (para campanhas de lembrete).
   Técnica: NOT EXISTS (subconsulta correlacionada)
   ------------------------------------------------------------------------ */
SELECT el.nif, el.nome, el.ativo
FROM dbo.Recenseamento r
JOIN dbo.Eleitor el ON el.nif = r.nif
WHERE r.eleicao = N'Eleição Presidencial 2026'
  AND NOT EXISTS (SELECT 1 FROM dbo.RegistoVoto rv WHERE rv.eleicao = r.eleicao AND rv.nif = r.nif)
ORDER BY el.nome;
GO

/* C5 ---------------------------------------------------------------------
   Enunciado: Votos registados por dia na presidencial de 2026, com o dia
   de maior afluência primeiro.
   Técnica: vista de afluência + GROUP BY + SUM
   ------------------------------------------------------------------------ */
SELECT a.dia, SUM(a.votantes) AS votantes, MAX(a.votantes) AS pico_numa_hora
FROM dbo.vw_AfluenciaHoraria a
WHERE a.eleicao = N'Eleição Presidencial 2026'
GROUP BY a.dia
ORDER BY votantes DESC;
GO

/* C6 ---------------------------------------------------------------------
   Enunciado: Listas cujo número de votos é superior à média de votos das
   listas da sua eleição.
   Técnica: subconsulta correlacionada com AVG
   ------------------------------------------------------------------------ */
SELECT r.eleicao, r.sigla, r.votos
FROM dbo.vw_ResultadosLista r
WHERE r.votos > (SELECT AVG(CAST(r2.votos AS FLOAT)) FROM dbo.vw_ResultadosLista r2 WHERE r2.eleicao = r.eleicao)
ORDER BY r.eleicao, r.votos DESC;
GO

/* C7 ---------------------------------------------------------------------
   Enunciado: Eleitores que votaram em TODAS as eleições encerradas ou
   apuradas em que estavam recenseados (e em pelo menos uma).
   Técnica: divisão relacional (duplo NOT EXISTS)
   ------------------------------------------------------------------------ */
SELECT el.nif, el.nome
FROM dbo.Eleitor el
WHERE EXISTS (SELECT 1 FROM dbo.Recenseamento r JOIN dbo.Eleicao e ON e.nome = r.eleicao
              WHERE r.nif = el.nif AND e.estado IN ('Encerrada', 'Apurada'))
  AND NOT EXISTS (SELECT 1
                  FROM dbo.Recenseamento r JOIN dbo.Eleicao e ON e.nome = r.eleicao
                  WHERE r.nif = el.nif AND e.estado IN ('Encerrada', 'Apurada')
                    AND NOT EXISTS (SELECT 1 FROM dbo.RegistoVoto rv WHERE rv.eleicao = r.eleicao AND rv.nif = r.nif))
ORDER BY el.nome;
GO

/* C8 ---------------------------------------------------------------------
   Enunciado: Participação na eleição autárquica de 2025 por escalão etário.
   Técnica: CASE + DATEDIFF + agregação condicional
   ------------------------------------------------------------------------ */
SELECT t.escalao,
       COUNT(*) AS inscritos,
       SUM(t.votou) AS votantes,
       CAST(100.0 * SUM(t.votou) / COUNT(*) AS DECIMAL(5,2)) AS taxa_participacao
FROM (
    SELECT CASE WHEN x.idade < 30 THEN N'18-29' WHEN x.idade < 45 THEN N'30-44'
                WHEN x.idade < 65 THEN N'45-64' ELSE N'65+' END AS escalao,
           x.votou
    FROM (
        SELECT DATEDIFF(YEAR, el.data_nascimento, GETDATE())
                 - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, el.data_nascimento, GETDATE()), el.data_nascimento) > GETDATE()
                        THEN 1 ELSE 0 END AS idade,
               CASE WHEN rv.nif IS NULL THEN 0 ELSE 1 END AS votou
        FROM dbo.Recenseamento r
        JOIN dbo.Eleitor el ON el.nif = r.nif
        LEFT JOIN dbo.RegistoVoto rv ON rv.eleicao = r.eleicao AND rv.nif = r.nif
        WHERE r.eleicao LIKE N'Eleições Autárquicas 2025%'
    ) x
) t
GROUP BY t.escalao
ORDER BY t.escalao;
GO

/* C9 ---------------------------------------------------------------------
   Enunciado: Vencedor (lista ou candidato) de cada cargo das eleições já
   apuradas, com o respetivo número de votos.
   Técnica: CTE + ROW_NUMBER() OVER (PARTITION BY ...)
   ------------------------------------------------------------------------ */
WITH ranking AS (
    SELECT ra.eleicao, ra.cargo, ra.sigla_lista, ra.nif_candidato, ra.num_votos,
           ROW_NUMBER() OVER (PARTITION BY ra.eleicao, ISNULL(ra.cargo, N'')
                              ORDER BY ra.num_votos DESC) AS pos
    FROM dbo.ResultadoApuramento ra
    WHERE ra.sigla_lista IS NOT NULL OR ra.nif_candidato IS NOT NULL
)
SELECT g.eleicao, COALESCE(g.sigla_lista, el.nome) AS vencedor, g.num_votos
FROM ranking g
JOIN dbo.Eleicao e ON e.nome = g.eleicao AND e.estado = 'Apurada'
LEFT JOIN dbo.Eleitor el ON el.nif = g.nif_candidato
WHERE g.pos = 1;
GO

/* C10 --------------------------------------------------------------------
   Enunciado: Afluência às urnas na eleição autárquica de 2025: votantes por
   dia e hora, com o total acumulado.
   Técnica: agregação + SUM() OVER (ORDER BY ...)
   ------------------------------------------------------------------------ */
SELECT CAST(rv.data_hora AS DATE) AS dia, DATEPART(HOUR, rv.data_hora) AS hora,
       COUNT(*) AS votantes,
       SUM(COUNT(*)) OVER (ORDER BY CAST(rv.data_hora AS DATE), DATEPART(HOUR, rv.data_hora)) AS acumulado
FROM dbo.RegistoVoto rv
WHERE rv.eleicao LIKE N'Eleições Autárquicas 2025%'
GROUP BY CAST(rv.data_hora AS DATE), DATEPART(HOUR, rv.data_hora)
ORDER BY dia, hora;
GO

/* C11 --------------------------------------------------------------------
   Enunciado: Percentagem de votos brancos e nulos em cada eleição com votos.
   Técnica: agregação condicional (CASE dentro de SUM)
   ------------------------------------------------------------------------ */
SELECT v.eleicao,
       COUNT(*) AS total_votos,
       SUM(CASE WHEN v.tipo_voto = 'Branco' THEN 1 ELSE 0 END) AS brancos,
       SUM(CASE WHEN v.tipo_voto = 'Nulo'   THEN 1 ELSE 0 END) AS nulos,
       CAST(100.0 * SUM(CASE WHEN v.tipo_voto <> 'Valido' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS perc_branco_nulo
FROM dbo.Voto v
GROUP BY v.eleicao;
GO

/* C12 --------------------------------------------------------------------
   Enunciado: Atividade registada na auditoria por autor e tipo de ação.
   Técnica: GROUP BY + MAX
   ------------------------------------------------------------------------ */
SELECT ISNULL(a.autor, N'(sistema)') AS autor, a.acao, COUNT(*) AS n_acoes, MAX(a.data_hora) AS ultima
FROM dbo.Auditoria a
GROUP BY a.autor, a.acao
ORDER BY n_acoes DESC;
GO

/* C13 --------------------------------------------------------------------
   Enunciado: Eleitores inativos que continuam recenseados em eleições ainda
   não encerradas (a corrigir pela administração).
   Técnica: JOIN múltiplo + filtro por conjunto de estados
   ------------------------------------------------------------------------ */
SELECT el.nif, el.nome, e.nome AS eleicao, e.estado
FROM dbo.Eleitor el
JOIN dbo.Recenseamento r ON r.nif = el.nif
JOIN dbo.Eleicao e       ON e.nome = r.eleicao
WHERE el.ativo = 0 AND e.estado IN ('Agendada', 'Em Curso');
GO

/* C14 --------------------------------------------------------------------
   Enunciado: Asserção de integridade - eleições em que o número de votos
   não corresponde ao número esperado de votos (0 linhas).
   Técnica: vista de integridade
   ------------------------------------------------------------------------ */
SELECT eleicao, registos_voto, votos, votos_esperados
FROM dbo.vw_Integridade
WHERE votos <> votos_esperados;
GO

/* C15 --------------------------------------------------------------------
   Enunciado: Ranking das eleições já iniciadas por abstenção (da maior para
   a menor), indicando a abstenção em % e em nº de eleitores.
   Técnica: vista + DENSE_RANK()
   ------------------------------------------------------------------------ */
SELECT DENSE_RANK() OVER (ORDER BY p.abstencao * 1.0 / NULLIF(p.inscritos, 0) DESC) AS posicao,
       p.eleicao, p.estado, p.abstencao AS abstencionistas,
       CAST(100.0 - p.taxa_participacao AS DECIMAL(5,2)) AS taxa_abstencao
FROM dbo.vw_ParticipacaoEleicao p
WHERE p.estado IN ('Em Curso', 'Encerrada', 'Apurada')
ORDER BY posicao;
GO

/* C16 --------------------------------------------------------------------
   Enunciado: Eleitores com tentativas de autenticação falhadas nas últimas
   24 horas, com o número de falhas e o último motivo.
   Técnica: JOIN + GROUP BY + HAVING + subconsulta
   ------------------------------------------------------------------------ */
SELECT el.nif, el.nome, COUNT(*) AS falhas, MAX(l.data_hora) AS ultima_falha,
       (SELECT TOP (1) l2.motivo_falha FROM dbo.LogAutenticacao l2
        WHERE l2.nif_tentativa = el.nif AND l2.sucesso = 0 ORDER BY l2.data_hora DESC) AS ultimo_motivo
FROM dbo.LogAutenticacao l
JOIN dbo.Eleitor el ON el.nif = l.nif_tentativa
WHERE l.sucesso = 0 AND l.data_hora >= DATEADD(HOUR, -24, GETDATE())
GROUP BY el.nif, el.nome
HAVING COUNT(*) >= 1
ORDER BY falhas DESC;
GO

/* C17 --------------------------------------------------------------------
   Enunciado: Composição de cada lista (candidatos por ordem de posição) na
   eleição autárquica de 2025.
   Técnica: JOIN de 3 tabelas + ORDER BY por grupo
   ------------------------------------------------------------------------ */
SELECT l.sigla, l.designacao, c.posicao, el.nome AS candidato
FROM dbo.Lista l
JOIN dbo.Candidato c ON c.eleicao = l.eleicao AND c.sigla_lista = l.sigla
JOIN dbo.Eleitor el  ON el.nif = c.nif
WHERE l.eleicao LIKE N'Eleições Autárquicas 2025%'
ORDER BY l.sigla, c.posicao;
GO
