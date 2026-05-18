from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
from functools import wraps
import jwt
import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = 'chiavesegretasegretissima'

CORS(app, resources={r"/api/*": {"origins": ["http://localhost", "http://127.0.0.1", "null"]}})

DB_CONFIG = {
    'host': 'localhost',
    'database': 'TerranovaDB',
    'user': 'root',
    'password': '',
    'port': 3306
}


def get_db():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        raise RuntimeError(f"Errore connessione DB: {e}")


def crea_token(matricola: str, is_responsabile: bool, is_ceo: bool = False) -> str:
    payload = {
        'matricola': matricola,
        'responsabile': is_responsabile,
        'ceo': is_ceo,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=8)
    }
    return jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')


def richiede_token(f):
    """Decorator: verifica il JWT nell'header Authorization."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            return jsonify({'errore': 'Token mancante'}), 401
        token = auth.split(' ', 1)[1]
        try:
            payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            request.utente_corrente = payload
        except jwt.ExpiredSignatureError:
            return jsonify({'errore': 'Token scaduto'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'errore': 'Token non valido'}), 401
        return f(*args, **kwargs)
    return wrapper


def solo_responsabile(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not request.utente_corrente.get('responsabile'):
            return jsonify({'errore': 'Accesso negato: solo per responsabili'}), 403
        return f(*args, **kwargs)
    return wrapper


def solo_ceo(f):
    """Decorator: consente l'accesso solo agli utenti con flag ceo."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not request.utente_corrente.get('ceo'):
            return jsonify({'errore': 'Accesso negato: solo per il CEO'}), 403
        return f(*args, **kwargs)
    return wrapper


