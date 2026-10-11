import 'dart:convert';
import 'sleep_presence_state.dart';
import 'sleep_tracking_math.dart';

class SleepScreenEvent {
  const SleepScreenEvent(this.at, this.screenOn);
  final int at;
  final bool screenOn;
  Map<String, Object> toMap() => {'at': at, 'on': screenOn};
}

/// Lưu sự kiện trước khi ghi mạng. Journal chỉ thuộc một UID/House/role.
class SleepScreenJournal {
  SleepScreenJournal(this.scope);
  final String scope;
  final events = <SleepScreenEvent>[];
  Map<String, dynamic> presence = {'sleep_tracking_enabled': true};

  factory SleepScreenJournal.read(String scope, String? json) {
    final journal = SleepScreenJournal(scope);
    try {
      final data = jsonDecode(json ?? '{}');
      if (data is! Map || data['scope'] != scope) return journal;
      if (data['presence'] is Map)
        journal.presence = Map<String, dynamic>.from(data['presence']);
      final raw = data['events'];
      if (raw is List)
        for (final e in raw.whereType<Map>()) {
          final at = sleepEpoch(e['at']);
          if (at > 0 && e['on'] is bool)
            journal.events.add(SleepScreenEvent(at, e['on'] as bool));
        }
    } catch (_) {
      /* Cache hỏng không tạo dữ liệu ngủ giả. */
    }
    return journal;
  }

  void observe(SleepScreenEvent event) {
    final next = screenSleepPresence(
      presence,
      screenOn: event.screenOn,
      at: event.at,
      timestamp: event.at,
    );
    if (identical(next, presence)) return;
    presence = next;
    events.add(event);
    // Giới hạn cache; giữ sự kiện gần nhất để không tăng bộ nhớ vô hạn khi offline.
    if (events.length > 128) events.removeRange(0, events.length - 128);
  }

  void acknowledge(SleepScreenEvent event) {
    events.removeWhere((e) => e.at == event.at && e.screenOn == event.screenOn);
  }

  String encode() => jsonEncode({
    'scope': scope,
    'presence': presence,
    'events': [for (final e in events) e.toMap()],
  });
}
