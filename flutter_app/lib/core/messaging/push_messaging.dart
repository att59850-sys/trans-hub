/// Push notification abstraction (TH-018).
///
/// Implement with Firebase Cloud Messaging behind this interface so the app
/// doesn't depend on the SDK directly. A [NoopPushMessaging] is used until FCM
/// is configured.
abstract interface class PushMessaging {
  /// Requests notification permission (no-op where implicit).
  Future<bool> requestPermission();

  /// Returns the device push token, or null when unavailable.
  Future<String?> deviceToken();

  /// Subscribes the device to a topic (e.g. `provider_<companyId>`).
  Future<void> subscribe(String topic);

  /// Unsubscribes from a topic.
  Future<void> unsubscribe(String topic);
}

class NoopPushMessaging implements PushMessaging {
  const NoopPushMessaging();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> deviceToken() async => null;

  @override
  Future<void> subscribe(String topic) async {}

  @override
  Future<void> unsubscribe(String topic) async {}
}
