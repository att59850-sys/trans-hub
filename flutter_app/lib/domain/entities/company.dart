import '../../core/utils/id_generator.dart';
import 'transport_service.dart';

/// A transport/logistics provider listed on the marketplace.
class Company {
  Company({
    String? id,
    required this.ownerId,
    required this.name,
    this.category = 'freight',
    this.tagline = '',
    this.description = '',
    this.city = '',
    List<String>? coverage,
    this.fleetSize = 1,
    this.yearsActive = 0,
    this.verified = false,
    this.verificationStatus = 'unverified',
    List<TransportService>? services,
    int? createdAt,
  })  : coverage = coverage ?? ['Local'],
        services = services ?? [],
        id = id ?? newId('c'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String ownerId;
  String name;
  String category;
  String tagline;
  String description;
  String city;
  List<String> coverage;
  int fleetSize;
  int yearsActive;
  bool verified;

  /// Provider verification workflow (TH-017):
  /// unverified | submitted | under_review | approved | rejected
  String verificationStatus;
  List<TransportService> services;
  int createdAt;

  /// Returns the service with [serviceId], or null if not found.
  TransportService? serviceById(String? serviceId) {
    if (serviceId == null) return null;
    for (final s in services) {
      if (s.id == serviceId) return s;
    }
    return null;
  }
}
