
const $ = (id) => document.getElementById(id);
let nifAtual = '', fimCodigo = 0, relogio = null;

/* ---- separadores Eleitor / Administração ---- */
function escolher(tab) {
  const admin = tab === 'admin';
  $('tabEleitor').classList.toggle('active', !admin); $('tabEleitor').setAttribute('aria-selected', String(!admin));
  $('tabAdmin').classList.toggle('active', admin);   $('tabAdmin').setAttribute('aria-selected', String(admin));
  $('painelEleitor').classList.toggle('hidden', admin);
  $('painelAdmin').classList.toggle('hidden', !admin);
  fecharSms();
}
$('tabEleitor').onclick = () => escolher('eleitor');
$('tabAdmin').onclick = () => escolher('admin');

const soDigitos = (v) => v.replace(/\D/g, '');
const agrupar = (v, n) => soDigitos(v).slice(0, n).replace(/(\d{3})(?=\d)/g, '$1 ');
$('nif').addEventListener('input', (e) => { e.target.value = agrupar(e.target.value, 9); });
$('cod').addEventListener('input', (e) => { e.target.value = agrupar(e.target.value, 6); });

function erro(id, msg) { const e = $(id); e.textContent = msg; e.classList.remove('hidden'); }
function limparErros() { ['erroNif', 'erroCod', 'erroAdmin'].forEach((i) => $(i).classList.add('hidden')); }

/* ---- notificação com o código ---- */
function mostrarSms(texto, codigo) {
  $('smsTexto').textContent = 'O seu código de acesso eVoto é:';
  $('smsCod').textContent = `${codigo.slice(0, 3)} ${codigo.slice(3)}`;
  $('sms').classList.remove('hidden');
}
function fecharSms() { $('sms').classList.add('hidden'); }
$('fechaSms').onclick = fecharSms;

/* ---- passo 2: contagem decrescente ---- */
function iniciarRelogio(segundos) {
  clearInterval(relogio);
  fimCodigo = Date.now() + segundos * 1000;
  const tick = () => {
    const rest = Math.max(0, Math.round((fimCodigo - Date.now()) / 1000));
    $('tempo').textContent = `${Math.floor(rest / 60)}:${String(rest % 60).padStart(2, '0')}`;
    if (rest === 0) {
      clearInterval(relogio); fecharSms();
      erro('erroCod', 'O código expirou. Peça um novo código.');
      $('btnCod').disabled = true;
    }
  };
  tick(); relogio = setInterval(tick, 500);
}

function passo(n) {
  $('formNif').classList.toggle('hidden', n !== 1);
  $('formCod').classList.toggle('hidden', n !== 2);
  $('st1').className = n === 1 ? 'on' : 'done';
  $('st2').className = n === 2 ? 'on' : '';
  limparErros();
  if (n === 1) { clearInterval(relogio); fecharSms(); $('nif').focus(); }
}

async function pedirCodigo() {
  limparErros(); $('btnNif').disabled = true;
  try {
    const nif = soDigitos($('nif').value);
    if (nif.length !== 9) throw new Error('O NIF tem 9 dígitos.');
    const r = await api('/api/auth/codigo', { method: 'POST', body: { nif } });
    nifAtual = nif;
    $('nifMostra').textContent = agrupar(nif, 9);
    $('cod').value = ''; $('btnCod').disabled = false;
    passo(2); iniciarRelogio(r.validadeSegundos);
    if (r.codigo) {
      mostrarSms(r.mensagem, r.codigo);
      // preenchimento automático, como se a mensagem tivesse acabado de chegar
      setTimeout(() => { $('cod').value = agrupar(r.codigo, 6); $('btnCod').focus(); }, 1400);
    } else {
      $('cod').focus();
    }
  } catch (e) { erro('erroNif', e.message); }
  finally { $('btnNif').disabled = false; }
}

$('formNif').addEventListener('submit', (ev) => { ev.preventDefault(); pedirCodigo(); });
$('novoCodigo').onclick = (ev) => { ev.preventDefault(); $('nif').value = agrupar(nifAtual, 9); pedirCodigo(); };
$('voltarNif').onclick = (ev) => { ev.preventDefault(); passo(1); };

$('formCod').addEventListener('submit', async (ev) => {
  ev.preventDefault(); limparErros(); $('btnCod').disabled = true;
  try {
    const r = await api('/api/auth/verificar', { method: 'POST', body: { nif: nifAtual, codigo: soDigitos($('cod').value) } });
    location.href = r.destino;
  } catch (e) { erro('erroCod', e.message); $('btnCod').disabled = false; $('cod').select(); }
});

/* NIF de demonstração (só disponível em modo de demonstração) */
$('usarDemo').onclick = async (ev) => {
  ev.preventDefault();
  try { const r = await api('/api/auth/demo'); $('nif').value = agrupar(r.nif, 9); $('nif').focus(); }
  catch (e) { erro('erroNif', e.message); }
};

/* ---- administração ---- */
$('formAdmin').addEventListener('submit', async (ev) => {
  ev.preventDefault(); limparErros(); $('btnAdmin').disabled = true;
  try {
    const r = await api('/api/auth/admin', { method: 'POST', body: { email: $('email').value, password: $('password').value } });
    location.href = r.destino;
  } catch (e) { erro('erroAdmin', e.message); }
  finally { $('btnAdmin').disabled = false; }
});
