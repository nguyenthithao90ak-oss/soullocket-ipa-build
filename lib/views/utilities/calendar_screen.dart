import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:ui' as ui;
import '../../services/notification_service.dart';
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';
import 'calendar/dialogs/calendar_quick_add_sheet.dart';
import 'calendar/widgets/calendar_background_decor.dart';
import 'calendar/widgets/calendar_event_input_panel.dart';
import 'calendar/widgets/calendar_event_list_section.dart';
import 'calendar/widgets/calendar_header_section.dart';
import 'calendar/widgets/calendar_info_pill.dart';
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

  final TextEditingController _eventController = TextEditingController();

  Map<DateTime, List<dynamic>> _events = {};
  StreamSubscription<DatabaseEvent>? _calendarSubscription;
  bool _isQuickAddSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  void _loadEvents() {
    _calendarSubscription = _dbRef
        .child('houses/${widget.houseId}/calendar')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) {
        if (mounted) {
          setState(() {
            _events = {};
          });
        }
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

      if (mounted) {
        setState(() {
          _events = newEvents;
        });
      }
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
          : L10nService().format('util_calendar_today_with_count', {'count': eventCount});
    }
    if (_isTomorrow(date)) {
      return eventCount == 0
          ? context.tr('util_ngymaichac_c9028e')
          : L10nService().format('util_calendar_tomorrow_with_count', {'count': eventCount});
    }
    if (_isPastDate(date)) {
      return eventCount == 0
          ? context.tr('util_ngynyquavc_7fd2b2')
          : L10nService().format('util_calendar_past_with_count', {'count': eventCount});
    }
    return eventCount == 0
        ? context.tr('util_ngynyangtr_12488d')
        : L10nService().format('util_calendar_day_with_count', {'count': eventCount});
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
    await _dbRef
        .child('houses/${widget.houseId}/calendar/$dateKey')
        .push()
        .set({
      'title': cleanText,
      'author': widget.myName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    _scheduleEventNotifications(day, cleanText);
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
              L10nService().format('util_calendar_added_for_date', {'date': _formatShortDate(day)}),
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
        body: L10nService().format('util_calendar_reminder_body', {'title': eventTitle}),
        scheduledDate: scheduleTime,
      );
    }

    // Thông báo trước 1 ngày
    final dayBefore = scheduleTime.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      NotificationService().scheduleLocalNotification(
        id: (dayBefore.millisecondsSinceEpoch ~/ 1000) + 1,
        title: context.tr('util_nhcnhngyma_b07d5b'),
        body: L10nService().format('util_calendar_upcoming_body', {'title': eventTitle}),
        scheduledDate: dayBefore,
      );
    }
  }

  void _deleteEvent(String dateKey, String eventId) {
    _dbRef
        .child('houses/${widget.houseId}/calendar/$dateKey/$eventId')
        .remove();
  }

  Future<void> _showUsageGuide() async {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 380;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: FastBackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 18 : 20,
                  compact ? 18 : 20,
                  compact ? 18 : 20,
                  compact ? 16 : 18,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      Colors.white.withValues(alpha: 0.86),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: compact ? 44 : 48,
                          height: compact ? 44 : 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8AA4), Color(0xFFE85D75)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(compact ? 14 : 16),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('util_hngdndnglc_234451'),
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 16 : 17,
                                  fontWeight: FontWeight.w900,
                                  color: SLTheme.textMain,
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                context.tr('util_thmlchhnvi_3cd2f4'),
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 11.5 : 12,
                                  fontWeight: FontWeight.w700,
                                  color: SLTheme.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: SLTheme.textMuted,
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CalendarInfoPill(
                          icon: Icons.notifications_active_rounded,
                          label: context.tr('util_nhcvo900sn_1062db'),
                          accent: const Color(0xFFE85D75),
                          compact: compact,
                        ),
                        CalendarInfoPill(
                          icon: Icons.event_available_rounded,
                          label: context.tr('util_nhctrc1ngy_09c55a'),
                          accent: const Color(0xFF2157F2),
                          compact: compact,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 16),
                    _buildGuideStep(
                      number: '1',
                      title: context.tr('util_chnngy_d2cce5'),
                      description:
                          context.tr('util_chmvongybn_92732b'),
                    ),
                    _buildGuideStep(
                      number: '2',
                      title: context.tr('util_nhpnidung_5f153e'),
                      description:
                          context.tr('util_ghingngnnh_2d7dac'),
                    ),
                    _buildGuideStep(
                      number: '3',
                      title: context.tr('util_thmvolch_2a1508'),
                      description:
                          context.tr('util_bmntthmluk_aa8abf'),
                    ),
                    _buildGuideStep(
                      number: '4',
                      title: context.tr('util_cchthngboh_efb6db'),
                      description:
                          context.tr('util_ngdnghinsn_2db6a9'),
                    ),
                    SizedBox(height: compact ? 14 : 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 12 : 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFD5DE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Color(0xFFE85D75),
                            size: 20,
                          ),
                          SLSpacing.w10,
                          Expanded(
                            child: Text(
                              context.tr('util_monnghikiu_82a005'),
                              style: SLTheme.quicksand(
                                fontSize: compact ? 11.5 : 12,
                                fontWeight: FontWeight.w700,
                                color: SLTheme.textMain,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF8AA4), Color(0xFFE85D75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: SLTheme.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: SLTheme.textMain,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLTheme.textMuted,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _calendarSubscription?.cancel();
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
                      stream: _dbRef
                          .child(
                            'houses/${widget.houseId}/calendar/${_getDateKey(selectedDay)}',
                          )
                          .onValue,
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
