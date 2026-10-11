import '../../utils/services/market_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/widgets/milestone_embedded_sticker.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../utilities/calendar_screen.dart';
import '../../core/sl_page_physics.dart';
import '../../widgets/living_sticker_scene.dart';
import '../../utils/services/holiday_service.dart';
import '../../utils/calendar/holiday_occurrence_resolver.dart';
import '../../utils/calendar/calendar_time_zone.dart';
import '../../utils/calendar/calendar_civil_date.dart';
import 'milestone_sticker_gallery_screen.dart';
import 'widgets/milestones/milestones_design.dart';

class MilestoneEvent {
  final String title;
  final DateTime date;
  final String type; // 'anniversary' | 'birthday' | 'holiday' | 'calendar'
  final int diffDays; // Countdown days (negative for past events)
  final String? stickerKey;

  MilestoneEvent({
    required this.title,
    required this.date,
    required this.type,
    required this.diffDays,
    this.stickerKey,
  });
}

class MilestonesScreen extends StatefulWidget {
  final String houseId;
  final String? startDate;
  final Map<String, dynamic> houseSettings;
  final List<Map<String, dynamic>> homeCalendarEvents;

  const MilestonesScreen({
    super.key,
    required this.houseId,
    this.startDate,
    required this.houseSettings,
    required this.homeCalendarEvents,
  });

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MilestoneEvent> _upcomingList = [];
  List<MilestoneEvent> _pastList = [];

  DateTime get _calendarNow => CalendarTimeZone.fromMilliseconds(
    DateTime.now().millisecondsSinceEpoch,
    MarketService.instance.preferences.timeZoneId,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateEvents();
    MarketService.instance.addListener(_onRegionChanged);
    L10nService().addListener(_onRegionChanged);
  }

  void _onRegionChanged() {
    if (mounted) setState(_calculateEvents);
  }

  @override
  void dispose() {
    MarketService.instance.removeListener(_onRegionChanged);
    L10nService().removeListener(_onRegionChanged);
    _tabController.dispose();
    super.dispose();
  }

  DateTime _clampedDate(int year, int month, int preferredDay) {
    final normalizedMonth = DateTime(year, month, 1);
    final lastDay = DateTime(
      normalizedMonth.year,
      normalizedMonth.month + 1,
      0,
    ).day;
    final safeDay = preferredDay > lastDay ? lastDay : preferredDay;
    return DateTime.utc(normalizedMonth.year, normalizedMonth.month, safeDay);
  }

  void _calculateEvents() {
    final today = _calendarNow;
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final List<MilestoneEvent> allEvents = [];
    DateTime? startDt;

    if (widget.startDate != null && widget.startDate!.isNotEmpty) {
      try {
        startDt = DateTime.parse(widget.startDate!);
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/home/milestones_screen.dart: $error',
        );
      }
    }

    // 1. Cột mốc kỷ niệm ngày yêu
    if (startDt != null) {
      final startDtMidnight = DateTime.utc(
        startDt.year,
        startDt.month,
        startDt.day,
      );

      // Cột mốc ngày (cả quá khứ và tương lai)
      final milestoneDays = [
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
        10000,
      ];
      for (final m in milestoneDays) {
        // Cùng quy ước với vòng đếm ở màn chính và thông báo: ngày bắt đầu
        // là ngày 0, nên mốc N ngày rơi vào đúng ngày bộ đếm hiện N.
        final milestoneDate = CalendarCivilDate.addDays(startDtMidnight, m);
        final diff = CalendarCivilDate.daysBetween(
          todayMidnight,
          milestoneDate,
        );
        allEvents.add(
          MilestoneEvent(
            title: milestoneStickerLabel('days_$m'),
            date: milestoneDate,
            type: 'anniversary',
            stickerKey: 'days_$m',
            diffDays: diff,
          ),
        );
      }

      // Cột mốc tháng (kỷ niệm tháng yêu nhau: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 tháng)
      final milestoneMonths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
      for (final m in milestoneMonths) {
        final milestoneDate = _clampedDate(
          startDtMidnight.year,
          startDtMidnight.month + m,
          startDtMidnight.day,
        );
        final diff = CalendarCivilDate.daysBetween(
          todayMidnight,
          milestoneDate,
        );
        final title = milestoneStickerLabel('months_$m');
        allEvents.add(
          MilestoneEvent(
            title: title,
            date: milestoneDate,
            type: 'anniversary',
            stickerKey: 'months_$m',
            diffDays: diff,
          ),
        );
      }

      // Cột mốc năm (kỷ niệm năm yêu nhau)
      for (int y = 1; y <= 25; y++) {
        final annivDate = _clampedDate(
          startDtMidnight.year + y,
          startDtMidnight.month,
          startDtMidnight.day,
        );
        final diff = CalendarCivilDate.daysBetween(todayMidnight, annivDate);
        allEvents.add(
          MilestoneEvent(
            title: milestoneStickerLabel('years_$y'),
            date: annivDate,
            type: 'anniversary',
            stickerKey: 'years_$y',
            diffDays: diff,
          ),
        );
      }
    }

