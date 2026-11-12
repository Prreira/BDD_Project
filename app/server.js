const path = require('path');
const crypto = require('crypto');
const express = require('express');
const session = require('express-session');
const bcrypt = require('bcryptjs');
const { sql, getPool } = require('./db');
const { wrap, requireRole, requirePage, errorHandler } = require('./util');

const app = express();
const PORT = process.env.PORT || 3000;
// 'ecra' (omissão): o código de acesso é mostrado no próprio site (sem SMS/email).
// Qualquer outro valor: o código NÃO é devolvido ao browser (teria de ser entregue por outro canal).
const OTP_MODO = process.env.OTP_MODO || 'ecra';

app.disable('x-powered-by');
app.use(express.json({ limit: '100kb' }));
app.use((req, res, next) => {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'same-origin',
    'Cache-Control': 'no-store',
  });
  next();
});
app.use(session({
  name: 'evoto.sid',
  secret: process.env.SESSION_SECRET || crypto.randomBytes(32).toString('hex'),
  resave: false,
  saveUninitialized: false,
  rolling: true,
  cookie: { httpOnly: true, sameSite: 'strict', maxAge: 30 * 60 * 1000 },
}));

// ---- páginas protegidas por perfil (antes dos ficheiros estáticos) ----------
app.get('/eleitor.html', requirePage('ELEITOR'));
app.get('/admin.html', requirePage('ADMIN'));
app.use(express.static(path.join(__dirname, 'public')));
// Chart.js servido localmente (a apresentação não pode depender de uma CDN nem de Internet)
app.use('/vendor/chart.js', express.static(path.join(__dirname, 'node_modules', 'chart.js', 'dist')));

// ---- limitação de pedidos por IP (memória) ---------------------------------
const pedidos = new Map();
function limitar(max, janelaMs) {
  return (req, res, next) => {
    const k = `${req.path}|${req.ip}`, agora = Date.now();
    const e = (pedidos.get(k) || []).filter((t) => agora - t < janelaMs);
    if (e.length >= max) return res.status(429).json({ erro: 'Demasiados pedidos. Aguarde alguns minutos e tente novamente.' });
    e.push(agora); pedidos.set(k, e); next();
  };
}
setInterval(() => pedidos.clear(), 60 * 60 * 1000).unref();

const limparNif = (v) => String(v || '').replace(/\s+/g, '');
const nifFormatoOk = (v) => /^\d{9}$/.test(v);

// ---- autenticação do eleitor: 1) NIF -> código; 2) código -> sessão --------
app.post('/api/auth/codigo', limitar(15, 10 * 60 * 1000), wrap(async (req, res) => {
  const nif = limparNif(req.body.nif);
  if (!nifFormatoOk(nif)) return res.status(400).json({ erro: 'O NIF tem 9 dígitos.' });
  const pool = await getPool();
  const r = await pool.request().input('nif', sql.NVarChar(9), nif).execute('dbo.sp_GerarCodigoAcesso');
  const c = r.recordset[0];
  const out = { validadeSegundos: c.validade_segundos, expiraEm: c.expira_em, modo: OTP_MODO };
  if (OTP_MODO === 'ecra') {
    out.codigo = c.codigo;
    out.mensagem = `eVoto: o seu código de acesso é ${c.codigo.slice(0, 3)} ${c.codigo.slice(3)}. Válido por ${c.validade_segundos / 60} minutos. Não o partilhe com ninguém.`;
  }
  res.json(out);
}));

app.post('/api/auth/verificar', limitar(30, 10 * 60 * 1000), wrap(async (req, res) => {
  const nif = limparNif(req.body.nif), codigo = String(req.body.codigo || '').replace(/\s+/g, '');
  if (!nifFormatoOk(nif)) return res.status(400).json({ erro: 'O NIF tem 9 dígitos.' });
  if (!/^\d{6}$/.test(codigo)) return res.status(400).json({ erro: 'O código tem 6 dígitos.' });
  const pool = await getPool();
  const r = await pool.request().input('nif', sql.NVarChar(9), nif).input('codigo', sql.NVarChar(6), codigo)
    .execute('dbo.sp_ValidarCodigoAcesso');
  const e = r.recordset[0];
  req.session.regenerate((err) => {
    if (err) return res.status(500).json({ erro: 'Erro ao iniciar sessão.' });
    req.session.user = { perfil: 'ELEITOR', nif: e.nif, nome: e.nome };
    res.json({ perfil: 'ELEITOR', nome: e.nome, destino: '/eleitor.html' });
  });
}));

