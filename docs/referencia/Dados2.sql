-- 1. Eleicao
CREATE TABLE Eleicao (
    nome NVARCHAR(200) NOT NULL PRIMARY KEY,
    data_inicio DATETIME NOT NULL,
    data_fim DATETIME NOT NULL,
    tipo_escrutinio NVARCHAR(20) NOT NULL
        CHECK (tipo_escrutinio IN ('Lista', 'Uninominal')),
    estado NVARCHAR(20) NOT NULL DEFAULT 'Agendada'
        CHECK (estado IN ('Agendada', 'Em Curso', 'Encerrada', 'Apurada')),
    CHECK (data_fim > data_inicio)
);

-- 2. Cargo (cargos em disputa numa eleição)
CREATE TABLE Cargo (
    eleicao NVARCHAR(200) NOT NULL,
    cargo NVARCHAR(100) NOT NULL,
    PRIMARY KEY (eleicao, cargo),
    FOREIGN KEY (eleicao) REFERENCES Eleicao(nome)
);

-- 3. Lista (só usada em eleições do tipo 'Lista')
CREATE TABLE Lista (
    eleicao NVARCHAR(200) NOT NULL,
    sigla NVARCHAR(15) NOT NULL,
    designacao NVARCHAR(150) NOT NULL,
    PRIMARY KEY (eleicao, sigla),
    FOREIGN KEY (eleicao) REFERENCES Eleicao(nome)
);

-- 4. Eleitor
CREATE TABLE Eleitor (
    nif NVARCHAR(9) NOT NULL PRIMARY KEY,
    nome NVARCHAR(150) NOT NULL
);

-- 5. MesaDeVoto
CREATE TABLE MesaDeVoto (
    eleicao NVARCHAR(200) NOT NULL,
    num_mesa INT NOT NULL,
    localizacao NVARCHAR(200) NOT NULL,
    num_votantes INT NOT NULL DEFAULT 0,
    PRIMARY KEY (eleicao, num_mesa),
    FOREIGN KEY (eleicao) REFERENCES Eleicao(nome)
);

-- 6. Recenseamento (eleitor inscrito numa eleição, numa mesa)
CREATE TABLE Recenseamento (
    eleicao NVARCHAR(200) NOT NULL,
    nif NVARCHAR(9) NOT NULL,
    num_mesa INT NOT NULL,
    PRIMARY KEY (eleicao, nif),
    FOREIGN KEY (nif) REFERENCES Eleitor(nif),
    FOREIGN KEY (eleicao, num_mesa) REFERENCES MesaDeVoto(eleicao, num_mesa)
);

-- 7. Candidato (sigla_lista e posicao só preenchidos em eleições do tipo 'Lista')
CREATE TABLE Candidato (
    eleicao NVARCHAR(200) NOT NULL,
    nif NVARCHAR(9) NOT NULL,
    cargo NVARCHAR(100) NOT NULL,
    sigla_lista NVARCHAR(15) NULL,
    posicao INT NULL,
    PRIMARY KEY (eleicao, nif),
    UNIQUE (eleicao, nif, cargo),
    FOREIGN KEY (nif) REFERENCES Eleitor(nif),
    FOREIGN KEY (eleicao, cargo) REFERENCES Cargo(eleicao, cargo),
    FOREIGN KEY (eleicao, sigla_lista) REFERENCES Lista(eleicao, sigla),
    CONSTRAINT CK_Candidato_Lista_Posicao CHECK (
        (sigla_lista IS NULL AND posicao IS NULL)
        OR (sigla_lista IS NOT NULL AND posicao IS NOT NULL)
    )
);

-- 8. MembroMesa
CREATE TABLE MembroMesa (
    eleicao NVARCHAR(200) NOT NULL,
    num_mesa INT NOT NULL,
    nif NVARCHAR(9) NOT NULL,
    funcao NVARCHAR(100) NOT NULL,
    PRIMARY KEY (eleicao, num_mesa, nif),
    FOREIGN KEY (eleicao, num_mesa) REFERENCES MesaDeVoto(eleicao, num_mesa),
    FOREIGN KEY (nif) REFERENCES Eleitor(nif)
);

