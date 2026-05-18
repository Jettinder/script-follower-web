// ── calendar.js ──────────────────────────────────────────────────────────────
//  Calendario mensile in vanilla JS (nessuna libreria esterna).
//  Griglia 7×N con navigazione mese precedente/successivo.
//  Colori dei giorni:
//    verde            = ferie approvate (proprie o del gruppo)
//    giallo           = ferie in attesa
//    rosso scuro      = periodo "Bloccato" da un vincolo
//    arancione tratt. = periodo "Sconsigliato"
//  Click su un giorno → popover con i dettagli.
//
//  API:  const cal = creaCalendario(container, { onDayClick });
//        cal.setFerie([...]);  cal.setVincoli([...]);  cal.render();
// ─────────────────────────────────────────────────────────────────────────────

function creaCalendario(container, opts) {
  if (!container) return { setFerie() {}, setVincoli() {}, render() {} };
  opts = opts || {};

  const MESI = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
                'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];
  const GIORNI = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  let mese = new Date();
  mese.setDate(1);
  let ferie = [];
  let vincoli = [];

  function isoDi(anno, m, d) {
    return anno + '-' + String(m + 1).padStart(2, '0') + '-' + String(d).padStart(2, '0');
  }

  // True se la data ISO è compresa nell'intervallo [inizio, fine] (stringhe ISO).
  function dentro(iso, inizio, fine) {
    return iso >= (inizio || '').substring(0, 10) && iso <= (fine || '').substring(0, 10);
  }

  function eventiDelGiorno(iso) {
    return {
      ferie:   ferie.filter(f => dentro(iso, f.inizio, f.fine)),
      vincoli: vincoli.filter(v => dentro(iso, v.inizio, v.fine))
    };
  }

  function render() {
    const anno = mese.getFullYear();
    const m = mese.getMonth();
    const primo = new Date(anno, m, 1);
    const offset = (primo.getDay() + 6) % 7;          // lunedì = 0
    const giorniMese = new Date(anno, m + 1, 0).getDate();
    const oggiIso = isoDi(new Date().getFullYear(), new Date().getMonth(), new Date().getDate());

    let celle = GIORNI.map(g => `<div class="cal-dow">${g}</div>`).join('');
    for (let i = 0; i < offset; i++) celle += '<div class="cal-cell cal-empty"></div>';

    for (let d = 1; d <= giorniMese; d++) {
      const iso = isoDi(anno, m, d);
      const ev = eventiDelGiorno(iso);
      const bloccato    = ev.vincoli.some(v => v.tipoPeriodo === 'Bloccato');
      const sconsigliato = ev.vincoli.some(v => v.tipoPeriodo === 'Sconsigliato');
      const approvata   = ev.ferie.some(f => f.stato === 'Approvato');
      const attesa      = ev.ferie.some(f => f.stato === 'In attesa');

      let cls = 'cal-cell';
      if (bloccato)        cls += ' cal-bloccato';
      else if (approvata)  cls += ' cal-approvato';
      else if (attesa)     cls += ' cal-attesa';
      if (sconsigliato && !bloccato) cls += ' cal-sconsigliato';
      if (iso === oggiIso) cls += ' cal-oggi';

      const marker = (ev.ferie.length || ev.vincoli.length) ? '<span class="cal-dot"></span>' : '';
      celle += `<div class="${cls}" data-iso="${iso}"><span class="cal-num">${d}</span>${marker}</div>`;
    }

    container.innerHTML = `
      <div class="cal-header">
        <button class="cal-nav" data-delta="-1" aria-label="Mese precedente">
          <i class="ti ti-chevron-left" aria-hidden="true"></i></button>
        <div class="cal-title">${MESI[m]} ${anno}</div>
        <button class="cal-nav" data-delta="1" aria-label="Mese successivo">
          <i class="ti ti-chevron-right" aria-hidden="true"></i></button>
      </div>
      <div class="cal-grid">${celle}</div>
      <div class="cal-legenda">
        <span><i class="cal-key cal-approvato"></i>Approvate</span>
        <span><i class="cal-key cal-attesa"></i>In attesa</span>
        <span><i class="cal-key cal-bloccato"></i>Bloccato</span>
        <span><i class="cal-key cal-sconsigliato"></i>Sconsigliato</span>
      </div>
      <div class="cal-popover" style="display:none;"></div>`;

    container.querySelectorAll('.cal-nav').forEach(btn => {
      btn.addEventListener('click', () => {
        mese.setMonth(mese.getMonth() + parseInt(btn.dataset.delta, 10));
        render();
      });
    });
    container.querySelectorAll('.cal-cell[data-iso]').forEach(cell => {
      cell.addEventListener('click', () => mostraPopover(cell));
    });
  }

  function mostraPopover(cell) {
    const iso = cell.dataset.iso;
    const ev = eventiDelGiorno(iso);
    const pop = container.querySelector('.cal-popover');

    let html = `<div class="cal-pop-title">${iso.split('-').reverse().join('/')}</div>`;

    ev.vincoli.forEach(v => {
      const cls = v.tipoPeriodo === 'Bloccato' ? 'bloccato' : 'sconsigliato';
      html += `<div class="cal-pop-row">
                 <span class="vincolo-badge ${cls}">${v.tipoPeriodo}</span>
               </div>`;
    });
    ev.ferie.forEach(f => {
      const nome = (f.nome || f.cognome)
        ? ((f.nome || '') + ' ' + (f.cognome || '')).trim()
        : 'Tu';
      html += `<div class="cal-pop-row">${statusPill(f.stato)}
                 <span class="cal-pop-nome">${nome}</span></div>`;
    });
    if (!ev.vincoli.length && !ev.ferie.length) {
      html += '<div class="cal-pop-row cal-pop-vuoto">Nessun evento in questa data.</div>';
    }
    if (typeof opts.onDayClick === 'function') {
      html += '<div class="cal-pop-azione">' + opts.onDayClick(iso) + '</div>';
    }
    html += '<button class="cal-pop-close" onclick="this.parentElement.style.display=\'none\'">Chiudi</button>';

    pop.innerHTML = html;
    pop.style.display = 'block';
  }

  render();

  return {
    setFerie(list)   { ferie = list || [];   render(); },
    setVincoli(list) { vincoli = list || []; render(); },
    render
  };
}
