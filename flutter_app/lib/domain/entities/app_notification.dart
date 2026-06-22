import '../../core/utils/id_generator.dart';

/// Categories of notification the platform emits (TH-018).
enum NotificationKind {
  bookingUpdate,
  quoteResponse,
  reviewReminder,
  system,
}

NotificationKind notificationKindFromString(String s) => switch (s) {
      'booking_update' => NotificationKind.bookingUpdate,
      'quote_response' => NotificationKind.quoteResponse,
      'review_reminder' => NotificationKind.reviewReminder,
      _ => NotificationKind.system,
    };

String notificationKindToString(NotificationKind k) => switch (k) {
      NotificationKind.bookingUpdate => 'booking_update',
      NotificationKind.quoteResponse => 'quote_response',
      NotificationKind.reviewReminder => 'review_reminder',
      NotificationKind.system => 'system',
    };

/// An in-app notification delivered to a user.
class AppNotification {
  AppNotification({
    String? id,
    required this.userId,
    required this.title,
    this.body = '',
    this.kind = NotificationKind.system,
    this.read = false,
    int? createdAt,
  })  : id = id ?? newId('n'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String userId;
  String title;
  String body;
  NotificationKind kind;
  bool read;
  int createdAt;
}
