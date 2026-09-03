import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:ui' as ui;
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/views/utilities/calendar/calendar_notification_ids.dart';
import 'package:soullocket_app/views/utilities/calendar/dialogs/calendar_quick_add_sheet.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_background_decor.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_event_input_panel.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_event_list_section.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_header_section.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_info_pill.dart';
import 'package:soullocket_app/views/utilities/calendar/widgets/calendar_selected_day_summary.dart';

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

  final TextEditingController _eventController = TextEditingController();

  Map<DateTime, List<dynamic>> _events = {};
  StreamSubscription<DatabaseEvent>? _calendarSubscription;
  int _calendarQueryGeneration = 0;
  bool _isQuickAddSheetOpen = false;
  bool _isCalendarLoading = true;
  bool _isSavingEvent = false;
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
    _selectedDay = _focusedDay;
    unawaited(_loadEvents());
  }

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
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return 'Hôm nay';
    }
  }

  String _monthName(int month) {
    const months = <String>[
      'tháng 1',
      'tháng 2',
      'tháng 3',
      'tháng 4',
      'tháng 5',
      'tháng 6',
      'tháng 7',
      'tháng 8',
      'tháng 9',
      'tháng 10',
      'tháng 11',
      'tháng 12',
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
      return 'Không rõ giờ tạo';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _selectedDayBadge(DateTime date) {
    if (_isToday(date)) {
      return 'Hôm nay';
    }
    if (_isTomorrow(date)) {
      return 'Ngày mai';
    }
    if (_isPastDate(date)) {
      return 'Đã qua';
    }
    return 'Sắp tới';
  }

  String _selectedDayDescription(DateTime date, int eventCount) {
    if (_isToday(date)) {
      return eventCount == 0
          ? 'Hôm nay đang trống lịch. Bạn có thể thêm kế hoạch mới để cả hai cùng theo dõi.'
          : 'Hôm nay có $eventCount kế hoạch. Nên ghi càng cụ thể càng dễ nhớ và dễ chuẩn bị.';
    }
    if (_isTomorrow(date)) {
      return eventCount == 0
          ? 'Ngày mai chưa có lịch nào. Có thể thêm lịch hẹn, việc cần làm hoặc nhắc quà từ bây giờ.'
          : 'Ngày mai đã có $eventCount kế hoạch. Ứng dụng sẽ nhắc trước để không bị quên.';
    }
    if (_isPastDate(date)) {
      return eventCount == 0
          ? 'Ngày này đã qua và chưa có dấu mốc nào được lưu lại.'
          : 'Ngày này đã qua, bạn vẫn có thể xem lại $eventCount kế hoạch từng được tạo.';
    }
    return eventCount == 0
        ? 'Ngày này đang trống. Hãy thêm lịch để biến nó thành một mốc đáng nhớ.'
        : 'Đã có $eventCount kế hoạch cho ngày này. Bạn có thể bổ sung thêm chi tiết nếu cần.';
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

  Future<void> _addEvent() async {
    final selectedDay = _selectedDay;
    if (selectedDay == null || _isSavingEvent) return;

    setState(() => _isSavingEvent = true);
    try {
      final added = await _saveEventForDay(
        day: selectedDay,
        text: _eventController.text,
      );
      if (!added) {
        return;
      }

      _eventController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm kế hoạch cho ${_formatShortDate(selectedDay)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu kế hoạch: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingEvent = false);
      }
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
            content: Text('Đã thêm kế hoạch cho ${_formatShortDate(day)}'),
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

  Future<void> _scheduleEventNotifications({
    required DateTime eventDate,
    required String eventTitle,
    required CalendarNotificationIds notificationIds,
  }) async {
    final now = DateTime.now();
    // Normalize eventDate to 9:00 AM
    final scheduleTime = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      9,
      0,
    );

    // Nếu ngày sự kiện là hôm nay và chưa qua 9h sáng
    if (scheduleTime.isAfter(now)) {
      await NotificationService().scheduleLocalNotification(
        id: notificationIds.onEventDay,
        title: 'Lịch trình hôm nay 📅',
        body: 'Đừng quên: $eventTitle',
        scheduledDate: scheduleTime,
      );
    }

    // Thông báo trước 1 ngày
    final dayBefore = scheduleTime.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      await NotificationService().scheduleLocalNotification(
        id: notificationIds.dayBefore,
        title: 'Nhắc nhở ngày mai ⏰',
        body: 'Sắp tới: $eventTitle',
        scheduledDate: dayBefore,
      );
    }
  }

  Future<void> _deleteEvent(String dateKey, String eventId) async {
    try {
      await _dbRef
          .child('houses/${widget.houseId}/calendar/$dateKey/$eventId')
          .remove();
    } catch (error) {
      debugPrint('[Calendar] Không thể xóa sự kiện $eventId: $error');
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

  Future<void> _showUsageGuide() async {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 380;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
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
                            borderRadius: BorderRadius.circular(
                              compact ? 14 : 16,
                            ),
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
                                'Hướng dẫn dùng Lịch chung',
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 16 : 17,
                                  fontWeight: FontWeight.w900,
                                  color: SLTheme.textMain,
                                ),
                              ),
                              SLSpacing.h4,
                              Text(
                                'Thêm lịch hẹn, việc cần nhớ hoặc kế hoạch chung để cả hai cùng theo dõi dễ hơn.',
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
                          label: 'Nhắc vào 9:00 sáng',
                          accent: const Color(0xFFE85D75),
                          compact: compact,
                        ),
                        CalendarInfoPill(
                          icon: Icons.event_available_rounded,
                          label: 'Nhắc trước 1 ngày',
                          accent: const Color(0xFF2157F2),
                          compact: compact,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 16),
                    _buildGuideStep(
                      number: '1',
                      title: 'Chọn ngày',
                      description:
                          'Chạm vào ngày bạn muốn tạo lịch trên lịch phía trên.',
                    ),
                    _buildGuideStep(
                      number: '2',
                      title: 'Nhập nội dung',
                      description:
                          'Ghi ngắn gọn nhưng rõ ràng, ví dụ giờ hẹn, địa điểm hoặc việc cần chuẩn bị.',
                    ),
                    _buildGuideStep(
                      number: '3',
                      title: 'Thêm vào lịch',
                      description:
                          'Bấm nút thêm để lưu kế hoạch vào ngày đã chọn.',
                    ),
                    _buildGuideStep(
                      number: '4',
                      title: 'Cách thông báo hoạt động',
                      description:
                          'Ứng dụng hiện sẽ nhắc trước 1 ngày vào 9:00 sáng và nhắc lại vào chính ngày đó lúc 9:00 sáng nếu thời điểm đó vẫn còn ở phía trước.',
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
                              'Mẹo: nên ghi kiểu “19:30 đi ăn ở ..., mang quà, gọi trước 15 phút” để khi nhận thông báo là hiểu ngay cần làm gì.',
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

  Widget _buildPinWidgetTile(bool compact) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF758C).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
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
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_to_home_screen_rounded,
                      color: Color(0xFFFF5E7E),
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
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 14 : 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ghim lịch trình & đếm ngược chuyến đi ra màn hình chính',
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
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
    _calendarQueryGeneration++;
    unawaited(_calendarSubscription?.cancel());
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
    final eventCount = selectedDay == null
        ? 0
        : _eventsForDay(selectedDay).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Lịch Chung 💗',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF163E99), Color(0xFF3B73E7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
            tooltip: 'Hướng dẫn sử dụng',
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
            child: RefreshIndicator(
              onRefresh: () async {
                await _reloadCalendar();
                await Future<void>.delayed(const Duration(milliseconds: 350));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    if (_calendarErrorMessage != null &&
                        _calendarErrorMessage!.trim().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalInset,
                          10,
                          horizontalInset,
                          4,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFFFD4DE)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.wifi_tethering_error_rounded,
                                color: Color(0xFFE45B87),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đồng bộ lịch đang gặp trục trặc nhỏ',
                                      style: SLTheme.quicksand(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: SLTheme.textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bạn có thể kéo xuống để tải lại hoặc chạm thử lại. Dữ liệu cũ vẫn được giữ nếu đã tải trước đó.',
                                      style: SLTheme.quicksand(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: SLTheme.textMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  unawaited(_reloadCalendar());
                                },
                                child: Text(
                                  'Thử lại',
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFE45B87),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                        final oldMonth = _focusedDay.month;
                        final oldYear = _focusedDay.year;
                        _focusedDay = focusedDay;
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
                      ),
                      if (Platform.isAndroid) ...[
                        SizedBox(height: compact ? 12 : 16),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalInset,
                          ),
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
                        isSaving: _isSavingEvent,
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
                            _deleteEvent(_getDateKey(selectedDay), eventId),
                          );
                        },
                      ),
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
