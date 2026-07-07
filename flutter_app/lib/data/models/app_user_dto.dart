import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

/// JSON (de)serialization for [AppUser].
///
/// The stored field is `passwordHash`; a legacy `password` key is read as a
/// fallback so older seed data still loads (it is re-hashed on next login).
extension AppUserDto on AppUser {
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'role': roleToString(role),
        'companyId': companyId,
        'createdAt': createdAt,
      };
}

AppUser appUserFromJson(Map j) => AppUser(
      id: j['id'] as String?,
      name: (j['name'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      passwordHash: (j['passwordHash'] ?? j['password'] ?? '') as String,
      role: roleFromString((j['role'] ?? 'customer') as String),
      companyId: j['companyId'] as String?,
      createdAt: j['createdAt'] as int?,
    );
