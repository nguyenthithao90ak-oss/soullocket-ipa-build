import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/core/constants/market_calendar_profiles.dart';
import 'package:soullocket_app/utils/calendar/calendar_display_format.dart';
import 'package:soullocket_app/utils/calendar/calendar_reminder_times.dart';
import 'package:soullocket_app/utils/calendar/holiday_occurrence_resolver.dart';
import 'package:soullocket_app/utils/services/holiday_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/market_service.dart';
import 'package:soullocket_app/views/utilities/calendar/calendar_notification_ids.dart';
import 'package:soullocket_app/views/utilities/calendar/dialogs/calendar_quick_add_sheet.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_background_decor.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_event_list_section.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_holiday_list_section.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_header_section.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_selected_day_summary.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_design.dart';

class CalendarScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const CalendarScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<dynamic>> _events = {};
  StreamSubscription<DatabaseEvent>? _calendarSubscription;
  int _calendarQueryGeneration = 0;
  bool _isQuickAddSheetOpen = false;
  bool _isCalendarLoading = true;
  String? _calendarErrorMessage;

  static int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _reloadCalendar() async {
    if (mounted) {
      setState(() {
        _isCalendarLoading = true;
        _calendarErrorMessage = null;
      });
    }
    await _loadEvents();
  }

  @override
  void initState() {
    super.initState();
    // Nạp CLDR trước frame đầu tiên để TableCalendar hiển thị đúng locale.
    unawaited(initializeDateFormatting());
    MarketService.instance.addListener(_onCalendarPreferencesChanged);
    L10nService().addListener(_onCalendarPreferencesChanged);
    _selectedDay = _focusedDay;
    unawaited(_loadEvents());
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _events = {};
      unawaited(_reloadCalendar());
    }
  }

  void _onCalendarPreferencesChanged() {
    if (mounted) setState(() {});
  }

  MarketCalendarProfile get _calendarProfile =>
      MarketCalendarProfiles.forMarket(MarketService.instance.marketCode);

  CalendarDisplayFormat get _displayFormat => CalendarDisplayFormat.forLocale(
    L10nService().locale,
    MarketService.instance.marketCode,
  );

  Future<void> _loadEvents() async {
    final queryGeneration = ++_calendarQueryGeneration;
    final previousSubscription = _calendarSubscription;
    _calendarSubscription = null;
    await previousSubscription?.cancel();
    if (!mounted || queryGeneration != _calendarQueryGeneration) return;

    // Chỉ query 3 tháng xung quanh tháng đang xem (trước/hiện/sau)
    final focusMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final startMonth = DateTime(focusMonth.year, focusMonth.month - 1, 1);
    final endMonth = DateTime(focusMonth.year, focusMonth.month + 2, 0);
    final startStr =
        '${startMonth.year}-${startMonth.month.toString().padLeft(2, '0')}-${startMonth.day.toString().padLeft(2, '0')}';
    final endStr =
        '${endMonth.year}-${endMonth.month.toString().padLeft(2, '0')}-${endMonth.day.toString().padLeft(2, '0')}';

    _calendarSubscription = _dbRef
        .child('houses/${widget.houseId}/calendar')
        .orderByKey()
        .startAt(startStr)
        .endAt(endStr)
        .onValue
        .listen(
          (event) {
            if (!mounted || queryGeneration != _calendarQueryGeneration) return;
            final snapshotValue = event.snapshot.value;
            if (snapshotValue == null) {
              if (mounted) {
                setState(() {
                  _events = {};
                  _isCalendarLoading = false;
                  _calendarErrorMessage = null;
                });
              }
              return;
            }

            try {
              if (snapshotValue is! Map) {
                if (mounted) {
                  setState(() {
                    _events = {};
                    _isCalendarLoading = false;
                    _calendarErrorMessage =
                        'Dữ liệu lịch không đúng định dạng mong đợi.';
                  });
                }
                return;
              }

              final data = Map<dynamic, dynamic>.from(snapshotValue);
              final Map<DateTime, List<dynamic>> newEvents = {};

              data.forEach((dateKey, dateEvents) {
                final parts = dateKey.toString().split('-');
                if (parts.length != 3) {
                  return;
                }
                final year = int.tryParse(parts[0]);
                final month = int.tryParse(parts[1]);
                final day = int.tryParse(parts[2]);
                if (year == null || month == null || day == null) {
                  return;
                }

                final date = DateTime.utc(year, month, day);
                if (dateEvents is! Map) {
                  newEvents[date] = const [];
                  return;
                }

                final eventsMap = Map<dynamic, dynamic>.from(dateEvents);
                newEvents[date] = eventsMap.entries
                    .where((e) => e.value is Map)
                    .map(
                      (e) => {
                        'key': e.key,
                        ...Map<String, dynamic>.from(e.value as Map),
                      },
                    )
                    .toList();
              });

              if (mounted) {
                setState(() {
                  _events = newEvents;
                  _isCalendarLoading = false;
                  _calendarErrorMessage = null;
                });
              }
            } catch (e) {
              if (mounted) {
                setState(() {
                  _isCalendarLoading = false;
                  _calendarErrorMessage = 'Không thể xử lý dữ liệu lịch: $e';
                });
              }
            }
          },
          onError: (error) {
            if (mounted && queryGeneration == _calendarQueryGeneration) {
              setState(() {
                _isCalendarLoading = false;
                _calendarErrorMessage = error.toString();
              });
            }
          },
        );
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
        (a, b) => _parseTimestamp(a['ts']).compareTo(_parseTimestamp(b['ts'])),
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

  Color _selectedAccent(DateTime date) => CalendarDesign.primary(context);

  String _formatDisplayDate(DateTime date) {
    return _displayFormat.longDate(date);
  }

  String _formatShortDate(DateTime date) {
    return _displayFormat.shortDate(date);
  }

  String _formatCreatedTime(int timestamp) {
    if (timestamp <= 0) {
      return L10nService().translate('sleep_state_unknown');
    }
    return _displayFormat.time(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  String _selectedDayBadge(DateTime date) {
    if (_isToday(date)) {
      return L10nService().translate('p3_today');
    }
    if (_isTomorrow(date)) {
      return L10nService().translate('theme_event_tomorrow');
    }
    if (_isPastDate(date)) {
      return L10nService().translate('milestone_tab_past');
    }
    return L10nService().translate('milestone_tab_upcoming');
  }

  String _selectedDayDescription(DateTime date, int eventCount) {
    if (_isToday(date)) {
      return eventCount == 0
          ? L10nService().translate('calendar_empty_day_desc')
          : L10nService().format('util_calendar_today_with_count', {
              'count': eventCount,
            });
    }
    if (_isTomorrow(date)) {
      return eventCount == 0
          ? L10nService().translate('calendar_empty_day_desc')
          : L10nService().format('util_calendar_tomorrow_with_count', {
              'count': eventCount,
            });
    }
    if (_isPastDate(date)) {
      return eventCount == 0
          ? L10nService().translate('calendar_empty_day_desc')
          : L10nService().format('util_calendar_past_with_count', {
              'count': eventCount,
            });
    }
    return eventCount == 0
        ? L10nService().translate('calendar_empty_day_desc')
        : L10nService().format('util_calendar_day_with_count', {
            'count': eventCount,
          });
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
    final eventRef = _dbRef
        .child('houses/${widget.houseId}/calendar/$dateKey')
        .push();
    final eventId = eventRef.key;
    if (eventId == null || eventId.isEmpty) {
      throw StateError('Không thể tạo mã sự kiện lịch.');
    }

    final notificationIds = CalendarNotificationIds.forEvent(
      houseId: widget.houseId,
      dateKey: dateKey,
      eventId: eventId,
    );
    await eventRef.set({
      'title': cleanText,
      'author': widget.myName,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'notificationIds': {
        'onEventDay': notificationIds.onEventDay,
        'dayBefore': notificationIds.dayBefore,
      },
    });

    try {
      await _scheduleEventNotifications(
        eventDate: day,
        eventTitle: cleanText,
        notificationIds: notificationIds,
      );
    } catch (error) {
      // Sự kiện đã lưu thành công; lỗi local notification không được làm mất lịch.
      debugPrint('[Calendar] Không thể đặt thông báo cho $eventId: $error');
    }
    return true;
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
          SLSnackBar(
            content: Text(
              L10nService().format('calendar_add_success', {
                'date': _formatShortDate(day),
              }),
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
    final monthChanged =
        _focusedDay.month != focused.month || _focusedDay.year != focused.year;
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    if (monthChanged) unawaited(_reloadCalendar());
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

  Future<void> _scheduleEventNotifications({
    required DateTime eventDate,
    required String eventTitle,
    required CalendarNotificationIds notificationIds,
  }) async {
    final now = DateTime.now();
    final reminderTimes = CalendarReminderTimes.forDate(eventDate);
    final scheduleTime = reminderTimes.onEventDay;

    // Nếu ngày sự kiện là hôm nay và chưa qua 9h sáng
    if (scheduleTime.isAfter(now)) {
      await NotificationService().scheduleLocalNotification(
        id: notificationIds.onEventDay,
        title: L10nService().translate('calendar_notification_today_title'),
        body: L10nService().format('calendar_notification_body', {
          'title': eventTitle,
        }),
        scheduledDate: scheduleTime,
      );
    }

    // Thông báo trước 1 ngày
    final dayBefore = reminderTimes.dayBefore;
    if (dayBefore.isAfter(now)) {
      await NotificationService().scheduleLocalNotification(
        id: notificationIds.dayBefore,
        title: L10nService().translate('calendar_notification_tomorrow_title'),
        body: L10nService().format('calendar_notification_upcoming_body', {
          'title': eventTitle,
        }),
        scheduledDate: dayBefore,
      );
    }
  }

  Future<void> _requestDeleteEvent(String dateKey, String eventId) async {
    final entry = _eventsForDay(
      _selectedDay ?? _focusedDay,
    ).where((event) => event['key']?.toString() == eventId);
    final title = entry.isEmpty ? '' : entry.first['title']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CalendarDesign.surface(dialogContext),
        title: Text(dialogContext.tr('confirm_delete')),
        content: Text(
          title.isEmpty ? dialogContext.tr('calendar_plan_no_content') : title,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr('p3_delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _deleteEvent(dateKey, eventId);
  }

  Future<void> _deleteEvent(String dateKey, String eventId) async {
    try {
      await _dbRef
          .child('houses/${widget.houseId}/calendar/$dateKey/$eventId')
          .remove();
    } catch (error) {
      debugPrint('[Calendar] Không thể xóa sự kiện $eventId: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(content: Text(context.tr('calendar_sync_error_title'))),
        );
      }
      return;
    }

    final ids = CalendarNotificationIds.forEvent(
      houseId: widget.houseId,
      dateKey: dateKey,
      eventId: eventId,
    );
    final legacyIds = _legacyNotificationIdsForDateKey(dateKey);
    try {
      await NotificationService().cancelLocalNotifications(<int>{
        ...ids.values,
        ...legacyIds,
      });
    } catch (error) {
      debugPrint('[Calendar] Không thể hủy thông báo cho $eventId: $error');
    }
  }

  Set<int> _legacyNotificationIdsForDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return const <int>{};

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return const <int>{};
    }

    final eventTime = DateTime(year, month, day, 9);
    final dayBefore = eventTime.subtract(const Duration(days: 1));
    return <int>{
      eventTime.millisecondsSinceEpoch ~/ 1000,
      (dayBefore.millisecondsSinceEpoch ~/ 1000) + 1,
    };
  }

  Future<void> _showUsageGuide() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: CalendarDesign.surface(dialogContext),
      title: Text(
        dialogContext.tr('calendar_usage_guide_tooltip'),
        style: CalendarDesign.text(
          dialogContext,
          size: 20,
          weight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dialogContext.tr('calendar_hero_desc'),
              style: CalendarDesign.text(dialogContext),
            ),
            const SizedBox(height: 16),
            Text(
              dialogContext.tr('calendar_add_plan_desc'),
              style: CalendarDesign.text(dialogContext),
            ),
            const SizedBox(height: 16),
            Text(
              dialogContext.tr('calendar_remind_one_day_before'),
              style: CalendarDesign.text(dialogContext),
            ),
            Text(
              dialogContext.tr('calendar_reminder_at_nine'),
              style: CalendarDesign.text(dialogContext),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.tr('close')),
        ),
      ],
    ),
  );

  Widget _buildPinWidgetTile(bool compact) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    tileColor: CalendarDesign.soft(context),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    leading: Icon(
      Icons.add_to_home_screen_rounded,
      color: CalendarDesign.primary(context),
    ),
    title: Text(
      context.tr('add_widget'),
      style: CalendarDesign.text(context, size: 14, weight: FontWeight.w700),
    ),
    subtitle: Text(
      context.tr('add_widget_desc'),
      style: CalendarDesign.text(
        context,
        size: 12,
        color: CalendarDesign.muted(context),
      ),
    ),
    trailing: Icon(
      Icons.chevron_right_rounded,
      color: CalendarDesign.muted(context),
    ),
    onTap: () async {
      try {
        await WidgetService.requestPinCalendarWidget();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(content: Text(context.tr('widget_pin_req_sent'))),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(content: Text(context.tr('widget_pin_failed'))),
        );
      }
    },
  );

  @override
  void dispose() {
    _calendarQueryGeneration++;
    unawaited(_calendarSubscription?.cancel());
    MarketService.instance.removeListener(_onCalendarPreferencesChanged);
    L10nService().removeListener(_onCalendarPreferencesChanged);
    super.dispose();
  }

  double _horizontalInsetForWidth(double width) {
    if (width > 680) {
      return (width - 640) / 2;
    }
    if (width <= 360) {
      return 16;
    }
    if (width <= 420) {
      return 20;
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
    final eventCount = selectedDay == null
        ? 0
        : _eventsForDay(selectedDay).length;

    // Cùng preferences/resolver với Home; lớp lễ không ghi vào calendar RTDB.
    final applicableHolidays = HolidayService.getApplicableHolidays();
    final holidaysByDate = <DateTime, List<HolidayOccurrence>>{};
    for (final occurrence in HolidayOccurrenceResolver.occurrencesBetween(
      applicableHolidays,
      start: DateTime(_focusedDay.year, _focusedDay.month - 1),
      end: DateTime(_focusedDay.year, _focusedDay.month + 2, 0),
    )) {
      (holidaysByDate[_normalizeDate(occurrence.date)] ??= []).add(occurrence);
    }
    if (selectedDay != null) {
      holidaysByDate.putIfAbsent(
        _normalizeDate(selectedDay),
        () => HolidayOccurrenceResolver.occurrencesBetween(
          applicableHolidays, start: selectedDay, end: selectedDay,
        ),
      );
    }
    List<HolidayOccurrence> holidaysForDay(DateTime day) =>
        holidaysByDate[_normalizeDate(day)] ?? const [];

    return Scaffold(
      backgroundColor: CalendarDesign.background(context),
      appBar: AppBar(
        title: Text(
          context.tr('calendar_shared_title'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            letterSpacing: 0.5,
            color: CalendarDesign.ink(context),
          ),
        ),
        centerTitle: true,
        backgroundColor: CalendarDesign.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: CalendarDesign.ink(context),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('calendar_usage_guide_tooltip'),
            onPressed: _showUsageGuide,
            icon: Icon(
              Icons.info_outline_rounded,
              color: CalendarDesign.primary(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: selectedDay == null
          ? null
          : ColoredBox(
              color: CalendarDesign.background(context),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    10,
                    horizontalInset,
                    12,
                  ),
                  child: FilledButton.icon(
                    onPressed: () => _showQuickAddSheet(selectedDay),
                    style: FilledButton.styleFrom(
                      backgroundColor: CalendarDesign.primary(context),
                      foregroundColor: CalendarDesign.onPrimary(context),
                      minimumSize: const Size(48, 54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      context.tr('calendar_add_plan_title'),
                      textAlign: TextAlign.center,
                      style: CalendarDesign.text(
                        context,
                        size: 15,
                        weight: FontWeight.w700,
                        color: CalendarDesign.onPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: Stack(
        children: [
          const Positioned.fill(child: CalendarBackgroundDecor()),
          SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await _reloadCalendar();
                await Future<void>.delayed(const Duration(milliseconds: 350));
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(
                  parent: SLResponsive.scrollPhysicsForPlatform(),
                ),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    CalendarHeaderSection(
                      horizontalInset: horizontalInset,
                      compact: compact,
                      calendarFormat: _calendarFormat,
                      focusedDay: _focusedDay,
                      selectedDay: selectedDay,
                      locale: _displayFormat.intlLocale,
                      calendarProfile: _calendarProfile,
                      eventLoader: (day) =>
                          _events[_normalizeDate(day)] ?? const <dynamic>[],
                      holidayLoader: holidaysForDay,
                      onTodayPressed: () {
                        final today = DateTime.now();
                        _selectDay(today, today);
                      },
                      onDaySelected: _selectDay,
                      onDayLongPressed: _handleDayLongPressed,
                      onFormatChanged: (format) {
                        if (_calendarFormat != format) {
                          setState(() => _calendarFormat = format);
                        }
                      },
                      onPageChanged: (focusedDay) {
                        final oldMonth = _focusedDay.month;
                        final oldYear = _focusedDay.year;
                        setState(() => _focusedDay = focusedDay);
                        // Khi chuyển tháng → reload query cho tháng mới
                        if (focusedDay.month != oldMonth ||
                            focusedDay.year != oldYear) {
                          unawaited(_reloadCalendar());
                        }
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
                        description: _selectedDayDescription(
                          selectedDay,
                          eventCount,
                        ),
                        badgeLabel: _selectedDayBadge(selectedDay),
                        shortDateLabel: _formatShortDate(selectedDay),
                        eventCount: eventCount,
                        holidayCount: holidaysForDay(selectedDay).length,
                      ),
                      CalendarHolidayListSection(
                        occurrences: holidaysForDay(selectedDay),
                        horizontalInset: horizontalInset,
                      ),
                      SizedBox(height: compact ? 12 : 16),
                      CalendarEventListSection(
                        items: _eventsForDay(selectedDay),
                        isLoading: _isCalendarLoading,
                        errorMessage: _calendarErrorMessage,
                        onRetry: () {
                          unawaited(_reloadCalendar());
                        },
                        horizontalInset: horizontalInset,
                        compact: compact,
                        accent: _selectedAccent(selectedDay),
                        selectedDateLabel: _formatShortDate(selectedDay),
                        itemCount: eventCount,
                        statusLabel: _selectedDayBadge(selectedDay),
                        formatCreatedTime: _formatCreatedTime,
                        onDelete: (eventId) {
                          unawaited(
                            _requestDeleteEvent(
                              _getDateKey(selectedDay),
                              eventId,
                            ),
                          );
                        },
                      ),
                      if (!kIsWeb && Platform.isAndroid) ...[
                        SizedBox(height: compact ? 12 : 16),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalInset,
                          ),
                          child: _buildPinWidgetTile(compact),
                        ),
                      ],
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
