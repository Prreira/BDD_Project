# 3. Modelação da base de dados e modelo relacional — eVoto

SGBD: **Microsoft SQL Server** (2016 SP1 ou superior). Scripts em [`../db`](../db). Diagramas: `uml/06_diagrama_classes.puml` (conceptual) e `uml/07_modelo_relacional_er.puml` (relacional/físico).

O modelo parte de um modelo prévio da equipa, o ficheiro `Dados2.sql` (12 tabelas com chaves naturais, NIF como identificador do eleitor) e foi **adaptado** para uma aplicação de **voto online**.

## 3.1 Alterações ao modelo original (`Dados2.sql`)

| Tabela | Alteração | Motivo |
|---|---|---|
| **MesaDeVoto** | **Removida** | O voto é online: não há mesas nem locais de voto. |
| **MembroMesa** | **Removida** | Dependia de `MesaDeVoto`. |
| Recenseamento | Perde `num_mesa` (e a FK para `MesaDeVoto`); passa a ter FK direta para `Eleicao` | O eleitor está inscrito na eleição, não numa mesa. |
| Voto | Perde `num_mesa` | Idem; o voto fica ainda menos associável a um subgrupo de eleitores. |
| RegistoVoto | Perde a coluna `origem` (`Automatica`/`Manual`) | `Manual` significava voto presencial na mesa; todo o voto é online. |
| **Administrador** | **Nova** (email, nome, hash bcrypt, nível, ativo) | O original não tinha utilizadores de administração; o login do admin é por email/palavra-passe. |
| **CodigoAcesso** | **Nova** (nif, salt, hash, criado/expira, estado, tentativas) | Autenticação do eleitor por NIF + código de uso único, sem serviços externos. Só se guarda um hash salgado. |
| **Auditoria** | **Nova** | Registo de ações administrativas e de votos (sem o sentido do voto). |
| Eleitor | + `data_nascimento`, `ativo`; `CHECK dbo.fn_NifValido(nif)` | Validar o NIF (dígito de controlo) e a idade mínima; poder desativar eleitores. |
| Eleicao | + `descricao`, `id_admin_criador` | Texto apresentado ao eleitor; autoria. |
| Cargo | + `num_mandatos` | Necessário para distribuir mandatos (Hondt). |
| Candidato | + índice único `(eleicao, sigla_lista, posicao)` | Posição única dentro da lista. |
| **Voto** | `id_voto`: de `INT IDENTITY` para `UNIQUEIDENTIFIER DEFAULT NEWID()` | **Anonimato:** um inteiro sequencial permitiria cruzar a ordem dos votos com `RegistoVoto.data_hora` e descobrir em quem cada eleitor votou. |
| LogAutenticacao | `eleicao` passa a opcional e `num_mesa` é removido; `nif_tentativa` alargado a 120; + `etapa` | O login acontece antes de escolher a eleição; regista também o email dos administradores. |
| Lista, ResultadoApuramento | Mantidas | — |

As tabelas `Utilizador`, `Circulo` e `CadernoEleitoral` de um desenho anterior foram substituídas por `Eleitor` + `Administrador` e `Recenseamento`.

## 3.2 Decisões de desenho

**Anonimato do voto.** Provar que cada eleitor votou uma só vez sem revelar em quem votou obriga a separar:
- **`RegistoVoto(eleicao, nif, data_hora)`** — PK `(eleicao, nif)` impede o duplo voto; FK para `Recenseamento` impede votar sem estar recenseado.
- **`Voto(id_voto, eleicao, tipo_voto, cargo, sigla_lista, nif_candidato)`** — sem NIF, sem data/hora, com GUID aleatório.

Como o voto já não guarda a mesa, **nenhuma coluna de `Voto` identifica, sequer, um subgrupo de eleitores**: um voto só sabe a que eleição pertence. O NIF dos candidatos nunca é mostrado ao eleitor no boletim.

**Código de acesso.** `sp_GerarCodigoAcesso` gera 6 dígitos com `CRYPT_GEN_RANDOM`, guarda `SHA2_256(salt + nif:código)` e devolve o código à aplicação, que o apresenta no ecrã. Regras: validade 3 min, uso único, só o mais recente vale, 3 tentativas, máx. 5 pedidos / 10 min por NIF; tudo em `LogAutenticacao`.

