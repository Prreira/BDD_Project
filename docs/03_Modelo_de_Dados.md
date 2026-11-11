# 3. Modelação da base de dados e modelo relacional — eVoto

SGBD: **Microsoft SQL Server** (2016 SP1 ou superior). Scripts em [`../db`](../db). Diagramas: `uml/06_diagrama_classes.puml` (conceptual) e `uml/07_modelo_relacional_er.puml` (relacional/físico).

O modelo parte do ficheiro original [`referencia/Dados2.sql`](referencia/Dados2.sql) (12 tabelas com chaves naturais, NIF como identificador do eleitor) e foi **adaptado** para a aplicação web.

## 3.1 Alterações ao modelo original (`Dados2.sql`)

| Tabela | Alteração | Motivo |
|---|---|---|
| **Administrador** | **Nova** (email, nome, hash bcrypt, nível, ativo) | O original não tinha utilizadores de administração; o login do admin é por email/palavra-passe. |
| **CodigoAcesso** | **Nova** (nif, salt, hash, criado/expira, estado, tentativas) | Autenticação do eleitor por NIF + código de uso único, sem serviços externos. Só se guarda um hash salgado. |
| **Auditoria** | **Nova** | Registo de ações administrativas e de votos (sem o sentido do voto). |
| Eleitor | + `data_nascimento`, `ativo`; `CHECK dbo.fn_NifValido(nif)` | Validar o NIF (dígito de controlo) e a idade mínima; poder desativar eleitores. |
| Eleicao | + `descricao`, `id_admin_criador` | Texto apresentado ao eleitor; autoria. |
| Cargo | + `num_mandatos` | Necessário para distribuir mandatos (Hondt). |
| Candidato | + índice único `(eleicao, sigla_lista, posicao)` | Posição única dentro da lista. |
| **Voto** | `id_voto`: de `INT IDENTITY` para `UNIQUEIDENTIFIER DEFAULT NEWID()` | **Anonimato:** um inteiro sequencial permitiria cruzar a ordem dos votos com `RegistoVoto.data_hora` e descobrir em quem cada eleitor votou. |
| LogAutenticacao | `eleicao`/`num_mesa` passam a opcionais; `nif_tentativa` alargado a 120; + `etapa` | O login acontece antes de escolher a eleição; regista também o email dos administradores. |
| Restantes (Lista, MesaDeVoto, Recenseamento, MembroMesa, RegistoVoto, ResultadoApuramento) | Mantidas | — |

As tabelas `Utilizador`, `Circulo` e `CadernoEleitoral` do desenho anterior foram substituídas por `Eleitor` + `Administrador`, `MesaDeVoto` e `Recenseamento`.

## 3.2 Decisões de desenho

**Anonimato do voto.** Provar que cada eleitor votou uma só vez sem revelar em quem votou obriga a separar:
- **`RegistoVoto(eleicao, nif, data_hora, origem)`** — PK `(eleicao, nif)` impede o duplo voto; FK para `Recenseamento` impede votar sem estar recenseado.
- **`Voto(id_voto, eleicao, num_mesa, tipo_voto, cargo, sigla_lista, nif_candidato)`** — sem NIF, sem data/hora, com GUID aleatório.

O voto mantém o `num_mesa` (apuramento por mesa, como numa eleição real); o NIF dos candidatos nunca é mostrado ao eleitor no boletim.

**Código de acesso.** `sp_GerarCodigoAcesso` gera 6 dígitos com `CRYPT_GEN_RANDOM`, guarda `SHA2_256(salt + nif:código)` e devolve o código à aplicação, que o apresenta no ecrã. Regras: validade 3 min, uso único, só o mais recente vale, 3 tentativas, máx. 5 pedidos / 10 min por NIF; tudo em `LogAutenticacao`.

**Dois escrutínios no mesmo modelo.** `Voto` aceita destino *lista* (`sigla_lista`) ou *candidato* (`nif_candidato` + `cargo`), com `CK_Voto_Destino`; o gatilho G5 exige o destino conforme o `tipo_escrutinio` da eleição.

## 3.3 Modelo relacional

(PK sublinhada; FK com `→`)