def ceo_o_responsabile(f):
    """Decorator per route condivise: ammette responsabili e CEO."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        u = request.utente_corrente
        if not (u.get('ceo') or u.get('responsabile')):
            return jsonify({'errore': 'Accesso negato: solo per responsabili o CEO'}), 403
        return f(*args, **kwargs)
    return wrapper


# ─────────────────────────────────────────
#  HELPER: logica Vincoli / Limitazioni
# ─────────────────────────────────────────

def _limitazioni_per_vincoli(cur, ids):
    """Carica le righe Limitazioni per un insieme di idVincolo.
    Ritorna {idVincolo: [ {id, idVincolo, idGruppo, codRuolo}, ... ]}."""
    if not ids:
        return {}
    ph = ', '.join(['%s'] * len(ids))
    cur.execute(
        f'SELECT id, idVincolo, idGruppo, codRuolo FROM Limitazioni WHERE idVincolo IN ({ph})',
        list(ids)
    )
    out = {}
    for r in cur.fetchall():
        out.setdefault(r['idVincolo'], []).append(r)
    return out


def _vincolo_applicabile(limitazioni, id_gruppo, cod_ruolo):
    """True se il vincolo si applica all'utente (gruppo + ruolo).
    Nessuna limitazione = vale per tutti. Più righe = unione (OR)."""
    if not limitazioni:
        return True
    for l in limitazioni:
        gruppo_ok = l['idGruppo'] is None or l['idGruppo'] == id_gruppo
        ruolo_ok = l['codRuolo'] is None or l['codRuolo'] == cod_ruolo
        if gruppo_ok and ruolo_ok:
            return True
    return False


def _vincolo_visibile_gruppo(limitazioni, id_gruppo):
    """True se il vincolo riguarda il gruppo indicato o è globale.
    Usato per la visibilità lato responsabile (ignora il ruolo)."""
    if not limitazioni:
        return True
    for l in limitazioni:
        if l['idGruppo'] is None or l['idGruppo'] == id_gruppo:
            return True
    return False


def _vincolo_solo_gruppo(limitazioni, id_gruppo):
    """True se il vincolo è limitato ESCLUSIVAMENTE al gruppo indicato
    (nessuna riga globale). Usato per i permessi di modifica/eliminazione
    del responsabile."""
    if not limitazioni:
        return False
    return all(l['idGruppo'] == id_gruppo for l in limitazioni)


def _valida_campi_vincolo(d):
    """Valida i campi di un vincolo replicando i CHECK del DB.
    Ritorna una stringa di errore oppure None se tutto ok."""
    if d.get('tipoPeriodo') not in ('Bloccato', 'Sconsigliato'):
        return "Il campo tipoPeriodo deve essere 'Bloccato' o 'Sconsigliato'"
    inizio, fine = d.get('inizio'), d.get('fine')
    if not inizio or not fine:
        return 'Campi inizio e fine obbligatori'
    if fine < inizio:
        return 'La data fine deve essere uguale o successiva alla data inizio'

    minG, maxG = d.get('minG'), d.get('maxG')
    nMin, percMin = d.get('nMin'), d.get('percMin')
    minGC, maxGC = d.get('minGCons'), d.get('maxGCons')

    if minG is not None and minG < 0:
        return 'minG deve essere >= 0'
    if maxG is not None and maxG < 0:
        return 'maxG deve essere >= 0'
    if minG is not None and maxG is not None and maxG < minG:
        return 'maxG deve essere >= minG'
    if nMin is not None and nMin < 0:
        return 'nMin deve essere >= 0'
    if percMin is not None and (percMin < 0 or percMin > 100):
        return 'percMin deve essere compreso tra 0 e 100'
    if minGC is not None and minGC < 0:
        return 'minGCons deve essere >= 0'
    if minGC is not None and maxGC is not None and maxGC < minGC:
        return 'maxGCons deve essere >= minGCons'
    return None


def _normalizza_limitazioni(limitazioni, is_ceo, gruppo_resp):
    """Applica le regole di permesso sulle Limitazioni.
    CEO: qualsiasi combinazione (anche array vuoto = vincolo globale).
    Responsabile: ogni riga DEVE avere idGruppo = suo gruppo; vietato il
    vincolo globale.
    Ritorna (errore_str, limitazioni_normalizzate)."""
    limitazioni = limitazioni or []
    if is_ceo:
        norm = []
        for l in limitazioni:
            g = l.get('idGruppo')
            r = l.get('codRuolo')
            norm.append({
                'idGruppo': g if g not in ('', None) else None,
                'codRuolo': r if r not in ('', None) else None
            })
        return None, norm

    # Responsabile
    if not limitazioni:
        return ('Un responsabile deve limitare il vincolo al proprio gruppo', None)
    norm = []
    for l in limitazioni:
        if l.get('idGruppo') != gruppo_resp:
            return ('Un responsabile può creare vincoli solo per il proprio gruppo', None)
        r = l.get('codRuolo')
        norm.append({'idGruppo': gruppo_resp,
                     'codRuolo': r if r not in ('', None) else None})
    return None, norm


def verifica_vincoli(matricola, inizio, fine, conn):
    """Verifica i vincoli applicabili a un utente nel periodo [inizio, fine].

    Ritorna (violazioni, avvisi):
      - violazioni: vincoli 'Bloccato' applicabili che si sovrappongono al
        periodo richiesto (la richiesta ferie va rifiutata).
      - avvisi: vincoli 'Sconsigliato' applicabili (la richiesta passa ma
        viene segnalata).

    TODO: controlli quantitativi su minG/maxG (durata richiesta),
    nMin/percMin (numero minimo di presenti nel gruppo) e
    minGCons/maxGCons (giorni consecutivi). La struttura è già pronta:
    basta estendere i due rami sotto leggendo gli omonimi campi del vincolo.
    """
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute('SELECT idGruppo, codRuolo FROM Utenti WHERE matricola = %s', (matricola,))
        u = cur.fetchone()
        if not u:
            return [], []

        # Sovrapposizione di intervalli: v.inizio <= fine_req AND v.fine >= inizio_req
        cur.execute(
            '''SELECT id, inizio, fine, tipoPeriodo
               FROM Vincoli
               WHERE inizio <= %s AND fine >= %s''',
            (fine, inizio)
        )
        vincoli = cur.fetchall()
        lim = _limitazioni_per_vincoli(cur, [v['id'] for v in vincoli])

        violazioni, avvisi = [], []
        for v in vincoli:
            if not _vincolo_applicabile(lim.get(v['id'], []), u['idGruppo'], u['codRuolo']):
                continue
            info = {
                'id': v['id'],
                'inizio': str(v['inizio']),
                'fine': str(v['fine']),
                'tipoPeriodo': v['tipoPeriodo']
            }
            if v['tipoPeriodo'] == 'Bloccato':
                violazioni.append(info)
            elif v['tipoPeriodo'] == 'Sconsigliato':
                avvisi.append(info)
        return violazioni, avvisi
    finally:
        cur.close()


# ─────────────────────────────────────────
#  ROUTE: Login
#  Body JSON: { "email": "...", "password": "..." }
#  - Le credenziali sono ora direttamente in Utenti (non in una tabella login separata)
# ─────────────────────────────────────────
@app.route('/api/login', methods=['POST'])
def login():
    dati = request.get_json(force=True) or {}
    email = dati.get('email', '').strip()
    password = dati.get('password', '').strip()

    if not email or not password:
        return jsonify({'errore': 'Email e password obbligatorie'}), 400

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        # Credenziali ora in Utenti direttamente
        cur.execute(
            '''SELECT matricola, nome, cognome, responsabile, ceo, idGruppo, cambioPassword
               FROM Utenti
               WHERE email = %s AND password = %s''',
            (email, password)
        )
        utente = cur.fetchone()
        if not utente:
            return jsonify({'errore': 'Credenziali non valide'}), 401

        matricola = utente['matricola']
        is_resp = bool(utente['responsabile'])
        is_ceo = bool(utente['ceo'])
        token = crea_token(matricola, is_resp, is_ceo)

        return jsonify({
            'token': token,
            'matricola': matricola,
            'nome': utente['nome'],
            'cognome': utente['cognome'],
            'responsabile': is_resp,
            'ceo': is_ceo,
            'idGruppo': utente['idGruppo'],
            'cambioPassword': bool(utente['cambioPassword'])
        })

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close()
            conn.close()


# ─────────────────────────────────────────
#  ROUTE: Membri del gruppo dell'utente corrente
# ─────────────────────────────────────────
@app.route('/api/gruppo/membri', methods=['GET'])
@richiede_token
def membri_gruppo():
    matricola = request.utente_corrente['matricola']

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
        row = cur.fetchone()
        if not row:
            return jsonify({'errore': 'Utente non trovato'}), 404

        id_gruppo = row['idGruppo']

        cur.execute(
            '''SELECT u.matricola, u.nome, u.cognome, u.responsabile, u.ceo,
                      r.denominazione AS ruolo,
                      g.denominazione AS gruppo
               FROM Utenti u
               JOIN Ruoli r ON u.codRuolo = r.codice
               JOIN Gruppi g ON u.idGruppo = g.id
               WHERE u.idGruppo = %s''',
            (id_gruppo,)
        )
        membri = cur.fetchall()
        for m in membri:
            m['responsabile'] = bool(m['responsabile'])
            m['ceo'] = bool(m['ceo'])

        return jsonify({'idGruppo': id_gruppo, 'membri': membri})

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close()
            conn.close()


# ─────────────────────────────────────────
#  ROUTE: Ferie proprie del dipendente
# ─────────────────────────────────────────
@app.route('/api/ferie/mie', methods=['GET'])
@richiede_token
def mie_ferie():
    matricola = request.utente_corrente['matricola']

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute(
            '''SELECT id, stato, inizio, fine, dataOraIns
               FROM RichiesteFerie
               WHERE matrUtente = %s
               ORDER BY dataOraIns DESC''',
            (matricola,)
        )
        ferie = cur.fetchall()
        for f in ferie:
            for k in ('inizio', 'fine', 'dataOraIns'):
                if f[k] is not None:
                    f[k] = str(f[k])

        return jsonify({'ferie': ferie})

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close()
            conn.close()


# ─────────────────────────────────────────
#  ROUTE: Tutte le ferie (responsabile = suo gruppo, CEO = tutti)
# ─────────────────────────────────────────
@app.route('/api/ferie', methods=['GET'])
@richiede_token
@ceo_o_responsabile
def richieste_ferie():
    is_ceo = request.utente_corrente.get('ceo', False)
    matricola_resp = request.utente_corrente['matricola']
    filtro_matr = request.args.get('matricola')
    filtro_stato = request.args.get('stato')    # opzionale
    filtro_gruppo = request.args.get('gruppo')  # opzionale, usato dal CEO

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        query = '''
            SELECT r.id, r.stato, r.inizio, r.fine,
                   r.matrUtente, r.dataOraIns, r.matrResp,
                   u.nome, u.cognome, u.idGruppo,
                   g.denominazione AS gruppo
            FROM RichiesteFerie r
            JOIN Utenti u ON r.matrUtente = u.matricola
            JOIN Gruppi g ON u.idGruppo = g.id
        '''
        condizioni = []
        params = []

        if is_ceo:
            # Il CEO vede tutte le richieste; filtro gruppo opzionale.
            if filtro_gruppo:
                condizioni.append('u.idGruppo = %s')
                params.append(filtro_gruppo)
        else:
            # Responsabile: solo le richieste del proprio gruppo.
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola_resp,))
            row = cur.fetchone()
            if not row:
                return jsonify({'errore': 'Responsabile non trovato'}), 404
            condizioni.append('u.idGruppo = %s')
            params.append(row['idGruppo'])

        if filtro_matr:
            condizioni.append('r.matrUtente = %s')
            params.append(filtro_matr)

        if filtro_stato in ('In attesa', 'Approvato', 'Rifiutato'):
            condizioni.append('r.stato = %s')
            params.append(filtro_stato)

        if condizioni:
            query += ' WHERE ' + ' AND '.join(condizioni)
        query += ' ORDER BY r.dataOraIns DESC'

        cur.execute(query, params)
        ferie = cur.fetchall()

        for f in ferie:
            for k in ('inizio', 'fine', 'dataOraIns'):
                if f[k] is not None:
                    f[k] = str(f[k])

        return jsonify({'ferie': ferie, 'totale': len(ferie)})

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close()
            conn.close()


# ─────────────────────────────────────────
#  ROUTE: Approva / rifiuta una richiesta ferie
#  Body JSON: { "stato": "Approvato" }  oppure  { "stato": "Rifiutato" }
#  - Responsabile: solo richieste del suo gruppo. CEO: qualsiasi gruppo.
# ─────────────────────────────────────────
@app.route('/api/ferie/<int:id_ferie>/approva', methods=['PUT'])
@richiede_token
@ceo_o_responsabile
def approva_ferie(id_ferie):
    dati = request.get_json(force=True) or {}
    nuovo_stato = dati.get('stato')

    # Il CHECK del DB accetta solo questi tre valori; qui blocchiamo i due di interesse
    if nuovo_stato not in ('Approvato', 'Rifiutato'):
        return jsonify({'errore': "Il campo stato deve essere 'Approvato' o 'Rifiutato'"}), 400

    is_ceo = request.utente_corrente.get('ceo', False)
    matricola_resp = request.utente_corrente['matricola']

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        if is_ceo:
            cur.execute('SELECT id, stato FROM RichiesteFerie WHERE id = %s', (id_ferie,))
            richiesta = cur.fetchone()
        else:
            # Verifica che la richiesta appartenga a un membro del gruppo del responsabile
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola_resp,))
            row = cur.fetchone()
            if not row:
                return jsonify({'errore': 'Responsabile non trovato'}), 404
            cur.execute(
                '''SELECT r.id, r.stato FROM RichiesteFerie r
                   JOIN Utenti u ON r.matrUtente = u.matricola
                   WHERE r.id = %s AND u.idGruppo = %s''',
                (id_ferie, row['idGruppo'])
            )
            richiesta = cur.fetchone()

        if not richiesta:
            return jsonify({'errore': 'Richiesta non trovata o non di tua competenza'}), 404

        if richiesta['stato'] != 'In attesa':
            return jsonify({'errore': f"Richiesta già gestita (stato attuale: {richiesta['stato']})"}), 409

        cur.execute(
            'UPDATE RichiesteFerie SET stato = %s, matrResp = %s WHERE id = %s',
            (nuovo_stato, matricola_resp, id_ferie)
        )
        conn.commit()

        return jsonify({'messaggio': f'Richiesta {id_ferie} impostata a "{nuovo_stato}"'})

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close()
            conn.close()


# ─────────────────────────────────────────
#  ROUTE: Inserisci nuova richiesta ferie
#  Body JSON: { "inizio": "YYYY-MM-DD", "fine": "YYYY-MM-DD" }
#  - stato iniziale sempre "In attesa"
#  - matrResp viene recuperato dal gruppo (NOT NULL nel DB)
#  - verifica i Vincoli: blocco -> 422, sconsigliato -> avvisi nella response
# ─────────────────────────────────────────
@app.route('/api/ferie', methods=['POST'])
@richiede_token
def inserisci_ferie():
    dati = request.get_json(force=True) or {}
    inizio = dati.get('inizio')
    fine = dati.get('fine')

    if not inizio or not fine:
        return jsonify({'errore': 'Campi inizio e fine obbligatori'}), 400

    if fine < inizio:
        return jsonify({'errore': 'La data fine deve essere uguale o successiva alla data inizio'}), 400

    matricola = request.utente_corrente['matricola']

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        # Verifica dei vincoli applicabili nel periodo richiesto
        violazioni, avvisi = verifica_vincoli(matricola, inizio, fine, conn)
        if violazioni:
            dettagli = '; '.join(f"{v['inizio']} → {v['fine']}" for v in violazioni)
            return jsonify({
                'errore': f'Le date richieste rientrano in un periodo bloccato: {dettagli}',
                'violazioni': violazioni
            }), 422

        # matrResp è NOT NULL nel DB: recuperiamo il responsabile del gruppo
        cur.execute(
            '''SELECT g.matricolaResp FROM Utenti u
               JOIN Gruppi g ON u.idGruppo = g.id
               WHERE u.matricola = %s''',
            (matricola,)
        )
        row = cur.fetchone()
        if not row or not row['matricolaResp']:
            return jsonify({'errore': 'Nessun responsabile associato al tuo gruppo'}), 422

        matr_resp = row['matricolaResp']

        cur.execute(
            '''INSERT INTO RichiesteFerie (stato, inizio, fine, matrUtente, dataOraIns, matrResp)
               VALUES ('In attesa', %s, %s, %s, NOW(), %s)''',
            (inizio, fine, matricola, matr_resp)
        )
        conn.commit()
        nuovo_id = cur.lastrowid

        risposta = {'messaggio': 'Richiesta inserita', 'id': nuovo_id}
        if avvisi:
            dettagli = '; '.join(f"{a['inizio']} → {a['fine']}" for a in avvisi)
            risposta['avvisi'] = [
                f'Le date richieste rientrano in un periodo sconsigliato: {dettagli}'
            ]
        return jsonify(risposta), 201

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close()
            conn.close()


# ─────────────────────────────────────────
#  ROUTE: Leggi commenti di una richiesta ferie
# ─────────────────────────────────────────
@app.route('/api/ferie/<int:id_ferie>/commenti', methods=['GET'])
@richiede_token
def get_commenti(id_ferie):
    matricola = request.utente_corrente['matricola']
    is_resp = request.utente_corrente.get('responsabile', False)
    is_ceo = request.utente_corrente.get('ceo', False)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.execute('SELECT matrUtente, matrResp FROM RichiesteFerie WHERE id = %s', (id_ferie,))
        richiesta = cur.fetchone()
        if not richiesta:
            return jsonify({'errore': 'Richiesta non trovata'}), 404
        if not is_resp and not is_ceo and richiesta['matrUtente'] != matricola:
            return jsonify({'errore': 'Accesso negato'}), 403
        if is_resp and not is_ceo:
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
            r1 = cur.fetchone()
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (richiesta['matrUtente'],))
            r2 = cur.fetchone()
            if not r2 or r2['idGruppo'] != r1['idGruppo']:
                return jsonify({'errore': 'Accesso negato: richiesta non del tuo gruppo'}), 403
        cur.execute(
            '''SELECT c.id, c.testo, c.dataOraIns, u.nome, u.cognome, u.responsabile, u.ceo
               FROM Commenti c
               JOIN Utenti u ON c.matrUtente = u.matricola
               WHERE c.idRichiesta = %s
               ORDER BY c.dataOraIns ASC''',
            (id_ferie,)
        )
        commenti = cur.fetchall()
        for c in commenti:
            c['dataOraIns'] = str(c['dataOraIns'])
            c['responsabile'] = bool(c['responsabile'])
            c['ceo'] = bool(c['ceo'])
        return jsonify({'commenti': commenti, 'totale': len(commenti)})
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


# ─────────────────────────────────────────
#  ROUTE: Inserisci un commento su una richiesta ferie
# ─────────────────────────────────────────
@app.route('/api/ferie/<int:id_ferie>/commenti', methods=['POST'])
@richiede_token
def post_commento(id_ferie):
    dati = request.get_json(force=True) or {}
    testo = dati.get('testo', '').strip()
    if not testo:
        return jsonify({'errore': 'Il testo del commento e obbligatorio'}), 400
    matricola = request.utente_corrente['matricola']
    is_resp = request.utente_corrente.get('responsabile', False)
    is_ceo = request.utente_corrente.get('ceo', False)
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.execute('SELECT matrUtente FROM RichiesteFerie WHERE id = %s', (id_ferie,))
        richiesta = cur.fetchone()
        if not richiesta:
            return jsonify({'errore': 'Richiesta non trovata'}), 404
        if not is_resp and not is_ceo and richiesta['matrUtente'] != matricola:
            return jsonify({'errore': 'Accesso negato'}), 403
        if is_resp and not is_ceo:
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
            r1 = cur.fetchone()
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (richiesta['matrUtente'],))
            r2 = cur.fetchone()
            if not r2 or r2['idGruppo'] != r1['idGruppo']:
                return jsonify({'errore': 'Accesso negato: richiesta non del tuo gruppo'}), 403
        cur.execute(
            'INSERT INTO Commenti (testo, matrUtente, idRichiesta) VALUES (%s, %s, %s)',
            (testo, matricola, id_ferie)
        )
        conn.commit()
        return jsonify({'messaggio': 'Commento inserito', 'id': cur.lastrowid}), 201
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


# ═════════════════════════════════════════
#  ROUTE: Ruoli (lista, per le dropdown)
# ═════════════════════════════════════════
@app.route('/api/ruoli', methods=['GET'])
@richiede_token
def lista_ruoli():
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.execute('SELECT codice, denominazione FROM Ruoli ORDER BY denominazione')
        return jsonify({'ruoli': cur.fetchall()})
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


# ═════════════════════════════════════════
#  ROUTE: Gruppi
#  - GET: CEO tutti i gruppi; responsabile/dipendente solo il proprio.
#  - POST/PUT: solo CEO.
# ═════════════════════════════════════════
@app.route('/api/gruppi', methods=['GET'])
@richiede_token
def lista_gruppi():
    is_ceo = request.utente_corrente.get('ceo', False)
    matricola = request.utente_corrente['matricola']
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        query = '''
            SELECT g.id, g.denominazione, g.matricolaResp,
                   r.nome AS nomeResp, r.cognome AS cognomeResp,
                   (SELECT COUNT(*) FROM Utenti u WHERE u.idGruppo = g.id) AS numMembri
            FROM Gruppi g
            LEFT JOIN Utenti r ON g.matricolaResp = r.matricola
        '''
        if is_ceo:
            cur.execute(query + ' ORDER BY g.denominazione')
        else:
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
            row = cur.fetchone()
            if not row:
                return jsonify({'errore': 'Utente non trovato'}), 404
            cur.execute(query + ' WHERE g.id = %s', (row['idGruppo'],))

        return jsonify({'gruppi': cur.fetchall()})
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


@app.route('/api/gruppi', methods=['POST'])
@richiede_token
@solo_ceo
def crea_gruppo():
    dati = request.get_json(force=True) or {}
    denominazione = (dati.get('denominazione') or '').strip()
    matricola_resp = dati.get('matricolaResp') or None

    if not denominazione:
        return jsonify({'errore': 'Il campo denominazione è obbligatorio'}), 400

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        cur.execute(
            'INSERT INTO Gruppi (denominazione, matricolaResp) VALUES (%s, %s)',
            (denominazione, matricola_resp)
        )
        conn.commit()
        return jsonify({'messaggio': 'Gruppo creato', 'id': cur.lastrowid}), 201
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    except Error as e:
        return jsonify({'errore': f'Errore database: {e}'}), 409
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


@app.route('/api/gruppi/<int:id_gruppo>', methods=['PUT'])
@richiede_token
@solo_ceo
def modifica_gruppo(id_gruppo):
    dati = request.get_json(force=True) or {}
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT id FROM Gruppi WHERE id = %s', (id_gruppo,))
        if not cur.fetchone():
            return jsonify({'errore': 'Gruppo non trovato'}), 404

        campi, params = [], []
        if 'denominazione' in dati:
            denom = (dati.get('denominazione') or '').strip()
            if not denom:
                return jsonify({'errore': 'La denominazione non può essere vuota'}), 400
            campi.append('denominazione = %s')
            params.append(denom)
        if 'matricolaResp' in dati:
            campi.append('matricolaResp = %s')
            params.append(dati.get('matricolaResp') or None)

        if not campi:
            return jsonify({'errore': 'Nessun campo da aggiornare'}), 400

        params.append(id_gruppo)
        cur.execute(f'UPDATE Gruppi SET {", ".join(campi)} WHERE id = %s', params)
        conn.commit()
        return jsonify({'messaggio': f'Gruppo {id_gruppo} aggiornato'})
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    except Error as e:
        return jsonify({'errore': f'Errore database: {e}'}), 409
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


# ═════════════════════════════════════════
#  ROUTE: Utenti (gestione personale, solo CEO)
# ═════════════════════════════════════════
@app.route('/api/utenti', methods=['GET'])
@richiede_token
@solo_ceo
def lista_utenti():
    filtro_gruppo = request.args.get('gruppo')
    filtro_ruolo = request.args.get('ruolo')
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)
        query = '''
            SELECT u.matricola, u.nome, u.cognome, u.email,
                   u.responsabile, u.ceo, u.cambioPassword,
                   u.codRuolo, u.idGruppo,
                   r.denominazione AS ruolo,
                   g.denominazione AS gruppo
            FROM Utenti u
            JOIN Ruoli r ON u.codRuolo = r.codice
            JOIN Gruppi g ON u.idGruppo = g.id
        '''
        condizioni, params = [], []
        if filtro_gruppo:
            condizioni.append('u.idGruppo = %s')
            params.append(filtro_gruppo)
        if filtro_ruolo:
            condizioni.append('u.codRuolo = %s')
            params.append(filtro_ruolo)
        if condizioni:
            query += ' WHERE ' + ' AND '.join(condizioni)
        query += ' ORDER BY u.cognome, u.nome'

        cur.execute(query, params)
        utenti = cur.fetchall()
        for u in utenti:
            u['responsabile'] = bool(u['responsabile'])
            u['ceo'] = bool(u['ceo'])
            u['cambioPassword'] = bool(u['cambioPassword'])
        return jsonify({'utenti': utenti, 'totale': len(utenti)})
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


@app.route('/api/utenti', methods=['POST'])
@richiede_token
@solo_ceo
def crea_utente():
    dati = request.get_json(force=True) or {}
    matricola = (dati.get('matricola') or '').strip()
    nome = (dati.get('nome') or '').strip()
    cognome = (dati.get('cognome') or '').strip()
    email = (dati.get('email') or '').strip()
    password = (dati.get('password') or '').strip()
    cod_ruolo = dati.get('codRuolo')
    id_gruppo = dati.get('idGruppo')
    responsabile = bool(dati.get('responsabile', False))
    ceo = bool(dati.get('ceo', False))

    if not all([matricola, nome, cognome, email, password]) or cod_ruolo is None or id_gruppo is None:
        return jsonify({'errore': 'Campi obbligatori: matricola, nome, cognome, email, '
                                  'password, codRuolo, idGruppo'}), 400
    if len(matricola) > 10:
        return jsonify({'errore': 'La matricola può avere al massimo 10 caratteri'}), 400

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT codice FROM Ruoli WHERE codice = %s', (cod_ruolo,))
        if not cur.fetchone():
            return jsonify({'errore': 'Ruolo inesistente'}), 422
        cur.execute('SELECT id FROM Gruppi WHERE id = %s', (id_gruppo,))
        if not cur.fetchone():
            return jsonify({'errore': 'Gruppo inesistente'}), 422

        cur.execute(
            '''INSERT INTO Utenti
               (matricola, nome, cognome, email, password, cambioPassword,
                responsabile, ceo, codRuolo, idGruppo)
               VALUES (%s, %s, %s, %s, %s, TRUE, %s, %s, %s, %s)''',
            (matricola, nome, cognome, email, password,
             responsabile, ceo, cod_ruolo, id_gruppo)
        )
        conn.commit()
        return jsonify({'messaggio': 'Utente creato', 'matricola': matricola}), 201
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    except Error as e:
        return jsonify({'errore': f'Matricola o email già esistente ({e})'}), 409
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


@app.route('/api/utenti/<matricola>', methods=['PUT'])
@richiede_token
@solo_ceo
def modifica_utente(matricola):
    dati = request.get_json(force=True) or {}
    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT matricola FROM Utenti WHERE matricola = %s', (matricola,))
        if not cur.fetchone():
            return jsonify({'errore': 'Utente non trovato'}), 404

        campi, params = [], []
        if 'codRuolo' in dati:
            cur.execute('SELECT codice FROM Ruoli WHERE codice = %s', (dati['codRuolo'],))
            if not cur.fetchone():
                return jsonify({'errore': 'Ruolo inesistente'}), 422
            campi.append('codRuolo = %s')
            params.append(dati['codRuolo'])
        if 'idGruppo' in dati:
            cur.execute('SELECT id FROM Gruppi WHERE id = %s', (dati['idGruppo'],))
            if not cur.fetchone():
                return jsonify({'errore': 'Gruppo inesistente'}), 422
            campi.append('idGruppo = %s')
            params.append(dati['idGruppo'])
        if 'responsabile' in dati:
            campi.append('responsabile = %s')
            params.append(bool(dati['responsabile']))
        if 'ceo' in dati:
            campi.append('ceo = %s')
            params.append(bool(dati['ceo']))
        if dati.get('password'):
            campi.append('password = %s')
            params.append(dati['password'].strip())
            # reset password: l'utente dovrà cambiarla al prossimo accesso
            campi.append('cambioPassword = TRUE')

        if not campi:
            return jsonify({'errore': 'Nessun campo da aggiornare'}), 400

        params.append(matricola)
        cur.execute(f'UPDATE Utenti SET {", ".join(campi)} WHERE matricola = %s', params)
        conn.commit()
        return jsonify({'messaggio': f'Utente {matricola} aggiornato'})
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    except Error as e:
        return jsonify({'errore': f'Errore database: {e}'}), 409
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


# ═════════════════════════════════════════
#  ROUTE: Vincoli
# ═════════════════════════════════════════
@app.route('/api/vincoli', methods=['GET'])
@richiede_token
def lista_vincoli():
    """CEO: tutti i vincoli. Responsabile: vincoli del suo gruppo + globali.
    Dipendente: solo i vincoli applicabili a lui (gruppo/ruolo o globali)."""
    is_ceo = request.utente_corrente.get('ceo', False)
    is_resp = request.utente_corrente.get('responsabile', False)
    matricola = request.utente_corrente['matricola']

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT idGruppo, codRuolo FROM Utenti WHERE matricola = %s', (matricola,))
        u = cur.fetchone()
        if not u:
            return jsonify({'errore': 'Utente non trovato'}), 404

        cur.execute('''SELECT id, inizio, fine, tipoPeriodo, minG, maxG, nMin,
                              percMin, minGCons, maxGCons
                       FROM Vincoli ORDER BY inizio''')
        vincoli = cur.fetchall()
        lim = _limitazioni_per_vincoli(cur, [v['id'] for v in vincoli])

        risultato = []
        for v in vincoli:
            limitazioni = lim.get(v['id'], [])

            if is_ceo:
                visibile = True
            elif is_resp:
                visibile = _vincolo_visibile_gruppo(limitazioni, u['idGruppo'])
            else:
                visibile = _vincolo_applicabile(limitazioni, u['idGruppo'], u['codRuolo'])
            if not visibile:
                continue

            v['inizio'] = str(v['inizio'])
            v['fine'] = str(v['fine'])
            if v['percMin'] is not None:
                v['percMin'] = float(v['percMin'])
            v['limitazioni'] = [
                {'id': l['id'], 'idGruppo': l['idGruppo'], 'codRuolo': l['codRuolo']}
                for l in limitazioni
            ]
            v['globale'] = len(limitazioni) == 0
            risultato.append(v)

        return jsonify({'vincoli': risultato, 'totale': len(risultato)})
    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


@app.route('/api/vincoli', methods=['POST'])
@richiede_token
@ceo_o_responsabile
def crea_vincolo():
    dati = request.get_json(force=True) or {}
    is_ceo = request.utente_corrente.get('ceo', False)
    matricola = request.utente_corrente['matricola']

    errore = _valida_campi_vincolo(dati)
    if errore:
        return jsonify({'errore': errore}), 400

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        gruppo_resp = None
        if not is_ceo:
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
            row = cur.fetchone()
            if not row:
                return jsonify({'errore': 'Responsabile non trovato'}), 404
            gruppo_resp = row['idGruppo']

        err_lim, limitazioni = _normalizza_limitazioni(
            dati.get('limitazioni'), is_ceo, gruppo_resp)
        if err_lim:
            return jsonify({'errore': err_lim}), 403

        # Transazione: Vincoli + Limitazioni nella stessa connessione.
        cur.execute(
            '''INSERT INTO Vincoli
               (inizio, fine, tipoPeriodo, minG, maxG, nMin, percMin, minGCons, maxGCons)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)''',
            (dati['inizio'], dati['fine'], dati['tipoPeriodo'],
             dati.get('minG'), dati.get('maxG'), dati.get('nMin'),
             dati.get('percMin'), dati.get('minGCons'), dati.get('maxGCons'))
        )
        id_vincolo = cur.lastrowid

        for l in limitazioni:
            cur.execute(
                'INSERT INTO Limitazioni (idVincolo, idGruppo, codRuolo) VALUES (%s, %s, %s)',
                (id_vincolo, l['idGruppo'], l['codRuolo'])
            )
        conn.commit()
        return jsonify({'messaggio': 'Vincolo creato', 'id': id_vincolo}), 201

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    except Error as e:
        if 'conn' in locals():
            conn.rollback()
        return jsonify({'errore': f'Errore database: {e}'}), 400
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


@app.route('/api/vincoli/<int:id_vincolo>', methods=['PUT'])
@richiede_token
@ceo_o_responsabile
def modifica_vincolo(id_vincolo):
    dati = request.get_json(force=True) or {}
    is_ceo = request.utente_corrente.get('ceo', False)
    matricola = request.utente_corrente['matricola']

    errore = _valida_campi_vincolo(dati)
    if errore:
        return jsonify({'errore': errore}), 400

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT id FROM Vincoli WHERE id = %s', (id_vincolo,))
        if not cur.fetchone():
            return jsonify({'errore': 'Vincolo non trovato'}), 404

        lim_esistenti = _limitazioni_per_vincoli(cur, [id_vincolo]).get(id_vincolo, [])

        gruppo_resp = None
        if not is_ceo:
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
            row = cur.fetchone()
            if not row:
                return jsonify({'errore': 'Responsabile non trovato'}), 404
            gruppo_resp = row['idGruppo']
            # Il responsabile può modificare solo vincoli limitati al suo gruppo.
            if not _vincolo_solo_gruppo(lim_esistenti, gruppo_resp):
                return jsonify({'errore': 'Puoi modificare solo i vincoli del tuo gruppo'}), 403

        err_lim, limitazioni = _normalizza_limitazioni(
            dati.get('limitazioni'), is_ceo, gruppo_resp)
        if err_lim:
            return jsonify({'errore': err_lim}), 403

        cur.execute(
            '''UPDATE Vincoli SET inizio = %s, fine = %s, tipoPeriodo = %s,
                   minG = %s, maxG = %s, nMin = %s, percMin = %s,
                   minGCons = %s, maxGCons = %s
               WHERE id = %s''',
            (dati['inizio'], dati['fine'], dati['tipoPeriodo'],
             dati.get('minG'), dati.get('maxG'), dati.get('nMin'),
             dati.get('percMin'), dati.get('minGCons'), dati.get('maxGCons'),
             id_vincolo)
        )
        cur.execute('DELETE FROM Limitazioni WHERE idVincolo = %s', (id_vincolo,))
        for l in limitazioni:
            cur.execute(
                'INSERT INTO Limitazioni (idVincolo, idGruppo, codRuolo) VALUES (%s, %s, %s)',
                (id_vincolo, l['idGruppo'], l['codRuolo'])
            )
        conn.commit()
        return jsonify({'messaggio': f'Vincolo {id_vincolo} aggiornato'})

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    except Error as e:
        if 'conn' in locals():
            conn.rollback()
        return jsonify({'errore': f'Errore database: {e}'}), 400
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


@app.route('/api/vincoli/<int:id_vincolo>', methods=['DELETE'])
@richiede_token
@ceo_o_responsabile
def elimina_vincolo(id_vincolo):
    is_ceo = request.utente_corrente.get('ceo', False)
    matricola = request.utente_corrente['matricola']

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT id FROM Vincoli WHERE id = %s', (id_vincolo,))
        if not cur.fetchone():
            return jsonify({'errore': 'Vincolo non trovato'}), 404

        lim_esistenti = _limitazioni_per_vincoli(cur, [id_vincolo]).get(id_vincolo, [])

        if not is_ceo:
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
            row = cur.fetchone()
            if not row:
                return jsonify({'errore': 'Responsabile non trovato'}), 404
            if not _vincolo_solo_gruppo(lim_esistenti, row['idGruppo']):
                return jsonify({'errore': 'Puoi eliminare solo i vincoli del tuo gruppo'}), 403

        # Cascade manuale: prima le Limitazioni, poi il Vincolo.
        cur.execute('DELETE FROM Limitazioni WHERE idVincolo = %s', (id_vincolo,))
        cur.execute('DELETE FROM Vincoli WHERE id = %s', (id_vincolo,))
        conn.commit()
        return jsonify({'messaggio': f'Vincolo {id_vincolo} eliminato'})

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    except Error as e:
        if 'conn' in locals():
            conn.rollback()
        return jsonify({'errore': f'Errore database: {e}'}), 400
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close(); conn.close()


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
