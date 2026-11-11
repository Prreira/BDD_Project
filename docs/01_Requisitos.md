# 1. Especificação de requisitos — eVoto

## 1.1 Âmbito

O **eVoto** é uma plataforma web de voto eletrónico. A página inicial é um *login* com dois acessos: o **eleitor** identifica-se com o **NIF** e um **código de uso único** gerado pelo sistema; a **administração** entra com email e palavra-passe. Depois de autenticado, cada perfil acede à sua área: o eleitor ao boletim de voto, a administração a dashboards e manutenção. Os dados estão numa base de dados **SQL Server**, cujo modelo parte do ficheiro `Dados2.sql` (eleições por Lista e Uninominais, mesas de voto, recenseamento, apuramento).

**Código de acesso sem serviços externos:** não havendo SMS/email, o código é gerado pela própria base de dados (`CRYPT_GEN_RANDOM`) e apresentado de imediato no site numa notificação (mensagem simulada), sendo preenchido automaticamente no campo. Num sistema real, o mesmo procedimento entregaria o código por um canal externo (modo `OTP_MODO`).

Fora de âmbito: autenticação com Cartão de Cidadão/Chave Móvel Digital, voto presencial (previsto no modelo pela origem `Manual` do registo de voto, mas sem interface) e cifra de voto ponta-a-ponta (trabalho futuro).

## 1.2 Atores

| Ator | Descrição |
|---|---|
| **Eleitor** | Pessoa recenseada numa ou mais eleições, que consulta as suas eleições e vota. |
| **Administrador** | Gere eleições, listas, candidatos, mesas, recenseamento e eleitores; consulta dashboards e registos. |
| **Sistema** | Executa tarefas automáticas (gerar/validar códigos, abrir e encerrar eleições por calendário, validações, auditoria). |

## 1.3 Requisitos funcionais

Prioridade MoSCoW: **M** (tem de existir), **S** (deve existir), **C** (pode existir).

### Autenticação e sessão

| ID | Requisito | Prior. | UC |
|---|---|---|---|
| RF01 | O eleitor identifica-se com o NIF; o sistema valida o formato e o dígito de controlo do NIF e se o eleitor está ativo e recenseado. | M | UC01 |
| RF02 | O sistema gera automaticamente um código de 6 dígitos de uso único, válido 3 minutos, e apresenta-o no ecrã (mensagem simulada), preenchendo o campo. | M | UC01 |
| RF03 | O eleitor entra introduzindo o código; ao fim de 3 tentativas erradas o código é anulado; o código expirado ou já usado é recusado. | M | UC01 |
| RF04 | O sistema limita os pedidos de código (máx. 5 em 10 minutos por NIF) e regista todas as tentativas na tabela `LogAutenticacao`. | S | UC01 |
| RF05 | A administração entra com email e palavra-passe, com bloqueio temporário após 5 falhas. | M | UC02 |
| RF06 | O sistema permite terminar sessão e expira a sessão após 30 minutos de inatividade. | M | UC03 |
| RF07 | Eleitores inativos não podem autenticar-se nem votar. | M | UC01 |

### Área do eleitor

| ID | Requisito | Prior. | UC |
|---|---|---|---|
| RF08 | O eleitor consulta as eleições em que está recenseado, com estado, período, mesa de voto e se já votou. | M | UC04 |
| RF09 | O eleitor vota numa eleição **Em Curso** em que está recenseado: escolhe uma lista (eleição por Lista) ou um candidato por cada cargo (Uninominal), podendo votar em branco ou nulo. | M | UC05 |
| RF10 | O sistema garante **um voto por eleitor e por eleição**. | M | UC05 |
| RF11 | O sistema pede confirmação antes de submeter; o voto é irrevogável. | M | UC05 |
| RF12 | O sistema emite um comprovativo de participação (hora e referência) sem revelar o sentido do voto. | S | UC05 |
| RF13 | O eleitor consulta os resultados das eleições já apuradas em que estava recenseado. | S | UC06 |

### Área de administração

| ID | Requisito | Prior. | UC |
|---|---|---|---|
| RF14 | Criar, editar e eliminar (só se Agendada) eleições, definindo tipo de escrutínio (Lista/Uninominal) e datas. | M | UC07 |
| RF15 | Gerir cargos (com nº de mandatos), listas e candidatos enquanto a eleição estiver Agendada. | M | UC08 |
| RF16 | Gerir mesas de voto e os seus membros enquanto a eleição estiver Agendada. | S | UC09 |
| RF17 | Gerir o recenseamento (recensear eleitores ativos, distribuídos pelas mesas) enquanto a eleição estiver Agendada. | M | UC10 |
| RF18 | Iniciar, encerrar e apurar a eleição, seguindo o ciclo de vida definido; o sistema abre e encerra automaticamente por calendário. | M | UC11 |
| RF19 | O apuramento só é possível com a eleição Encerrada e com integridade verificada; nas eleições por Lista distribui os mandatos pelo método de Hondt. | M | UC11 |
| RF20 | Criar, editar, ativar e desativar eleitores (identificados pelo NIF). | M | UC12 |
| RF21 | Dashboard com indicadores globais, resultados por lista/candidato, participação e abstenção, participação por mesa, atualizado automaticamente. | M | UC13 |
| RF22 | Consultar o registo de auditoria e o registo de autenticações. | S | UC14 |

