import '../models/models.dart';

class SeedData {
  final List<Company> companies;
  final List<AppUser> users;
  final List<Booking> bookings;
  final List<Review> reviews;
  SeedData(this.companies, this.users, this.bookings, this.reviews);
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

TransportService _svc(
        String name, String desc, String unit, double price, String icon) =>
    TransportService(
        id: 's_${_slug(name)}',
        name: name,
        desc: desc,
        unit: unit,
        price: price,
        icon: icon);

/// Mirrors the web platform's seed catalog (original 5 + 5 new services),
/// integrating all providers, services, reviews and demo bookings.
SeedData buildSeedData() {
  final now = DateTime.now().millisecondsSinceEpoch;
  const day = 86400000;

  Company mk(
      String name,
      String category,
      String tagline,
      String city,
      List<String> coverage,
      int fleet,
      int years,
      bool verified,
      List<TransportService> services) {
    return Company(
      id: 'c_${_slug(name)}',
      ownerId: 'u_owner_${_slug(name)}',
      name: name,
      category: category,
      tagline: tagline,
      description:
          '$tagline We pride ourselves on reliability, transparent pricing and great service.',
      city: city,
      coverage: coverage,
      fleetSize: fleet,
      yearsActive: years,
      verified: verified,
      services: services,
    );
  }

  final companies = <Company>[
    mk(
        'TransGlobal Freight',
        'freight',
        'Nationwide full-truckload & part-load freight you can track in real time.',
        'Chicago, IL',
        ['National', 'Cross-border'],
        120,
        14,
        true,
        [
          _svc(
              'Full Truckload (FTL)',
              'Dedicated trailer for large shipments, door-to-door.',
              'per mile',
              2.4,
              'local_shipping'),
          _svc(
              'Less-than-Truckload (LTL)',
              'Share trailer space, pay only for what you ship.',
              'per pallet',
              65,
              'pallet'),
          _svc(
              'Real-time GPS tracking',
              'Live shipment visibility & ETA alerts.',
              'add-on',
              19,
              'my_location'),
        ]),
    mk(
        'SwiftMove Relocations',
        'movers',
        'Stress-free home & office moves with full packing and insurance.',
        'Austin, TX',
        ['Local', 'Long-distance'],
        22,
        9,
        true,
        [
          _svc(
              'Local home move',
              '2-3 movers, truck, blankets & basic insurance.',
              'per hour',
              110,
              'home'),
          _svc('Full packing service', 'We pack, label and unpack everything.',
              'flat', 380, 'inventory_2'),
          _svc('Office relocation', 'After-hours moves to minimize downtime.',
              'quote', 0, 'apartment'),
        ]),
    mk(
        'RapidParcel Courier',
        'courier',
        'Same-day and express parcel delivery across the metro area.',
        'New York, NY',
        ['Local', 'Same-day'],
        60,
        6,
        true,
        [
          _svc('Same-day delivery', 'Picked up & delivered within 4 hours.',
              'flat', 14, 'bolt'),
          _svc('Express overnight', 'Guaranteed next-morning delivery.', 'flat',
              9, 'schedule'),
          _svc('Scheduled routes', 'Recurring B2B parcel runs.', 'monthly', 240,
              'event_repeat'),
        ]),
    mk(
        'Horizon Coaches',
        'coach',
        'Modern coaches for tours, events, corporate and school travel.',
        'Denver, CO',
        ['Regional', 'National'],
        18,
        20,
        true,
        [
          _svc('49-seat luxury coach', 'WiFi, restroom, reclining seats.',
              'per day', 950, 'directions_bus'),
          _svc('Minibus (16-seat)', 'Ideal for small groups & airport runs.',
              'per day', 420, 'airport_shuttle'),
          _svc(
              'Event shuttle loop',
              'Continuous shuttle for festivals & weddings.',
              'quote',
              0,
              'sync'),
        ]),
    mk(
        'CityRide Express',
        'ride',
        'Reliable on-demand rides, airport transfers and corporate accounts.',
        'Seattle, WA',
        ['Local'],
        80,
        5,
        false,
        [
          _svc('Standard ride', 'Comfortable sedan, up to 4 passengers.',
              'per mile', 1.8, 'local_taxi'),
          _svc('Airport transfer', 'Fixed-price meet & greet at the terminal.',
              'flat', 45, 'flight'),
          _svc('Corporate account', 'Monthly billing & priority dispatch.',
              'monthly', 0, 'badge'),
        ]),
    // ---- New services ----
    mk(
        'PolarLine Cold-Chain',
        'coldchain',
        'Temperature-controlled logistics for food, pharma and perishables.',
        'Miami, FL',
        ['National', 'Cross-border'],
        35,
        11,
        true,
        [
          _svc(
              'Frozen (-18°C) transport',
              'Deep-freeze trailers with data logging.',
              'per mile',
              3.1,
              'ac_unit'),
          _svc(
              'Pharma (2-8°C) cold-chain',
              'GDP-compliant, validated reefer units.',
              'quote',
              0,
              'medical_services'),
          _svc(
              'Temperature data logging',
              'Continuous monitoring & compliance report.',
              'add-on',
              29,
              'thermostat'),
        ]),
    mk(
        'TitanHaul Heavy Logistics',
        'heavy',
        'Oversized, abnormal and project cargo with permits and escorts.',
        'Houston, TX',
        ['National'],
        14,
        17,
        true,
        [
          _svc('Lowboy heavy haul', 'Up to 80-ton machinery & equipment.',
              'quote', 0, 'precision_manufacturing'),
          _svc(
              'Permit & route survey',
              'We handle abnormal-load permits & escorts.',
              'flat',
              650,
              'route'),
          _svc(
              'Crane-assisted load/unload',
              'On-site lifting for plant relocation.',
              'quote',
              0,
              'construction'),
        ]),
    mk(
        'VoltWay Green Fleet',
        'ev',
        'Carbon-neutral urban delivery with a 100% electric fleet.',
        'San Francisco, CA',
        ['Local', 'Same-day'],
        40,
        3,
        true,
        [
          _svc('EV same-day delivery', 'Zero-emission vans across the city.',
              'flat', 16, 'electric_bolt'),
          _svc('Carbon-neutral courier',
              'Bike + EV last-mile with offset report.', 'flat', 8, 'eco'),
          _svc('Sustainability reporting', 'Monthly CO₂ savings dashboard.',
              'monthly', 49, 'monitoring'),
        ]),
    mk(
        'AeroDrop Air & Drone',
        'air',
        'Time-critical air freight plus pioneering last-mile drone delivery.',
        'Atlanta, GA',
        ['National', 'Last-mile'],
        25,
        4,
        false,
        [
          _svc('Air cargo (next-flight-out)',
              'Urgent freight on the next departure.', 'per kg', 4.2, 'send'),
          _svc('Last-mile drone delivery',
              'Sub-5kg parcels delivered by drone.', 'flat', 22, 'send'),
          _svc('Medical / organ courier',
              'Priority climate-safe air transport.', 'quote', 0, 'emergency'),
        ]),
    mk(
        'BlueWave Ferry & Marine',
        'ferry',
        'Ro-Ro vehicle ferries and container transfers along the coast.',
        'San Diego, CA',
        ['Regional', 'Marine'],
        8,
        22,
        true,
        [
          _svc(
              'Vehicle ferry (Ro-Ro)',
              'Drive-on, drive-off car & truck ferry.',
              'per vehicle',
              120,
              'directions_boat'),
          _svc('Container marine transfer', 'Port-to-port container shipping.',
              'quote', 0, 'anchor'),
          _svc(
              'Passenger + cargo combo',
              'Mixed crossings for islands & coast.',
              'per trip',
              38,
              'sailing'),
        ]),
  ];

  // Owners + a demo customer
  final users = <AppUser>[];
  for (var i = 0; i < companies.length; i++) {
    final c = companies[i];
    users.add(AppUser(
      id: c.ownerId,
      name: '${c.name} Admin',
      email: 'admin@${_slug(c.name).replaceAll('_', '')}.com',
      password: 'demo123',
      role: UserRole.company,
      companyId: c.id,
      createdAt: now - (i + 1) * day,
    ));
  }
  users.add(AppUser(
    id: 'u_demo_customer',
    name: 'Demo Customer',
    email: 'customer@demo.com',
    password: 'demo123',
    role: UserRole.customer,
    createdAt: now - day,
  ));

  // Reviews
  final sample = [
    [
      'Maria L.',
      5,
      'On time, professional and the live tracking was a game changer.'
    ],
    [
      'James P.',
      4,
      'Good value. Communication could be a touch faster but overall solid.'
    ],
    [
      'Aisha K.',
      5,
      'Handled fragile items with real care. Would book again instantly.'
    ],
    [
      'Tom R.',
      4,
      'Fair quote, no hidden fees. Driver was friendly and efficient.'
    ],
    ['Wei C.', 5, 'Exceeded expectations — smooth from booking to delivery.'],
  ];
  final reviews = <Review>[];
  for (var ci = 0; ci < companies.length; ci++) {
    final n = 2 + (ci % 3);
    for (var i = 0; i < n; i++) {
      final r = sample[(ci + i) % sample.length];
      reviews.add(Review(
        id: 'r_${ci}_$i',
        companyId: companies[ci].id,
        userId: 'u_demo_customer',
        name: r[0] as String,
        rating: r[1] as int,
        text: r[2] as String,
        createdAt: now - (i + 1) * day,
      ));
    }
  }

  String dateStr(int plus) =>
      DateTime.fromMillisecondsSinceEpoch(now + plus * day)
          .toIso8601String()
          .substring(0, 10);

  final bookings = <Booking>[
    Booking(
      id: 'b_seed1',
      companyId: companies[0].id,
      serviceId: companies[0].services[0].id,
      userId: 'u_demo_customer',
      contactName: 'Demo Customer',
      contactEmail: 'customer@demo.com',
      phone: '555-0100',
      pickup: 'Chicago, IL',
      dropoff: 'Detroit, MI',
      date: dateStr(2),
      notes: 'Two pallets, no rush.',
      status: 'confirmed',
      createdAt: now - 2 * day,
    ),
    Booking(
      id: 'b_seed2',
      companyId: companies[5].id,
      serviceId: companies[5].services[0].id,
      userId: 'u_demo_customer',
      contactName: 'Demo Customer',
      contactEmail: 'customer@demo.com',
      phone: '555-0100',
      pickup: 'Miami, FL',
      dropoff: 'Orlando, FL',
      date: dateStr(5),
      notes: 'Frozen seafood, -18°C.',
      status: 'pending',
      createdAt: now - day,
    ),
  ];

  return SeedData(companies, users, bookings, reviews);
}
