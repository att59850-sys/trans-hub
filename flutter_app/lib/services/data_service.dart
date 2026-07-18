import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
import '../core/maps/maps_service.dart';
import '../core/telemetry/analytics.dart';
import '../core/utils/password_hasher.dart';
import '../core/utils/validators.dart';
import '../data/datasources/local/hive_local_datasource.dart';
import '../domain/entities/app_notification.dart';
import '../domain/entities/booking_status.dart' as dom;
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/repositories.dart' as dom_repo;
import '../models/models.dart';
import 'seed_data.dart';

/// Presentation controller (TH-005).
///
/// Previously a monolithic singleton that owned all persistence. It has been
/// decomposed: persistence now lives in the repository layer
/// (`data/repositories/*`, wired through `core/di/injection.dart`), and Hive
/// access is centralized in [HiveLocalDataSource]. This class is now a thin
/// reactive facade ([ChangeNotifier]) the legacy screens still bind to.
///
/// Security (P2/TH-010): passwords are stored as salted hashes via
/// [PasswordHasher] — never plaintext.
class DataService extends ChangeNotifier {
  DataService._();
  static final DataService instance = DataService._();

  final HiveLocalDataSource _local = HiveLocalDataSource.instance;
  final PasswordHasher _hasher = const PasswordHasher();

  static const _kSeeded = 'seeded_v2';

  Box get _box => _local.meta;
  Box get _companiesBox => _local.companies;
  Box get _usersBox => _local.users;
  Box get _bookingsBox => _local.bookings;
  Box get _reviewsBox => _local.reviews;

