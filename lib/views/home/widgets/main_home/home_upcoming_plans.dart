import 'package:flutter/material.dart';
import 'package:soullocket_app/models/home_calendar_plan.dart';
import 'package:soullocket_app/utils/calendar/calendar_civil_date.dart';
import 'package:soullocket_app/utils/calendar/calendar_display_format.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/utilities/widgets/keepsake_design.dart';

/// Nhận snapshot/callback từ Home; không tự mở listener hoặc tải media.
class HomeUpcomingPlans extends StatelessWidget {
  const HomeUpcomingPlans({
    super.key,
    required this.plans,
    required this.loadState,
    required this.displayFormat,
    required this.onOpenPlan,
    required this.onRetry,
    this.use24HourFormat,
  });

  final List<HomeCalendarPlan> plans;
  final HomeCalendarLoadState loadState;
  final CalendarDisplayFormat displayFormat;
  final bool? use24HourFormat;
  final ValueChanged<HomeCalendarPlan> onOpenPlan;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          context.tr('home_upcoming_title'),
          style: KeepsakeStyle.text(context, size: 13, weight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 10),
      if (plans.isNotEmpty)
        for (final plan in plans.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PlanRow(
              key: ValueKey('home-plan-${plan.identity}'),
              plan: plan,
              displayFormat: displayFormat,
              use24HourFormat: use24HourFormat,
              onTap: () => onOpenPlan(plan),
            ),
          )
      else if (loadState == HomeCalendarLoadState.loading)
        Semantics(
          label: context.tr('home_upcoming_loading'),
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KeepsakeStyle.accentSurface(
                  context,
                ).withValues(alpha: .45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 18,
                    color: KeepsakeStyle.muted(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('home_upcoming_loading'),
                      style: KeepsakeStyle.text(
                        context,
                        size: 12,
                        color: KeepsakeStyle.muted(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      else if (loadState == HomeCalendarLoadState.ready)
        Text(
          context.tr('home_upcoming_empty'),
          style: KeepsakeStyle.text(
            context,
            size: 12,
            color: KeepsakeStyle.muted(context),
          ),
        ),
      if (loadState == HomeCalendarLoadState.failed) ...[
        const SizedBox(height: 4),
        Text(
          context.tr(
            plans.isEmpty
                ? 'home_upcoming_error'
                : 'home_upcoming_cached_error',
          ),
          style: KeepsakeStyle.text(
            context,
            size: 12,
            color: KeepsakeStyle.muted(context),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.tr('core_retry')),
            style: TextButton.styleFrom(
              foregroundColor: KeepsakeStyle.accent(context),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
      ],
    ],
  );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    super.key,
    required this.plan,
    required this.displayFormat,
    required this.use24HourFormat,
    required this.onTap,
  });

  final HomeCalendarPlan plan;
  final CalendarDisplayFormat displayFormat;
  final bool? use24HourFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = CalendarCivilDate.parse(plan.dateKey)!;
    final timing = plan.timing;
    final when = timing == null
        ? '${displayFormat.shortDate(date)} · ${context.tr('calendar_all_day')}'
        : '${displayFormat.shortDate(date)} · ${displayFormat.time(timing.start, alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context), use24HourFormat: use24HourFormat)} · ${timing.timeZoneId}';
    return Semantics(
      button: true,
      label: '${plan.title}, $when',
      onTap: onTap,
      excludeSemantics: true,
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(color: KeepsakeStyle.line(context)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.event_outlined,
                      size: 19,
                      color: KeepsakeStyle.accent(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KeepsakeStyle.text(
                            context,
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          when,
                          style: KeepsakeStyle.text(
                            context,
                            size: 11,
                            color: KeepsakeStyle.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: KeepsakeStyle.muted(context),
                    textDirection: Directionality.of(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