- **Administrador**(<u>id_admin</u>, email, nome, password_hash, nivel_acesso, ativo) — UNIQUE(email)
- **Eleicao**(<u>nome</u>, descricao, data_inicio, data_fim, tipo_escrutinio, estado, id_admin_criador) — id_admin_criador → Administrador; CHECK(data_fim > data_inicio)
- **Cargo**(<u>eleicao, cargo</u>, num_mandatos) — eleicao → Eleicao
- **Lista**(<u>eleicao, sigla</u>, designacao) — eleicao → Eleicao
- **Eleitor**(<u>nif</u>, nome, data_nascimento, ativo) — CHECK fn_NifValido(nif)
- **MesaDeVoto**(<u>eleicao, num_mesa</u>, localizacao, num_votantes) — eleicao → Eleicao
- **Recenseamento**(<u>eleicao, nif</u>, num_mesa) — nif → Eleitor; (eleicao, num_mesa) → MesaDeVoto
- **Candidato**(<u>eleicao, nif</u>, cargo, sigla_lista, posicao) — nif → Eleitor; (eleicao, cargo) → Cargo; (eleicao, sigla_lista) → Lista; UNIQUE(eleicao, nif, cargo)
- **MembroMesa**(<u>eleicao, num_mesa, nif</u>, funcao) — (eleicao, num_mesa) → MesaDeVoto; nif → Eleitor
- **RegistoVoto**(<u>eleicao, nif</u>, data_hora, origem) — (eleicao, nif) → Recenseamento
- **Voto**(<u>id_voto</u>, eleicao, num_mesa, tipo_voto, cargo, sigla_lista, nif_candidato) — (eleicao, num_mesa) → MesaDeVoto; (eleicao, cargo) → Cargo; (eleicao, sigla_lista) → Lista; (eleicao, nif_candidato, cargo) → Candidato
- **ResultadoApuramento**(<u>id_resultado</u>, eleicao, cargo, sigla_lista, nif_candidato, num_votos, num_mandatos)
- **CodigoAcesso**(<u>id_codigo</u>, nif, salt, hash_codigo, criado_em, expira_em, estado, tentativas) — nif → Eleitor
- **LogAutenticacao**(<u>id_log</u>, nif_tentativa, data_hora, sucesso, motivo_falha, eleicao, num_mesa, etapa) — (eleicao, num_mesa) → MesaDeVoto
- **Auditoria**(<u>id_log</u>, data_hora, autor, acao, entidade, detalhe)

## 3.4 Normalização

- **1FN:** atributos atómicos; sem grupos repetitivos.
- **2FN:** nas chaves compostas (`Recenseamento`, `RegistoVoto`, `MembroMesa`, `Cargo`, `Lista`, `MesaDeVoto`) todos os atributos dependem da chave completa (ex.: `num_mesa` depende de *eleição e NIF*).
- **3FN:** sem dependências transitivas (nome e data de nascimento só em `Eleitor`; localização só em `MesaDeVoto`; designação só em `Lista`).
- Não há desnormalização: os totais (inscritos, votantes, percentagens) calculam-se nas vistas. Única exceção deliberada, herdada do modelo original: `MesaDeVoto.num_votantes`, mantido pelo gatilho G3 e validado pela asserção de integridade (`vw_Integridade`).

## 3.5 Restrições de integridade (resumo)

| Tipo | Exemplos |
|---|---|
| PK / UNIQUE | NIF; (eleição, NIF) em `RegistoVoto`; email do administrador; posição única por lista |
| FK | todas as relações; FKs compostas para garantir coerência eleição/cargo/lista/mesa |
| CHECK | NIF válido (`fn_NifValido`), estado, tipo de escrutínio, `data_fim > data_inicio`, `CK_Voto_Destino`, `CK_Candidato_Lista_Posicao`, origem, estado do código |
| DEFAULT | `estado = 'Agendada'`, `ativo = 1`, datas = `GETDATE()`, `id_voto = NEWID()`, `num_votantes = 0` |
| Índices | `IX_Recenseamento_Nif`, `IX_Voto_Eleicao`, `IX_Eleicao_Estado`, `IX_CodigoAcesso_Nif`, `IX_LogAutenticacao_Dt`, `IX_Auditoria_Data` |

## 3.6 Gatilhos e asserções (`db/02_gatilhos.sql`)

O SQL Server não tem `CREATE ASSERTION`; as regras multi-linha/multi-tabela são gatilhos e as de linha são `CHECK`. Cada gatilho tem teste em `db/06_testes_gatilhos.sql`.

