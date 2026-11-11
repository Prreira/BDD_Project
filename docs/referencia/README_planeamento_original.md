# 🗳️ eVoto — Sistema de Votação Online

**Projeto de Desenvolvimento de uma Aplicação Web de Votação Online**

O **eVoto** é uma aplicação web desenvolvida para permitir a realização e gestão de eleições simuladas através de uma plataforma digital.

---

## 📋 Índice

1. [Descrição do Projeto](#-descrição-do-projeto)
2. [Objetivos](#-objetivos)
3. [Tecnologias Utilizadas](#-tecnologias-utilizadas)
4. [Instalação e Configuração](#-instalação-e-configuração)
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
15. [Planeamento do Desenvolvimento](#-planeamento-do-desenvolvimento)
16. [Critérios de Avaliação](#-critérios-de-avaliação)
17. [Documentação e Entregáveis](#-documentação-e-entregáveis)
18. [Considerações de Segurança](#-considerações-de-segurança)

---

## 📖 Descrição do Projeto

O **eVoto** é uma aplicação web desenvolvida com o objetivo de permitir a realização e gestão de eleições através de uma plataforma digital.

O sistema disponibiliza uma página inicial com autenticação, permitindo que diferentes tipos de utilizadores acedam às funcionalidades correspondentes às suas permissões.

Existem dois perfis principais:

- **Eleitor:** pode consultar as eleições em que está inscrito, visualizar os candidatos e exercer o seu direito de voto.
- **Administrador:** pode gerir eleições, candidatos e eleitores, assim como consultar dashboards, estatísticas e resultados eleitorais.

A aplicação utiliza uma base de dados Microsoft SQL Server para armazenar e gerir toda a informação necessária ao funcionamento do sistema.

## 🎯 Objetivos

Os principais objetivos do projeto são:

- Desenvolver uma aplicação web funcional para votação online.
- Implementar um sistema de autenticação e controlo de acessos.
- Permitir a gestão de eleições e candidatos.
- Permitir aos eleitores votar de forma simples e intuitiva.
- Impedir que um eleitor vote mais do que uma vez na mesma eleição.
- Garantir a integridade e consistência dos dados.
- Implementar mecanismos de validação através de constraints e triggers SQL.
- Desenvolver consultas SQL para obtenção de estatísticas e resultados.
- Construir dashboards para administração e acompanhamento das eleições.
- Aplicar conceitos de modelação UML e bases de dados relacionais.

---

## 💻 Tecnologias Utilizadas

| Tecnologia | Utilização |
|---|---|
| C# | Linguagem de programação principal |
| ASP.NET Core MVC | Desenvolvimento da aplicação web |
| .NET 10 | Plataforma de desenvolvimento |
| HTML5 | Estrutura das páginas |
| CSS3 | Estilização das interfaces |
| Bootstrap | Design responsivo |
| JavaScript | Interatividade das páginas |
| Microsoft SQL Server | Sistema de gestão da base de dados |
| SQL Server Management Studio | Administração e consulta da base de dados |
| Entity Framework Core | Comunicação entre a aplicação e a base de dados |
| ASP.NET Core Identity | Autenticação e gestão de utilizadores |
| diagrams.net | Criação dos diagramas UML |
| Git e GitHub | Controlo de versões e colaboração |

---

## ⚙️ Instalação e Configuração

### 1. Programas necessários

Antes de iniciar o desenvolvimento, devem ser instalados os seguintes programas:

| Programa | Finalidade | Ligação |
|---|---|---|
| Visual Studio Community | Desenvolvimento da aplicação | https://visualstudio.microsoft.com/downloads/ |
| .NET 10 SDK | Compilação e execução do projeto | https://dotnet.microsoft.com/download/dotnet/10.0 |
| SQL Server Developer | Motor da base de dados | https://www.microsoft.com/en-us/sql-server/sql-server-downloads |
| SQL Server Management Studio | Gestão da base de dados | https://learn.microsoft.com/en-us/ssms/download-sql-server-management-studio-ssms |
| diagrams.net | Modelação UML | https://app.diagrams.net/ |
| Git | Controlo de versões | https://git-scm.com/downloads |

No Visual Studio, durante a instalação, deve ser selecionada a carga de trabalho:

**ASP.NET and web development**

### 2. Verificar a instalação do .NET

Abrir o CMD ou PowerShell e executar:

```bash
dotnet --version
```

Deve ser apresentada uma versão correspondente ao .NET 10.

### 3. Criar a base de dados

Abrir o SQL Server Management Studio e estabelecer ligação ao servidor local.

Utilizar:

- Server Type: Database Engine
- Server Name: `localhost`
- Authentication: Windows Authentication

Executar o seguinte comando:

```sql
CREATE DATABASE eVotoDB;
GO
```

### 4. Criar o projeto no Visual Studio

1. Abrir o Visual Studio.
2. Selecionar `Create a new project`.
3. Procurar `ASP.NET Core Web App (Model-View-Controller)`.
4. Definir o nome do projeto como `eVoto`.
5. Definir o nome da solução como `eVoto`.
6. Selecionar .NET 10.
7. Configurar a autenticação como `Individual Accounts`.
8. Ativar HTTPS.
9. Criar o projeto.

### 5. Instalar os pacotes necessários

Abrir a Package Manager Console no Visual Studio e executar:

```powershell
Install-Package Microsoft.EntityFrameworkCore.SqlServer
Install-Package Microsoft.EntityFrameworkCore.Tools
```

Os pacotes devem utilizar versões compatíveis com o .NET 10 e com a versão do Entity Framework Core utilizada pelo projeto.

### 6. Configurar a ligação ao SQL Server

No ficheiro `appsettings.json`, configurar a connection string:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=eVotoDB;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true"
  }
}
```

A configuração do `ApplicationDbContext` deve utilizar o fornecedor SQL Server (`UseSqlServer`).

### 7. Criar e atualizar a base de dados

Na Package Manager Console:

```powershell
Add-Migration InitialCreate
Update-Database
```

Estas operações criam e atualizam a estrutura da base de dados através do Entity Framework Core.

Os scripts adicionais de SQL, nomeadamente triggers e stored procedures, devem ser executados posteriormente no SQL Server Management Studio.

---

## 🏗️ Arquitetura do Sistema

A aplicação segue uma arquitetura baseada em ASP.NET Core MVC.

A comunicação entre os diferentes componentes é organizada da seguinte forma:

```text
                  UTILIZADOR
                      |
                      |
                 INTERFACE WEB
             HTML / CSS / Bootstrap
                      |
                      |
              ASP.NET CORE MVC
                      |
          ---------------------------
          |             |           |
      CONTROLLERS    SERVICES     MODELS
          |             |           |
          ---------------------------
                      |
                      |
              ENTITY FRAMEWORK
                      |
                      |
              MICROSOFT SQL SERVER
                      |
          ---------------------------
          |             |           |
        TABELAS      TRIGGERS   PROCEDURES
```

### Componentes principais

- **Models:** representam as entidades e os dados utilizados pela aplicação.
- **Controllers:** recebem os pedidos dos utilizadores e controlam as operações da aplicação.
- **Views:** representam as páginas apresentadas aos utilizadores.
- **Services:** implementam a lógica de negócio, incluindo as validações do processo de votação.
- **Data:** contém a configuração e o acesso à base de dados.
- **Entity Framework Core:** permite comunicar com o SQL Server através de entidades e operações C#.

---

## 🔐 Funcionalidades

### Área de autenticação

- Login através de email e palavra-passe.
- Validação das credenciais.
- Identificação do perfil do utilizador.
- Redirecionamento automático para a área correspondente.
- Terminar sessão.
- Controlo de acessos através de funções (Roles).

### Área do eleitor

O eleitor poderá:

- Iniciar sessão.
- Consultar eleições em que está inscrito.
- Consultar informações das eleições.
- Visualizar os candidatos.
- Selecionar um candidato.
- Confirmar a intenção de voto.
- Submeter o voto.
- Receber uma confirmação da participação.
- Consultar se já participou numa eleição.

### Área de administração

O administrador poderá:

- Consultar o dashboard administrativo.
- Criar eleições.
- Editar eleições.
- Abrir e encerrar eleições.
- Consultar eleições existentes.
- Adicionar candidatos.
- Editar candidatos.
- Gerir eleitores.
- Inscrever eleitores em eleições.
- Consultar o número de eleitores inscritos.
- Consultar o número de votos recebidos.
- Consultar resultados eleitorais.
- Consultar estatísticas e gráficos.
- Consultar registos de auditoria.

### Regras de funcionamento

1. Cada utilizador tem um perfil e permissões específicas.
2. Um eleitor apenas pode votar em eleições nas quais esteja inscrito.
3. Um eleitor apenas pode votar em eleições abertas.
4. Um eleitor apenas pode submeter um voto por eleição.
5. Depois de submetido, o voto não pode ser alterado através das operações normais da aplicação.
6. Os administradores podem gerir eleições e candidatos de acordo com o estado da eleição.
7. Os resultados devem ser calculados através de consultas à base de dados.
8. O sistema deve impedir acessos não autorizados às funcionalidades administrativas.

### Estados de uma eleição

| Estado | Descrição |
|---|---|
| Rascunho | Eleição em preparação |
| Agendada | Eleição criada, com data futura |
| Aberta | Eleição disponível para votação |
| Encerrada | Eleição terminada |
| Arquivada | Eleição concluída, disponível apenas para consulta |

---

## 📝 Requisitos do Sistema

### Requisitos funcionais

| ID | Descrição |
|---|---|
| RF01 | O sistema deve permitir iniciar sessão. |
| RF02 | O sistema deve identificar o perfil do utilizador. |
| RF03 | O sistema deve direcionar o utilizador para a respetiva área. |
| RF04 | O eleitor deve poder consultar as eleições em que está inscrito. |
| RF05 | O eleitor deve poder consultar os candidatos. |
| RF06 | O eleitor deve poder submeter um voto. |
| RF07 | O sistema deve impedir votos duplicados por eleitor e eleição. |
| RF08 | O sistema deve confirmar a submissão do voto. |
| RF09 | O administrador deve poder criar e gerir eleições. |
| RF10 | O administrador deve poder gerir candidatos. |
| RF11 | O administrador deve poder gerir eleitores. |
| RF12 | O administrador deve poder inscrever eleitores em eleições. |
| RF13 | O administrador deve poder abrir e encerrar eleições. |
| RF14 | O sistema deve apresentar resultados e estatísticas. |
| RF15 | O sistema deve registar operações administrativas. |
| RF16 | O sistema deve permitir terminar sessão. |

### Requisitos não funcionais

| ID | Descrição |
|---|---|
| RNF01 | O sistema deve implementar autenticação. |
| RNF02 | As palavras-passe devem ser armazenadas através de hashing seguro. |
| RNF03 | O sistema deve separar os privilégios de eleitores e administradores. |
| RNF04 | A submissão dos votos deve ser transacional. |
| RNF05 | O sistema deve impedir votos em eleições encerradas. |
| RNF06 | A interface deve ser responsiva. |
| RNF07 | O sistema deve apresentar mensagens de erro claras. |
| RNF08 | A base de dados deve garantir integridade referencial. |
| RNF09 | A aplicação deve utilizar HTTPS quando publicada. |
| RNF10 | A identidade do eleitor não deve estar diretamente associada à opção de voto na tabela de boletins. |
| RNF11 | A interface deve ser intuitiva e de fácil utilização. |
| RNF12 | A base de dados deve permitir a realização de cópias de segurança. |

---

## 📐 Modelação UML

A modelação UML será utilizada para representar o funcionamento e a estrutura da aplicação antes e durante o desenvolvimento.

Os diagramas previstos são:

### 1. Diagrama de casos de utilização

Identifica os atores e as funcionalidades da aplicação.

**Atores:**
- Eleitor.
- Administrador.

**Casos de utilização do eleitor:**
- Iniciar sessão.
- Consultar eleições.
- Consultar candidatos.
- Votar.
- Confirmar voto.
- Consultar participação.
- Terminar sessão.

**Casos de utilização do administrador:**
- Iniciar sessão.
- Consultar dashboard.
- Gerir eleições.
- Gerir candidatos.
- Gerir eleitores.
- Inscrever eleitores.
- Abrir eleições.
- Encerrar eleições.
- Consultar resultados.
- Consultar auditoria.
- Terminar sessão.

### 2. Diagrama de atividades

Representa o processo de votação, desde a autenticação até à confirmação da submissão.

Deve incluir:

- Validação das credenciais.
- Identificação do perfil.
- Consulta da eleição.
- Verificação da inscrição.
- Verificação da participação anterior.
- Verificação do estado da eleição.
- Seleção do candidato.
- Confirmação.
- Registo do voto.

### 3. Diagrama de sequência

Representa a comunicação entre:

- Eleitor.
- Interface Web.
- Controller.
- Serviço de votação.
- Base de dados.

Deve demonstrar os pedidos e respostas necessários para a submissão de um voto.

### 4. Diagrama de classes

Representa as principais classes da aplicação:

- ApplicationUser.
- Eleitor.
- Eleicao.
- Candidato.
- InscricaoEleitor.
- Boletim.
- RegistoAuditoria.

### 5. Diagrama entidade-relacionamento

Representa as entidades da base de dados e as respetivas relações.

### 6. Modelo relacional

Apresenta as tabelas, atributos, chaves primárias e chaves estrangeiras.

---

## 🗄️ Modelo da Base de Dados

A base de dados será implementada em Microsoft SQL Server com o nome:

`eVotoDB`

### Tabelas principais

#### 1. AspNetUsers

Tabela de autenticação gerida pelo ASP.NET Core Identity.

Principais atributos:

- Id (PK).
- Email.
- UserName.
- PasswordHash.

O sistema Identity também utiliza outras tabelas para gerir funções, permissões e autenticação.

#### 2. Eleitor

Armazena os dados dos eleitores.

| Atributo | Descrição |
|---|---|
| EleitorId (PK) | Identificador do eleitor |
| UserId (FK) | Referência ao utilizador Identity |
| Nome | Nome do eleitor |

#### 3. Eleicao

Armazena as informações das eleições.

| Atributo | Descrição |
|---|---|
| EleicaoId (PK) | Identificador da eleição |
| Titulo | Nome da eleição |
| Descricao | Descrição |
| DataInicio | Data de início |
| DataFim | Data de fim |
| Estado | Estado da eleição |

#### 4. Candidato

Armazena os candidatos associados às eleições.

| Atributo | Descrição |
|---|---|
| CandidatoId (PK) | Identificador do candidato |
| EleicaoId (FK) | Eleição a que pertence |
| Nome | Nome do candidato |
| Descricao | Informação do candidato |

#### 5. InscricaoEleitor

Relaciona os eleitores com as eleições em que estão inscritos.

| Atributo | Descrição |
|---|---|
| EleicaoId (PK, FK) | Identificador da eleição |
| EleitorId (PK, FK) | Identificador do eleitor |
| JaVotou | Indica se já participou |

A chave primária é composta por `EleicaoId` e `EleitorId`.

#### 6. Boletim

Armazena os votos submetidos.

| Atributo | Descrição |
|---|---|
| BoletimId (PK) | Identificador do boletim |
| EleicaoId (FK) | Eleição correspondente |
| CandidatoId (FK) | Candidato selecionado |

A tabela não deve guardar diretamente o identificador do eleitor, permitindo separar a informação de participação da opção de voto.

Deve existir uma chave estrangeira composta que assegure que o candidato pertence à eleição indicada no boletim.

#### 7. RegistoAuditoria

Armazena operações administrativas.

| Atributo | Descrição |
|---|---|
| RegistoId (PK) | Identificador do registo |
| UserId (FK) | Utilizador responsável |
| Acao | Operação executada |
| DataHora | Data e hora da operação |
| Detalhes | Informação complementar |

### Relações entre as tabelas

| Relação | Cardinalidade |
|---|---|
| Utilizador — Eleitor | 1 : 0..1 |
| Eleição — Candidato | 1 : N |
| Eleição — InscriçãoEleitor | 1 : N |
| Eleitor — InscriçãoEleitor | 1 : N |
| Eleição — Boletim | 1 : N |
| Candidato — Boletim | 1 : N |
| Utilizador — RegistoAuditoria | 1 : N |

### Normalização

A estrutura da base de dados deverá respeitar as formas normais:

- **1FN:** utilização de atributos atómicos.
- **2FN:** dependência funcional dos atributos não-chave da totalidade da chave primária.
- **3FN:** eliminação de dependências transitivas desnecessárias.

---

## 🔒 Regras de Integridade e Triggers

A base de dados deverá implementar mecanismos de controlo e validação para garantir a consistência dos dados.

### Constraints

Devem ser implementadas:

- Primary Keys.
- Foreign Keys.
- UNIQUE.
- CHECK.
- NOT NULL.

Exemplos de regras:

- Não permitir datas finais anteriores às datas iniciais.
- Não permitir estados de eleição inválidos.
- Não permitir inscrições duplicadas.
- Não permitir relações entre boletins e candidatos de eleições diferentes.
- Não permitir identificadores duplicados.

### Trigger 1 — Validar a eleição

Nome: `TR_Boletim_ValidarEleicao`

Objetivo:

Impedir que sejam inseridos boletins quando a eleição não está aberta ou quando a data atual está fora do período permitido.

### Trigger 2 — Impedir alterações aos boletins

Nome: `TR_Boletim_Imutavel`

Objetivo:

Impedir operações de alteração ou eliminação de boletins já submetidos.

### Stored Procedure — Registar voto

Nome: `SP_RegistarVoto`

Objetivo:

Executar o processo de votação de forma transacional.

A procedure deverá:

1. Receber os identificadores do eleitor, eleição e candidato.
2. Validar se o eleitor está inscrito.
3. Verificar se já votou.
4. Verificar se a eleição está aberta.
5. Verificar se o candidato pertence à eleição.
6. Marcar a inscrição como utilizada.
7. Inserir o boletim.
8. Confirmar a transação.

Deve utilizar mecanismos de controlo de concorrência, como transações e bloqueios apropriados, para impedir a submissão duplicada de votos em pedidos simultâneos.

### Testes aos triggers

| Teste | Resultado esperado |
|---|---|
| Inserir voto numa eleição aberta | Permitido |
| Inserir voto numa eleição encerrada | Rejeitado |
| Inserir voto fora do período | Rejeitado |
| Alterar um boletim | Rejeitado |
| Eliminar um boletim | Rejeitado |

---

## 📊 Interrogações SQL

Serão desenvolvidas pelo menos 12 consultas SQL, com diferentes níveis de complexidade.

As consultas deverão demonstrar a utilização de:

- SELECT.
- WHERE.
- INNER JOIN.
- LEFT JOIN.
- GROUP BY.
- HAVING.
- ORDER BY.
- COUNT.
- SUM.
- Subconsultas.
- CTE.
- Funções de janela.

### Consultas previstas

| Nº | Consulta | Objetivo |
|---|---|---|
| 01 | Eleições abertas | Consultar eleições disponíveis |
| 02 | Candidatos por eleição | Consultar os candidatos |
| 03 | Votos por candidato | Contabilizar os votos |
| 04 | Taxa de participação | Calcular a percentagem de participação |
| 05 | Eleitores que ainda não votaram | Consultar participações pendentes |
| 06 | Eleições com mais de um candidato | Identificar eleições elegíveis |
| 07 | Candidatos sem votos | Identificar candidatos sem participação |
| 08 | Eleições por eleitor | Contabilizar as inscrições |
| 09 | Eleição com mais votos | Identificar a eleição mais participada |
| 10 | Classificação de candidatos | Ordenar candidatos por votação |
| 11 | Histórico administrativo | Consultar operações registadas |
| 12 | Eleitores inscritos | Consultar participantes de uma eleição |

Cada consulta deverá ser acompanhada de:

- Objetivo.
- Código SQL.
- Conceitos utilizados.
- Resultado obtido.

Os resultados eleitorais deverão ser calculados através de queries à base de dados.

---

## 🎨 Interfaces Gráficas

A aplicação eVoto terá diferentes páginas consoante o perfil do utilizador.

### 1. Página inicial e Login

Deve apresentar:

- Logótipo e identidade visual do eVoto.
- Campo de email.
- Campo de palavra-passe.
- Botão de autenticação.
- Mensagens de erro.

### 2. Dashboard do Eleitor

Deve apresentar:

- Mensagem de boas-vindas.
- Eleições disponíveis.
- Estado das eleições.
- Indicação de participação.
- Acesso à consulta das eleições.

### 3. Consulta de Eleição

Deve apresentar:

- Informação da eleição.
- Lista de candidatos.
- Descrições dos candidatos.
- Opção de seleção.
- Botão de confirmação.

### 4. Confirmação do Voto

Deve apresentar:

- Mensagem de sucesso.
- Confirmação de participação.
- Botão de regresso ao dashboard.

### 5. Dashboard Administrativo

Deve apresentar:

- Total de eleições.
- Eleições abertas.
- Total de eleitores inscritos.
- Total de votos.
- Gráficos de resultados.
- Gráficos de participação.
- Eleições recentes.

### 6. Gestão de Eleições

Deve permitir:

- Consultar eleições.
- Criar eleições.
- Editar eleições.
- Abrir e encerrar eleições.
- Consultar candidatos e inscrições.

### 7. Gestão de Candidatos

Deve permitir:

- Adicionar candidatos.
- Editar candidatos.
- Remover candidatos quando permitido.
- Associar candidatos a eleições.

### 8. Gestão de Eleitores

Deve permitir:

- Criar eleitores.
- Editar informação.
- Consultar eleitores.
- Inscrever eleitores em eleições.
- Consultar participação.

### 9. Resultados

Deve apresentar:

- Total de votos.
- Votos por candidato.
- Percentagem de votos.
- Taxa de participação.
- Resultados por eleição.

---

## 📁 Estrutura do Projeto

A estrutura proposta para a aplicação é:

```text
eVoto/
│
├── Controllers/
│   ├── HomeController.cs
│   ├── EleitorController.cs
│   ├── AdminController.cs
│   ├── EleicaoController.cs
│   └── DashboardController.cs
│
├── Models/
│   ├── ApplicationUser.cs
│   ├── Eleitor.cs
│   ├── Eleicao.cs
│   ├── Candidato.cs
│   ├── InscricaoEleitor.cs
│   ├── Boletim.cs
│   └── RegistoAuditoria.cs
│
├── Data/
│   └── ApplicationDbContext.cs
│
├── Services/
│   └── ServicoVotacao.cs
│
├── Views/
│   ├── Home/
│   ├── Eleitor/
│   ├── Admin/
│   ├── Eleicao/
│   └── Dashboard/
│
├── wwwroot/
│   ├── css/
│   ├── js/
│   └── images/
│
├── Database/
│   └── Scripts/
│       ├── 01_Constraints.sql
│       ├── 02_Triggers.sql
│       ├── 03_StoredProcedures.sql
│       ├── 04_Views.sql
│       ├── 05_Queries.sql
│       └── 06_DadosTeste.sql
│
├── Migrations/
│
├── appsettings.json
├── Program.cs
└── eVoto.sln
```

Esta estrutura poderá ser ajustada durante o desenvolvimento, conforme a evolução da aplicação.

---

## 🧪 Testes

Serão efetuados testes funcionais, testes de integridade da base de dados e testes de permissões.

### Testes de autenticação

| Teste | Resultado esperado |
|---|---|
| Login válido de eleitor | Acesso à área do eleitor |
| Login válido de administrador | Acesso à área administrativa |
| Login com palavra-passe incorreta | Mensagem de erro |
| Eleitor tenta aceder à administração | Acesso recusado |
| Administrador tenta utilizar a área de eleitor | Acesso recusado |

### Testes de votação

| Teste | Resultado esperado |
|---|---|
| Eleitor inscrito vota numa eleição aberta | Voto registado |
| Eleitor não inscrito tenta votar | Operação recusada |
| Eleitor tenta votar duas vezes | Operação recusada |
| Eleitor tenta votar numa eleição encerrada | Operação recusada |
| Eleitor tenta votar fora do período | Operação recusada |
| Submissão simultânea de votos | Apenas uma submissão aceite |

### Testes administrativos

| Teste | Resultado esperado |
|---|---|
| Criar uma eleição | Eleição criada |
| Criar um candidato | Candidato criado |
| Criar um eleitor | Eleitor criado |
| Inscrever eleitor | Inscrição criada |
| Consultar dashboard | Indicadores corretos |
| Consultar resultados | Resultados corretos |

### Testes da base de dados

| Teste | Resultado esperado |
|---|---|
| Inserir eleição com datas inválidas | Operação rejeitada |
| Inserir inscrição duplicada | Operação rejeitada |
| Alterar boletim | Operação rejeitada |
| Eliminar boletim | Operação rejeitada |
| Inserir candidato de outra eleição no boletim | Operação rejeitada |

Todos os testes deverão ser documentados e acompanhados de capturas de ecrã sempre que possível.

---

## 📅 Planeamento do Desenvolvimento

O desenvolvimento será dividido em quatro fases principais.

### Semana 1 — Planeamento e modelação

- Instalação das ferramentas.
- Especificação dos requisitos.
- Definição das funcionalidades.
- Diagrama de casos de utilização.
- Diagrama de atividades.
- Diagrama de sequência.
- Diagrama de classes.
- Diagrama entidade-relacionamento.
- Modelo relacional.

**Objetivo:** concluir a documentação inicial e a modelação.

### Semana 2 — Base de dados e backend

- Criação da base de dados.
- Criação das tabelas.
- Definição das relações.
- Implementação de constraints.
- Implementação de triggers.
- Implementação de stored procedures.
- Inserção dos dados de teste.
- Criação da aplicação MVC.
- Ligação ao SQL Server.
- Implementação da autenticação.

**Objetivo:** ter a base de dados e o backend preparados.

### Semana 3 — Desenvolvimento das interfaces

- Página inicial e login.
- Dashboard do eleitor.
- Processo de votação.
- Confirmação de voto.
- Dashboard administrativo.
- Gestão de eleições.
- Gestão de candidatos.
- Gestão de eleitores.
- Dashboards e gráficos.

**Objetivo:** obter uma aplicação funcional.

### Semana 4 — Consultas SQL, testes e documentação

- Implementação das 12 consultas SQL.
- Testes funcionais.
- Testes de integridade.
- Testes de permissões.
- Correção de erros.
- Revisão dos diagramas.
- Capturas de ecrã.
- Organização dos ficheiros.
- Finalização do README.

**Objetivo:** preparar a versão final do projeto.

---

## 📈 Critérios de Avaliação

O projeto será desenvolvido tendo em consideração os seguintes critérios:

| Critério | Peso |
|---|---:|
| Especificação de requisitos funcionais e não funcionais | 5% |
| Modelação UML de requisitos | 15% |
| Modelação UML da base de dados e modelo relacional | 15% |
| Gatilhos e/ou asserções | 10% |
| Interrogações SQL à base de dados | 15% |
| Interfaces gráficas | 10% |
| Defesa oral | 30% |

**Total dos critérios técnicos considerados neste planeamento: 70%.**

A defesa oral não está incluída no âmbito deste plano de desenvolvimento.

---

## 📦 Documentação e Entregáveis

A entrega final deverá incluir:

```text
Documentacao/
│
├── 01_Especificacao_Requisitos.pdf
├── 02_UML_Casos_Utilizacao.pdf
├── 03_UML_Atividades.pdf
├── 04_UML_Sequencia.pdf
├── 05_UML_Classes.pdf
├── 06_Modelo_ER.pdf
├── 07_Modelo_Relacional.pdf
├── 08_Triggers_Procedures.sql
├── 09_Consultas_SQL.sql
├── 10_Plano_Testes.pdf
│
├── CapturasEcra/
│
└── Aplicacao/
    └── eVoto.sln
```

O projeto deverá também incluir um ficheiro README com instruções para instalação, configuração e execução da aplicação.

---

## 🛡️ Considerações de Segurança

O eVoto é um protótipo académico destinado a eleições simuladas.

Devem ser consideradas as seguintes medidas:

- Utilização de autenticação segura.
- Armazenamento de palavras-passe através de hashing.
- Separação dos privilégios dos utilizadores.
- Proteção das páginas administrativas.
- Validação dos dados no servidor.
- Utilização de consultas SQL parametrizadas.
- Proteção contra SQL Injection.
- Proteção contra pedidos não autorizados.
- Registo de operações administrativas.
- Utilização de transações na submissão dos votos.
- Separação entre a informação de participação e a opção de voto.

A ausência de uma relação direta entre eleitor e boletim é uma medida de separação lógica de dados, mas não garante anonimato absoluto. Esta aplicação não está certificada nem preparada para eleições reais ou oficiais.

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

## 📌 Estado do Projeto

Projeto em desenvolvimento.

As funcionalidades, documentação e estrutura apresentadas neste README correspondem ao planeamento previsto e deverão ser atualizadas à medida que forem implementadas e testadas.

---

**eVoto — Sistema de Votação Online**

*Projeto Académico | 2026/2027*
