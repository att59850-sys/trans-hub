import '../../core/errors/failures.dart';
import '../../core/utils/password_hasher.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/hive_local_datasource.dart';
import '../models/app_user_dto.dart';
import '../models/company_dto.dart';

/// Hive-backed [AuthRepository] with salted password hashing (P2/TH-010).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._ds, {PasswordHasher? hasher})
      : _hasher = hasher ?? const PasswordHasher();

  final HiveLocalDataSource _ds;
  final PasswordHasher _hasher;

  List<AppUser> get _users =>
      _ds.users.values.map((e) => appUserFromJson(e as Map)).toList();

  @override
  AppUser? get currentUser {
    final id = _ds.meta.get('session');
    if (id == null) return null;
    final j = _ds.users.get(id);
    return j == null ? null : appUserFromJson(j as Map);
  }

  @override
  AppUser signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? defaultCity,
  }) {
    final normalized = email.trim().toLowerCase();
    // Shared validation rules (single source of truth) — keeps this repository
    // and the DataService facade in agreement.
    if (!Validators.isNonEmptyName(name)) {
      throw const ValidationFailure('Please enter your name.');
    }
    if (!Validators.isValidEmail(normalized)) {
      throw const ValidationFailure('Please enter a valid email address.');
    }
    if (!Validators.isValidPassword(password)) {
      throw const ValidationFailure(
          'Password must be at least ${Validators.minPasswordLength} characters.');
    }
    if (_users.any((u) => u.email == normalized)) {
      throw const AuthFailure('An account with that email already exists.');
    }
    final user = AppUser(
      name: name,
      email: normalized,
      passwordHash: _hasher.hash(password),
      role: role,
    );
    if (role == UserRole.company) {
      final company = Company(
        ownerId: user.id,
        name: companyName?.trim().isNotEmpty == true
            ? companyName!.trim()
            : "$name's Transport",
        tagline: 'New transport provider on Trans-Hub.',
        description:
            'Tell customers about your fleet, coverage area and what makes you reliable.',
        city: (defaultCity?.isNotEmpty ?? false) ? defaultCity! : 'Your City',
      );
      _ds.companies.put(company.id, company.toJson());
      user.companyId = company.id;
    }
    _ds.users.put(user.id, user.toJson());
    _ds.meta.put('session', user.id);
    return user;
  }

  @override
  AppUser login({required String email, required String password}) {
    final normalized = email.trim().toLowerCase();
    for (final u in _users) {
      if (u.email == normalized && _hasher.verify(password, u.passwordHash)) {
        // Transparently upgrade legacy plaintext hashes.
        if (_hasher.isLegacy(u.passwordHash)) {
          u.passwordHash = _hasher.hash(password);
          _ds.users.put(u.id, u.toJson());
        }
        _ds.meta.put('session', u.id);
        return u;
      }
    }
    throw const AuthFailure('Invalid email or password.');
  }

  @override
  void logout() => _ds.meta.delete('session');
}
