// ── ceo.js ───────────────────────────────────────────────────────────────────
//  Logica della pagina CEO: dashboard, gruppi, personale, ferie, vincoli.
//  Dipende dalle funzioni e variabili globali definite in app.js e calendar.js
//  (apiCall, showToast, escHTML, _utente, _ruoliCache, _gruppiCache, ecc.).
// ─────────────────────────────────────────────────────────────────────────────

let _calCeo = null;
let _ceoUtentiCache = [];   // ultimo elenco utenti caricato

function initCeo(data) {
  document.getElementById('ceo-avatar').textContent = initiali(data.nome, data.cognome);
  document.getElementById('ceo-name').textContent = (data.nome || '') + ' ' + (data.cognome || '');
  showPage('page-ceo');
  _calCeo = creaCalendario(document.getElementById('ceo-calendario'), {});
  loadCeoDashboard();
  loadCeoGruppi();
  loadCeoPersonale();
  loadCeoFerie();
  loadCeoVincoli();
}

// ── Modal generico ────────────────────────────────────────────────────────────

function apriModal(titolo, contenutoHTML) {
  document.getElementById('modal-titolo').textContent = titolo;
  document.getElementById('modal-body').innerHTML = contenutoHTML;
  document.getElementById('modal-overlay').classList.add('open');
}

