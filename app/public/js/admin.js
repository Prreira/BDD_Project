/* Administração eVoto: painel de acompanhamento e manutenção */
const $ = (id) => document.getElementById(id);
const charts = {};
let timer = null;
let eleicoesCache = [], eleitoresCache = [], atual = null;

/* ---------------------------- navegação ---------------------------------- */
const SECOES = [['dash', 'Painel'], ['eleicoes', 'Eleições'], ['eleitores', 'Eleitores'], ['autenticacoes', 'Autenticações'], ['auditoria', 'Auditoria']];
function irPara(v) {
  SECOES.forEach(([s]) => $(s).classList.toggle('hidden', s !== v));
  document.querySelectorAll('#nav button').forEach((b) => b.classList.toggle('active', b.dataset.v === v));
  window.scrollTo(0, 0);
  clearInterval(timer);
  if (v === 'dash') { carregarDashboard(); timer = setInterval(carregarDashboard, 15000); }
  if (v === 'eleicoes') carregarEleicoes();
  if (v === 'eleitores') carregarEleitores();
  if (v === 'autenticacoes') carregarAutenticacoes();
  if (v === 'auditoria') carregarAuditoria();
}

/* ---------------------------- gráficos ----------------------------------- */
const CORES = ['#1769e0', '#15945a', '#e0861a', '#8a3ffc', '#d64545', '#0b9db5', '#68748a'];
function desenhar(id, tipo, labels, datasets, opcoes = {}) {
  if (charts[id]) charts[id].destroy();
  charts[id] = new Chart($(id), {
    type: tipo, data: { labels, datasets },
    options: Object.assign({ responsive: true, maintainAspectRatio: false, animation: false,
      plugins: { legend: { display: tipo === 'doughnut' || datasets.length > 1 } } }, opcoes),
  });
}

/* ---------------------------- painel ------------------------------------- */
async function carregarDashboard() {
  try {
    const d = await api('/api/admin/dashboard');
    const k = d.kpi;
    $('kpis').innerHTML = [['Eleitores ativos', k.eleitores_ativos], ['Eleições', k.eleicoes],
      ['Eleições em curso', k.em_curso], ['Votos registados', k.votos_registados]]
      .map(([l, v]) => `<div class="card stat"><div class="label">${esc(l)}</div><div class="value">${esc(v)}</div></div>`).join('');

    desenhar('chGeral', 'bar', d.participacao.map((p) => p.eleicao.slice(0, 30)), [
      { label: 'Votaram', data: d.participacao.map((p) => p.votantes), backgroundColor: '#1769e0' },
      { label: 'Abstenção', data: d.participacao.map((p) => p.abstencao), backgroundColor: '#d8deea' }],
      { scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true, ticks: { precision: 0 } } } });

    $('tAtividade').innerHTML = '<tr><th>Quando</th><th>Autor</th><th>Ação</th></tr>' +
      d.atividade.map((a) => `<tr><td class="small">${esc(fmtData(a.data_hora))}</td><td class="small">${esc(a.autor || '-')}</td><td class="small">${esc(a.acao)}</td></tr>`).join('');

    const sel = $('selResultados'), ant = sel.value;
    sel.innerHTML = d.participacao.map((p, i) => `<option value="${i}">${esc(p.eleicao)} (${esc(p.estado)})</option>`).join('');
    window.__part = d.participacao;
    const idx = ant !== '' && sel.options[ant] ? Number(ant)
      : Math.max(0, d.participacao.findIndex((p) => p.estado === 'Em Curso'));
    if (d.participacao.length) { sel.value = String(idx); await carregarResultados(d.participacao[idx].eleicao); }
  } catch (e) { toast(e.message, 'err'); }
}
$('selResultados').addEventListener('change', (e) => carregarResultados(window.__part[Number(e.target.value)].eleicao));

