const BASE = 'http://localhost:5000/api';
let _token = '', _utente = {};

// Cache condivise (popolate dopo il login, usate da app.js e ceo.js)
let _ruoliCache = {};   // codRuolo  -> denominazione
let _gruppiCache = {};  // idGruppo  -> denominazione

// Riferimenti ai calendari delle pagine dipendente/responsabile
let _calDip = null, _calResp = null;

// ── Utilità ──────────────────────────────────────────────────────────────────

function showPage(id) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.getElementById(id).classList.add('active');
}

function initiali(nome, cognome) {
  return ((nome || '?')[0] + (cognome || '?')[0]).toUpperCase();
}

function showToast(msg, dur = 2500) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), dur);
}

// stato è la stringa del DB: 'In attesa' | 'Approvato' | 'Rifiutato'
function statusPill(stato) {
  if (!stato || stato === 'In attesa') return '<span class="status-pill pending">In attesa</span>';
  if (stato === 'Approvato')           return '<span class="status-pill approved">Approvato</span>';
  return                                      '<span class="status-pill rejected">Rifiutato</span>';
}

function fmtDate(s) {
  if (!s) return '—';
  return s.substring(0, 10).split('-').reverse().join('/');
}

function fmtDateTime(s) {
  if (!s) return '—';
  const [d, t] = s.split(' ');
  return d.split('-').reverse().join('/') + (t ? ' ' + t.substring(0, 5) : '');
}

async function apiCall(path, method = 'GET', body = null) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + _token }
  };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(BASE + path, opts);
  return r.json();
}

// ── Auth ──────────────────────────────────────────────────────────────────────

async function doLogin() {
  const email  = document.getElementById('inp-email').value.trim();
  const pwd    = document.getElementById('inp-pwd').value.trim();
  const errEl  = document.getElementById('login-error');
  const btn    = document.getElementById('btn-login');

  errEl.style.display = 'none';
  if (!email || !pwd) {
    errEl.textContent = 'Inserisci email e password.';
    errEl.style.display = 'block';
    return;
  }

  btn.disabled = true;
  btn.textContent = 'Accesso in corso…';

  try {
    const data = await fetch(BASE + '/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: pwd })
    }).then(r => r.json());

    if (data.errore) {
      errEl.textContent = data.errore;
      errEl.style.display = 'block';
      return;
    }

    _token  = data.token;
    _utente = data;

    // Cache ruoli e gruppi: servono alle dropdown e ai dettagli dei vincoli.
    await caricaCache();

    if (data.ceo) {
      // La pagina CEO è gestita da ceo.js
      initCeo(data);
    } else if (data.responsabile) {
      document.getElementById('resp-avatar').textContent = initiali(data.nome, data.cognome);
      document.getElementById('resp-name').textContent   = (data.nome || '') + ' ' + (data.cognome || '');
      showPage('page-responsabile');
      _calResp = creaCalendario(document.getElementById('resp-calendario'), {});
      loadRespFerie();
      loadTeam();
      loadRespVincoli();
    } else {
      document.getElementById('dip-avatar').textContent = initiali(data.nome, data.cognome);
      document.getElementById('dip-name').textContent   = (data.nome || '') + ' ' + (data.cognome || '');
      showPage('page-dipendente');
      _calDip = creaCalendario(document.getElementById('dip-calendario'), {
        onDayClick: iso => `<button class="btn-cal-richiedi" onclick="precompilaFerie('${iso}')">
            <i class="ti ti-calendar-plus" aria-hidden="true"></i> Richiedi da questo giorno
          </button>`
      });
      loadDipFerie();
      loadDipVincoli();
    }
  } catch (e) {
    errEl.textContent = 'Impossibile contattare il server. Controlla che Flask sia in esecuzione.';
    errEl.style.display = 'block';
  } finally {
    btn.disabled = false;
    btn.textContent = 'Accedi';
  }
}

function doLogout() {
  _token = ''; _utente = {};
  _ruoliCache = {}; _gruppiCache = {};
  _calDip = null; _calResp = null;
  document.getElementById('inp-email').value = '';
  document.getElementById('inp-pwd').value   = '';
  document.getElementById('login-error').style.display = 'none';
  ['dip-ferie-list', 'resp-ferie-list', 'resp-team-list'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.innerHTML = '<div class="loading-row"><span class="spinner"></span>Caricamento...</div>';
  });
  showPage('page-login');
}

