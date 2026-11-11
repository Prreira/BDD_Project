// Funções comuns às páginas
async function api(url, opts = {}) {
  const init = { method: opts.method || 'GET', headers: {}, credentials: 'same-origin' };
  if (opts.body !== undefined) { init.headers['Content-Type'] = 'application/json'; init.body = JSON.stringify(opts.body); }
  const r = await fetch(url, init);
  let dados = null;
  try { dados = await r.json(); } catch (_) { /* sem corpo */ }
  if (r.status === 401 && !url.startsWith('/api/auth/')) { location.href = '/'; throw new Error('Sessão expirada.'); }
  if (!r.ok) throw new Error((dados && dados.erro) || 'Erro inesperado.');
  return dados;
}

// escapa texto vindo da BD antes de o inserir em HTML (previne XSS)
function esc(v) {
  return String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
const enc = encodeURIComponent;
const fmtData = (v) => v ? new Date(v).toLocaleString('pt-PT', { dateStyle: 'short', timeStyle: 'short' }) : '-';
const fmtDia = (v) => v ? new Date(v).toLocaleDateString('pt-PT') : '-';
// valor para <input type="datetime-local"> em hora local
function paraInputData(v) {
  const d = new Date(v); const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}
const badge = (estado) => `<span class="badge b-${esc(String(estado).replace(/\s+/g, '-'))}">${esc(estado)}</span>`;

let toastTimer;
function toast(msg, tipo = 'ok') {
  let t = document.getElementById('toast');
  if (!t) { t = document.createElement('div'); t.id = 'toast'; t.setAttribute('role', 'status'); document.body.appendChild(t); }
  t.className = `toast ${tipo}`; t.textContent = msg;
  clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.add('hidden'), 5000);
}

async function sair() { try { await api('/api/logout', { method: 'POST' }); } finally { location.href = '/'; } }

/* ---- barra superior (igual à do exemplo eVoto/) ---- */
function cabecalho({ perfil, nome } = {}) {
  const el = document.getElementById('cabecalho');
  if (!el) return;
  const inicial = nome ? esc(nome.trim().charAt(0).toUpperCase()) : '';
  el.innerHTML = `
    <a class="skip" href="#conteudo">Saltar para o conteúdo</a>
    <header class="topbar">
      <a class="brand" href="/" aria-label="eVoto - página inicial"><img class="logo" src="/img/logo-192.png" alt=""> eVoto</a>
      ${nome ? `<div class="top-actions">
        <span class="role-pill">${perfil === 'ADMIN' ? 'Administração' : 'Eleitor'}</span>
        <span class="who-name">${esc(nome)}</span><span class="avatar" aria-hidden="true">${inicial}</span>
        <button class="btn sec sm" onclick="sair()">Terminar sessão</button></div>` : ''}
    </header>`;
}

function rodape() {
  const el = document.getElementById('rodape');
  if (el) el.innerHTML = `<div class="page-foot">eVoto · O seu voto é secreto, pessoal e intransmissível · Projeto académico de Bases de Dados · © ${new Date().getFullYear()}</div>`;
}
