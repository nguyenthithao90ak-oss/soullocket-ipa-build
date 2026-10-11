import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/locale_date_format.dart';
import '../../../utils/screen_activity_mixin.dart';
import '../../../utils/services/l10n_service.dart';
import 'cinema_teaser_player.dart';

@immutable
class CinemaMilestone {
  const CinemaMilestone({required this.date, required this.title});

  final DateTime date;
  final String title;
}

int cinemaDaysUntil(DateTime date, DateTime now) => math.max(
  0,
  DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays,
);

class CinemaWaitingRoom extends StatefulWidget {
  const CinemaWaitingRoom({
    super.key,
    required this.houseName,
    required this.photoCount,
    required this.photoBuilder,
    required this.milestones,
    required this.onBack,
    required this.onInfo,
    this.notice,
    this.onDayChanged,
    this.now,
  });

  final String houseName;
  final int photoCount;
  final IndexedWidgetBuilder photoBuilder;
  final List<CinemaMilestone> milestones;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final String? notice;
  final VoidCallback? onDayChanged;
  final DateTime Function()? now;

  @override
  State<CinemaWaitingRoom> createState() => _CinemaWaitingRoomState();
}

class _CinemaWaitingRoomState extends State<CinemaWaitingRoom>
    with ScreenActivityMixin {
  Timer? _dayTimer;
  bool _openingTeaser = false;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void onScreenActivityChanged(bool active) {
    _dayTimer?.cancel();
    if (!active) return;
    _scheduleDayChange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isScreenActive) {
        setState(() {});
        widget.onDayChanged?.call();
      }
    });
  }

  void _scheduleDayChange() {
    _dayTimer?.cancel();
    final now = _now;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(tomorrow.difference(now), () {
      if (!isScreenActive) return;
      setState(() {});
      widget.onDayChanged?.call();
      _scheduleDayChange();
    });
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  Future<void> _openTeaser() async {
    if (_openingTeaser || widget.photoCount == 0) return;
    _openingTeaser = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => CinemaTeaserPlayer(
          photoCount: math.min(widget.photoCount, 3),
          photoBuilder: widget.photoBuilder,
        ),
      );
    } finally {
      _openingTeaser = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final milestones = [...widget.milestones]
      ..sort((first, second) => first.date.compareTo(second.date));
    final nextIndex = milestones.indexWhere(
      (item) => !DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
      ).isBefore(today),
    );
    final next = nextIndex < 0 ? null : milestones[nextIndex];
    final visible = milestones
        .skip(
          nextIndex < 0
              ? math.max(0, milestones.length - 4)
              : math.max(0, nextIndex - 1),
        )
        .take(4)
        .toList();
    final dayNumber =
        DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final dailyKey = 'cinema_daily_${dayNumber % 3}';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F4),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4EC), Color(0xFFF5F0FF), Color(0xFFFFFAF4)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: context.tr('p8_cinema_back'),
                          onPressed: widget.onBack,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: _ink,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: context.tr('p8_cinema_info'),
                          onPressed: widget.onInfo,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: _ink,
                          ),
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('util_rpknim_d094b9'),
                      style: _text(30, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.houseName, style: _text(14, color: _muted)),
                    const SizedBox(height: 18),
                    _buildPhotoStack(),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(dailyKey),
                      textAlign: TextAlign.center,
                      style: _text(15, color: _muted),
                    ),
                    const SizedBox(height: 18),
                    _buildTicket(next, now),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('cinema-open-teaser'),
                        onPressed: widget.photoCount == 0 ? null : _openTeaser,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 52),
                          backgroundColor: _rose,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE7DEDB),
                          disabledForegroundColor: _muted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          context.tr('cinema_teaser_action'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        widget.photoCount == 0
                            ? 'cinema_teaser_empty'
                            : 'cinema_teaser_body',
                      ),
                      textAlign: TextAlign.center,
                      style: _text(12, color: _muted),
                    ),
                    if (visible.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Text(
                        context.tr('cinema_timeline_title'),
                        style: _text(18, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      for (final milestone in visible)
                        _buildMilestone(
                          milestone,
                          today,
                          next?.date,
                          milestone == visible.last,
                        ),
                    ],
                    if (widget.notice != null) ...[
                      const SizedBox(height: 18),
                      Text(widget.notice!, style: _text(12, color: _muted)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoStack() => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(164.0, constraints.maxWidth * 0.52);
      final height = width * 1.24;
      final count = math.min(widget.photoCount, 3);
      return SizedBox(
        key: const Key('cinema-teaser-posters'),
        width: double.infinity,
        height: height + 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE2F5).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            for (final index in [if (count > 1) 1, if (count > 2) 2, 0])
              Transform.translate(
                offset: Offset(
                  index == 1 ? -width * 0.32 : (index == 2 ? width * 0.32 : 0),
                  index == 0 ? 0 : 8,
                ),
                child: Transform.rotate(
                  angle: index == 1 ? -0.13 : (index == 2 ? 0.13 : -0.015),
                  child: Container(
                    width: width,
                    height: height,
                    padding: const EdgeInsets.fromLTRB(7, 7, 7, 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x223F2B4C),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: count == 0
                          ? const ColoredBox(
                              color: Color(0xFFF1E4E5),
                              child: Icon(
                                Icons.favorite_outline_rounded,
                                color: _rose,
                                size: 48,
                              ),
                            )
                          : ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 1.4,
                                sigmaY: 1.4,
                              ),
                              child: widget.photoBuilder(context, index),
                            ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFFFFDEAC),
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.tr('cinema_premiere_waiting'),
                          style: _text(
                            12,
                            color: Colors.white,
                            weight: FontWeight.w800,
                          ),
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
    },
  );

  Widget _buildTicket(CinemaMilestone? next, DateTime now) => Container(
    key: const Key('cinema-premiere-ticket'),
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECD1),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE9CCAA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              color: _rose,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('cinema_ticket_title'),
                style: _text(13, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          next?.title ?? context.tr('util_chacngybtu_0f2f9a'),
          style: _text(20, weight: FontWeight.w900),
        ),
        if (next != null) ...[
          const SizedBox(height: 6),
          Text(
            LocaleDateFormat.date(next.date),
            style: _text(14, color: _muted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: List.generate(
                (constraints.maxWidth / 9).floor(),
                (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(height: 1, color: const Color(0xFFD9BA94)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: _rose, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cinemaDaysUntil(next.date, now) == 0
                      ? context.tr('countdown_today')
                      : L10nScope.of(context).format('cinema_countdown_days', {
                          'count': cinemaDaysUntil(next.date, now),
                        }),
                  style: _text(18, color: _rose, weight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          context.tr('cinema_premiere_hint'),
          style: _text(12, color: _muted),
        ),
      ],
    ),
  );

  Widget _buildMilestone(
    CinemaMilestone milestone,
    DateTime today,
    DateTime? nextDate,
    bool last,
  ) {
    final date = DateTime(
      milestone.date.year,
      milestone.date.month,
      milestone.date.day,
    );
    final reached = date.isBefore(today);
    final next = nextDate == milestone.date;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: next ? const Color(0xFFE8D9F5) : const Color(0xFFEEE8E3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              reached
                  ? Icons.check_rounded
                  : (next
                        ? Icons.favorite_rounded
                        : Icons.lock_outline_rounded),
              color: next ? const Color(0xFF8960A7) : _muted,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: next
                    ? const Color(0xFFEEE4F7)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: _text(14, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    LocaleDateFormat.date(milestone.date),
                    style: _text(12, color: _muted),
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

const _ink = Color(0xFF443548);
const _muted = Color(0xFF786B7D);
const _rose = Color(0xFFA95C78);

TextStyle _text(
  double size, {
  Color color = _ink,
  FontWeight weight = FontWeight.w600,
}) => SLTheme.quicksand(
  fontSize: size,
  height: 1.4,
  fontWeight: weight,
  color: color,
);
