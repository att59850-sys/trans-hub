import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted password hashing (P2 / TH-010).
///
/// Replaces the previous plaintext password storage. Produces a value of the
/// form `salt:sha256(salt + password)`. This is a transitional measure for the
/// offline-first build; production auth is delegated to Supabase Auth, which
/// performs server-side hashing and never exposes raw passwords to the client.
class PasswordHasher {
  const PasswordHasher();

  static final Random _rng = Random.secure();

  String _newSalt([int len = 16]) {
    final bytes = List<int>.generate(len, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _digest(String salt, String password) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  /// Hashes [password] with a freshly generated salt.
  String hash(String password) {
    final salt = _newSalt();
    return '$salt:${_digest(salt, password)}';
  }

  /// Verifies [password] against a previously stored [stored] hash.
  ///
  /// Tolerates legacy plaintext values (no `:` separator) so existing seed
  /// data keeps working during migration.
  bool verify(String password, String stored) {
    final idx = stored.indexOf(':');
    if (idx < 0) {
      // Legacy plaintext fallback.
      return stored == password;
    }
    final salt = stored.substring(0, idx);
    final expected = stored.substring(idx + 1);
    return _digest(salt, password) == expected;
  }

  /// True if [stored] is a legacy plaintext value that should be re-hashed.
  bool isLegacy(String stored) => !stored.contains(':');
}
