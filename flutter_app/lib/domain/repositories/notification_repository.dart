import '../entities/app_notification.dart';

/// In-app notifications (TH-018).
abstract interface class NotificationRepository {
  /// Notifications for [userId], newest first.
  List<AppNotification> forUser(String userId);

  /// Count of unread notifications for [userId].
  int unreadCount(String userId);

  /// Creates a new notification.
  void add(AppNotification notification);

  /// Marks a single notification read, but only if it belongs to [userId].
  ///
  /// Returns whether a notification was actually marked (false when the id is
  /// unknown or is owned by another user). Scoping by owner prevents one
  /// account from clearing another user's unread badge via a stale/misrouted
  /// id (QA round 20).
  bool markRead(String userId, String notificationId);

  /// Marks all of [userId]'s notifications read.
  void markAllRead(String userId);
}
