/* ============================================================
   store.js — offline-first state layer (localStorage)
   Acts as a tiny "backend": users, companies, services, bookings,
   reviews, favorites. Everything persists in the browser.
   ============================================================ */
(function (global) {
  'use strict';

  const KEY = 'transporthub.v2';

  const Store = {
    state: null,

    /* ---- persistence ---- */
    load() {
      try {
        const raw = localStorage.getItem(KEY);
        if (raw) { this.state = JSON.parse(raw); }
      } catch (e) { console.warn('store load failed', e); }
      if (!this.state || !this.state.companies) {
        this.state = global.SEED_DATA ? global.SEED_DATA() : this._empty();
        this.save();
      }
      // forward-compat: ensure arrays exist
      ['companies', 'users', 'bookings', 'reviews'].forEach(k => {
        if (!Array.isArray(this.state[k])) this.state[k] = [];
      });
      if (!this.state.session) this.state.session = null;
      if (!Array.isArray(this.state.favorites)) this.state.favorites = [];
      if (!this.state.location) this.state.location = '';
      return this.state;
    },
    save() {
      try { localStorage.setItem(KEY, JSON.stringify(this.state)); }
      catch (e) { console.warn('store save failed', e); }
    },
    reset() { localStorage.removeItem(KEY); this.state = null; this.load(); },
    _empty() { return { companies: [], users: [], bookings: [], reviews: [], favorites: [], session: null, location: '' }; },

    /* ---- ids ---- */
    id(prefix) { return prefix + '_' + Math.random().toString(36).slice(2, 9) + Date.now().toString(36).slice(-4); },

    /* ---- session / auth ---- */
    currentUser() {
      if (!this.state.session) return null;
      return this.state.users.find(u => u.id === this.state.session) || null;
    },
    signup({ name, email, password, role, companyName }) {
      email = (email || '').trim().toLowerCase();
      if (this.state.users.some(u => u.email === email)) {
        throw new Error('An account with that email already exists.');
      }
      const user = { id: this.id('u'), name, email, password, role, createdAt: Date.now(), companyId: null };
      if (role === 'company') {
        const company = this.createCompany({ name: companyName || (name + "'s Transport"), ownerId: user.id });
        user.companyId = company.id;
      }
      this.state.users.push(user);
      this.state.session = user.id;
      this.save();
      return user;
    },
    login({ email, password }) {
      email = (email || '').trim().toLowerCase();
      const user = this.state.users.find(u => u.email === email && u.password === password);
      if (!user) throw new Error('Invalid email or password.');
      this.state.session = user.id;
      this.save();
      return user;
    },
    logout() { this.state.session = null; this.save(); },

    /* ---- companies ---- */
    createCompany({ name, ownerId }) {
      const company = {
        id: this.id('c'), name, ownerId,
        category: 'freight',
        tagline: 'New transport provider on TransportHub.',
        description: 'Tell customers about your fleet, coverage area and what makes you reliable.',
        city: this.state.location || 'Your City',
        coverage: ['Local'], fleetSize: 1, yearsActive: 0, verified: false,
        cover: pickCover('freight'),
        services: [], createdAt: Date.now()
      };
      this.state.companies.push(company);
      this.save();
      return company;
    },
    getCompany(id) { return this.state.companies.find(c => c.id === id) || null; },
    myCompany() {
      const u = this.currentUser();
      if (!u || u.role !== 'company') return null;
      return this.getCompany(u.companyId);
    },
    updateCompany(id, patch) {
      const c = this.getCompany(id); if (!c) return null;
      Object.assign(c, patch); this.save(); return c;
    },

    /* ---- services ---- */
    addService(companyId, svc) {
      const c = this.getCompany(companyId); if (!c) return null;
      const service = Object.assign({ id: this.id('s'), active: true }, svc);
      c.services.push(service); this.save(); return service;
    },
    updateService(companyId, serviceId, patch) {
      const c = this.getCompany(companyId); if (!c) return null;
      const s = c.services.find(x => x.id === serviceId); if (!s) return null;
      Object.assign(s, patch); this.save(); return s;
    },
    removeService(companyId, serviceId) {
      const c = this.getCompany(companyId); if (!c) return;
      c.services = c.services.filter(s => s.id !== serviceId); this.save();
    },

    /* ---- bookings ---- */
    createBooking(b) {
      const booking = Object.assign({
        id: this.id('b'), status: 'pending', createdAt: Date.now()
      }, b);
      this.state.bookings.push(booking); this.save(); return booking;
    },
    bookingsForCompany(companyId) { return this.state.bookings.filter(b => b.companyId === companyId).sort((a,b)=>b.createdAt-a.createdAt); },
    bookingsForUser(userId) { return this.state.bookings.filter(b => b.userId === userId).sort((a,b)=>b.createdAt-a.createdAt); },
    setBookingStatus(id, status) {
      const b = this.state.bookings.find(x => x.id === id); if (!b) return;
      b.status = status; this.save();
    },

    /* ---- reviews ---- */
    addReview(companyId, { userId, name, rating, text }) {
      const r = { id: this.id('r'), companyId, userId, name, rating, text, createdAt: Date.now() };
      this.state.reviews.push(r); this.save(); return r;
    },
    reviewsForCompany(companyId) { return this.state.reviews.filter(r => r.companyId === companyId).sort((a,b)=>b.createdAt-a.createdAt); },
    ratingFor(companyId) {
      const rs = this.reviewsForCompany(companyId);
      if (!rs.length) return { avg: 0, count: 0 };
      const avg = rs.reduce((s, r) => s + r.rating, 0) / rs.length;
      return { avg: Math.round(avg * 10) / 10, count: rs.length };
    },

    /* ---- favorites ---- */
    isFav(companyId) { return this.state.favorites.includes(companyId); },
    toggleFav(companyId) {
      const i = this.state.favorites.indexOf(companyId);
      if (i >= 0) this.state.favorites.splice(i, 1); else this.state.favorites.push(companyId);
      this.save(); return this.isFav(companyId);
    },

    /* ---- location ---- */
    setLocation(loc) { this.state.location = loc; this.save(); }
  };

  // cover image helper (deterministic-ish)
  function pickCover(cat) {
    const map = {
      freight:   'linear-gradient(135deg,#1565d8,#0f4fb0)',
      movers:    'linear-gradient(135deg,#ff7a18,#f06400)',
      courier:   'linear-gradient(135deg,#138a55,#0e6e44)',
      coach:     'linear-gradient(135deg,#7c3aed,#5b21b6)',
      ride:      'linear-gradient(135deg,#0ea5e9,#0369a1)',
      coldchain: 'linear-gradient(135deg,#06b6d4,#0e7490)',
      ferry:     'linear-gradient(135deg,#2563eb,#1e3a8a)',
      heavy:     'linear-gradient(135deg,#475569,#1e293b)',
      ev:        'linear-gradient(135deg,#16a34a,#15803d)',
      air:       'linear-gradient(135deg,#0891b2,#155e75)'
    };
    return map[cat] || map.freight;
  }
  Store.pickCover = pickCover;

  global.Store = Store;
})(window);
