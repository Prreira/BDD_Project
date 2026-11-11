let boletim = null;      // boletim aberto: {eleicao, listas | cargos}
let escolhas = {};       // grupo (lista ou cargo) -> {tipo, sigla|indice, texto}
let eleicoes = [];       // eleições do eleitor
let filtro = 'Todas';
const $ = (id) => document.getElementById(id);

const FILTROS = [['Todas', 'Todas as eleições'], ['Em Curso', 'Em curso'], ['Agendada', 'Agendadas'], ['Apurada', 'Apuradas']];
const vistas = ['vistaLista', 'vistaVoto', 'vistaRes'];
function mostrarVista(id) { vistas.forEach((v) => $(v).classList.toggle('hidden', v !== id)); window.scrollTo(0, 0); }
function mostrarPasso(n) {
  [1, 2, 3].forEach((i) => {
    $('passo' + i).classList.toggle('hidden', i !== n);
    $('p' + i).className = i < n ? 'done' : i === n ? 'on' : '';
  });
}

async function iniciar() {
  const me = await api('/api/me');
  cabecalho({ perfil: 'ELEITOR', nome: me.nome });
  rodape();
  $('saudacao').textContent = `Olá, ${me.nome.split(' ')[0]}`;
  $('nav').addEventListener('click', (e) => {
    if (e.target.dataset.f) { filtro = e.target.dataset.f; desenharLista(); voltarVista(); }
  });
  await carregarLista();
}
function voltarVista() { mostrarVista('vistaLista'); }

async function carregarLista() {
  mostrarVista('vistaLista');
  try { eleicoes = await api('/api/eleitor/eleicoes'); desenharLista(); }
  catch (e) { $('lista').innerHTML = `<div class="msg err">${esc(e.message)}</div>`; }
}

function desenharLista() {
  $('nav').innerHTML = FILTROS.map(([f, t]) => {
    const n = f === 'Todas' ? eleicoes.length : eleicoes.filter((e) => e.estado === f).length;
    return `<button data-f="${f}" class="${f === filtro ? 'active' : ''}">${t}<span class="count">${n}</span></button>`;
  }).join('');
  $('tituloLista').textContent = FILTROS.find((x) => x[0] === filtro)[1];
  const visiveis = eleicoes.map((e, i) => ({ e, i })).filter((x) => filtro === 'Todas' || x.e.estado === filtro);
  if (!visiveis.length) { $('lista').innerHTML = '<div class="card empty">Não existem eleições nesta categoria.</div>'; return; }
  $('lista').innerHTML = visiveis.map(({ e, i }) => {
    let acao = '';
    if (e.estado === 'Em Curso' && !e.ja_votou) acao = `<button class="btn" onclick="abrirBoletim(${i})">Votar agora</button>`;
    else if (e.ja_votou) acao = `<span class="badge b-ok">&#10004; Votou em ${esc(fmtData(e.data_voto))}</span>`;
    else if (e.estado === 'Agendada') acao = `<span class="muted small">Abre em ${esc(fmtData(e.data_inicio))}</span>`;
    const res = e.estado === 'Apurada' ? `<button class="btn sec sm" onclick="verResultados(${i})">Ver resultados</button>` : '';
    return `<article class="card">
      <div style="display:flex;justify-content:space-between;gap:.6rem">${badge(e.estado)}<span class="muted small">Escrutínio ${esc(e.tipo_escrutinio.toLowerCase())}</span></div>
      <h3 style="margin-top:12px">${esc(e.nome)}</h3>
      <p class="muted small">${esc(e.descricao || '')}</p>
      <p class="small"><strong>Período:</strong> ${esc(fmtData(e.data_inicio))} &rarr; ${esc(fmtData(e.data_fim))}</p>
      <div style="display:flex;gap:.6rem;flex-wrap:wrap;align-items:center">${acao} ${res}</div>
    </article>`;
  }).join('');
}

/* ---- boletim ---- */
function opcao(grupo, valor, simbolo, titulo, sub, extra) {
  return `<label class="candidate" data-grupo="${esc(grupo)}" ${extra}><span class="symbol">${esc(simbolo)}</span>
    <div><div class="nome">${esc(titulo)}</div>${sub ? `<div class="part">${esc(sub)}</div>` : ''}</div>
    <input type="radio" name="g_${esc(grupo)}" value="${esc(valor)}"></label>`;
}
const brancoNulo = (g) => opcao(g, 'B', '○', 'Voto em branco', '', 'data-tipo="Branco" data-texto="Voto em branco"') +
                          opcao(g, 'N', '✕', 'Voto nulo', '', 'data-tipo="Nulo" data-texto="Voto nulo"');

