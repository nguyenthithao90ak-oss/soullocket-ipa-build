import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
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
  if (p.state == 'recorded')
    return sleepDurationText(p.duration) +
        ' · ' +
        DateFormat(
          'dd/MM HH:mm',
        ).format(DateTime.fromMillisecondsSinceEpoch(p.end));
  if (p.state == 'manual' || p.state == 'estimated')
    return L10nService().format('p3_sleep_started_at', {
          'time': DateFormat(
            'HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(p.start)),
        }) +
        ' · ' +
        sleepDurationText(now.millisecondsSinceEpoch - p.start);
  return L10nService().translate('sleep_sync_hint');
}

class SleepStatusCard extends StatelessWidget {
  const SleepStatusCard({
    super.key,
    required this.name,
    required this.person,
    required this.now,
    required this.avatarKey,
  });
  final String name, avatarKey;
  final SleepPersonSnapshot person;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final night = avatarKey == 'warm';
    final ink = night ? const Color(0xFFFAF8FF) : const Color(0xFF353953);
    final muted = night ? const Color(0xFFC8CCE3) : const Color(0xFF737A95);
    final active =
        person.state == 'recorded' ||
        person.state == 'manual' ||
        person.state == 'estimated';
    final duration = person.state == 'recorded'
        ? person.duration
        : (now.millisecondsSinceEpoch - person.start).clamp(0, 86400000);
    final detail = person.state == 'recorded'
          ? DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(person.end))
        : L10nService().format('p3_sleep_started_at', {
            'time': DateFormat(
              'HH:mm',
            ).format(DateTime.fromMillisecondsSinceEpoch(person.start)),
          });
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
            context.tr(sleepStateKey(person.state)),
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? sleepDurationText(duration)
                : context.tr('sleep_sync_hint'),
            style: SLTheme.quicksand(
              fontSize: active ? 25 : 14,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                detail,
                style: TextStyle(color: muted, fontSize: 12, height: 1.4),
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: night
                    ? Colors.white.withValues(alpha: .08)
                    : Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                sleepSourceLabel(person.source),
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
