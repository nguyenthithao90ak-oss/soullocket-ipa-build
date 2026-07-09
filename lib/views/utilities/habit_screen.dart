import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:ui' as ui;
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../utils/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/activity_history_service.dart';

class HabitScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const HabitScreen({super.key, required this.houseId, required this.myName});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _habitController = TextEditingController();
  late Stream<DatabaseEvent> _habitsStream;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _habitsStream = _dbRef.child('houses/${widget.houseId}/habits').onValue;
  }

  @override
  void didUpdateWidget(covariant HabitScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _habitsStream = _dbRef.child('houses/${widget.houseId}/habits').onValue;
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD81B60),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _addHabit() async {
    final text = _habitController.text.trim();
    if (text.isEmpty) return;

    String? timeString;
    if (_selectedTime != null) {
      timeString =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    }

    await _dbRef.child('houses/${widget.houseId}/habits').push().set({
      'name': text,
      'creator': widget.myName,
      'time': timeString,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    ActivityHistoryService.instance.add(
      context.tr('util_tomtthique_a49546'),
      houseId: widget.houseId,
      role: role,
    );

    _habitController.clear();
    setState(() {
      _selectedTime = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _deleteHabit(String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá thói quen'),
        content: const Text('Bạn có chắc chắn muốn xoá thói quen này? Dữ liệu điểm danh sẽ mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dbRef.child('houses/${widget.houseId}/habits/$key').remove();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  void _toggleHabitDay(String key, String dateStr, bool currentValue) {
    if (currentValue) {
      _dbRef
          .child(
              'houses/${widget.houseId}/habits/$key/completed_dates/$dateStr')
          .remove();
    } else {
      _dbRef
          .child(
              'houses/${widget.houseId}/habits/$key/completed_dates/$dateStr')
          .set(true);
    }
  }

  List<DateTime> _getLast7Days() {
    final today = DateTime.now();
    return List.generate(
        7, (index) => today.subtract(Duration(days: 6 - index)));
  }

  String _formatDateKey(DateTime d) {
    return '${d.day}-${d.month}-${d.year}';
  }

  int _calculateHabitStreak(Map<dynamic, dynamic> completedMap) {
    int streak = 0;
    DateTime checkDate = DateTime.now();
    while (true) {
      final key = _formatDateKey(checkDate);
      if (completedMap[key] == true) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        if (streak == 0 &&
            _formatDateKey(checkDate) == _formatDateKey(DateTime.now())) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          if (completedMap[_formatDateKey(checkDate)] == true) {
            streak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
            continue;
          }
        }
        break;
      }
    }
    return streak;
  }

  void _showHabitInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.tr('util_theodithiq_5cf852'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          context.tr('util_habit_help_body'),
          style: SLTheme.quicksand(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('util_hiu_93c4c0')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _habitController.dispose();
    super.dispose();
  }

  String _habitMetaLabel(Map<dynamic, dynamic> item) {
    final creator = item['creator']?.toString();
    final time = item['time']?.toString();
    final parts = <String>[];
    if (creator != null && creator.isNotEmpty) {
      parts.add(L10nService().format('util_habit_created_by', {'name': creator}));
    }
    if (time != null && time.isNotEmpty) {
      parts.add('⏰ $time');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.tr('util_theodithiq_362d99'),
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
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('util_giithiuthe_3c2cfe'),
            icon: const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 22),
            onPressed: _showHabitInfo,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildInputArea(),
              Expanded(child: _buildHabitsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: SLSpacing.all20,
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: SLRadius.lgAll,
                    border: Border.all(
                      color: const Color(0xFFFF8AA0).withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _habitController,
                    cursorColor: const Color(0xFFD81B60),
                    style: SLTheme.quicksand(
                      color: const Color(0xFF243041),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('util_thiquenmiv_24be39'),
                      hintStyle: SLTheme.quicksand(
                        color: const Color(0xFFB55A73),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 12),
                    ),
                    onSubmitted: (_) => _addHabit(),
                  ),
                ),
              ),
              SLSpacing.w8,
              GestureDetector(
                onTap: () => _selectTime(context),
                child: Container(
                  padding: SLSpacing.all12,
                  decoration: BoxDecoration(
                    color: _selectedTime != null
                        ? Colors.amber[700]
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: SLRadius.lgAll,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time,
                          color: Colors.white, size: 20),
                      if (_selectedTime != null)
                        Text(
                          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),
              SLSpacing.w8,
              GestureDetector(
                onTap: _addHabit,
                child: Container(
                  padding: SLSpacing.all12,
                  decoration: const BoxDecoration(
                      color: Color(0xFFD81B60), shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitSummary({
    required List<Map<String, dynamic>> items,
    required List<DateTime> last7Days,
    required String todayKey,
  }) {
    int doneToday = 0;
    int weekDone = 0;
    int bestStreak = 0;

    for (final item in items) {
      final completedMap = item['completed_dates'] != null
          ? Map<dynamic, dynamic>.from(item['completed_dates'])
          : <dynamic, dynamic>{};
      if (completedMap[todayKey] == true) {
        doneToday++;
      }
      for (final day in last7Days) {
        if (completedMap[_formatDateKey(day)] == true) {
          weekDone++;
        }
      }
      bestStreak = max(bestStreak, _calculateHabitStreak(completedMap));
    }

    final weekTarget = items.length * last7Days.length;
    final weekProgress = weekTarget == 0 ? 0.0 : weekDone / weekTarget;
    final badge = weekProgress >= 0.85
        ? 'Tuần rất đều'
        : weekProgress >= 0.5
            ? 'Đang giữ nhịp'
            : 'Cần nhắc thêm';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Colors.amberAccent, size: 23),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge,
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      'Hôm nay $doneToday/${items.length} • Streak tốt nhất $bestStreak ngày',
                      style: SLTheme.quicksand(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: weekProgress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            ),
          ),
          SLSpacing.h8,
          Text(
            'Tiến độ 7 ngày: $weekDone/$weekTarget lượt check-in.',
            style: SLTheme.quicksand(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList() {
    return StreamBuilder(
      stream: _habitsStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              context.tr('util_khngticthi_a88c58'),
              style: SLTheme.quicksand(
                  color: Colors.white70, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(
            child: Text(
              context.tr('util_chacthique_191171'),
              style: SLTheme.quicksand(
                  color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          );
        }

        final raw = snapshot.data!.snapshot.value;
        if (raw is! Map) {
          return const SizedBox.shrink();
        }
        final data = Map<dynamic, dynamic>.from(raw);
        final items = data.entries
            .where((e) => e.value is Map)
            .map((e) => {
                  'key': e.key,
                  ...Map<String, dynamic>.from(e.value as Map),
                })
            .toList();
        items.sort(
            (a, b) => (a['ts'] as int? ?? 0).compareTo(b['ts'] as int? ?? 0));

        final last7Days = _getLast7Days();
        final todayKey = _formatDateKey(DateTime.now());

        // Auto-remind logic (runs once per stream update)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (var item in items) {
            final completedMap = item['completed_dates'] != null
                ? Map<dynamic, dynamic>.from(item['completed_dates'])
                : {};
            final isCompletedToday = completedMap[todayKey] == true;

            if (!isCompletedToday && item['time'] != null) {
              final timeParts = item['time'].toString().split(':');
              if (timeParts.length == 2) {
                final habitTime = TimeOfDay(
                    hour: int.parse(timeParts[0]),
                    minute: int.parse(timeParts[1]));
                final now = TimeOfDay.now();

                final habitMinutes = habitTime.hour * 60 + habitTime.minute;
                final nowMinutes = now.hour * 60 + now.minute;

                // Check if we are within 30 minutes before or after scheduled time
                if (nowMinutes >= habitMinutes - 30 &&
                    item['last_reminded_date'] != todayKey) {
                  NotificationService().sendHabitReminderNotification(
                      widget.houseId, item['name']);
                  _dbRef
                      .child(
                          'houses/${widget.houseId}/habits/${item['key']}/last_reminded_date')
                      .set(todayKey);
                }
              }
            }
          }
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHabitSummary(
                items: items.cast<Map<String, dynamic>>(),
                last7Days: last7Days,
                todayKey: todayKey,
              );
            }

            final item = items[index - 1];
            final completedMap = item['completed_dates'] != null
                ? Map<dynamic, dynamic>.from(item['completed_dates'])
                : {};

            final streak = _calculateHabitStreak(completedMap);

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: ClipRRect(
                borderRadius: SLRadius.xlAll,
                child: Container(
                  padding: SLSpacing.all20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: SLRadius.xlAll,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? '',
                                  style: SLTheme.quicksand(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18),
                                ),
                                if (item['creator'] != null ||
                                    item['time'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _habitMetaLabel(item),
                                      style: SLTheme.quicksand(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.3),
                              borderRadius: SLRadius.mdAll,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department,
                                    color: Colors.orangeAccent, size: 16),
                                SLSpacing.w4,
                                Text(
                                  L10nService().format('util_habit_streak_days', {'count': streak}),
                                  style: SLTheme.quicksand(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          SLSpacing.w8,
                          GestureDetector(
                            onTap: () => _deleteHabit(item['key']),
                            child: const Icon(Icons.close,
                                color: Colors.white54, size: 20),
                          ),
                        ],
                      ),
                      SLSpacing.h20,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: last7Days.map((date) {
                          final dateKey = _formatDateKey(date);
                          final isCompleted = completedMap[dateKey] == true;
                          final isToday = date.day == DateTime.now().day &&
                              date.month == DateTime.now().month;

                          return GestureDetector(
                            onTap: () => _toggleHabitDay(
                                item['key'], dateKey, isCompleted),
                            child: Column(
                              children: [
                                Text(
                                  isToday ? 'Nay' : '${date.day}/${date.month}',
                                  style: SLTheme.quicksand(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isToday ? Colors.white : Colors.white60,
                                  ),
                                ),
                                SLSpacing.h8,
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? Colors.greenAccent.withValues(alpha: 0.8)
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: SLRadius.mdAll,
                                    border: Border.all(
                                      color: isCompleted
                                          ? Colors.greenAccent
                                          : Colors.white24,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isCompleted
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 20)
                                      : null,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
