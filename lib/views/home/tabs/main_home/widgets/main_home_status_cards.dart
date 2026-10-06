part of '../../main_home_tab.dart';

extension _MainHomeTabStatusCards on _MainHomeTabState {
  Widget _buildHomeCardFirstTapWrapper({
    required Widget child,
    required bool showHint,
    required Future<void> Function() onTap,
  }) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(onTap()),
        child: child,
      ),
    );
  }

  /// Kỷ niệm, sinh nhật, ngày lễ (và lịch ở chế độ một người), chưa lọc.
  ({
    List<HomeUpcomingEvent> events,
    int totalDays,
    String nameU1,
    String nameU2,
  })
  _collectHomeUpcomingEvents({
    required String? startDate,
    required DateTime todayMidnight,
  }) {
    final List<HomeUpcomingEvent> upcomingEvents = [];

    // 1. Kỷ niệm ngày yêu
    int totalDays = -1;
    if (startDate != null && startDate.isNotEmpty) {
      try {
        final startDt = DateTime.parse(startDate);
        final startDtMidnight = DateTime.utc(
          startDt.year,
          startDt.month,
          startDt.day,
        );
        // Ngày bắt đầu là ngày 0, khớp vòng đếm chính.
        final daysToday =
            CalendarCivilDate.daysBetween(startDtMidnight, todayMidnight);
        totalDays = daysToday;

        int? nextMilestone;
        for (final m in [
          100,
          200,
          300,
          400,
          500,
          600,
          700,
          800,
          900,
          1000,
          1500,
          2000,
          2500,
          3000,
          4000,
          5000,
        ]) {
          if (m >= daysToday) {
            nextMilestone = m;
            break;
          }
        }
        if (nextMilestone != null) {
          final milestoneDate = CalendarCivilDate.addDays(
            startDtMidnight,
            nextMilestone,
          );
          upcomingEvents.add(
            HomeUpcomingEvent(
              title: L10nService().format('home_anniversary_days', {
                'days': nextMilestone,
              }),
              date: milestoneDate,
              type: 'anniversary',
            ),
          );
        }

        DateTime nextAnniversary = DateTime(
          todayMidnight.year,
          startDtMidnight.month,
          startDtMidnight.day,
        );
        if (nextAnniversary.isBefore(todayMidnight)) {
          nextAnniversary = DateTime(
            todayMidnight.year + 1,
            startDtMidnight.month,
            startDtMidnight.day,
          );
        }
        final years = nextAnniversary.year - startDtMidnight.year;
        if (years > 0) {
          upcomingEvents.add(
            HomeUpcomingEvent(
              title: L10nService().format('home_anniversary_years', {
                'years': years,
              }),
              date: nextAnniversary,
              type: 'anniversary',
            ),
          );
        }
      } catch (error) {
        debugPrint('[MainHome] Invalid anniversary date: $error');
      }
    }

    // 2. Sinh nhật
    final dobU1 = _houseSettings?['dobU1']?.toString() ?? '';
    final dobU2 = _houseSettings?['dobU2']?.toString() ?? '';
    String nameU1 = _houseSettings?['nameU1']?.toString() ?? UiCopy.text('copy_40ffd8d0f1c7');
    String nameU2 = _houseSettings?['nameU2']?.toString() ?? UiCopy.text('copy_145933221191');
    if (nameU1.toLowerCase() == 'bạn nam') {
      nameU1 = context.tr('male_role_default');
    }
    if (nameU1.toLowerCase() == 'bạn nữ') {
      nameU1 = context.tr('female_role_default');
    }
    if (nameU2.toLowerCase() == 'bạn nam') {
      nameU2 = context.tr('male_role_default');
    }
    if (nameU2.toLowerCase() == 'bạn nữ') {
      nameU2 = context.tr('female_role_default');
    }

    void addBirthday(String dob, String name) {
      if (dob.isEmpty) return;
      try {
        final bday = DateTime.parse(dob);
        DateTime nextBday = DateTime(todayMidnight.year, bday.month, bday.day);
        if (nextBday.isBefore(todayMidnight)) {
          nextBday = DateTime(todayMidnight.year + 1, bday.month, bday.day);
        }
        final daysUntil = CalendarCivilDate.daysBetween(
          todayMidnight,
          nextBday,
        );
        final giftHint = daysUntil <= 7 && daysUntil >= 0
            ? _MainHomeTabState._giftSuggestionsForBirthday(
                bday.month,
                bday.day,
              )
            : '';
        upcomingEvents.add(
          HomeUpcomingEvent(
            title: giftHint.isNotEmpty
                ? '${L10nService().format('home_birthday_title', {'name': name})} $giftHint'
                : L10nService().format('home_birthday_title', {'name': name}),
            date: nextBday,
            type: 'birthday',
          ),
        );
      } catch (error) {
        debugPrint('[MainHome] Invalid birthday date: $error');
      }
    }

    addBirthday(dobU1, nameU1);
    addBirthday(dobU2, nameU2);

    // 3. Ngày lễ lớn (lọc theo quốc gia / ngôn ngữ của người dùng)
    final applicableHolidays = HolidayService.getApplicableHolidays();
    for (final occurrence in HolidayOccurrenceResolver.nextOccurrences(
      applicableHolidays,
      from: todayMidnight,
    )) {
      final displayName = HolidayService.getLocalizedName(occurrence.holiday);
      upcomingEvents.add(
        HomeUpcomingEvent(
          title: displayName,
          date: occurrence.date,
          type: 'holiday',
        ),
      );
    }

    // Mode đôi đã xem kế hoạch ở thẻ hằng ngày; thẻ này giữ kỷ niệm/ngày lễ.
    for (final event
        in _homeCalendarSnapshotMatchesScope &&
                _homeToolRelationshipMode() != 'couple'
            ? _homeCalendarEvents
            : const <Map<String, dynamic>>[]) {
      final dateKey = event['dateKey']?.toString() ?? '';
      final evTitle = event['title']?.toString() ?? '';
      if (dateKey.isEmpty || evTitle.isEmpty) continue;

      final parts = dateKey.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;

      final eventDate = DateTime(year, month, day);
      if (eventDate.isBefore(todayMidnight)) continue;

      upcomingEvents.add(
        HomeUpcomingEvent(title: evTitle, date: eventDate, type: 'calendar'),
      );
    }

    return (
      events: upcomingEvents,
      totalDays: totalDays,
      nameU1: nameU1,
      nameU2: nameU2,
    );
  }

  Widget _buildInsightBubbleWrap(
    List<_InsightBubbleSpec> metrics, {
    required bool compact,
    bool enableMotion = true,
  }) {
    final bubbleSize = compact ? 58.0 : 60.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(
            child: Center(
              child: _FloatingInsightBubble(
                label: metrics[index].label,
                value: metrics[index].value,
                color: metrics[index].color,
                phase: metrics[index].phase,
                size: bubbleSize,
                emphasize: metrics[index].emphasize,
                compact: compact,
                enableMotion: enableMotion,
              ),
            ),
          ),
          if (index < metrics.length - 1) SizedBox(width: compact ? 12 : 18),
        ],
      ],
    );
  }
}