### Regras de negócio

| ID | Regra |
|---|---|
| RN01 | Ciclo de vida: `Agendada → Em Curso → Encerrada → Apurada` (sem retrocessos). |
| RN02 | Para iniciar uma eleição são necessários: 1 cargo, 1 mesa, eleitores recenseados e pelo menos 2 listas (Lista) ou 2 candidatos (Uninominal). |
| RN03 | Um eleitor tem NIF válido (dígito de controlo) e pelo menos 18 anos. |
| RN04 | Depois de a eleição iniciar, cargos, listas, candidatos, mesas, membros e recenseamento não podem ser alterados. |
| RN05 | Registos de voto e votos nunca podem ser alterados ou apagados. |
| RN06 | Numa eleição por Lista, o voto válido indica uma lista e o candidato pertence a uma lista; numa uninominal o voto válido indica um candidato de um cargo e o candidato não tem lista. |
| RN07 | O código de acesso é de uso único, expira em 3 minutos e só o mais recente é válido. |

## 1.4 Requisitos não funcionais

| ID | Categoria | Requisito | Critério de aceitação |
|---|---|---|---|
| RNF01 | Segurança | Palavras-passe de administradores guardadas só como *hash* bcrypt; códigos de acesso guardados só como *hash* SHA-256 salgado. | Nenhum segredo em claro na BD. |
| RNF02 | Segurança | Controlo de acesso por perfil validado no servidor. | Um eleitor a chamar a API de administração recebe HTTP 403. |
| RNF03 | Segurança | Proteção contra *SQL injection* e XSS; proteção contra força bruta do código. | Queries parametrizadas; texto escapado no cliente; 3 tentativas por código e 5 pedidos por 10 min. |
| RNF04 | Privacidade | **Anonimato do voto.** | `RegistoVoto` e `Voto` sem ligação; `Voto` sem data/hora e com identificador GUID aleatório; NIFs dos candidatos não são expostos ao eleitor. |
| RNF05 | Integridade | Um eleitor, um voto, garantido pela própria BD. | PK (eleição, NIF) em `RegistoVoto` e gatilhos; 2.º voto rejeitado mesmo por acesso direto à BD. |
| RNF06 | Integridade | Registo do voto atómico. | `RegistoVoto` e `Voto` na mesma transação. |
| RNF07 | Auditabilidade | Ações administrativas e de autenticação registadas com autor e hora. | `Auditoria` e `LogAutenticacao`; o sentido do voto nunca é registado. |
| RNF08 | Desempenho | Páginas e dashboards respondem em menos de 2 s com 10 000 eleitores. | Índices nas junções e filtros mais usados. |
| RNF09 | Usabilidade e acessibilidade | Interface em português, institucional, responsiva e acessível (contraste, teclado, *skip link*, rótulos). | Utilizável desde 360 px; foco visível. |
| RNF10 | Disponibilidade | Estados das eleições e códigos guardados na BD, não em memória. | Reiniciar o servidor não altera o estado. |
| RNF11 | Portabilidade | Executável em Windows com Node.js ≥ 18 e SQL Server 2016 SP1 ou superior. | `npm run setup` e `npm start`. |
| RNF12 | Manutenibilidade | Lógica crítica na BD (procedimentos, gatilhos, vistas) e aplicação modular. | Scripts SQL numerados e reexecutáveis. |

## 1.5 Matriz de rastreabilidade (resumo)

| Requisito | UC | Implementação na BD | Ecrã |
|---|---|---|---|
| RF01–RF04, RF07 | UC01 | `fn_NifValido`, `sp_GerarCodigoAcesso`, `sp_ValidarCodigoAcesso`, `CodigoAcesso`, `LogAutenticacao` | Login (Eleitor) |
| RF09–RF12 | UC05 | `sp_RegistarVoto`, G1, G2, G5 | Boletim de voto |
| RF18, RF19 | UC11 | G9, `sp_AtualizarEstadosEleicoes`, `sp_ApurarEleicao`, `ResultadoApuramento` | Gerir eleição |
| RF21 | UC13 | `vw_ResultadosLista`, `vw_ResultadosCandidato`, `vw_ParticipacaoEleicao`, `vw_ParticipacaoPorMesa` | Painel |
| RF22, RNF07 | UC14 | G4, G10, `Auditoria`, `LogAutenticacao` | Auditoria / Autenticações |
| RNF04 | todos | Separação `RegistoVoto` / `Voto`, GUID | n/a |