    // 2. Sinh nhật đôi bạn (dobU1, dobU2)
    final dobU1 = widget.houseSettings['dobU1']?.toString() ?? '';
    final dobU2 = widget.houseSettings['dobU2']?.toString() ?? '';
    final nameU1 =
        widget.houseSettings['nameU1']?.toString() ??
        L10nService().translate('p4_default_you');
    final nameU2 =
        widget.houseSettings['nameU2']?.toString() ??
        L10nService().translate('p4_default_partner');

    void computeBirthdays(String dob, String name, String stickerKey) {
      if (dob.isEmpty) return;
      try {
        final bday = DateTime.parse(dob);
        // Tính sinh nhật trong năm trước, năm nay, và năm sau
        for (int yearOffset = -1; yearOffset <= 1; yearOffset++) {
          final targetYear = todayMidnight.year + yearOffset;
          int day = bday.day;
          if (bday.month == 2 && bday.day == 29) {
            final isLeap =
                (targetYear % 4 == 0 && targetYear % 100 != 0) ||
                (targetYear % 400 == 0);
            if (!isLeap) day = 28;
          }
          final bdayDate = DateTime(targetYear, bday.month, day);
          final diff = CalendarCivilDate.daysBetween(todayMidnight, bdayDate);
          allEvents.add(
            MilestoneEvent(
              title: L10nService().format('sticker_love_birthday', {
                'name': name,
              }),
              date: bdayDate,
              type: 'birthday',
              stickerKey: stickerKey,
              diffDays: diff,
            ),
          );
        }
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/home/milestones_screen.dart: $error',
        );
      }
    }

    computeBirthdays(dobU1, nameU1, 'moment_birthday_u1');
    computeBirthdays(dobU2, nameU2, 'moment_birthday_u2');

    // 3. Ngày lễ lớn đầy đủ (lọc theo quốc gia / ngôn ngữ của người dùng)
    final applicableHolidays = HolidayService.getApplicableHolidays();
    final holidayOccurrences = HolidayOccurrenceResolver.occurrencesBetween(
      applicableHolidays,
      start: DateTime(todayMidnight.year - 1),
      end: DateTime(todayMidnight.year + 1, 12, 31),
    );
    for (final occurrence in holidayOccurrences) {
      final h = occurrence.holiday;
      final holidayStickerKey = h.stickerKey;
      final useEnglishLabel =
          !h.countries.contains('VN') &&
          holidayStickerKey != null &&
          MilestoneStickerCatalog.scene(holidayStickerKey) != null;
      allEvents.add(
        MilestoneEvent(
          title: useEnglishLabel
              ? milestoneStickerLabel(holidayStickerKey)
              : HolidayService.getLocalizedName(h),
          date: occurrence.date,
          type: 'holiday',
          stickerKey:
              h.stickerKey ??
              MilestoneStickerCatalog.holidayKey(occurrence.date),
          diffDays: occurrence.daysFrom(todayMidnight),
        ),
      );
    }

    // 4. Lịch trình chuyến đi
    for (final event in widget.homeCalendarEvents) {
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
      final diff = CalendarCivilDate.daysBetween(todayMidnight, eventDate);
      allEvents.add(
        MilestoneEvent(
          title: evTitle,
          date: eventDate,
          type: 'calendar',
          stickerKey: MilestoneStickerCatalog.calendarKey(evTitle),
          diffDays: diff,
        ),
      );
    }

    // Lọc trùng
    final seen = <String>{};
    final List<MilestoneEvent> uniqueEvents = [];
    for (final e in allEvents) {
      final key = '${e.title}_${e.date.year}-${e.date.month}-${e.date.day}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueEvents.add(e);
      }
    }

    final upcoming = uniqueEvents.where((e) => e.diffDays >= 0).toList();

    // Đã qua: chỉ ghi nhận các sự kiện diễn ra từ ngày bắt đầu tính (startDate) trở đi
    final past = uniqueEvents.where((e) {
      if (e.diffDays >= 0) return false;
      if (startDt != null) {
        final startDtMidnight = DateTime(
          startDt.year,
          startDt.month,
          startDt.day,
        );
        final eventDateMidnight = DateTime(
          e.date.year,
          e.date.month,
          e.date.day,
        );
        return !eventDateMidnight.isBefore(startDtMidnight);
      }
      return true;
    }).toList();

    // Sắp xếp:
    // - Sắp tới: Tăng dần (gần hôm nay nhất lên đầu)
    upcoming.sort((a, b) => a.diffDays.compareTo(b.diffDays));
    // - Đã qua: Giảm dần (mới trôi qua nhất lên đầu)
    past.sort((a, b) => b.diffDays.compareTo(a.diffDays));

    setState(() {
      _upcomingList = upcoming.take(5).toList();
      _pastList = past;
    });
  }

  void _openCalendar() {
    slPush<void>(
      context,
      CalendarScreen(
        houseId: widget.houseId,
        myName:
            widget.houseSettings['nameU1']?.toString() ??
            L10nService().translate('p4_default_you'),
      ),
    ).then((_) {
      if (mounted) _calculateEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = _calendarNow;
    final todayMidnight = DateTime(today.year, today.month, today.day);

    int daysLove = 0;
    if (widget.startDate != null && widget.startDate!.isNotEmpty) {
      try {
        final startDt = DateTime.parse(widget.startDate!);
        final startDtMidnight = DateTime(
          startDt.year,
          startDt.month,
          startDt.day,
        );
        daysLove = CalendarCivilDate.daysBetween(
          startDtMidnight,
          todayMidnight,
        );
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/home/milestones_screen.dart: $error',
        );
      }
    }

    final palette = MilestonePalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                MilestoneNavigationBar(
                  backLabel: context.tr('sticker_love_back'),
                  libraryLabel: context.tr('sticker_love_library_title'),
                  calendarLabel: context.tr('sticker_love_calendar'),
                  onBack: () => Navigator.pop(context),
                  onLibrary: () => slPush<void>(
                    context,
                    const MilestoneStickerGalleryScreen(),
                  ),
                  onCalendar: _openCalendar,
                ),
                Expanded(
                  child: NestedScrollView(
                    physics: SLResponsive.scrollPhysicsForPlatform(),
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        sliver: SliverToBoxAdapter(
                          child: Semantics(
                            header: true,
                            child: Text(
                              context.tr('sticker_love_events_title'),
                              style: SLTheme.quicksand(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                color: palette.ink,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (daysLove > 0)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverToBoxAdapter(
                            child: MilestoneTogetherCard(
                              caption: context.tr('sticker_love_together'),
                              label: milestoneStickerLabel('days_$daysLove'),
                              artwork: MilestoneEmbeddedSticker(
                                'days_$daysLove',
                              ),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        sliver: SliverToBoxAdapter(
                          child: MilestoneTabSelector(
                            controller: _tabController,
                            upcomingLabel: context.tr('sticker_love_upcoming'),
                            pastLabel: context.tr('sticker_love_past'),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      physics: MediaQuery.disableAnimationsOf(context)
                          ? const NeverScrollableScrollPhysics()
                          : const SLPagePhysics(),
                      children: [
                        _buildEventsList(_upcomingList, isUpcoming: true),
                        _buildEventsList(_pastList, isUpcoming: false),
                      ],
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

  String _resolveMilestoneStickerKey(MilestoneEvent event) =>
      event.stickerKey ?? MilestoneStickerCatalog.calendarKey(event.title);

  Widget _buildEventsList(
    List<MilestoneEvent> list, {
    required bool isUpcoming,
  }) {
    if (list.isEmpty) {
      return ListView(
        physics: SLResponsive.scrollPhysicsForPlatform(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MilestoneEmptyCard(
            label: context.tr(
              isUpcoming
                  ? 'sticker_love_empty_upcoming'
                  : 'sticker_love_empty_past',
            ),
            artwork: const MilestoneEmbeddedSticker('moment_first_date'),
            actionLabel: isUpcoming
                ? context.tr('sticker_love_plan_now')
                : null,
            onAction: isUpcoming ? _openCalendar : null,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: SLResponsive.scrollPhysicsForPlatform(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildEventItemCard(list[index], isUpcoming: isUpcoming),
    );
  }

  Widget _buildEventItemCard(MilestoneEvent event, {required bool isUpcoming}) {
    final countdownText = switch ((isUpcoming, event.diffDays)) {
      (true, 0) => context.tr('sticker_love_today'),
      (true, 1) => context.tr('sticker_love_tomorrow'),
      (true, final d) => L10nService().format('sticker_love_days_left', {
        'days': d.toString(),
      }),
      (false, -1) => context.tr('sticker_love_yesterday'),
      (false, _) => L10nService().format('sticker_love_days_passed', {
        'days': event.diffDays.abs().toString(),
      }),
    };
    final (kind, fallbackAsset) = switch (event.type) {
      'birthday' => (
        MilestoneCardKind.birthday,
        'assets/images/anhtomau_stickers/sticker_17.gif',
      ),
      'anniversary' => (
        MilestoneCardKind.anniversary,
        'assets/images/anhtomau_stickers/sticker_14.gif',
      ),
      'holiday' => (
        MilestoneCardKind.holiday,
        'assets/images/anhtomau_stickers/sticker_22.gif',
      ),
      _ => (
        MilestoneCardKind.calendar,
        'assets/images/anhtomau_stickers/sticker_9.gif',
      ),
    };
    return MilestoneEventCard(
      title: event.title,
      dateLabel: DateFormat('EEE, dd MMM yyyy', 'en').format(event.date),
      countdownLabel: countdownText,
      kind: kind,
      isPast: !isUpcoming,
      isToday: isUpcoming && event.diffDays == 0,
      artwork: MilestoneEmbeddedSticker(
        _resolveMilestoneStickerKey(event),
        fallbackAssetPath: fallbackAsset,
      ),
    );
  }
}