async function carregarResultados(nome) {
  const r = await api(`/api/admin/eleicoes/${enc(nome)}/resultados`);
  desenhar('chResultados', 'bar', r.resultados.map((c) => c.opcao),
    [{ label: 'Votos', data: r.resultados.map((c) => c.votos), backgroundColor: CORES }],
    { indexAxis: 'y', scales: { x: { beginAtZero: true, ticks: { precision: 0 } } } });
  const p = r.participacao;
  desenhar('chParticipacao', 'doughnut', ['Votaram', 'Abstenção'],
    [{ data: [p.votantes, p.abstencao], backgroundColor: ['#1769e0', '#d8deea'] }]);
  const af = r.afluencia.slice(-48);   // últimas 48 horas com votos
  desenhar('chAfluencia', 'bar', af.map((a) => { const d = new Date(a.dia); return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')} ${String(a.hora).padStart(2, '0')}h`; }),
    [{ label: 'Votos por hora', data: af.map((a) => a.votantes), backgroundColor: '#15945a' }],
    { scales: { y: { beginAtZero: true, ticks: { precision: 0 } }, x: { ticks: { maxRotation: 60, autoSkip: true } } } });
  $('resInfo').textContent = `Recenseados: ${p.inscritos} | Votantes: ${p.votantes} (${p.taxa_participacao ?? 0}%) | Brancos: ${p.votos_brancos} | Nulos: ${p.votos_nulos}.`;
}

/* ---------------------------- modal -------------------------------------- */
function abrirModal(html) { $('modal').innerHTML = html; $('modalBg').classList.remove('hidden'); }
function fecharModal() { $('modalBg').classList.add('hidden'); }
$('modalBg').addEventListener('mousedown', (e) => { if (e.target.id === 'modalBg') fecharModal(); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') fecharModal(); });
function erroModal(msg) { const m = $('mErro'); if (m) { m.textContent = msg; m.classList.remove('hidden'); } else toast(msg, 'err'); }

/* ---------------------------- eleições ----------------------------------- */
async function carregarEleicoes() {
  eleicoesCache = await api('/api/admin/eleicoes');
  $('tEleicoes').innerHTML =
    '<tr><th>Eleição</th><th>Escrutínio</th><th>Período</th><th>Estado</th><th>Cand.</th><th>Recens.</th><th>Votos</th><th></th></tr>' +
    eleicoesCache.map((e, i) => `<tr>
      <td><strong>${esc(e.nome)}</strong></td><td class="small">${esc(e.tipo_escrutinio)}</td>
      <td class="small">${esc(fmtData(e.data_inicio))}<br>${esc(fmtData(e.data_fim))}</td>
      <td>${badge(e.estado)}</td><td>${e.candidatos}</td><td>${e.recenseados}</td><td>${e.votos}</td>
      <td><button class="btn sm" onclick="gerirEleicao(${i})">Gerir</button></td></tr>`).join('');
}

function formEleicao(e, criar) {
  const v = e || { nome: '', descricao: '', tipo_escrutinio: 'Lista', data_inicio: new Date(Date.now() + 864e5), data_fim: new Date(Date.now() + 2 * 864e5) };
  const editavel = criar || (e && e.estado === 'Agendada');
  const dis = editavel ? '' : 'disabled';
  return `${criar ? `<label for="fNome">Nome da eleição</label><input id="fNome" maxlength="200" value="">` : ''}
    <label for="fDesc">Descrição</label><textarea id="fDesc" maxlength="500" rows="2">${esc(v.descricao || '')}</textarea>
    <div class="row"><div><label for="fTipo">Tipo de escrutínio</label><select id="fTipo" ${dis}>
      ${['Lista', 'Uninominal'].map((t) => `<option ${t === v.tipo_escrutinio ? 'selected' : ''}>${t}</option>`).join('')}</select></div>
    <div><label for="fIni">Início</label><input id="fIni" type="datetime-local" value="${paraInputData(v.data_inicio)}" ${dis}></div>
    <div><label for="fFim">Fim</label><input id="fFim" type="datetime-local" value="${paraInputData(v.data_fim)}" ${e && ['Encerrada', 'Apurada'].includes(e.estado) ? 'disabled' : ''}></div></div>`;
}
const lerForm = (criar) => ({
  nome: criar ? $('fNome').value : undefined, descricao: $('fDesc').value, tipo: $('fTipo').value,
  dataInicio: $('fIni').value, dataFim: $('fFim').value,
});

function novaEleicao() {
  abrirModal(`<div class="modal-head"><h2>Nova eleição</h2><button class="btn sec sm" onclick="fecharModal()">Fechar</button></div>
    ${formEleicao(null, true)}<div id="mErro" class="msg err hidden"></div>
    <button class="btn" style="margin-top:1rem" onclick="criarEleicao()">Criar eleição</button>`);
}
async function criarEleicao() {
  try {
    const r = await api('/api/admin/eleicoes', { method: 'POST', body: lerForm(true) });
    toast('Eleição criada. Adicione agora cargos, listas, candidatos e recenseamento.');
    await carregarEleicoes();
    gerirEleicao(eleicoesCache.findIndex((e) => e.nome === r.nome));
  } catch (e) { erroModal(e.message); }
}

const TRANSICOES = { 'Agendada': [['Em Curso', 'Iniciar votação']], 'Em Curso': [['Encerrada', 'Encerrar votação']], 'Encerrada': [['Apurada', 'Apurar resultados']], 'Apurada': [] };

async function recarregar() { await carregarEleicoes(); if (atual) await abrirGestao(atual); }
function gerirEleicao(i) { atual = eleicoesCache[i].nome; abrirGestao(atual); }

async function abrirGestao(nome) {
  try {
    const [d, eleitores] = await Promise.all([api(`/api/admin/eleicoes/${enc(nome)}`), api('/api/admin/eleitores?q=')]);
    eleitoresCache = eleitores;
    const e = d.eleicao, ed = e.estado === 'Agendada', lista = e.tipo_escrutinio === 'Lista';
    const optEleitores = eleitores.filter((x) => x.ativo).map((x) => `<option value="${esc(x.nif)}">${esc(x.nif)} - ${esc(x.nome)}</option>`).join('');
    const tr = TRANSICOES[e.estado].map(([s, l]) => `<button class="btn" data-est="${esc(s)}">${l}</button>`).join(' ');
    const apagar = ed ? `<button class="btn danger" id="btnApagar">Eliminar eleição</button>` : '';

    const cargos = d.cargos.map((c) => `<tr><td>${esc(c.cargo)}</td><td>${c.num_mandatos}</td>
      <td>${ed ? `<button class="btn danger sm" data-del="cargos/${enc(c.cargo)}">Remover</button>` : ''}</td></tr>`).join('');
    const listas = d.listas.map((l) => `<tr><td><strong>${esc(l.sigla)}</strong></td><td>${esc(l.designacao)}</td>
      <td>${ed ? `<button class="btn danger sm" data-del="listas/${enc(l.sigla)}">Remover</button>` : ''}</td></tr>`).join('');
    const cands = d.candidatos.map((c) => `<tr><td>${esc(c.nif)}</td><td>${esc(c.nome)}</td><td>${esc(c.cargo)}</td>
      <td>${esc(c.sigla_lista || '-')}${c.posicao ? ` (#${c.posicao})` : ''}</td>
      <td>${ed ? `<button class="btn danger sm" data-del="candidatos/${enc(c.nif)}">Remover</button>` : ''}</td></tr>`).join('');

    abrirModal(`
      <div class="modal-head"><div><h2>${esc(e.nome)}</h2>${badge(e.estado)} <span class="muted small">Escrutínio ${esc(e.tipo_escrutinio)}</span></div>
        <button class="btn sec sm" onclick="fecharModal()">Fechar</button></div>
      <div id="mErro" class="msg err hidden" role="alert"></div>
      <div style="display:flex;gap:.6rem;flex-wrap:wrap;margin:.8rem 0">${tr} ${apagar}</div>
      ${ed ? '' : '<p class="msg info">A estrutura da eleição (cargos, listas, candidatos e recenseamento) está bloqueada porque a eleição já não está agendada.</p>'}

      <h3 class="sec-t">Dados gerais</h3>${formEleicao(e, false)}
      <button class="btn sec" style="margin-top:.8rem" id="btnGuardar">Guardar alterações</button>

      <h3 class="sec-t">Cargos em disputa</h3>
      <div class="table-wrap"><table><tr><th>Cargo</th><th>Mandatos</th><th></th></tr>${cargos || '<tr><td colspan="3" class="muted">Sem cargos.</td></tr>'}</table></div>
      ${ed ? `<div class="row" style="margin-top:.6rem"><div><label for="cgNome">Cargo</label><input id="cgNome" maxlength="100"></div>
        <div><label for="cgMand">Nº de mandatos</label><input id="cgMand" type="number" min="1" value="1"></div><button class="btn" id="btnCargo">Adicionar cargo</button></div>` : ''}

      ${lista ? `<h3 class="sec-t">Listas</h3>
      <div class="table-wrap"><table><tr><th>Sigla</th><th>Designação</th><th></th></tr>${listas || '<tr><td colspan="3" class="muted">Sem listas.</td></tr>'}</table></div>
      ${ed ? `<div class="row" style="margin-top:.6rem"><div><label for="lsSigla">Sigla</label><input id="lsSigla" maxlength="15"></div>
        <div><label for="lsDes">Designação</label><input id="lsDes" maxlength="150"></div><button class="btn" id="btnLista">Adicionar lista</button></div>` : ''}` : ''}

      <h3 class="sec-t">Candidatos</h3>
      <div class="table-wrap"><table><tr><th>NIF</th><th>Nome</th><th>Cargo</th><th>Lista</th><th></th></tr>${cands || '<tr><td colspan="5" class="muted">Sem candidatos.</td></tr>'}</table></div>
      ${ed ? `<div class="row" style="margin-top:.6rem"><div><label for="cdNif">Eleitor</label><select id="cdNif">${optEleitores}</select></div>
        <div><label for="cdCargo">Cargo</label><select id="cdCargo">${d.cargos.map((c) => `<option>${esc(c.cargo)}</option>`).join('')}</select></div>
        ${lista ? `<div><label for="cdLista">Lista</label><select id="cdLista">${d.listas.map((l) => `<option>${esc(l.sigla)}</option>`).join('')}</select></div>
        <div><label for="cdPos">Posição</label><input id="cdPos" type="number" min="1" value="1"></div>` : ''}
        <button class="btn" id="btnCand">Adicionar candidato</button></div>` : ''}

      <h3 class="sec-t">Recenseamento <span class="muted small">(${d.recenseados} eleitores)</span></h3>
      ${ed ? `<p class="small muted">Recenseia todos os eleitores ativos que ainda não estejam inscritos nesta eleição.</p>
        <button class="btn" id="btnRec">Recensear eleitores ativos</button> <button class="btn danger" id="btnLimpar">Limpar recenseamento</button>`
        : '<p class="muted small">Recenseamento bloqueado.</p>'}`);

    ligarGestao(nome, d);
  } catch (e) { toast(e.message, 'err'); }
}

async function acao(fn, okMsg) {
  try { const r = await fn(); if (okMsg) toast(typeof okMsg === 'function' ? okMsg(r) : okMsg); await recarregar(); }
  catch (e) { erroModal(e.message); }
}

function ligarGestao(nome, d) {
  const base = `/api/admin/eleicoes/${enc(nome)}`;
  const on = (id, fn) => { const el = $(id); if (el) el.onclick = fn; };
  document.querySelectorAll('#modal [data-est]').forEach((b) => b.onclick = () => {
    const est = b.dataset.est;
    const msg = { 'Em Curso': 'Iniciar a votação agora?', 'Encerrada': 'Encerrar a votação? Já não será possível votar.', 'Apurada': 'Apurar a eleição? Esta ação é definitiva.' }[est];
    if (confirm(msg)) acao(() => api(`${base}/estado`, { method: 'POST', body: { estado: est } }), `Estado alterado para ${est}.`);
  });
  document.querySelectorAll('#modal [data-del]').forEach((b) => b.onclick = () => {
    if (confirm('Remover este elemento?')) acao(() => api(`${base}/${b.dataset.del}`, { method: 'DELETE' }), 'Removido.');
  });
  on('btnGuardar', () => acao(() => api(base, { method: 'PUT', body: lerForm(false) }), 'Eleição atualizada.'));
  on('btnApagar', () => { if (confirm('Eliminar esta eleição? Não pode ser desfeito.')) acao(async () => { await api(base, { method: 'DELETE' }); atual = null; fecharModal(); }, 'Eleição eliminada.'); });
  on('btnCargo', () => acao(() => api(`${base}/cargos`, { method: 'POST', body: { cargo: $('cgNome').value, numMandatos: $('cgMand').value } }), 'Cargo adicionado.'));
  on('btnLista', () => acao(() => api(`${base}/listas`, { method: 'POST', body: { sigla: $('lsSigla').value, designacao: $('lsDes').value } }), 'Lista adicionada.'));
  on('btnCand', () => acao(() => api(`${base}/candidatos`, { method: 'POST', body: {
    nif: $('cdNif').value, cargo: $('cdCargo').value, sigla: $('cdLista') ? $('cdLista').value : null, posicao: $('cdPos') ? $('cdPos').value : null } }), 'Candidato adicionado.'));
  on('btnRec', () => acao(() => api(`${base}/recenseamento`, { method: 'POST', body: {} }), (r) => `${r.recenseados} eleitores recenseados.`));
  on('btnLimpar', () => { if (confirm('Remover todos os eleitores do recenseamento?')) acao(() => api(`${base}/recenseamento`, { method: 'DELETE' }), 'Recenseamento limpo.'); });
}

/* ---------------------------- eleitores ---------------------------------- */
async function carregarEleitores() {
  eleitoresCache = await api(`/api/admin/eleitores?q=${enc($('pesq').value)}`);
  $('tEleitores').innerHTML = '<tr><th>NIF</th><th>Nome</th><th>Nascimento</th><th>Estado</th><th></th></tr>' +
    eleitoresCache.map((e, i) => `<tr><td>${esc(e.nif)}</td><td>${esc(e.nome)}</td><td>${esc(fmtDia(e.data_nascimento))}</td>
      <td>${e.ativo ? '<span class="badge b-ok">Ativo</span>' : '<span class="badge b-no">Inativo</span>'}</td>
      <td><button class="btn sec sm" onclick="editarEleitor(${i})">Editar</button></td></tr>`).join('');
}
let pesqTimer;
$('pesq').addEventListener('input', () => { clearTimeout(pesqTimer); pesqTimer = setTimeout(carregarEleitores, 300); });

function novoEleitor() {
  abrirModal(`<div class="modal-head"><h2>Novo eleitor</h2><button class="btn sec sm" onclick="fecharModal()">Fechar</button></div>
    <div class="row"><div><label for="eNif">NIF (9 dígitos)</label><input id="eNif" maxlength="9" inputmode="numeric"></div>
      <div><label for="eNome">Nome</label><input id="eNome" maxlength="150"></div>
      <div><label for="eNasc">Data de nascimento</label><input id="eNasc" type="date"></div></div>
    <p class="hint-t">O eleitor não tem palavra-passe: entra com o NIF e um código de uso único gerado pelo sistema.</p>
    <div id="mErro" class="msg err hidden"></div>
    <button class="btn" style="margin-top:1rem" onclick="criarEleitor()">Criar eleitor</button>`);
}
async function criarEleitor() {
  try {
    await api('/api/admin/eleitores', { method: 'POST', body: { nif: $('eNif').value, nome: $('eNome').value, dataNascimento: $('eNasc').value } });
    fecharModal(); toast('Eleitor criado.'); carregarEleitores();
  } catch (e) { erroModal(e.message); }
}
function editarEleitor(i) {
  const e = eleitoresCache[i];
  abrirModal(`<div class="modal-head"><h2>Editar eleitor</h2><button class="btn sec sm" onclick="fecharModal()">Fechar</button></div>
    <p class="muted small">NIF ${esc(e.nif)}</p>
    <label for="eNome">Nome</label><input id="eNome" value="${esc(e.nome)}" maxlength="150">
    <label><input type="checkbox" id="eAtivo" style="width:auto" ${e.ativo ? 'checked' : ''}> Conta ativa (pode autenticar-se e votar)</label>
    <div id="mErro" class="msg err hidden"></div>
    <button class="btn" style="margin-top:1rem" onclick="guardarEleitor('${esc(e.nif)}')">Guardar</button>`);
}
async function guardarEleitor(nif) {
  try {
    await api(`/api/admin/eleitores/${enc(nif)}`, { method: 'PUT', body: { nome: $('eNome').value, ativo: $('eAtivo').checked } });
    fecharModal(); toast('Eleitor atualizado.'); carregarEleitores();
  } catch (e) { erroModal(e.message); }
}

/* ------------------- autenticações e auditoria --------------------------- */
async function carregarAutenticacoes() {
  const l = await api('/api/admin/autenticacoes');
  $('tAutenticacoes').innerHTML = '<tr><th>Data/hora</th><th>Identificador</th><th>Etapa</th><th>Resultado</th><th>Motivo</th></tr>' +
    l.map((a) => `<tr><td class="small">${esc(fmtData(a.data_hora))}</td><td>${esc(a.nif_tentativa)}</td><td class="small">${esc(a.etapa)}</td>
      <td>${a.sucesso ? '<span class="badge b-ok">Sucesso</span>' : '<span class="badge b-no">Falha</span>'}</td><td class="small">${esc(a.motivo_falha || '')}</td></tr>`).join('');
}
async function carregarAuditoria() {
  const l = await api('/api/admin/auditoria');
  $('tAuditoria').innerHTML = '<tr><th>Data/hora</th><th>Autor</th><th>Ação</th><th>Entidade</th><th>Detalhe</th></tr>' +
    l.map((a) => `<tr><td class="small">${esc(fmtData(a.data_hora))}</td><td class="small">${esc(a.autor || '-')}</td><td>${esc(a.acao)}</td>
      <td class="small">${esc(a.entidade)}</td><td class="small">${esc(a.detalhe || '')}</td></tr>`).join('');
}

/* ---------------------------- arranque ----------------------------------- */
(async () => {
  try {
    const me = await api('/api/me');
    cabecalho({ perfil: 'ADMIN', nome: me.nome });
    $('nav').innerHTML = SECOES.map(([v, t]) => `<button data-v="${v}">${t}</button>`).join('');
    rodape();
    $('nav').addEventListener('click', (e) => { if (e.target.dataset.v) irPara(e.target.dataset.v); });
    irPara('dash');
  } catch (e) { toast(e.message, 'err'); }
})();
