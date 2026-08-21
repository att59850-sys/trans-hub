import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/domain/entities/booking_status.dart';

void main() {
  group('BookingStatus', () {
    test('wire round-trips through parser', () {
      for (final s in BookingStatus.values) {
        expect(bookingStatusFromWire(s.wire), s);
      }
    });

    test('legacy "confirmed" maps to accepted', () {
      expect(bookingStatusFromWire('confirmed'), BookingStatus.accepted);
    });

    test('unknown maps to pending', () {
      expect(bookingStatusFromWire('???'), BookingStatus.pending);
      expect(bookingStatusFromWire(null), BookingStatus.pending);
    });

    test('lifecycle has 8 states', () {
      expect(BookingStatus.values.length, 8);
    });

    test('terminal states have no next transitions', () {
      expect(BookingStatus.completed.nextStates, isEmpty);
      expect(BookingStatus.cancelled.nextStates, isEmpty);
      expect(BookingStatus.completed.isTerminal, isTrue);
    });

    test('pending can advance to accepted or cancelled', () {
      expect(BookingStatus.pending.nextStates,
          containsAll([BookingStatus.accepted, BookingStatus.cancelled]));
    });

    group('canTransitionTo (state-machine guard)', () {
      test('allows only declared next states', () {
        for (final from in BookingStatus.values) {
          for (final to in BookingStatus.values) {
            expect(
              from.canTransitionTo(to),
              from.nextStates.contains(to),
              reason: '${from.wire} -> ${to.wire}',
            );
          }
        }
      });

      test('blocks illegal jumps a client might attempt', () {
        expect(BookingStatus.pending.canTransitionTo(BookingStatus.completed),
            isFalse);
        expect(BookingStatus.pending.canTransitionTo(BookingStatus.inTransit),
            isFalse);
        expect(BookingStatus.draft.canTransitionTo(BookingStatus.completed),
            isFalse);
      });

      test('blocks any move out of a terminal state', () {
        for (final to in BookingStatus.values) {
          expect(BookingStatus.completed.canTransitionTo(to), isFalse);
          expect(BookingStatus.cancelled.canTransitionTo(to), isFalse);
        }
      });

      test('blocks self-transition (no-op is not a real move)', () {
        for (final s in BookingStatus.values) {
          expect(s.canTransitionTo(s), isFalse);
        }
      });
    });

    group('canonical wire recognition (QA round 16)', () {
      test('every enum wire is recognised', () {
        for (final s in BookingStatus.values) {
          expect(isKnownBookingStatusWire(s.wire), isTrue, reason: s.wire);
        }
      });

      test('kBookingStatusWires holds exactly the enum wires', () {
        expect(kBookingStatusWires,
            BookingStatus.values.map((s) => s.wire).toSet());
      });

      test('typos and unknown values are not recognised', () {
        for (final w in [
          'complete', // typo for completed
          'in-transit', // hyphen instead of underscore
          'confirmedd',
          'PENDING', // wrong case
          '',
          ' pending',
        ]) {
          expect(isKnownBookingStatusWire(w), isFalse, reason: '"$w"');
        }
      });

      test('null is not recognised', () {
        expect(isKnownBookingStatusWire(null), isFalse);
      });

      test('legacy alias "confirmed" is readable but not a canonical target',
          () {
        // The parser still resolves a stored legacy value...
        expect(bookingStatusFromWire('confirmed'), BookingStatus.accepted);
        // ...but it is NOT a valid write target (callers must use 'accepted').
        expect(isKnownBookingStatusWire('confirmed'), isFalse);
      });
    });
  });
}
