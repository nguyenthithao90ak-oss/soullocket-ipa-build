import 'package:flutter_test/flutter_test.dart';
import 'package:soullocket_app/utils/services/schedule_notification_presenter.dart';

/// Trả về khóa + tham số để kiểm tra mà không phụ thuộc file dịch.
String _keyText(String key, [Map<String, Object?>? params]) {
  if (params == null || params.isEmpty) return key;
  final entries = params.entries.map((e) => '${e.key}=${e.value}').join(',');
  return '$key($entries)';
}

void main() {
  const identity = ScheduleIdentityContext(
    houseId: 'house1',
    nameU1: 'Alex',
    nameU2: 'Sam',
    startDate: '2026-01-10',
    dobU1: '1998-03-20',
    dobU2: '1999-07-04',
  );

  ScheduleEventPresentation describe({
    required String id,
    required String eventKey,
    String title = '',
    String? date,
  }) =>
      describeScheduleNotification(
        notificationId: id,
        fallbackTitle: '',
        fallbackMessage: '',
        eventTitle: title,
        eventDate: date,
        eventKey: eventKey,
        identity: identity,
        text: _keyText,
      );

  test('mốc ngày yêu dùng eventKey, không cần câu tiếng Việt', () {
    final result = describe(
      id: 'sched_d0_abc',
      eventKey: 'sys:milestone:100:2026-04-20',
      title: '100-day love anniversary',
    );
    expect(result.eventType, 'love_day_milestone');
    expect(result.title, 'sched_milestone_title_d0(days=100)');
    expect(
      result.message,
      'sched_milestone_msg_d0(couple=sched_couple_names(a=Alex,b=Sam),days=100)',
    );
  });

  test('sinh nhật lấy đúng tên theo vai trò', () {
    final result = describe(
      id: 'sched_d1_abc',
      eventKey: 'sys:birthday:user2:2026-07-04',
    );
    expect(result.eventType, 'birthday');
    expect(result.title, 'sched_birthday_title_d1');
    expect(result.message, 'sched_birthday_msg_d1(name=Sam)');
  });

  test('nhắc trước 7 ngày không bị báo là "hôm nay sinh nhật"', () {
    final result = describe(
      id: 'sched_d0_abc',
      eventKey: 'sys:birthday:user1:pre7:2026-03-13',
    );
    expect(result.eventType, 'birthday_reminder');
    expect(result.title, 'sched_birthday_week_title(name=Alex)');
    expect(result.message, startsWith('sched_birthday_week_msg(name=Alex,gift=sched_gift_'));
  });

  test('sự kiện người dùng tạo giữ nguyên tên sự kiện', () {
    final result = describe(
      id: 'sched_d2_abc',
      eventKey: 'cust:-Nabc:2026-05-01',
      title: 'Trip to Da Lat',
    );
    expect(result.eventType, 'generic');
    expect(result.title, 'sched_title_d2');
    expect(result.message, 'sched_msg_d2(event=Trip to Da Lat)');
  });

  test('thông báo cũ tiếng Việt (không có eventKey) vẫn nhận diện được', () {
    final result = describeScheduleNotification(
      notificationId: 'sched_d3_legacy',
      fallbackTitle: '🎉 Sắp tới rồi!',
      fallbackMessage: '',
      eventTitle: 'Kỷ niệm 30 ngày yêu',
      identity: identity,
      text: _keyText,
    );
    expect(result.eventType, 'love_day_milestone');
    expect(result.title, 'sched_milestone_title_d3(days=30)');
  });

  test('tiêu đề mặc định theo số ngày còn lại', () {
    expect(scheduleGenericTitle(3, text: _keyText), 'sched_title_d3');
    expect(scheduleGenericTitle(0, text: _keyText), 'sched_title_d0');
    expect(
      scheduleGenericMessage(1, '', text: _keyText),
      'sched_msg_d1(event=sched_event_this)',
    );
  });
}
