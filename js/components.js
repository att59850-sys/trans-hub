/* ============================================================
   components.js — reusable render helpers + modal/toast system
   ============================================================ */
(function (global) {
  'use strict';

  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const money = n => '$' + Number(n).toLocaleString(undefined, { maximumFractionDigits: 2 });
  const initials = name => (name || '?').trim().split(/\s+/).slice(0,2).map(w=>w[0]).join('').toUpperCase();
  const icon = (n, cls='') => `<span class="material-symbols-rounded ${cls}">${n}</span>`;

  function priceLabel(s) {
    if (!s) return 'Quote';
    if (s.unit === 'quote' || !s.price) return 'On quote';
    if (s.unit === 'flat') return money(s.price);
    return money(s.price) + ' / ' + s.unit.replace('per ', '');
  }

  function stars(avg) {
    const full = Math.round(avg);
    let out = '';
    for (let i = 1; i <= 5; i++) out += `<span class="material-symbols-rounded" style="font-size:15px;color:${i<=full?'var(--orange)':'var(--line)'};font-variation-settings:'FILL' 1">star</span>`;
    return `<span style="display:inline-flex">${out}</span>`;
  }

  /* ---- company card ---- */
  function companyCard(c) {
    const r = Store.ratingFor(c.id);
    const cat = catById(c.category);
    const fav = Store.isFav(c.id);
    const minPrice = (c.services || []).filter(s => s.price && s.unit !== 'quote').map(s => s.price).sort((a,b)=>a-b)[0];
    const cover = c.cover && c.cover.startsWith('linear') ? `background-image:${c.cover}` : `background:${c.cover||'#1565d8'}`;
    return `
    <article class="ccard" data-go="#/company/${c.id}">
      <div class="cover" style="${cover}">
        ${c.verified ? `<span class="verified">${icon('verified','')}Verified</span>` : ''}
        <button class="fav ${fav?'on':''}" data-fav="${c.id}" title="Save">${icon(fav?'favorite':'favorite_border')}</button>
      </div>
      <div class="body">
        <div class="cat">${esc(cat.name)}</div>
        <div class="top">
          <h3>${esc(c.name)}</h3>
          <span class="rating">${icon('star')}${r.avg||'—'}<span class="count">(${r.count})</span></span>
        </div>
        <p class="desc">${esc(c.tagline || c.description)}</p>
        <div class="meta">
          <span class="tag">${icon('location_on')}${esc(c.city)}</span>
          <span class="tag">${icon('local_shipping')}${c.fleetSize}+ fleet</span>
          ${(c.coverage||[]).slice(0,1).map(cv=>`<span class="tag">${icon('public')}${esc(cv)}</span>`).join('')}
        </div>
        <div class="foot">
          <span class="price">${minPrice?`from <b>${money(minPrice)}</b>`:'<b>Custom quote</b>'}</span>
          <button class="btn btn-accent btn-sm" data-go="#/company/${c.id}">${icon('event_available')}Book now</button>
        </div>
      </div>
    </article>`;
  }

  /* ---- toast ---- */
  function toast(msg, type='ok') {
    const root = document.getElementById('toastRoot');
    const el = document.createElement('div');
    el.className = 'toast ' + (type==='err'?'err':'ok');
    el.innerHTML = `${icon(type==='err'?'error':'check_circle')}<span>${esc(msg)}</span>`;
    root.appendChild(el);
    setTimeout(() => { el.style.opacity = '0'; el.style.transition='.3s'; setTimeout(()=>el.remove(), 320); }, 2600);
  }

  /* ---- modal ---- */
  function modal({ title, body, onMount }) {
    const root = document.getElementById('modalRoot');
    root.innerHTML = `
      <div class="modal-overlay" data-overlay>
        <div class="modal" role="dialog" aria-modal="true">
          <div class="modal-head"><h3>${esc(title)}</h3><button class="modal-close" data-close>${icon('close')}</button></div>
          <div class="modal-body">${body}</div>
        </div>
      </div>`;
    const overlay = root.querySelector('[data-overlay]');
    const close = () => { root.innerHTML = ''; };
    overlay.addEventListener('click', e => { if (e.target === overlay) close(); });
    root.querySelector('[data-close]').addEventListener('click', close);
    document.addEventListener('keydown', function esc(e){ if(e.key==='Escape'){ close(); document.removeEventListener('keydown', esc);} });
    if (onMount) onMount(root.querySelector('.modal-body'), close);
    return close;
  }

  function emptyState(icn, title, sub, action='') {
    return `<div class="empty">${icon(icn)}<h3 style="margin:10px 0 4px;color:var(--ink)">${esc(title)}</h3><p>${esc(sub)}</p>${action}</div>`;
  }

  global.UI = { esc, money, initials, icon, priceLabel, stars, companyCard, toast, modal, emptyState };
})(window);