| Id | Gatilho | Tabela / evento | Regra |
|---|---|---|---|
| G1 | `trg_RegistoVoto_Validar` | RegistoVoto, AFTER INSERT | Eleição Em Curso e no prazo; eleitor ativo |
| G2 | `trg_RegistoVoto_Imutavel` | RegistoVoto, INSTEAD OF UPDATE/DELETE | Registos imutáveis |
| G3 | `trg_RegistoVoto_Mesa` | RegistoVoto, AFTER INSERT | Mantém `MesaDeVoto.num_votantes` |
| G4 | `trg_RegistoVoto_Auditoria` | RegistoVoto, AFTER INSERT | Regista que alguém votou (sem o sentido) |
| G5 | `trg_Voto_Validar` | Voto, AFTER INSERT | Só em eleição Em Curso; destino conforme o escrutínio |
| G6 | `trg_Voto_Imutavel` | Voto, INSTEAD OF UPDATE/DELETE | Votos imutáveis |
| G7 | `trg_Cargo/Lista/Candidato/MesaDeVoto/MembroMesa/Recenseamento_Bloqueio` | AFTER I/U/D | Estrutura só muda com a eleição Agendada |
| G8 | `trg_Candidato_Coerencia` | Candidato, AFTER I/U | Lista obrigatória (Lista) ou proibida (Uninominal); candidato ativo |
| G9 | `trg_Eleicao_Estado` | Eleicao, AFTER UPDATE | Transições válidas; requisitos para iniciar; dados congelados |
| G10 | `trg_Eleicao_Auditoria` | Eleicao, AFTER I/U/D | Auditoria com o autor (`SESSION_CONTEXT`) |
| G11 | `trg_Eleitor_Idade` | Eleitor, AFTER I/U | Idade mínima 18 anos |

**Asserções declarativas:** `CK_Eleitor_Nif`, `CK_Voto_Destino`, `CK_Candidato_Lista_Posicao`, FKs compostas. **Asserção de integridade global:** `vw_Integridade` (registos de voto = contadores das mesas; nº de votos = esperado), exigida por `sp_ApurarEleicao`.

## 3.7 Vistas e procedimentos (`db/03_vistas_procedimentos.sql`)

| Objeto | Função |
|---|---|
| `fn_NifValido`, `fn_NifCompletar` | Validação do NIF e geração de NIFs de teste |
| `vw_ResultadosLista` / `vw_ResultadosCandidato` | Votos, % e mandatos |
| `vw_ParticipacaoEleicao` / `vw_ParticipacaoPorMesa` | Inscritos, votantes, abstenção, brancos, nulos |
| `vw_Integridade` | Asserção de integridade |
| `sp_GerarCodigoAcesso` | Gera e guarda o código (hash) e devolve-o |
| `sp_ValidarCodigoAcesso` | Valida o código (uso único, 3 tentativas, 3 min) |
| `sp_RegistarVoto` | Voto atómico a partir de um JSON de escolhas |
| `sp_AtualizarEstadosEleicoes` | Inicia/encerra por calendário |
| `sp_ApurarEleicao` | Apuramento com verificação de integridade e Hondt |

## 3.8 Interrogações SQL (`db/05_consultas.sql`)

| # | Objetivo | Técnica |
|---|---|---|
| C1 | Eleições em curso com mesas/recenseados | JOIN, GROUP BY |
| C2 | Classificação e mandatos das listas | RANK() |
| C3 | Participação e abstenção por eleição | vista |
| C4 | Eleitores que ainda não votaram | NOT EXISTS |
| C5 | Participação por mesa | vista |
| C6 | Listas acima da média | subconsulta correlacionada |
| C7 | Eleitores que votaram em todas as eleições encerradas | divisão relacional |
| C8 | Participação por escalão etário | CASE, agregação condicional |
| C9 | Vencedor por cargo das eleições apuradas | CTE + ROW_NUMBER |
| C10 | Afluência por hora com acumulado | SUM() OVER |
| C11 | % de brancos e nulos | agregação condicional |
| C12 | Atividade na auditoria por autor | GROUP BY |
| C13 | Inativos ainda recenseados | JOIN múltiplo |
| C14 | Asserção: integridade (0 linhas) | vista |
| C15 | Mesas com maior abstenção | DENSE_RANK() |
| C16 | Autenticações falhadas nas últimas 24 h | JOIN, GROUP BY, HAVING, subconsulta |
| C17 | Composição de cada lista | JOIN de 3 tabelas |
