import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'seed_data.dart';

/// Offline-first data layer backed by Hive (as the original plan specified).
/// Acts as the app's "backend": auth, companies, services, bookings, reviews,
/// favorites. A [ChangeNotifier] so the UI rebuilds reactively.
class DataService extends ChangeNotifier {
  static final DataService instance = DataService._();
  DataService._();

  late Box _box; // single settings/meta box (session, location, favorites)
  late Box _companiesBox;
  late Box _usersBox;
  late Box _bookingsBox;
  late Box _reviewsBox;

  static const _kSeeded = 'seeded_v2';

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('meta');
    _companiesBox = await Hive.openBox('companies');
    _usersBox = await Hive.openBox('users');
    _bookingsBox = await Hive.openBox('bookings');
    _reviewsBox = await Hive.openBox('reviews');

    if (_box.get(_kSeeded) != true) {
      await _seed();
      await _box.put(_kSeeded, true);
    }
  }

  Future<void> _seed() async {
    final seed = buildSeedData();
    for (final c in seed.companies) {
      await _companiesBox.put(c.id, c.toJson());
    }
    for (final u in seed.users) {
      await _usersBox.put(u.id, u.toJson());
    }
    for (final b in seed.bookings) {
      await _bookingsBox.put(b.id, b.toJson());
    }
    for (final r in seed.reviews) {
      await _reviewsBox.put(r.id, r.toJson());
    }
  }

  Future<void> resetAll() async {
    await _companiesBox.clear();
    await _usersBox.clear();
    await _bookingsBox.clear();
    await _reviewsBox.clear();
    await _box.clear();
    await _seed();
    await _box.put(_kSeeded, true);
    notifyListeners();
  }

  // ---------- collections ----------
  List<Company> get companies =>
      _companiesBox.values.map((e) => Company.fromJson(e as Map)).toList();

  Company? company(String id) {
    final j = _companiesBox.get(id);
    return j == null ? null : Company.fromJson(j as Map);
  }

  List<AppUser> get users =>
      _usersBox.values.map((e) => AppUser.fromJson(e as Map)).toList();

  List<Booking> get bookings =>
      _bookingsBox.values.map((e) => Booking.fromJson(e as Map)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Review> reviewsFor(String companyId) => _reviewsBox.values
      .map((e) => Review.fromJson(e as Map))
      .where((r) => r.companyId == companyId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  ({double avg, int count}) ratingFor(String companyId) {
    final rs = reviewsFor(companyId);
    if (rs.isEmpty) return (avg: 0, count: 0);
    final avg = rs.map((r) => r.rating).reduce((a, b) => a + b) / rs.length;
    return (avg: (avg * 10).round() / 10, count: rs.length);
  }

  // ---------- session / auth ----------
  AppUser? get currentUser {
    final id = _box.get('session');
    if (id == null) return null;
    final j = _usersBox.get(id);
    return j == null ? null : AppUser.fromJson(j as Map);
  }

  Company? get myCompany {
    final u = currentUser;
    if (u == null || u.role != UserRole.company || u.companyId == null) {
      return null;
    }
    return company(u.companyId!);
  }

  AppUser signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
  }) {
    email = email.trim().toLowerCase();
    if (users.any((u) => u.email == email)) {
      throw Exception('An account with that email already exists.');
    }
    final user =
        AppUser(name: name, email: email, password: password, role: role);
    if (role == UserRole.company) {
      final company = Company(
        ownerId: user.id,
        name: companyName?.trim().isNotEmpty == true
            ? companyName!.trim()
            : '$name\'s Transport',
        tagline: 'New transport provider on TransportHub.',
        description:
            'Tell customers about your fleet, coverage area and what makes you reliable.',
        city: location.isNotEmpty ? location : 'Your City',
      );
      _companiesBox.put(company.id, company.toJson());
      user.companyId = company.id;
    }
    _usersBox.put(user.id, user.toJson());
    _box.put('session', user.id);
    notifyListeners();
    return user;
  }

  AppUser login({required String email, required String password}) {
    email = email.trim().toLowerCase();
    final u = users.firstWhere(
      (u) => u.email == email && u.password == password,
      orElse: () => throw Exception('Invalid email or password.'),
    );
    _box.put('session', u.id);
    notifyListeners();
    return u;
  }

  void logout() {
    _box.delete('session');
    notifyListeners();
  }

  // ---------- companies ----------
  void updateCompany(Company c) {
    _companiesBox.put(c.id, c.toJson());
    notifyListeners();
  }

  // ---------- services ----------
  void addService(String companyId, TransportService s) {
    final c = company(companyId);
    if (c == null) return;
    c.services.add(s);
    updateCompany(c);
  }

  void updateService(String companyId, TransportService s) {
    final c = company(companyId);
    if (c == null) return;
    final i = c.services.indexWhere((x) => x.id == s.id);
    if (i >= 0) c.services[i] = s;
    updateCompany(c);
  }

  void removeService(String companyId, String serviceId) {
    final c = company(companyId);
    if (c == null) return;
    c.services.removeWhere((x) => x.id == serviceId);
    updateCompany(c);
  }

  // ---------- bookings ----------
  Booking createBooking(Booking b) {
    _bookingsBox.put(b.id, b.toJson());
    notifyListeners();
    return b;
  }

  List<Booking> bookingsForCompany(String companyId) =>
      bookings.where((b) => b.companyId == companyId).toList();

  List<Booking> bookingsForUser(String userId) =>
      bookings.where((b) => b.userId == userId).toList();

  void setBookingStatus(String id, String status) {
    final j = _bookingsBox.get(id);
    if (j == null) return;
    final b = Booking.fromJson(j as Map)..status = status;
    _bookingsBox.put(id, b.toJson());
    notifyListeners();
  }

  // ---------- reviews ----------
  void addReview(Review r) {
    _reviewsBox.put(r.id, r.toJson());
    notifyListeners();
  }

  // ---------- favorites ----------
  List<String> get favorites =>
      (_box.get('favorites') as List?)?.map((e) => e.toString()).toList() ?? [];

  bool isFav(String companyId) => favorites.contains(companyId);

  bool toggleFav(String companyId) {
    final favs = favorites;
    if (favs.contains(companyId)) {
      favs.remove(companyId);
    } else {
      favs.add(companyId);
    }
    _box.put('favorites', favs);
    notifyListeners();
    return favs.contains(companyId);
  }

  // ---------- location ----------
  String get location => (_box.get('location') as String?) ?? '';
  void setLocation(String loc) {
    _box.put('location', loc);
    notifyListeners();
  }
}
