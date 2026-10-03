import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

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
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9B5570),
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
            color: const Color(0xFF893653),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('p3_health_header_subtitle'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF815B69),
          ),
        ),
      ],
    ),
  );
}

/// Chỉ trình bày dữ liệu đã tính; không suy ra thêm ngày/khả năng thụ thai.
class HealthCycleDashboard extends StatelessWidget {
  const HealthCycleDashboard({
    super.key,
    required this.daysRemaining,
    required this.progress,
    required this.phase,
    required this.phaseColor,
    required this.fertility,
  });

  final int daysRemaining;
  final double progress;
  final String phase, fertility;
  final Color phaseColor;

  @override
  Widget build(BuildContext context) {
    final days = daysRemaining == 0 ? context.tr('p3_today') : '$daysRemaining';
    final dayLabel = context.tr('p3_health_days_remaining');
    final phaseLabel = L10nService().format('p3_health_phase_label', {
      'value': phase,
    });
    final fertilityLabel = L10nService().format('p3_health_fertility_label', {
      'value': fertility,
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(310.0, constraints.maxWidth - 40);
        final stroke = diameter >= 280 ? 15.0 : 12.0;
        final inner = diameter - stroke * 2 - 16;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.tr('p3_health_expected_date'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: const Color(0xFF7A5362),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '${context.tr('p3_health_expected_date')}: $days '
                  '${daysRemaining == 0 ? '' : dayLabel}',
              child: ExcludeSemantics(
                child: SizedBox(
                  key: const ValueKey('health-cycle-ring'),
                  width: diameter,
                  height: diameter,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.all(stroke / 2),
                          child: CircularProgressIndicator(
                            value: 1,
                            strokeWidth: stroke,
                            color: const Color(0xFFF5DCE6),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.all(stroke / 2),
                          child: CircularProgressIndicator(
                            value: progress.isFinite
                                ? progress.clamp(0.0, 1.0)
                                : 0,
                            strokeWidth: stroke,
                            strokeCap: StrokeCap.round,
                            color: const Color(0xFFD64B78),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      Container(
                        width: inner,
                        height: inner,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFD81B60,
                              ).withValues(alpha: .08),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: diameter * .28,
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  days,
                                  key: const ValueKey('health-cycle-days'),
                                  style: SLTheme.quicksand(
                                    color: const Color(0xFFD13E6E),
                                    fontWeight: FontWeight.w900,
                                    fontSize: daysRemaining == 0 ? 30 : 64,
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
                                    color: const Color(0xFFD13E6E),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    height: 1.2,
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
            const SizedBox(height: 14),
            Container(
              constraints: BoxConstraints(maxWidth: diameter),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF5D7E2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: phaseColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_florist_outlined,
                      color: Color(0xFFD13E6E),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      phaseLabel,
                      style: SLTheme.quicksand(
                        color: const Color(0xFF7A3E56),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                fertilityLabel,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: const Color(0xFF8C4662),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
