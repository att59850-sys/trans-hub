// Data models for TransportHub. Stored in Hive as JSON-able maps.
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId(String prefix) => '${prefix}_${_uuid.v4().substring(0, 8)}';

enum UserRole { customer, company }

UserRole roleFromString(String s) =>
    s == 'company' ? UserRole.company : UserRole.customer;
String roleToString(UserRole r) =>
    r == UserRole.company ? 'company' : 'customer';

class TransportService {
  final String id;
  String name;
  String desc;
  String unit; // flat, per mile, per kg, quote, etc.
  double price;
  String icon; // material icon key
  bool active;

  TransportService({
    String? id,
    required this.name,
    this.desc = '',
    this.unit = 'flat',
    this.price = 0,
    this.icon = 'local_shipping',
    this.active = true,
  }) : id = id ?? newId('s');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'unit': unit,
        'price': price,
        'icon': icon,
        'active': active,
      };

  factory TransportService.fromJson(Map j) => TransportService(
        id: j['id'] as String?,
        name: j['name'] ?? '',
        desc: j['desc'] ?? '',
        unit: j['unit'] ?? 'flat',
        price: (j['price'] ?? 0).toDouble(),
        icon: j['icon'] ?? 'local_shipping',
        active: j['active'] ?? true,
      );

  String get priceLabel {
    if (unit == 'quote' || price == 0) return 'On quote';
    final p = price == price.roundToDouble()
        ? '\$${price.toInt()}'
        : '\$${price.toStringAsFixed(2)}';
    if (unit == 'flat') return p;
    return '$p / ${unit.replaceFirst('per ', '')}';
  }
}

class Company {
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
    String? verificationStatus,
    List<TransportService>? services,
    int? createdAt,
  })  : verificationStatus =
            verificationStatus ?? (verified ? 'approved' : 'unverified'),
        coverage = coverage ?? ['Local'],
        services = services ?? [],
        id = id ?? newId('c'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

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

  /// Returns the service with [serviceId], or null if not found.
  TransportService? serviceById(String? serviceId) {
    if (serviceId == null) return null;
    for (final s in services) {
      if (s.id == serviceId) return s;
    }
    return null;
  }

  factory Company.fromJson(Map j) => Company(
        id: j['id'] as String?,
        ownerId: j['ownerId'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? 'freight',
        tagline: j['tagline'] ?? '',
        description: j['description'] ?? '',
        city: j['city'] ?? '',
        coverage: (j['coverage'] as List?)?.map((e) => e.toString()).toList() ??
            ['Local'],
        fleetSize: j['fleetSize'] ?? 1,
        yearsActive: j['yearsActive'] ?? 0,
        verified: j['verified'] ?? false,
        verificationStatus: j['verificationStatus'] as String?,
        services: (j['services'] as List?)
                ?.map((e) => TransportService.fromJson(e as Map))
                .toList() ??
            [],
        createdAt: j['createdAt'],
      );
}

class AppUser {
  final String id;
  String name;
  String email;
  String password;
  UserRole role;
  String? companyId;
  int createdAt;

  AppUser({
    String? id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.companyId,
    int? createdAt,
  })  : id = id ?? newId('u'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': roleToString(role),
        'companyId': companyId,
        'createdAt': createdAt,
      };

  factory AppUser.fromJson(Map j) => AppUser(
        id: j['id'] as String?,
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        password: j['password'] ?? '',
        role: roleFromString(j['role'] ?? 'customer'),
        companyId: j['companyId'],
        createdAt: j['createdAt'],
      );
}

class Booking {
  final String id;
  String companyId;
  String? serviceId;
  String? userId;
  String contactName;
  String contactEmail;
  String phone;
  String pickup;
  String dropoff;
  String date;
  String notes;
  String status; // pending, confirmed, completed, cancelled
  int createdAt;

  Booking({
    String? id,
    required this.companyId,
    this.serviceId,
    this.userId,
    this.contactName = '',
    this.contactEmail = '',
    this.phone = '',
    this.pickup = '',
    this.dropoff = '',
    this.date = '',
    this.notes = '',
    this.status = 'pending',
    int? createdAt,
  })  : id = id ?? newId('b'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'serviceId': serviceId,
        'userId': userId,
        'contactName': contactName,
        'contactEmail': contactEmail,
        'phone': phone,
        'pickup': pickup,
        'dropoff': dropoff,
        'date': date,
        'notes': notes,
        'status': status,
        'createdAt': createdAt,
      };

  factory Booking.fromJson(Map j) => Booking(
        id: j['id'] as String?,
        companyId: j['companyId'] ?? '',
        serviceId: j['serviceId'],
        userId: j['userId'],
        contactName: j['contactName'] ?? '',
        contactEmail: j['contactEmail'] ?? '',
        phone: j['phone'] ?? '',
        pickup: j['pickup'] ?? '',
        dropoff: j['dropoff'] ?? '',
        date: j['date'] ?? '',
        notes: j['notes'] ?? '',
        status: j['status'] ?? 'pending',
        createdAt: j['createdAt'],
      );
}

class Review {
  final String id;
  String companyId;
  String? userId;
  String name;
  int rating;
  String text;
  int createdAt;

  Review({
    String? id,
    required this.companyId,
    this.userId,
    required this.name,
    required this.rating,
    required this.text,
    int? createdAt,
  })  : id = id ?? newId('r'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'userId': userId,
        'name': name,
        'rating': rating,
        'text': text,
        'createdAt': createdAt,
      };

  factory Review.fromJson(Map j) => Review(
        id: j['id'] as String?,
        companyId: j['companyId'] ?? '',
        userId: j['userId'],
        name: j['name'] ?? '',
        rating: j['rating'] ?? 5,
        text: j['text'] ?? '',
        createdAt: j['createdAt'],
      );
}

/// Service category metadata (matches the web platform's catalog,
/// including the newly-introduced services).
class ServiceCategory {
  final String id;
  final String name;
  final String icon;
  final String blurb;
  final bool isNew;
  const ServiceCategory(this.id, this.name, this.icon, this.blurb,
      {this.isNew = false});
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
