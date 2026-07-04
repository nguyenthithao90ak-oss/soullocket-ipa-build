import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:ui' as ui;
import '../../utils/services/notification_service.dart';
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';
import 'calendar/dialogs/calendar_quick_add_sheet.dart';
import 'calendar/widgets/calendar_background_decor.dart';
import 'calendar/widgets/calendar_event_input_panel.dart';
import 'calendar/widgets/calendar_event_list_section.dart';
import 'calendar/widgets/calendar_header_section.dart';
import 'calendar/widgets/calendar_selected_day_summary.dart';

class CalendarScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const CalendarScreen(
      {super.key, required this.houseId, required this.myName});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Stream<DatabaseEvent> _selectedDayStream;

  final TextEditingController _eventController = TextEditingController();

  Map<DateTime, List<dynamic>> _events = {};
  StreamSubscription<DatabaseEvent>? _calendarSubscription;
  Timer? _debounceTimer;
  bool _isQuickAddSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedDayStream = _dbRef
        .child('houses/${widget.houseId}/calendar/${_getDateKey(_focusedDay)}')
        .onValue;
    _loadEvents();
  }

  void _loadEvents() {
    _calendarSubscription = _dbRef
        .child('houses/${widget.houseId}/calendar')
        .onValue
        .listen((event) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        if (event.snapshot.value == null) {
          setState(() {
            _events = {};
          });
          return;
        }

        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final Map<DateTime, List<dynamic>> newEvents = {};

        data.forEach((dateKey, dateEvents) {
          final parts = dateKey.toString().split('-');
          if (parts.length == 3) {
            final year = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final day = int.tryParse(parts[2]);
            if (year != null && month != null && day != null) {
              final date = DateTime.utc(year, month, day);
              final eventsMap = Map<dynamic, dynamic>.from(dateEvents as Map);
              newEvents[date] = eventsMap.entries
                  .map((e) => {
                        'key': e.key,
                        ...Map<String, dynamic>.from(e.value as Map)
                      })
                  .toList();
            }
          }
        });

        setState(() {
          _events = newEvents;
        });
      });
    });
  }

  String _getDateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    final raw = _events[_normalizeDate(day)] ?? const <dynamic>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort(
        (a, b) => (a['ts'] as int? ?? 0).compareTo(b['ts'] as int? ?? 0),
      );
  }

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

  bool _isToday(DateTime date) => isSameDay(date, DateTime.now());

  bool _isTomorrow(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final target = DateTime(date.year, date.month, date.day);
    return isSameDay(tomorrow, target);
  }

  Color _selectedAccent(DateTime date) {
    if (_isPastDate(date)) {
      return const Color(0xFFE46A7A);
    }
    if (_isToday(date)) {
      return const Color(0xFF2157F2);
    }
    if (_isTomorrow(date)) {
      return const Color(0xFF0E9F8D);
    }
    return const Color(0xFFFF8A65);
  }

  String _weekdayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return context.tr('util_thhai_5bb9bc');
      case DateTime.tuesday:
        return context.tr('util_thba_daeb4b');
      case DateTime.wednesday:
        return context.tr('util_tht_1bd584');
      case DateTime.thursday:
        return context.tr('util_thnm_f3409d');
      case DateTime.friday:
        return context.tr('util_thsu_f2726e');
      case DateTime.saturday:
        return context.tr('util_thby_7d9b56');
      case DateTime.sunday:
        return context.tr('util_chnht_3ab601');
      default:
        return context.tr('util_hmnay_928c25');
    }
  }

  String _monthName(int month) {
    final months = <String>[
      context.tr('util_thng1_db2569'),
      context.tr('util_thng2_afb937'),
      context.tr('util_thng3_b426e8'),
      context.tr('util_thng4_a41472'),
      context.tr('util_thng5_421305'),
      context.tr('util_thng6_09ac20'),
      context.tr('util_thng7_736c97'),
      context.tr('util_thng8_7c30f4'),
      context.tr('util_thng9_b91fa1'),
      context.tr('util_thng10_592fc9'),
      context.tr('util_thng11_1bfbf7'),
      context.tr('util_thng12_8dffb8'),
    ];
    return months[month - 1];
  }

  String _formatDisplayDate(DateTime date) {
    return '${_weekdayName(date)}, ${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatCreatedTime(int timestamp) {
    if (timestamp <= 0) {
      return context.tr('util_khngrgito_22882c');
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _selectedDayBadge(DateTime date) {
    if (_isToday(date)) {
      return context.tr('util_hmnay_928c25');
    }
    if (_isTomorrow(date)) {
      return context.tr('util_ngymai_cd64f0');
    }
    if (_isPastDate(date)) {
      return context.tr('util_qua_8ff9a0');
    }
    return context.tr('util_spti_c7f0f9');
  }

  String _selectedDayDescription(DateTime date, int eventCount) {
    if (_isToday(date)) {
      return eventCount == 0
          ? context.tr('util_hmnayangtr_1d1c51')
          : L10nService()
              .format('util_calendar_today_with_count', {'count': eventCount});
    }
    if (_isTomorrow(date)) {
      return eventCount == 0
          ? context.tr('util_ngymaichac_c9028e')
          : L10nService().format(
              'util_calendar_tomorrow_with_count', {'count': eventCount});
    }
    if (_isPastDate(date)) {
      return eventCount == 0
          ? context.tr('util_ngynyquavc_7fd2b2')
          : L10nService()
              .format('util_calendar_past_with_count', {'count': eventCount});
    }
    return eventCount == 0
        ? context.tr('util_ngynyangtr_12488d')
        : L10nService()
            .format('util_calendar_day_with_count', {'count': eventCount});
  }

  Future<bool> _saveEventForDay({
    required DateTime day,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return false;
    }

    final dateKey = _getDateKey(day);
    final daySnap =
        await _dbRef.child('houses/${widget.houseId}/calendar/$dateKey').get();
    if (daySnap.exists && daySnap.value is Map) {
      final dayMap = daySnap.value as Map;
      if (dayMap.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Một ngày chỉ có thể có tối đa 5 sự kiện. Vui lòng xoá bớt trước khi thêm mới.'),
          backgroundColor: SLColors.danger,
        ));
        return false;
      }
    }

    await _dbRef
        .child('houses/${widget.houseId}/calendar/$dateKey')
        .push()
        .set({
      'title': cleanText,
      'author': widget.myName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    _scheduleEventNotifications(day, cleanText);
    if (Platform.isAndroid) {
      unawaited(WidgetService.syncCalendarWidgetData(houseId: widget.houseId));
    }
    return true;
  }

  Future<void> _addEvent() async {
    final selectedDay = _selectedDay;
    if (selectedDay == null) return;

    final added = await _saveEventForDay(
      day: selectedDay,
      text: _eventController.text,
    );
    if (!added) {
      return;
    }

    // Cài đặt thông báo cục bộ

    _eventController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _showQuickAddSheet(DateTime day) async {
    if (_isQuickAddSheetOpen || !mounted) {
      return;
    }

    _isQuickAddSheetOpen = true;
    try {
      final mediaSize = MediaQuery.sizeOf(context);
      final added = await showCalendarQuickAddSheet(
        context: context,
        compact: _useCompactLayout(mediaSize),
        accent: _selectedAccent(day),
        eventCount: _eventsForDay(day).length,
        formattedDate: _formatShortDate(day),
        onSubmit: (text) => _saveEventForDay(day: day, text: text),
      );
      if (added && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10nService().format('util_calendar_added_for_date',
                  {'date': _formatShortDate(day)}),
            ),
          ),
        );
      }
    } finally {
      _isQuickAddSheetOpen = false;
    }
  }

  void _selectDay(DateTime selected, DateTime focused) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
      _selectedDayStream = _dbRef
          .child('houses/${widget.houseId}/calendar/${_getDateKey(selected)}')
          .onValue;
    });
  }

  void _handleDayLongPressed(DateTime selected, DateTime focused) {
    _selectDay(selected, focused);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showQuickAddSheet(selected);
    });
  }

  void _scheduleEventNotifications(DateTime eventDate, String eventTitle) {
    final now = DateTime.now();
    // Normalize eventDate to 9:00 AM
    final scheduleTime =
        DateTime(eventDate.year, eventDate.month, eventDate.day, 9, 0);

    // Nếu ngày sự kiện là hôm nay và chưa qua 9h sáng
    if (scheduleTime.isAfter(now)) {
      NotificationService().scheduleLocalNotification(
        id: scheduleTime.millisecondsSinceEpoch ~/ 1000,
        title: context.tr('util_calendar_today_title'),
        body: L10nService()
            .format('util_calendar_reminder_body', {'title': eventTitle}),
        scheduledDate: scheduleTime,
      );
    }

    // Thông báo trước 1 ngày
    final dayBefore = scheduleTime.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      NotificationService().scheduleLocalNotification(
        id: (dayBefore.millisecondsSinceEpoch ~/ 1000) + 1,
        title: context.tr('util_nhcnhngyma_b07d5b'),
        body: L10nService()
            .format('util_calendar_upcoming_body', {'title': eventTitle}),
        scheduledDate: dayBefore,
      );
    }
  }

  void _deleteEvent(String dateKey, String eventId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá sự kiện'),
        content: const Text('Bạn có chắc chắn muốn xoá sự kiện này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _doDeleteEvent(dateKey, eventId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  void _doDeleteEvent(String dateKey, String eventId) {
    _dbRef
        .child('houses/${widget.houseId}/calendar/$dateKey/$eventId')
        .remove()
        .then((_) {
      if (mounted && Platform.isAndroid) {
        unawaited(
            WidgetService.syncCalendarWidgetData(houseId: widget.houseId));
      }
    });
  }

  void _showUsageGuide() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1B2A36),
        title: Text(
          'Lịch & Sự kiện',
          style: SLTheme.quicksand(
              fontWeight: FontWeight.w900, color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 4),
              Text(
                  '- Ghi nhớ ngày kỷ niệm, ngày sinh nhật, hoặc các lịch hẹn hò quan trọng.\n- Hệ thống sẽ tự động nhắc nhở trước sự kiện.',
                  style: TextStyle(color: Colors.white70)),
              SizedBox(height: 12),
              Text('Cách sử dụng:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 4),
              Text(
                  '- Bấm chọn ngày, nhập nội dung sự kiện và lưu lại.\n- Các sự kiện quan trọng có thể được xem lại và nhận thông báo nhắc nhở trước 1 ngày.',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu',
                style: TextStyle(color: Color(0xFF64B5F6))),
          ),
        ],
      ),
    );
  }

  Widget _buildPinWidgetTile(bool compact) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF758C), // Coral Pink
            Color(0xFFFF7EB3), // Soft Pink
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.hideCurrentSnackBar();
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đang gửi yêu cầu... Nếu không thấy phản hồi, vui lòng nhấn giữ màn hình chính để tự thêm thủ công nhé! ✨',
                  ),
                  duration: Duration(seconds: 5),
                ),
              );
              await WidgetService.requestPinCalendarWidget();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: compact ? 40 : 44,
                    height: compact ? 40 : 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_to_home_screen_rounded,
                      color: Color(0xFFFF758C),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thêm tiện ích ra màn hình chính',
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 14 : 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ghim lịch trình & đếm ngược chuyến đi ra màn hình chính',
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: compact ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _calendarSubscription?.cancel();
    _debounceTimer?.cancel();
    _eventController.dispose();
    super.dispose();
  }

  double _horizontalInsetForWidth(double width) {
    if (width <= 360) {
      return 8;
    }
    if (width <= 420) {
      return 10;
    }
    return 18;
  }

  bool _useCompactLayout(Size size) {
    return size.width <= 380 || size.height <= 760;
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final horizontalInset = _horizontalInsetForWidth(mediaSize.width);
    final compact = _useCompactLayout(mediaSize);
    final selectedDay = _selectedDay;
    final eventCount =
        selectedDay == null ? 0 : _eventsForDay(selectedDay).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'LICH CHUNG',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('util_hngdnsdng_14c212'),
            onPressed: _showUsageGuide,
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: CalendarBackgroundDecor()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  CalendarHeaderSection(
                    horizontalInset: horizontalInset,
                    compact: compact,
                    calendarFormat: _calendarFormat,
                    focusedDay: _focusedDay,
                    selectedDay: selectedDay,
                    eventLoader: (day) =>
                        _events[_normalizeDate(day)] ?? const <dynamic>[],
                    onDaySelected: _selectDay,
                    onDayLongPressed: _handleDayLongPressed,
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() => _calendarFormat = format);
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                  if (selectedDay != null) ...[
                    CalendarSelectedDaySummary(
                      horizontalInset: horizontalInset,
                      compact: compact,
                      accent: _selectedAccent(selectedDay),
                      leadingIcon: _isPastDate(selectedDay)
                          ? Icons.history_rounded
                          : Icons.event_available_rounded,
                      displayDate: _formatDisplayDate(selectedDay),
                      description:
                          _selectedDayDescription(selectedDay, eventCount),
                      badgeLabel: _selectedDayBadge(selectedDay),
                      shortDateLabel: _formatShortDate(selectedDay),
                      eventCount: eventCount,
                    ),
                    if (Platform.isAndroid) ...[
                      SizedBox(height: compact ? 12 : 16),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: horizontalInset),
                        child: _buildPinWidgetTile(compact),
                      ),
                    ],
                    SizedBox(height: compact ? 12 : 16),
                    CalendarEventInputPanel(
                      horizontalInset: horizontalInset,
                      compact: compact,
                      accent: _selectedAccent(selectedDay),
                      eventCount: eventCount,
                      controller: _eventController,
                      onAdd: _addEvent,
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    CalendarEventListSection(
                      stream: _selectedDayStream,
                      horizontalInset: horizontalInset,
                      compact: compact,
                      accent: _selectedAccent(selectedDay),
                      selectedDateLabel: _formatShortDate(selectedDay),
                      itemCount: eventCount,
                      statusLabel: _selectedDayBadge(selectedDay),
                      formatCreatedTime: _formatCreatedTime,
                      onDelete: (eventId) =>
                          _deleteEvent(_getDateKey(selectedDay), eventId),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
