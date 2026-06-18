/// Service category metadata (matches the marketplace catalog, including the
/// newly-introduced services).
class ServiceCategory {
  const ServiceCategory(
    this.id,
    this.name,
    this.icon,
    this.blurb, {
    this.isNew = false,
  });

  final String id;
  final String name;
  final String icon;
  final String blurb;
  final bool isNew;
}

const List<ServiceCategory> kCategories = [
  ServiceCategory('freight', 'Freight & Cargo', 'local_shipping',
      'Full-load & part-load road freight'),
  ServiceCategory('movers', 'Movers & Relocation', 'inventory_2',
      'Home & office moving, packing'),
  ServiceCategory('courier', 'Courier & Parcel', 'local_post_office',
      'Same-day & express delivery'),
  ServiceCategory(
      'coach', 'Coach & Bus', 'directions_bus', 'Group travel & charters'),
  ServiceCategory(
      'ride', 'Ride & Taxi', 'local_taxi', 'On-demand passenger rides'),
  // New services
  ServiceCategory('coldchain', 'Cold-Chain Logistics', 'ac_unit',
      'Refrigerated & temperature-controlled',
      isNew: true),
  ServiceCategory('heavy', 'Heavy Haul & Machinery', 'precision_manufacturing',
      'Oversized & abnormal loads',
      isNew: true),
  ServiceCategory('ev', 'Green / EV Fleet', 'electric_bolt',
      'Zero-emission electric delivery',
      isNew: true),
  ServiceCategory(
      'air', 'Air & Drone Freight', 'send', 'Air cargo & last-mile drone',
      isNew: true),
  ServiceCategory('ferry', 'Ferry & Marine', 'directions_boat',
      'Ro-Ro, container & marine transfer',
      isNew: true),
];

ServiceCategory categoryById(String id) =>
    kCategories.firstWhere((c) => c.id == id, orElse: () => kCategories.first);