// Carica ruoli (sempre) e gruppi (in base ai permessi) nelle cache globali.
async function caricaCache() {
  try {
    const ruoli = await apiCall('/ruoli');
    (ruoli.ruoli || []).forEach(r => { _ruoliCache[r.codice] = r.denominazione; });
  } catch (e) { /* le dropdown ruolo resteranno vuote */ }
  try {
    const gruppi = await apiCall('/gruppi');
    (gruppi.gruppi || []).forEach(g => { _gruppiCache[g.id] = g.denominazione; });
  } catch (e) { /* idem per i gruppi */ }
}

function nomeRuolo(cod) { return cod == null ? 'Tutti i ruoli'  : (_ruoliCache[cod] || ('Ruolo ' + cod)); }
function nomeGruppo(id) { return id  == null ? 'Tutti i gruppi' : (_gruppiCache[id] || ('Gruppo ' + id)); }

// ── Dipendente ────────────────────────────────────────────────────────────────

async function loadDipFerie() {
  const el = document.getElementById('dip-ferie-list');
  try {
    const data = await apiCall('/ferie/mie');
    if (data.errore) {
      el.innerHTML = `<div class="loading-row" style="color:var(--color-text-danger)">${data.errore}</div>`;
      return;
    }
    const list = data.ferie || [];
    if (_calDip) _calDip.setFerie(list);
    if (!list.length) {
      el.innerHTML = '<div class="loading-row">Nessuna richiesta inviata.</div>';
      return;
    }
    el.innerHTML = '<div class="ferie-list">' + list.map(f => ferieItemHTML(f, false)).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento dati.</div>';
  }
}

// Pre-compila le date partendo dal giorno cliccato sul calendario.
function precompilaFerie(iso) {
  document.getElementById('dip-inizio').value = iso;
  document.getElementById('dip-fine').value   = iso;
  document.getElementById('dip-inizio').scrollIntoView({ behavior: 'smooth', block: 'center' });
}

async function inviaFerie() {
  const inizio = document.getElementById('dip-inizio').value;
  const fine   = document.getElementById('dip-fine').value;
  const btn    = document.getElementById('btn-richiedi');

  if (!inizio || !fine) { showToast('Inserisci data inizio e fine.'); return; }
  if (fine < inizio)    { showToast("La data fine deve essere successiva all'inizio."); return; }

  btn.disabled = true;
  try {
    const data = await apiCall('/ferie', 'POST', { inizio, fine });
    if (data.errore) { showToast('Errore: ' + data.errore, 4000); return; }
    if (data.avvisi && data.avvisi.length) {
      showToast('⚠ ' + data.avvisi.join(' '), 5000);
    } else {
      showToast('✓ Richiesta inviata con successo!');
    }
    document.getElementById('dip-inizio').value = '';
    document.getElementById('dip-fine').value   = '';
    loadDipFerie();
  } catch (e) {
    showToast('Errore di rete.');
  } finally {
    btn.disabled = false;
  }
}

async function loadDipVincoli() {
  const el = document.getElementById('dip-vincoli-list');
  try {
    const data = await apiCall('/vincoli');
    if (data.errore) {
      el.innerHTML = `<div class="loading-row" style="color:var(--color-text-danger)">${data.errore}</div>`;
      return;
    }
    const list = data.vincoli || [];
    if (_calDip) _calDip.setVincoli(list);
    if (!list.length) {
      el.innerHTML = '<div class="loading-row">Nessun periodo bloccato o sconsigliato.</div>';
      return;
    }
    el.innerHTML = '<div class="vincoli-list">' + list.map(v => vincoloItemHTML(v, false)).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento vincoli.</div>';
  }
}

// ── Responsabile ──────────────────────────────────────────────────────────────

