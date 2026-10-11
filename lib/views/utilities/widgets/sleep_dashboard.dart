import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import 'sleep_status_card.dart';

const sleepInk = Color(0xFF25283F);
const sleepAccent = Color(0xFF686EAA);
const sleepCanvas = Color(0xFFF4F5F9);

class SleepDashboardHeader extends StatelessWidget {
  const SleepDashboardHeader({super.key, this.now});
  final DateTime? now;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.nights_stay_rounded,
          color: sleepAccent,
          size: 30,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('sleep_dashboard_title'),
              style: SLTheme.quicksand(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: sleepInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LocaleDateFormat.date(now ?? DateTime.now()),
              style: const TextStyle(color: Color(0xFF72778C), height: 1.4),
            ),
          ],
        ),
      ),
    ],
  );
}

class SleepTrackingPanel extends StatelessWidget {
  const SleepTrackingPanel({
    super.key,
    required this.enabled,
    required this.busy,
    required this.supported,
    required this.ios,
    required this.manualActive,
    this.serviceReady = true,
    required this.onToggle,
    required this.onManual,
    this.error,
  });
  final bool enabled, busy, supported, ios, manualActive, serviceReady;
  final VoidCallback? onToggle, onManual;
  final String? error;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                context.tr('sleep_tracking_title'),
                style: SLTheme.quicksand(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: sleepInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              toggled: enabled,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  enabled
                      ? Icons.check_circle_rounded
                      : Icons.power_settings_new_rounded,
                  color: enabled
                      ? const Color(0xFF467E74)
                      : const Color(0xFF8B90A4),
                  size: 28,
                ),
              ),
            ),
          ],
        ),
        Text(
          context.tr(
            !enabled
                ? 'sleep_state_disabled'
                : serviceReady
                ? 'sleep_tracking_on'
                : 'sleep_tracking_restarting',
          ),
          style: TextStyle(
            color: enabled && serviceReady
                ? const Color(0xFF467E74)
                : const Color(0xFF72778C),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (supported)
          _SleepMethodExplanation(
            icon: ios
                ? Icons.favorite_outline_rounded
                : Icons.phone_android_rounded,
            title: context.tr(
              ios
                  ? 'sleep_tracking_method_ios'
                  : 'sleep_tracking_method_android',
            ),
            description: context.tr(
              ios ? 'sleep_tracking_info_ios' : 'sleep_tracking_info_android',
            ),
          )
        else
          Text(
            context.tr('sleep_tracking_mobile_only'),
            style: const TextStyle(color: Color(0xFF62697F), height: 1.5),
          ),
        if (error != null) ...[
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              key: const ValueKey('sleep-tracking-error'),
              style: const TextStyle(color: Color(0xFFAB4D53), height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('sleep-tracking-toggle'),
          style: FilledButton.styleFrom(
            backgroundColor: sleepAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: busy || !supported ? null : onToggle,
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  enabled
                      ? Icons.pause_rounded
                      : Icons.power_settings_new_rounded,
                ),
          label: Text(
            context.tr(
              busy
                  ? 'sleep_tracking_processing'
                  : enabled
                  ? 'sleep_tracking_disable'
                  : 'sleep_tracking_enable',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (supported) ...[
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFE8EAF2)),
          const SizedBox(height: 20),
          _SleepMethodExplanation(
            icon: Icons.bedtime_outlined,
            title: context.tr('sleep_tracking_manual_title'),
            description: context.tr('sleep_tracking_manual_hint'),
          ),
        ],
        if (enabled && supported) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('sleep-manual-toggle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: sleepAccent,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              side: const BorderSide(color: Color(0xFFD9DCED)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: busy ? null : onManual,
            icon: Icon(
              manualActive ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
            ),
            label: Text(
              context.tr(
                manualActive ? 'sleep_manual_stop' : 'sleep_manual_start',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    ),
  );
}

class _SleepMethodExplanation extends StatelessWidget {
  const _SleepMethodExplanation({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title, description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: sleepCanvas,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: sleepAccent, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: sleepInk,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF62697F),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class SleepWeekCard extends StatelessWidget {
  const SleepWeekCard({super.key, required this.week, required this.now});
  final Map<int, double> week;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final recorded = week.values.where((v) => v.isFinite && v > 0).toList();
    final average = recorded.isEmpty
        ? 0
        : recorded.reduce((a, b) => a + b) / recorded.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('sleep_week_title'),
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: sleepInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recorded.isEmpty
                ? context.tr('sleep_week_empty')
                : sleepDurationText((average * 3600000).round()),
            style: TextStyle(
              fontSize: recorded.isEmpty ? 13 : 22,
              color: sleepAccent,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (recorded.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.tr('sleep_week_average'),
                style: const TextStyle(
                  color: Color(0xFF72778C),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 6; i >= 0; i--)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Semantics(
                      label: DateFormat(
                        'dd/MM/yyyy',
                      ).format(DateTime(now.year, now.month, now.day - i)),
                      value: sleepDurationText(
                        ((week[i] ?? 0) * 3600000).round(),
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                (week[i] ?? 0) > 0
                                    ? week[i]!.toStringAsFixed(1)
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: sleepInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 92,
                              width: 22,
                              alignment: Alignment.bottomCenter,
                              decoration: BoxDecoration(
                                color: sleepCanvas,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                height: ((week[i] ?? 0) / 12 * 92).clamp(
                                  0.0,
                                  92.0,
                                ),
                                width: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: i == 0
                                        ? [sleepAccent, const Color(0xFF989FCB)]
                                        : [
                                            const Color(0xFFB2B7D6),
                                            const Color(0xFFD3D7EB),
                                          ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                DateFormat('E').format(
                                  DateTime(now.year, now.month, now.day - i),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: i == 0
                                      ? sleepAccent
                                      : const Color(0xFF72778C),
                                  fontWeight: i == 0
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
