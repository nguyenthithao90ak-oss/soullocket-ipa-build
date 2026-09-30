part of '../../love_insights_view.dart';

enum _TimelineEntryState { passed, current, upcoming }

class _TimelineDisplayEntry {
  final LoveInsightTimelineEntry entry;
  final _TimelineEntryState state;

  const _TimelineDisplayEntry({required this.entry, required this.state});
}

extension _InsightTimelineSectionExt on LoveInsightsView {
  DateTime _timelineDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  List<_TimelineDisplayEntry> _buildVisibleTimeline(
    List<LoveInsightTimelineEntry> timeline,
  ) {
    final sorted = [...timeline]
      ..sort((a, b) => _timelineDay(a.date).compareTo(_timelineDay(b.date)));
    final today = _timelineDay(DateTime.now());
    final reached = sorted
        .where((entry) => !_timelineDay(entry.date).isAfter(today))
        .toList(growable: false);
    final upcoming = sorted
        .where((entry) => _timelineDay(entry.date).isAfter(today))
        .toList(growable: false);

    final visible = <_TimelineDisplayEntry>[];

    visible.addAll(
      upcoming
          .take(2)
          .map(
            (entry) => _TimelineDisplayEntry(
              entry: entry,
              state: _TimelineEntryState.upcoming,
            ),
          ),
    );

    if (reached.isNotEmpty) {
      visible.add(
        _TimelineDisplayEntry(
          entry: reached.last,
          state: _TimelineEntryState.current,
        ),
      );
    }

    if (reached.length > 1) {
      visible.addAll(
        reached.reversed
            .skip(1)
            .map(
              (entry) => _TimelineDisplayEntry(
                entry: entry,
                state: _TimelineEntryState.passed,
              ),
            ),
      );
    }

    if (visible.isEmpty) {
      visible.addAll(
        sorted
            .take(2)
            .map(
              (entry) => _TimelineDisplayEntry(
                entry: entry,
                state: _TimelineEntryState.upcoming,
              ),
            ),
      );
    }

    return visible;
  }

  Widget _buildTimelineSection(LoveInsightData insight) {
    final visibleTimeline = _buildVisibleTimeline(insight.timeline);
    return Container(
      key: const ValueKey('insight-timeline'),
      padding: const EdgeInsets.all(20),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardTitle(
            icon: Icons.auto_stories_outlined,
            title: L10nService().translate(
              _isSingle ? 'home_dngthigian_231147' : 'home_dngthigian_a93fc5',
            ),
            subtitle: L10nService().translate(
              _isSingle ? 'home_nhngctmcvs_f144c1' : 'home_ccmcquantr_89a221',
            ),
          ),
          const SizedBox(height: 24),
          if (insight.timeline.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5EF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 36,
                    color: Color(0xFFB88A7B),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    L10nService().translate(
                      _isSingle
                          ? 'home_chacctmcno_6d2fc1'
                          : 'home_chacknimno_aa5b75',
                    ),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                      color: const Color(0xFF806C73),
                    ),
                  ),
                ],
              ),
            )
          else
            ...visibleTimeline.asMap().entries.map(
              (item) => _buildTimelineItem(
                item.value,
                isLast: item.key == visibleTimeline.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineDisplayEntry item, {bool isLast = false}) {
    final entry = item.entry;
    final dateText = DateFormat('dd/MM/yyyy').format(entry.date);
    final isCurrent = item.state == _TimelineEntryState.current;
    final isUpcoming = item.state == _TimelineEntryState.upcoming;
    final accent = isCurrent
        ? const Color(0xFF99516B)
        : isUpcoming
        ? const Color(0xFFA47750)
        : const Color(0xFF637F78);
    final background = isCurrent
        ? const Color(0xFFFFF0F3)
        : isUpcoming
        ? const Color(0xFFFFF7EC)
        : const Color(0xFFF4F7F4);
    final badgeText = L10nService().translate(
      isCurrent
          ? 'home_hinti_d6af47'
          : isUpcoming
          ? 'insight_timeline_upcoming'
          : 'home_qua_8ff9a0',
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    isCurrent
                        ? Icons.favorite_rounded
                        : isUpcoming
                        ? Icons.event_outlined
                        : Icons.check_rounded,
                    size: 15,
                    color: accent,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE8D9D3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                key: ValueKey(
                  'insight-milestone-${entry.date.millisecondsSinceEpoch}-${entry.title}',
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: SLTheme.quicksand(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          dateText,
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF806C73),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry.title,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: const Color(0xFF492E3A),
                      ),
                    ),
                    if (entry.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.subtitle,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          color: const Color(0xFF806C73),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
