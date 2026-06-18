import '../../core/utils/id_generator.dart';

/// A customer review of a company.
class Review {
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

  final String id;
  String companyId;
  String? userId;
  String name;
  int rating;
  String text;
  int createdAt;
}
