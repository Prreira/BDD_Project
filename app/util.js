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
  // erros do corpo do pedido (JSON malformado, demasiado grande): 4xx, não 500
  if (err.type === 'entity.parse.failed') return res.status(400).json({ erro: 'Pedido inválido (JSON malformado).' });
  if (err.type === 'entity.too.large') return res.status(413).json({ erro: 'Pedido demasiado grande.' });
  const n = err.number || (err.originalError && err.originalError.info && err.originalError.info.number);
  if (n >= 50000 && n < 51000) return res.status(409).json({ erro: err.message });
  if (n === 2627 || n === 2601) return res.status(409).json({ erro: 'Já existe um registo com esses dados.' });
  if (n === 547) return res.status(409).json({ erro: 'Operação inválida: algum dos dados indicados não existe (NIF, cargo ou lista), é inválido ou o registo está em utilização.' });
  if (n === 8152 || n === 2628) return res.status(400).json({ erro: 'Um dos campos excede o tamanho permitido.' });
  console.error(err);
  res.status(500).json({ erro: 'Erro interno do servidor.' });
}


// NIF português: 9 dígitos, começa por 1, 2 ou 3 (pessoa singular) e dígito de controlo módulo 11
function nifValido(nif) {
  if (!/^[123]\d{8}$/.test(String(nif))) return false;
  let soma = 0;
  for (let i = 0; i < 8; i++) soma += Number(nif[i]) * (9 - i);
  const resto = soma % 11;
  return (resto < 2 ? 0 : 11 - resto) === Number(nif[8]);
}

// os nomes de eleição vão em NVARCHAR(200): recusa pedidos maiores em vez de rebentar no driver
function limitarNome(req, res, next, valor) {
  if (!valor || valor.length > 200) return res.status(400).json({ erro: 'Nome de eleição inválido.' });
  next();
}

module.exports = { wrap, requireRole, requirePage, errorHandler, nifValido, limitarNome };
