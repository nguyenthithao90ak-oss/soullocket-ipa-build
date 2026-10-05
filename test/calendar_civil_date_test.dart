import 'package:flutter_test/flutter_test.dart';
import 'package:soullocket_app/utils/calendar/calendar_civil_date.dart';

void main() {
  group('CalendarCivilDate', () {
    test('đếm ngày theo lịch, không hụt ngày khi qua giờ mùa hè', () {
      // Bắt đầu mùa đông, "hôm nay" mùa hè: ở New York/Berlin cách tính cũ
      // (hiệu hai nửa đêm địa phương rồi .inDays) ra 532.
      expect(
        CalendarCivilDate.daysBetween(
          DateTime(2025, 1, 14),
          DateTime(2026, 7, 1, 12),
        ),
        533,
      );
      expect(
        CalendarCivilDate.daysBetween(
          DateTime(2024, 2, 14),
          DateTime(2026, 10, 5, 0, 30),
        ),
        964,
      );
      expect(
        CalendarCivilDate.daysBetween(
          DateTime(2025, 12, 1),
          DateTime(2026, 4, 1, 23, 59),
        ),
        121,
      );
    });

    test('bỏ qua giờ trong ngày và chấp nhận chiều ngược', () {
      expect(
        CalendarCivilDate.daysBetween(
          DateTime(2026, 3, 8, 23, 59),
          DateTime(2026, 3, 9, 0, 1),
        ),
        1,
      );
      expect(
        CalendarCivilDate.daysBetween(DateTime(2026, 3, 9), DateTime(2026, 3, 8)),
        -1,
      );
    });

    test('cộng ngày theo lịch giữ đúng ngày dù qua DST', () {
      final milestone = CalendarCivilDate.addDays(DateTime(2026, 8, 1), 100);
      expect(CalendarCivilDate.key(milestone), '2026-11-09');
      expect(milestone.hour, 0);

      final back = CalendarCivilDate.addDays(DateTime(2026, 3, 9, 22, 15), -1);
      expect(CalendarCivilDate.key(back), '2026-03-08');
      expect(back.hour, 22);
      expect(back.minute, 15);

      final utc = CalendarCivilDate.addDays(DateTime.utc(2026, 1, 31), 30);
      expect(utc.isUtc, isTrue);
      expect(CalendarCivilDate.key(utc), '2026-03-02');
    });

    test('isSameDay chỉ so ngày/tháng/năm', () {
      expect(
        CalendarCivilDate.isSameDay(
          DateTime(2026, 5, 1, 1),
          DateTime(2026, 5, 1, 23),
        ),
        isTrue,
      );
      expect(
        CalendarCivilDate.isSameDay(DateTime(2026, 5, 1), DateTime(2026, 5, 2)),
        isFalse,
      );
    });
  });
}
