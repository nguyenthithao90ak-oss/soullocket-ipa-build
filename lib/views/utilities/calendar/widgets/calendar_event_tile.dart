import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'calendar_design.dart';

class CalendarEventTile extends StatelessWidget {
  final Color accent;
  final String title;
  final String? author;
  final String timestampLabel;
  final int index;
  final String statusLabel;
  final VoidCallback? onDelete;

  const CalendarEventTile({
    super.key,
    required this.accent,
    required this.title,
    required this.author,
    required this.timestampLabel,
    required this.index,
    required this.statusLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
    decoration: BoxDecoration(
      color: CalendarDesign.surface(context),
      border: Border.all(color: CalendarDesign.border(context)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            Icons.event_note_rounded,
            size: 21,
            color: CalendarDesign.primary(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? context.tr('calendar_plan_no_content') : title,
                style: CalendarDesign.text(
                  context,
                  size: 16,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                author?.isNotEmpty == true
                    ? L10nService().format('calendar_created_by', {
                        'name': author!,
                      })
                    : context.tr('calendar_unknown_creator'),
                style: CalendarDesign.text(
                  context,
                  size: 12,
                  color: CalendarDesign.muted(context),
                ),
              ),
              Text(
                timestampLabel,
                style: CalendarDesign.text(
                  context,
                  size: 12,
                  color: CalendarDesign.muted(context),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: context.tr('p3_delete'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 21,
            color: CalendarDesign.muted(context),
          ),
        ),
      ],
    ),
  );
}
