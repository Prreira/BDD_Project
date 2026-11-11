# 🗳️ eVoto — Sistema de Votação Online

**Projeto de Desenvolvimento de uma Aplicação Web de Votação Online**

O **eVoto** é uma aplicação web para a realização e gestão de eleições simuladas. O eleitor entra com o **NIF** e um **código de uso único**; a administração entra com email e palavra-passe. Os dados estão em **Microsoft SQL Server**.

> 📌 **Nota:** a versão inicial deste README previa ASP.NET Core MVC com Entity Framework. A implementação final usa **Node.js + Express** sobre SQL Server, e o modelo de dados parte de um modelo prévio da equipa (`Dados2.sql`), adaptado para voto online (sem mesas de voto). Este documento descreve o que foi **efetivamente implementado**.

---

## 📋 Índice

1. [Descrição do Projeto](#-descrição-do-projeto)
2. [Objetivos](#-objetivos)
3. [Tecnologias Utilizadas](#-tecnologias-utilizadas)
4. [Instalação e Execução](#-instalação-e-execução)
5. [Arquitetura do Sistema](#-arquitetura-do-sistema)
6. [Funcionalidades](#-funcionalidades)
7. [Requisitos do Sistema](#-requisitos-do-sistema)
8. [Modelação UML](#-modelação-uml)
9. [Modelo da Base de Dados](#-modelo-da-base-de-dados)
10. [Regras de Integridade e Triggers](#-regras-de-integridade-e-triggers)
11. [Interrogações SQL](#-interrogações-sql)
12. [Interfaces Gráficas](#-interfaces-gráficas)
13. [Estrutura do Projeto](#-estrutura-do-projeto)
14. [Testes](#-testes)
15. [Estado do Desenvolvimento](#-estado-do-desenvolvimento)
16. [Critérios de Avaliação](#-critérios-de-avaliação)
17. [Documentação e Entregáveis](#-documentação-e-entregáveis)
18. [Considerações de Segurança e Limitações](#-considerações-de-segurança-e-limitações)

---

## 📖 Descrição do Projeto

A página inicial tem um *login* com dois acessos:

- **Eleitor** — identifica-se com o **NIF** (validado pelo dígito de controlo). O sistema **gera automaticamente** um código de 6 dígitos, de uso único e válido 3 minutos, e **mostra-o no próprio site** numa notificação (mensagem simulada), preenchendo o campo. Não são usados serviços externos (SMS/email). Depois de autenticado, o eleitor consulta as suas eleições, vota e recebe um comprovativo.
- **Administrador** — entra com email e palavra-passe e acede a dashboards em tempo real e à manutenção de eleições, listas, candidatos, recenseamento e eleitores.

Suporta eleições por **Lista** (mandatos distribuídos pelo método de Hondt) e **Uninominais** (um ou mais cargos).

## 🎯 Objetivos

- Aplicação web funcional para votação online com controlo de acessos.
- Impedir que um eleitor vote mais do que uma vez na mesma eleição (garantido pela própria base de dados).
- **Anonimato do voto:** participação e voto em tabelas sem qualquer ligação.
- Integridade e consistência através de constraints, **gatilhos**, vistas e procedimentos.
- Consultas SQL para estatísticas e resultados; dashboards de acompanhamento.
- Modelação UML e modelo relacional.

---

## 💻 Tecnologias Utilizadas

| Tecnologia | Utilização |
|---|---|
| Node.js 18+ / Express | Servidor e API |
| `mssql` (tedious) | Ligação ao SQL Server (queries parametrizadas e procedimentos) |
| `bcryptjs`, `express-session` | Palavras-passe de administradores e sessões |
| HTML5, CSS3, JavaScript | Interfaces (sem frameworks) |
| Chart.js | Gráficos do painel de administração |
| Microsoft SQL Server (2016 SP1+, Express serve) | Base de dados, gatilhos, vistas e procedimentos |
| PlantUML | Diagramas UML (`docs/uml`) |
| Git e GitHub | Controlo de versões |

---

## ⚙️ Instalação e Execução

Instruções completas em [`docs/00_Como_Executar.md`](docs/00_Como_Executar.md). Resumo, no PowerShell:

```powershell
cd app
npm install

$env:DB_SERVER   = "localhost"
$env:DB_INSTANCE = "SQLEXPRESS"        # instância nomeada (omitir se usar o porto 1433)
$env:DB_USER     = "sa"
$env:DB_PASSWORD = "a-sua-password"

npm run setup        # RECRIA a BD eVoto (tabelas, gatilhos, vistas, 300 eleitores, 6 eleições)
npm start            # http://localhost:3000
```

Atalhos na raiz do projeto: `.\iniciar.ps1` (arranca) e `.\preparar-apresentacao.ps1` (verifica requisitos, repõe os dados com datas atuais e arranca).

**Contas de demonstração**

| Perfil | Como entrar |
|---|---|
| Eleitor | separador *Sou eleitor* → "preencher NIF de teste" → *Pedir código* → o código aparece no ecrã e preenche-se sozinho |
| Administrador | `admin1@evoto.pt` / `Admin#2026` |

Executar os scripts SQL e mostrar os resultados no terminal (alternativa ao SSMS):

```powershell
npm run sql -- ..\db\06_testes_gatilhos.sql
npm run sql -- ..\db\05_consultas.sql
```

---

## 🏗️ Arquitetura do Sistema

```text
                    UTILIZADOR
                        |
              INTERFACE WEB (HTML/CSS/JS)
        login · área do eleitor · administração
                        |  fetch (JSON)
                EXPRESS (Node.js)
     sessões · perfis (403) · validação · limitação de pedidos
                        |  mssql (queries parametrizadas / EXEC)
                  MICROSOFT SQL SERVER
        ┌───────────────┼────────────────┬───────────────┐
      TABELAS        GATILHOS         VISTAS      PROCEDIMENTOS
   (Dados2 adaptado)  (G1–G10)    (dashboards)  (código, voto, apuramento)
```

A lógica crítica (um voto por eleitor, anonimato, estados, apuramento, código de acesso) está **na base de dados**; o servidor valida, autentica e traduz pedidos.

---

## 🔐 Funcionalidades

### Autenticação
- Eleitor: NIF + código de uso único (3 min, 3 tentativas, máx. 5 pedidos / 10 min, tudo registado).
- Administrador: email + palavra-passe (bcrypt), bloqueio após 5 falhas.
- Perfis separados e verificados no servidor; sessão com expiração aos 30 min.

### Área do eleitor
- Consultar eleições em que está recenseado (estado, período) com filtros.
- Votar: lista (ou candidato por cargo), voto em branco ou nulo; confirmação; comprovativo (hora + referência, sem o sentido do voto).
- Consultar resultados das eleições apuradas.

### Área de administração
- Painel em tempo real: indicadores, resultados por opção, participação, afluência ao longo do tempo (votos por hora).
- Gerir eleições, cargos, listas, candidatos e recenseamento.
- Iniciar, encerrar e **apurar** (Hondt nas listas); abertura/encerramento automático por calendário.
- Gerir eleitores (NIF); consultar auditoria e registo de autenticações.

### Estados de uma eleição
`Agendada → Em Curso → Encerrada → Apurada` (a estrutura só é editável enquanto Agendada).

---

## 📝 Requisitos do Sistema

Especificação completa (20 requisitos funcionais, 12 não funcionais, regras de negócio e matriz de rastreabilidade) em [`docs/01_Requisitos.md`](docs/01_Requisitos.md).

---

## 📐 Modelação UML

Descrição dos casos de uso em [`docs/02_Modelacao_UML_Requisitos.md`](docs/02_Modelacao_UML_Requisitos.md). Diagramas PlantUML em [`docs/uml`](docs/uml):

| Ficheiro | Diagrama |
|---|---|
| `01_casos_de_uso.puml` | Casos de uso |
| `02_atividade_votar.puml` | Atividades: autenticar e votar |
| `03_atividade_gerir_eleicao.puml` | Atividades: preparar e apurar uma eleição |
| `04_sequencia_votar.puml` | Sequência: autenticação e votação |
| `05_estados_eleicao.puml` | Estados da eleição |
| `06_diagrama_classes.puml` | Modelo conceptual (classes) |
| `07_modelo_relacional_er.puml` | Modelo relacional (ER) |

---

## 🗄️ Modelo da Base de Dados

Base de dados **`eVoto`**. Detalhe (alterações ao `Dados2.sql`, modelo relacional, normalização) em [`docs/03_Modelo_de_Dados.md`](docs/03_Modelo_de_Dados.md).

| Tabela | Função |
|---|---|
| `Eleicao`, `Cargo`, `Lista`, `Candidato` | Eleições, cargos (com mandatos), listas e candidatos |
| `Eleitor` (NIF), `Recenseamento` | Eleitores e quem pode votar em cada eleição |
| **`RegistoVoto`** | Prova **que** o eleitor votou — PK `(eleicao, nif)` impede o duplo voto |
| **`Voto`** | O voto, **sem ligação ao eleitor** (sem NIF, sem hora, GUID aleatório) |
| `ResultadoApuramento` | Votos e mandatos (Hondt) |
| `Administrador`, `CodigoAcesso`, `Auditoria` | Novas: login da administração, códigos de uso único (só hash), auditoria |
| `LogAutenticacao` | Todas as tentativas de autenticação |

Principais alterações ao modelo original: tabelas novas (`Administrador`, `CodigoAcesso`, `Auditoria`), `Eleitor.data_nascimento/ativo` e validação do NIF, `Cargo.num_mandatos`, e `Voto.id_voto` passou de `IDENTITY` a GUID para que a ordem dos votos não permita descobrir em quem cada pessoa votou.

---

## 🔒 Regras de Integridade e Triggers

Ficheiro [`db/02_gatilhos.sql`](db/02_gatilhos.sql) (testes em `db/06_testes_gatilhos.sql`):

| Id | Gatilho | Regra |
|---|---|---|
| G1 | `trg_RegistoVoto_Validar` | Eleição Em Curso e no prazo; eleitor ativo |
| G2 | `trg_RegistoVoto_Imutavel` | Registos de voto imutáveis |
| G3 | `trg_RegistoVoto_Auditoria` | Regista que alguém votou (nunca o sentido) |
| G4 | `trg_Voto_Validar` | Só em eleição Em Curso; destino conforme o escrutínio |
| G5 | `trg_Voto_Imutavel` | Votos imutáveis |
| G6 | `trg_*_Bloqueio` (4 tabelas) | Estrutura só muda com a eleição Agendada |
| G7 | `trg_Candidato_Coerencia` | Lista obrigatória (Lista) ou proibida (Uninominal) |
| G8 | `trg_Eleicao_Estado` | Transições válidas, requisitos para iniciar, dados congelados |
| G9 | `trg_Eleicao_Auditoria` | Auditoria com o autor |
| G10 | `trg_Eleitor_Idade` | Idade mínima 18 anos |

Asserções declarativas: `CK_Eleitor_Nif` (dígito de controlo), `CK_Voto_Destino`, FKs compostas; asserção global `vw_Integridade` (votos = votantes), exigida no apuramento.

**Procedimentos:** `sp_GerarCodigoAcesso`, `sp_ValidarCodigoAcesso`, `sp_RegistarVoto` (transacional, JSON de escolhas), `sp_AtualizarEstadosEleicoes`, `sp_ApurarEleicao` (integridade + Hondt). **Vistas:** `vw_ResultadosLista`, `vw_ResultadosCandidato`, `vw_ParticipacaoEleicao`, `vw_AfluenciaHoraria`, `vw_Integridade`.

---

## 📊 Interrogações SQL

[`db/05_consultas.sql`](db/05_consultas.sql) — 17 consultas, cada uma com enunciado e técnica:

| Nº | Objetivo | Técnica |
|---|---|---|
| C1 | Eleições em curso (cargos, candidatos, recenseados, votos) | subconsultas correlacionadas |
| C2 | Classificação e mandatos das listas | `RANK()` |
| C3 | Participação e abstenção por eleição | vista |
| C4 | Eleitores que ainda não votaram | `NOT EXISTS` |
| C5 | Votos por dia numa eleição | vista de afluência, GROUP BY |
| C6 | Listas acima da média | subconsulta correlacionada |
| C7 | Eleitores que votaram em todas as eleições encerradas | divisão relacional |
| C8 | Participação por escalão etário | CASE, agregação condicional |
| C9 | Vencedor por cargo das eleições apuradas | CTE + `ROW_NUMBER()` |
| C10 | Afluência por hora com acumulado | `SUM() OVER` |
| C11 | % de brancos e nulos | agregação condicional |
| C12 | Atividade na auditoria por autor | GROUP BY |
| C13 | Inativos ainda recenseados | JOIN múltiplo |
| C14 | Asserção de integridade (0 linhas) | vista |
| C15 | Ranking das eleições por abstenção | `DENSE_RANK()` |
| C16 | Autenticações falhadas nas últimas 24 h | JOIN, GROUP BY, HAVING, subconsulta |
| C17 | Composição de cada lista | JOIN de 3 tabelas |

Dados de demonstração (`db/04_dados_teste.sql` + `db/07_dados_adicionais.sql`): **300 eleitores** com NIF válido, **6 eleições** (2 em curso, 1 agendada, 3 apuradas) e cerca de 700 votos.

---

## 🎨 Interfaces Gráficas

Estilo baseado no exemplo da equipa (barra superior, menu lateral azul-escuro, banner, cartões), responsivo.

1. **Entrada** — duas colunas; separadores *Sou eleitor* / *Administração*; passo 1 (NIF) e passo 2 (código com contagem decrescente e **notificação com o código**).
2. **Área do eleitor** — banner de boas-vindas, filtros por estado, cartões de eleições.
3. **Boletim de voto** — cartões de listas/candidatos, branco e nulo; confirmação; comprovativo.
4. **Resultados** (eleição apurada) — votos, percentagens e mandatos.
5. **Painel de administração** — indicadores e gráficos em tempo real.
6. **Gestão de eleições** — janela com dados, cargos, listas, candidatos, recenseamento e estado.
7. **Eleitores**, **Autenticações** e **Auditoria**.

---

## 📁 Estrutura do Projeto

```text
BDD_Project/
├─ README.md
├─ iniciar.ps1                       Arranca a aplicação
├─ preparar-apresentacao.ps1         Verifica requisitos, repõe dados e arranca
├─ app/                              Node.js + Express
│  ├─ server.js · db.js · util.js · setup.js
│  ├─ routes/ (eleitor.js, admin.js)
│  ├─ tools/executar-sql.js          Corre .sql e mostra resultados no terminal
│  └─ public/ (index.html, eleitor.html, admin.html, css/, js/, img/)
├─ db/                               Scripts SQL (01 → 04 → 07; 05 consultas; 06 testes)
└─ docs/                             Requisitos, UML, modelo de dados, apresentação
   └─ uml/*.puml
```

---

## 🧪 Testes

- **Gatilhos e restrições:** `db/06_testes_gatilhos.sql` — 21 verificações (voto duplicado, eleição não aberta, imutabilidade, estrutura bloqueada, NIF inválido, menor de idade, código de acesso…). Todas devem imprimir `OK`.
- **Aplicação (executados manualmente):** login de eleitor e administrador, perfis (403), voto em eleição por Lista e uninominal com 1 e 2 cargos, segundo voto recusado, código errado/expirado/reutilizado, limite de pedidos, ciclo de vida completo de uma eleição até ao apuramento, páginas em computador e telemóvel.

---

## 🧭 Estado do Desenvolvimento

Implementado: modelo de dados, gatilhos, vistas, procedimentos, dados de demonstração, consultas, aplicação web (eleitor e administração) e documentação. Em falta para a entrega: relatório final com diagramas exportados e capturas de ecrã (ver `docs/04_Guia_Relatorio_e_Checklist.md`). Limitações assumidas em `docs/05_Apresentacao_e_Limitacoes.md`.

---

## 📈 Critérios de Avaliação

| Critério | Peso | Onde |
|---|---:|---|
| Especificação de requisitos funcionais e não funcionais | 5% | `docs/01_Requisitos.md` |
| Modelação UML de requisitos | 15% | `docs/02_*.md`, `docs/uml/01–05` |
| Modelação UML da BD e modelo relacional | 15% | `docs/03_Modelo_de_Dados.md`, `docs/uml/06–07`, `db/01_schema.sql` |
| Gatilhos e/ou asserções | 10% | `db/02_gatilhos.sql`, `db/06_testes_gatilhos.sql` |
| Interrogações SQL | 15% | `db/05_consultas.sql` |
| Interfaces gráficas | 10% | `app/public` |
| Defesa oral | 30% | — |

---

## 📦 Documentação e Entregáveis

| Documento | Conteúdo |
|---|---|
| `docs/00_Como_Executar.md` | Instalação, arranque, demonstração |
| `docs/01_Requisitos.md` | Requisitos |
| `docs/02_Modelacao_UML_Requisitos.md` | Casos de uso descritos |
| `docs/03_Modelo_de_Dados.md` | Modelo relacional, normalização, gatilhos, consultas |
| `docs/04_Guia_Relatorio_e_Checklist.md` | Estrutura do relatório e checklist |
| `docs/05_Apresentacao_e_Limitacoes.md` | Roteiro de demonstração, riscos e limitações |

---

## 🛡️ Considerações de Segurança e Limitações

Medidas: NIF validado; código de uso único com hash salgado, validade e tentativas limitadas; bcrypt; sessões `HttpOnly` + `SameSite=Strict`; perfis verificados no servidor; queries parametrizadas; escape de HTML; transações na votação; separação entre participação e voto; auditoria.

O eVoto é um **protótipo académico** para eleições simuladas. A separação entre `RegistoVoto` e `Voto` é uma medida de separação lógica, **não** garante anonimato absoluto (quem tiver acesso total à BD e aos registos de rede poderia tentar correlações). Limitações conhecidas: o código de acesso é mostrado no ecrã em vez de enviado por SMS/email; sem HTTPS nem cifra do voto; sessões em memória; apenas voto online (as mesas de voto do modelo original foram removidas). Ver `docs/05_Apresentacao_e_Limitacoes.md`.

---

## 👥 Equipa

**Elementos do grupo:**

- Elemento 1 — [Nome]
- Elemento 2 — [Nome]
- Elemento 3 — [Nome]
- Elemento 4 — [Nome]

**Unidade curricular:** [Nome da unidade curricular]

**Instituição:** [Nome da instituição]

**Ano letivo:** 2026/2027

---

**eVoto — Sistema de Votação Online**

*Projeto Académico | 2026/2027*
