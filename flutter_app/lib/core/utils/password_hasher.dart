import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted password hashing (P2 / TH-010).
///
/// Replaces the previous plaintext password storage. New values are
/// scheme-tagged as `s1:<salt>:sha256(salt + password)`. This is a transitional
/// measure for the offline-first build; production auth is delegated to
/// Supabase Auth, which performs server-side hashing and never exposes raw
/// passwords to the client.
///
/// The `s1:` scheme prefix was added (QA round 19) so that legacy-plaintext
/// detection no longer depends on whether the *password* contains a `:`. The
/// original untagged `salt:digest` format is still recognised for back-compat,
/// and a plaintext value — even one containing a colon, e.g. a passphrase like
/// `correct:horse` — verifies correctly instead of being mis-parsed as a hash.
class PasswordHasher {
  const PasswordHasher();

  static const String _scheme = 's1';

  static final Random _rng = Random.secure();

  String _newSalt([int len = 16]) {
    final bytes = List<int>.generate(len, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _digest(String salt, String password) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  /// Hashes [password] with a freshly generated salt (scheme-tagged).
  String hash(String password) {
    final salt = _newSalt();
    return '$_scheme:$salt:${_digest(salt, password)}';
  }

  /// Verifies [password] against a previously stored [stored] hash.
  ///
  /// Recognises three shapes, in order:
  ///   1. scheme-tagged `s1:<salt>:<digest>` (current format);
  ///   2. legacy untagged `<salt>:<digest>` (base64url salt + 64-hex digest);
  ///   3. legacy plaintext (compared verbatim) — including values that happen
  ///      to contain a `:` (QA round 19).
  bool verify(String password, String stored) {
    if (stored.startsWith('$_scheme:')) {
      final rest = stored.substring(_scheme.length + 1);
      final idx = rest.indexOf(':');
      if (idx < 0) return false;
      final salt = rest.substring(0, idx);
      final expected = rest.substring(idx + 1);
      return _digest(salt, password) == expected;
    }
    final old = _parseOldFormat(stored);
    if (old != null) {
      return _digest(old.$1, password) == old.$2;
    }
    // Legacy plaintext fallback (colon-safe).
    return stored == password;
  }

  /// True if [stored] is a legacy plaintext value that should be re-hashed.
  bool isLegacy(String stored) =>
      !stored.startsWith('$_scheme:') && _parseOldFormat(stored) == null;

  /// Parses an untagged legacy `salt:digest` hash, or null if [stored] is not
  /// one. A real digest is exactly 64 lowercase hex characters; the base64url
  /// salt contains no `:`. This lets a plaintext passphrase that merely
  /// contains a colon fall through to the plaintext branch rather than being
  /// mistaken for a hash.
  (String, String)? _parseOldFormat(String stored) {
    final idx = stored.indexOf(':');
    if (idx <= 0) return null;
    final salt = stored.substring(0, idx);
    final digest = stored.substring(idx + 1);
    final digestOk =
        digest.length == 64 && RegExp(r'^[0-9a-f]{64}$').hasMatch(digest);
    final saltOk = salt.isNotEmpty && !salt.contains(':');
    return (digestOk && saltOk) ? (salt, digest) : null;
  }
}
