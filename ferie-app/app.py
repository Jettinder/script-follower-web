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


def crea_token(matricola: str, is_responsabile: bool) -> str:
    payload = {
        'matricola': matricola,
        'responsabile': is_responsabile,
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
            '''SELECT matricola, nome, cognome, responsabile, idGruppo, cambioPassword
               FROM Utenti
               WHERE email = %s AND password = %s''',
            (email, password)
        )
        utente = cur.fetchone()
        if not utente:
            return jsonify({'errore': 'Credenziali non valide'}), 401

        matricola = utente['matricola']
        is_resp = bool(utente['responsabile'])
        token = crea_token(matricola, is_resp)

        return jsonify({
            'token': token,
            'matricola': matricola,
            'nome': utente['nome'],
            'cognome': utente['cognome'],
            'responsabile': is_resp,
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
            '''SELECT u.matricola, u.nome, u.cognome, u.responsabile,
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
#  ROUTE: Tutte le ferie del gruppo (solo responsabile)
# ─────────────────────────────────────────
@app.route('/api/ferie', methods=['GET'])
@richiede_token
@solo_responsabile
def richieste_ferie():
    matricola_resp = request.utente_corrente['matricola']
    filtro_matr = request.args.get('matricola')
    filtro_stato = request.args.get('stato')  # opzionale: 'In attesa', 'Approvato', 'Rifiutato'

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola_resp,))
        row = cur.fetchone()
        if not row:
            return jsonify({'errore': 'Responsabile non trovato'}), 404

        id_gruppo = row['idGruppo']

        cur.execute('SELECT matricola FROM Utenti WHERE idGruppo = %s', (id_gruppo,))
        matricole_gruppo = [r['matricola'] for r in cur.fetchall()]

        if not matricole_gruppo:
            return jsonify({'ferie': [], 'totale': 0})

        placeholders = ', '.join(['%s'] * len(matricole_gruppo))
        params = list(matricole_gruppo)

        query = f'''
            SELECT r.id, r.stato, r.inizio, r.fine,
                   r.matrUtente, r.dataOraIns, r.matrResp,
                   u.nome, u.cognome
            FROM RichiesteFerie r
            JOIN Utenti u ON r.matrUtente = u.matricola
            WHERE r.matrUtente IN ({placeholders})
        '''

        if filtro_matr:
            query += ' AND r.matrUtente = %s'
            params.append(filtro_matr)

        if filtro_stato in ('In attesa', 'Approvato', 'Rifiutato'):
            query += ' AND r.stato = %s'
            params.append(filtro_stato)

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
# ─────────────────────────────────────────
@app.route('/api/ferie/<int:id_ferie>/approva', methods=['PUT'])
@richiede_token
@solo_responsabile
def approva_ferie(id_ferie):
    dati = request.get_json(force=True) or {}
    nuovo_stato = dati.get('stato')

    # Il CHECK del DB accetta solo questi tre valori; qui blocchiamo i due di interesse
    if nuovo_stato not in ('Approvato', 'Rifiutato'):
        return jsonify({'errore': "Il campo stato deve essere 'Approvato' o 'Rifiutato'"}), 400

    matricola_resp = request.utente_corrente['matricola']

    try:
        conn = get_db()
        cur = conn.cursor(dictionary=True)

        # Verifica che la richiesta appartenga a un membro del gruppo del responsabile
        cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola_resp,))
        row = cur.fetchone()
        if not row:
            return jsonify({'errore': 'Responsabile non trovato'}), 404
        id_gruppo = row['idGruppo']

        cur.execute(
            '''SELECT r.id, r.stato FROM RichiesteFerie r
               JOIN Utenti u ON r.matrUtente = u.matricola
               WHERE r.id = %s AND u.idGruppo = %s''',
            (id_ferie, id_gruppo)
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

        return jsonify({'messaggio': 'Richiesta inserita', 'id': nuovo_id}), 201

    except RuntimeError as e:
        return jsonify({'errore': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cur.close()
            conn.close()


# ─────────────────────────────────────────


# ─────────────────────────────────────────
#  ROUTE: Leggi commenti di una richiesta ferie
# ─────────────────────────────────────────
@app.route('/api/ferie/<int:id_ferie>/commenti', methods=['GET'])
@richiede_token
def get_commenti(id_ferie):
    matricola = request.utente_corrente['matricola']
    is_resp   = request.utente_corrente.get('responsabile', False)
    try:
        conn = get_db()
        cur  = conn.cursor(dictionary=True)
        cur.execute('SELECT matrUtente, matrResp FROM RichiesteFerie WHERE id = %s', (id_ferie,))
        richiesta = cur.fetchone()
        if not richiesta:
            return jsonify({'errore': 'Richiesta non trovata'}), 404
        if not is_resp and richiesta['matrUtente'] != matricola:
            return jsonify({'errore': 'Accesso negato'}), 403
        if is_resp:
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (matricola,))
            r1 = cur.fetchone()
            cur.execute('SELECT idGruppo FROM Utenti WHERE matricola = %s', (richiesta['matrUtente'],))
            r2 = cur.fetchone()
            if not r2 or r2['idGruppo'] != r1['idGruppo']:
                return jsonify({'errore': 'Accesso negato: richiesta non del tuo gruppo'}), 403
        cur.execute(
            '''SELECT c.id, c.testo, c.dataOraIns, u.nome, u.cognome, u.responsabile
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
    dati  = request.get_json(force=True) or {}
    testo = dati.get('testo', '').strip()
    if not testo:
        return jsonify({'errore': 'Il testo del commento e obbligatorio'}), 400
    matricola = request.utente_corrente['matricola']
    is_resp   = request.utente_corrente.get('responsabile', False)
    try:
        conn = get_db()
        cur  = conn.cursor(dictionary=True)
        cur.execute('SELECT matrUtente FROM RichiesteFerie WHERE id = %s', (id_ferie,))
        richiesta = cur.fetchone()
        if not richiesta:
            return jsonify({'errore': 'Richiesta non trovata'}), 404
        if not is_resp and richiesta['matrUtente'] != matricola:
            return jsonify({'errore': 'Accesso negato'}), 403
        if is_resp:
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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
