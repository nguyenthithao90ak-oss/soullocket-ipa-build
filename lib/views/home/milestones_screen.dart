import 'package:flutter/material.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../utilities/calendar_screen.dart';
import '../../core/sl_page_physics.dart';


class MilestoneEvent {
  final String title;
  final DateTime date;
  final String type; // 'anniversary' | 'birthday' | 'holiday' | 'calendar'
  final int diffDays; // Countdown days (negative for past events)

  MilestoneEvent({
    required this.title,
    required this.date,
    required this.type,
    required this.diffDays,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _calculateEvents() {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final List<MilestoneEvent> allEvents = [];
    DateTime? startDt;

    if (widget.startDate != null && widget.startDate!.isNotEmpty) {
      try {
        startDt = DateTime.parse(widget.startDate!);
      } catch (_) {}
    }

    // 1. Cột mốc kỷ niệm ngày yêu
    if (startDt != null) {
      final startDtMidnight = DateTime(startDt.year, startDt.month, startDt.day);

      // Cột mốc ngày (cả quá khứ và tương lai)
      final milestoneDays = [
        100, 200, 300, 400, 500, 600, 700, 800, 900, 1000,
        1500, 2000, 2500, 3000, 4000, 5000, 10000
      ];
      for (final m in milestoneDays) {
        final milestoneDate = startDtMidnight.add(Duration(days: m - 1));
        final diff = milestoneDate.difference(todayMidnight).inDays;
        allEvents.add(MilestoneEvent(
          title: L10nService().format('milestone_anniversary_days', {'days': m.toString()}),
          date: milestoneDate,
          type: 'anniversary',
          diffDays: diff,
        ));
      }

      // Cột mốc năm (kỷ niệm năm yêu nhau)
      for (int y = 1; y <= 25; y++) {
        final annivDate = DateTime(startDtMidnight.year + y, startDtMidnight.month, startDtMidnight.day);
        final diff = annivDate.difference(todayMidnight).inDays;
        allEvents.add(MilestoneEvent(
          title: L10nService().format('milestone_anniversary_years', {'years': y.toString()}),
          date: annivDate,
          type: 'anniversary',
          diffDays: diff,
        ));
      }
    }

    // 2. Sinh nhật đôi bạn (dobU1, dobU2)
    final dobU1 = widget.houseSettings['dobU1']?.toString() ?? '';
    final dobU2 = widget.houseSettings['dobU2']?.toString() ?? '';
    final nameU1 = widget.houseSettings['nameU1']?.toString() ?? 'Bạn';
    final nameU2 = widget.houseSettings['nameU2']?.toString() ?? 'Người ấy';

    void computeBirthdays(String dob, String name) {
      if (dob.isEmpty) return;
      try {
        final bday = DateTime.parse(dob);
        // Tính sinh nhật trong năm trước, năm nay, và năm sau
        for (int yearOffset = -1; yearOffset <= 1; yearOffset++) {
          final targetYear = todayMidnight.year + yearOffset;
          int day = bday.day;
          if (bday.month == 2 && bday.day == 29) {
            final isLeap = (targetYear % 4 == 0 && targetYear % 100 != 0) || (targetYear % 400 == 0);
            if (!isLeap) day = 28;
          }
          final bdayDate = DateTime(targetYear, bday.month, day);
          final diff = bdayDate.difference(todayMidnight).inDays;
          allEvents.add(MilestoneEvent(
            title: L10nService().format('milestone_birthday', {'name': name}),
            date: bdayDate,
            type: 'birthday',
            diffDays: diff,
          ));
        }
      } catch (_) {}
    }
    computeBirthdays(dobU1, nameU1);
    computeBirthdays(dobU2, nameU2);

    // 3. Ngày lễ lớn đầy đủ (năm trước, năm nay, năm sau)
    final holidaysList = [
      {'month': 1, 'day': 1, 'name': L10nService().translate('holiday_new_year')},
      {'month': 2, 'day': 14, 'name': L10nService().translate('holiday_valentine')},
      {'month': 3, 'day': 8, 'name': L10nService().translate('holiday_womens_day')},
      {'month': 3, 'day': 14, 'name': L10nService().translate('holiday_white_valentine')},
      {'month': 4, 'day': 1, 'name': L10nService().translate('holiday_april_fools')},
      {'month': 4, 'day': 14, 'name': L10nService().translate('holiday_black_valentine')},
      {'month': 6, 'day': 1, 'name': L10nService().translate('holiday_childrens_day')},
      {'month': 6, 'day': 28, 'name': L10nService().translate('holiday_vietnamese_family_day')},
      {'month': 10, 'day': 20, 'name': L10nService().translate('holiday_vietnamese_womens_day')},
      {'month': 10, 'day': 31, 'name': L10nService().translate('holiday_halloween')},
      {'month': 12, 'day': 24, 'name': L10nService().translate('holiday_christmas_eve')},
      {'month': 12, 'day': 25, 'name': L10nService().translate('holiday_christmas')},
      {'month': 12, 'day': 31, 'name': L10nService().translate('holiday_new_years_eve')},
    ];
    for (final h in holidaysList) {
      for (int yearOffset = -1; yearOffset <= 1; yearOffset++) {
        final targetYear = todayMidnight.year + yearOffset;
        final holidayDate = DateTime(targetYear, h['month'] as int, h['day'] as int);
        final diff = holidayDate.difference(todayMidnight).inDays;
        allEvents.add(MilestoneEvent(
          title: h['name'] as String,
          date: holidayDate,
          type: 'holiday',
          diffDays: diff,
        ));
      }
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
      final diff = eventDate.difference(todayMidnight).inDays;
      allEvents.add(MilestoneEvent(
        title: evTitle,
        date: eventDate,
        type: 'calendar',
        diffDays: diff,
      ));
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
        final startDtMidnight = DateTime(startDt.year, startDt.month, startDt.day);
        final eventDateMidnight = DateTime(e.date.year, e.date.month, e.date.day);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          houseId: widget.houseId,
          myName: widget.houseSettings['nameU1']?.toString() ?? 'Bạn',
        ),
      ),
    ).then((_) {
      _calculateEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    int daysLove = 0;
    if (widget.startDate != null && widget.startDate!.isNotEmpty) {
      try {
        final startDt = DateTime.parse(widget.startDate!);
        final startDtMidnight = DateTime(startDt.year, startDt.month, startDt.day);
        daysLove = todayMidnight.difference(startDtMidnight).inDays + 1;
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      body: Stack(
        children: [
          // Nền gradient ngọt ngào
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFF5F8),
                    Color(0xFFFFEEF4),
                    Color(0xFFF7ECFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.1, 0.5, 0.9],
                ),
              ),
            ),
          ),
          // Các Orb bồng bềnh làm nền sinh động
          Positioned(
            top: -40,
            right: -50,
            child: _buildBackdropOrb(
              size: 220,
              colors: const [Color(0xFFFFB3D1), Color(0xFFE5C3FF)],
            ),
          ),
          Positioned(
            left: -60,
            top: 200,
            child: _buildBackdropOrb(
              size: 180,
              colors: const [Color(0xFFFFC6D9), Color(0xFFFFB0C7)],
              delay: 1500,
            ),
          ),
          Positioned(
            right: -20,
            top: 480,
            child: _buildBackdropOrb(
              size: 140,
              colors: const [Color(0xFFF0C8FF), Color(0xFFFFE0EC)],
              delay: 800,
            ),
          ),
          // Nội dung chính
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar siêu đáng yêu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFFFF5E8B),
                            size: 18,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        L10nService().translate('milestone_title'),
                        style: SLTheme.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF37474F),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFFFF5E8B),
                            size: 20,
                          ),
                        ),
                        onPressed: _openCalendar,
                        tooltip: L10nService().translate('milestone_manage_calendar'),
                      ),
                    ],
                  ),
                ),
                // Banner số ngày yêu nhau xinh xắn
                if (daysLove > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    width: double.infinity,
                    height: 96,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF9EB7), Color(0xFFFF6B95)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B95).withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Watermark cute hearts
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Icon(
                            Icons.favorite,
                            size: 100,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: -20,
                          child: Icon(
                            Icons.favorite_border,
                            size: 50,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Image.asset('assets/images/interaction_stickers/custom/numbered/sticker_005.png'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      L10nService().translate('milestone_together_for'),
                                      style: SLTheme.quicksand(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      L10nService().format('milestone_love_days', {'days': daysLove.toString()}),
                                      style: SLTheme.quicksand(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Custom TabBar kiểu bong bóng kẹo ngọt
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCEBCD0).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF8E7A8A),
                    labelStyle: SLTheme.quicksand(fontWeight: FontWeight.w900, fontSize: 13.5),
                    unselectedLabelStyle: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 13.5),
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9EBA), Color(0xFFFF6D97)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6D97).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.hourglass_empty_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(L10nService().translate('milestone_tab_upcoming')),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(L10nService().translate('milestone_tab_past')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    physics: const SLPagePhysics(),
                    controller: _tabController,
                    children: [
                      _buildEventsList(_upcomingList, isUpcoming: true),
                      _buildEventsList(_pastList, isUpcoming: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<MilestoneEvent> list, {required bool isUpcoming}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC0CB), width: 2),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset('assets/images/interaction_stickers/custom/numbered/sticker_158.png'), // Thỏ ôm tim/chờ đợi
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isUpcoming ? L10nService().translate('milestone_empty_upcoming') : L10nService().translate('milestone_empty_past'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7E6475),
                  height: 1.4,
                ),
              ),
              if (isUpcoming) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openCalendar,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(L10nService().translate('milestone_plan_now'), style: SLTheme.quicksand(fontWeight: FontWeight.w800, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D97),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFFFF6D97).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final event = list[index];
        return _buildEventItemCard(event, isUpcoming: isUpcoming);
      },
    );
  }

  Widget _buildEventItemCard(MilestoneEvent event, {required bool isUpcoming}) {
    String countdownText = '';
    Color badgeBgColor;
    Color badgeTextColor;

    if (isUpcoming) {
      if (event.diffDays == 0) {
        countdownText = L10nService().translate('milestone_today');
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
      } else if (event.diffDays == 1) {
        countdownText = L10nService().translate('milestone_tomorrow');
        badgeBgColor = const Color(0xFFECFEFF);
        badgeTextColor = const Color(0xFF155E75);
      } else {
        countdownText = L10nService().format('milestone_days_left', {'days': event.diffDays.toString()});
        badgeBgColor = const Color(0xFFFCE7F3);
        badgeTextColor = const Color(0xFF9D174D);
      }
    } else {
      final passedDays = event.diffDays.abs();
      if (passedDays == 1) {
        countdownText = L10nService().translate('milestone_yesterday');
        badgeBgColor = const Color(0xFFF1F5F9);
        badgeTextColor = const Color(0xFF475569);
      } else {
        countdownText = L10nService().format('milestone_days_passed', {'days': passedDays.toString()});
        badgeBgColor = const Color(0xFFF1F5F9);
        badgeTextColor = const Color(0xFF475569);
      }
    }

    String stickerPath;
    Color iconBgColor;
    switch (event.type) {
      case 'birthday':
        stickerPath = 'assets/images/interaction_stickers/custom/numbered/sticker_108.png';
        iconBgColor = const Color(0xFFFEF3C7);
        break;
      case 'anniversary':
        stickerPath = 'assets/images/interaction_stickers/custom/numbered/sticker_005.png';
        iconBgColor = const Color(0xFFFCE7F3);
        break;
      case 'holiday':
        stickerPath = 'assets/images/interaction_stickers/custom/numbered/sticker_008.png';
        iconBgColor = const Color(0xFFEDE9FE);
        break;
      case 'calendar':
      default:
        stickerPath = 'assets/images/interaction_stickers/custom/numbered/sticker_008.png';
        iconBgColor = const Color(0xFFDBEAFE);
        break;
    }

    final weekdays = [
      L10nService().translate('milestone_weekday_1'),
      L10nService().translate('milestone_weekday_2'),
      L10nService().translate('milestone_weekday_3'),
      L10nService().translate('milestone_weekday_4'),
      L10nService().translate('milestone_weekday_5'),
      L10nService().translate('milestone_weekday_6'),
      L10nService().translate('milestone_weekday_7')
    ];
    final weekdayStr = weekdays[event.date.weekday - 1];
    final formattedDate = '$weekdayStr, ${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}/${event.date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB3CA).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(stickerPath),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formattedDate,
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF78909C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: badgeTextColor.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  countdownText,
                  style: SLTheme.quicksand(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackdropOrb({
    required double size,
    required List<Color> colors,
    int delay = 0,
  }) {
    return _FloatingOrb(
      size: size,
      colors: colors,
      delayMilliseconds: delay,
    );
  }
}

class _FloatingOrbState extends State<_FloatingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (widget.delayMilliseconds > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMilliseconds), () {
        if (mounted) _controller.repeat(reverse: true);
      });
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -20.0 * _animation.value),
          child: child,
        );
      },
      child: IgnorePointer(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.colors.first.withValues(alpha: 0.8),
                widget.colors.last.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingOrb extends StatefulWidget {
  final double size;
  final List<Color> colors;
  final int delayMilliseconds;

  const _FloatingOrb({
    required this.size,
    required this.colors,
    this.delayMilliseconds = 0,
  });

  @override
  State<_FloatingOrb> createState() => _FloatingOrbState();
}