class _InsightBubbleSpec {
  final String label;
  final int value;
  final Color color;
  final double phase;
  final bool emphasize;

  const _InsightBubbleSpec({
    required this.label,
    required this.value,
    required this.color,
    required this.phase,
    this.emphasize = false,
  });
}

class _FloatingInsightBubble extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final double phase;
  final double size;
  final bool emphasize;
  final bool compact;
  final bool enableMotion;

  const _FloatingInsightBubble({
    required this.label,
    required this.value,
    required this.color,
    required this.phase,
    required this.size,
    required this.emphasize,
    required this.compact,
    this.enableMotion = true,
  });

  @override
  State<_FloatingInsightBubble> createState() => _FloatingInsightBubbleState();
}

class _FloatingInsightBubbleState extends State<_FloatingInsightBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4200 + (widget.phase * 240).round()),
    );
    if (widget.enableMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _FloatingInsightBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableMotion != widget.enableMotion) {
      if (widget.enableMotion) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = widget.value.clamp(0, 100);
    final label = widget.label.isEmpty ? 'LOVE' : widget.label;
    final shouldUseLoveBlock =
        widget.emphasize && label.toUpperCase() == 'LOVE';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_controller.isAnimating) {
          return child!;
        }
        final angle = (_controller.value * 2 * pi) + widget.phase;
        final verticalShift = sin(angle) * (widget.compact ? 1.2 : 1.8);
        final horizontalShift = cos(angle * 0.9) * 0.5;
        final scale = 1 + (sin(angle + 0.8) * 0.006);

        return Transform.translate(
          offset: Offset(horizontalShift, -verticalShift),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shouldUseLoveBlock)
            _buildLoveBlock(clampedValue, label)
          else ...[
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: clampedValue / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.98),
                                widget.color.withValues(
                                  alpha: widget.emphasize ? 0.18 : 0.11,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: null,
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(
                                  alpha: widget.emphasize ? 0.16 : 0.1,
                                ),
                                blurRadius: widget.emphasize ? 16 : 12,
                                offset: const Offset(0, 7),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.82),
                                blurRadius: 8,
                                offset: const Offset(-2, -2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: widget.size * 0.12,
                        left: widget.size * 0.16,
                        child: Container(
                          width: widget.size * 0.28,
                          height: widget.size * 0.14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: widget.size * 0.78,
                        height: widget.size * 0.78,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: widget.compact ? 4.2 : 4.6,
                          backgroundColor: widget.color.withValues(alpha: 0.09),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.color,
                          ),
                        ),
                      ),
                      Container(
                        width: widget.size * 0.52,
                        height: widget.size * 0.52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white,
                              widget.color.withValues(alpha: 0.05),
                            ],
                          ),
                          border: null,
                        ),
                      ),
                      Text(
                        '$clampedValue',
                        style: SLTheme.quicksand(
                          fontSize: widget.compact ? 13 : 15,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SLSpacing.h8,
            SizedBox(
              width: double.infinity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: widget.compact ? 8.5 : 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF74707A),
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoveBlock(int clampedValue, String label) {
    final blockWidth = widget.compact ? widget.size + 18 : widget.size + 26;
    final blockHeight = widget.compact ? widget.size + 6 : widget.size + 10;
    final radius = BorderRadius.circular(widget.compact ? 24 : 28);

    return SizedBox(
      width: blockWidth,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clampedValue / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          final fill = progress.clamp(0.06, 1.0);
          return Container(
            height: blockHeight,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.98),
                  widget.color.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: null,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.84),
                  blurRadius: 10,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: fill,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withValues(alpha: 0.14),
                              widget.color.withValues(alpha: 0.30),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: widget.compact ? 6 : 8,
                    right: widget.compact ? 7 : 8,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: widget.compact ? 13 : 15,
                      color: widget.color.withValues(alpha: 0.45),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.compact ? 8 : 10,
                        vertical: widget.compact ? 7 : 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: widget.compact ? 9 : 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: widget.color.withValues(alpha: 0.82),
                            ),
                          ),
                          SizedBox(height: widget.compact ? 2 : 3),
                          Text(
                            '$clampedValue%',
                            style: SLTheme.quicksand(
                              fontSize: widget.compact ? 15 : 16,
                              fontWeight: FontWeight.w900,
                              color: widget.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