**Dois escrutínios no mesmo modelo.** `Voto` aceita destino *lista* (`sigla_lista`) ou *candidato* (`nif_candidato` + `cargo`), com `CK_Voto_Destino`; o gatilho G4 exige o destino conforme o `tipo_escrutinio` da eleição.

**Afluência em vez de mesas.** O acompanhamento da participação faz-se por tempo (`vw_AfluenciaHoraria`: votantes por dia e hora), a partir do `RegistoVoto`.

## 3.3 Modelo relacional

(PK sublinhada; FK com `→`)

- **Administrador**(<u>id_admin</u>, email, nome, password_hash, nivel_acesso, ativo) — UNIQUE(email)
- **Eleicao**(<u>nome</u>, descricao, data_inicio, data_fim, tipo_escrutinio, estado, id_admin_criador) — id_admin_criador → Administrador; CHECK(data_fim > data_inicio)
- **Cargo**(<u>eleicao, cargo</u>, num_mandatos) — eleicao → Eleicao
- **Lista**(<u>eleicao, sigla</u>, designacao) — eleicao → Eleicao
- **Eleitor**(<u>nif</u>, nome, data_nascimento, ativo) — CHECK fn_NifValido(nif)
- **Recenseamento**(<u>eleicao, nif</u>) — eleicao → Eleicao; nif → Eleitor
- **Candidato**(<u>eleicao, nif</u>, cargo, sigla_lista, posicao) — nif → Eleitor; (eleicao, cargo) → Cargo; (eleicao, sigla_lista) → Lista; UNIQUE(eleicao, nif, cargo)
- **RegistoVoto**(<u>eleicao, nif</u>, data_hora) — (eleicao, nif) → Recenseamento
- **Voto**(<u>id_voto</u>, eleicao, tipo_voto, cargo, sigla_lista, nif_candidato) — eleicao → Eleicao; (eleicao, cargo) → Cargo; (eleicao, sigla_lista) → Lista; (eleicao, nif_candidato, cargo) → Candidato
- **ResultadoApuramento**(<u>id_resultado</u>, eleicao, cargo, sigla_lista, nif_candidato, num_votos, num_mandatos)
- **CodigoAcesso**(<u>id_codigo</u>, nif, salt, hash_codigo, criado_em, expira_em, estado, tentativas) — nif → Eleitor
- **LogAutenticacao**(<u>id_log</u>, nif_tentativa, data_hora, sucesso, motivo_falha, eleicao, etapa) — eleicao → Eleicao
- **Auditoria**(<u>id_log</u>, data_hora, autor, acao, entidade, detalhe)

## 3.4 Normalização

- **1FN:** atributos atómicos; sem grupos repetitivos.
- **2FN:** nas chaves compostas (`Recenseamento`, `RegistoVoto`, `Cargo`, `Lista`) todos os atributos dependem da chave completa (ex.: `data_hora` depende de *eleição e NIF*).
- **3FN:** sem dependências transitivas (nome e data de nascimento só em `Eleitor`; designação só em `Lista`).
- Não há desnormalização: os totais (inscritos, votantes, percentagens) calculam-se nas vistas, nunca se guardam.

## 3.5 Restrições de integridade (resumo)

| Tipo | Exemplos |
|---|---|
| PK / UNIQUE | NIF; (eleição, NIF) em `RegistoVoto`; email do administrador; posição única por lista |
| FK | todas as relações; FKs compostas para garantir coerência eleição/cargo/lista |
| CHECK | NIF válido (`fn_NifValido`), estado, tipo de escrutínio, `data_fim > data_inicio`, `CK_Voto_Destino`, `CK_Candidato_Lista_Posicao`, estado do código |
| DEFAULT | `estado = 'Agendada'`, `ativo = 1`, datas = `GETDATE()`, `id_voto = NEWID()` |
| Índices | `IX_Recenseamento_Nif`, `IX_Voto_Eleicao`, `IX_RegistoVoto_Hora`, `IX_Eleicao_Estado`, `IX_CodigoAcesso_Nif`, `IX_LogAutenticacao_Dt`, `IX_Auditoria_Data` |

## 3.6 Gatilhos e asserções (`db/02_gatilhos.sql`)

O SQL Server não tem `CREATE ASSERTION`; as regras multi-linha/multi-tabela são gatilhos e as de linha são `CHECK`. Cada gatilho tem teste em `db/06_testes_gatilhos.sql`.

