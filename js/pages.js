/* ============================================================
   pages.js — view renderers. Each returns HTML; some attach
   behaviour via Pages.mount<View> after injection (handled in app.js).
   ============================================================ */
(function (global) {
  'use strict';
  const { esc, money, icon, priceLabel, stars, companyCard, toast, modal, emptyState, initials } = UI;

  const Pages = {};

  /* ===================== HOME ===================== */
  Pages.home = function () {
    const companies = Store.state.companies;
    const featured = [...companies].sort((a,b)=> Store.ratingFor(b.id).avg - Store.ratingFor(a.id).avg).slice(0,6);
    const newCats = CATEGORIES.filter(c => c.isNew);

    return `
    <section class="hero">
      <h1>Move anything, anywhere — with transport you can trust.</h1>
      <p>Compare vetted freight, moving, courier, cold-chain, heavy-haul and more. Get instant quotes and book in minutes.</p>
      <form class="hero-search" id="heroSearch">
        <div class="field">${icon('category')}
          <select id="heroCat">
            <option value="">Any service</option>
            ${CATEGORIES.map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('')}
          </select>
        </div>
        <div class="field">${icon('location_on')}
          <input id="heroLoc" placeholder="Pickup city or area" value="${esc(Store.state.location)}" />
        </div>
        <button class="btn btn-accent btn-lg" type="submit">${icon('search')}Search</button>
      </form>
      <div class="hero-stats">
        <div class="stat"><b>${companies.length}</b><span>Verified providers</span></div>
        <div class="stat"><b>${CATEGORIES.length}</b><span>Service categories</span></div>
        <div class="stat"><b>24/7</b><span>Booking & support</span></div>
        <div class="stat"><b>100%</b><span>Transparent pricing</span></div>
      </div>
    </section>

    <div class="section-head"><h2>Browse by service</h2><a class="link" href="#/browse" data-link>View all ${icon('arrow_forward')}</a></div>
    <div class="chips" id="homeChips">
      ${CATEGORIES.map(c=>`
        <button class="chip" data-cat="${c.id}">
          <span class="ico">${icon(c.icon)}</span>
          <span>${esc(c.name)}</span>
          ${c.isNew?'<span class="pill-new">New</span>':''}
        </button>`).join('')}
    </div>

    ${newCats.length ? `
    <div class="section-head"><h2>✨ Newly added services</h2></div>
    <div class="feature-row">
      ${newCats.map(c=>`
        <div class="feature" data-go="#/browse?cat=${c.id}" style="cursor:pointer">
          <div class="fi">${icon(c.icon)}</div>
          <h4>${esc(c.name)} <span class="pill-new">New</span></h4>
          <p>${esc(c.blurb)}</p>
        </div>`).join('')}
    </div>` : ''}

    <div class="section-head"><h2>Top-rated providers</h2><a class="link" href="#/browse" data-link>See more ${icon('arrow_forward')}</a></div>
    <div class="grid">${featured.map(companyCard).join('')}</div>

    <div class="banner-cta">
      <div>
        <h3>Run a transport business?</h3>
        <p>List your services free, reach new customers and manage bookings from one dashboard.</p>
      </div>
      <a class="btn btn-accent btn-lg" href="#/register-company" data-link>${icon('add_business')}List your business</a>
    </div>

    <div class="section-head"><h2>Why TransportHub</h2></div>
    <div class="feature-row">
      ${[
        ['verified_user','Vetted & verified','Every provider is reviewed before going live.'],
        ['payments','Transparent pricing','See rates up front or request a fast quote.'],
        ['reviews','Real reviews','Ratings from real bookings help you choose.'],
        ['support_agent','Always supported','Booking help whenever you need it.']
      ].map(f=>`<div class="feature"><div class="fi">${icon(f[0])}</div><h4>${f[1]}</h4><p>${f[2]}</p></div>`).join('')}
    </div>`;
  };

  /* ===================== BROWSE ===================== */
  Pages.browse = function (params) {
    const q = (params.q || '').toLowerCase();
    const activeCat = params.cat || '';
    const sort = params.sort || 'rating';
    const verifiedOnly = params.verified === '1';

    let list = Store.state.companies.filter(c => {
      if (activeCat && c.category !== activeCat) return false;
      if (verifiedOnly && !c.verified) return false;
      if (q) {
        const hay = (c.name + ' ' + c.tagline + ' ' + c.city + ' ' + (c.services||[]).map(s=>s.name).join(' ') + ' ' + catById(c.category).name).toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });

    const sorters = {
      rating: (a,b)=> Store.ratingFor(b.id).avg - Store.ratingFor(a.id).avg,
      reviews:(a,b)=> Store.ratingFor(b.id).count - Store.ratingFor(a.id).count,
      fleet:  (a,b)=> b.fleetSize - a.fleetSize,
      name:   (a,b)=> a.name.localeCompare(b.name)
    };
    list.sort(sorters[sort] || sorters.rating);

    return `
    <div class="browse">
      <aside class="filters">
        <h4>Service type</h4>
        <label class="row"><input type="radio" name="cat" value="" ${!activeCat?'checked':''} style="accent-color:var(--blue)"> All services</label>
        ${CATEGORIES.map(c=>`<label class="row"><input type="radio" name="cat" value="${c.id}" ${activeCat===c.id?'checked':''} style="accent-color:var(--blue)"> ${esc(c.name)} ${c.isNew?'<span class="pill-new">New</span>':''}</label>`).join('')}
        <div class="fgroup">
          <h4>Filters</h4>
          <label class="row"><input type="checkbox" id="fVerified" ${verifiedOnly?'checked':''}> Verified providers only</label>
        </div>
        <div class="fgroup">
          <button class="btn btn-outline btn-block" id="clearFilters">${icon('restart_alt')}Reset filters</button>
        </div>
      </aside>

      <section>
        <div class="browse-head">
          <div class="count">${list.length} provider${list.length!==1?'s':''} ${activeCat?`in ${esc(catById(activeCat).name)}`:''} ${q?`for “${esc(q)}”`:''}</div>
          <div class="sortbar">
            <span class="muted">Sort by</span>
            <select id="sortSel">
              <option value="rating" ${sort==='rating'?'selected':''}>Top rated</option>
              <option value="reviews" ${sort==='reviews'?'selected':''}>Most reviewed</option>
              <option value="fleet" ${sort==='fleet'?'selected':''}>Largest fleet</option>
              <option value="name" ${sort==='name'?'selected':''}>Name (A-Z)</option>
            </select>
          </div>
        </div>
        ${list.length ? `<div class="grid">${list.map(companyCard).join('')}</div>`
          : emptyState('search_off','No providers found','Try a different service type or clear your filters.')}
      </section>
    </div>`;
  };

  /* ===================== COMPANY PROFILE ===================== */
  Pages.company = function (params) {
    const c = Store.getCompany(params.id);
    if (!c) return emptyState('error','Company not found','It may have been removed.');
    const r = Store.ratingFor(c.id);
    const cat = catById(c.category);
    const reviews = Store.reviewsForCompany(c.id);
    const fav = Store.isFav(c.id);
    const cover = c.cover && c.cover.startsWith('linear') ? `background-image:${c.cover}` : `background:${c.cover||'#1565d8'}`;
    const activeServices = (c.services||[]).filter(s=>s.active!==false);

    return `
    <div class="profile-hero">
      <div class="banner" style="${cover}"></div>
      <div class="pbody">
        <div class="logo">${icon(cat.icon)}</div>
        <div style="flex:1;min-width:240px">
          <div class="cat">${esc(cat.name)} ${c.verified?`<span style="color:var(--ok)">· ${icon('verified')}Verified</span>`:''}</div>
          <h1>${esc(c.name)}</h1>
          <p class="muted" style="margin:4px 0">${esc(c.tagline)}</p>
          <div class="meta" style="display:flex;gap:8px;flex-wrap:wrap;margin-top:6px">
            <span class="rating">${icon('star')}${r.avg||'—'} <span class="count">(${r.count} reviews)</span></span>
            <span class="tag">${icon('location_on')}${esc(c.city)}</span>
            <span class="tag">${icon('local_shipping')}${c.fleetSize}+ vehicles</span>
            <span class="tag">${icon('history')}${c.yearsActive} yrs</span>
            ${(c.coverage||[]).map(cv=>`<span class="tag">${icon('public')}${esc(cv)}</span>`).join('')}
          </div>
        </div>
        <div style="display:flex;gap:8px">
          <button class="btn btn-outline" data-fav="${c.id}">${icon(fav?'favorite':'favorite_border')}${fav?'Saved':'Save'}</button>
          <button class="btn btn-accent" id="quoteBtn">${icon('request_quote')}Request a quote</button>
        </div>
      </div>
    </div>

    <div class="profile-grid">
      <div>
        <div class="section-head" style="margin-top:6px"><h2>Services & pricing</h2></div>
        ${activeServices.length ? activeServices.map(s=>`
          <div class="svc-row">
            <div class="sico">${icon(s.icon||'local_shipping')}</div>
            <div class="sinfo"><h4>${esc(s.name)}</h4><p>${esc(s.desc)}</p></div>
            <div class="sprice"><b>${priceLabel(s)}</b><div><button class="btn btn-primary btn-sm" data-book="${s.id}">${icon('event_available')}Book</button></div></div>
          </div>`).join('') : emptyState('inventory','No services listed yet','Check back soon.')}

        <div class="section-head"><h2>About</h2></div>
        <div class="panel"><p style="margin:0;color:var(--ink-2)">${esc(c.description)}</p></div>

        <div class="section-head"><h2>Reviews (${reviews.length})</h2></div>
        <div class="panel">
          ${reviews.length ? reviews.map(rv=>`
            <div class="review">
              <div class="rh"><span class="av">${initials(rv.name)}</span><div><strong>${esc(rv.name)}</strong><div>${stars(rv.rating)}</div></div></div>
              <p style="margin:4px 0 0;color:var(--ink-2)">${esc(rv.text)}</p>
            </div>`).join('') : `<p class="muted" style="margin:0">No reviews yet — be the first to review after booking.</p>`}
          <div style="margin-top:14px"><button class="btn btn-outline" id="writeReview">${icon('rate_review')}Write a review</button></div>
        </div>
      </div>

      <aside class="side-card">
        <div class="panel">
          <h3 style="margin:0 0 4px">Get started</h3>
          <p class="muted" style="margin:0 0 14px;font-size:14px">Book a service or request a custom quote — responses usually within 24h.</p>
          <button class="btn btn-accent btn-block" id="quoteBtn2">${icon('request_quote')}Request a quote</button>
          <div style="height:8px"></div>
          <button class="btn btn-outline btn-block" id="callBtn">${icon('call')}Contact provider</button>
          <hr style="border:none;border-top:1px solid var(--line);margin:16px 0">
          <div class="tag" style="margin:3px">${icon('verified_user')}${c.verified?'Identity verified':'Verification pending'}</div>
          <div class="tag" style="margin:3px">${icon('schedule')}Avg response < 24h</div>
        </div>
      </aside>
    </div>`;
  };

  /* ===================== AUTH ===================== */
  Pages.login = function () {
    return `
    <div class="auth-wrap panel">
      <h2>Welcome back</h2>
      <p class="muted">Log in to book services or manage your business.</p>
      <form class="form" id="loginForm" style="margin-top:14px">
        <div class="field"><label class="field-label">Email</label><input type="email" name="email" required placeholder="you@example.com"></div>
        <div class="field"><label class="field-label">Password</label><input type="password" name="password" required placeholder="••••••••"></div>
        <div class="err" id="loginErr"></div>
        <button class="btn btn-primary btn-block btn-lg" type="submit">${icon('login')}Log in</button>
      </form>
      <p class="muted" style="margin-top:14px;text-align:center">No account? <a href="#/signup" data-link style="color:var(--blue);font-weight:600">Sign up</a></p>
      <div class="panel" style="background:var(--blue-50);border-color:#cfe0fb;margin-top:16px">
        <strong style="font-size:14px">Demo logins</strong>
        <p class="muted" style="margin:6px 0 0;font-size:13px">Customer → <code>customer@demo.com</code> / <code>demo123</code><br>
        Provider → <code>admin@transglobalfreight.com</code> / <code>demo123</code></p>
      </div>
    </div>`;
  };

  Pages.signup = function (params) {
    const role = params.role === 'company' ? 'company' : 'customer';
    return `
    <div class="auth-wrap panel">
      <h2>Create your account</h2>
      <p class="muted">Join TransportHub in seconds.</p>
      <div class="role-toggle" id="roleToggle" style="margin-top:12px">
        <button type="button" data-role="customer" class="${role==='customer'?'active':''}">${icon('person')}I'm a customer</button>
        <button type="button" data-role="company" class="${role==='company'?'active':''}">${icon('store')}I'm a provider</button>
      </div>
      <form class="form" id="signupForm">
        <input type="hidden" name="role" value="${role}">
        <div class="field"><label class="field-label">Full name</label><input name="name" required placeholder="Jane Doe"></div>
        <div class="field companyField" style="${role==='company'?'':'display:none'}">
          <label class="field-label">Company name</label><input name="companyName" placeholder="Acme Transport Co.">
        </div>
        <div class="field"><label class="field-label">Email</label><input type="email" name="email" required placeholder="you@example.com"></div>
        <div class="field"><label class="field-label">Password</label><input type="password" name="password" required minlength="5" placeholder="At least 5 characters"></div>
        <div class="err" id="signupErr"></div>
        <button class="btn btn-primary btn-block btn-lg" type="submit">${icon('person_add')}Create account</button>
      </form>
      <p class="muted" style="margin-top:14px;text-align:center">Already have an account? <a href="#/login" data-link style="color:var(--blue);font-weight:600">Log in</a></p>
    </div>`;
  };

  Pages.registerCompany = function () {
    const u = Store.currentUser();
    if (u && u.role === 'company') { location.hash = '#/dashboard'; return ''; }
    return `
    <div class="auth-wrap panel">
      <h2>List your transport business</h2>
      <p class="muted">Reach thousands of customers searching for reliable transport. It's free to list.</p>
      <div class="feature-row" style="margin:14px 0">
        ${[['storefront','Free profile'],['event_available','Manage bookings'],['trending_up','Grow revenue']].map(f=>`<div class="feature" style="padding:14px"><div class="fi">${icon(f[0])}</div><h4 style="font-size:15px">${f[1]}</h4></div>`).join('')}
      </div>
      <a class="btn btn-accent btn-block btn-lg" href="#/signup?role=company" data-link>${icon('add_business')}Create provider account</a>
    </div>`;
  };

  /* ===================== CUSTOMER BOOKINGS ===================== */
  Pages.myBookings = function () {
    const u = Store.currentUser();
    if (!u) { location.hash = '#/login'; return ''; }
    const bookings = Store.bookingsForUser(u.id);
    return `
    <div class="section-head"><h2>My bookings</h2><a class="link" href="#/browse" data-link>Book another ${icon('add')}</a></div>
    ${bookings.length ? `
    <table class="table">
      <thead><tr><th>Provider</th><th>Service</th><th>Route</th><th>Date</th><th>Status</th></tr></thead>
      <tbody>
        ${bookings.map(b=>{
          const c = Store.getCompany(b.companyId);
          const s = c && c.services.find(x=>x.id===b.serviceId);
          return `<tr>
            <td><a href="#/company/${b.companyId}" data-link style="color:var(--blue);font-weight:600">${esc(c?c.name:'—')}</a></td>
            <td>${esc(s?s.name:b.serviceId||'Quote request')}</td>
            <td>${esc(b.pickup||'—')} → ${esc(b.dropoff||'—')}</td>
            <td>${esc(b.date||'—')}</td>
            <td><span class="badge ${b.status}">${esc(b.status)}</span></td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>` : emptyState('event_busy','No bookings yet','Browse providers and book your first service.',`<a class="btn btn-accent" href="#/browse" data-link style="margin-top:12px">${icon('search')}Browse services</a>`)}
    `;
  };

  /* ===================== PROVIDER DASHBOARD ===================== */
  Pages.dashboard = function (params) {
    const u = Store.currentUser();
    if (!u) { location.hash = '#/login'; return ''; }
    if (u.role !== 'company') return emptyState('lock','Provider area','This dashboard is for transport providers. Create a provider account to list services.',`<a class="btn btn-accent" href="#/signup?role=company" data-link style="margin-top:12px">${icon('add_business')}Become a provider</a>`);
    const c = Store.myCompany();
    const tab = params.tab || 'overview';
    const bookings = Store.bookingsForCompany(c.id);
    const r = Store.ratingFor(c.id);

    const nav = [
      ['overview','dashboard','Overview'],
      ['services','inventory_2','Services'],
      ['bookings','event_note','Bookings'],
      ['profile','storefront','Profile']
    ];

    let content = '';
    if (tab === 'overview') {
      const pending = bookings.filter(b=>b.status==='pending').length;
      content = `
        <div class="kpis">
          <div class="kpi">${icon('event_note')}<b>${bookings.length}</b><span>Total bookings</span></div>
          <div class="kpi">${icon('pending_actions')}<b>${pending}</b><span>Pending requests</span></div>
          <div class="kpi">${icon('inventory_2')}<b>${c.services.length}</b><span>Active services</span></div>
          <div class="kpi">${icon('star')}<b>${r.avg||'—'}</b><span>${r.count} reviews</span></div>
        </div>
        <div class="section-head"><h2>Recent bookings</h2><a class="link" href="#/dashboard?tab=bookings" data-link>View all ${icon('arrow_forward')}</a></div>
        ${bookingsTable(bookings.slice(0,5), c)}`;
    } else if (tab === 'services') {
      content = `
        <div class="section-head"><h2>Your services</h2><button class="btn btn-accent" id="addSvc">${icon('add')}Add service</button></div>
        ${c.services.length ? c.services.map(s=>`
          <div class="svc-row">
            <div class="sico">${icon(s.icon||'local_shipping')}</div>
            <div class="sinfo"><h4>${esc(s.name)} ${s.active===false?'<span class="badge cancelled">hidden</span>':''}</h4><p>${esc(s.desc)}</p></div>
            <div class="sprice"><b>${priceLabel(s)}</b></div>
            <div style="display:flex;gap:6px">
              <button class="btn btn-outline btn-sm" data-edit-svc="${s.id}">${icon('edit')}</button>
              <button class="btn btn-outline btn-sm" data-del-svc="${s.id}">${icon('delete')}</button>
            </div>
          </div>`).join('') : emptyState('inventory','No services yet','Add your first service so customers can book.')}`;
    } else if (tab === 'bookings') {
      content = `<div class="section-head"><h2>Bookings</h2></div>${bookingsTable(bookings, c, true)}`;
    } else if (tab === 'profile') {
      content = `
        <div class="section-head"><h2>Business profile</h2></div>
        <div class="panel">
          <form class="form" id="profileForm">
            <div class="field"><label class="field-label">Business name</label><input name="name" value="${esc(c.name)}" required></div>
            <div class="field"><label class="field-label">Tagline</label><input name="tagline" value="${esc(c.tagline)}"></div>
            <div class="field"><label class="field-label">Service category</label>
              <select name="category">${CATEGORIES.map(cat=>`<option value="${cat.id}" ${c.category===cat.id?'selected':''}>${esc(cat.name)}</option>`).join('')}</select>
            </div>
            <div class="row2">
              <div class="field"><label class="field-label">City / base</label><input name="city" value="${esc(c.city)}"></div>
              <div class="field"><label class="field-label">Fleet size</label><input type="number" name="fleetSize" value="${c.fleetSize}" min="1"></div>
            </div>
            <div class="row2">
              <div class="field"><label class="field-label">Years active</label><input type="number" name="yearsActive" value="${c.yearsActive}" min="0"></div>
              <div class="field"><label class="field-label">Coverage (comma separated)</label><input name="coverage" value="${esc((c.coverage||[]).join(', '))}"></div>
            </div>
            <div class="field"><label class="field-label">About your business</label><textarea name="description" rows="4">${esc(c.description)}</textarea></div>
            <button class="btn btn-primary btn-lg" type="submit">${icon('save')}Save changes</button>
          </form>
        </div>`;
    }

    return `
    <div class="dash">
      <nav class="dash-nav">
        <div style="padding:8px 12px;font-weight:800">${esc(c.name)}</div>
        ${nav.map(n=>`<a href="#/dashboard?tab=${n[0]}" data-link class="${tab===n[0]?'active':''}">${icon(n[1])}${n[2]}</a>`).join('')}
        <a href="#/company/${c.id}" data-link>${icon('open_in_new')}View public page</a>
      </nav>
      <section>${content}</section>
    </div>`;

    function bookingsTable(list, c, withActions) {
      if (!list.length) return emptyState('event_busy','No bookings yet','New requests will appear here.');
      return `<table class="table">
        <thead><tr><th>Customer</th><th>Service</th><th>Route</th><th>Date</th><th>Status</th>${withActions?'<th>Actions</th>':''}</tr></thead>
        <tbody>${list.map(b=>{
          const s = c.services.find(x=>x.id===b.serviceId);
          return `<tr>
            <td><strong>${esc(b.contactName||'—')}</strong><div class="muted" style="font-size:12px">${esc(b.contactEmail||'')}</div></td>
            <td>${esc(s?s.name:b.serviceId||'Quote request')}</td>
            <td>${esc(b.pickup||'—')} → ${esc(b.dropoff||'—')}</td>
            <td>${esc(b.date||'—')}</td>
            <td><span class="badge ${b.status}">${esc(b.status)}</span></td>
            ${withActions?`<td>
              <select data-status="${b.id}" style="padding:6px 8px;border:1px solid var(--line);border-radius:8px">
                ${['pending','confirmed','completed','cancelled'].map(st=>`<option value="${st}" ${b.status===st?'selected':''}>${st}</option>`).join('')}
              </select>
            </td>`:''}
          </tr>`;
        }).join('')}</tbody></table>`;
    }
  };

  /* ===================== ABOUT ===================== */
  Pages.about = function () {
    return `
    <section class="hero" style="padding:40px 36px">
      <h1>How TransportHub works</h1>
      <p>One marketplace connecting customers with trusted transport &amp; logistics providers — across every mode of transport.</p>
    </section>
    <div class="section-head"><h2>For customers</h2></div>
    <div class="feature-row">
      ${[['search','1. Search & compare','Filter by service, location and rating.'],
         ['request_quote','2. Book or get a quote','Instant booking or a fast custom quote.'],
         ['local_shipping','3. Track & relax','Stay updated and rate your experience.']].map(f=>`<div class="feature"><div class="fi">${icon(f[0])}</div><h4>${f[1]}</h4><p>${f[2]}</p></div>`).join('')}
    </div>
    <div class="section-head"><h2>For providers</h2></div>
    <div class="feature-row">
      ${[['add_business','List free','Create a profile and add your services.'],
         ['inbox','Receive requests','Bookings & quote requests in one inbox.'],
         ['insights','Grow','Build reviews and win repeat business.']].map(f=>`<div class="feature"><div class="fi">${icon(f[0])}</div><h4>${f[1]}</h4><p>${f[2]}</p></div>`).join('')}
    </div>
    <div class="banner-cta">
      <div><h3>Ready to get moving?</h3><p>Join as a customer or list your transport business today.</p></div>
      <div style="display:flex;gap:10px"><a class="btn btn-outline" href="#/signup" data-link style="background:#fff">${icon('person_add')}Sign up</a><a class="btn btn-accent" href="#/register-company" data-link>${icon('add_business')}List business</a></div>
    </div>`;
  };

  global.Pages = Pages;
})(window);
