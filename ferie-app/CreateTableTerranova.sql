CREATE TABLE Ruoli (
  codice INT PRIMARY KEY AUTO_INCREMENT,
  denominazione VARCHAR(20) NOT NULL
);

CREATE TABLE Gruppi (
  id INT PRIMARY KEY AUTO_INCREMENT,
  denominazione VARCHAR(20) NOT NULL
);

CREATE TABLE Utenti (
  matricola CHAR(10) PRIMARY KEY,
  nome VARCHAR(50) NOT NULL,
  cognome VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password VARCHAR(50) NOT NULL,
  cambioPassword BOOLEAN NOT NULL DEFAULT TRUE,
  responsabile BOOLEAN NOT NULL,
  codRuolo INT NOT NULL,
  idGruppo INT NOT NULL,
  FOREIGN KEY (codRuolo) REFERENCES Ruoli (codice),
  FOREIGN KEY (idGruppo) REFERENCES Gruppi (id)
);

ALTER TABLE Gruppi
ADD COLUMN matricolaResp CHAR(10) DEFAULT NULL, ADD FOREIGN KEY (matricolaResp) REFERENCES Utenti (matricola);

CREATE TABLE RichiesteFerie (
  id INT PRIMARY KEY AUTO_INCREMENT,
  stato VARCHAR(15) NOT NULL,
  inizio DATE NOT NULL,
  fine DATE NOT NULL,
  matrUtente CHAR(10) NOT NULL,
  dataOraIns DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  matrResp CHAR(10) NOT NULL,
  FOREIGN KEY (matrUtente) REFERENCES Utenti (matricola),
  FOREIGN KEY (matrResp) REFERENCES Utenti (matricola),
  CHECK (fine >= inizio),
  CHECK (stato = 'Approvato' OR stato = 'Rifiutato' OR stato = 'In attesa')
);

CREATE TABLE Commenti (
  id INT PRIMARY KEY AUTO_INCREMENT,
  testo TEXT NOT NULL,
  matrUtente CHAR(10) NOT NULL,
  dataOraIns DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  idRichiesta INT NOT NULL,
  FOREIGN KEY (matrUtente) REFERENCES Utenti (matricola),
  FOREIGN KEY (idRichiesta) REFERENCES RichiesteFerie (id)
);

CREATE TABLE Vincoli (
  id INT PRIMARY KEY AUTO_INCREMENT,
  inizio DATE NOT NULL,
  fine DATE NOT NULL,
  tipoPeriodo VARCHAR(15) NOT NULL,
  minG INT,
  maxG INT,
  nMin INT,
  percMin DECIMAL(5, 2),
  minGCons INT,
  maxGCons INT,
  -- CHECK (inizio > CURRENT_DATE() AND fine >= inizio),
  CHECK (percMin >= 0 AND percMin <= 100),
  CHECK (nMin >= 0),
  CHECK (minGCons >= 0 AND maxGCons >= minGCons),
  CHECK (minG >= 0 AND maxG >= minG),
  CHECK (tipoPeriodo = 'Bloccato' OR tipoPeriodo = 'Sconsigliato')
);

CREATE TABLE Limitazioni (
  id INT PRIMARY KEY AUTO_INCREMENT,
  idVincolo INT NOT NULL,
  idGruppo INT,
  codRuolo INT,
  FOREIGN KEY (idVincolo) REFERENCES Vincoli (id),
  FOREIGN KEY (idGruppo) REFERENCES Gruppi (id),
  FOREIGN KEY (codRuolo) REFERENCES Ruoli (codice)
);