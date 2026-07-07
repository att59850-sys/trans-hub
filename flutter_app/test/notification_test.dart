import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/data/models/app_notification_dto.dart';
import 'package:transport_hub/data/models/pending_operation_dto.dart';
import 'package:transport_hub/domain/entities/app_notification.dart';
import 'package:transport_hub/domain/entities/pending_operation.dart';

void main() {
  group('AppNotification', () {
    test('kind wire round-trips', () {
      for (final k in NotificationKind.values) {
        expect(
          notificationKindFromString(notificationKindToString(k)),
          k,
        );
      }
    });

    test('DTO round-trip', () {
      final n = AppNotification(
        userId: 'u_1',
        title: 'Booking accepted',
        body: 'Your booking is confirmed',
        kind: NotificationKind.bookingUpdate,
      );
      final back = appNotificationFromJson(n.toJson());
      expect(back.title, n.title);
      expect(back.kind, NotificationKind.bookingUpdate);
      expect(back.read, isFalse);
    });
  });

  group('PendingOperation', () {
    test('DTO round-trip preserves payload + type', () {
      final op = PendingOperation(
        type: SyncOpType.delete,
        table: 'reviews',
        recordId: 'r_1',
        payload: const {'id': 'r_1', 'rating': 5},
      );
      final back = pendingOperationFromJson(op.toJson());
      expect(back.type, SyncOpType.delete);
      expect(back.table, 'reviews');
      expect(back.payload['rating'], 5);
    });
  });
}
