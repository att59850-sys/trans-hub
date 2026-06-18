import '../../core/utils/id_generator.dart';
import 'booking_status.dart';

/// A single transition record in a booking's history (TH-016 booking_events).
class BookingEvent {
  BookingEvent({
    required this.status,
    int? at,
    this.note = '',
  }) : at = at ?? DateTime.now().millisecondsSinceEpoch;

  final BookingStatus status;
  final int at;
  final String note;
}

/// A booking (or quote request) placed by a customer against a company.
class Booking {
  Booking({
    String? id,
    required this.companyId,
    this.serviceId,
    this.userId,
    this.contactName = '',
    this.contactEmail = '',
    this.phone = '',
    this.pickup = '',
    this.dropoff = '',
    this.date = '',
    this.notes = '',
    BookingStatus? status,
    List<BookingEvent>? events,
    int? createdAt,
  })  : id = id ?? newId('b'),
        status = status ?? BookingStatus.pending,
        events = events ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String companyId;
  String? serviceId;
  String? userId;
  String contactName;
  String contactEmail;
  String phone;
  String pickup;
  String dropoff;
  String date;
  String notes;
  BookingStatus status;

  /// Append-only history of status transitions.
  List<BookingEvent> events;
  int createdAt;
}
