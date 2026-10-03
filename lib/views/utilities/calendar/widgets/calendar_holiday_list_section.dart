import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/calendar/holiday_occurrence_resolver.dart';
import 'package:soullocket_app/utils/services/holiday_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'calendar_design.dart';

/// Lớp lễ đọc riêng. Không có callback sửa/xóa kế hoạch của House.
class CalendarHolidayListSection extends StatelessWidget {
  const CalendarHolidayListSection({
    super.key,
    required this.occurrences,
    required this.horizontalInset,
  });

  final List<HolidayOccurrence> occurrences;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset + 4, 12, horizontalInset + 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('calendar_holidays_title'),
            style: CalendarDesign.text(context, size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('calendar_holidays_selected_packs'),
            style: CalendarDesign.text(context, size: 12, color: CalendarDesign.muted(context)),
          ),
          for (final occurrence in occurrences)
            Padding(
              key: ValueKey(occurrence.occurrenceId),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.star_outline_rounded, size: 22, color: CalendarDesign.holidayAccent(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      HolidayService.getLocalizedName(occurrence.holiday),
                      style: CalendarDesign.text(context, size: 14, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
