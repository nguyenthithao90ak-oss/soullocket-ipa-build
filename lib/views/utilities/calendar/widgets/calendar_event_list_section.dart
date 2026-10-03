import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'calendar_design.dart';
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
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(items)
      ..sort(
        (a, b) => _parseTimestamp(a['ts']).compareTo(_parseTimestamp(b['ts'])),
      );
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 12, horizontalInset, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(
                  color: CalendarDesign.primary(context),
                ),
              ),
            )
          else if (errorMessage?.trim().isNotEmpty == true)
            CalendarEventStateCard(
              icon: Icons.cloud_off_rounded,
              title: context.tr('calendar_load_error_title'),
              description: context.tr('calendar_sync_error_desc'),
              color: CalendarDesign.primary(context),
              actionLabel: context.tr('calendar_retry_load'),
              onAction: onRetry,
            )
          else if (sorted.isEmpty)
            CalendarEventStateCard(
              icon: Icons.event_available_rounded,
              title: context.tr('calendar_empty_day_title'),
              description: context.tr('calendar_empty_day_desc'),
              color: CalendarDesign.primary(context),
            ),
          // Nếu tải lại bị lỗi, vẫn giữ các kế hoạch đã nhận trước đó.
          if (!isLoading)
            for (var index = 0; index < sorted.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              CalendarEventTile(
                accent: accent,
                title: sorted[index]['title']?.toString().trim() ?? '',
                author: sorted[index]['author']?.toString().trim(),
                timestampLabel: formatCreatedTime(
                  _parseTimestamp(sorted[index]['ts']),
                ),
                index: index,
                statusLabel: statusLabel,
                onDelete: sorted[index]['key']?.toString().isNotEmpty == true
                    ? () => onDelete(sorted[index]['key'].toString())
                    : null,
              ),
            ],
        ],
      ),
    );
  }
}
