import '../../core/utils/ordering.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/hive_local_datasource.dart';
import '../models/booking_dto.dart';

/// Hive-backed [BookingRepository] with lifecycle event tracking (TH-016).
class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  @override
  List<Booking> all() => _ds.bookings.values
      .map((e) => bookingFromJson(e as Map))
      .toList()
    // Newest first, stable on same-millisecond ties (QA round 7 sweep).
    ..sort(
        (a, b) => Ordering.newestFirst(a.createdAt, a.id, b.createdAt, b.id));

  @override
  Booking create(Booking booking) {
    // Seed the event history with the initial status.
    if (booking.events.isEmpty) {
      booking.events.add(
        BookingEvent(status: booking.status, note: 'Booking created'),
      );
    }
    _ds.bookings.put(booking.id, booking.toJson());
    return booking;
  }

  @override
  List<Booking> forCompany(String companyId) =>
      all().where((b) => b.companyId == companyId).toList();

  @override
  List<Booking> forUser(String userId) =>
      all().where((b) => b.userId == userId).toList();

  @override
  bool setStatus(String bookingId, BookingStatus status, {String note = ''}) {
    final j = _ds.bookings.get(bookingId);
    if (j == null) return false;
    final b = bookingFromJson(j as Map);

    // Defend the lifecycle invariant at the data layer: reject illegal
    // transitions regardless of who calls us (UI, sync engine, future API).
    if (!b.status.canTransitionTo(status)) return false;

    b
      ..status = status
      ..events.add(BookingEvent(status: status, note: note));
    _ds.bookings.put(bookingId, b.toJson());
    return true;
  }
}
