/* =====================================================================
   eVoto - Sistema de Voto Online
   01_schema.sql : criação da base de dados (SQL Server)

   Este esquema é a adaptação do modelo original (Dados2.sql) ao projeto web:
   - mantém as tabelas originais que fazem sentido num voto ONLINE (Eleicao,
     Cargo, Lista, Eleitor, Recenseamento, Candidato, RegistoVoto, Voto,
     ResultadoApuramento, LogAutenticacao) com as mesmas chaves naturais (NIF);
   - remove MesaDeVoto, MembroMesa e a coluna origem (só existiam para voto
     presencial);
   - acrescenta o necessário para a aplicação: Administrador (login por
     email/palavra-passe), CodigoAcesso (código de uso único enviado ao eleitor
     quando este se identifica com o NIF) e Auditoria.
   Ver docs/03_Modelo_de_Dados.md para a lista completa de alterações.

   ATENÇÃO: este script RECRIA a base de dados eVoto (apaga a anterior).
   ===================================================================== */
USE master;
GO
IF DB_ID(N'eVoto') IS NOT NULL
BEGIN
    ALTER DATABASE eVoto SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE eVoto;
END;
GO
CREATE DATABASE eVoto COLLATE Latin1_General_100_CI_AS;
GO
USE eVoto;
GO

/* ---------------------------------------------------------------------
   Funções auxiliares sobre o NIF português (9 dígitos, dígito de controlo
   módulo 11; pessoas singulares começam por 1, 2 ou 3)
   --------------------------------------------------------------------- */
CREATE FUNCTION dbo.fn_NifValido (@nif NVARCHAR(9))
RETURNS BIT
AS
BEGIN
    IF @nif IS NULL OR LEN(@nif) <> 9 OR @nif LIKE N'%[^0-9]%' OR @nif NOT LIKE N'[123]%'
        RETURN 0;
    DECLARE @soma INT = 0, @i INT = 1;
    WHILE @i <= 8
    BEGIN
        SET @soma += CAST(SUBSTRING(@nif, @i, 1) AS INT) * (10 - @i);   -- pesos 9..2
        SET @i += 1;
    END;
    DECLARE @r INT = @soma % 11;
    DECLARE @controlo INT = CASE WHEN @r < 2 THEN 0 ELSE 11 - @r END;
    RETURN CASE WHEN @controlo = CAST(RIGHT(@nif, 1) AS INT) THEN 1 ELSE 0 END;
END;
GO

-- Completa 8 dígitos com o dígito de controlo (usada para gerar NIFs de teste)
CREATE FUNCTION dbo.fn_NifCompletar (@base CHAR(8))
RETURNS NVARCHAR(9)
AS
BEGIN
    DECLARE @soma INT = 0, @i INT = 1;
    WHILE @i <= 8
    BEGIN
        SET @soma += CAST(SUBSTRING(@base, @i, 1) AS INT) * (10 - @i);
        SET @i += 1;
    END;
    DECLARE @r INT = @soma % 11;
    RETURN CONCAT(@base, CASE WHEN @r < 2 THEN 0 ELSE 11 - @r END);
END;
GO

