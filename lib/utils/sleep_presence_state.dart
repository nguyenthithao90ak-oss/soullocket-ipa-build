import 'sleep_tracking_math.dart';

/// Transaction reducer: một tác vụ nền không được bật lại consent hoặc ghi đè manual.
Map<String, dynamic>? automatedSleepPresence(Map<String, dynamic> previous, Map<String, dynamic> values) {
  if (previous['sleep_tracking_enabled'] != true ||
      (previous['sleep_source'] == 'manual' && previous['sleep_mode'] == true)) return null;
  return {...previous, ...values, 'sleep_tracking_enabled': true};
}

Map<String, dynamic> enabledSleepPresence(Map<String, dynamic> previous, bool enabled, Object timestamp) => {
  ...previous,
  'sleep_tracking_enabled': enabled,
  'sleep_mode': false,
  'sleep_status': 'unknown',
  'sleep_source': 'unknown',
  'sleep_start_time': 0,
  'sleep_record_start': 0,
  'sleep_record_end': 0,
  'sleep_record_duration': 0,
  'sleep_updated_at': timestamp,
};

Map<String, dynamic>? manualSleepPresence(Map<String, dynamic> previous, bool sleeping, int now, Object timestamp) {
  if (previous['sleep_tracking_enabled'] != true) return null;
  final active = previous['sleep_source'] == 'manual' && previous['sleep_mode'] == true;
  if (sleeping && active) return previous;
  final start = sleepEpoch(previous['sleep_start_time']);
  return {
    ...previous,
    'sleep_source': 'manual',
    'sleep_mode': sleeping,
    'sleep_status': sleeping ? 'sleeping' : 'awake',
    'sleep_start_time': sleeping ? now : 0,
    'sleep_updated_at': timestamp,
    if (!sleeping && active && start > 0 && now > start && now - start <= 86400000)
      'last_wake_time': now,
  };
}
