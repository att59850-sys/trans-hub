import '../entities/app_notification.dart';

/// In-app notifications (TH-018).
abstract interface class NotificationRepository {
  /// Notifications for [userId], newest first.
  List<AppNotification> forUser(String userId);

  /// Count of unread notifications for [userId].
  int unreadCount(String userId);

  /// Creates a new notification.
  void add(AppNotification notification);

  /// Marks a single notification read.
  void markRead(String notificationId);

  /// Marks all of [userId]'s notifications read.
  void markAllRead(String userId);
}