/* ---------------------------------------------------------------------
   ADMINISTRADOR (nova): acesso à área de administração
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Administrador (
    id_admin      INT IDENTITY(1,1) NOT NULL,
    email         NVARCHAR(120)     NOT NULL,
    nome          NVARCHAR(100)     NOT NULL,
    password_hash VARCHAR(100)      NOT NULL,                -- bcrypt
    nivel_acesso  TINYINT           NOT NULL CONSTRAINT DF_Admin_Nivel DEFAULT (1),  -- 1 gestor, 2 super-admin
    ativo         BIT               NOT NULL CONSTRAINT DF_Admin_Ativo DEFAULT (1),
    CONSTRAINT PK_Administrador PRIMARY KEY (id_admin),
    CONSTRAINT UQ_Administrador_Email UNIQUE (email),
    CONSTRAINT CK_Administrador_Email CHECK (email LIKE N'%_@_%._%'),
    CONSTRAINT CK_Administrador_Nivel CHECK (nivel_acesso IN (1, 2))
);
GO

/* ---------------------------------------------------------------------
   1. ELEICAO (original + descricao e administrador criador)
   Ciclo de vida: Agendada -> Em Curso -> Encerrada -> Apurada
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Eleicao (
    nome            NVARCHAR(200) NOT NULL PRIMARY KEY,
    descricao       NVARCHAR(500) NULL,                       -- novo
    data_inicio     DATETIME      NOT NULL,
    data_fim        DATETIME      NOT NULL,
    tipo_escrutinio NVARCHAR(20)  NOT NULL
        CHECK (tipo_escrutinio IN ('Lista', 'Uninominal')),
    estado          NVARCHAR(20)  NOT NULL DEFAULT 'Agendada'
        CHECK (estado IN ('Agendada', 'Em Curso', 'Encerrada', 'Apurada')),
    id_admin_criador INT          NULL                        -- novo
        CONSTRAINT FK_Eleicao_Admin REFERENCES dbo.Administrador (id_admin),
    CHECK (data_fim > data_inicio)
);
GO

/* 2. CARGO (original + nº de mandatos a distribuir) */
CREATE TABLE dbo.Cargo (
    eleicao      NVARCHAR(200) NOT NULL,
    cargo        NVARCHAR(100) NOT NULL,
    num_mandatos INT           NOT NULL DEFAULT 1 CHECK (num_mandatos >= 1),   -- novo
    PRIMARY KEY (eleicao, cargo),
    FOREIGN KEY (eleicao) REFERENCES dbo.Eleicao (nome)
);
GO

/* 3. LISTA (só usada em eleições do tipo 'Lista') */
CREATE TABLE dbo.Lista (
    eleicao    NVARCHAR(200) NOT NULL,
    sigla      NVARCHAR(15)  NOT NULL,
    designacao NVARCHAR(150) NOT NULL,
    PRIMARY KEY (eleicao, sigla),
    FOREIGN KEY (eleicao) REFERENCES dbo.Eleicao (nome)
);
GO

/* 4. ELEITOR (original + data de nascimento, estado e validação do NIF) */
CREATE TABLE dbo.Eleitor (
    nif             NVARCHAR(9)   NOT NULL PRIMARY KEY,
    nome            NVARCHAR(150) NOT NULL,
    data_nascimento DATE          NOT NULL,                   -- novo
    ativo           BIT           NOT NULL DEFAULT 1,         -- novo
    CONSTRAINT CK_Eleitor_Nif CHECK (dbo.fn_NifValido(nif) = 1)
);
GO

/* 5. RECENSEAMENTO (eleitor inscrito numa eleição). Como o voto é online,
      não existem mesas de voto: MesaDeVoto e MembroMesa do modelo original
      foram removidas. */
CREATE TABLE dbo.Recenseamento (
    eleicao  NVARCHAR(200) NOT NULL,
    nif      NVARCHAR(9)   NOT NULL,
    PRIMARY KEY (eleicao, nif),
    FOREIGN KEY (eleicao) REFERENCES dbo.Eleicao (nome),
    FOREIGN KEY (nif) REFERENCES dbo.Eleitor (nif)
);
GO

