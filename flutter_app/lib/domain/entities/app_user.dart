import '../../core/utils/id_generator.dart';
import 'user_role.dart';

/// An authenticated account holder (customer or provider owner).
///
/// NOTE (P2/TH-010): the [passwordHash] field stores a salted hash, never a
/// plaintext password. Local auth is a transitional step until Supabase Auth
/// replaces it entirely.
class AppUser {
  AppUser({
    String? id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.companyId,
    int? createdAt,
  })  : id = id ?? newId('u'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String name;
  String email;

  /// Salted hash of the password (see [PasswordHasher]). Never plaintext.
  String passwordHash;
  UserRole role;
  String? companyId;
  int createdAt;
}
