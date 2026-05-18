const BASE = 'http://localhost:5000/api';
let _token = '', _utente = {};

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

    if (data.responsabile) {
      document.getElementById('resp-avatar').textContent = initiali(data.nome, data.cognome);
      document.getElementById('resp-name').textContent   = (data.nome || '') + ' ' + (data.cognome || '');
      showPage('page-responsabile');
      loadRespFerie();
      loadTeam();
    } else {
      document.getElementById('dip-avatar').textContent = initiali(data.nome, data.cognome);
      document.getElementById('dip-name').textContent   = (data.nome || '') + ' ' + (data.cognome || '');
      showPage('page-dipendente');
      loadDipFerie();
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
  document.getElementById('inp-email').value = '';
  document.getElementById('inp-pwd').value   = '';
  document.getElementById('login-error').style.display = 'none';
  ['dip-ferie-list', 'resp-ferie-list', 'resp-team-list'].forEach(id => {
    document.getElementById(id).innerHTML = '<div class="loading-row"><span class="spinner"></span>Caricamento...</div>';
  });
  showPage('page-login');
}

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
    if (!list.length) {
      el.innerHTML = '<div class="loading-row">Nessuna richiesta inviata.</div>';
      return;
    }
    el.innerHTML = '<div class="ferie-list">' + list.map(f => ferieItemHTML(f, false)).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento dati.</div>';
  }
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
    if (data.errore) { showToast('Errore: ' + data.errore); return; }
    showToast('✓ Richiesta inviata con successo!');
    document.getElementById('dip-inizio').value = '';
    document.getElementById('dip-fine').value   = '';
    loadDipFerie();
  } catch (e) {
    showToast('Errore di rete.');
  } finally {
    btn.disabled = false;
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
    if (!list.length) {
      el.innerHTML = '<div class="loading-row">Nessuna richiesta nel gruppo.</div>';
      return;
    }
    el.innerHTML = '<div class="ferie-list">' + list.map(f => ferieItemHTML(f, true)).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento dati.</div>';
  }
}

async function gestisciFerie(id, nuovoStato) {
  try {
    const data = await apiCall('/ferie/' + id + '/approva', 'PUT', { stato: nuovoStato });
    if (data.errore) { showToast('Errore: ' + data.errore); return; }
    showToast(nuovoStato === 'Approvato' ? '✓ Richiesta approvata' : '✗ Richiesta rifiutata');
    loadRespFerie();
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
          <div class="member-role">${m.responsabile ? 'Responsabile' : 'Dipendente'} · ${m.ruolo || ''}</div>
        </div>
      </div>`).join('') + '</div>';
  } catch (e) {
    el.innerHTML = '<div class="loading-row" style="color:var(--color-text-danger)">Errore caricamento team.</div>';
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
                ${c.nome || ''} ${c.cognome || ''}${c.responsabile ? ' <span class="role-badge resp" style="font-size:10px;padding:1px 6px;">Resp.</span>' : ''}
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
  document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
  document.getElementById(tabId).classList.add('active');
  btn.classList.add('active');
}

// ── Init ──────────────────────────────────────────────────────────────────────

document.getElementById('inp-pwd').addEventListener('keydown', e => {
  if (e.key === 'Enter') doLogin();
});
