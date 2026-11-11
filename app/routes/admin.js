// API da administração: dashboards e manutenção
const router = require('express').Router();
const { sql, getPool, runAs } = require('../db');
const { wrap } = require('../util');

const TIPOS = ['Lista', 'Uninominal'];
const ESTADOS_DESTINO = ['Em Curso', 'Encerrada', 'Apurada'];
const bad = (res, msg) => res.status(400).json({ erro: msg });
const texto = (v, max) => (typeof v === 'string' && v.trim().length && v.trim().length <= max ? v.trim() : null);
const opcional = (v, max) => (v ? String(v).trim().slice(0, max) || null : null);
const data = (v) => { const d = new Date(v); return isNaN(d) ? null : d; };
const dataLocal = (v) => {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(v || ''));
  return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null;
};
const nifOk = (v) => /^\d{9}$/.test(String(v || ''));
const autor = (req) => `ADMIN:${req.session.user.id}`;
const lancar = (numero, msg) => { const e = new Error(msg); e.number = numero; throw e; };

/* ---------------------------- DASHBOARD ---------------------------------- */
router.get('/dashboard', wrap(async (req, res) => {
  const pool = await getPool();
  await pool.request().execute('dbo.sp_AtualizarEstadosEleicoes');
  const [kpi, part, logs] = await Promise.all([
    pool.request().query(`SELECT
        (SELECT COUNT(*) FROM dbo.Eleitor WHERE ativo = 1) AS eleitores_ativos,
        (SELECT COUNT(*) FROM dbo.Eleicao) AS eleicoes,
        (SELECT COUNT(*) FROM dbo.Eleicao WHERE estado = 'Em Curso') AS em_curso,
        (SELECT COUNT(*) FROM dbo.RegistoVoto) AS votos_registados`),
    pool.request().query(`SELECT eleicao, estado, inscritos, votantes, abstencao, taxa_participacao
                          FROM dbo.vw_ParticipacaoEleicao WHERE estado <> 'Agendada' ORDER BY eleicao`),
    pool.request().query(`SELECT TOP 8 data_hora, autor, acao, detalhe FROM dbo.Auditoria ORDER BY id_log DESC`),
  ]);
  res.json({ kpi: kpi.recordset[0], participacao: part.recordset, atividade: logs.recordset });
}));

/* ----------------------------- ELEIÇÕES ---------------------------------- */
router.get('/eleicoes', wrap(async (req, res) => {
  const r = await (await getPool()).request().query(`
    SELECT e.nome, e.tipo_escrutinio, e.data_inicio, e.data_fim, e.estado,
           (SELECT COUNT(*) FROM dbo.Candidato c WHERE c.eleicao = e.nome) AS candidatos,
           (SELECT COUNT(*) FROM dbo.Recenseamento r WHERE r.eleicao = e.nome) AS recenseados,
           (SELECT COUNT(*) FROM dbo.RegistoVoto rv WHERE rv.eleicao = e.nome) AS votos
    FROM dbo.Eleicao e ORDER BY e.data_inicio DESC`);
  res.json(r.recordset);
}));

router.get('/eleicoes/:nome', wrap(async (req, res) => {
  const pool = await getPool();
  const q = (txt) => pool.request().input('e', sql.NVarChar(200), req.params.nome).query(txt);
  const e = await q('SELECT nome, descricao, data_inicio, data_fim, tipo_escrutinio, estado FROM dbo.Eleicao WHERE nome = @e');
  if (!e.recordset.length) return res.status(404).json({ erro: 'Eleição não encontrada.' });
  const [cargos, listas, cands, rec] = await Promise.all([
    q('SELECT cargo, num_mandatos FROM dbo.Cargo WHERE eleicao = @e ORDER BY cargo'),
    q('SELECT sigla, designacao FROM dbo.Lista WHERE eleicao = @e ORDER BY sigla'),
    q(`SELECT c.nif, el.nome, c.cargo, c.sigla_lista, c.posicao FROM dbo.Candidato c
       JOIN dbo.Eleitor el ON el.nif = c.nif WHERE c.eleicao = @e ORDER BY c.sigla_lista, c.posicao, el.nome`),
    q('SELECT COUNT(*) AS n FROM dbo.Recenseamento WHERE eleicao = @e'),
  ]);
  res.json({ eleicao: e.recordset[0], cargos: cargos.recordset, listas: listas.recordset,
    candidatos: cands.recordset, recenseados: rec.recordset[0].n });
}));