async function loadRespFerie() {
  const el = document.getElementById('resp-ferie-list');
  try {
    const data = await apiCall('/ferie');
    if (data.errore) {
      el.innerHTML = `<div class="loading-row" style="color:var(--color-text-danger)">${data.errore}</div>`;
      return;
    }
    const list = data.ferie || [];
    if (_calResp) _calResp.setFerie(list);
    if (!list.length) {
      el.innerHTML = '<div class="loading-row">Nessuna richiesta nel gruppo.</div>';
      return;
    }
    el.innerHTML = '<div class="ferie-list">' + list.map(f => ferieItemHTML(f, true)).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento dati.</div>';
  }
}

// Ricarica la lista ferie corretta in base alla pagina attiva (resp o CEO).
function ricaricaFerieCorrenti() {
  const ceo = document.getElementById('page-ceo');
  if (ceo && ceo.classList.contains('active') && typeof loadCeoFerie === 'function') {
    loadCeoFerie();
  } else {
    loadRespFerie();
  }
}

async function gestisciFerie(id, nuovoStato) {
  try {
    const data = await apiCall('/ferie/' + id + '/approva', 'PUT', { stato: nuovoStato });
    if (data.errore) { showToast('Errore: ' + data.errore); return; }
    showToast(nuovoStato === 'Approvato' ? '✓ Richiesta approvata' : '✗ Richiesta rifiutata');
    ricaricaFerieCorrenti();
  } catch (e) {
    showToast('Errore di rete.');
  }
}

async function loadTeam() {
  const el = document.getElementById('resp-team-list');
  try {
    const data = await apiCall('/gruppo/membri');
    if (data.errore) {
      el.innerHTML = `<div class="loading-row" style="color:var(--color-text-danger)">${data.errore}</div>`;
      return;
    }
    const membri = data.membri || [];
    if (!membri.length) {
      el.innerHTML = '<div class="loading-row">Nessun membro trovato.</div>';
      return;
    }
    el.innerHTML = '<div class="members-grid">' + membri.map(m => `
      <div class="member-card">
        <div class="member-av">${initiali(m.nome, m.cognome)}</div>
        <div>
          <div class="member-name">${m.nome || ''} ${m.cognome || ''}</div>
          <div class="member-role">${m.ceo ? 'CEO' : (m.responsabile ? 'Responsabile' : 'Dipendente')} · ${m.ruolo || ''}</div>
        </div>
      </div>`).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento team.</div>';
  }
}

// ── Vincoli (responsabile) ────────────────────────────────────────────────────

async function loadRespVincoli() {
  const el = document.getElementById('resp-vincoli-list');
  // Popola la dropdown ruolo del form (con opzione "Tutti i ruoli").
  popolaSelectRuoli('resp-vinc-ruolo', true);
  try {
    const data = await apiCall('/vincoli');
    if (data.errore) {
      el.innerHTML = `<div class="loading-row" style="color:var(--color-text-danger)">${data.errore}</div>`;
      return;
    }
    const list = data.vincoli || [];
    if (_calResp) _calResp.setVincoli(list);
    if (!list.length) {
      el.innerHTML = '<div class="loading-row">Nessun vincolo per il tuo gruppo.</div>';
      return;
    }
    el.innerHTML = '<div class="vincoli-list">' + list.map(v => {
      // Il responsabile può modificare solo i vincoli esclusivi del suo gruppo.
      const soloMio = v.limitazioni.length > 0 &&
        v.limitazioni.every(l => l.idGruppo === _utente.idGruppo);
      return vincoloItemHTML(v, soloMio);
    }).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento vincoli.</div>';
  }
}

async function creaVincoloResp() {
  const inizio = document.getElementById('resp-vinc-inizio').value;
  const fine   = document.getElementById('resp-vinc-fine').value;
  const tipo   = document.getElementById('resp-vinc-tipo').value;
  const ruolo  = document.getElementById('resp-vinc-ruolo').value;
  const btn    = document.getElementById('btn-crea-vincolo-resp');

  if (!inizio || !fine) { showToast('Inserisci data inizio e fine.'); return; }
  if (fine < inizio)    { showToast('La data fine deve essere successiva.'); return; }

  // Il vincolo è forzato sul proprio gruppo; il ruolo è opzionale.
  const limitazioni = [{ idGruppo: _utente.idGruppo, codRuolo: ruolo ? parseInt(ruolo) : null }];

  btn.disabled = true;
  try {
    const data = await apiCall('/vincoli', 'POST',
      { inizio, fine, tipoPeriodo: tipo, limitazioni });
    if (data.errore) { showToast('Errore: ' + data.errore, 4000); return; }
    showToast('✓ Vincolo creato');
    document.getElementById('resp-vinc-inizio').value = '';
    document.getElementById('resp-vinc-fine').value   = '';
    document.getElementById('resp-vinc-ruolo').value  = '';
    loadRespVincoli();
  } catch (e) {
    showToast('Errore di rete.');
  } finally {
    btn.disabled = false;
  }
}

