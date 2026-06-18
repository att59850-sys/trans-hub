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
  });

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Builds config from `--dart-define` values.
  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return AppConfig(
      environment: switch (env) {
        'production' => AppEnvironment.production,
        'staging' => AppEnvironment.staging,
        _ => AppEnvironment.development,
      },
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  /// True when a Supabase backend is configured. While false, the app runs
  /// fully offline against Hive (current default).
  bool get hasRemoteBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