function chiudiModal() {
  document.getElementById('modal-overlay').classList.remove('open');
  document.getElementById('modal-body').innerHTML = '';
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

async function loadCeoDashboard() {
  try {
    const [gruppi, utenti, pendenti, vincoli] = await Promise.all([
      apiCall('/gruppi'),
      apiCall('/utenti'),
      apiCall('/ferie?stato=In attesa'),
      apiCall('/vincoli')
    ]);
    setDashCounter('dash-gruppi',  (gruppi.gruppi  || []).length);
    setDashCounter('dash-utenti',  (utenti.utenti  || []).length);
    setDashCounter('dash-pendenti', pendenti.totale != null ? pendenti.totale : 0);
    setDashCounter('dash-vincoli', (vincoli.vincoli || []).length);
  } catch (e) {
    showToast('Errore caricamento dashboard.');
  }
}

function setDashCounter(id, valore) {
  const el = document.getElementById(id);
  if (el) el.textContent = valore;
}

// ── Gruppi ────────────────────────────────────────────────────────────────────

async function loadCeoGruppi() {
  const el = document.getElementById('ceo-gruppi-list');
  try {
    const data = await apiCall('/gruppi');
    if (data.errore) { el.innerHTML = errBox(data.errore); return; }
    const gruppi = data.gruppi || [];
    // Aggiorna la cache globale dei gruppi.
    _gruppiCache = {};
    gruppi.forEach(g => { _gruppiCache[g.id] = g.denominazione; });

    if (!gruppi.length) { el.innerHTML = '<div class="loading-row">Nessun gruppo.</div>'; return; }
    el.innerHTML = `
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>ID</th><th>Denominazione</th><th>Capo gruppo</th><th>Membri</th><th></th></tr></thead>
        <tbody>${gruppi.map(g => `
          <tr>
            <td>${g.id}</td>
            <td>${escHTML(g.denominazione)}</td>
            <td>${g.matricolaResp
                  ? escHTML((g.nomeResp || '') + ' ' + (g.cognomeResp || ''))
                  : '<span class="muted">— non assegnato —</span>'}</td>
            <td>${g.numMembri}</td>
            <td><button class="btn-mini" onclick="modalGruppo(${g.id})">
                  <i class="ti ti-edit" aria-hidden="true"></i> Modifica</button></td>
          </tr>`).join('')}</tbody>
      </table></div>`;
  } catch (e) {
    el.innerHTML = errBox('Errore caricamento gruppi.');
  }
}

async function modalGruppo(id) {
  // id null = creazione; altrimenti modifica.
  const gruppi = (await apiCall('/gruppi')).gruppi || [];
  const g = id ? gruppi.find(x => x.id === id) : null;
  await assicuraUtentiCache();

  const optResp = '<option value="">— nessuno —</option>' + _ceoUtentiCache.map(u =>
    `<option value="${u.matricola}" ${g && g.matricolaResp === u.matricola ? 'selected' : ''}>
       ${escHTML(u.cognome + ' ' + u.nome)} (${u.matricola})</option>`).join('');

  apriModal(id ? 'Modifica gruppo' : 'Nuovo gruppo', `
    <div class="field-form">
      <label>Denominazione</label>
      <input type="text" id="m-grp-denom" value="${g ? escHTML(g.denominazione) : ''}" />
    </div>
    <div class="field-form">
      <label>Capo gruppo (responsabile)</label>
      <select id="m-grp-resp">${optResp}</select>
    </div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="chiudiModal()">Annulla</button>
      <button class="btn-submit" onclick="salvaGruppo(${id || 'null'})">Salva</button>
    </div>`);
}

async function salvaGruppo(id) {
  const denominazione = document.getElementById('m-grp-denom').value.trim();
  const matricolaResp = document.getElementById('m-grp-resp').value || null;
  if (!denominazione) { showToast('La denominazione è obbligatoria.'); return; }

  const body = { denominazione, matricolaResp };
  const res = id
    ? await apiCall('/gruppi/' + id, 'PUT', body)
    : await apiCall('/gruppi', 'POST', body);
  if (res.errore) { showToast('Errore: ' + res.errore, 4000); return; }
  showToast(id ? '✓ Gruppo aggiornato' : '✓ Gruppo creato');
  chiudiModal();
  loadCeoGruppi();
  loadCeoDashboard();
}

// ── Personale ─────────────────────────────────────────────────────────────────

async function assicuraUtentiCache() {
  if (!_ceoUtentiCache.length) {
    const data = await apiCall('/utenti');
    _ceoUtentiCache = data.utenti || [];
  }
}

async function loadCeoPersonale() {
  const el = document.getElementById('ceo-personale-list');
  const fGruppo = document.getElementById('ceo-filtro-gruppo').value;
  const fRuolo = document.getElementById('ceo-filtro-ruolo').value;

  // Popola le dropdown dei filtri (una volta sola).
  popolaFiltriPersonale();

  let qs = [];
  if (fGruppo) qs.push('gruppo=' + encodeURIComponent(fGruppo));
  if (fRuolo) qs.push('ruolo=' + encodeURIComponent(fRuolo));

  try {
    const data = await apiCall('/utenti' + (qs.length ? '?' + qs.join('&') : ''));
    if (data.errore) { el.innerHTML = errBox(data.errore); return; }
    const utenti = data.utenti || [];
    if (!fGruppo && !fRuolo) _ceoUtentiCache = utenti;

    if (!utenti.length) { el.innerHTML = '<div class="loading-row">Nessun utente.</div>'; return; }
    el.innerHTML = `
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Matricola</th><th>Nome</th><th>Email</th><th>Ruolo</th>
                   <th>Gruppo</th><th>Livello</th><th></th></tr></thead>
        <tbody>${utenti.map(u => `
          <tr>
            <td>${escHTML(u.matricola)}</td>
            <td>${escHTML(u.cognome + ' ' + u.nome)}</td>
            <td>${escHTML(u.email)}</td>
            <td>${escHTML(u.ruolo || '')}</td>
            <td>${escHTML(u.gruppo || '')}</td>
            <td>${badgeLivello(u)}</td>
            <td><button class="btn-mini" onclick="modalUtente('${escHTML(u.matricola)}')">
                  <i class="ti ti-edit" aria-hidden="true"></i> Modifica</button></td>
          </tr>`).join('')}</tbody>
      </table></div>`;
  } catch (e) {
    el.innerHTML = errBox('Errore caricamento personale.');
  }
}

function badgeLivello(u) {
  if (u.ceo) return '<span class="role-badge ceo">CEO</span>';
  if (u.responsabile) return '<span class="role-badge resp">Responsabile</span>';
  return '<span class="role-badge">Dipendente</span>';
}

function popolaFiltriPersonale() {
  const selG = document.getElementById('ceo-filtro-gruppo');
  const selR = document.getElementById('ceo-filtro-ruolo');
  if (selG && selG.dataset.popolato !== '1') {
    selG.innerHTML = '<option value="">Tutti i gruppi</option>' +
      Object.keys(_gruppiCache).map(id =>
        `<option value="${id}">${escHTML(_gruppiCache[id])}</option>`).join('');
    selG.dataset.popolato = '1';
  }
  if (selR && selR.dataset.popolato !== '1') {
    selR.innerHTML = '<option value="">Tutti i ruoli</option>' +
      Object.keys(_ruoliCache).map(c =>
        `<option value="${c}">${escHTML(_ruoliCache[c])}</option>`).join('');
    selR.dataset.popolato = '1';
  }
}

function optionsGruppi(sel)  {
  return Object.keys(_gruppiCache).map(id =>
    `<option value="${id}" ${String(sel) === String(id) ? 'selected' : ''}>${escHTML(_gruppiCache[id])}</option>`).join('');
}
function optionsRuoli(sel) {
  return Object.keys(_ruoliCache).map(c =>
    `<option value="${c}" ${String(sel) === String(c) ? 'selected' : ''}>${escHTML(_ruoliCache[c])}</option>`).join('');
}

async function modalUtente(matricola) {
  const u = matricola ? _ceoUtentiCache.find(x => x.matricola === matricola) : null;
  const nuovo = !u;

  apriModal(nuovo ? 'Nuovo utente' : 'Modifica utente: ' + matricola, `
    <div class="modal-grid">
      <div class="field-form">
        <label>Matricola</label>
        <input type="text" id="m-ut-matr" maxlength="10"
               value="${u ? escHTML(u.matricola) : ''}" ${nuovo ? '' : 'disabled'} />
      </div>
      <div class="field-form">
        <label>Email</label>
        <input type="email" id="m-ut-email" value="${u ? escHTML(u.email) : ''}" ${nuovo ? '' : 'disabled'} />
      </div>
      <div class="field-form">
        <label>Nome</label>
        <input type="text" id="m-ut-nome" value="${u ? escHTML(u.nome) : ''}" ${nuovo ? '' : 'disabled'} />
      </div>
      <div class="field-form">
        <label>Cognome</label>
        <input type="text" id="m-ut-cognome" value="${u ? escHTML(u.cognome) : ''}" ${nuovo ? '' : 'disabled'} />
      </div>
      <div class="field-form">
        <label>Ruolo</label>
        <select id="m-ut-ruolo">${optionsRuoli(u ? u.codRuolo : null)}</select>
      </div>
      <div class="field-form">
        <label>Gruppo</label>
        <select id="m-ut-gruppo">${optionsGruppi(u ? u.idGruppo : null)}</select>
      </div>
      <div class="field-form">
        <label>${nuovo ? 'Password' : 'Reset password (lascia vuoto per non cambiarla)'}</label>
        <input type="text" id="m-ut-pwd" placeholder="${nuovo ? 'password iniziale' : '— invariata —'}" />
      </div>
    </div>
    <div class="modal-flags">
      <label><input type="checkbox" id="m-ut-resp" ${u && u.responsabile ? 'checked' : ''} /> Responsabile</label>
      <label><input type="checkbox" id="m-ut-ceo" ${u && u.ceo ? 'checked' : ''} /> CEO</label>
    </div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="chiudiModal()">Annulla</button>
      <button class="btn-submit" onclick="salvaUtente(${nuovo ? 'null' : `'${escHTML(matricola)}'`})">Salva</button>
    </div>`);
}

async function salvaUtente(matricola) {
  const codRuolo = parseInt(document.getElementById('m-ut-ruolo').value, 10);
  const idGruppo = parseInt(document.getElementById('m-ut-gruppo').value, 10);
  const responsabile = document.getElementById('m-ut-resp').checked;
  const ceo = document.getElementById('m-ut-ceo').checked;
  const pwd = document.getElementById('m-ut-pwd').value.trim();

  let res;
  if (matricola) {
    const body = { codRuolo, idGruppo, responsabile, ceo };
    if (pwd) body.password = pwd;
    res = await apiCall('/utenti/' + matricola, 'PUT', body);
  } else {
    const body = {
      matricola: document.getElementById('m-ut-matr').value.trim(),
      nome: document.getElementById('m-ut-nome').value.trim(),
      cognome: document.getElementById('m-ut-cognome').value.trim(),
      email: document.getElementById('m-ut-email').value.trim(),
      password: pwd,
      codRuolo, idGruppo, responsabile, ceo
    };
    if (!body.matricola || !body.nome || !body.cognome || !body.email || !body.password) {
      showToast('Compila tutti i campi obbligatori.'); return;
    }
    res = await apiCall('/utenti', 'POST', body);
  }
  if (res.errore) { showToast('Errore: ' + res.errore, 4000); return; }
  showToast(matricola ? '✓ Utente aggiornato' : '✓ Utente creato');
  chiudiModal();
  _ceoUtentiCache = [];
  loadCeoPersonale();
  loadCeoDashboard();
}

// ── Ferie (tutti i gruppi) ────────────────────────────────────────────────────

async function loadCeoFerie() {
  const el = document.getElementById('ceo-ferie-list');
  const fGruppo = document.getElementById('ceo-ferie-gruppo');
  // Popola il filtro gruppo una volta.
  if (fGruppo && fGruppo.dataset.popolato !== '1') {
    fGruppo.innerHTML = '<option value="">Tutti i gruppi</option>' +
      Object.keys(_gruppiCache).map(id =>
        `<option value="${id}">${escHTML(_gruppiCache[id])}</option>`).join('');
    fGruppo.dataset.popolato = '1';
  }
  const qs = fGruppo && fGruppo.value ? '?gruppo=' + encodeURIComponent(fGruppo.value) : '';
  try {
    const data = await apiCall('/ferie' + qs);
    if (data.errore) { el.innerHTML = errBox(data.errore); return; }
    const list = data.ferie || [];
    if (_calCeo) _calCeo.setFerie(list);
    if (!list.length) { el.innerHTML = '<div class="loading-row">Nessuna richiesta.</div>'; return; }
    el.innerHTML = '<div class="ferie-list">' +
      list.map(f => ferieItemHTML(f, true)).join('') + '</div>';
  } catch (e) {
    el.innerHTML = errBox('Errore caricamento ferie.');
  }
}

// ── Vincoli ───────────────────────────────────────────────────────────────────

async function loadCeoVincoli() {
  const el = document.getElementById('ceo-vincoli-list');
  try {
    const data = await apiCall('/vincoli');
    if (data.errore) { el.innerHTML = errBox(data.errore); return; }
    const list = data.vincoli || [];
    if (_calCeo) _calCeo.setVincoli(list);
    if (!list.length) { el.innerHTML = '<div class="loading-row">Nessun vincolo.</div>'; return; }
    el.innerHTML = '<div class="vincoli-list">' + list.map(v => `
      <div class="vincolo-item">
        <div class="vincolo-head">
          <span class="vincolo-badge ${v.tipoPeriodo === 'Bloccato' ? 'bloccato' : 'sconsigliato'}">${v.tipoPeriodo}</span>
          <span class="vincolo-date">${fmtDate(v.inizio)} → ${fmtDate(v.fine)}</span>
          <button class="btn-mini" onclick="modalVincolo(${v.id})">
            <i class="ti ti-edit" aria-hidden="true"></i> Modifica</button>
          <button class="btn-mini-danger" onclick="eliminaVincolo(${v.id})">
            <i class="ti ti-trash" aria-hidden="true"></i> Elimina</button>
        </div>
        <div class="vincolo-target">
          <i class="ti ti-users-group" style="font-size:12px;vertical-align:-1px;margin-right:3px;" aria-hidden="true"></i>
          ${escHTML(v.globale
            ? 'Tutti i gruppi e ruoli'
            : v.limitazioni.map(l => nomeGruppo(l.idGruppo) + ' / ' + nomeRuolo(l.codRuolo)).join(' · '))}
        </div>
      </div>`).join('') + '</div>';
  } catch (e) {
    el.innerHTML = errBox('Errore caricamento vincoli.');
  }
}

async function modalVincolo(id) {
  const v = id ? (await apiCall('/vincoli')).vincoli.find(x => x.id === id) : null;

  // Multi-select gruppi: "" = Tutti i gruppi.
  const selGruppi = new Set(v && !v.globale ? v.limitazioni.map(l => String(l.idGruppo)) : []);
  const selRuoli  = new Set(v && !v.globale ? v.limitazioni.map(l => String(l.codRuolo)) : []);
  const optG = `<option value="" ${selGruppi.has('null') || (v && v.globale) ? 'selected' : ''}>— Tutti i gruppi —</option>` +
    Object.keys(_gruppiCache).map(g =>
      `<option value="${g}" ${selGruppi.has(g) ? 'selected' : ''}>${escHTML(_gruppiCache[g])}</option>`).join('');
  const optR = `<option value="" ${selRuoli.has('null') || (v && v.globale) ? 'selected' : ''}>— Tutti i ruoli —</option>` +
    Object.keys(_ruoliCache).map(r =>
      `<option value="${r}" ${selRuoli.has(r) ? 'selected' : ''}>${escHTML(_ruoliCache[r])}</option>`).join('');

  apriModal(id ? 'Modifica vincolo' : 'Nuovo vincolo', `
    <div class="modal-grid">
      <div class="field-form">
        <label>Data inizio</label>
        <input type="date" id="m-vin-inizio" value="${v ? v.inizio : ''}" />
      </div>
      <div class="field-form">
        <label>Data fine</label>
        <input type="date" id="m-vin-fine" value="${v ? v.fine : ''}" />
      </div>
      <div class="field-form">
        <label>Tipo periodo</label>
        <select id="m-vin-tipo">
          <option value="Bloccato" ${v && v.tipoPeriodo === 'Bloccato' ? 'selected' : ''}>Bloccato</option>
          <option value="Sconsigliato" ${v && v.tipoPeriodo === 'Sconsigliato' ? 'selected' : ''}>Sconsigliato</option>
        </select>
      </div>
    </div>
    <div class="modal-grid">
      <div class="field-form">
        <label>Gruppi (Ctrl/Cmd per multipla)</label>
        <select id="m-vin-gruppi" multiple size="4">${optG}</select>
      </div>
      <div class="field-form">
        <label>Ruoli (Ctrl/Cmd per multipla)</label>
        <select id="m-vin-ruoli" multiple size="4">${optR}</select>
      </div>
    </div>
    <p class="modal-hint">Selezionando solo "Tutti" per entrambi il vincolo sarà globale.
       I parametri quantitativi (minG, maxG, nMin…) non sono ancora gestiti dalla UI.</p>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="chiudiModal()">Annulla</button>
      <button class="btn-submit" onclick="salvaVincolo(${id || 'null'})">Salva</button>
    </div>`);
}

async function salvaVincolo(id) {
  const inizio = document.getElementById('m-vin-inizio').value;
  const fine = document.getElementById('m-vin-fine').value;
  const tipo = document.getElementById('m-vin-tipo').value;
  if (!inizio || !fine) { showToast('Inserisci data inizio e fine.'); return; }
  if (fine < inizio) { showToast('La data fine deve essere successiva.'); return; }

  // "" nell'elenco = Tutti (null). Nessuna selezione = Tutti.
  const valGruppi = [...document.getElementById('m-vin-gruppi').selectedOptions]
    .map(o => o.value === '' ? null : parseInt(o.value, 10));
  const valRuoli = [...document.getElementById('m-vin-ruoli').selectedOptions]
    .map(o => o.value === '' ? null : parseInt(o.value, 10));
  const gruppi = valGruppi.length ? valGruppi : [null];
  const ruoli  = valRuoli.length ? valRuoli : [null];

  // Prodotto cartesiano gruppi × ruoli.
  let limitazioni = [];
  gruppi.forEach(g => ruoli.forEach(r => limitazioni.push({ idGruppo: g, codRuolo: r })));
  // Singola riga (null, null) ⇒ vincolo globale ⇒ array vuoto.
  if (limitazioni.length === 1 && limitazioni[0].idGruppo === null && limitazioni[0].codRuolo === null) {
    limitazioni = [];
  }

  const body = { inizio, fine, tipoPeriodo: tipo, limitazioni };
  const res = id
    ? await apiCall('/vincoli/' + id, 'PUT', body)
    : await apiCall('/vincoli', 'POST', body);
  if (res.errore) { showToast('Errore: ' + res.errore, 4000); return; }
  showToast(id ? '✓ Vincolo aggiornato' : '✓ Vincolo creato');
  chiudiModal();
  loadCeoVincoli();
  loadCeoDashboard();
}

// ── Helper ────────────────────────────────────────────────────────────────────

function errBox(msg) {
  return `<div class="loading-row" style="color:var(--color-text-danger)">${escHTML(msg)}</div>`;
}
