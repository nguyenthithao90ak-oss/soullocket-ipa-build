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
    return event.source == 'calendar'
        ? context.tr('theme_event_calendar_label')
        : context.tr('theme_event_anniversary_label');
  }

  Color _themeEventSourceColor(UpcomingEvent event) {
    return event.source == 'calendar'
        ? SLSettingsColors.sky
        : SLSettingsColors.rose;
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
        color: background ?? color.withValues(alpha: 0.12),
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
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
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
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  accent == SLSettingsColors.sky
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
                        color: SLSettingsColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: SLSettingsColors.inkSecondary,
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
    final isDeleting =
        customEventId != null &&
        _deletingCustomEventIds.contains(customEventId);
    final accent = _themeEventSourceColor(event);
    final dateLabel = _formatThemeDate(
      DateTime.fromMillisecondsSinceEpoch(event.dateMs),
    );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SLSettingsColors.surface,
        borderRadius: BorderRadius.circular(SLSettingsRadius.control + 2),
        border: Border.all(color: SLSettingsColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
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
                      color: SLSettingsColors.inkSecondary,
                      background: SLSettingsColors.surfaceMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: SLSettingsColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 14,
                      color: SLSettingsColors.inkSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context
                            .tr('theme_event_date_label')
                            .replaceAll('{date}', dateLabel),
                        style: SLTheme.quicksand(
                          fontSize: 11.4,
                          fontWeight: FontWeight.w700,
                          color: SLSettingsColors.inkSecondary,
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
                onTap: isDeleting
                    ? null
                    : () => _deleteCustomAnniversary(event),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SLSettingsColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SLSettingsColors.border),
                  ),
                  alignment: Alignment.center,
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: SLSettingsColors.accentStrong,
                          ),
                        )
                      : Icon(
                          Icons.delete_outline_rounded,
                          color: SLSettingsColors.accentStrong,
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
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) {
      return Text(
        context.tr('theme_event_empty_house'),
        style: SLTheme.quicksand(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SLSettingsColors.inkSecondary,
        ),
      );
    }

    return _ThemeEventPreviewSection(
      key: ValueKey((FirebaseAuth.instance.currentUser?.uid, houseId)),
      houseId: houseId,
      scheduleNotifService: _scheduleNotifService,
      eventCardBuilder: _buildThemeEventCard,
      eventSectionBuilder: _buildThemeEventSection,
      context: context,
    );
  }
}

class _ThemeEventPreviewSection extends StatefulWidget {
  final String houseId;
  final ScheduleNotifService scheduleNotifService;
  final Widget Function(UpcomingEvent event) eventCardBuilder;
  final Widget Function({
    required String title,
    required String subtitle,
    required Color accent,
    required List<UpcomingEvent> events,
  })
  eventSectionBuilder;
  final BuildContext context;

  const _ThemeEventPreviewSection({
    super.key,
    required this.houseId,
    required this.scheduleNotifService,
    required this.eventCardBuilder,
    required this.eventSectionBuilder,
    required this.context,
  });

  @override
  State<_ThemeEventPreviewSection> createState() =>
      _ThemeEventPreviewSectionState();
}

class _ThemeEventPreviewSectionState extends State<_ThemeEventPreviewSection> {
  late Stream<List<UpcomingEvent>> _upcomingEventsStream;
  int _streamGeneration = 0;

  @override
  void initState() {
    super.initState();
    _upcomingEventsStream = _createUpcomingEventsStream();
  }

  Stream<List<UpcomingEvent>> _createUpcomingEventsStream() {
    return withInitialEventTimeout<List<UpcomingEvent>>(
      widget.scheduleNotifService.streamUpcomingEvents(widget.houseId),
      timeout: const Duration(seconds: 12),
    );
  }

  void _retryUpcomingEvents() {
    if (!mounted) return;
    setState(() {
      _streamGeneration++;
      _upcomingEventsStream = _createUpcomingEventsStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UpcomingEvent>>(
      key: ValueKey(_streamGeneration),
      stream: _upcomingEventsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: SLSettingsColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SLSettingsColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: SLSettingsColors.inkSecondary,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.tr('core_err_try_again_later'),
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: SLSettingsColors.inkSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _retryUpcomingEvents,
                  child: Text(context.tr('retry')),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final events = snapshot.data ?? const <UpcomingEvent>[];
        if (events.isEmpty) {
          return Text(
            widget.context.tr('theme_event_empty_list'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SLSettingsColors.inkSecondary,
            ),
          );
        }

        final anniversaryEvents = events
            .where((event) => event.source == 'custom')
            .toList();
        final calendarEvents = events
            .where((event) => event.source == 'calendar')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: SLSettingsColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SLSettingsColors.border),
              ),
              child: Text(
                widget.context.tr('theme_event_description_hint'),
                style: SLTheme.quicksand(
                  fontSize: 11.4,
                  fontWeight: FontWeight.w800,
                  color: SLSettingsColors.inkSecondary,
                  height: 1.42,
                ),
              ),
            ),
            if (anniversaryEvents.isNotEmpty)
              widget.eventSectionBuilder(
                title: widget.context.tr(
                  'theme_event_anniversary_section_title',
                ),
                subtitle: widget.context.tr(
                  'theme_event_anniversary_section_desc',
                ),
                accent: SLSettingsColors.accentStrong,
                events: anniversaryEvents,
              ),
            if (calendarEvents.isNotEmpty)
              widget.eventSectionBuilder(
                title: widget.context.tr('theme_event_calendar_section_title'),
                subtitle: widget.context.tr(
                  'theme_event_calendar_section_desc',
                ),
                accent: SLSettingsColors.sky,
                events: calendarEvents,
              ),
          ],
        );
      },
    );
  }
}
