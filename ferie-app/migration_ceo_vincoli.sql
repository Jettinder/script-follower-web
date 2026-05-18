-- ============================================================================
--  migration_ceo_vincoli.sql
--  Migration: ruolo CEO + dati di esempio per il sistema Vincoli.
--  - NON ricrea le tabelle esistenti: solo ALTER + INSERT.
--  - Idempotente dove possibile (procedura di guardia per la colonna,
--    INSERT IGNORE per i dati di seed).
--  Eseguire su TerranovaDB DOPO CreateTableTerranova.sql.
-- ============================================================================

-- ── 1. Nuova colonna `ceo` su Utenti (in aggiunta a `responsabile`) ─────────
--  MySQL non supporta ADD COLUMN IF NOT EXISTS in modo portabile:
--  usiamo una procedura di guardia che controlla INFORMATION_SCHEMA.
DROP PROCEDURE IF EXISTS _migr_add_ceo_column;
DELIMITER $$
CREATE PROCEDURE _migr_add_ceo_column()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'Utenti'
      AND COLUMN_NAME  = 'ceo'
  ) THEN
    ALTER TABLE Utenti
      ADD COLUMN ceo BOOLEAN NOT NULL DEFAULT FALSE AFTER responsabile;
  END IF;
END$$
DELIMITER ;
CALL _migr_add_ceo_column();
DROP PROCEDURE IF EXISTS _migr_add_ceo_column;

-- ── 2. Dati di esempio per test ─────────────────────────────────────────────
--  Ruolo e gruppo dedicati alla direzione (id espliciti per riproducibilità).
INSERT IGNORE INTO Ruoli (codice, denominazione) VALUES (99, 'Dirigente');
INSERT IGNORE INTO Gruppi (id, denominazione)    VALUES (99, 'Direzione');

--  Utente CEO seedato.
--  responsabile = FALSE: il CEO è un livello a sé; i permessi di responsabile
--  sono comunque coperti dal decoratore @ceo_o_responsabile lato backend.
--  password in chiaro per coerenza con lo schema attuale (campo Utenti.password).
INSERT IGNORE INTO Utenti
  (matricola, nome, cognome, email, password, cambioPassword, responsabile, ceo, codRuolo, idGruppo)
VALUES
  ('CEO0000001', 'Aldo', 'Direttore', 'ceo@terranova.it', 'ceo123', FALSE, FALSE, TRUE, 99, 99);

-- ── 3. Vincoli di esempio ───────────────────────────────────────────────────
--  Vincolo 1: periodo bloccato GLOBALE (nessuna riga in Limitazioni → tutti).
INSERT IGNORE INTO Vincoli
  (id, inizio, fine, tipoPeriodo, minG, maxG, nMin, percMin, minGCons, maxGCons)
VALUES
  (1, '2026-08-01', '2026-08-15', 'Bloccato', NULL, NULL, NULL, NULL, NULL, NULL);

--  Vincolo 2: periodo sconsigliato limitato al gruppo Direzione (id 99).
INSERT IGNORE INTO Vincoli
  (id, inizio, fine, tipoPeriodo, minG, maxG, nMin, percMin, minGCons, maxGCons)
VALUES
  (2, '2026-12-20', '2026-12-31', 'Sconsigliato', NULL, NULL, NULL, NULL, NULL, NULL);

--  Limitazione del vincolo 2: solo gruppo 99, tutti i ruoli (codRuolo NULL).
INSERT IGNORE INTO Limitazioni (id, idVincolo, idGruppo, codRuolo)
VALUES (1, 2, 99, NULL);

-- ============================================================================
--  Note:
--  - Il DELETE di un vincolo gestisce il cascade su Limitazioni lato backend
--    (DELETE FROM Limitazioni WHERE idVincolo = ... dentro la stessa
--    transazione), quindi NON viene aggiunto ON DELETE CASCADE allo schema.
-- ============================================================================