async function eliminaVincolo(id) {
  if (!confirm('Eliminare definitivamente questo vincolo?')) return;
  try {
    const data = await apiCall('/vincoli/' + id, 'DELETE');
    if (data.errore) { showToast('Errore: ' + data.errore); return; }
    showToast('✓ Vincolo eliminato');
    const ceo = document.getElementById('page-ceo');
    if (ceo && ceo.classList.contains('active') && typeof loadCeoVincoli === 'function') {
      loadCeoVincoli();
      loadCeoDashboard();
    } else {
      loadRespVincoli();
    }
  } catch (e) {
    showToast('Errore di rete.');
  }
}

// ── Ferie item HTML (riusato da dipendente e responsabile) ────────────────────

function ferieItemHTML(f, isResp) {
  const pulsantiAzione = isResp && f.stato === 'In attesa' ? `
    <div class="action-btns">
      <button class="btn-approve" onclick="gestisciFerie(${f.id}, 'Approvato')">
        <i class="ti ti-check" style="font-size:13px;vertical-align:-1px;" aria-hidden="true"></i> Approva
      </button>
      <button class="btn-reject" onclick="gestisciFerie(${f.id}, 'Rifiutato')">
        <i class="ti ti-x" style="font-size:13px;vertical-align:-1px;" aria-hidden="true"></i> Rifiuta
      </button>
    </div>` : '';

  const nomeUtente = isResp ? ` · ${f.nome || ''} ${f.cognome || ''}` : '';

  return `
    <div class="ferie-item" id="ferie-${f.id}">
      <div class="ferie-item-header">
        <div>
          <div class="ferie-date">
            <i class="ti ti-calendar-event" style="font-size:14px;vertical-align:-2px;margin-right:4px;" aria-hidden="true"></i>
            ${fmtDate(f.inizio)} → ${fmtDate(f.fine)}
          </div>
          <div class="ferie-sub">Inserita: ${fmtDate(f.dataOraIns)}${nomeUtente}</div>
        </div>
        <div class="ferie-right">
          ${statusPill(f.stato)}
          ${pulsantiAzione}
          <button class="btn-commenti" onclick="toggleCommenti(${f.id}, this)">
            <i class="ti ti-message" style="font-size:13px;" aria-hidden="true"></i>
            Commenti
          </button>
        </div>
      </div>
      <div class="commenti-panel" id="commenti-${f.id}">
        <div class="loading-row" style="padding:0.5rem 0;"><span class="spinner"></span>Caricamento commenti...</div>
      </div>
    </div>`;
}

// ── Vincolo item HTML (riusato da dipendente, responsabile, CEO) ──────────────

function vincoloItemHTML(v, modificabile) {
  const tipoCls = v.tipoPeriodo === 'Bloccato' ? 'bloccato' : 'sconsigliato';

  let target;
  if (v.globale) {
    target = 'Tutti i gruppi e ruoli';
  } else {
    target = v.limitazioni.map(l =>
      `${nomeGruppo(l.idGruppo)} / ${nomeRuolo(l.codRuolo)}`).join(' · ');
  }

  const azioni = modificabile ? `
    <button class="btn-mini-danger" onclick="eliminaVincolo(${v.id})">
      <i class="ti ti-trash" style="font-size:13px;" aria-hidden="true"></i> Elimina
    </button>` : '';

  return `
    <div class="vincolo-item">
      <div class="vincolo-head">
        <span class="vincolo-badge ${tipoCls}">${v.tipoPeriodo}</span>
        <span class="vincolo-date">${fmtDate(v.inizio)} → ${fmtDate(v.fine)}</span>
        ${azioni}
      </div>
      <div class="vincolo-target">
        <i class="ti ti-users-group" style="font-size:12px;vertical-align:-1px;margin-right:3px;" aria-hidden="true"></i>
        ${escHTML(target)}
      </div>
    </div>`;
}

