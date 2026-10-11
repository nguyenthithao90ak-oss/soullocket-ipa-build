import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/cycle_flower.dart';

/// Token trình bày; giữ màu giai đoạn đầu vào và dữ liệu chu kỳ hiện hữu.
@immutable
class HealthCyclePalette {
  const HealthCyclePalette._(this.dark);
  factory HealthCyclePalette.of(BuildContext context) =>
      HealthCyclePalette._(Theme.of(context).brightness == Brightness.dark);
  final bool dark;

  Color get surface => dark ? SLColors.darkBgCard : Colors.white;
  Color get onAccent => dark ? SLColors.darkBgMain : Colors.white;
  Color text(Color light) => dark ? SLColors.darkTextPrimary : light;
  Color secondary(Color light) => dark ? SLColors.darkTextSecond : light;
  Color accent(Color light) => dark ? const Color(0xFFE7ADC1) : light;
  Color soft(Color light) => dark
      ? Color.alphaBlend(light.withValues(alpha: .09), SLColors.darkBgCard)
      : light;
  Color border(Color light) => dark ? SLColors.darkBorder : light;
  List<Color> get canvas => dark
      ? const [SLColors.darkBgMain, Color(0xFF29212C)]
      : const [Color(0xFFFFFAF4), Color(0xFFFFEDF3)];
}

class HealthCycleHeader extends StatelessWidget {
  const HealthCycleHeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      children: [
        Text(
          context.tr('p3_health_header_tracking'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: HealthCyclePalette.of(
              context,
            ).secondary(const Color(0xFFAA5C79)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('p3_health_header_cycle'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w900,
            color: HealthCyclePalette.of(context).text(const Color(0xFF8E3657)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('p3_health_header_subtitle'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: HealthCyclePalette.of(
              context,
            ).secondary(const Color(0xFF815B69)),
          ),
        ),
      ],
    ),
  );
}

/// Trình bày dữ liệu đã tính; không tự suy ra thêm ngày hay khả năng thụ thai.
class HealthCycleDashboard extends StatelessWidget {
  const HealthCycleDashboard({
    super.key,
    required this.daysRemaining,
    required this.progress,
    required this.phase,
    required this.phaseColor,
    required this.fertility,
    this.cycleDay,
    this.cycleLength,
    this.expectedDate,
  });

  final int daysRemaining;
  final double progress;
  final String phase, fertility;
  final Color phaseColor;
  final int? cycleDay;
  final int? cycleLength;
  final String? expectedDate;

  @override
  Widget build(BuildContext context) {
    final days = daysRemaining == 0 ? context.tr('p3_today') : '$daysRemaining';
    final dayLabel = context.tr('p3_health_days_remaining');
    final safeProgress = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final fertilityLabel = L10nService().format('cycle_ui_fertility_estimate', {
      'value': fertility,
    });
    final cycleLabel = cycleDay != null && cycleLength != null
        ? L10nService().format('cycle_ui_day_in_cycle', {
            'day': cycleDay! + 1,
            'total': cycleLength!,
          })
        : null;
    final expectedLabel = expectedDate == null || expectedDate!.isEmpty
        ? null
        : L10nService().format('cycle_ui_expected_on', {'date': expectedDate!});
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(520.0, constraints.maxWidth);
        final ringDiameter = math.min(244.0, math.max(190.0, width - 116));
        final stroke = ringDiameter >= 220 ? 13.0 : 11.0;
        final inner = ringDiameter - stroke * 2 - 18;
        final duration = disableMotion
            ? Duration.zero
            : const Duration(milliseconds: 680);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: HealthCyclePalette.of(context).dark
                    ? [SLColors.darkBgCard, const Color(0xFF342731)]
                    : const [Color(0xFFFFFCFE), Color(0xFFFFF2F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: HealthCyclePalette.of(
                  context,
                ).border(const Color(0xFFF5D4E0)),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC45C7C).withValues(alpha: .10),
                  blurRadius: 24,
                  offset: const Offset(0, 11),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CycleFlower(width: 64, animated: !disableMotion),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('cycle_ui_until_next_period'),
                            style: SLTheme.quicksand(
                              color: HealthCyclePalette.of(
                                context,
                              ).text(const Color(0xFF813B58)),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('cycle_ui_estimate'),
                            style: SLTheme.quicksand(
                              color: HealthCyclePalette.of(
                                context,
                              ).secondary(const Color(0xFF986C7B)),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: HealthCyclePalette.of(
                          context,
                        ).soft(const Color(0xFFFFE6EF)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: HealthCyclePalette.of(
                          context,
                        ).accent(const Color(0xFFD64B78)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Semantics(
                  label:
                      '${context.tr('cycle_ui_until_next_period')}: $days ${daysRemaining == 0 ? '' : dayLabel}',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      key: const ValueKey('health-cycle-ring'),
                      width: ringDiameter,
                      height: ringDiameter,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.all(stroke / 2),
                              child: CircularProgressIndicator(
                                value: 1,
                                strokeWidth: stroke,
                                color: HealthCyclePalette.of(
                                  context,
                                ).soft(const Color(0xFFF4DCE6)),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.all(stroke / 2),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: safeProgress),
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) =>
                                    CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: stroke,
                                      strokeCap: StrokeCap.round,
                                      color: HealthCyclePalette.of(
                                        context,
                                      ).accent(const Color(0xFFD64B78)),
                                      backgroundColor: Colors.transparent,
                                    ),
                              ),
                            ),
                          ),
                          Container(
                            width: inner,
                            height: inner,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: HealthCyclePalette.of(context).surface,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFD81B60,
                                  ).withValues(alpha: .08),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: ringDiameter * .24,
                                  width: double.infinity,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      days,
                                      key: const ValueKey('health-cycle-days'),
                                      style: SLTheme.quicksand(
                                        color: HealthCyclePalette.of(
                                          context,
                                        ).accent(const Color(0xFFD13E6E)),
                                        fontWeight: FontWeight.w900,
                                        fontSize: daysRemaining == 0 ? 29 : 60,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                if (daysRemaining != 0)
                                  Flexible(
                                    child: Text(
                                      dayLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: SLTheme.quicksand(
                                        color: HealthCyclePalette.of(
                                          context,
                                        ).accent(const Color(0xFFD13E6E)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (cycleLabel != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    cycleLabel,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: HealthCyclePalette.of(
                        context,
                      ).secondary(const Color(0xFF9A6C7C)),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (expectedLabel != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    expectedLabel,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: HealthCyclePalette.of(
                        context,
                      ).secondary(const Color(0xFF9A6C7C)),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: HealthCyclePalette.of(context).dark
                        ? Color.alphaBlend(
                            phaseColor.withValues(alpha: .12),
                            SLColors.darkBgCard,
                          )
                        : phaseColor.withValues(alpha: .62),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: HealthCyclePalette.of(context).dark
                          ? SLColors.darkBorder
                          : phaseColor.withValues(alpha: .9),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.local_florist_rounded,
                        color: HealthCyclePalette.of(
                          context,
                        ).accent(const Color(0xFFD13E6E)),
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('cycle_ui_phase_title'),
                              style: SLTheme.quicksand(
                                color: HealthCyclePalette.of(
                                  context,
                                ).secondary(const Color(0xFF986C7B)),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              phase,
                              style: SLTheme.quicksand(
                                color: HealthCyclePalette.of(
                                  context,
                                ).text(const Color(0xFF7A3E56)),
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fertilityLabel,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: HealthCyclePalette.of(
                      context,
                    ).secondary(const Color(0xFF8C4662)),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