function lerEleicao(body, criar) {
  const nome = texto(body.nome, 200), tipo = body.tipo, ini = data(body.dataInicio), fim = data(body.dataFim);
  if (criar && (!nome || nome.includes('/'))) return { erro: 'Indique o nome da eleição (máx. 200 caracteres, sem "/").' };
  if (!TIPOS.includes(tipo)) return { erro: 'Tipo de escrutínio inválido.' };
  if (!ini || !fim) return { erro: 'Datas inválidas.' };
  if (fim <= ini) return { erro: 'A data de fim tem de ser posterior à data de início.' };
  return { nome, tipo, ini, fim, descricao: opcional(body.descricao, 500) };
}

router.post('/eleicoes', wrap(async (req, res) => {
  const v = lerEleicao(req.body, true);
  if (v.erro) return bad(res, v.erro);
  await runAs(autor(req), (rq) => rq().input('n', sql.NVarChar(200), v.nome).input('d', sql.NVarChar(500), v.descricao)
    .input('t', sql.NVarChar(20), v.tipo).input('i', sql.DateTime, v.ini).input('f', sql.DateTime, v.fim)
    .input('a', sql.Int, req.session.user.id)
    .query(`INSERT dbo.Eleicao (nome, descricao, data_inicio, data_fim, tipo_escrutinio, id_admin_criador)
            VALUES (@n, @d, @i, @f, @t, @a)`));
  res.status(201).json({ nome: v.nome });
}));

router.put('/eleicoes/:nome', wrap(async (req, res) => {
  const v = lerEleicao(req.body, false);
  if (v.erro) return bad(res, v.erro);
  await runAs(autor(req), (rq) => rq().input('n', sql.NVarChar(200), req.params.nome).input('d', sql.NVarChar(500), v.descricao)
    .input('t', sql.NVarChar(20), v.tipo).input('i', sql.DateTime, v.ini).input('f', sql.DateTime, v.fim)
    .query('UPDATE dbo.Eleicao SET descricao=@d, tipo_escrutinio=@t, data_inicio=@i, data_fim=@f WHERE nome=@n'));
  res.json({ ok: true });
}));

// só é possível eliminar eleições ainda Agendadas e sem votos
router.delete('/eleicoes/:nome', wrap(async (req, res) => {
  await runAs(autor(req), async (rq) => {
    const q = (txt) => rq().input('e', sql.NVarChar(200), req.params.nome).query(txt);
    const e = await q('SELECT estado FROM dbo.Eleicao WHERE nome = @e');
    if (!e.recordset.length) lancar(50900, 'Eleição não encontrada.');
    if (e.recordset[0].estado !== 'Agendada') lancar(50901, 'Só é possível eliminar eleições agendadas.');
    for (const t of ['Recenseamento', 'Candidato', 'Lista', 'Cargo'])
      await q(`DELETE FROM dbo.${t} WHERE eleicao = @e`);
    await q('DELETE FROM dbo.Eleicao WHERE nome = @e');
  });
  res.json({ ok: true });
}));

router.post('/eleicoes/:nome/estado', wrap(async (req, res) => {
  const estado = req.body.estado;
  if (!ESTADOS_DESTINO.includes(estado)) return bad(res, 'Estado inválido.');
  await runAs(autor(req), async (rq) => {
    if (estado === 'Apurada') {
      await rq().input('eleicao', sql.NVarChar(200), req.params.nome).execute('dbo.sp_ApurarEleicao');
    } else {
      await rq().input('e', sql.NVarChar(200), req.params.nome).input('s', sql.NVarChar(20), estado)
        .query('UPDATE dbo.Eleicao SET estado = @s WHERE nome = @e');
    }
  });
  res.json({ ok: true });
}));

/* ---------------------- CARGOS, LISTAS, CANDIDATOS ----------------------- */

router.post('/eleicoes/:nome/cargos', wrap(async (req, res) => {
  const cargo = texto(req.body.cargo, 100), n = Number(req.body.numMandatos || 1);
  if (!cargo || !Number.isInteger(n) || n < 1 || n > 500) return bad(res, 'Indique o cargo e o nº de mandatos.');
  await runAs(autor(req), (rq) => rq().input('e', sql.NVarChar(200), req.params.nome)
    .input('c', sql.NVarChar(100), cargo).input('n', sql.Int, n)
    .query('INSERT dbo.Cargo (eleicao, cargo, num_mandatos) VALUES (@e, @c, @n)'));
  res.status(201).json({ ok: true });
}));
router.delete('/eleicoes/:nome/cargos/:cargo', wrap(async (req, res) => {
  await runAs(autor(req), (rq) => rq().input('e', sql.NVarChar(200), req.params.nome).input('c', sql.NVarChar(100), req.params.cargo)
    .query('DELETE FROM dbo.Cargo WHERE eleicao = @e AND cargo = @c'));
  res.json({ ok: true });
}));

