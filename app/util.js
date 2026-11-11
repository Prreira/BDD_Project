// Utilitários partilhados pelas rotas

const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

function requireRole(perfil) {
  return (req, res, next) => {
    if (!req.session.user) return res.status(401).json({ erro: 'Sessão expirada. Inicie sessão novamente.' });
    if (req.session.user.perfil !== perfil) return res.status(403).json({ erro: 'Sem permissões para este recurso.' });
    next();
  };
}

// páginas HTML: redireciona para o login se não houver sessão com o perfil certo
function requirePage(perfil) {
  return (req, res, next) => {
    const u = req.session.user;
    if (!u || u.perfil !== perfil) return res.redirect('/');
    next();
  };
}

// Traduz erros do SQL Server em mensagens para o utilizador.
// 50000-50999 -> mensagens dos gatilhos/procedimentos (já em português)
function errorHandler(err, req, res, next) {
  const n = err.number || (err.originalError && err.originalError.info && err.originalError.info.number);
  if (n >= 50000 && n < 51000) return res.status(409).json({ erro: err.message });
  if (n === 2627 || n === 2601) return res.status(409).json({ erro: 'Já existe um registo com esses dados.' });
  if (n === 547) return res.status(409).json({ erro: 'Operação inválida: dados inconsistentes ou registo em utilização.' });
  if (n === 8152 || n === 2628) return res.status(400).json({ erro: 'Um dos campos excede o tamanho permitido.' });
  console.error(err);
  res.status(500).json({ erro: 'Erro interno do servidor.' });
}

function inteiro(v) {
  const n = Number(v);
  return Number.isInteger(n) && n > 0 ? n : null;
}

module.exports = { wrap, requireRole, requirePage, errorHandler, inteiro };
