import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../utilities/calendar_screen.dart';
import '../../core/sl_page_physics.dart';

class MilestoneEvent {
  final String title;
  final DateTime date;
  final String type; // 'anniversary' | 'birthday' | 'holiday' | 'calendar'
  final int diffDays; // Countdown days (negative for past events)
  final int? daysCount; // Số ngày cụ thể (dùng để chọn sticker milestone)

  MilestoneEvent({
    required this.title,
    required this.date,
    required this.type,
    required this.diffDays,
    this.daysCount,
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
      final startDtMidnight =
          DateTime(startDt.year, startDt.month, startDt.day);

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
        10000
      ];
      for (final m in milestoneDays) {
        final milestoneDate = startDtMidnight.add(Duration(days: m - 1));
        final diff = milestoneDate.difference(todayMidnight).inDays;
        allEvents.add(MilestoneEvent(
          title: L10nService()
              .format('milestone_anniversary_days', {'days': m.toString()}),
          date: milestoneDate,
          type: 'anniversary',
          diffDays: diff,
          daysCount: m,
        ));
      }

      // Cột mốc tháng (kỷ niệm tháng yêu nhau: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 tháng)
      final milestoneMonths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
      for (final m in milestoneMonths) {
        final milestoneDate = DateTime(
          startDtMidnight.year,
          startDtMidnight.month + m,
          startDtMidnight.day,
        );
        final diff = milestoneDate.difference(todayMidnight).inDays;
        final title = L10nService().localeCode == 'vi'
            ? 'Kỷ niệm $m tháng bên nhau 💖'
            : 'Celebrating $m months of love 💖';
        // Tính số ngày xấp xỉ cho tháng (để chọn sticker)
        allEvents.add(MilestoneEvent(
          title: title,
          date: milestoneDate,
          type: 'anniversary',
          diffDays: diff,
          daysCount: -m, // Dùng âm để đánh dấu là tháng (không phải ngày)
        ));
      }

      // Cột mốc năm (kỷ niệm năm yêu nhau)
      for (int y = 1; y <= 25; y++) {
        final annivDate = DateTime(startDtMidnight.year + y,
            startDtMidnight.month, startDtMidnight.day);
        final diff = annivDate.difference(todayMidnight).inDays;
        allEvents.add(MilestoneEvent(
          title: L10nService()
              .format('milestone_anniversary_years', {'years': y.toString()}),
          date: annivDate,
          type: 'anniversary',
          diffDays: diff,
          daysCount: -(y * 100 + 1000), // Dùng mã âm đặc biệt để đánh dấu năm
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
            final isLeap = (targetYear % 4 == 0 && targetYear % 100 != 0) ||
                (targetYear % 400 == 0);
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
      {
        'month': 1,
        'day': 1,
        'name': L10nService().translate('holiday_new_year')
      },
      {
        'month': 2,
        'day': 14,
        'name': L10nService().translate('holiday_valentine')
      },
      {
        'month': 3,
        'day': 8,
        'name': L10nService().translate('holiday_womens_day')
      },
      {
        'month': 3,
        'day': 14,
        'name': L10nService().translate('holiday_white_valentine')
      },
      {
        'month': 4,
        'day': 1,
        'name': L10nService().translate('holiday_april_fools')
      },
      {
        'month': 4,
        'day': 14,
        'name': L10nService().translate('holiday_black_valentine')
      },
      {
        'month': 6,
        'day': 1,
        'name': L10nService().translate('holiday_childrens_day')
      },
      {
        'month': 6,
        'day': 28,
        'name': L10nService().translate('holiday_vietnamese_family_day')
      },
      {
        'month': 10,
        'day': 20,
        'name': L10nService().translate('holiday_vietnamese_womens_day')
      },
      {
        'month': 10,
        'day': 31,
        'name': L10nService().translate('holiday_halloween')
      },
      {
        'month': 12,
        'day': 24,
        'name': L10nService().translate('holiday_christmas_eve')
      },
      {
        'month': 12,
        'day': 25,
        'name': L10nService().translate('holiday_christmas')
      },
      {
        'month': 12,
        'day': 31,
        'name': L10nService().translate('holiday_new_years_eve')
      },
    ];
    for (final h in holidaysList) {
      for (int yearOffset = -1; yearOffset <= 1; yearOffset++) {
        final targetYear = todayMidnight.year + yearOffset;
        final holidayDate =
            DateTime(targetYear, h['month'] as int, h['day'] as int);
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
        final startDtMidnight =
            DateTime(startDt.year, startDt.month, startDt.day);
        final eventDateMidnight =
            DateTime(e.date.year, e.date.month, e.date.day);
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

  /// Trả về đường dẫn sticker milestone phù hợp với số ngày/tháng/năm.
  /// daysCount:
  ///   > 0: số ngày chính xác (100, 200, 365...)
  ///   < 0 và > -100: số tháng âm (-1 → 1 tháng, -11 → 11 tháng)
  ///   <= -1000: mã năm âm (-(y*100+1000) → y năm)
  String _getMilestoneSticker(int? daysCount) {
    const base = 'assets/images/milestone_stickers';
    const fallback = 'assets/images/milestone_stickers_2/ms_ngay_dac_biet.webp';

    if (daysCount == null) return fallback;

    // Trường hợp NĂM (mã âm đặc biệt <= -1000)
    if (daysCount <= -1000) {
      final years = ((-daysCount) - 1000) ~/ 100;
      final yearMap = {
        1: 'ms_1nam_365b.webp',
        2: 'ms_1nam_2nam.webp',
        3: 'ms_3nam.webp',
        4: 'ms_4nam.webp',
        5: 'ms_5nam.webp',
        6: 'ms_6nam.webp',
        7: 'ms_7nam.webp',
        8: 'ms_8nam.webp',
        9: 'ms_9nam.webp',
        10: 'ms_10nam.webp',
      };
      return yearMap.containsKey(years) ? '$base/${yearMap[years]}' : fallback;
    }

    // Trường hợp THÁNG (âm từ -1 đến -11)
    if (daysCount < 0) {
      final months = -daysCount;
      if (months >= 1 && months <= 12) {
        return 'assets/images/milestone_stickers_2/ms_thang_$months.webp';
      }
      return fallback;
    }

    // Trường hợp NGÀY (> 0)
    return _getStickerByDays(daysCount, base, fallback);
  }

  String _getStickerByDays(int days, String base, String fallback) {
    // Map chính xác
    final exactMap = {
      1:    'ms_1ngay.webp',
      7:    'ms_7ngay.webp',
      10:   'ms_10ngay.webp',
      14:   'ms_14ngay.webp',
      20:   'ms_20ngay.webp',
      30:   'ms_30ngay_a.webp',
      40:   'ms_40ngay.webp',
      50:   'ms_50ngay_a.webp',
      60:   'ms_60ngay.webp',
      70:   'ms_70ngay.webp',
      80:   'ms_80ngay.webp',
      90:   'ms_90ngay.webp',
      100:  'ms_100ngay_a.webp',
      111:  'ms_111ngay.webp',
      120:  'ms_120ngay.webp',
      130:  'ms_130ngay.webp',
      140:  'ms_140ngay.webp',
      150:  'ms_150ngay.webp',
      160:  'ms_160ngay.webp',
      170:  'ms_170ngay.webp',
      180:  'ms_180ngay.webp',
      190:  'ms_190ngay.webp',
      200:  'ms_200ngay.webp',
      210:  'ms_210ngay.webp',
      220:  'ms_220ngay.webp',
      230:  'ms_230ngay.webp',
      240:  'ms_240ngay.webp',
      250:  'ms_250ngay.webp',
      260:  'ms_260ngay.webp',
      270:  'ms_270ngay.webp',
      280:  'ms_280ngay.webp',
      290:  'ms_290ngay.webp',
      300:  'ms_300ngay.webp',
      310:  'ms_310ngay.webp',
      320:  'ms_320ngay.webp',
      330:  'ms_330ngay.webp',
      340:  'ms_340ngay.webp',
      350:  'ms_350ngay.webp',
      360:  'ms_360ngay.webp',
      365:  'ms_365ngay_a.webp',
      400:  'ms_400ngay.webp',
      500:  'ms_500ngay.webp',
      600:  'ms_600ngay.webp',
      700:  'ms_700ngay.webp',
      730:  'ms_730ngay.webp',
      800:  'ms_800ngay_a.webp',
      900:  'ms_900ngay.webp',
      1000: 'ms_1000ngay.webp',
      1001: 'ms_1001ngay.webp',
      1460: 'ms_1460ngay.webp',
      1500: 'ms_1460ngay.webp',
      1825: 'ms_1825ngay.webp',
      2000: 'ms_2000ngay.webp',
      2500: 'ms_2000ngay.webp',
      3000: 'ms_3000ngay.webp',
      4000: 'ms_4000ngay.webp',
      5000: 'ms_5000ngay.webp',
      6000: 'ms_6000ngay.webp',
      7000: 'ms_7000ngay.webp',
      8000: 'ms_8000ngay.webp',
      9000: 'ms_9000ngay.webp',
      10000: 'ms_10000ngay.webp',
    };

    if (exactMap.containsKey(days)) {
      return '$base/${exactMap[days]}';
    }

    // Fallback về gần nhất
    final keys = exactMap.keys.toList()..sort();
    int closest = keys.first;
    for (final k in keys) {
      if ((k - days).abs() < (closest - days).abs()) closest = k;
    }
    return '$base/${exactMap[closest]}';
  }


  String _getHolidaySticker(MilestoneEvent event) {
    const base = 'assets/images/milestone_stickers_2';
    final d = event.date.day;
    final m = event.date.month;
    
    if (d == 1 && m == 1) return '$base/ms_tet_duong_lich_1_1.webp';
    if (d == 14 && m == 2) return '$base/ms_valentine_14_2.webp';
    if (d == 8 && m == 3) return '$base/ms_quoc_te_phu_nu_8_3.webp';
    if (d == 20 && m == 3) return '$base/ms_quoc_te_hanh_phuc_20_3.webp';
    if (d == 30 && m == 4) return '$base/ms_giai_phong_mien_nam_30_4.webp';
    if (d == 1 && m == 5) return '$base/ms_quoc_te_lao_dong_1_5.webp';
    if (d == 1 && m == 6) return '$base/ms_tet_thieu_nhi_1_6.webp';
    if (d == 20 && m == 11) return '$base/ms_ngay_nha_giao_20_11.webp';
    if (d == 25 && m == 12) return '$base/ms_giang_sinh_25_12.webp';
    
    final title = event.title.toLowerCase();
    if (title.contains('tết nguyên đán') || title.contains('lunar new year')) {
      return '$base/ms_tet_nguyen_dan.webp';
    }
    if (title.contains('giỗ tổ') || title.contains('hùng vương')) {
      return '$base/ms_gio_to_hung_vuong.webp';
    }
    
    return '$base/ms_chuc_mung.webp';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    int daysLove = 0;
    if (widget.startDate != null && widget.startDate!.isNotEmpty) {
      try {
        final startDt = DateTime.parse(widget.startDate!);
        final startDtMidnight =
            DateTime(startDt.year, startDt.month, startDt.day);
        daysLove = todayMidnight.difference(startDtMidnight).inDays;
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
                    Color(0xFFFFF4F8),
                    Color(0xFFFFEEF5),
                    Color(0xFFF6ECFF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Các Orb bồng bềnh làm nền sinh động
          Positioned(
            top: -40,
            right: -50,
            child: _buildBackdropOrb(
              size: 240,
              colors: const [Color(0xFFFFB3D1), Color(0xFFE5C3FF)],
            ),
          ),
          Positioned(
            left: -60,
            top: 200,
            child: _buildBackdropOrb(
              size: 190,
              colors: const [Color(0xFFFFC6D9), Color(0xFFFFB0C7)],
              delay: 1500,
            ),
          ),
          Positioned(
            right: -20,
            top: 480,
            child: _buildBackdropOrb(
              size: 150,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFFFF4D7D),
                            size: 18,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        L10nService().translate('milestone_title'),
                        style: SLTheme.quicksand(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFFFF4D7D),
                            size: 20,
                          ),
                        ),
                        onPressed: _openCalendar,
                        tooltip: L10nService()
                            .translate('milestone_manage_calendar'),
                      ),
                    ],
                  ),
                ),
                // Banner số ngày yêu nhau xinh xắn
                if (daysLove > 0)
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    width: double.infinity,
                    height: 100,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF85A2),
                                  Color(0xFFFF4D7D),
                                  Color(0xFFFF6584)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4D7D)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Soft highlight line top
                        Positioned(
                          top: 0,
                          left: 20,
                          right: 20,
                          height: 1.5,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Watermark cute hearts
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Icon(
                            Icons.favorite,
                            size: 110,
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: -20,
                          child: Icon(
                            Icons.favorite_border,
                            size: 55,
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(0.0),
                                    child: R2StickerImage(
                                        'assets/images/milestone_stickers_2/ms_ky_niem.webp'),
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
                                      L10nService()
                                          .translate('milestone_together_for'),
                                      style: SLTheme.quicksand(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            Colors.white.withValues(alpha: 0.95),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      L10nService().format(
                                          'milestone_love_days',
                                          {'days': daysLove.toString()}),
                                      style: SLTheme.quicksand(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        shadows: [
                                          const Shadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
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
                      ],
                    ),
                  ),
                // Custom TabBar kiểu bong bóng kẹo ngọt
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCEBCD0).withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF7E6475),
                    labelStyle: SLTheme.quicksand(
                        fontWeight: FontWeight.w900, fontSize: 13.5),
                    unselectedLabelStyle: SLTheme.quicksand(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7E9B), Color(0xFFFF4D7D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D7D).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    tabs: [
                      Tab(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.hourglass_empty_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(L10nService()
                                .translate('milestone_tab_upcoming')),
                          ],
                        ),
                      ),
                      Tab(
                        height: 38,
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

  Widget _buildEventsList(List<MilestoneEvent> list,
      {required bool isUpcoming}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC0CB), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC0CB).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(2.0),
                    child: R2StickerImage(
                        'assets/images/milestone_stickers_2/ms_ngay_dac_biet.webp'), 
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isUpcoming
                    ? L10nService().translate('milestone_empty_upcoming')
                    : L10nService().translate('milestone_empty_past'),
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
                  label: Text(L10nService().translate('milestone_plan_now'),
                      style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D7D),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFFFF4D7D).withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
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
    final (countdownText, badgeBgColors, badgeBorderColor, badgeTextColor) =
        switch ((isUpcoming, event.diffDays)) {
      (true, 0) => (
          L10nService().translate('milestone_today'),
          const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
          const Color(0xFF86EFAC),
          const Color(0xFF15803D)
        ),
      (true, 1) => (
          L10nService().translate('milestone_tomorrow'),
          const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
          const Color(0xFF7DD3FC),
          const Color(0xFF0369A1)
        ),
      (true, final d) => (
          L10nService().format('milestone_days_left', {'days': d.toString()}),
          const [Color(0xFFFFF0F5), Color(0xFFFFE4EC)],
          const Color(0xFFFFC0CB),
          const Color(0xFF9D174D)
        ),
      (false, -1) => (
          L10nService().translate('milestone_yesterday'),
          const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          const Color(0xFFE2E8F0),
          const Color(0xFF475569)
        ),
      (false, _) => (
          L10nService().format('milestone_days_passed',
              {'days': event.diffDays.abs().toString()}),
          const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          const Color(0xFFE2E8F0),
          const Color(0xFF475569)
        ),
    };

    String stickerPath;
    List<Color> iconGradients;
    switch (event.type) {
      case 'birthday':
        stickerPath = 'assets/images/milestone_stickers_2/ms_sinh_nhat.webp';
        iconGradients = const [Color(0xFFFFF3C4), Color(0xFFFFE082)];
        break;
      case 'anniversary':
        stickerPath = _getMilestoneSticker(event.daysCount);
        iconGradients = const [Color(0xFFFFD1E1), Color(0xFFFFB2CC)];
        break;
      case 'holiday':
        stickerPath = _getHolidaySticker(event);
        iconGradients = const [Color(0xFFE9D5FF), Color(0xFFD8B4FE)];
        break;
      default:
        stickerPath = 'assets/images/milestone_stickers_2/ms_ngay_dac_biet.webp';
        iconGradients = const [Color(0xFFBAE6FD), Color(0xFF7DD3FC)];
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
    final formattedDate =
        '$weekdayStr, ${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}/${event.date.year}';

    final bool isMajorEvent = event.type == 'birthday' ||
        (event.type == 'anniversary' &&
            (event.daysCount == null || event.daysCount! > 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: isMajorEvent
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9EB7).withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8), width: 1.2),
            ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: isMajorEvent ? 14 : 10),
          child: Row(
            children: [
              Transform.rotate(
                angle: -0.03,
                child: Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: iconGradients,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradients.last.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: R2StickerImage(stickerPath),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2C3437),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF78909C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: badgeBgColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badgeBorderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: badgeTextColor.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  countdownText,
                  style: SLTheme.quicksand(
                    fontSize: 11,
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

