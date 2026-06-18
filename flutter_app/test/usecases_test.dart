import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transport_hub/domain/entities/entities.dart';
import 'package:transport_hub/domain/repositories/repositories.dart';
import 'package:transport_hub/domain/usecases/usecases.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockBookingRepository extends Mock implements BookingRepository {}

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(Booking(companyId: 'c_1'));
    registerFallbackValue(BookingStatus.pending);
  });

  group('Use cases', () {
    test('LoginUser delegates to AuthRepository', () {
      final auth = MockAuthRepository();
      final user = AppUser(
        name: 'Jo',
        email: 'jo@x.com',
        passwordHash: 'h',
        role: UserRole.customer,
      );
      when(() => auth.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenReturn(user);

      final result = LoginUser(auth)(email: 'jo@x.com', password: 'pw');

      expect(result, user);
      verify(() => auth.login(email: 'jo@x.com', password: 'pw')).called(1);
    });

    test('CreateBooking delegates to BookingRepository', () {
      final repo = MockBookingRepository();
      final booking = Booking(companyId: 'c_1');
      when(() => repo.create(any())).thenReturn(booking);

      final result = CreateBooking(repo)(booking);

      expect(result, booking);
      verify(() => repo.create(booking)).called(1);
    });

    test('UpdateBookingStatus passes status + note', () {
      final repo = MockBookingRepository();
      when(() => repo.setStatus(any(), any(), note: any(named: 'note')))
          .thenReturn(null);

      UpdateBookingStatus(repo)('b_1', BookingStatus.accepted, note: 'ok');

      verify(() => repo.setStatus('b_1', BookingStatus.accepted, note: 'ok'))
          .called(1);
    });

    test('ToggleFavorite returns repository result', () {
      final repo = MockFavoritesRepository();
      when(() => repo.toggle(any())).thenReturn(true);

      expect(ToggleFavorite(repo)('c_1'), isTrue);
      verify(() => repo.toggle('c_1')).called(1);
    });
  });
}
