/// Runtime configuration (TH-009).
///
/// Values are injected at build time via `--dart-define` (or a .env loader),
/// so secrets never ship hard-coded in source. Three logical environments are
/// supported: development, staging, production.
enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.adminEmails = const [],
  });

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Emails granted access to the in-app verification review queue (TH-017).
  /// Configured via `--dart-define=ADMIN_EMAILS=a@x.com,b@y.com`. In
  /// development a default admin is provided so the queue is reachable.
  final List<String> adminEmails;

  /// Builds config from `--dart-define` values.
  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    const adminsRaw = String.fromEnvironment('ADMIN_EMAILS');
    final environment = switch (env) {
      'production' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };
    final admins = adminsRaw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    // Convenience default so the review queue is reachable out of the box in
    // development; production should set ADMIN_EMAILS explicitly.
    if (admins.isEmpty && environment == AppEnvironment.development) {
      admins.add('admin@transporthub.app');
    }
    return AppConfig(
      environment: environment,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      adminEmails: admins,
    );
  }

  /// True when a Supabase backend is configured. While false, the app runs
  /// fully offline against Hive (current default).
  bool get hasRemoteBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether [email] is an administrator (case-insensitive).
  bool isAdmin(String? email) =>
      email != null && adminEmails.contains(email.trim().toLowerCase());
}
