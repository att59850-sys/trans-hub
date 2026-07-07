import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/data/models/booking_dto.dart';
import 'package:transport_hub/data/models/company_dto.dart';
import 'package:transport_hub/data/models/review_dto.dart';
import 'package:transport_hub/data/models/transport_service_dto.dart';
import 'package:transport_hub/domain/entities/entities.dart';

void main() {
  group('DTO round-trips', () {
    test('TransportService', () {
      final s = TransportService(
        name: 'Express',
        desc: 'Fast',
        unit: 'per kg',
        price: 2.5,
        icon: 'send',
      );
      final back = transportServiceFromJson(s.toJson());
      expect(back.name, s.name);
      expect(back.price, s.price);
      expect(back.unit, s.unit);
      expect(back.priceLabel, '\$2.50 / kg');
    });

    test('Company with services', () {
      final c = Company(
        ownerId: 'u_1',
        name: 'Acme',
        category: 'freight',
        services: [TransportService(name: 'Full load')],
      );
      final back = companyFromJson(c.toJson());
      expect(back.name, 'Acme');
      expect(back.services.length, 1);
      expect(back.verificationStatus, 'unverified');
      expect(back.serviceById(back.services.first.id), isNotNull);
    });

    test('Booking preserves status + events', () {
      final b = Booking(companyId: 'c_1', status: BookingStatus.inTransit)
        ..events.add(BookingEvent(status: BookingStatus.inTransit));
      final back = bookingFromJson(b.toJson());
      expect(back.status, BookingStatus.inTransit);
      expect(back.events.length, 1);
    });

    test('Booking reads legacy "confirmed"', () {
      final json = Booking(companyId: 'c_1').toJson()..['status'] = 'confirmed';
      expect(bookingFromJson(json).status, BookingStatus.accepted);
    });

    test('Review', () {
      final r = Review(companyId: 'c_1', name: 'Jo', rating: 5, text: 'Great');
      final back = reviewFromJson(r.toJson());
      expect(back.rating, 5);
      expect(back.text, 'Great');
    });
  });
}
