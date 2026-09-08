import 'dart:io';

import 'package:hive/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transport_hub/core/utils/password_hasher.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/data/repositories/auth_repository_impl.dart';
import 'package:transport_hub/data/repositories/booking_repository_impl.dart';
import 'package:transport_hub/data/repositories/company_repository_impl.dart';
import 'package:transport_hub/data/repositories/favorites_repository_impl.dart';
import 'package:transport_hub/data/repositories/notification_repository_impl.dart';
import 'package:transport_hub/data/repositories/review_repository_impl.dart';
import 'package:transport_hub/domain/entities/entities.dart';
import 'package:transport_hub/domain/usecases/usecases.dart';

/// TH-022 — Integration tests covering the core end-to-end user journeys
/// against the real repository + Hive stack:
///   1. Sign-up flow (customer)
///   2. Provider onboarding (company sign-up auto-creates a Company)
///   3. Booking lifecycle (create → quote → accept → in-transit → complete)
///   4. Review submission and aggregate rating
///
/// The harness opens Hive against a temporary directory so the suite is
/// portable: it runs under `flutter test integration_test/app_test.dart`
/// on the host as well as on a device/emulator in CI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveLocalDataSource ds;
  late AuthRepositoryImpl auth;
  late CompanyRepositoryImpl companies;
  late BookingRepositoryImpl bookings;
  late ReviewRepositoryImpl reviews;
  late FavoritesRepositoryImpl favorites;
  late NotificationRepositoryImpl notifications;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transhub_it_');
    Hive.init(tempDir.path);

    ds = HiveLocalDataSource.instance;
    // Open the same set of boxes the app uses (bypassing initFlutter so the
    // suite does not need a platform path provider).
    ds.meta = await Hive.openBox(HiveLocalDataSource.metaBox);
    ds.companies = await Hive.openBox(HiveLocalDataSource.companiesBox);
    ds.users = await Hive.openBox(HiveLocalDataSource.usersBox);
    ds.bookings = await Hive.openBox(HiveLocalDataSource.bookingsBox);
    ds.reviews = await Hive.openBox(HiveLocalDataSource.reviewsBox);
    ds.notifications = await Hive.openBox(HiveLocalDataSource.notificationsBox);
    ds.pendingOps = await Hive.openBox(HiveLocalDataSource.pendingOpsBox);

    auth = AuthRepositoryImpl(ds, hasher: const PasswordHasher());
    companies = CompanyRepositoryImpl(ds);
    bookings = BookingRepositoryImpl(ds);
    reviews = ReviewRepositoryImpl(ds);
    favorites = FavoritesRepositoryImpl(ds);
    notifications = NotificationRepositoryImpl(ds);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('Sign-up flow', () {
    test('registers a customer and starts a session', () {
      final register = RegisterUser(auth);
      final user = register(
        name: 'Ada Customer',
        email: 'Ada@Example.com',
        password: 'secret123',
        role: UserRole.customer,
      );

      expect(user.role, UserRole.customer);
      expect(user.email, 'ada@example.com'); // normalized
      expect(user.companyId, isNull);
      // Password is hashed, never stored in plaintext.
      expect(user.passwordHash, isNot('secret123'));
      expect(auth.currentUser?.id, user.id);
    });

    test('rejects a duplicate email', () {
      final register = RegisterUser(auth);
      register(
        name: 'First',
        email: 'dup@example.com',
        password: 'secret123',
        role: UserRole.customer,
      );
      expect(
        () => register(
          name: 'Second',
          email: 'dup@example.com',
          password: 'another1',
          role: UserRole.customer,
        ),
        throwsA(isA<Object>()),
      );
    });

    test('login succeeds with correct credentials and fails otherwise', () {
      RegisterUser(auth)(
        name: 'Login User',
        email: 'login@example.com',
        password: 'goodpass',
        role: UserRole.customer,
      );
      LogoutUser(auth)();
      expect(auth.currentUser, isNull);

      final login = LoginUser(auth);
      final back = login(email: 'login@example.com', password: 'goodpass');
      expect(back.email, 'login@example.com');

      LogoutUser(auth)();
      expect(
        () => login(email: 'login@example.com', password: 'wrong'),
        throwsA(isA<Object>()),
      );
    });
  });

  group('Provider onboarding', () {
    test('company sign-up auto-creates a linked Company', () {
      final user = RegisterUser(auth)(
        name: 'Owner',
        email: 'owner@example.com',
        password: 'ownerpass',
        role: UserRole.company,
        companyName: 'Skyline Logistics',
        defaultCity: 'Lagos',
      );

      expect(user.role, UserRole.company);
      expect(user.companyId, isNotNull);

      final company = companies.byId(user.companyId!);
      expect(company, isNotNull);
      expect(company!.name, 'Skyline Logistics');
      expect(company.city, 'Lagos');
      expect(company.ownerId, user.id);
    });

    test('owner can add a service to their company', () {
      final user = RegisterUser(auth)(
        name: 'Owner2',
        email: 'owner2@example.com',
        password: 'ownerpass',
        role: UserRole.company,
        companyName: 'Cargo Co',
      );
      final cid = user.companyId!;

      final service = TransportService(
        name: 'Same-day courier',
        desc: 'Door-to-door within the city',
        unit: 'flat',
        price: 25,
      );
      companies.addService(cid, service);

      final company = companies.byId(cid)!;
      expect(company.services.any((s) => s.name == 'Same-day courier'), isTrue);
    });
  });

  group('Booking lifecycle', () {
    test('records every transition in the event history', () {
      final owner = RegisterUser(auth)(
        name: 'Provider',
        email: 'provider@example.com',
        password: 'providerpw',
        role: UserRole.company,
        companyName: 'Move It',
      );
      final cid = owner.companyId!;

      final created = CreateBooking(bookings)(
        Booking(
          companyId: cid,
          contactName: 'Buyer',
          pickup: 'A',
          dropoff: 'B',
          status: BookingStatus.quoteRequested,
        ),
      );
      expect(created.events, hasLength(1));
      expect(created.events.first.status, BookingStatus.quoteRequested);

      final update = UpdateBookingStatus(bookings);
      update(created.id, BookingStatus.quoteSent, note: 'Quote: 100');
      update(created.id, BookingStatus.accepted);
      update(created.id, BookingStatus.inTransit);
      update(created.id, BookingStatus.completed);

      final reloaded = bookings.all().firstWhere((b) => b.id == created.id);
      expect(reloaded.status, BookingStatus.completed);
      expect(reloaded.status.isTerminal, isTrue);
      // Initial + four transitions.
      expect(reloaded.events, hasLength(5));
      expect(
        reloaded.events.map((e) => e.status).toList(),
        [
          BookingStatus.quoteRequested,
          BookingStatus.quoteSent,
          BookingStatus.accepted,
          BookingStatus.inTransit,
          BookingStatus.completed,
        ],
      );
    });

    test('bookings are queryable by company and user', () {
      final owner = RegisterUser(auth)(
        name: 'P',
        email: 'p@example.com',
        password: 'password',
        role: UserRole.company,
        companyName: 'Q',
      );
      final cid = owner.companyId!;

      CreateBooking(bookings)(
        Booking(companyId: cid, userId: 'u1', pickup: 'X'),
      );
      CreateBooking(bookings)(
        Booking(companyId: cid, userId: 'u2', pickup: 'Y'),
      );

      expect(bookings.forCompany(cid), hasLength(2));
      expect(bookings.forUser('u1'), hasLength(1));
    });
  });

  group('Review submission', () {
    test('submitting reviews updates the aggregate rating', () {
      final owner = RegisterUser(auth)(
        name: 'Provider',
        email: 'rev@example.com',
        password: 'password',
        role: UserRole.company,
        companyName: 'Rated Co',
      );
      final cid = owner.companyId!;

      expect(reviews.ratingFor(cid), (avg: 0.0, count: 0));

      final submit = SubmitReview(reviews);
      submit(Review(companyId: cid, name: 'A', rating: 5, text: 'Great'));
      submit(Review(companyId: cid, name: 'B', rating: 4, text: 'Good'));

      final rating = reviews.ratingFor(cid);
      expect(rating.count, 2);
      expect(rating.avg, 4.5);
      expect(reviews.forCompany(cid), hasLength(2));
    });
  });

  group('Favorites', () {
    test('toggle adds and removes a company', () {
      final toggle = ToggleFavorite(favorites);
      expect(favorites.isFavorite('c1'), isFalse);
      expect(toggle('c1'), isTrue);
      expect(favorites.isFavorite('c1'), isTrue);
      expect(toggle('c1'), isFalse);
      expect(favorites.isFavorite('c1'), isFalse);
    });
  });

  group('Notifications', () {
    test('delivers per-user and tracks unread / read state', () {
      notifications.add(AppNotification(
        userId: 'u1',
        title: 'Booking accepted',
        kind: NotificationKind.bookingUpdate,
      ));
      notifications.add(AppNotification(userId: 'u1', title: 'Quote sent'));
      notifications.add(AppNotification(userId: 'u2', title: 'Other user'));

      expect(notifications.forUser('u1'), hasLength(2));
      expect(notifications.unreadCount('u1'), 2);
      expect(notifications.forUser('u2'), hasLength(1));

      final first = notifications.forUser('u1').first;
      // Owner-scoped mark-read (QA round 20): another user cannot clear it,
      // but the rightful owner can.
      expect(notifications.markRead('u2', first.id), isFalse);
      expect(notifications.unreadCount('u1'), 2);
      expect(notifications.markRead('u1', first.id), isTrue);
      expect(notifications.unreadCount('u1'), 1);

      notifications.markAllRead('u1');
      expect(notifications.unreadCount('u1'), 0);
      // u2 is unaffected.
      expect(notifications.unreadCount('u2'), 1);
    });
  });
}
