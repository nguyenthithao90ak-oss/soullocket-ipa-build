import 'dart:ui' as ui;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/sl_theme.dart';

import 'calendar_event_state_card.dart';
import 'calendar_event_tile.dart';

class CalendarEventListSection extends StatelessWidget {
  final Stream<DatabaseEvent> stream;
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
    required this.stream,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 18,
              compact ? 16 : 18,
              compact ? 16 : 18,
              10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.74),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
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
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(compact ? 14 : 15),
                      ),
                      child: Icon(
                        Icons.view_timeline_rounded,
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
                            'Chi tiết trong ngày',
                            style: SLTheme.quicksand(
                              fontSize: compact ? 15 : 16,
                              fontWeight: FontWeight.w900,
                              color: SLTheme.textMain,
                            ),
                          ),
                          SLSpacing.h4,
                          Text(
                            'Toàn bộ kế hoạch cho $selectedDateLabel sẽ hiển thị ở đây theo thứ tự tạo.',
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
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$itemCount mục',
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
                StreamBuilder<DatabaseEvent>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: CircularProgressIndicator(color: accent),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return CalendarEventStateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Không tải được lịch của ngày này',
                        description: '${snapshot.error}',
                        color: const Color(0xFFE46A7A),
                      );
                    }

                    if (!snapshot.hasData ||
                        snapshot.data?.snapshot.value == null) {
                      return CalendarEventStateCard(
                        icon: Icons.event_busy_rounded,
                        title: 'Ngày này chưa có kế hoạch nào',
                        description:
                            'Thử thêm một lịch hẹn, việc cần làm hoặc mốc quan trọng để cả hai dễ theo dõi hơn.',
                        color: accent,
                      );
                    }

                    try {
                      final raw = snapshot.data!.snapshot.value;
                      if (raw is! Map) {
                        return CalendarEventStateCard(
                          icon: Icons.event_busy_rounded,
                          title: 'Ngày này chưa có kế hoạch nào',
                          description:
                              'Thử thêm một lịch hẹn, việc cần làm hoặc mốc quan trọng để cả hai dễ theo dõi hơn.',
                          color: accent,
                        );
                      }
                      final data = Map<dynamic, dynamic>.from(raw);
                      final items = data.entries
                          .where((entry) => entry.value is Map)
                          .map(
                            (entry) => {
                              'key': entry.key,
                              ...Map<String, dynamic>.from(entry.value as Map),
                            },
                          )
                          .toList()
                        ..sort(
                          (a, b) {
                            final tsA = _parseTimestamp(a['ts']);
                            final tsB = _parseTimestamp(b['ts']);
                            return tsA.compareTo(tsB);
                          },
                        );

                      if (items.isEmpty) {
                        return CalendarEventStateCard(
                          icon: Icons.event_busy_rounded,
                          title: 'Ngày này chưa có kế hoạch nào',
                          description:
                              'Thử thêm một lịch hẹn, việc cần làm hoặc mốc quan trọng để cả hai dễ theo dõi hơn.',
                          color: accent,
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 10),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final eventKey = item['key']?.toString() ?? '';
                          return CalendarEventTile(
                            accent: accent,
                            title: item['title']?.toString().trim() ?? '',
                            author: item['author']?.toString().trim(),
                            timestampLabel: formatCreatedTime(
                                _parseTimestamp(item['ts'])),
                            index: index,
                            statusLabel: statusLabel,
                            onDelete: eventKey.isEmpty
                                ? null
                                : () => onDelete(eventKey),
                          );
                        },
                      );
                    } catch (e) {
                      return CalendarEventStateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Không tải được lịch của ngày này',
                        description: '$e',
                        color: const Color(0xFFE46A7A),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
