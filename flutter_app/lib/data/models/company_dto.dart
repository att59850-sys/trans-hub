import '../../domain/entities/company.dart';
import '../../domain/entities/transport_service.dart';
import 'transport_service_dto.dart';

/// JSON (de)serialization for [Company].
extension CompanyDto on Company {
  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'category': category,
        'tagline': tagline,
        'description': description,
        'city': city,
        'coverage': coverage,
        'fleetSize': fleetSize,
        'yearsActive': yearsActive,
        'verified': verified,
        'verificationStatus': verificationStatus,
        'services': services.map((s) => s.toJson()).toList(),
        'createdAt': createdAt,
      };
}

Company companyFromJson(Map j) => Company(
      id: j['id'] as String?,
      ownerId: (j['ownerId'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      category: (j['category'] ?? 'freight') as String,
      tagline: (j['tagline'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      city: (j['city'] ?? '') as String,
      coverage: (j['coverage'] as List?)?.map((e) => e.toString()).toList() ??
          ['Local'],
      fleetSize: (j['fleetSize'] ?? 1) as int,
      yearsActive: (j['yearsActive'] ?? 0) as int,
      verified: (j['verified'] ?? false) as bool,
      verificationStatus: (j['verificationStatus'] ?? 'unverified') as String,
      services: (j['services'] as List?)
              ?.map((e) => transportServiceFromJson(e as Map))
              .toList() ??
          <TransportService>[],
      createdAt: j['createdAt'] as int?,
    );
