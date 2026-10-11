import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/sleep_tracking_math.dart';
import '../../../utils/services/l10n_service.dart';

String sleepStateKey(String state) => switch (state) {
  'manual' => 'sleep_state_manual',
  'estimated' => 'sleep_state_estimated',
  'recorded' => 'sleep_state_recorded',
  'disabled' => 'sleep_state_disabled',
  'active' => 'p3_sleep_active',
  'inactive' => 'p3_sleep_offline',
  _ => 'sleep_state_unknown',
};
String sleepSourceLabel(String source) => source == 'healthkit'
    ? 'Apple Health'
    : L10nService().translate(
        source == 'manual'
            ? 'sleep_source_manual'
            : source == 'screen_estimate'
            ? 'sleep_source_estimate'
            : 'sleep_sync_hint',
      );
String sleepDurationText(int duration) => L10nService().format(
  'sleep_duration',
  {'hours': duration ~/ 3600000, 'minutes': duration ~/ 60000 % 60},
);
String sleepPersonDetail(SleepPersonSnapshot p, DateTime now) {
  if (p.state == 'recorded') {
    final start = LocaleDateFormat.dayMonthTime(
      DateTime.fromMillisecondsSinceEpoch(p.start),
    );
    final end = LocaleDateFormat.dayMonthTime(
      DateTime.fromMillisecondsSinceEpoch(p.end),
    );
    return '${sleepDurationText(p.duration)} · $start → $end';
  }
  if (p.state == 'manual' || p.state == 'estimated') {
    final startedAt = L10nService().format('p3_sleep_started_at', {
      'time': LocaleDateFormat.timeFormat().format(
        DateTime.fromMillisecondsSinceEpoch(p.start),
      ),
    });
    return '$startedAt · ${sleepDurationText(now.millisecondsSinceEpoch - p.start)}';
  }
  if (p.screenOff > p.screenOn && p.screenOff > 0) {
    return L10nService().format('sleep_screen_off_at', {
      'time': LocaleDateFormat.timeFormat().format(
        DateTime.fromMillisecondsSinceEpoch(p.screenOff),
      ),
    });
  }
  return L10nService().translate('sleep_sync_hint');
}

class SleepStatusCard extends StatelessWidget {
  const SleepStatusCard({
    super.key,
    required this.name,
    required this.person,
    required this.now,
    required this.avatarKey,
    this.isOwn = false,
  });
  final String name, avatarKey;
  final SleepPersonSnapshot person;
  final DateTime now;

  /// Thẻ của chính máy này; nhãn "trên điện thoại này" không dùng cho người ấy.
  final bool isOwn;
  @override
  Widget build(BuildContext context) {
    final night = avatarKey == 'warm';
    final ink = night ? const Color(0xFFFAF8FF) : const Color(0xFF353953);
    final muted = night ? const Color(0xFFC8CCE3) : const Color(0xFF737A95);
    final active =
        person.state == 'recorded' ||
        person.state == 'manual' ||
        person.state == 'estimated';
    final disabled = person.state == 'disabled';
    final stateLabelKey =
        isOwn && person.state == 'unknown' && person.trackingEnabled
        ? 'sleep_tracking_on'
        : sleepStateKey(person.state);
    final pendingScreenOff =
        person.screenOff > person.screenOn && person.screenOff > 0;
    // Chỉ máy này biết có sự kiện chưa đồng bộ; thẻ người ấy hiện nguồn dữ liệu.
    final pillText = isOwn && pendingScreenOff && !active
        ? context.tr('sleep_sync_pending')
        : person.source != 'unknown'
        ? sleepSourceLabel(person.source)
        : null;
    final duration = person.state == 'recorded'
        ? person.duration
        : (now.millisecondsSinceEpoch - person.start).clamp(0, 86400000);
    final recordedStart = LocaleDateFormat.dayMonthTime(
      DateTime.fromMillisecondsSinceEpoch(person.start),
    );
    final recordedEnd = LocaleDateFormat.dayMonthTime(
      DateTime.fromMillisecondsSinceEpoch(person.end),
    );
    final detail = person.state == 'recorded'
        ? '$recordedStart → $recordedEnd'
        : person.state == 'manual' || person.state == 'estimated'
        ? L10nService().format('p3_sleep_started_at', {
            'time': LocaleDateFormat.timeFormat().format(
              DateTime.fromMillisecondsSinceEpoch(person.start),
            ),
          })
        : pendingScreenOff
        ? L10nService().format('sleep_screen_off_at', {
            'time': LocaleDateFormat.timeFormat().format(
              DateTime.fromMillisecondsSinceEpoch(person.screenOff),
            ),
          })
        : L10nService().translate('sleep_sync_hint');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: night
              ? [const Color(0xFF303650), const Color(0xFF4B5275)]
              : [const Color(0xFFEAEDF8), const Color(0xFFF0EEF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 56,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F2E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SvgPicture.asset(
                  'assets/images/widget_stickers/avatar_$avatarKey.svg',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                active ? Icons.bedtime_rounded : Icons.cloud_outlined,
                color: muted,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(stateLabelKey),
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          // Người chưa bật theo dõi: nhãn trạng thái là đủ, không hiện "đang chờ".
          if (!disabled) ...[
            const SizedBox(height: 8),
            Text(
              active
                  ? sleepDurationText(duration)
                  : person.screenOff > person.screenOn
                  ? context.tr('sleep_state_estimated')
                  : context.tr('sleep_sync_hint'),
              style: SLTheme.quicksand(
                fontSize: active ? 25 : 14,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ],
          if (active || pendingScreenOff)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: person.state == 'recorded'
                  ? Semantics(
                      label: detail,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 7,
                        runSpacing: 4,
                        children: [
                          Icon(Icons.bedtime_rounded, color: muted, size: 14),
                          Text(
                            recordedStart,
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            key: const ValueKey('sleep-recorded-time-arrow'),
                            color: muted,
                            size: 16,
                          ),
                          Icon(Icons.wb_sunny_rounded, color: muted, size: 14),
                          Text(
                            recordedEnd,
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      detail,
                      style: TextStyle(color: muted, fontSize: 12, height: 1.4),
                    ),
            ),
          // Không lặp lại câu "đang chờ" khi chưa có nguồn dữ liệu.
          if (!disabled && pillText != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: night
                      ? Colors.white.withValues(alpha: .08)
                      : Colors.white.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pillText,
                  style: TextStyle(color: muted, fontSize: 11, height: 1.4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
