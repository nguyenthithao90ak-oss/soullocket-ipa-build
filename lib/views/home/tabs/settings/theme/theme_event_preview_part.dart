part of '../../settings_tab.dart';

extension _SettingsTabThemeEventPreviewPart on _SettingsTabState {
  String _themeUpcomingBadge(UpcomingEvent event) {
    if (event.daysUntil == 0) return context.tr('theme_event_today');
    if (event.daysUntil == 1) return context.tr('theme_event_tomorrow');
    return context
        .tr('theme_event_days_left')
        .replaceAll('{days}', event.daysUntil.toString());
  }

  String _themeEventSourceLabel(UpcomingEvent event) {
    return event.source == 'calendar' ? 'Lịch chung' : 'Kỷ niệm';
  }

  Color _themeEventSourceColor(UpcomingEvent event) {
    return event.source == 'calendar'
        ? const Color(0xFF5B8DEF)
        : const Color(0xFFE57AA5);
  }

  Widget _buildThemeEventChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 10.6,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeEventSection({
    required String title,
    required String subtitle,
    required Color accent,
    required List<UpcomingEvent> events,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  title.contains('Lịch')
                      ? Icons.calendar_view_day_rounded
                      : Icons.favorite_rounded,
                  color: accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3B45),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A5B76),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...events.map(_buildThemeEventCard),
        ],
      ),
    );
  }

  Widget _buildThemeEventCard(UpcomingEvent event) {
    final customEventId = _extractCustomEventId(event);
    final isDeleting = customEventId != null &&
        _deletingCustomEventIds.contains(customEventId);
    final accent = _themeEventSourceColor(event);
    final dateLabel = _formatThemeDate(
      DateTime.fromMillisecondsSinceEpoch(event.dateMs),
    );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              event.source == 'calendar'
                  ? Icons.event_note_rounded
                  : Icons.favorite_rounded,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildThemeEventChip(
                      icon: event.source == 'calendar'
                          ? Icons.calendar_today_rounded
                          : Icons.favorite_rounded,
                      label: _themeEventSourceLabel(event),
                      color: accent,
                    ),
                    _buildThemeEventChip(
                      icon: Icons.schedule_rounded,
                      label: _themeUpcomingBadge(event),
                      color: const Color(0xFF8A5B76),
                      background: const Color(0xFFF9EEF4),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF444444),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 14,
                      color: Color(0xFF8A5B76),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ngày diễn ra: $dateLabel',
                        style: SLTheme.quicksand(
                          fontSize: 11.4,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8A5B76),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (customEventId != null) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap:
                    isDeleting ? null : () => _deleteCustomAnniversary(event),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFC8D8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFFD81B60),
                          ),
                        )
                      : Icon(
                          Icons.delete_outline_rounded,
                          color: const Color(0xFFD81B60),
                          size: 18,
                          semanticLabel: context.tr('theme_event_delete_cta'),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeEventPreview() {
    if (_houseId == null || _houseId!.trim().isEmpty) {
      return Text(
        context.tr('theme_event_empty_house'),
        style: SLTheme.quicksand(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8F7A85),
        ),
      );
    }

    return StreamBuilder<List<UpcomingEvent>>(
      stream: _scheduleNotifService.streamUpcomingEvents(_houseId!),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <UpcomingEvent>[];
        if (events.isEmpty) {
          return Text(
            context.tr('theme_event_empty_list'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8F7A85),
            ),
          );
        }

        final anniversaryEvents =
            events.where((event) => event.source == 'custom').toList();
        final calendarEvents =
            events.where((event) => event.source == 'calendar').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF6D9E6)),
              ),
              child: Text(
                'Bên dưới đã tách rõ: khối hồng là kỷ niệm bạn thêm ở đây, khối xanh là lịch chung lấy từ mục Lịch.',
                style: SLTheme.quicksand(
                  fontSize: 11.4,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8A5B76),
                  height: 1.42,
                ),
              ),
            ),
            if (anniversaryEvents.isNotEmpty)
              _buildThemeEventSection(
                title: 'Kỷ niệm sắp tới',
                subtitle: 'Các mốc riêng được thêm trong phần kỷ niệm',
                accent: const Color(0xFFD81B60),
                events: anniversaryEvents,
              ),
            if (calendarEvents.isNotEmpty)
              _buildThemeEventSection(
                title: 'Lịch chung sắp tới',
                subtitle: 'Các kế hoạch đang lấy từ mục Lịch chung',
                accent: const Color(0xFF3366D6),
                events: calendarEvents,
              ),
          ],
        );
      },
    );
  }
}
