import 'dart:io';

import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transport_hub/core/di/injection.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/models/models.dart';
import 'package:transport_hub/services/data_service.dart';

/// "Human user" end-to-end journey (manual-QA simulation).
///
/// Instead of unit-testing pieces, this drives the exact `DataService` facade
/// methods the UI screens call, in the order a real person would tap through
/// the app. Every step is logged so the run reads like a QA session; failures
/// point straight at the broken user action.
///
/// The journeys run sequentially against one seeded singleton and build on each
/// other (a provider submits for verification in journey 2, an admin approves
/// it in journey 4), mirroring a continuous session.
///
/// NOTE: this exercises the full app graph (Hive + DI + every repository) and
/// is intended to run in CI. It compiles a large kernel, so it can OOM on very
/// low-memory hosts; the credential-free logic covered here is also validated
/// by `tool/human_journey.dart`, which runs on the plain Dart VM.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ds = DataService.instance;
  late Directory tempDir;

  void step(String s) => debugPrint('  >> $s');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('transhub_human_');
    Hive.init(tempDir.path);

    // Bootstrap the same stack DataService.init() builds, but without
    // Hive.initFlutter() (no platform path provider on the test host).
    final local = HiveLocalDataSource.instance;
    local.meta = await Hive.openBox(HiveLocalDataSource.metaBox);
    local.companies = await Hive.openBox(HiveLocalDataSource.companiesBox);
    local.users = await Hive.openBox(HiveLocalDataSource.usersBox);
    local.bookings = await Hive.openBox(HiveLocalDataSource.bookingsBox);
    local.reviews = await Hive.openBox(HiveLocalDataSource.reviewsBox);
    local.notifications =
        await Hive.openBox(HiveLocalDataSource.notificationsBox);
    local.pendingOps = await Hive.openBox(HiveLocalDataSource.pendingOpsBox);

    configureDependencies(local);
    await ds.resetAll(); // seed demo data
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('JOURNEY 1: a customer discovers a provider and books', () {
    step('App opens, telemetry fires');
    ds.trackAppOpened();

    step('Browse seeded providers');
    final catalogue = ds.companies;
    expect(catalogue, isNotEmpty, reason: 'seed data should list providers');
    debugPrint('     found ${catalogue.length} providers');
    final target = catalogue.first;

    step('Search for something');
    ds.trackSearch('movers', category: null);

    step('Open a provider profile');
    ds.trackCompanyViewed(target.id);
    final profile = ds.company(target.id);
    expect(profile, isNotNull);

    step('Sign up as a customer');
    final customer = ds.signup(
      name: 'Jane Customer',
      email: 'jane@example.com',
      password: 'secret123',
      role: UserRole.customer,
    );
    expect(ds.currentUser?.id, customer.id);
    expect(customer.password, isNot('secret123'),
        reason: 'password must be hashed, never plaintext');

    step('Save provider to favourites');
    final favOn = ds.toggleFav(target.id);
    expect(favOn, isTrue);
    expect(ds.isFav(target.id), isTrue);

    step('Request a booking');
    final booking = ds.createBooking(Booking(
      companyId: target.id,
      userId: customer.id,
      contactName: 'Jane Customer',
      contactEmail: 'jane@example.com',
      phone: '555-0100',
      pickup: 'New York',
      dropoff: 'Boston',
      date: '2026-08-01',
      notes: 'Two-bedroom apartment',
      status: 'pending',
    ));
    final mine = ds.bookingsForUser(customer.id);
    expect(mine.map((b) => b.id), contains(booking.id));
    debugPrint('     booking ${booking.id} status=${booking.status}');

    step('A booking with a malformed contact email is rejected (QA round 11)');
    final beforeCount = ds.bookingsForCompany(target.id).length;
    expect(
      () => ds.createBooking(Booking(
        companyId: target.id,
        userId: customer.id,
        contactName: 'Jane',
        contactEmail: 'notanemail',
      )),
      throwsA(isA<Exception>()),
    );
    // The rejected request must NOT have been persisted.
    expect(ds.bookingsForCompany(target.id).length, beforeCount);

    step('Leave a review');
    ds.addReview(Review(
      companyId: target.id,
      name: 'Jane Customer',
      rating: 5,
      text: 'Smooth and on time!',
    ));
    final rating = ds.ratingFor(target.id);
    expect(rating.count, greaterThanOrEqualTo(1));
    debugPrint('     rating now ${rating.avg} (${rating.count} reviews)');

    step('Log out');
    ds.logout();
    expect(ds.currentUser, isNull);
  });

  test('JOURNEY 2: a provider signs up, lists a service, works a booking', () {
    step('Sign up as a company');
    final owner = ds.signup(
      name: 'Pat Provider',
      email: 'pat@haulers.com',
      password: 'movepeople',
      role: UserRole.company,
      companyName: 'Pat Haulers',
    );
    final myCo = ds.myCompany;
    expect(myCo, isNotNull,
        reason: 'company sign-up should auto-create a Company');
    debugPrint('     company ${myCo!.id} "${myCo.name}"');

    step('Submit for verification');
    ds.submitForVerification(myCo.id);
    final afterSubmit = ds.company(myCo.id)!;
    debugPrint('     verification=${afterSubmit.verificationStatus}');
    expect(afterSubmit.verificationStatus, 'submitted');

    step('Publish a service');
    ds.addService(
      myCo.id,
      TransportService(
        name: 'Long-distance moving',
        desc: 'Interstate household moves',
        unit: 'per trip',
        price: 900,
      ),
    );
    final withService = ds.company(myCo.id)!;
    expect(withService.services, isNotEmpty);

    step('A customer books this provider');
    final booking = ds.createBooking(Booking(
      companyId: myCo.id,
      serviceId: withService.services.first.id,
      userId: 'anon-buyer',
      contactName: 'Bob Buyer',
      contactEmail: 'bob@example.com',
      phone: '555-0200',
      pickup: 'Chicago',
      dropoff: 'Denver',
      date: '2026-09-10',
      notes: '',
      status: 'pending',
    ));

    step('Provider sees a notification for the request');
    ds.logout();
    ds.login(email: 'pat@haulers.com', password: 'movepeople');
    final inbox = ds.notifications;
    debugPrint('     provider inbox: ${inbox.length} notification(s)');
    expect(inbox, isNotEmpty,
        reason: 'new-booking notification should reach owner');

    step('Move booking through its lifecycle');
    var current = ds.bookings.firstWhere((b) => b.id == booking.id).status;
    debugPrint('     start: $current');
    while (!ds.isTerminalStatus(current)) {
      final next = ds.nextStatuses(current);
      if (next.isEmpty) break;
      final choice = next.first;
      ds.setBookingStatus(booking.id, choice, note: 'advancing');
      current = ds.bookings.firstWhere((b) => b.id == booking.id).status;
      debugPrint('     -> ${ds.statusLabel(current)}');
    }
    expect(ds.isTerminalStatus(current), isTrue,
        reason: 'booking should reach a terminal state');
  });

  test('JOURNEY 3: route estimate on the booking form', () async {
    step('Estimate NYC -> Boston');
    final preview = await ds.estimateRoute('New York', 'Boston');
    expect(preview, isNotNull,
        reason: 'offline estimator should return a route');
    debugPrint('     ~${preview!.distanceKm.toStringAsFixed(0)} km, '
        '${preview.durationMinutes} min');
    expect(preview.distanceKm, greaterThan(0));
    expect(preview.durationMinutes, greaterThan(0));
  });

  test('JOURNEY 4: admin reviews the verification queue', () {
    step('Log in as the configured admin');
    // Dev default admin email is admin@transporthub.app; create + sign in.
    ds.logout();
    try {
      ds.signup(
        name: 'Admin',
        email: 'admin@transporthub.app',
        password: 'adminpass',
        role: UserRole.customer,
      );
    } catch (_) {
      ds.login(email: 'admin@transporthub.app', password: 'adminpass');
    }
    debugPrint('     isAdmin=${ds.isAdmin}');
    expect(ds.isAdmin, isTrue, reason: 'configured email should be admin');

    step('Inspect the review queue');
    final queue = ds.companiesForReview;
    debugPrint('     ${queue.length} company/companies awaiting review');
    expect(queue, isNotEmpty, reason: 'Pat Haulers submitted in journey 2');

    step('Approve the first pending company');
    final co = queue.first;
    ds.setVerificationStatus(co.id, 'approved');
    final approved = ds.company(co.id)!;
    debugPrint('     ${approved.name} -> ${approved.verificationStatus}');
    expect(approved.verificationStatus, 'approved');
    expect(approved.verified, isTrue,
        reason: 'legacy verified flag should stay in sync');
  });
}
