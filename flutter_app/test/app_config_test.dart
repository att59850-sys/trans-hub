import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/config/app_config.dart';

/// TH-009 / TH-017 — Runtime config: environment, remote-backend detection,
/// and the admin-email gate driving the verification review queue.
void main() {
  group('AppConfig', () {
    test('hasRemoteBackend is false without Supabase credentials', () {
      const c = AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: '',
        supabaseAnonKey: '',
      );
      expect(c.hasRemoteBackend, isFalse);
    });

    test('hasRemoteBackend is true when both credentials are set', () {
      const c = AppConfig(
        environment: AppEnvironment.production,
        supabaseUrl: 'https://x.supabase.co',
        supabaseAnonKey: 'anon-key',
      );
      expect(c.hasRemoteBackend, isTrue);
    });

    group('isAdmin', () {
      const c = AppConfig(
        environment: AppEnvironment.production,
        supabaseUrl: '',
        supabaseAnonKey: '',
        adminEmails: ['admin@transporthub.app', 'ops@transporthub.app'],
      );

      test('matches a configured admin email', () {
        expect(c.isAdmin('admin@transporthub.app'), isTrue);
      });

      test('is case-insensitive and trims whitespace', () {
        expect(c.isAdmin('  ADMIN@TransportHub.app '), isTrue);
      });

      test('rejects non-admin and null emails', () {
        expect(c.isAdmin('user@example.com'), isFalse);
        expect(c.isAdmin(null), isFalse);
      });
    });

    test('development env provides a default admin when none configured', () {
      // fromEnvironment reads --dart-define values; with none set under the
      // default (development) environment a convenience admin is injected.
      final c = AppConfig.fromEnvironment();
      expect(c.environment, AppEnvironment.development);
      expect(c.adminEmails, isNotEmpty);
      expect(c.isAdmin(c.adminEmails.first), isTrue);
    });
  });
}