// Popola un <select> con i ruoli. Se conTutti=true aggiunge l'opzione "Tutti".
function popolaSelectRuoli(selectId, conTutti) {
  const sel = document.getElementById(selectId);
  if (!sel) return;
  let html = conTutti ? '<option value="">Tutti i ruoli</option>' : '';
  Object.keys(_ruoliCache).forEach(cod => {
    html += `<option value="${cod}">${escHTML(_ruoliCache[cod])}</option>`;
  });
  sel.innerHTML = html;
}

// ── Commenti ──────────────────────────────────────────────────────────────────

async function toggleCommenti(idFerie, btn) {
  const panel = document.getElementById('commenti-' + idFerie);
  const isOpen = panel.classList.contains('open');

  if (isOpen) {
    panel.classList.remove('open');
    return;
  }

  panel.classList.add('open');
  await loadCommenti(idFerie);
}

async function loadCommenti(idFerie) {
  const panel = document.getElementById('commenti-' + idFerie);
  panel.innerHTML = '<div class="loading-row" style="padding:0.5rem 0;"><span class="spinner"></span>Caricamento commenti...</div>';

  try {
    const data = await apiCall('/ferie/' + idFerie + '/commenti');
    if (data.errore) {
      panel.innerHTML = `<div class="commenti-empty" style="color:var(--color-text-danger)">${data.errore}</div>`;
      return;
    }

    const lista = data.commenti || [];
    const listaHTML = lista.length
      ? '<div class="commenti-list">' + lista.map(c => `
          <div class="commento-item">
            <div class="commento-header">
              <span class="commento-autore">
                <i class="ti ti-user" style="font-size:12px;vertical-align:-1px;margin-right:3px;" aria-hidden="true"></i>
                ${c.nome || ''} ${c.cognome || ''}${c.ceo ? ' <span class="role-badge ceo" style="font-size:10px;padding:1px 6px;">CEO</span>' : (c.responsabile ? ' <span class="role-badge resp" style="font-size:10px;padding:1px 6px;">Resp.</span>' : '')}
              </span>
              <span class="commento-data">${fmtDateTime(c.dataOraIns)}</span>
            </div>
            <div class="commento-testo">${escHTML(c.testo)}</div>
          </div>`).join('') + '</div>'
      : '<div class="commenti-empty">Nessun commento ancora.</div>';

    panel.innerHTML = listaHTML + `
      <div class="commenti-form">
        <textarea id="txt-commento-${idFerie}" placeholder="Scrivi un commento…"></textarea>
        <button class="btn-send-comment" onclick="inviaCommento(${idFerie})">
          <i class="ti ti-send" style="font-size:14px;vertical-align:-2px;" aria-hidden="true"></i>
        </button>
      </div>`;

  } catch (e) {
    panel.innerHTML = '<div class="commenti-empty" style="color:var(--color-text-danger)">Errore caricamento commenti.</div>';
  }
}

async function inviaCommento(idFerie) {
  const txt = document.getElementById('txt-commento-' + idFerie);
  const testo = (txt ? txt.value : '').trim();
  if (!testo) { showToast('Il commento non può essere vuoto.'); return; }

  const btn = txt.nextElementSibling;
  btn.disabled = true;

  try {
    const data = await apiCall('/ferie/' + idFerie + '/commenti', 'POST', { testo });
    if (data.errore) { showToast('Errore: ' + data.errore); return; }
    showToast('✓ Commento inviato');
    await loadCommenti(idFerie);
  } catch (e) {
    showToast('Errore di rete.');
  } finally {
    btn.disabled = false;
  }
}

function escHTML(str) {
  return (str || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

function switchTab(tabId, btn) {
  // Disattiva solo i tab/contenuti della stessa pagina di quello cliccato.
  const container = btn.closest('.page') || document;
  container.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  container.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
  document.getElementById(tabId).classList.add('active');
  btn.classList.add('active');
}

// ── Init ──────────────────────────────────────────────────────────────────────

document.getElementById('inp-pwd').addEventListener('keydown', e => {
  if (e.key === 'Enter') doLogin();
});
