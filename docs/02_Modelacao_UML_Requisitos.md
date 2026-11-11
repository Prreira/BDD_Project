# 2. Modelação UML de requisitos — eVoto

Os diagramas estão em PlantUML na pasta [`uml/`](uml). Para os exportar para imagem (PNG/SVG): extensão **PlantUML** do VS Code (Alt+D), ou colar o conteúdo em <https://www.plantuml.com/plantuml> (os diagramas não contêm dados pessoais).

| Ficheiro | Diagrama |
|---|---|
| `01_casos_de_uso.puml` | Casos de uso (Eleitor, Administrador, Sistema) |
| `02_atividade_votar.puml` | Atividades — autenticar (NIF + código) e votar |
| `03_atividade_gerir_eleicao.puml` | Atividades — preparar e apurar uma eleição |
| `04_sequencia_votar.puml` | Sequência — autenticação e votação (browser → servidor → BD) |
| `05_estados_eleicao.puml` | Máquina de estados da eleição |
| `06_diagrama_classes.puml` | Modelo conceptual (classes) |

## 2.1 Descrição dos casos de uso

### UC01 — Autenticar eleitor (NIF + código)
- **Ator:** Eleitor (com apoio do Sistema). **Pré:** eleitor ativo e recenseado em pelo menos uma eleição.
- **Fluxo principal:** 1) o eleitor indica o NIF; 2) o sistema valida o NIF (formato e dígito de controlo), o estado do eleitor e o recenseamento; 3) o sistema **gera o código** de 6 dígitos (*include* «Gerar código de acesso»), guarda apenas o seu *hash* salgado e mostra o código no ecrã numa notificação, preenchendo o campo; 4) o eleitor confirma o código; 5) o sistema **valida o código** (*include* «Validar código de acesso»), marca-o como Usado, cria a sessão e abre a área do eleitor.
- **Alternativos:** A1) NIF inválido, inexistente, inativo ou sem recenseamento → mensagem de erro e registo em `LogAutenticacao`. A2) mais de 5 pedidos em 10 min → recusado. A3) código errado → restam N tentativas; à 3.ª o código é anulado. A4) código expirado (3 min) ou já usado → pedir novo código. A5) novo pedido anula o código anterior.
- **Pós:** sessão ativa com perfil Eleitor; todas as tentativas registadas.

### UC02 — Autenticar administrador
- **Ator:** Administrador. **Fluxo:** email e palavra-passe → comparação bcrypt → sessão. **Alternativos:** credenciais inválidas ou conta inativa → mensagem genérica; 5 falhas → bloqueio de 10 min. Tudo registado em `LogAutenticacao` (etapa Admin).

### UC03 — Terminar sessão
- A sessão é destruída; também expira após 30 min de inatividade.

### UC04 — Consultar as minhas eleições
- **Ator:** Eleitor. **Fluxo:** lista das eleições do recenseamento com estado, período, mesa e indicação "já votou".

### UC05 — Votar
- **Pré:** eleição Em Curso, eleitor recenseado e sem registo de voto.
- **Fluxo principal:** 1) escolhe a eleição; 2) o sistema apresenta o boletim (listas, ou candidatos por cargo); 3) escolhe uma opção por grupo (ou branco/nulo); 4) revê e confirma (*include* «Confirmar voto»); 5) o sistema grava `RegistoVoto` e `Voto(s)` numa transação; 6) emite o comprovativo.
- **Alternativos:** A1) já votou → rejeitado (PK/procedimento); A2) a eleição encerrou entretanto → rejeitado (G1); A3) boletim incompleto → botão desativado.
- **Pós:** existe um `RegistoVoto` e `Voto`(s) sem ligação entre si; `MesaDeVoto.num_votantes` incrementado.

### UC06 — Consultar resultados
- **Pré:** eleição Apurada em que estava recenseado. **Fluxo:** votos, percentagens, mandatos (listas), participação, brancos e nulos.

### UC07 — Gerir eleições
- Criar (nome, descrição, escrutínio, datas), editar e eliminar (só Agendada). Alterações de tipo/início depois de iniciada → G9.

### UC08 — Gerir cargos, listas e candidatos
- **Pré:** eleição Agendada. Cargo com nº de mandatos; listas (sigla, designação); candidatos escolhidos entre os eleitores, com cargo e (se Lista) lista e posição. Eleição iniciada → G7.

### UC09 — Gerir mesas de voto
- Criar mesas (localização) e atribuir membros (Presidente, Secretário, Vogal).

### UC10 — Gerir recenseamento
- Recensear todos os eleitores ativos ainda não inscritos, distribuídos pelas mesas; limpar recenseamento.

### UC11 — Alterar estado / apurar
- **Atores:** Administrador, Sistema. Iniciar, encerrar e apurar; o Sistema abre/encerra por calendário (UC15). **Alternativos:** transição inválida → G9; iniciar sem requisitos → G9; apurar com integridade violada → `sp_ApurarEleicao` rejeita. O apuramento distribui mandatos por Hondt (Lista) ou elege o mais votado por cargo (Uninominal).

### UC12 — Gerir eleitores
- Criar (NIF, nome, data de nascimento), editar, ativar/desativar. **Alternativos:** NIF inválido → CHECK; duplicado → PK; menor de 18 anos → G11.

### UC13 — Consultar painel
- Indicadores, resultados por opção, participação, participação por mesa e atividade recente; atualização automática a cada 15 s.

### UC14 — Consultar auditoria e autenticações
- Últimas ações (autor, ação, detalhe) e últimas tentativas de autenticação. O sentido do voto nunca é registado.

## 2.2 Diagramas de atividade, sequência e estados

- **Atividades "Autenticar e votar"** (`02_*.puml`): *swimlanes* Eleitor/Sistema, validações do NIF e do código, `ROLLBACK`.
- **Atividades "Preparar e apurar"** (`03_*.puml`): ciclo completo da eleição, incluindo Hondt.
- **Sequência** (`04_*.puml`): `sp_GerarCodigoAcesso` / `sp_ValidarCodigoAcesso` e `sp_RegistarVoto`, com os gatilhos.
- **Estados da eleição** (`05_*.puml`): transições permitidas, implementadas pelo gatilho G9.
- **Classes** (`06_*.puml`): modelo conceptual que dá origem ao modelo relacional (ver `03_Modelo_de_Dados.md`).