async function abrirBoletim(i) {
  try {
    boletim = await api(`/api/eleitor/boletim?eleicao=${enc(eleicoes[i].nome)}`);
    escolhas = {};
    $('bTitulo').textContent = boletim.eleicao.nome;
    $('bDesc').textContent = boletim.eleicao.descricao || '';
    let html = '';
    if (boletim.listas) {
      html += '<div class="group-title">Escolha uma lista</div>';
      html += boletim.listas.map((l) => opcao('lista', `L:${l.sigla}`, l.sigla, l.designacao,
        l.candidatos.slice(0, 3).join(' · ') + (l.candidatos.length > 3 ? ' …' : ''),
        `data-tipo="Valido" data-sigla="${esc(l.sigla)}" data-texto="${esc(l.sigla + ' - ' + l.designacao)}"`)).join('');
      html += brancoNulo('lista');
    } else {
      html += boletim.cargos.map((c) => `<div class="group-title">${esc(c.cargo)}</div>` +
        c.candidatos.map((k) => opcao(c.cargo, `C:${k.indice}`, k.nome.charAt(0), k.nome, '',
          `data-tipo="Valido" data-indice="${k.indice}" data-texto="${esc(k.nome)}"`)).join('') + brancoNulo(c.cargo)).join('');
    }
    $('boletim').innerHTML = html;
    $('erroVoto').classList.add('hidden');
    $('btnContinuar').disabled = true;
    mostrarPasso(1); mostrarVista('vistaVoto');
  } catch (e) { toast(e.message, 'err'); carregarLista(); }
}

const totalGrupos = () => (boletim.listas ? 1 : boletim.cargos.length);

$('boletim').addEventListener('change', (ev) => {
  const opt = ev.target.closest('.candidate');
  if (!opt) return;
  const grupo = opt.dataset.grupo;
  document.querySelectorAll(`.candidate[data-grupo="${CSS.escape(grupo)}"]`).forEach((o) => o.classList.remove('selected'));
  opt.classList.add('selected');
  escolhas[grupo] = { tipo: opt.dataset.tipo, sigla: opt.dataset.sigla, indice: opt.dataset.indice, texto: opt.dataset.texto };
  $('btnContinuar').disabled = Object.keys(escolhas).length < totalGrupos();
});

$('btnContinuar').addEventListener('click', () => {
  $('resumo').innerHTML = Object.entries(escolhas).map(([g, c]) =>
    `<p style="margin:.3rem 0">${boletim.listas ? '' : `<strong>${esc(g)}:</strong> `}${esc(c.texto)}</p>`).join('');
  $('erroConf').classList.add('hidden');
  mostrarPasso(2);
});

$('btnConfirmar').addEventListener('click', async () => {
  const btn = $('btnConfirmar'), erro = $('erroConf');
  btn.disabled = true; erro.classList.add('hidden');
  const lista = Object.entries(escolhas).map(([g, c]) => boletim.listas
    ? { tipo: c.tipo, sigla: c.sigla }
    : { cargo: g, tipo: c.tipo, indice: c.indice === undefined ? undefined : Number(c.indice) });
  try {
    const r = await api('/api/eleitor/votar', { method: 'POST', body: { eleicao: boletim.eleicao.nome, escolhas: lista } });
    $('comprov').textContent = fmtData(r.dataHora);
    $('refer').textContent = r.referencia;
    escolhas = {}; mostrarPasso(3);
  } catch (e) { erro.textContent = e.message; erro.classList.remove('hidden'); }
  finally { btn.disabled = false; }
});

/* ---- resultados ---- */
async function verResultados(i) {
  const e = eleicoes[i];
  try {
    const r = await api(`/api/eleitor/resultados?eleicao=${enc(e.nome)}`);
    $('rTitulo').textContent = e.nome;
    const p = r.participacao;
    $('rPart').textContent = `Participação: ${p.votantes} de ${p.inscritos} (${p.taxa_participacao}%). Votos em branco: ${p.votos_brancos}. Votos nulos: ${p.votos_nulos}.`;
    $('rLista').innerHTML = r.resultados.map((c) => `
      <div style="margin:18px 0">
        <div style="display:flex;justify-content:space-between;gap:1rem"><strong>${esc(c.opcao)}</strong>
          <span>${c.votos} votos &middot; ${c.percentagem ?? 0}%${r.tipo === 'Lista' ? ` &middot; <strong>${c.mandatos} mandato(s)</strong>` : ''}</span></div>
        <div class="small muted" style="margin-bottom:6px">${esc(c.detalhe || '')}</div>
        <div class="progress" role="img" aria-label="${esc(c.opcao)} ${c.percentagem ?? 0}%"><div style="width:${Number(c.percentagem) || 0}%"></div></div>
      </div>`).join('');
    mostrarVista('vistaRes');
  } catch (err) { toast(err.message, 'err'); }
}

function voltar() { carregarLista(); }
iniciar().catch((e) => toast(e.message, 'err'));
