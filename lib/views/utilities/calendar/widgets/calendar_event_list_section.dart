import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'calendar_event_state_card.dart';
import 'calendar_event_tile.dart';

class CalendarEventListSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final double horizontalInset;
  final bool compact;
  final Color accent;
  final String selectedDateLabel;
  final int itemCount;
  final String statusLabel;
  final String Function(int timestamp) formatCreatedTime;
  final ValueChanged<String> onDelete;

  const CalendarEventListSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.horizontalInset,
    required this.compact,
    required this.accent,
    required this.selectedDateLabel,
    required this.itemCount,
    required this.statusLabel,
    required this.formatCreatedTime,
    required this.onDelete,
  });

  static int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final sortedItems = List<Map<String, dynamic>>.from(items)
      ..sort(
        (a, b) => _parseTimestamp(a['ts']).compareTo(_parseTimestamp(b['ts'])),
      );

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 20),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 18,
          compact ? 16 : 18,
          compact ? 16 : 18,
          10,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFCFF), Color(0xFFF8FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE6EAF9)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 22,
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
                  width: compact ? 40 : 44,
                  height: compact ? 40 : 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.14),
                        accent.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(compact ? 14 : 15),
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
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
                        context.tr('calendar_scheduled_title'),
                        style: SLTheme.quicksand(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w900,
                          color: SLTheme.textMain,
                        ),
                      ),
                      SLSpacing.h4,
                      Text(
                        L10nService().format('calendar_scheduled_desc', {
                          'date': selectedDateLabel,
                        }),
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
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 9 : 10,
                    vertical: compact ? 7 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    L10nService().format('calendar_item_count', {
                      'count': itemCount,
                    }),
                    style: SLTheme.quicksand(
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 16),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(color: accent)),
              )
            else if (errorMessage != null && errorMessage!.trim().isNotEmpty)
              CalendarEventStateCard(
                icon: Icons.cloud_off_rounded,
                title: context.tr('calendar_load_error_title'),
                description: L10nService().format('calendar_load_error_desc', {
                  'error': errorMessage!,
                }),
                color: const Color(0xFFE46A7A),
                actionLabel: context.tr('calendar_retry_load'),
                onAction: onRetry,
              )
            else if (sortedItems.isEmpty)
              CalendarEventStateCard(
                icon: Icons.event_available_rounded,
                title: context.tr('calendar_empty_day_title'),
                description: context.tr('calendar_empty_day_desc'),
                color: accent,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 10),
                itemCount: sortedItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = sortedItems[index];
                  final eventKey = item['key']?.toString() ?? '';
                  return CalendarEventTile(
                    accent: accent,
                    title: item['title']?.toString().trim() ?? '',
                    author: item['author']?.toString().trim(),
                    timestampLabel: formatCreatedTime(
                      _parseTimestamp(item['ts']),
                    ),
                    index: index,
                    statusLabel: statusLabel,
                    onDelete: eventKey.isEmpty
                        ? null
                        : () => onDelete(eventKey),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
