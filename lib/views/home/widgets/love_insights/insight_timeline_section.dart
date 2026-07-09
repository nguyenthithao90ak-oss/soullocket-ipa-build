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

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.timeline_rounded,
            title: _isSingle
                ? context.tr('home_dngthigian_231147')
                : context.tr('home_dngthigian_a93fc5'),
            subtitle: _isSingle
                ? context.tr('home_nhngctmcvs_f144c1')
                : context.tr('home_ccmcquantr_89a221'),
          ),
          SLSpacing.h12,
          if (insight.timeline.isEmpty)
            Container(
              width: double.infinity,
              padding: SLSpacing.all16,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: SLRadius.lgAll,
                border: Border.all(color: const Color(0xFFE8EAF0)),
              ),
              child: Text(
                _isSingle
                    ? context.tr('home_chacctmcno_6d2fc1')
                    : context.tr('home_chacknimno_aa5b75'),
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.55,
                  color: const Color(0xFF7A7480),
                ),
              ),
            )
          else
            ...visibleTimeline.map(_buildTimelineItem),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineDisplayEntry item) {
    final entry = item.entry;
    final dateText = DateFormat('dd/MM/yyyy').format(entry.date);
    final baseAccent =
        entry.isCustom ? const Color(0xFF9C27B0) : const Color(0xFFD81B60);
    final isCurrent = item.state == _TimelineEntryState.current;
    final isUpcoming = item.state == _TimelineEntryState.upcoming;
    final accent = isCurrent
        ? const Color(0xFFF26A3D)
        : isUpcoming
            ? const Color(0xFFC4BDCC)
            : baseAccent;
    final cardColor = isCurrent
        ? const Color(0xFFFFF6F0)
        : isUpcoming
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.88);
    final borderColor = isCurrent
        ? const Color(0xFFFFD7C5)
        : isUpcoming
            ? const Color(0xFFE6E1EB)
            : baseAccent.withValues(alpha: 0.14);
    final titleColor =
        isUpcoming ? const Color(0xFF8F8998) : const Color(0xFF233041);
    final subtitleColor =
        isUpcoming ? const Color(0xFFA8A2AF) : const Color(0xFF837C88);
    final dateColor = isCurrent
        ? const Color(0xFFF26A3D)
        : isUpcoming
            ? const Color(0xFFBBB5C3)
            : const Color(0xFF9B98A1);
    final badgeText = isCurrent
        ? context.tr('home_hinti_d6af47')
        : isUpcoming
            ? context.tr('home_kha_171aa7')
            : context.tr('home_qua_8ff9a0');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                dateText,
                textAlign: TextAlign.right,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: dateColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: SLRadius.lgAll,
                border: Border.all(color: borderColor),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFFF26A3D).withValues(alpha: 0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -19,
                    top: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isUpcoming ? Colors.white : accent,
                        shape: BoxShape.circle,
                        border: isUpcoming
                            ? Border.all(
                                color: const Color(0xFFD5CFDD),
                                width: 1.4,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xFFFFE8DC)
                                  : isUpcoming
                                      ? const Color(0xFFF3F0F6)
                                      : accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText,
                              style: SLTheme.quicksand(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isCurrent) const _TimelineFlameBadge(),
                          if (isUpcoming)
                            Opacity(
                              opacity: 0.55,
                              child: Icon(
                                Icons.lock_rounded,
                                size: 18,
                                color: accent,
                              ),
                            ),
                          if (!isCurrent && !isUpcoming)
                            Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: accent.withValues(alpha: 0.8),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
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
    // ⚡ Delay animation start by 3s to reduce initial app startup lag
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
                colors: [Color(0xFFFF9A6A), Color(0xFFFF5B6E)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5B6E).withValues(alpha: glow),
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