-- 9. RegistoVoto (a chave primária impede o duplo voto)
CREATE TABLE RegistoVoto (
    eleicao NVARCHAR(200) NOT NULL,
    nif NVARCHAR(9) NOT NULL,
    data_hora DATETIME NOT NULL DEFAULT GETDATE(),
    origem NVARCHAR(20) NOT NULL CHECK (origem IN ('Automatica', 'Manual')),
    PRIMARY KEY (eleicao, nif),
    FOREIGN KEY (eleicao, nif) REFERENCES Recenseamento(eleicao, nif)
);

-- 10. Voto (sem ligação ao eleitor; destino = lista OU candidato)
CREATE TABLE Voto (
    id_voto INT IDENTITY(1,1) PRIMARY KEY,
    eleicao NVARCHAR(200) NOT NULL,
    num_mesa INT NOT NULL,
    tipo_voto NVARCHAR(20) NOT NULL CHECK (tipo_voto IN ('Valido', 'Branco', 'Nulo')),
    cargo NVARCHAR(100) NULL,
    sigla_lista NVARCHAR(15) NULL,
    nif_candidato NVARCHAR(9) NULL,
    FOREIGN KEY (eleicao, num_mesa) REFERENCES MesaDeVoto(eleicao, num_mesa),
    FOREIGN KEY (eleicao, cargo) REFERENCES Cargo(eleicao, cargo),
    FOREIGN KEY (eleicao, sigla_lista) REFERENCES Lista(eleicao, sigla),
    FOREIGN KEY (eleicao, nif_candidato, cargo) REFERENCES Candidato(eleicao, nif, cargo),
    CONSTRAINT CK_Voto_Destino CHECK (
        (tipo_voto = 'Valido' AND (
               (sigla_lista IS NOT NULL AND nif_candidato IS NULL AND cargo IS NULL)
            OR (sigla_lista IS NULL AND nif_candidato IS NOT NULL AND cargo IS NOT NULL)
        ))
        OR (tipo_voto IN ('Branco', 'Nulo') AND sigla_lista IS NULL AND nif_candidato IS NULL)
    )
);

-- 11. ResultadoApuramento (linha sem lista nem candidato = total global)
CREATE TABLE ResultadoApuramento (
    id_resultado INT IDENTITY(1,1) PRIMARY KEY,
    eleicao NVARCHAR(200) NOT NULL,
    cargo NVARCHAR(100) NULL,
    sigla_lista NVARCHAR(15) NULL,
    nif_candidato NVARCHAR(9) NULL,
    num_votos INT NOT NULL DEFAULT 0,
    num_mandatos INT NOT NULL DEFAULT 0,
    FOREIGN KEY (eleicao) REFERENCES Eleicao(nome),
    FOREIGN KEY (eleicao, cargo) REFERENCES Cargo(eleicao, cargo),
    FOREIGN KEY (eleicao, sigla_lista) REFERENCES Lista(eleicao, sigla),
    FOREIGN KEY (eleicao, nif_candidato, cargo) REFERENCES Candidato(eleicao, nif, cargo),
    CHECK (sigla_lista IS NULL OR nif_candidato IS NULL)
);

-- 12. LogAutenticacao
CREATE TABLE LogAutenticacao (
    id_log INT IDENTITY(1,1) PRIMARY KEY,
    nif_tentativa NVARCHAR(20) NOT NULL,
    data_hora DATETIME NOT NULL DEFAULT GETDATE(),
    sucesso BIT NOT NULL,
    motivo_falha NVARCHAR(255) NULL,
    eleicao NVARCHAR(200) NOT NULL,
    num_mesa INT NOT NULL,
    FOREIGN KEY (eleicao, num_mesa) REFERENCES MesaDeVoto(eleicao, num_mesa)
);