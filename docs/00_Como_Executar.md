# eVoto — Como executar o projeto

Aplicação web (Node.js + Express) sobre **SQL Server**: *login* único, **área do eleitor** (votar) e **área de administração** (dashboards e manutenção). O eleitor entra com o **NIF** + **código de uso único** gerado pela base de dados e mostrado no próprio site (sem SMS/email).

## Estrutura

```
BDD_Project/
├─ README.md                           Descrição geral do projeto
├─ iniciar.ps1                         Arranca a aplicação
├─ preparar-apresentacao.ps1           Verifica requisitos, repõe os dados e arranca
├─ docs/                               Requisitos, UML, modelo de dados, apresentação
│  ├─ 00_Como_Executar.md              (este ficheiro)
│  ├─ 01_Requisitos.md … 05_Apresentacao_e_Limitacoes.md
│  ├─ uml/*.puml                       Diagramas PlantUML
│  └─ referencia/                      Dados2.sql (modelo original) e README de planeamento original
├─ db/
│  ├─ 01_schema.sql                    Recria a BD eVoto e as tabelas
│  ├─ 02_gatilhos.sql                  Gatilhos (G1–G11)
│  ├─ 03_vistas_procedimentos.sql      Vistas, NIF, código de acesso, votação, apuramento
│  ├─ 04_dados_teste.sql               Dados base (60 eleitores, 3 eleições)
│  ├─ 07_dados_adicionais.sql          Carga de volume (300 eleitores, 6 eleições, ~700 votos)
│  ├─ 05_consultas.sql                 17 interrogações SQL
│  └─ 06_testes_gatilhos.sql           Testes dos gatilhos e do código de acesso
└─ app/                                Aplicação web (server.js, routes/, public/, tools/)
```

Ordem de execução da carga: `01 → 02 → 03 → 04 → 07` (feita por `npm run setup`). Os ficheiros `05` e `06` são para consulta e testes.

## Requisitos

- **SQL Server** 2016 SP1 ou superior (Express serve) com **autenticação SQL** e TCP/IP ativos.
- **Node.js** 18 ou superior.

## Instalação e arranque

No PowerShell, dentro da pasta `app`:

```powershell
cd app
npm install

# credenciais do SQL Server (ajustar)
$env:DB_SERVER   = "localhost"
$env:DB_USER     = "sa"
$env:DB_PASSWORD = "a-sua-password"
$env:DB_INSTANCE = "SQLEXPRESS"     # instância nomeada (sem porto); omitir se usar o porto 1433

npm run setup     # RECRIA a BD eVoto (tabelas, gatilhos, vistas, dados) e define a password dos admins
npm start         # http://localhost:3000
```

**Atalhos neste PC** (a password do `sa` está na variável de utilizador `DB_PASSWORD`):

- `.\iniciar.ps1` — arranca a aplicação.
- `.\preparar-apresentacao.ps1` — verifica Node.js e SQL Server, recria a BD com datas atuais e arranca.

Em alternativa ao `npm run setup`, corra `db/01…04` e `db/07` no SSMS (por ordem) e depois `npm run passwords`.

### Ver os scripts SQL sem o SSMS

```powershell
cd app
npm run sql -- ..\db\06_testes_gatilhos.sql
npm run sql -- ..\db\05_consultas.sql
```

### Contas de demonstração

| Perfil | Como entrar |
|---|---|
| **Eleitor** | Separador *Sou eleitor* → "preencher NIF de teste" (ou um NIF mostrado no fim do `npm run setup`) → *Pedir código de acesso* → o código aparece numa notificação e preenche-se sozinho → *Entrar*. |
| **Administrador** | Separador *Administração*: `admin1@evoto.pt` / `Admin#2026` (também `admin2@evoto.pt`). |

Os NIF dos eleitores são válidos (dígito de controlo). O modo em que o código é mostrado no ecrã é só para demonstração (`OTP_MODO=ecra`, por omissão).

## Segurança implementada

NIF validado; código de uso único com *hash* SHA-256 salgado, validade de 3 min, 3 tentativas e limite de pedidos; bcrypt para administradores; sessões `HttpOnly` + `SameSite=Strict`; perfil verificado no servidor (HTTP 403); queries parametrizadas; escape de HTML no cliente; **anonimato do voto** por desenho da BD (ver `03_Modelo_de_Dados.md`). Limitações em `05_Apresentacao_e_Limitacoes.md`.
