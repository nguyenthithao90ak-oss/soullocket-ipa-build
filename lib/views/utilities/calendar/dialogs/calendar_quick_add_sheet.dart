import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_info_pill.dart';

Future<bool> showCalendarQuickAddSheet({
  required BuildContext context,
  required bool compact,
  required Color accent,
  required int eventCount,
  required String formattedDate,
  required Future<bool> Function(String text) onSubmit,
}) async {
  final controller = TextEditingController();
  var didAdd = false;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> submit() async {
          final added = await onSubmit(controller.text);
          if (!added) {
            return;
          }

          didAdd = true;
          if (!sheetContext.mounted) {
            return;
          }

          controller.clear();
          if (Navigator.of(sheetContext).canPop()) {
            Navigator.of(sheetContext).pop();
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: FastBackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 18,
                  compact ? 16 : 18,
                  compact ? 16 : 18,
                  compact ? 18 : 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.96),
                      Colors.white.withOpacity(0.86),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.42)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: compact ? 42 : 46,
                          height: compact ? 42 : 46,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(compact ? 14 : 16),
                          ),
                          child: Icon(
                            Icons.add_task_rounded,
                            color: accent,
                            size: compact ? 21 : 23,
                          ),
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thêm nhanh cho $formattedDate',
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 15 : 16,
                                  fontWeight: FontWeight.w900,
                                  color: SLTheme.textMain,
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                eventCount == 0
                                    ? 'Ngày này chưa có kế hoạch nào. Bạn có thể thêm ngay tại đây.'
                                    : 'Ngày này đang có $eventCount kế hoạch. Có thể thêm tiếp mà không cần kéo xuống dưới.',
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
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: SLTheme.textMuted,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 12 : 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.84),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 14 : 16,
                      ),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        style: SLTheme.quicksand(
                          color: SLTheme.textMain,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Ví dụ: 19:30 đi ăn, mua quà, gọi video, chuẩn bị đồ...',
                          hintStyle: SLTheme.quicksand(
                            color: SLTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) async => submit(),
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CalendarInfoPill(
                          icon: Icons.notifications_none_rounded,
                          label: 'Nhắc trước 1 ngày',
                          accent: accent,
                          compact: compact,
                        ),
                        CalendarInfoPill(
                          icon: Icons.event_note_rounded,
                          label: '$eventCount mục hiện có',
                          accent: accent,
                          compact: compact,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 13 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.add_task_rounded, size: 20),
                        label: Text(
                          'Lưu kế hoạch cho ngày này',
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
            ),
          ),
        );
      },
    );
  } finally {
    controller.dispose();
  }

  return didAdd;
}
