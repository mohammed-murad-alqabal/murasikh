import 'package:flutter_test/flutter_test.dart';
import 'package:murassikh_app/services/notification_service.dart';

void main() {
  group('NotificationSchedulePolicy', () {
    test('moves a passed time to the next day', () {
      final now = DateTime(2026, 1, 1, 21, 30);
      final next = NotificationSchedulePolicy.nextInstanceOfTime(now, 20, 0);

      expect(next, DateTime(2026, 1, 2, 20, 0));
    });

    test('keeps a future time on the current day', () {
      final now = DateTime(2026, 1, 1, 18, 30);
      final next = NotificationSchedulePolicy.nextInstanceOfTime(now, 20, 0);

      expect(next, DateTime(2026, 1, 1, 20, 0));
    });

    test('handles quiet hours that cross midnight', () {
      expect(
        NotificationSchedulePolicy.isWithinQuietHours(
          DateTime(2026, 1, 1, 23, 30),
          '22:00',
          '06:00',
        ),
        isTrue,
      );
      expect(
        NotificationSchedulePolicy.isWithinQuietHours(
          DateTime(2026, 1, 1, 12, 0),
          '22:00',
          '06:00',
        ),
        isFalse,
      );
    });
  });
}
