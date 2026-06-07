/* ============================================================
   data.js — service categories (incl. NEW services) + seed data
   ============================================================ */
(function (global) {
  'use strict';

  /* ---- Transport service categories ----
     `isNew:true` flags services newly introduced in this release. */
  const CATEGORIES = [
    { id: 'freight',   name: 'Freight & Cargo',     icon: 'local_shipping',   blurb: 'Full-load & part-load road freight' },
    { id: 'movers',    name: 'Movers & Relocation', icon: 'inventory_2',      blurb: 'Home & office moving, packing' },
    { id: 'courier',   name: 'Courier & Parcel',    icon: 'package_2',        blurb: 'Same-day & express delivery' },
    { id: 'coach',     name: 'Coach & Bus',         icon: 'directions_bus',   blurb: 'Group travel & charters' },
    { id: 'ride',      name: 'Ride & Taxi',         icon: 'local_taxi',       blurb: 'On-demand passenger rides' },
    // ----- NEW services introduced in this release -----
    { id: 'coldchain', name: 'Cold-Chain Logistics', icon: 'ac_unit',         blurb: 'Refrigerated & temperature-controlled', isNew: true },
    { id: 'heavy',     name: 'Heavy Haul & Machinery', icon: 'precision_manufacturing', blurb: 'Oversized & abnormal loads', isNew: true },
    { id: 'ev',        name: 'Green / EV Fleet',    icon: 'electric_bolt',    blurb: 'Zero-emission electric delivery', isNew: true },
    { id: 'air',       name: 'Air & Drone Freight', icon: 'flightsd',         blurb: 'Air cargo & last-mile drone', isNew: true, _icon:'send' },
    { id: 'ferry',     name: 'Ferry & Marine',      icon: 'directions_boat',  blurb: 'Ro-Ro, container & marine transfer', isNew: true }
  ];
  // normalize icon (a couple of symbols renamed for clarity)
  CATEGORIES.forEach(c => { if (c._icon) c.icon = c._icon; });

  function catById(id) { return CATEGORIES.find(c => c.id === id) || CATEGORIES[0]; }

  /* ---- Seed companies & services ---- */
  function SEED_DATA() {
    const now = Date.now();
    const day = 86400000;

    const companies = [
      mk('TransGlobal Freight', 'freight', {
        tagline: 'Nationwide full-truckload & part-load freight you can track in real time.',
        city: 'Chicago, IL', coverage: ['National', 'Cross-border'], fleetSize: 120, yearsActive: 14, verified: true,
        services: [
          svc('Full Truckload (FTL)', 'Dedicated trailer for large shipments, door-to-door.', 'per mile', 2.4, 'local_shipping'),
          svc('Less-than-Truckload (LTL)', 'Share trailer space, pay only for what you ship.', 'per pallet', 65, 'pallet'),
          svc('Real-time GPS tracking', 'Live shipment visibility & ETA alerts.', 'add-on', 19, 'my_location')
        ]
      }),
      mk('SwiftMove Relocations', 'movers', {
        tagline: 'Stress-free home & office moves with full packing and insurance.',
        city: 'Austin, TX', coverage: ['Local', 'Long-distance'], fleetSize: 22, yearsActive: 9, verified: true,
        services: [
          svc('Local home move', '2-3 movers, truck, blankets & basic insurance.', 'per hour', 110, 'home'),
          svc('Full packing service', 'We pack, label and unpack everything.', 'flat', 380, 'inventory_2'),
          svc('Office relocation', 'After-hours moves to minimize downtime.', 'quote', 0, 'apartment')
        ]
      }),
      mk('RapidParcel Courier', 'courier', {
        tagline: 'Same-day and express parcel delivery across the metro area.',
        city: 'New York, NY', coverage: ['Local', 'Same-day'], fleetSize: 60, yearsActive: 6, verified: true,
        services: [
          svc('Same-day delivery', 'Picked up & delivered within 4 hours.', 'flat', 14, 'bolt'),
          svc('Express overnight', 'Guaranteed next-morning delivery.', 'flat', 9, 'schedule'),
          svc('Scheduled routes', 'Recurring B2B parcel runs.', 'monthly', 240, 'event_repeat')
        ]
      }),
      mk('Horizon Coaches', 'coach', {
        tagline: 'Modern coaches for tours, events, corporate and school travel.',
        city: 'Denver, CO', coverage: ['Regional', 'National'], fleetSize: 18, yearsActive: 20, verified: true,
        services: [
          svc('49-seat luxury coach', 'WiFi, restroom, reclining seats.', 'per day', 950, 'directions_bus'),
          svc('Minibus (16-seat)', 'Ideal for small groups & airport runs.', 'per day', 420, 'airport_shuttle'),
          svc('Event shuttle loop', 'Continuous shuttle for festivals & weddings.', 'quote', 0, 'sync')
        ]
      }),
      mk('CityRide Express', 'ride', {
        tagline: 'Reliable on-demand rides, airport transfers and corporate accounts.',
        city: 'Seattle, WA', coverage: ['Local'], fleetSize: 80, yearsActive: 5, verified: false,
        services: [
          svc('Standard ride', 'Comfortable sedan, up to 4 passengers.', 'per mile', 1.8, 'local_taxi'),
          svc('Airport transfer', 'Fixed-price meet & greet at the terminal.', 'flat', 45, 'flight'),
          svc('Corporate account', 'Monthly billing & priority dispatch.', 'monthly', 0, 'badge')
        ]
      }),
      // ----- NEW service providers -----
      mk('PolarLine Cold-Chain', 'coldchain', {
        tagline: 'Temperature-controlled logistics for food, pharma and perishables.',
        city: 'Miami, FL', coverage: ['National', 'Cross-border'], fleetSize: 35, yearsActive: 11, verified: true,
        services: [
          svc('Frozen (-18°C) transport', 'Deep-freeze trailers with data logging.', 'per mile', 3.1, 'ac_unit'),
          svc('Pharma (2-8°C) cold-chain', 'GDP-compliant, validated reefer units.', 'quote', 0, 'medical_services'),
          svc('Temperature data logging', 'Continuous monitoring & compliance report.', 'add-on', 29, 'thermostat')
        ]
      }),
      mk('TitanHaul Heavy Logistics', 'heavy', {
        tagline: 'Oversized, abnormal and project cargo with permits and escorts.',
        city: 'Houston, TX', coverage: ['National'], fleetSize: 14, yearsActive: 17, verified: true,
        services: [
          svc('Lowboy heavy haul', 'Up to 80-ton machinery & equipment.', 'quote', 0, 'precision_manufacturing'),
          svc('Permit & route survey', 'We handle abnormal-load permits & escorts.', 'flat', 650, 'route'),
          svc('Crane-assisted load/unload', 'On-site lifting for plant relocation.', 'quote', 0, 'construction')
        ]
      }),
      mk('VoltWay Green Fleet', 'ev', {
        tagline: 'Carbon-neutral urban delivery with a 100% electric fleet.',
        city: 'San Francisco, CA', coverage: ['Local', 'Same-day'], fleetSize: 40, yearsActive: 3, verified: true,
        services: [
          svc('EV same-day delivery', 'Zero-emission vans across the city.', 'flat', 16, 'electric_bolt'),
          svc('Carbon-neutral courier', 'Bike + EV last-mile with offset report.', 'flat', 8, 'eco'),
          svc('Sustainability reporting', 'Monthly CO₂ savings dashboard.', 'monthly', 49, 'monitoring')
        ]
      }),
      mk('AeroDrop Air & Drone', 'air', {
        tagline: 'Time-critical air freight plus pioneering last-mile drone delivery.',
        city: 'Atlanta, GA', coverage: ['National', 'Last-mile'], fleetSize: 25, yearsActive: 4, verified: false,
        services: [
          svc('Air cargo (next-flight-out)', 'Urgent freight on the next departure.', 'per kg', 4.2, 'send'),
          svc('Last-mile drone delivery', 'Sub-5kg parcels delivered by drone.', 'flat', 22, 'flightsd'),
          svc('Medical / organ courier', 'Priority climate-safe air transport.', 'quote', 0, 'emergency')
        ]
      }),
      mk('BlueWave Ferry & Marine', 'ferry', {
        tagline: 'Ro-Ro vehicle ferries and container transfers along the coast.',
        city: 'San Diego, CA', coverage: ['Regional', 'Marine'], fleetSize: 8, yearsActive: 22, verified: true,
        services: [
          svc('Vehicle ferry (Ro-Ro)', 'Drive-on, drive-off car & truck ferry.', 'per vehicle', 120, 'directions_boat'),
          svc('Container marine transfer', 'Port-to-port container shipping.', 'quote', 0, 'anchor'),
          svc('Passenger + cargo combo', 'Mixed crossings for islands & coast.', 'per trip', 38, 'sailing')
        ]
      })
    ];

    // demo users (owners) + one customer
    const users = [];
    companies.forEach((c, i) => {
      const owner = { id: c.ownerId, name: c.name + ' Admin', email: ownerEmail(c.name), password: 'demo123', role: 'company', companyId: c.id, createdAt: now - (i+1)*day };
      users.push(owner);
    });
    users.push({ id: 'u_demo_customer', name: 'Demo Customer', email: 'customer@demo.com', password: 'demo123', role: 'customer', companyId: null, createdAt: now - day });

    // seed reviews
    const reviews = [];
    const sampleReviews = [
      ['Maria L.', 5, 'On time, professional and the live tracking was a game changer.'],
      ['James P.', 4, 'Good value. Communication could be a touch faster but overall solid.'],
      ['Aisha K.', 5, 'Handled fragile items with real care. Would book again instantly.'],
      ['Tom R.', 4, 'Fair quote, no hidden fees. Driver was friendly and efficient.'],
      ['Wei C.', 5, 'Exceeded expectations — smooth from booking to delivery.']
    ];
    companies.forEach((c, ci) => {
      const n = 2 + (ci % 3);
      for (let i = 0; i < n; i++) {
        const r = sampleReviews[(ci + i) % sampleReviews.length];
        reviews.push({ id: 'r_' + ci + '_' + i, companyId: c.id, userId: 'u_demo_customer', name: r[0], rating: r[1], text: r[2], createdAt: now - (i+1)*day });
      }
    });

    // a couple of seed bookings for the demo customer
    const bookings = [
      { id: 'b_seed1', companyId: companies[0].id, serviceId: companies[0].services[0].id, userId: 'u_demo_customer',
        contactName: 'Demo Customer', contactEmail: 'customer@demo.com', phone: '555-0100',
        pickup: 'Chicago, IL', dropoff: 'Detroit, MI', date: dateStr(2), notes: 'Two pallets, no rush.',
        status: 'confirmed', createdAt: now - 2*day },
      { id: 'b_seed2', companyId: companies[5].id, serviceId: companies[5].services[0].id, userId: 'u_demo_customer',
        contactName: 'Demo Customer', contactEmail: 'customer@demo.com', phone: '555-0100',
        pickup: 'Miami, FL', dropoff: 'Orlando, FL', date: dateStr(5), notes: 'Frozen seafood, -18°C.',
        status: 'pending', createdAt: now - day }
    ];

    return { companies, users, bookings, reviews, favorites: [], session: null, location: '' };

    /* helpers */
    function mk(name, category, extra) {
      const ownerId = 'u_owner_' + slug(name);
      return Object.assign({
        id: 'c_' + slug(name), name, ownerId, category,
        description: extra.tagline + ' We pride ourselves on reliability, transparent pricing and great service.',
        cover: global.Store ? global.Store.pickCover(category) : '#1565d8',
        services: []
      }, extra);
    }
    function svc(name, desc, unit, price, icon) { return { id: 's_' + slug(name), name, desc, unit, price, icon, active: true }; }
    function slug(s){ return s.toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_|_$/g,'').slice(0,28); }
    function ownerEmail(name){ return 'admin@' + slug(name).replace(/_/g,'') + '.com'; }
    function dateStr(plus){ const d=new Date(now+plus*day); return d.toISOString().slice(0,10); }
  }

  global.CATEGORIES = CATEGORIES;
  global.catById = catById;
  global.SEED_DATA = SEED_DATA;
})(window);
