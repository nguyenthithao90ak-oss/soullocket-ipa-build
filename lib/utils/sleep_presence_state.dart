import 'sleep_tracking_math.dart';

/// Transaction reducer: một tác vụ nền không được bật lại consent hoặc ghi đè manual.
Map<String, dynamic>? automatedSleepPresence(
  Map<String, dynamic> previous,
  Map<String, dynamic> values,
) {
  if (previous['sleep_tracking_enabled'] != true ||
      (previous['sleep_source'] == 'manual' && previous['sleep_mode'] == true))
    return null;
  return {...previous, ...values, 'sleep_tracking_enabled': true};
}

Map<String, dynamic> enabledSleepPresence(
  Map<String, dynamic> previous,
  bool enabled,
  Object timestamp,
) => {
  ...previous,
  'sleep_tracking_enabled': enabled,
  'sleep_mode': false,
  'sleep_status': 'unknown',
  'sleep_source': 'unknown',
  'sleep_start_time': 0,
  'sleep_record_start': 0,
  'sleep_record_end': 0,
  'sleep_record_duration': 0,
  'last_screen_off': 0,
  'last_screen_on': 0,
  'sleep_updated_at': timestamp,
};

Map<String, dynamic>? manualSleepPresence(
  Map<String, dynamic> previous,
  bool sleeping,
  int now,
  Object timestamp,
) {
  if (previous['sleep_tracking_enabled'] != true) return null;
  final active =
      previous['sleep_source'] == 'manual' && previous['sleep_mode'] == true;
  if (sleeping && active) return previous;
  final start = sleepEpoch(previous['sleep_start_time']);
  return {
    ...previous,
    'sleep_source': 'manual',
    'sleep_mode': sleeping,
    'sleep_status': sleeping ? 'sleeping' : 'awake',
    'sleep_start_time': sleeping ? now : 0,
    'sleep_updated_at': timestamp,
    if (!sleeping &&
        active &&
        start > 0 &&
        now > start &&
        now - start <= 86400000)
      'last_wake_time': now,
    if (!sleeping &&
        active &&
        start > 0 &&
        now > start &&
        now - start <= 86400000) ...{
      'sleep_record_start': start,
      'sleep_record_end': now,
      'sleep_record_duration': now - start,
      'sleep_record_source': 'manual',
    },
  };
}

/// Mốc sự kiện được giữ nguyên khi retry, không dùng giờ đồng bộ làm giờ ngủ/thức.
Map<String, dynamic> screenSleepPresence(
  Map<String, dynamic> previous, {
  required bool screenOn,
  required int at,
  required Object timestamp,
}) {
  final off = sleepEpoch(previous['last_screen_off']);
  final on = sleepEpoch(previous['last_screen_on']);
  if (at <= 0 || at <= on || at < off) return previous;
  if (!screenOn && off > on) return previous;
  final next = <String, dynamic>{
    ...previous,
    if (screenOn) 'last_screen_on': at else 'last_screen_off': at,
    'sleep_updated_at': timestamp,
  };
  // Sự kiện màn hình vẫn lưu được khi manual đang chạy, nhưng không ghi đè phiên đó.
  if (previous['sleep_source'] == 'manual' && previous['sleep_mode'] == true)
    return next;
  next['sleep_source'] = 'screen_estimate';
  if (screenOn) {
    final kind = androidSleepEstimate(
      previous,
      DateTime.fromMillisecondsSinceEpoch(at),
    );
    if (off > on && (kind == 'sleeping' || kind == 'noon_nap')) {
      next.addAll({
        'sleep_record_start': off,
        'sleep_record_end': at,
        'sleep_record_duration': at - off,
        'sleep_record_source': 'screen_estimate',
      });
    }
    next.addAll({
      'last_active': at,
      'sleep_mode': false,
      'sleep_status': 'awake',
      'sleep_start_time': 0,
    });
  } else {
    next.addAll({
      'sleep_mode': false,
      'sleep_status': 'unknown',
      'sleep_start_time': 0,
    });
  }
  return next;
}

Map<String, dynamic> tickScreenSleepPresence(
  Map<String, dynamic> previous,
  DateTime now,
) {
  if (previous['sleep_source'] == 'manual' && previous['sleep_mode'] == true)
    return previous;
  final state = androidSleepEstimate(previous, now);
  return {
    ...previous,
    'sleep_mode': state == 'sleeping' || state == 'noon_nap',
    'sleep_status': state,
    'sleep_start_time': state == 'sleeping' || state == 'noon_nap'
        ? sleepEpoch(previous['last_screen_off'])
        : 0,
    'sleep_source': 'screen_estimate',
    'sleep_updated_at': now.millisecondsSinceEpoch,
  };
}

SleepRecord? completedScreenSleep(Map<String, dynamic> p, int at) {
  final start = sleepEpoch(p['sleep_record_start']),
      end = sleepEpoch(p['sleep_record_end']);
  if (p['sleep_record_source'] != 'screen_estimate' ||
      end != at ||
      start <= 0 ||
      end <= start ||
      end - start > 50400000)
    return null;
  return SleepRecord(start, end, end - start);
}
