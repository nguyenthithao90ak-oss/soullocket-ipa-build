import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../../../core/sl_theme.dart';

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
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
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
                            ? context.tr('util_chactiu_3f4360')
                            : title,
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Text(
                        statusLabel,
                        style: SLTheme.quicksand(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
                          ? 'Tạo bởi $author'
                          : context.tr('util_charngito_c3640d'),
                    ),
                    _CalendarEventMetaChip(
                      icon: Icons.schedule_rounded,
                      label: timestampLabel,
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
                color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF6B6B),
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

  const _CalendarEventMetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
