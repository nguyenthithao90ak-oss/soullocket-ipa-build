import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, accent.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.92), accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              index == 0 ? Icons.favorite_rounded : Icons.event_note_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty
                            ? context.tr('calendar_plan_no_content')
                            : title,
                        style: SLTheme.quicksand(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: SLTheme.textMain,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CalendarEventMetaChip(
                      icon: Icons.person_rounded,
                      label: author?.isNotEmpty == true
                          ? L10nService().format('calendar_created_by', {
                              'name': author!,
                            })
                          : context.tr('calendar_unknown_creator'),
                    ),
                    _CalendarEventMetaChip(
                      icon: Icons.schedule_rounded,
                      label: timestampLabel,
                    ),
                    _CalendarEventMetaChip(
                      icon: Icons.tag_faces_rounded,
                      label: L10nService().format('calendar_item_index', {
                        'index': index + 1,
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFC6D6)),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE46A7A),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CalendarEventMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEADFF6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SLTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SLTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
