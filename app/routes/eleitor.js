// API da área do eleitor (identificado pelo NIF da sessão)
const router = require('express').Router();
const { sql, getPool } = require('../db');
const { wrap } = require('../util');

const nomeEleicao = (q) => (typeof q === 'string' && q.length && q.length <= 200 ? q : null);

// Eleições em que o eleitor está recenseado
router.get('/eleicoes', wrap(async (req, res) => {
  const pool = await getPool();
  await pool.request().execute('dbo.sp_AtualizarEstadosEleicoes');
  const r = await pool.request().input('nif', sql.NVarChar(9), req.session.user.nif).query(`
    SELECT e.nome, e.descricao, e.tipo_escrutinio, e.data_inicio, e.data_fim, e.estado,
           CASE WHEN rv.nif IS NULL THEN 0 ELSE 1 END AS ja_votou, rv.data_hora AS data_voto
    FROM dbo.Recenseamento r
    JOIN dbo.Eleicao e   ON e.nome = r.eleicao
    LEFT JOIN dbo.RegistoVoto rv ON rv.eleicao = r.eleicao AND rv.nif = r.nif
    WHERE r.nif = @nif
    ORDER BY CASE e.estado WHEN 'Em Curso' THEN 0 WHEN 'Agendada' THEN 1 ELSE 2 END, e.data_inicio DESC`);
  res.json(r.recordset);
}));

// Candidatos de um cargo, por ordem estável (o índice é o que o browser envia;
// o NIF dos candidatos nunca é exposto ao eleitor)
async function candidatosPorCargo(pool, eleicao) {
  const r = await pool.request().input('e', sql.NVarChar(200), eleicao).query(`
    SELECT c.cargo, c.nif, el.nome
    FROM dbo.Candidato c JOIN dbo.Eleitor el ON el.nif = c.nif
    WHERE c.eleicao = @e ORDER BY c.cargo, el.nome, c.nif`);
  const por = {};
  for (const c of r.recordset) (por[c.cargo] = por[c.cargo] || []).push(c);
  return por;
}

// Boletim de voto: só se a eleição estiver em curso e o eleitor ainda não tiver votado
router.get('/boletim', wrap(async (req, res) => {
  const nome = nomeEleicao(req.query.eleicao);
  if (!nome) return res.status(400).json({ erro: 'Eleição inválida.' });
  const pool = await getPool();
  const e = await pool.request().input('e', sql.NVarChar(200), nome).input('nif', sql.NVarChar(9), req.session.user.nif).query(`
    SELECT e.nome, e.descricao, e.tipo_escrutinio, e.data_fim,
           CASE WHEN rv.nif IS NULL THEN 0 ELSE 1 END AS ja_votou
    FROM dbo.Recenseamento r
    JOIN dbo.Eleicao e ON e.nome = r.eleicao
    LEFT JOIN dbo.RegistoVoto rv ON rv.eleicao = r.eleicao AND rv.nif = r.nif
    WHERE r.eleicao = @e AND r.nif = @nif
      AND e.estado = 'Em Curso' AND GETDATE() BETWEEN e.data_inicio AND e.data_fim`);
  if (!e.recordset.length) return res.status(404).json({ erro: 'Eleição não disponível para votação.' });
  const el = e.recordset[0];
  if (el.ja_votou) return res.status(409).json({ erro: 'Já exerceu o seu direito de voto nesta eleição.' });

  if (el.tipo_escrutinio === 'Lista') {
    const l = await pool.request().input('e', sql.NVarChar(200), nome).query(
      'SELECT sigla, designacao FROM dbo.Lista WHERE eleicao = @e ORDER BY sigla');
    const c = await pool.request().input('e', sql.NVarChar(200), nome).query(`
      SELECT k.sigla_lista AS sigla, k.posicao, el.nome
      FROM dbo.Candidato k JOIN dbo.Eleitor el ON el.nif = k.nif
      WHERE k.eleicao = @e ORDER BY k.sigla_lista, k.posicao`);
    const listas = l.recordset.map((x) => ({ ...x, candidatos: c.recordset.filter((k) => k.sigla === x.sigla).map((k) => k.nome) }));
    return res.json({ eleicao: el, listas });
  }
  const cargos = await pool.request().input('e', sql.NVarChar(200), nome).query(
    'SELECT cargo FROM dbo.Cargo WHERE eleicao = @e ORDER BY cargo');
  const por = await candidatosPorCargo(pool, nome);
  res.json({
    eleicao: el,
    cargos: cargos.recordset.map((c) => ({
      cargo: c.cargo,
      candidatos: (por[c.cargo] || []).map((k, i) => ({ indice: i, nome: k.nome })),
    })),
  });
}));

