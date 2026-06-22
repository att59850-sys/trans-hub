import '../../domain/entities/app_notification.dart';

/// JSON (de)serialization for [AppNotification].
extension AppNotificationDto on AppNotification {
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'kind': notificationKindToString(kind),
        'read': read,
        'createdAt': createdAt,
      };
}

AppNotification appNotificationFromJson(Map j) => AppNotification(
      id: j['id'] as String?,
      userId: (j['userId'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      body: (j['body'] ?? '') as String,
      kind: notificationKindFromString((j['kind'] ?? 'system') as String),
      read: (j['read'] ?? false) as bool,
      createdAt: j['createdAt'] as int?,
    );
