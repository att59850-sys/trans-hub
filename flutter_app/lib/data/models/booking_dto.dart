import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_status.dart';

/// JSON (de)serialization for [BookingEvent].
extension BookingEventDto on BookingEvent {
  Map<String, dynamic> toJson() => {
        'status': status.wire,
        'at': at,
        'note': note,
      };
}

BookingEvent bookingEventFromJson(Map j) => BookingEvent(
      status: bookingStatusFromWire(j['status'] as String?),
      at: j['at'] as int?,
      note: (j['note'] ?? '') as String,
    );

/// JSON (de)serialization for [Booking].
extension BookingDto on Booking {
  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'serviceId': serviceId,
        'userId': userId,
        'contactName': contactName,
        'contactEmail': contactEmail,
        'phone': phone,
        'pickup': pickup,
        'dropoff': dropoff,
        'date': date,
        'notes': notes,
        'status': status.wire,
        'events': events.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
      };
}

Booking bookingFromJson(Map j) => Booking(
      id: j['id'] as String?,
      companyId: (j['companyId'] ?? '') as String,
      serviceId: j['serviceId'] as String?,
      userId: j['userId'] as String?,
      contactName: (j['contactName'] ?? '') as String,
      contactEmail: (j['contactEmail'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      pickup: (j['pickup'] ?? '') as String,
      dropoff: (j['dropoff'] ?? '') as String,
      date: (j['date'] ?? '') as String,
      notes: (j['notes'] ?? '') as String,
      status: bookingStatusFromWire(j['status'] as String?),
      events: (j['events'] as List?)
              ?.map((e) => bookingEventFromJson(e as Map))
              .toList() ??
          <BookingEvent>[],
      createdAt: j['createdAt'] as int?,
    );