/* 6. CANDIDATO (sigla_lista e posicao só em eleições do tipo 'Lista') */
CREATE TABLE dbo.Candidato (
    eleicao     NVARCHAR(200) NOT NULL,
    nif         NVARCHAR(9)   NOT NULL,
    cargo       NVARCHAR(100) NOT NULL,
    sigla_lista NVARCHAR(15)  NULL,
    posicao     INT           NULL,
    PRIMARY KEY (eleicao, nif),
    UNIQUE (eleicao, nif, cargo),
    FOREIGN KEY (nif) REFERENCES dbo.Eleitor (nif),
    FOREIGN KEY (eleicao, cargo) REFERENCES dbo.Cargo (eleicao, cargo),
    FOREIGN KEY (eleicao, sigla_lista) REFERENCES dbo.Lista (eleicao, sigla),
    CONSTRAINT CK_Candidato_Lista_Posicao CHECK (
        (sigla_lista IS NULL AND posicao IS NULL)
        OR (sigla_lista IS NOT NULL AND posicao IS NOT NULL)
    )
);
-- posição única dentro de cada lista (novo)
CREATE UNIQUE INDEX UX_Candidato_Posicao ON dbo.Candidato (eleicao, sigla_lista, posicao)
    WHERE sigla_lista IS NOT NULL;
GO

/* 7. REGISTO DE VOTO: prova QUE o eleitor votou; a PK impede o duplo voto.
      (A coluna "origem" do modelo original foi removida: todo o voto é online.) */
CREATE TABLE dbo.RegistoVoto (
    eleicao   NVARCHAR(200) NOT NULL,
    nif       NVARCHAR(9)   NOT NULL,
    data_hora DATETIME      NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (eleicao, nif),
    FOREIGN KEY (eleicao, nif) REFERENCES dbo.Recenseamento (eleicao, nif)
);
GO

/* 8. VOTO: sem ligação ao eleitor (destino = lista OU candidato).
       ALTERAÇÃO de anonimato: id_voto passa a GUID aleatório (NEWSEQUENTIALID
       não é usado de propósito) em vez de IDENTITY, porque um inteiro
       sequencial permitiria cruzar a ordem dos votos com data_hora do
       RegistoVoto e descobrir em quem cada eleitor votou. */
CREATE TABLE dbo.Voto (
    id_voto       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    eleicao       NVARCHAR(200) NOT NULL,
    tipo_voto     NVARCHAR(20)  NOT NULL CHECK (tipo_voto IN ('Valido', 'Branco', 'Nulo')),
    cargo         NVARCHAR(100) NULL,
    sigla_lista   NVARCHAR(15)  NULL,
    nif_candidato NVARCHAR(9)   NULL,
    FOREIGN KEY (eleicao) REFERENCES dbo.Eleicao (nome),
    FOREIGN KEY (eleicao, cargo) REFERENCES dbo.Cargo (eleicao, cargo),
    FOREIGN KEY (eleicao, sigla_lista) REFERENCES dbo.Lista (eleicao, sigla),
    FOREIGN KEY (eleicao, nif_candidato, cargo) REFERENCES dbo.Candidato (eleicao, nif, cargo),
    CONSTRAINT CK_Voto_Destino CHECK (
        (tipo_voto = 'Valido' AND (
               (sigla_lista IS NOT NULL AND nif_candidato IS NULL AND cargo IS NULL)
            OR (sigla_lista IS NULL AND nif_candidato IS NOT NULL AND cargo IS NOT NULL)
        ))
        OR (tipo_voto IN ('Branco', 'Nulo') AND sigla_lista IS NULL AND nif_candidato IS NULL)
    )
);
GO

/* 9. RESULTADO DO APURAMENTO (linha sem lista nem candidato = total global) */
CREATE TABLE dbo.ResultadoApuramento (
    id_resultado  INT IDENTITY(1,1) PRIMARY KEY,
    eleicao       NVARCHAR(200) NOT NULL,
    cargo         NVARCHAR(100) NULL,
    sigla_lista   NVARCHAR(15)  NULL,
    nif_candidato NVARCHAR(9)   NULL,
    num_votos     INT           NOT NULL DEFAULT 0,
    num_mandatos  INT           NOT NULL DEFAULT 0,
    FOREIGN KEY (eleicao) REFERENCES dbo.Eleicao (nome),
    FOREIGN KEY (eleicao, cargo) REFERENCES dbo.Cargo (eleicao, cargo),
    FOREIGN KEY (eleicao, sigla_lista) REFERENCES dbo.Lista (eleicao, sigla),
    FOREIGN KEY (eleicao, nif_candidato, cargo) REFERENCES dbo.Candidato (eleicao, nif, cargo),
    CHECK (sigla_lista IS NULL OR nif_candidato IS NULL)
);
GO