// NIF de um eleitor de teste (só em modo de demonstração)
app.get('/api/auth/demo', wrap(async (req, res) => {
  if (OTP_MODO !== 'ecra') return res.status(404).json({ erro: 'Indisponível.' });
  const r = await (await getPool()).request().query(`
    SELECT TOP 1 el.nif FROM dbo.Eleitor el
    JOIN dbo.Recenseamento r ON r.nif = el.nif
    JOIN dbo.Eleicao e ON e.nome = r.eleicao AND e.estado = 'Em Curso'
    WHERE el.ativo = 1
      AND NOT EXISTS (SELECT 1 FROM dbo.RegistoVoto rv JOIN dbo.Eleicao e2 ON e2.nome = rv.eleicao AND e2.estado = 'Em Curso'
                      WHERE rv.nif = el.nif)
      AND NOT EXISTS (SELECT 1 FROM dbo.Candidato c WHERE c.nif = el.nif)
    ORDER BY NEWID()`);   // aleatório: não esgota o limite de pedidos de código de um único NIF
  if (!r.recordset.length) return res.status(404).json({ erro: 'Sem eleitores de teste disponíveis.' });
  res.json({ nif: r.recordset[0].nif });
}));

// ---- autenticação da administração: email + palavra-passe -------------------
const falhas = new Map(); // email -> {n, ate}
const MAX_FALHAS = 5, BLOQUEIO_MS = 10 * 60 * 1000;
const HASH_FALSO = bcrypt.hashSync(crypto.randomBytes(8).toString('hex'), 10);

app.post('/api/auth/admin', wrap(async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase().slice(0, 120);
  const password = String(req.body.password || '');
  const f = falhas.get(email);
  if (f && f.n >= MAX_FALHAS && f.ate > Date.now()) {
    return res.status(429).json({ erro: 'Demasiadas tentativas falhadas. Tente novamente dentro de alguns minutos.' });
  }
  const pool = await getPool();
  const r = await pool.request().input('e', sql.NVarChar(120), email)
    .query('SELECT id_admin, nome, password_hash, ativo FROM dbo.Administrador WHERE email = @e');
  const a = r.recordset[0];
  // compara sempre o hash (mesmo sem utilizador) para não revelar se o email existe
  const ok = await bcrypt.compare(password, a ? a.password_hash : HASH_FALSO);
  const log = (sucesso, motivo) => pool.request()
    .input('i', sql.NVarChar(120), email).input('s', sql.Bit, sucesso).input('m', sql.NVarChar(255), motivo)
    .query("INSERT dbo.LogAutenticacao (nif_tentativa, sucesso, motivo_falha, etapa) VALUES (@i, @s, @m, 'Admin')");
  if (!a || !ok || !a.ativo) {
    const n = (f && f.ate > Date.now() ? f.n : 0) + 1;
    falhas.set(email, { n, ate: Date.now() + BLOQUEIO_MS });
    await log(0, 'Credenciais inválidas ou conta inativa');
    return res.status(401).json({ erro: 'Email ou palavra-passe incorretos.' });
  }
  falhas.delete(email);
  await log(1, null);
  req.session.regenerate((err) => {
    if (err) return res.status(500).json({ erro: 'Erro ao iniciar sessão.' });
    req.session.user = { perfil: 'ADMIN', id: a.id_admin, nome: a.nome };
    res.json({ perfil: 'ADMIN', nome: a.nome, destino: '/admin.html' });
  });
}));

app.post('/api/logout', (req, res) => req.session.destroy(() => res.json({ ok: true })));

app.get('/api/me', (req, res) => {
  if (!req.session.user) return res.status(401).json({ erro: 'Não autenticado.' });
  res.json(req.session.user);
});

// ---- rotas por perfil -----------------------------------------------------
app.use('/api/eleitor', requireRole('ELEITOR'), require('./routes/eleitor'));
app.use('/api/admin', requireRole('ADMIN'), require('./routes/admin'));

app.use('/api', (req, res) => res.status(404).json({ erro: 'Recurso não encontrado.' }));
app.use(errorHandler);

// abre/encerra as eleições automaticamente conforme o calendário
async function atualizarEstados() {
  try { await (await getPool()).request().execute('dbo.sp_AtualizarEstadosEleicoes'); }
  catch (e) { console.error('Atualização de estados falhou:', e.message); }
}
setInterval(atualizarEstados, 30 * 1000);

getPool()
  .then(() => atualizarEstados())
  .then(() => app.listen(PORT, () => console.log(`eVoto a correr em http://localhost:${PORT} (código de acesso: modo "${OTP_MODO}")`)))
  .catch((e) => { console.error('Não foi possível ligar ao SQL Server:', e.message); process.exit(1); });