router.post('/eleicoes/:nome/listas', wrap(async (req, res) => {
  const sigla = texto(req.body.sigla, 15), des = texto(req.body.designacao, 150);
  if (!sigla || !des) return bad(res, 'Indique a sigla e a designação da lista.');
  await runAs(autor(req), (rq) => rq().input('e', sql.NVarChar(200), req.params.nome)
    .input('s', sql.NVarChar(15), sigla).input('d', sql.NVarChar(150), des)
    .query('INSERT dbo.Lista (eleicao, sigla, designacao) VALUES (@e, @s, @d)'));
  res.status(201).json({ ok: true });
}));
router.delete('/eleicoes/:nome/listas/:sigla', wrap(async (req, res) => {
  await runAs(autor(req), (rq) => rq().input('e', sql.NVarChar(200), req.params.nome).input('s', sql.NVarChar(15), req.params.sigla)
    .query('DELETE FROM dbo.Lista WHERE eleicao = @e AND sigla = @s'));
  res.json({ ok: true });
}));

router.post('/eleicoes/:nome/candidatos', wrap(async (req, res) => {
  const cargo = texto(req.body.cargo, 100), sigla = opcional(req.body.sigla, 15);
  const posicao = req.body.posicao ? Number(req.body.posicao) : null;
  if (!nifOk(req.body.nif) || !cargo) return bad(res, 'Indique o NIF do candidato e o cargo.');
  if (sigla && !Number.isInteger(posicao)) return bad(res, 'Indique a posição do candidato na lista.');
  await runAs(autor(req), (rq) => rq().input('e', sql.NVarChar(200), req.params.nome)
    .input('n', sql.NVarChar(9), req.body.nif).input('c', sql.NVarChar(100), cargo)
    .input('s', sql.NVarChar(15), sigla).input('p', sql.Int, sigla ? posicao : null)
    .query('INSERT dbo.Candidato (eleicao, nif, cargo, sigla_lista, posicao) VALUES (@e, @n, @c, @s, @p)'));
  res.status(201).json({ ok: true });
}));
router.delete('/eleicoes/:nome/candidatos/:nif', wrap(async (req, res) => {
  await runAs(autor(req), (rq) => rq().input('e', sql.NVarChar(200), req.params.nome).input('n', sql.NVarChar(9), req.params.nif)
    .query('DELETE FROM dbo.Candidato WHERE eleicao = @e AND nif = @n'));
  res.json({ ok: true });
}));

/* ------------------------- RECENSEAMENTO --------------------------------- */
// Recenseia todos os eleitores ativos que ainda não estejam inscritos na eleição
router.post('/eleicoes/:nome/recenseamento', wrap(async (req, res) => {
  const n = await runAs(autor(req), async (rq) => {
    const r = await rq().input('e', sql.NVarChar(200), req.params.nome).query(`
      INSERT dbo.Recenseamento (eleicao, nif)
      SELECT @e, el.nif FROM dbo.Eleitor el
      WHERE el.ativo = 1
        AND NOT EXISTS (SELECT 1 FROM dbo.Recenseamento r WHERE r.eleicao = @e AND r.nif = el.nif)`);
    return r.rowsAffected[0];
  });
  res.json({ recenseados: n });
}));
router.delete('/eleicoes/:nome/recenseamento', wrap(async (req, res) => {
  await runAs(autor(req), (rq) => rq().input('e', sql.NVarChar(200), req.params.nome)
    .query('DELETE FROM dbo.Recenseamento WHERE eleicao = @e'));
  res.json({ ok: true });
}));

