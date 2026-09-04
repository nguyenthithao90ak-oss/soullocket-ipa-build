import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'calendar_info_pill.dart';

class CalendarEventInputPanel extends StatelessWidget {
  final double horizontalInset;
  final bool compact;
  final Color accent;
  final int eventCount;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final bool isSaving;

  const CalendarEventInputPanel({
    super.key,
    required this.horizontalInset,
    required this.compact,
    required this.accent,
    required this.eventCount,
    required this.controller,
    required this.onAdd,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Container(
        padding: EdgeInsets.all(compact ? 16 : 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF9FCFF), Color(0xFFF7F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6EAF9)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 42 : 46,
                  height: compact ? 42 : 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        accent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(compact ? 14 : 16),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: accent,
                    size: compact ? 20 : 22,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('calendar_add_plan_title'),
                        style: SLTheme.quicksand(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w900,
                          color: SLTheme.textMain,
                        ),
                      ),
                      SLSpacing.h4,
                      Text(
                        context.tr('calendar_add_plan_desc'),
                        style: SLTheme.quicksand(
                          fontSize: compact ? 11.5 : 12,
                          fontWeight: FontWeight.w700,
                          color: SLTheme.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE9D8D3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                style: SLTheme.quicksand(
                  color: SLTheme.textMain,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('calendar_plan_hint'),
                  hintStyle: SLTheme.quicksand(
                    color: SLTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CalendarInfoPill(
                  icon: Icons.notifications_none_rounded,
                  label: context.tr('calendar_remind_one_day_before'),
                  accent: accent,
                  compact: compact,
                ),
                CalendarInfoPill(
                  icon: Icons.schedule_rounded,
                  label: L10nService().format('calendar_items_in_day', {
                    'count': eventCount,
                  }),
                  accent: accent,
                  compact: compact,
                ),
                CalendarInfoPill(
                  icon: Icons.favorite_outline_rounded,
                  label: context.tr('calendar_lovely_note'),
                  accent: accent,
                  compact: compact,
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withValues(alpha: 0.5),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: compact ? 13 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.add_task_rounded, size: 20),
                label: Text(
                  isSaving
                      ? context.tr('calendar_saving_plan')
                      : context.tr('calendar_add_to_shared'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 13 : 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