  Future<void> init() async {
    await _local.init();
    // Register the Clean Architecture dependency graph (TH-008).
    configureDependencies(_local);

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
      // Ensure seeded accounts are hashed, not plaintext (P2).
      final stored =
          u.password.contains(':') ? u.password : _hasher.hash(u.password);
      final map = u.toJson()..['password'] = stored;
      await _usersBox.put(u.id, map);
    }
    for (final b in seed.bookings) {
      await _bookingsBox.put(b.id, b.toJson());
    }
    for (final r in seed.reviews) {
      await _reviewsBox.put(r.id, r.toJson());
    }
  }

  // ---------- analytics (TH-024) ----------
  // Central instrumentation point. Events go to the AnalyticsService
  // abstraction (Noop by default; a real provider just works once wired).
  AnalyticsService get _analytics => sl<AnalyticsService>();

  void _track(AnalyticsEvent event, {Map<String, Object?> params = const {}}) {
    _analytics.logEvent(event, params: params);
  }

  /// Records that the app was opened and attributes the current session.
  void trackAppOpened() {
    _analytics.setUser(currentUser?.id);
    _track(AnalyticsEvent.appOpened);
  }

  /// Records that a company profile was viewed.
  void trackCompanyViewed(String companyId) =>
      _track(AnalyticsEvent.companyViewed, params: {'company_id': companyId});

  /// Records that a search was performed.
  void trackSearch(String query, {String? category}) => _track(
        AnalyticsEvent.searchPerformed,
        params: {'q': query, if (category != null) 'category': category},
      );

  Future<void> resetAll() async {
    await _local.clearAll();
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

  // ---------- session / auth (salted hashing, P2) ----------
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
    // Validate input through the shared rules so the facade and the Clean
    // Architecture auth repository cannot disagree (a QA pass found the facade
    // accepting empty emails and 1-char passwords the repository rejected).
    final err = Validators.signupError(
      name: name,
      email: email,
      password: password,
    );
    if (err != null) throw Exception(err);

    email = email.trim().toLowerCase();
    if (users.any((u) => u.email == email)) {
      throw Exception('An account with that email already exists.');
    }
    final user = AppUser(
      name: name,
      email: email,
      password: _hasher.hash(password), // hashed, never plaintext
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
        city: location.isNotEmpty ? location : 'Your City',
      );
      _companiesBox.put(company.id, company.toJson());
      user.companyId = company.id;
    }
    _usersBox.put(user.id, user.toJson());
    _box.put('session', user.id);
    _analytics.setUser(user.id);
    _track(AnalyticsEvent.signUp, params: {'role': roleToString(role)});
    notifyListeners();
    return user;
  }

  AppUser login({required String email, required String password}) {
    email = email.trim().toLowerCase();
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Please enter your email and password.');
    }
    for (final u in users) {
      if (u.email == email && _hasher.verify(password, u.password)) {
        if (_hasher.isLegacy(u.password)) {
          u.password = _hasher.hash(password);
          _usersBox.put(u.id, u.toJson());
        }
        _box.put('session', u.id);
        _analytics.setUser(u.id);
        _track(AnalyticsEvent.login);
        notifyListeners();
        return u;
      }
    }
    throw Exception('Invalid email or password.');
  }

  void logout() {
    _track(AnalyticsEvent.logout);
    _analytics.setUser(null);
    _box.delete('session');
    notifyListeners();
  }

  // ---------- companies ----------
  void updateCompany(Company c) {
    _companiesBox.put(c.id, c.toJson());
    notifyListeners();
  }

  // ---------- maps / routing (TH-019) ----------

  /// Estimates a route between two free-text locations, or null if either is
  /// empty or can't be resolved. Backed by the [MapsService] abstraction
  /// (offline estimator by default; swappable for Google/Mapbox).
  Future<RoutePreview?> estimateRoute(String pickup, String dropoff) async {
    if (pickup.trim().isEmpty || dropoff.trim().isEmpty) return null;
    final maps = sl<MapsService>();
    final from = await maps.geocode(pickup);
    final to = await maps.geocode(dropoff);
    if (from == null || to == null) return null;
    return maps.routePreview(from, to);
  }

  // ---------- provider verification (TH-017) ----------

  /// Human-friendly label for a verification status.
  String verificationLabel(String status) => switch (status) {
        'submitted' => 'Submitted',
        'under_review' => 'Under review',
        'approved' => 'Verified',
        'rejected' => 'Rejected',
        _ => 'Unverified',
      };

  /// Provider submits their company for verification (unverified/rejected →
  /// submitted). Notifies the owner that the request was received (TH-018).
  void submitForVerification(String companyId) {
    final c = company(companyId);
    if (c == null) return;
    c.verificationStatus = 'submitted';
    updateCompany(c);
    addNotification(AppNotification(
      userId: c.ownerId,
      title: 'Verification submitted',
      body: 'Your verification request for ${c.name} is now in the queue.',
      kind: NotificationKind.system,
    ));
  }

  /// Whether the signed-in user is an administrator (config-driven, TH-017).
  bool get isAdmin => sl<AppConfig>().isAdmin(currentUser?.email);

  /// Companies awaiting an admin decision, oldest first (review queue).
  List<Company> get companiesForReview => companies
      .where((c) =>
          c.verificationStatus == 'submitted' ||
          c.verificationStatus == 'under_review')
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Transitions a company's verification status (e.g. admin review action).
  /// Keeps the legacy [Company.verified] boolean in sync and notifies the
  /// owner of the outcome.
  void setVerificationStatus(String companyId, String status) {
    final c = company(companyId);
    if (c == null) return;
    c.verificationStatus = status;
    c.verified = status == 'approved';
    updateCompany(c);
    addNotification(AppNotification(
      userId: c.ownerId,
      title: 'Verification ${verificationLabel(status).toLowerCase()}',
      body: status == 'approved'
          ? '${c.name} is now a verified provider.'
          : 'Verification status for ${c.name}: ${verificationLabel(status)}.',
      kind: NotificationKind.system,
    ));
  }

  // ---------- services ----------
  void addService(String companyId, TransportService s) {
    final c = company(companyId);
    if (c == null) return;
    c.services.add(s);
    updateCompany(c);
    _track(AnalyticsEvent.serviceCreated, params: {'company_id': companyId});
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
    // Persist the UI model, then seed the lifecycle history with an initial
    // "Booking created" event (TH-016) by merging the events key into the
    // stored JSON without coupling the legacy UI model to the event type.
    final json = b.toJson()
      ..['events'] = [
        {
          'status': b.status,
          'at': DateTime.now().millisecondsSinceEpoch,
          'note': 'Booking created',
        }
      ];
    _bookingsBox.put(b.id, json);

    // A request tied to a concrete service is a booking; one without is a
    // quote request (TH-024).
    _track(
      b.serviceId == null
          ? AnalyticsEvent.quoteRequested
          : AnalyticsEvent.bookingCreated,
      params: {
        'company_id': b.companyId,
        if (b.serviceId != null) 'service_id': b.serviceId,
      },
    );

    // Notify the provider that owns the company of the new request (TH-018).
    final c = company(b.companyId);
    if (c != null && c.ownerId.isNotEmpty) {
      addNotification(AppNotification(
        userId: c.ownerId,
        title: 'New booking request',
        body: b.contactName.isEmpty
            ? 'You have a new booking request.'
            : '${b.contactName} requested a booking.',
        kind: NotificationKind.bookingUpdate,
      ));
    }
    notifyListeners();
    return b;
  }

  List<Booking> bookingsForCompany(String companyId) =>
      bookings.where((b) => b.companyId == companyId).toList();

  List<Booking> bookingsForUser(String userId) =>
      bookings.where((b) => b.userId == userId).toList();

  /// Ordered lifecycle statuses (TH-016) for UI pickers.
  List<String> get bookingStatuses =>
      dom.BookingStatus.values.map((s) => s.wire).toList();

  /// Human-friendly label for a wire status, e.g. `in_transit` → "In transit".
  String statusLabel(String wire) => dom.bookingStatusFromWire(wire).label;

  /// Valid next transitions (as wire values) from the given status (TH-016).
  /// Drives the dashboard's status controls so providers can only move a
  /// booking along legal lifecycle edges.
  List<String> nextStatuses(String wire) =>
      dom.bookingStatusFromWire(wire).nextStates.map((s) => s.wire).toList();

  /// Whether a status is terminal (completed/cancelled) — no further actions.
  bool isTerminalStatus(String wire) =>
      dom.bookingStatusFromWire(wire).isTerminal;

  /// Transitions a booking. Returns `false` (and does nothing) if the move is
  /// not a legal lifecycle transition, so callers can surface an error.
  bool setBookingStatus(String id, String status, {String note = ''}) {
    // Route through the domain repository so the transition is appended to the
    // booking's event history (TH-016) and preserved in the cache, rather than
    // overwriting the record with the event-less UI model. The repository
    // enforces the state machine and returns false for illegal moves.
    final applied = sl<dom_repo.BookingRepository>()
        .setStatus(id, dom.bookingStatusFromWire(status), note: note);
    if (!applied) return false;

    _track(
      AnalyticsEvent.bookingStatusChanged,
      params: {'booking_id': id, 'status': status},
    );

    // Notify the customer who placed the booking (TH-018).
    final j = _bookingsBox.get(id);
    if (j != null) {
      final b = Booking.fromJson(j as Map);
      if (b.userId != null && b.userId!.isNotEmpty) {
        addNotification(AppNotification(
          userId: b.userId!,
          title: 'Booking ${statusLabel(status).toLowerCase()}',
          body: note.isNotEmpty
              ? note
              : 'Your booking is now "${statusLabel(status)}".',
          kind: NotificationKind.bookingUpdate,
        ));
      }
    }
    notifyListeners();
    return true;
  }

  // ---------- notifications (TH-018) ----------
  NotificationRepository get _notifications => sl<NotificationRepository>();

  /// Notifications for the signed-in user, newest first.
  List<AppNotification> get notifications {
    final u = currentUser;
    return u == null ? const [] : _notifications.forUser(u.id);
  }

  /// Unread count for the signed-in user (drives the app-bar badge).
  int get unreadNotifications {
    final u = currentUser;
    return u == null ? 0 : _notifications.unreadCount(u.id);
  }

  void addNotification(AppNotification n) {
    _notifications.add(n);
    notifyListeners();
  }

  void markNotificationRead(String id) {
    _notifications.markRead(id);
    notifyListeners();
  }

  void markAllNotificationsRead() {
    final u = currentUser;
    if (u == null) return;
    _notifications.markAllRead(u.id);
    notifyListeners();
  }

  // ---------- reviews ----------
  void addReview(Review r) {
    _reviewsBox.put(r.id, r.toJson());
    _track(
      AnalyticsEvent.reviewSubmitted,
      params: {'company_id': r.companyId, 'rating': r.rating},
    );
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
    final nowFav = favs.contains(companyId);
    _track(
      AnalyticsEvent.favoriteToggled,
      params: {'company_id': companyId, 'favorited': nowFav},
    );
    notifyListeners();
    return nowFav;
  }

  // ---------- location ----------
  String get location => (_box.get('location') as String?) ?? '';
  void setLocation(String loc) {
    _box.put('location', loc);
    notifyListeners();
  }
}
