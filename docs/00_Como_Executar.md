# eVoto — Como executar o projeto

Trabalho prático de Bases de Dados. Aplicação web sobre **SQL Server**: página inicial com *login* único, **área do eleitor** (votar) e **área de administração** (dashboards e manutenção).

O eleitor entra com o **NIF** + **código de uso único**. Como não há serviços externos (SMS/email), o código é **gerado pela base de dados** e **aparece automaticamente no site** (notificação com a mensagem simulada, campo preenchido sozinho, validade de 3 minutos).

## Estrutura do projeto

```
BDD/
├─ docs/referencia/Dados2.sql          Modelo original (ponto de partida da adaptação)
├─ docs/
│  ├─ 01_Requisitos.md                 Requisitos funcionais e não funcionais
│  ├─ 02_Modelacao_UML_Requisitos.md   Casos de uso descritos + índice dos diagramas
│  ├─ 03_Modelo_de_Dados.md            Adaptação do Dados2.sql, modelo relacional, gatilhos, queries
│  ├─ 04_Guia_Relatorio_e_Checklist.md Estrutura sugerida do relatório e checklist
│  └─ uml/*.puml                       Diagramas PlantUML
├─ db/
│  ├─ 01_schema.sql                    Recria a BD eVoto e as tabelas
│  ├─ 02_gatilhos.sql                  Gatilhos (G1–G11)
│  ├─ 03_vistas_procedimentos.sql      Vistas, NIF, código de acesso, votação, apuramento
│  ├─ 04_dados_teste.sql               Dados de demonstração
│  ├─ 05_consultas.sql                 17 interrogações SQL
│  └─ 06_testes_gatilhos.sql           Testes dos gatilhos e do código de acesso
├─ app/                                Aplicação web (Node.js + Express)
└─ iniciar.ps1                         Atalho para arrancar a aplicação
```

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
# $env:DB_INSTANCE = "SQLEXPRESS"   # se usar uma instância nomeada (sem porto)

npm run setup     # RECRIA a BD eVoto (tabelas, gatilhos, vistas, dados) e define a password dos admins
npm start         # http://localhost:3000
```

**Atalho neste PC:** `.\iniciar.ps1` na raiz do projeto arranca a aplicação (liga a `localhost\SQLEXPRESS` com o utilizador `sa`; pede a password se `DB_PASSWORD` não estiver definida).

Em alternativa ao `npm run setup`, corra `db/01…04` no SSMS (por ordem) e depois `npm run passwords` para definir a palavra-passe dos administradores.

### Contas de demonstração

| Perfil | Como entrar |
|---|---|
| **Eleitor** | No separador *Eleitor*, clique em "preencher NIF de teste" (ou use o NIF que o `npm run setup` mostra no fim, ex.: `231079192`) → *Pedir código de acesso* → o código aparece numa notificação e preenche-se sozinho → *Entrar*. |
| **Administrador** | Separador *Administração*: `admin1@evoto.pt` / `Admin#2026` (também `admin2@evoto.pt`). |

Os NIF dos eleitores são válidos (dígito de controlo). O modo em que o código é mostrado no ecrã é só para demonstração (`OTP_MODO=ecra`, por omissão); com outro valor o código deixa de ser devolvido ao browser e teria de ser entregue por um canal externo.

### Demonstração sugerida

1. **Eleitor:** NIF → código no ecrã → ver eleições → votar na presidencial → comprovativo → tentar votar de novo → ver resultados da autárquica (mandatos por Hondt).
2. **Administrador:** painel (gráficos em tempo real, participação por mesa) → criar eleição → cargos, listas, candidatos, mesas, recenseamento → iniciar → encerrar → apurar. Ver *Autenticações* e *Auditoria*.
3. **SSMS / terminal:** `db/06_testes_gatilhos.sql` (todas as linhas `OK`) e `db/05_consultas.sql`.

## Segurança implementada

NIF validado (formato e dígito de controlo); código de uso único com *hash* SHA-256 salgado, validade de 3 min, 3 tentativas e limite de pedidos; bcrypt para administradores; sessões `HttpOnly` + `SameSite=Strict`; perfil verificado no servidor (HTTP 403); queries parametrizadas; escape de HTML no cliente; **anonimato do voto** por desenho da BD (ver `03_Modelo_de_Dados.md`).