// Votar: a validação final está na base de dados (procedimento + gatilhos)
router.post('/votar', wrap(async (req, res) => {
  const nome = nomeEleicao(req.body.eleicao);
  const escolhas = Array.isArray(req.body.escolhas) ? req.body.escolhas : null;
  if (!nome || !escolhas || !escolhas.length || escolhas.length > 20) return res.status(400).json({ erro: 'Pedido inválido.' });

  const pool = await getPool();
  const t = await pool.request().input('e', sql.NVarChar(200), nome)
    .query('SELECT tipo_escrutinio FROM dbo.Eleicao WHERE nome = @e');
  if (!t.recordset.length) return res.status(404).json({ erro: 'Eleição não encontrada.' });
  const lista = t.recordset[0].tipo_escrutinio === 'Lista';
  const por = lista ? null : await candidatosPorCargo(pool, nome);

  const json = [];
  for (const c of escolhas) {
    const tipo = String(c.tipo || '');
    if (!['Valido', 'Branco', 'Nulo'].includes(tipo)) return res.status(400).json({ erro: 'Pedido inválido.' });
    if (lista) {
      if (tipo === 'Valido' && (typeof c.sigla !== 'string' || !c.sigla || c.sigla.length > 15)) return res.status(400).json({ erro: 'Escolha uma lista.' });
      json.push({ tipo, sigla: tipo === 'Valido' ? c.sigla : null });
    } else {
      if (typeof c.cargo !== 'string' || !c.cargo || c.cargo.length > 100) return res.status(400).json({ erro: 'Pedido inválido.' });
      const cand = (por[c.cargo] || [])[Number(c.indice)];
      if (tipo === 'Valido' && !cand) return res.status(400).json({ erro: 'Escolha um candidato.' });
      json.push({ cargo: c.cargo, tipo, nif: tipo === 'Valido' ? cand.nif : null });
    }
  }
  const r = await pool.request()
    .input('nif', sql.NVarChar(9), req.session.user.nif)
    .input('eleicao', sql.NVarChar(200), nome)
    .input('escolhas', sql.NVarChar(sql.MAX), JSON.stringify(json))
    .execute('dbo.sp_RegistarVoto');
  res.json({ ok: true, dataHora: r.recordset[0].data_hora, referencia: r.recordset[0].referencia });
}));

// Resultados: só de eleições apuradas em que o eleitor estava recenseado
router.get('/resultados', wrap(async (req, res) => {
  const nome = nomeEleicao(req.query.eleicao);
  if (!nome) return res.status(400).json({ erro: 'Eleição inválida.' });
  const pool = await getPool();
  const q = (txt) => pool.request().input('e', sql.NVarChar(200), nome).input('nif', sql.NVarChar(9), req.session.user.nif).query(txt);
  const ok = await q(`SELECT e.tipo_escrutinio FROM dbo.Recenseamento r JOIN dbo.Eleicao e ON e.nome = r.eleicao
                      WHERE r.eleicao = @e AND r.nif = @nif AND e.estado = 'Apurada'`);
  if (!ok.recordset.length) return res.status(404).json({ erro: 'Resultados ainda não disponíveis.' });
  const tipo = ok.recordset[0].tipo_escrutinio;
  const resultados = tipo === 'Lista'
    ? await q('SELECT sigla AS opcao, designacao AS detalhe, votos, percentagem, mandatos FROM dbo.vw_ResultadosLista WHERE eleicao = @e ORDER BY votos DESC')
    : await q('SELECT nome AS opcao, cargo AS detalhe, votos, percentagem, 0 AS mandatos FROM dbo.vw_ResultadosCandidato WHERE eleicao = @e ORDER BY cargo, votos DESC');
  const p = await q('SELECT inscritos, votantes, abstencao, taxa_participacao, votos_brancos, votos_nulos FROM dbo.vw_ParticipacaoEleicao WHERE eleicao = @e');
  res.json({ tipo, resultados: resultados.recordset, participacao: p.recordset[0] });
}));

module.exports = router;