/* 10. LOG DE AUTENTICAÇÃO (original; eleicao passa a ser opcional porque o
       login é anterior à escolha da eleição; num_mesa foi removido;
       nif_tentativa guarda também o email das tentativas de administradores) */
CREATE TABLE dbo.LogAutenticacao (
    id_log        INT IDENTITY(1,1) PRIMARY KEY,
    nif_tentativa NVARCHAR(120) NOT NULL,
    data_hora     DATETIME      NOT NULL DEFAULT GETDATE(),
    sucesso       BIT           NOT NULL,
    motivo_falha  NVARCHAR(255) NULL,
    eleicao       NVARCHAR(200) NULL,
    etapa         NVARCHAR(20)  NOT NULL DEFAULT 'Codigo'      -- novo: Codigo | Validacao | Admin
        CHECK (etapa IN ('Codigo', 'Validacao', 'Admin')),
    FOREIGN KEY (eleicao) REFERENCES dbo.Eleicao (nome)
);
GO

/* ---------------------------------------------------------------------
   CODIGO DE ACESSO (novo): código de 6 dígitos de uso único e curta duração
   enviado ao eleitor quando se identifica com o NIF. Só se guarda um hash
   salgado, nunca o código em claro.
   --------------------------------------------------------------------- */
CREATE TABLE dbo.CodigoAcesso (
    id_codigo  INT IDENTITY(1,1) PRIMARY KEY,
    nif        NVARCHAR(9)  NOT NULL REFERENCES dbo.Eleitor (nif),
    salt       BINARY(16)   NOT NULL,
    hash_codigo BINARY(32)  NOT NULL,
    criado_em  DATETIME     NOT NULL DEFAULT GETDATE(),
    expira_em  DATETIME     NOT NULL,
    estado     NVARCHAR(10) NOT NULL DEFAULT 'Pendente'
        CHECK (estado IN ('Pendente', 'Usado', 'Expirado', 'Anulado')),
    tentativas TINYINT      NOT NULL DEFAULT 0,
    CHECK (expira_em > criado_em)
);
GO

/* ---------------------------------------------------------------------
   AUDITORIA (nova): ações relevantes; nunca regista o sentido do voto
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Auditoria (
    id_log    BIGINT IDENTITY(1,1) PRIMARY KEY,
    data_hora DATETIME      NOT NULL DEFAULT GETDATE(),
    autor     NVARCHAR(40)  NULL,          -- 'ADMIN:3' ou 'NIF:123456789'
    acao      NVARCHAR(30)  NOT NULL,
    entidade  NVARCHAR(30)  NOT NULL,
    detalhe   NVARCHAR(400) NULL
);
GO

/* Índices de suporte às consultas e aos dashboards */
CREATE INDEX IX_Recenseamento_Nif   ON dbo.Recenseamento (nif);
CREATE INDEX IX_Voto_Eleicao        ON dbo.Voto (eleicao, tipo_voto) INCLUDE (sigla_lista, nif_candidato, cargo);
CREATE INDEX IX_RegistoVoto_Hora    ON dbo.RegistoVoto (eleicao, data_hora);
CREATE INDEX IX_Eleicao_Estado      ON dbo.Eleicao (estado, data_inicio, data_fim);
CREATE INDEX IX_CodigoAcesso_Nif    ON dbo.CodigoAcesso (nif, estado, expira_em);
CREATE INDEX IX_LogAutenticacao_Dt  ON dbo.LogAutenticacao (data_hora DESC);
CREATE INDEX IX_Auditoria_Data      ON dbo.Auditoria (data_hora DESC);
GO
