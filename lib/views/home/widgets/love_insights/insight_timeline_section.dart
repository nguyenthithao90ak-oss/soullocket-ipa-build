part of '../../love_insights_screen.dart';

enum _TimelineEntryState { passed, current, upcoming }

class _TimelineDisplayEntry {
  final LoveInsightTimelineEntry entry;
  final _TimelineEntryState state;

  const _TimelineDisplayEntry({
    required this.entry,
    required this.state,
  });
}

extension _InsightTimelineSectionExt on _LoveInsightsScreenState {
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
      upcoming.take(2).map(
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
        reached.reversed.skip(1).map(
              (entry) => _TimelineDisplayEntry(
                entry: entry,
                state: _TimelineEntryState.passed,
              ),
            ),
      );
    }

    if (visible.isEmpty) {
      visible.addAll(
        sorted.take(2).map(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeline header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF4F87),
                size: 20,
              ),
              SLSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSingle
                          ? context.tr('home_dngthigian_231147')
                          : context.tr('home_dngthigian_a93fc5'),
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF332C35),
                      ),
                    ),
                    Text(
                      _isSingle
                          ? context.tr('home_nhngctmcvs_f144c1')
                          : context.tr('home_ccmcquantr_89a221'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8D8490),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SLSpacing.h16,
        if (insight.timeline.isEmpty)
          Container(
            width: double.infinity,
            padding: SLSpacing.all16,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isSingle
                  ? context.tr('home_chacctmcno_6d2fc1')
                  : context.tr('home_chacknimno_aa5b75'),
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.55,
                color: const Color(0xFF8D8490),
              ),
            ),
          )
        else
          ...visibleTimeline.asMap().entries.map(
                (e) => _buildTimelineItem(e.value, isLast: e.key == visibleTimeline.length - 1),
              ),
      ],
    );
  }

  Widget _buildTimelineItem(_TimelineDisplayEntry item, {bool isLast = false}) {
    final entry = item.entry;
    final dateText = DateFormat('dd/MM/yyyy').format(entry.date);
    final isCurrent = item.state == _TimelineEntryState.current;
    final isUpcoming = item.state == _TimelineEntryState.upcoming;

    final nodeColor = isCurrent
        ? const Color(0xFFFF4F87)
        : isUpcoming
            ? const Color(0xFFE9DDFF)
            : const Color(0xFFFFB3D0);
    final cardBg = isCurrent
        ? Colors.white
        : isUpcoming
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.85);
    final borderColor = isCurrent
        ? const Color(0xFFFFDCE8)
        : isUpcoming
            ? const Color(0xFFE9DDFF)
            : const Color(0xFFFFDCE8).withValues(alpha: 0.5);
    final titleColor =
        isUpcoming ? const Color(0xFFBDB5C2) : const Color(0xFF332C35);
    final subtitleColor =
        isUpcoming ? const Color(0xFFBDB5C2) : const Color(0xFF8D8490);
    final badgeText = isCurrent
        ? context.tr('home_hinti_d6af47')
        : isUpcoming
            ? context.tr('home_kha_171aa7')
            : context.tr('home_qua_8ff9a0');
    final badgeBg = isCurrent
        ? const Color(0xFFFFEEF4)
        : isUpcoming
            ? const Color(0xFFF3EEFF)
            : const Color(0xFFFFEEF4);
    final badgeColor = isCurrent
        ? const Color(0xFFFF4F87)
        : isUpcoming
            ? const Color(0xFF9B7AE8)
            : const Color(0xFFFF85A2);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline line + node ──
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Node
                Container(
                  width: isCurrent ? 16 : 12,
                  height: isCurrent ? 16 : 12,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: isUpcoming
                        ? Border.all(color: const Color(0xFF9B7AE8).withValues(alpha: 0.3), width: 2)
                        : null,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF4F87).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isCurrent
                      ? const Icon(Icons.favorite_rounded, size: 9, color: Colors.white)
                      : null,
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFFF8FB3).withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          SLSpacing.w8,
          // ── Event card ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF4F87).withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badgeText,
                            style: SLTheme.quicksand(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateText,
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.title,
                      style: SLTheme.quicksand(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      entry.subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                      ),
                    ),
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

class _TimelineFlameBadge extends StatefulWidget {
  const _TimelineFlameBadge();

  @override
  State<_TimelineFlameBadge> createState() => _TimelineFlameBadgeState();
}

class _TimelineFlameBadgeState extends State<_TimelineFlameBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 0.16 + (_controller.value * 0.22);
        final scale = 0.98 + (_controller.value * 0.04);
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF85A2), Color(0xFFFF4F87)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4F87).withValues(alpha: glow),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                SLSpacing.w4,
                Text(
                  context.tr('home_angchy_f406fd'),
                  style: SLTheme.quicksand(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
