# CHANGELOG — FerieApp / ProgettoTerranova

Riepilogo delle modifiche per l'introduzione del ruolo **CEO** e del
**sistema Vincoli**.

## Database

- **`migration_ceo_vincoli.sql`** (nuovo): aggiunge la colonna
  `ceo BOOLEAN NOT NULL DEFAULT FALSE` alla tabella `Utenti` tramite una
  procedura di guardia idempotente (controllo su `INFORMATION_SCHEMA`).
  Nessuna tabella esistente viene ricreata.
- Dati di esempio (`INSERT IGNORE`): ruolo "Dirigente", gruppo "Direzione",
  un utente CEO seedato (`ceo@terranova.it` / `ceo123`) e due vincoli di
  test (uno bloccato globale, uno sconsigliato limitato a un gruppo).

## Backend (`app.py`)

- Payload JWT esteso con il flag `ceo` (`crea_token` + `login`).
- Nuovi decoratori: `@solo_ceo` e `@ceo_o_responsabile`.
- **Vincoli** — nuovi endpoint `GET/POST/PUT/DELETE /api/vincoli`:
  - logica `Limitazioni`: 0 righe = vincolo globale; `idGruppo`/`codRuolo`
    `NULL` = "tutti"; più righe = unione (OR);
  - validazione dei `CHECK` del DB lato Python prima dell'INSERT;
  - transazioni (Vincoli + Limitazioni) con `rollback` su errore;
  - il **responsabile** può creare/modificare/eliminare solo vincoli
    limitati al proprio gruppo (forzatura lato server, 403 altrimenti).
- **Gestione personale (solo CEO)**: `GET/POST /api/utenti`,
  `PUT /api/utenti/<matricola>`, `GET/POST /api/gruppi`,
  `PUT /api/gruppi/<id>`.
- `GET /api/ruoli` (autenticato) per le dropdown.
- `GET /api/ferie` e `PUT /api/ferie/<id>/approva` ora accessibili anche al
  CEO, su tutti i gruppi (con filtro `gruppo` opzionale); i commenti sono
  accessibili al CEO su qualsiasi richiesta.
- `POST /api/ferie` verifica i vincoli applicabili: periodo **Bloccato**
  → `422`; periodo **Sconsigliato** → richiesta accettata con campo
  `avvisi` nella response. Helper `verifica_vincoli(matricola, inizio,
  fine, conn)` predisposto per i futuri controlli quantitativi
  (`minG`/`maxG`/`nMin`/`percMin`/`minGCons`/`maxGCons`, lasciati come TODO).

## Frontend

- **`index.html`**: nuova pagina `#page-ceo` (tab Dashboard, Gruppi,
  Personale, Ferie, Vincoli); sezione Vincoli nelle pagine Dipendente
  (sola lettura) e Responsabile (creazione limitata al gruppo); calendario
  in tutte e tre le pagine; modal generico.
- **`app.js`**: login con instradamento al ruolo CEO; caricamento vincoli;
  rendering vincoli condiviso; pre-compilazione date ferie dal calendario.
- **`calendar.js`** (nuovo): calendario mensile vanilla JS (griglia 7×N,
  navigazione mese, colori per stato ferie/vincolo, popover di dettaglio).
- **`ceo.js`** (nuovo): logica della pagina CEO (dashboard con contatori,
  CRUD gruppi/utenti via modal, ferie di tutti i gruppi, CRUD vincoli con
  multi-select gruppi/ruoli).
- **`style.css`**: nuovi componenti (calendario, tabelle dati, modal,
  badge CEO, badge stato vincoli, dashboard, toolbar) coerenti col design
  system; sezione responsive per schermi stretti.

## Note tecniche

- **`:root` in `style.css`**: le variabili `--color-*`, `--border-radius-*`
  e `--font-sans` erano referenziate ma non definite in alcun file. È stato
  aggiunto un blocco `:root` con i token mancanti, così l'app è
  effettivamente stilizzata. Sostituibile con il design system reale se
  fornito altrove.
- **Tabler Icons via CDN**: il markup usa le classi `ti ti-*` ma il webfont
  non era incluso. È stato aggiunto il `<link>` al CDN di
  `@tabler/icons-webfont`. È l'unica dipendenza esterna nuova; rimuoverla se
  il font è già servito localmente nell'ambiente di produzione.
- Nessuna nuova dipendenza Python: il backend resta su Flask +
  mysql-connector + PyJWT.
