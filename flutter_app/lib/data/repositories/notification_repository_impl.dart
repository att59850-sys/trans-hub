import '../../core/utils/ordering.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/local/hive_local_datasource.dart';
import '../models/app_notification_dto.dart';

/// Hive-backed [NotificationRepository].
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  List<AppNotification> get _all => _ds.notifications.values
      .map((e) => appNotificationFromJson(e as Map))
      .toList();

  @override
  List<AppNotification> forUser(String userId) => _all
      .where((n) => n.userId == userId)
      .toList()
    // Newest first, stable on same-millisecond ties: a single action can
    // fan out several notifications in the SAME millisecond, and a
    // createdAt-only sort left their order at the mercy of Hive iteration
    // order — the list could reorder/flicker between reads. (QA round 5.)
    ..sort(
        (a, b) => Ordering.newestFirst(a.createdAt, a.id, b.createdAt, b.id));

  @override
  int unreadCount(String userId) =>
      _all.where((n) => n.userId == userId && !n.read).length;

  @override
  void add(AppNotification notification) =>
      _ds.notifications.put(notification.id, notification.toJson());

  @override
  void markRead(String notificationId) {
    final j = _ds.notifications.get(notificationId);
    if (j == null) return;
    final n = appNotificationFromJson(j as Map)..read = true;
    _ds.notifications.put(n.id, n.toJson());
  }

  @override
  void markAllRead(String userId) {
    for (final n in forUser(userId)) {
      if (!n.read) {
        n.read = true;
        _ds.notifications.put(n.id, n.toJson());
      }
    }
  }
}
