import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
import '../core/maps/maps_service.dart';
import '../core/telemetry/analytics.dart';
import '../core/utils/ordering.dart';
import '../core/utils/password_hasher.dart';
import '../core/utils/validators.dart';
import '../core/verification/verification_status.dart';
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

  List<Booking> get bookings => _bookingsBox.values
      .map((e) => Booking.fromJson(e as Map))
      .toList()
    // Newest first, stable on same-millisecond ties (QA round 7 sweep).
    ..sort(
        (a, b) => Ordering.newestFirst(a.createdAt, a.id, b.createdAt, b.id));

  List<Review> reviewsFor(String companyId) => _reviewsBox.values
      .map((e) => Review.fromJson(e as Map))
      .where((r) => r.companyId == companyId)
      .toList()
    // Newest first, stable on same-millisecond ties (QA round 7 sweep).
    ..sort(
        (a, b) => Ordering.newestFirst(a.createdAt, a.id, b.createdAt, b.id));

  ({double avg, int count}) ratingFor(String companyId) {
    final rs = reviewsFor(companyId);
    if (rs.isEmpty) return (avg: 0, count: 0);
    // Clamp each rating on read so any legacy/corrupt out-of-range value can
    // never push a company's average outside 1..5.
    final avg = rs
            .map((r) => Validators.clampRating(r.rating))
            .reduce((a, b) => a + b) /
        rs.length;
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
    // Sanitize numeric profile fields regardless of caller so the UI can never
    // render "-5 vehicles" / "0+ vehicles" / "-3 yrs" (QA round 13). These are
    // idempotent for already-valid values, so internal callers are unaffected.
    c.fleetSize = Validators.sanitizeFleetSize(c.fleetSize);
    c.yearsActive = Validators.sanitizeYearsActive(c.yearsActive);
    // A company must keep a name: if a caller blanked it, fall back to the last
    // stored name rather than persisting a nameless card.
    if (!Validators.isNonEmptyName(c.name)) {
      final existing = company(c.id);
      if (existing != null && Validators.isNonEmptyName(existing.name)) {
        c.name = existing.name;
      }
    } else {
      c.name = c.name.trim();
    }
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
    // No meaningful route when pickup and dropoff are the same place (QA round
    // 18): identical text — or two inputs that resolve to the same point —
    // would otherwise render a phantom "~0 km / ~5m" estimate that looks like a
    // real quote for a trip from a location to itself. Suppress it so the
    // preview strip stays hidden until there are two distinct endpoints.
    if (_sameEndpoint(pickup, dropoff, from, to)) return null;
    return maps.routePreview(from, to);
  }

  /// Whether two endpoints denote the same place: equal case/space-folded text,
  /// or coordinates within ~11 m of each other.
  bool _sameEndpoint(
      String pickup, String dropoff, GeoPoint from, GeoPoint to) {
    if (pickup.trim().toLowerCase() == dropoff.trim().toLowerCase())
      return true;
    const eps = 1e-4;
    return (from.lat - to.lat).abs() < eps && (from.lng - to.lng).abs() < eps;
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
  ///
  /// Returns false (a no-op) if the transition is illegal — e.g. an already
  /// verified company must not be able to re-submit and lose its badge, and a
  /// company already in the queue must not be re-queued (QA round 12).
  bool submitForVerification(String companyId) {
    final c = company(companyId);
    if (c == null) return false;
    final current = verificationStatusFromWire(c.verificationStatus);
    if (!current.canTransitionTo(VerificationStatus.submitted)) return false;
    c.verificationStatus = VerificationStatus.submitted.wire;
    updateCompany(c);
    addNotification(AppNotification(
      userId: c.ownerId,
      title: 'Verification submitted',
      body: 'Your verification request for ${c.name} is now in the queue.',
      kind: NotificationKind.system,
    ));
    return true;
  }

  /// Whether the signed-in user is an administrator (config-driven, TH-017).
  bool get isAdmin => sl<AppConfig>().isAdmin(currentUser?.email);

  /// Companies awaiting an admin decision, oldest first (review queue).
  List<Company> get companiesForReview => companies
      .where((c) =>
          c.verificationStatus == 'submitted' ||
          c.verificationStatus == 'under_review')
      .toList()
    // Oldest first (review queue), stable on same-ms ties (QA round 7 sweep).
    ..sort(
        (a, b) => Ordering.oldestFirst(a.createdAt, a.id, b.createdAt, b.id));

  /// Transitions a company's verification status (e.g. admin review action).
  /// Keeps the legacy [Company.verified] boolean in sync and notifies the
  /// owner of the outcome.
  ///
  /// Returns false (a no-op) if [status] is not a legal next state from the
  /// company's current status. This enforces the review state machine at the
  /// data layer so an unknown/misspelled status or an illegal jump (e.g.
  /// unverified → approved with no submission) can never strand a company
  /// out of the queue or hand out an unearned badge (QA round 12).
  bool setVerificationStatus(String companyId, String status) {
    final c = company(companyId);
    if (c == null) return false;
    final current = verificationStatusFromWire(c.verificationStatus);
    final target = verificationStatusFromWire(status);
    // Reject unknown/misspelled statuses (they parse to unverified, which is
    // never a legal explicit target here) and illegal transitions.
    if (target == VerificationStatus.unverified ||
        !current.canTransitionTo(target)) {
      return false;
    }
    c.verificationStatus = target.wire;
    c.verified = target == VerificationStatus.approved;
    updateCompany(c);
    addNotification(AppNotification(
      userId: c.ownerId,
      title: 'Verification ${target.label.toLowerCase()}',
      body: target == VerificationStatus.approved
          ? '${c.name} is now a verified provider.'
          : 'Verification status for ${c.name}: ${target.label}.',
      kind: NotificationKind.system,
    ));
    return true;
  }

  // ---------- services ----------
  void addService(String companyId, TransportService s) {
    final c = company(companyId);
    if (c == null) return;
    // Defend price integrity regardless of caller: a non-finite (NaN/±Infinity)
    // or negative price would crash the service card or show a nonsensical
    // figure (QA round 9). Sanitize before persisting.
    s.price = Validators.sanitizePrice(s.price);
    c.services.add(s);
    updateCompany(c);
    _track(AnalyticsEvent.serviceCreated, params: {'company_id': companyId});
  }

  void updateService(String companyId, TransportService s) {
    final c = company(companyId);
    if (c == null) return;
    s.price = Validators.sanitizePrice(s.price);
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
    // Defend contact integrity regardless of caller (QA round 11): a provider
    // can only follow up with a real name and a well-formed email. The booking
    // form checks this too, but the facade is the single choke point so no
    // other path can persist an unreachable request.
    final contactErr = Validators.bookingContactError(
        name: b.contactName, email: b.contactEmail);
    if (contactErr != null) {
      throw Exception(contactErr);
    }
    // Normalize the stored contact so trailing spaces / casing don't vary.
    b.contactName = b.contactName.trim();
    b.contactEmail = b.contactEmail.trim();

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
    // Reject an unrecognised/misspelled status wire outright (QA round 16).
    // bookingStatusFromWire tolerantly falls back to `pending`, so without this
    // guard a typo like "complete" on a `draft` booking would silently move it
    // to Pending (draft → pending is a legal edge). Only canonical wires may be
    // written; legacy aliases are read-only compatibility, not write targets.
    if (!dom.isKnownBookingStatusWire(status)) return false;

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
    final u = currentUser;
    if (u == null) return;
    // Scope to the signed-in user so a stale/misrouted id can't clear another
    // account's unread badge (QA round 20).
    _notifications.markRead(u.id, id);
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
    // Defend rating integrity regardless of caller: clamp to the legal 1..5
    // range and require non-empty body text (a QA pass showed an out-of-range
    // rating could skew a company's displayed average, e.g. a 999-star review).
    if (!Validators.isValidReviewText(r.text)) {
      throw Exception('Please write a short review.');
    }

    // A company owner must not review their own company (QA round 14: a
    // provider could otherwise post a 5-star self-review and inflate the
    // rating shown to customers).
    final owner = company(r.companyId)?.ownerId;
    final eligibility = Validators.reviewEligibilityError(
      reviewerId: r.userId,
      ownerUserId: owner,
    );
    if (eligibility != null) throw Exception(eligibility);

    r.rating = Validators.clampRating(r.rating);

    // One review per user per company (QA round 14): a single account could
    // otherwise stack unlimited reviews for one company and skew both its
    // displayed average and its review count. A repeat submission edits the
    // existing review in place instead of adding a new row. Anonymous
    // reviewers (null/empty userId) cannot be de-duplicated, so each stands.
    final existingId = _existingReviewId(r.userId, r.companyId);
    final storageId = existingId ?? r.id;
    final json = r.toJson()..['id'] = storageId;
    _reviewsBox.put(storageId, json);
    _track(
      AnalyticsEvent.reviewSubmitted,
      params: {'company_id': r.companyId, 'rating': r.rating},
    );
    notifyListeners();
  }

  /// Id of an existing review by [userId] for [companyId], or null if none.
  String? _existingReviewId(String? userId, String companyId) {
    if (userId == null || userId.isEmpty) return null;
    for (final e in _reviewsBox.values) {
      final j = e as Map;
      if (j['userId'] == userId && j['companyId'] == companyId) {
        return j['id'] as String?;
      }
    }
    return null;
  }

  // ---------- favorites ----------
  List<String> get favorites {
    // De-dupe on read so a legacy/corrupt list holding the same id twice can't
    // break isFav/toggleFav (a QA pass showed a duplicate made "unfavorite"
    // silently fail — the heart stayed filled). Preserves first-seen order.
    final raw = (_box.get('favorites') as List?)?.map((e) => e.toString()) ??
        const <String>[];
    final seen = <String>{};
    final out = <String>[];
    for (final id in raw) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  bool isFav(String companyId) => favorites.contains(companyId);

  /// Favorited companies that still exist, in the user's saved order.
  ///
  /// A saved id can become a dangling reference when its company disappears —
  /// e.g. a sync `_pull` (server-wins) prunes a company the server no longer
  /// has. This resolver drops those danglers so callers never render a broken
  /// tile or crash on a `firstWhere` miss, and so the "Saved providers" count
  /// reflects only what the user can actually open (QA round 17).
  List<Company> get favoriteCompanies {
    final out = <Company>[];
    for (final id in favorites) {
      final c = company(id);
      if (c != null) out.add(c);
    }
    return out;
  }

  bool toggleFav(String companyId) {
    final favs = favorites; // already de-duped
    if (favs.contains(companyId)) {
      // removeWhere clears ALL copies, not just the first.
      favs.removeWhere((e) => e == companyId);
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
