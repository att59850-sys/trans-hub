import '../../domain/entities/review.dart';

/// JSON (de)serialization for [Review].
extension ReviewDto on Review {
  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'userId': userId,
        'name': name,
        'rating': rating,
        'text': text,
        'createdAt': createdAt,
      };
}

Review reviewFromJson(Map j) => Review(
      id: j['id'] as String?,
      companyId: (j['companyId'] ?? '') as String,
      userId: j['userId'] as String?,
      name: (j['name'] ?? '') as String,
      rating: (j['rating'] ?? 5) as int,
      text: (j['text'] ?? '') as String,
      createdAt: j['createdAt'] as int?,
    );
