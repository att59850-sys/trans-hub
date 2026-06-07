/* ============================================================
   app.js — router, app-bar, and interaction wiring
   ============================================================ */
(function (global) {
  'use strict';
  const { icon, esc, money, priceLabel, toast, modal } = UI;

  Store.load();
  document.getElementById('year').textContent = new Date().getFullYear();

  /* ---------- routing ---------- */
  function parseHash() {
    let h = location.hash.replace(/^#/, '') || '/';
    const [path, query] = h.split('?');
    const params = {};
    (query || '').split('&').forEach(p => { if (!p) return; const [k, v] = p.split('='); params[k] = decodeURIComponent(v || ''); });
    return { path, params };
  }

  function render() {
    const { path, params } = parseHash();
    const view = document.getElementById('view');
    let html = '';
    let mount = null;

    if (path === '/' || path === '') { html = Pages.home(); mount = mountHome; }
    else if (path === '/browse') { html = Pages.browse(params); mount = () => mountBrowse(params); }
    else if (path.startsWith('/company/')) { params.id = path.split('/')[2]; html = Pages.company(params); mount = () => mountCompany(params); }
    else if (path === '/login') { html = Pages.login(); mount = mountLogin; }
    else if (path === '/signup') { html = Pages.signup(params); mount = mountSignup; }
    else if (path === '/register-company') { html = Pages.registerCompany(); }
    else if (path === '/my-bookings') { html = Pages.myBookings(); }
    else if (path === '/dashboard') { html = Pages.dashboard(params); mount = () => mountDashboard(params); }
    else if (path === '/about') { html = Pages.about(); }
    else { html = UI.emptyState('explore_off', 'Page not found', 'The page you are looking for does not exist.'); }

    view.innerHTML = html;
    renderAppbar();
    if (mount) mount(view);
    window.scrollTo({ top: 0, behavior: 'instant' in window ? 'instant' : 'auto' });
  }

  function go(hash) { location.hash = hash; }

  /* ---------- app bar ---------- */
  function renderAppbar() {
    const u = Store.currentUser();
    const el = document.getElementById('appbarActions');
    const locLabel = document.getElementById('locLabel');
    locLabel.textContent = Store.state.location || 'Set location';

    if (!u) {
      el.innerHTML = `
        <a class="btn btn-ghost" href="#/register-company" data-link>${icon('add_business')}List business</a>
        <a class="btn btn-ghost" href="#/login" data-link>Log in</a>
        <a class="btn btn-primary" href="#/signup" data-link>${icon('person_add')}Sign up</a>`;
    } else {
      const dash = u.role === 'company'
        ? `<a class="btn btn-ghost" href="#/dashboard" data-link>${icon('dashboard')}Dashboard</a>`
        : `<a class="btn btn-ghost" href="#/my-bookings" data-link>${icon('event_note')}My bookings</a>`;
      el.innerHTML = `
        ${dash}
        <button class="avatar-btn" id="userMenuBtn" title="${esc(u.name)}">${UI.initials(u.name)}</button>`;
      setTimeout(() => {
        const b = document.getElementById('userMenuBtn');
        if (b) b.onclick = () => openUserMenu(u);
      }, 0);
    }
  }

  function openUserMenu(u) {
    modal({
      title: u.name,
      body: `
        <p class="muted" style="margin-top:0">${esc(u.email)} · <strong>${u.role==='company'?'Provider':'Customer'}</strong></p>
        <div class="form">
          ${u.role==='company'
            ? `<a class="btn btn-outline btn-block" href="#/dashboard" data-link data-close-on-click>${icon('dashboard')}Dashboard</a>`
            : `<a class="btn btn-outline btn-block" href="#/my-bookings" data-link data-close-on-click>${icon('event_note')}My bookings</a>`}
          <button class="btn btn-primary btn-block" id="logoutBtn">${icon('logout')}Log out</button>
        </div>`,
      onMount: (body, close) => {
        body.querySelector('#logoutBtn').onclick = () => { Store.logout(); close(); toast('Logged out'); go('#/'); render(); };
        body.querySelectorAll('[data-close-on-click]').forEach(a => a.addEventListener('click', close));
      }
    });
  }

  /* ---------- location picker ---------- */
  document.getElementById('locBtn').addEventListener('click', () => {
    modal({
      title: 'Set your location',
      body: `<form class="form" id="locForm">
        <div class="field"><label class="field-label">City or area</label><input name="loc" placeholder="e.g. Chicago, IL" value="${esc(Store.state.location)}" autofocus></div>
        <button class="btn btn-primary btn-block" type="submit">${icon('check')}Save location</button>
      </form>`,
      onMount: (body, close) => {
        body.querySelector('#locForm').onsubmit = e => {
          e.preventDefault();
          const loc = e.target.loc.value.trim();
          Store.setLocation(loc); close(); renderAppbar();
          toast(loc ? 'Location set to ' + loc : 'Location cleared');
        };
      }
    });
  });

  /* ---------- global search ---------- */
  const search = document.getElementById('globalSearch');
  search.addEventListener('keydown', e => {
    if (e.key === 'Enter') { const q = search.value.trim(); go('#/browse?q=' + encodeURIComponent(q)); }
  });

  /* ---------- delegated clicks (links, cards, favorites) ---------- */
  document.body.addEventListener('click', e => {
    const fav = e.target.closest('[data-fav]');
    if (fav) {
      e.preventDefault(); e.stopPropagation();
      const on = Store.toggleFav(fav.getAttribute('data-fav'));
      toast(on ? 'Saved to favorites' : 'Removed from favorites');
      render();
      return;
    }
    const go2 = e.target.closest('[data-go]');
    if (go2 && !e.target.closest('[data-fav]')) { go(go2.getAttribute('data-go')); return; }
    const link = e.target.closest('a[data-link]');
    if (link) { /* hash navigation handled by browser; nothing needed */ }
  });

  /* ============================================================
     PAGE MOUNTS
     ============================================================ */
  function mountHome() {
    const form = document.getElementById('heroSearch');
    if (form) form.onsubmit = e => {
      e.preventDefault();
      const cat = document.getElementById('heroCat').value;
      const loc = document.getElementById('heroLoc').value.trim();
      if (loc) Store.setLocation(loc);
      go('#/browse' + (cat ? '?cat=' + cat : ''));
    };
    document.querySelectorAll('#homeChips .chip').forEach(ch => {
      ch.onclick = () => go('#/browse?cat=' + ch.getAttribute('data-cat'));
    });
  }

  function mountBrowse(params) {
    document.querySelectorAll('input[name="cat"]').forEach(r => {
      r.onchange = () => updateBrowse(params, { cat: r.value });
    });
    const sort = document.getElementById('sortSel');
    if (sort) sort.onchange = () => updateBrowse(params, { sort: sort.value });
    const ver = document.getElementById('fVerified');
    if (ver) ver.onchange = () => updateBrowse(params, { verified: ver.checked ? '1' : '' });
    const clear = document.getElementById('clearFilters');
    if (clear) clear.onclick = () => go('#/browse');
  }
  function updateBrowse(params, patch) {
    const p = Object.assign({}, params, patch);
    const qs = Object.entries(p).filter(([, v]) => v).map(([k, v]) => k + '=' + encodeURIComponent(v)).join('&');
    go('#/browse' + (qs ? '?' + qs : ''));
  }

  function mountCompany(params) {
    const c = Store.getCompany(params.id);
    if (!c) return;
    const openQuote = () => bookingModal(c, null);
    ['quoteBtn', 'quoteBtn2'].forEach(id => { const b = document.getElementById(id); if (b) b.onclick = openQuote; });
    document.querySelectorAll('[data-book]').forEach(b => {
      b.onclick = () => { const s = c.services.find(x => x.id === b.getAttribute('data-book')); bookingModal(c, s); };
    });
    const call = document.getElementById('callBtn');
    if (call) call.onclick = () => toast('Demo: in a live app this would open chat/phone for ' + c.name);
    const wr = document.getElementById('writeReview');
    if (wr) wr.onclick = () => reviewModal(c);
  }

  function mountLogin() {
    const f = document.getElementById('loginForm');
    f.onsubmit = e => {
      e.preventDefault();
      try {
        const u = Store.login({ email: f.email.value, password: f.password.value });
        toast('Welcome back, ' + u.name.split(' ')[0]);
        go(u.role === 'company' ? '#/dashboard' : '#/');
        render();
      } catch (err) { document.getElementById('loginErr').textContent = err.message; }
    };
  }

  function mountSignup() {
    const toggle = document.getElementById('roleToggle');
    const form = document.getElementById('signupForm');
    toggle.querySelectorAll('button').forEach(btn => {
      btn.onclick = () => {
        toggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const role = btn.getAttribute('data-role');
        form.role.value = role;
        form.querySelector('.companyField').style.display = role === 'company' ? '' : 'none';
      };
    });
    form.onsubmit = e => {
      e.preventDefault();
      try {
        const u = Store.signup({
          name: form.name.value.trim(),
          email: form.email.value,
          password: form.password.value,
          role: form.role.value,
          companyName: form.companyName ? form.companyName.value.trim() : ''
        });
        toast('Account created — welcome!');
        go(u.role === 'company' ? '#/dashboard?tab=profile' : '#/');
        render();
      } catch (err) { document.getElementById('signupErr').textContent = err.message; }
    };
  }

  function mountDashboard(params) {
    const u = Store.currentUser();
    if (!u || u.role !== 'company') return;
    const c = Store.myCompany();
    const tab = params.tab || 'overview';

    if (tab === 'services') {
      const add = document.getElementById('addSvc');
      if (add) add.onclick = () => serviceModal(c, null);
      document.querySelectorAll('[data-edit-svc]').forEach(b => {
        b.onclick = () => serviceModal(c, c.services.find(s => s.id === b.getAttribute('data-edit-svc')));
      });
      document.querySelectorAll('[data-del-svc]').forEach(b => {
        b.onclick = () => {
          if (confirm('Remove this service?')) { Store.removeService(c.id, b.getAttribute('data-del-svc')); toast('Service removed'); render(); }
        };
      });
    }
    if (tab === 'bookings' || tab === 'overview') {
      document.querySelectorAll('[data-status]').forEach(sel => {
        sel.onchange = () => { Store.setBookingStatus(sel.getAttribute('data-status'), sel.value); toast('Booking updated'); };
      });
    }
    if (tab === 'profile') {
      const f = document.getElementById('profileForm');
      f.onsubmit = e => {
        e.preventDefault();
        Store.updateCompany(c.id, {
          name: f.name.value.trim(),
          tagline: f.tagline.value.trim(),
          category: f.category.value,
          city: f.city.value.trim(),
          fleetSize: parseInt(f.fleetSize.value) || 1,
          yearsActive: parseInt(f.yearsActive.value) || 0,
          coverage: f.coverage.value.split(',').map(s => s.trim()).filter(Boolean),
          description: f.description.value.trim(),
          cover: Store.pickCover(f.category.value)
        });
        toast('Profile saved');
        render();
      };
    }
  }

  /* ============================================================
     MODALS: booking / quote, review, service editor
     ============================================================ */
  function bookingModal(c, service) {
    const u = Store.currentUser();
    const services = (c.services || []).filter(s => s.active !== false);
    modal({
      title: service ? 'Book: ' + service.name : 'Request a quote — ' + c.name,
      body: `<form class="form" id="bookForm">
        <div class="field"><label class="field-label">Service</label>
          <select name="serviceId">
            <option value="">General quote request</option>
            ${services.map(s => `<option value="${s.id}" ${service && service.id === s.id ? 'selected' : ''}>${esc(s.name)} — ${priceLabel(s)}</option>`).join('')}
          </select>
        </div>
        <div class="row2">
          <div class="field"><label class="field-label">Pickup</label><input name="pickup" placeholder="From city/address" value="${esc(Store.state.location)}"></div>
          <div class="field"><label class="field-label">Drop-off</label><input name="dropoff" placeholder="To city/address"></div>
        </div>
        <div class="field"><label class="field-label">Preferred date</label><input type="date" name="date"></div>
        <div class="row2">
          <div class="field"><label class="field-label">Your name</label><input name="contactName" required value="${u ? esc(u.name) : ''}"></div>
          <div class="field"><label class="field-label">Email</label><input type="email" name="contactEmail" required value="${u ? esc(u.email) : ''}"></div>
        </div>
        <div class="field"><label class="field-label">Phone</label><input name="phone" placeholder="Optional"></div>
        <div class="field"><label class="field-label">Details</label><textarea name="notes" rows="3" placeholder="Cargo, weight, special requirements…"></textarea></div>
        <button class="btn btn-accent btn-block btn-lg" type="submit">${icon('send')}${service ? 'Confirm booking request' : 'Send quote request'}</button>
      </form>`,
      onMount: (body, close) => {
        body.querySelector('#bookForm').onsubmit = e => {
          e.preventDefault();
          const f = e.target;
          Store.createBooking({
            companyId: c.id,
            serviceId: f.serviceId.value || null,
            userId: u ? u.id : null,
            contactName: f.contactName.value.trim(),
            contactEmail: f.contactEmail.value.trim(),
            phone: f.phone.value.trim(),
            pickup: f.pickup.value.trim(),
            dropoff: f.dropoff.value.trim(),
            date: f.date.value,
            notes: f.notes.value.trim()
          });
          close();
          toast(service ? 'Booking request sent to ' + c.name : 'Quote request sent!');
          if (u && u.role === 'customer') { go('#/my-bookings'); render(); }
        };
      }
    });
  }

  function reviewModal(c) {
    const u = Store.currentUser();
    let rating = 5;
    modal({
      title: 'Review ' + c.name,
      body: `<form class="form" id="revForm">
        <div class="field"><label class="field-label">Your rating</label>
          <div id="starPick" style="display:flex;gap:4px;font-size:30px;cursor:pointer">
            ${[1,2,3,4,5].map(i => `<span class="material-symbols-rounded" data-star="${i}" style="color:var(--orange);font-variation-settings:'FILL' 1">star</span>`).join('')}
          </div>
        </div>
        <div class="field"><label class="field-label">Your name</label><input name="name" required value="${u ? esc(u.name) : ''}"></div>
        <div class="field"><label class="field-label">Review</label><textarea name="text" rows="3" required placeholder="How was your experience?"></textarea></div>
        <button class="btn btn-primary btn-block" type="submit">${icon('rate_review')}Post review</button>
      </form>`,
      onMount: (body, close) => {
        const paint = () => body.querySelectorAll('[data-star]').forEach(s => {
          s.style.color = (+s.getAttribute('data-star') <= rating) ? 'var(--orange)' : 'var(--line)';
        });
        body.querySelectorAll('[data-star]').forEach(s => {
          s.onclick = () => { rating = +s.getAttribute('data-star'); paint(); };
        });
        paint();
        body.querySelector('#revForm').onsubmit = e => {
          e.preventDefault();
          Store.addReview(c.id, { userId: u ? u.id : null, name: e.target.name.value.trim(), rating, text: e.target.text.value.trim() });
          close(); toast('Thanks for your review!'); render();
        };
      }
    });
  }

  function serviceModal(c, svc) {
    const editing = !!svc;
    const ICONS = ['local_shipping','package_2','inventory_2','directions_bus','local_taxi','ac_unit','precision_manufacturing','electric_bolt','send','directions_boat','bolt','schedule','home','flight','my_location','medical_services','eco'];
    modal({
      title: editing ? 'Edit service' : 'Add a service',
      body: `<form class="form" id="svcForm">
        <div class="field"><label class="field-label">Service name</label><input name="name" required value="${editing ? esc(svc.name) : ''}" placeholder="e.g. Same-day delivery"></div>
        <div class="field"><label class="field-label">Description</label><textarea name="desc" rows="2" placeholder="What's included?">${editing ? esc(svc.desc) : ''}</textarea></div>
        <div class="row2">
          <div class="field"><label class="field-label">Pricing model</label>
            <select name="unit">
              ${[['flat','Flat price'],['per mile','Per mile'],['per kg','Per kg'],['per pallet','Per pallet'],['per hour','Per hour'],['per day','Per day'],['per trip','Per trip'],['per vehicle','Per vehicle'],['monthly','Monthly'],['add-on','Add-on'],['quote','On quote']]
                .map(([v,l]) => `<option value="${v}" ${editing && svc.unit === v ? 'selected' : ''}>${l}</option>`).join('')}
            </select>
          </div>
          <div class="field"><label class="field-label">Price (USD)</label><input type="number" name="price" min="0" step="0.01" value="${editing ? svc.price : ''}" placeholder="0 for quote"></div>
        </div>
        <div class="field"><label class="field-label">Icon</label>
          <select name="icon">${ICONS.map(i => `<option value="${i}" ${editing && svc.icon === i ? 'selected' : ''}>${i}</option>`).join('')}</select>
        </div>
        <label class="row" style="display:flex;align-items:center;gap:8px"><input type="checkbox" name="active" ${(!editing || svc.active !== false) ? 'checked' : ''} style="accent-color:var(--blue);width:16px;height:16px"> Visible to customers</label>
        <button class="btn btn-primary btn-block" type="submit">${icon('save')}${editing ? 'Save service' : 'Add service'}</button>
      </form>`,
      onMount: (body, close) => {
        body.querySelector('#svcForm').onsubmit = e => {
          e.preventDefault();
          const f = e.target;
          const data = {
            name: f.name.value.trim(), desc: f.desc.value.trim(),
            unit: f.unit.value, price: parseFloat(f.price.value) || 0,
            icon: f.icon.value, active: f.active.checked
          };
          if (editing) Store.updateService(c.id, svc.id, data);
          else Store.addService(c.id, data);
          close(); toast(editing ? 'Service updated' : 'Service added'); render();
        };
      }
    });
  }

  /* ---------- boot ---------- */
  window.addEventListener('hashchange', render);
  render();
  global.go = go;
})(window);
