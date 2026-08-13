import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../utils/services/l10n_service.dart';
import '../../utils/services/notification_service.dart';
import '../../utils/services/widget_service.dart';

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
  late Stream<DatabaseEvent> _selectedDayStream;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  Map<DateTime, List<dynamic>> _events = {};
  StreamSubscription<DatabaseEvent>? _calendarSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedDayStream = _dbRef
        .child('houses/${widget.houseId}/calendar/${_getDateKey(_focusedDay)}')
        .onValue
        .asBroadcastStream();
    _loadEvents();
  }

  @override
  void dispose() {
    _calendarSubscription?.cancel();
    _debounceTimer?.cancel();
    _titleController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  String _getDateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _normalizeDate(DateTime d) {
    return DateTime.utc(d.year, d.month, d.day);
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

  void _selectDay(DateTime selected, DateTime focused) {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
      _selectedDayStream = _dbRef
          .child('houses/${widget.houseId}/calendar/${_getDateKey(selected)}')
          .onValue
          .asBroadcastStream();
    });
  }

  Future<void> _addEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedDay == null) return;
    
    String fullText = title;
    final time = _timeController.text.trim();
    final location = _locationController.text.trim();
    if (time.isNotEmpty || location.isNotEmpty) {
      fullText += '\n';
      if (time.isNotEmpty) fullText += '🕘 $time  ';
      if (location.isNotEmpty) fullText += '📍 $location';
    }

    final dateKey = _getDateKey(_selectedDay!);
    await _dbRef
        .child('houses/${widget.houseId}/calendar/$dateKey')
        .push()
        .set({
      'title': fullText,
      'author': widget.myName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    _scheduleEventNotifications(_selectedDay!, title);
    
    if (Platform.isAndroid) {
      unawaited(WidgetService.syncCalendarWidgetData(houseId: widget.houseId));
    }

    _titleController.clear();
    _locationController.clear();
    _timeController.clear();
    FocusScope.of(context).unfocus();
  }

  void _scheduleEventNotifications(DateTime eventDate, String eventTitle) {
    final now = DateTime.now();
    final scheduleTime =
        DateTime(eventDate.year, eventDate.month, eventDate.day, 9, 0);

    if (scheduleTime.isAfter(now)) {
      NotificationService().scheduleLocalNotification(
        id: scheduleTime.millisecondsSinceEpoch ~/ 1000,
        title: 'Hôm nay có kế hoạch!',
        body: 'Đừng quên: $eventTitle',
        scheduledDate: scheduleTime,
      );
    }
    final dayBefore = scheduleTime.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      NotificationService().scheduleLocalNotification(
        id: (dayBefore.millisecondsSinceEpoch ~/ 1000) + 1,
        title: 'Nhắc nhở ngày mai',
        body: 'Ngày mai có sự kiện: $eventTitle',
        scheduledDate: dayBefore,
      );
    }
  }

  void _deleteEvent(String dateKey, String eventId) {
    _dbRef
        .child('houses/${widget.houseId}/calendar/$dateKey/$eventId')
        .remove()
        .then((_) {
      if (Platform.isAndroid) {
        unawaited(WidgetService.syncCalendarWidgetData(houseId: widget.houseId));
      }
    });
  }

  // --- WIDGETS BUILDER ---

  Widget _buildCalendarCard() {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📅 Lịch đi chơi',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chạm vào ngày để xem kế hoạch',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF202124).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Tháng',
                  CalendarFormat.twoWeeks: '2 Tuần',
                  CalendarFormat.week: 'Tuần',
                },
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: _selectDay,
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() => _calendarFormat = format);
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) => _events[_normalizeDate(day)] ?? [],
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF202124),
                  ),
                  leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF202124)),
                  rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF202124)),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF202124).withValues(alpha: 0.6),
                  ),
                  weekendStyle: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF5C9E),
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  selectedBuilder: (context, date, events) {
                    return Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5C9E), Color(0xFFFF8AB3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5C9E).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                  todayBuilder: (context, date, events) {
                    return Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFF5C9E), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFF5C9E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return const SizedBox();
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFB983FF),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
    if (_selectedDay == null) return const SizedBox();
    final isToday = isSameDay(_selectedDay, DateTime.now());
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isToday ? '🩷 Hôm nay' : '📅 ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF202124),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy').format(_selectedDay!),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF202124).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<DatabaseEvent>(
            stream: _selectedDayStream,
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                final data = Map.from(snapshot.data!.snapshot.value as Map);
                count = data.length;
              }
              if (count == 0) {
                return Text(
                  'Bạn chưa có kế hoạch nào.',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: const Color(0xFF202124).withValues(alpha: 0.7),
                  ),
                );
              }
              return Text(
                'Có $count kế hoạch trong ngày.',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF5C9E),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hãy ra màn hình chính của điện thoại, nhấn giữ để thêm Widget Lịch nhé!')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5C9E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.widgets_rounded,
                    color: Color(0xFFFF5C9E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📲 Widget màn hình chính',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF202124),
                        ),
                      ),
                      Text(
                        'Hiển thị lịch và đếm ngược',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF202124).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD1D1D6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddScheduleCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📝 Thêm kế hoạch',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF202124)),
            decoration: InputDecoration(
              hintText: 'Tên kế hoạch (vd: Đi ăn tối)...',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF202124).withValues(alpha: 0.4)),
              filled: true,
              fillColor: const Color(0xFFF9F9FB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _timeController,
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF202124)),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFB983FF)),
                    hintText: 'Giờ',
                    hintStyle: GoogleFonts.outfit(color: const Color(0xFF202124).withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: const Color(0xFFF9F9FB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _locationController,
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF202124)),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFFB983FF)),
                    hintText: 'Địa điểm',
                    hintStyle: GoogleFonts.outfit(color: const Color(0xFF202124).withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: const Color(0xFFF9F9FB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ).copyWith(
                elevation: WidgetStateProperty.all(0),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5C9E), Color(0xFFFF8AB3)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5C9E).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: Text(
                    '＋ Thêm vào lịch',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _selectedDayStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox(height: 100);
        }

        final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final events = data.entries.map((e) {
          return {
            'id': e.key,
            ...Map<String, dynamic>.from(e.value as Map),
          };
        }).toList();
        events.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(0),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            separatorBuilder: (context, index) => const Divider(
              color: Color(0xFFE5E5EA),
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final ev = events[index];
              final titleText = ev['title'] ?? '';
              
              final lines = titleText.split('\n');
              final mainTitle = lines.first;
              final subTitle = lines.length > 1 ? lines.skip(1).join(' ') : null;

              return Dismissible(
                key: Key(ev['id']),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  _deleteEvent(_getDateKey(_selectedDay!), ev['id']);
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red.shade400,
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5C9E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mainTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF202124),
                              ),
                            ),
                            if (subTitle != null && subTitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                subTitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF202124).withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFFFFF7FB).withValues(alpha: 0.8),
            floating: true,
            pinned: true,
            toolbarHeight: 56,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF202124), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lịch Chung',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF202124),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('📅', style: TextStyle(fontSize: 18)),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF202124), size: 22),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lịch chung giữa hai người.')),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildCalendarCard(),
              _buildTodayCard(),
              if (Platform.isAndroid || Platform.isIOS) _buildWidgetCard(),
              _buildAddScheduleCard(),
              _buildScheduleList(),
            ]),
          ),
        ],
      ),
    );
  }
}
