import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../../../core/fast_backdrop_filter.dart';
import '../../../../core/sl_theme.dart';

import 'calendar_info_pill.dart';

class CalendarEventInputPanel extends StatelessWidget {
  final double horizontalInset;
  final bool compact;
  final Color accent;
  final int eventCount;
  final TextEditingController controller;
  final VoidCallback onAdd;

  const CalendarEventInputPanel({
    super.key,
    required this.horizontalInset,
    required this.compact,
    required this.accent,
    required this.eventCount,
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FastBackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.all(compact ? 16 : 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
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
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(compact ? 14 : 15),
                        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Icon(
                        Icons.edit_calendar_rounded,
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
                            context.tr('util_thmkhochmi_89a3cf'),
                            style: SLTheme.quicksand(
                              fontSize: compact ? 15 : 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SLSpacing.h4,
                          Text(
                            context.tr('util_vitrgihnvi_101585'),
                            style: SLTheme.quicksand(
                              fontSize: compact ? 11.5 : 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.8),
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
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: 2),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 100,
                    textInputAction: TextInputAction.done,
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('util_vd1930givi_57624e'),
                      hintStyle: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      counterText: '',
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
                      label: context.tr('util_nhctrc1ngy_09c55a'),
                      accent: accent,
                      compact: compact,
                    ),
                    CalendarInfoPill(
                      icon: Icons.schedule_rounded,
                      label: '$eventCount mục trong ngày',
                      accent: accent,
                      compact: compact,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5287), Color(0xFFFF7397)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5287).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: compact ? 13 : 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 20),
                    label: Text(
                      context.tr('util_thmvolchic_6b3138'),
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 13.5 : 14.5,
                        color: Colors.white,
                        letterSpacing: 0.3,
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
  }
}