| Id | Gatilho | Tabela / evento | Regra |
|---|---|---|---|
| G1 | `trg_RegistoVoto_Validar` | RegistoVoto, AFTER INSERT | Eleição Em Curso e no prazo; eleitor ativo |
| G2 | `trg_RegistoVoto_Imutavel` | RegistoVoto, INSTEAD OF UPDATE/DELETE | Registos imutáveis |
| G3 | `trg_RegistoVoto_Auditoria` | RegistoVoto, AFTER INSERT | Regista que alguém votou (sem o sentido) |
| G4 | `trg_Voto_Validar` | Voto, AFTER INSERT | Só em eleição Em Curso; destino conforme o escrutínio |
| G5 | `trg_Voto_Imutavel` | Voto, INSTEAD OF UPDATE/DELETE | Votos imutáveis |
| G6 | `trg_Cargo/Lista/Candidato/Recenseamento_Bloqueio` | AFTER I/U/D | Estrutura só muda com a eleição Agendada |
| G7 | `trg_Candidato_Coerencia` | Candidato, AFTER I/U | Lista obrigatória (Lista) ou proibida (Uninominal); candidato ativo |
| G8 | `trg_Eleicao_Estado` | Eleicao, AFTER UPDATE | Transições válidas; requisitos para iniciar; dados congelados |
| G9 | `trg_Eleicao_Auditoria` | Eleicao, AFTER I/U/D | Auditoria com o autor (`SESSION_CONTEXT`) |
| G10 | `trg_Eleitor_Idade` | Eleitor, AFTER I/U | Idade mínima 18 anos |

**Asserções declarativas:** `CK_Eleitor_Nif`, `CK_Voto_Destino`, `CK_Candidato_Lista_Posicao`, FKs compostas. **Asserção de integridade global:** `vw_Integridade` (nº de votos = nº esperado: 1 por boletim, ou 1 por cargo nas uninominais), exigida por `sp_ApurarEleicao`.

## 3.7 Vistas e procedimentos (`db/03_vistas_procedimentos.sql`)

| Objeto | Função |
|---|---|
| `fn_NifValido`, `fn_NifCompletar` | Validação do NIF e geração de NIFs de teste |
| `vw_ResultadosLista` / `vw_ResultadosCandidato` | Votos, % e mandatos |
| `vw_ParticipacaoEleicao` | Inscritos, votantes, abstenção, brancos, nulos |
| `vw_AfluenciaHoraria` | Votantes por dia e hora |
| `vw_Integridade` | Asserção de integridade |
| `sp_GerarCodigoAcesso` | Gera e guarda o código (hash) e devolve-o |
| `sp_ValidarCodigoAcesso` | Valida o código (uso único, 3 tentativas, 3 min) |
| `sp_RegistarVoto` | Voto atómico a partir de um JSON de escolhas |
| `sp_AtualizarEstadosEleicoes` | Inicia/encerra por calendário |
| `sp_ApurarEleicao` | Apuramento com verificação de integridade e Hondt |

## 3.8 Interrogações SQL (`db/05_consultas.sql`)

| # | Objetivo | Técnica |
|---|---|---|
| C1 | Eleições em curso (cargos, candidatos, recenseados, votos) | subconsultas correlacionadas |
| C2 | Classificação e mandatos das listas | RANK() |
| C3 | Participação e abstenção por eleição | vista |
| C4 | Eleitores que ainda não votaram | NOT EXISTS |
| C5 | Votos por dia numa eleição | vista de afluência, GROUP BY |
| C6 | Listas acima da média | subconsulta correlacionada |
| C7 | Eleitores que votaram em todas as eleições encerradas | divisão relacional |
| C8 | Participação por escalão etário | CASE, agregação condicional |
| C9 | Vencedor por cargo das eleições apuradas | CTE + ROW_NUMBER |
| C10 | Afluência por hora com acumulado | SUM() OVER |
| C11 | % de brancos e nulos | agregação condicional |
| C12 | Atividade na auditoria por autor | GROUP BY |
| C13 | Inativos ainda recenseados | JOIN múltiplo |
| C14 | Asserção: integridade (0 linhas) | vista |
| C15 | Ranking das eleições por abstenção | vista + DENSE_RANK() |
| C16 | Autenticações falhadas nas últimas 24 h | JOIN, GROUP BY, HAVING, subconsulta |
| C17 | Composição de cada lista | JOIN de 3 tabelas |