/* ----------------------------- RESULTADOS -------------------------------- */
router.get('/eleicoes/:nome/resultados', wrap(async (req, res) => {
  const pool = await getPool();
  const q = (t) => pool.request().input('e', sql.NVarChar(200), req.params.nome).query(t);
  const info = await q('SELECT nome, estado, tipo_escrutinio FROM dbo.Eleicao WHERE nome = @e');
  if (!info.recordset.length) return res.status(404).json({ erro: 'Eleição não encontrada.' });
  const lista = info.recordset[0].tipo_escrutinio === 'Lista';
  const [resu, part, afluencia] = await Promise.all([
    lista ? q('SELECT sigla AS opcao, designacao AS detalhe, votos, percentagem, mandatos FROM dbo.vw_ResultadosLista WHERE eleicao = @e ORDER BY votos DESC')
          : q('SELECT nome AS opcao, cargo AS detalhe, votos, percentagem, 0 AS mandatos FROM dbo.vw_ResultadosCandidato WHERE eleicao = @e ORDER BY cargo, votos DESC'),
    q('SELECT inscritos, votantes, abstencao, taxa_participacao, votos_brancos, votos_nulos FROM dbo.vw_ParticipacaoEleicao WHERE eleicao = @e'),
    q('SELECT dia, hora, votantes FROM dbo.vw_AfluenciaHoraria WHERE eleicao = @e ORDER BY dia, hora'),
  ]);
  res.json({ eleicao: info.recordset[0], resultados: resu.recordset, participacao: part.recordset[0], afluencia: afluencia.recordset });
}));

/* ------------------------------ ELEITORES -------------------------------- */
router.get('/eleitores', wrap(async (req, res) => {
  const q = `%${String(req.query.q || '').trim().slice(0, 60)}%`;
  const r = await (await getPool()).request().input('q', sql.NVarChar(62), q).query(`
    SELECT TOP 500 nif, nome, data_nascimento, ativo FROM dbo.Eleitor
    WHERE nome LIKE @q OR nif LIKE @q ORDER BY nome`);
  res.json(r.recordset);
}));

router.post('/eleitores', wrap(async (req, res) => {
  const nome = texto(req.body.nome, 150), nasc = dataLocal(req.body.dataNascimento);
  if (!nome || !nasc) return bad(res, 'Indique o nome e a data de nascimento.');
  if (!nifOk(req.body.nif)) return bad(res, 'O NIF tem 9 dígitos.');
  await runAs(autor(req), async (rq) => {
    await rq().input('n', sql.NVarChar(9), req.body.nif).input('nm', sql.NVarChar(150), nome).input('d', sql.Date, nasc)
      .query('INSERT dbo.Eleitor (nif, nome, data_nascimento) VALUES (@n, @nm, @d)');
    await rq().input('n', sql.NVarChar(9), req.body.nif)
      .query("INSERT dbo.Auditoria (autor, acao, entidade, detalhe) VALUES (TRY_CAST(SESSION_CONTEXT(N'autor') AS NVARCHAR(40)), N'CRIAR_ELEITOR', N'Eleitor', CONCAT(N'NIF ', @n))");
  });
  res.status(201).json({ ok: true });
}));

router.put('/eleitores/:nif', wrap(async (req, res) => {
  const nome = texto(req.body.nome, 150), ativo = req.body.ativo ? 1 : 0;
  if (!nome) return bad(res, 'Indique o nome.');
  await runAs(autor(req), async (rq) => {
    await rq().input('n', sql.NVarChar(9), req.params.nif).input('nm', sql.NVarChar(150), nome).input('a', sql.Bit, ativo)
      .query('UPDATE dbo.Eleitor SET nome = @nm, ativo = @a WHERE nif = @n');
    await rq().input('n', sql.NVarChar(9), req.params.nif).input('d', sql.NVarChar(400), ativo ? 'Eleitor ativo/atualizado' : 'Eleitor desativado')
      .query("INSERT dbo.Auditoria (autor, acao, entidade, detalhe) VALUES (TRY_CAST(SESSION_CONTEXT(N'autor') AS NVARCHAR(40)), N'ATUALIZAR_ELEITOR', N'Eleitor', CONCAT(N'NIF ', @n, N': ', @d))");
  });
  res.json({ ok: true });
}));

/* ------------------------ AUDITORIA E AUTENTICAÇÕES ---------------------- */
router.get('/auditoria', wrap(async (req, res) => {
  const r = await (await getPool()).request().query(
    'SELECT TOP 200 id_log, data_hora, autor, acao, entidade, detalhe FROM dbo.Auditoria ORDER BY id_log DESC');
  res.json(r.recordset);
}));

router.get('/autenticacoes', wrap(async (req, res) => {
  const r = await (await getPool()).request().query(`
    SELECT TOP 200 l.id_log, l.data_hora, l.nif_tentativa, l.etapa, l.sucesso, l.motivo_falha
    FROM dbo.LogAutenticacao l ORDER BY l.id_log DESC`);
  res.json(r.recordset);
}));

module.exports = router;
