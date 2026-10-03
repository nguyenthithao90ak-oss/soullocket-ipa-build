import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'calendar_design.dart';

class CalendarSelectedDaySummary extends StatelessWidget {
  final double horizontalInset;
  final bool compact;
  final Color accent;
  final IconData leadingIcon;
  final String displayDate;
  final String description;
  final String badgeLabel;
  final String shortDateLabel;
  final int eventCount;
  final int holidayCount;
  final String? secondaryDateLabel;

  const CalendarSelectedDaySummary({
    super.key,
    required this.horizontalInset,
    required this.compact,
    required this.accent,
    required this.leadingIcon,
    required this.displayDate,
    required this.description,
    required this.badgeLabel,
    required this.shortDateLabel,
    required this.eventCount,
    this.holidayCount = 0,
    this.secondaryDateLabel,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalInset + 4),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                badgeLabel,
                style: CalendarDesign.text(
                  context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: CalendarDesign.primary(context),
                ),
              ),
              Text(
                L10nService().format('calendar_plan_count', {
                  'count': eventCount,
                }),
                style: CalendarDesign.text(
                  context,
                  size: 13,
                  color: CalendarDesign.muted(context),
                ),
              ),
              if (holidayCount > 0)
                Text(
                  L10nService().format('calendar_holiday_count', {
                    'count': holidayCount,
                  }),
                  style: CalendarDesign.text(
                    context,
                    size: 13,
                    color: CalendarDesign.holidayAccent(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            displayDate,
            style: CalendarDesign.text(
              context,
              size: 19,
              weight: FontWeight.w700,
            ),
          ),
          if (secondaryDateLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              secondaryDateLabel!,
              style: CalendarDesign.text(
                context,
                size: 12,
                color: CalendarDesign.muted(context),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
