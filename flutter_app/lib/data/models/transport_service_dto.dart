import '../../domain/entities/transport_service.dart';

/// JSON (de)serialization for [TransportService]. Kept separate from the
/// domain entity so storage/transport concerns don't leak into the domain.
extension TransportServiceDto on TransportService {
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'unit': unit,
        'price': price,
        'icon': icon,
        'active': active,
      };
}

TransportService transportServiceFromJson(Map j) => TransportService(
      id: j['id'] as String?,
      name: (j['name'] ?? '') as String,
      desc: (j['desc'] ?? '') as String,
      unit: (j['unit'] ?? 'flat') as String,
      price: (j['price'] ?? 0).toDouble() as double,
      icon: (j['icon'] ?? 'local_shipping') as String,
      active: (j['active'] ?? true) as bool,
    );
