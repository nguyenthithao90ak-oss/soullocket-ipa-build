import 'package:soullocket_app/widgets/sl_date_picker.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'package:soullocket_app/utils/calendar/calendar_civil_date.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'dart:ui' as ui;
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../widgets/skeleton_container.dart';
import '../../utils/initial_event_timeout.dart';

import '../../utils/services/habit_reminder_service.dart';
import '../../utils/habit_local_reminders.dart';
import '../../utils/locale_date_format.dart';
import '../../utils/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/activity_history_service.dart';
import '../../utils/services/connectivity_service.dart';

class HabitScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const HabitScreen({super.key, required this.houseId, required this.myName});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitGardenPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  const _HabitGardenPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width / 118, size.height / 124);
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.58);
    canvas.scale(scale);

    final ground = Paint()
      ..color = (isDark ? const Color(0xFF16271F) : const Color(0xFFE3D7B7))
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(-56, 40, 112, 26), ground);

    final trunk = Paint()
      ..color = isDark ? const Color(0xFFB8895C) : const Color(0xFF9C6B45)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final treeHeight = 27 + (progress * 24);
    canvas.drawLine(const Offset(0, 42), Offset(0, 42 - treeHeight), trunk);
    canvas.drawLine(
      const Offset(0, 24),
      const Offset(-15, 12),
      trunk..strokeWidth = 4,
    );
    canvas.drawLine(
      const Offset(0, 17),
      const Offset(17, 5),
      trunk..strokeWidth = 4,
    );

    final leaf = Paint()..style = PaintingStyle.fill;
    final leafColor = isDark
        ? const Color(0xFF8FCF86)
        : const Color(0xFF6FAE72);
    final softLeaf = isDark ? const Color(0xFFB8E4A9) : const Color(0xFF9ACB8E);
    final leaves = <({Offset center, double radius, Color color})>[
      (center: const Offset(-18, 4), radius: 14, color: leafColor),
      (center: const Offset(17, -4), radius: 15, color: softLeaf),
      (center: const Offset(0, -17), radius: 18, color: leafColor),
      if (progress > 0.34)
        (center: const Offset(-28, 23), radius: 10, color: softLeaf),
      if (progress > 0.68)
        (center: const Offset(28, 20), radius: 11, color: leafColor),
    ];
    for (final item in leaves) {
      leaf.color = item.color;
      canvas.drawCircle(item.center, item.radius, leaf);
    }

    final fruit = Paint()..color = const Color(0xFFE89978);
    if (progress > 0.5) canvas.drawCircle(const Offset(-9, -18), 4, fruit);
    if (progress > 0.82) canvas.drawCircle(const Offset(12, -7), 4, fruit);

    final sparkle = Paint()..color = const Color(0xFFF0C870);
    if (progress > 0.15) {
      canvas.drawCircle(const Offset(-42, -15), 2.2, sparkle);
      canvas.drawCircle(const Offset(42, 1), 2.2, sparkle);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HabitGardenPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

class _HabitScreenState extends State<HabitScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _habitController = TextEditingController();
  final FocusNode _habitFocusNode = FocusNode();
  late Stream<DatabaseEvent> _habitsStream;
  TimeOfDay? _selectedTime;
  String? _screenUid;
  int? _observedHabitCount;

  @override
  void initState() {
    super.initState();
    _habitsStream = _watchHabits();
    _screenUid = FirebaseAuth.instance.currentUser?.uid;
    // Màn Thói quen có thể được mở trực tiếp từ deep link/thông báo; bảo đảm
    // owner nhắc đã chạy ngay cả khi warm-up nền chưa kịp hoàn tất.
    HabitReminderService.instance.start();
  }

  Stream<DatabaseEvent> _watchHabits() => withInitialEventTimeout(
    _dbRef.child('houses/${widget.houseId}/habits').limitToLast(25).onValue,
  );

  Future<void> _pickHabitReminder(String key, String? rawTime) async {
    final houseId = widget.houseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final parsed = HabitLocalReminderPlanner.parseTime(rawTime);
    final initialTime = parsed == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: parsed.$1, minute: parsed.$2);
    final picked = await showSLTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted ||
        picked == null ||
        uid == null ||
        uid != FirebaseAuth.instance.currentUser?.uid ||
        uid != _screenUid ||
        houseId != widget.houseId) {
      return;
    }
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _saveHabitReminder(key, value);
  }

  void _handleHabitReminderAction(String key, String? rawTime, String action) {
    if (action == 'set') {
      unawaited(_pickHabitReminder(key, rawTime));
    } else if (action == 'remove') {
      _saveHabitReminder(key, null);
    }
  }

  void _saveHabitReminder(String key, String? time) {
    if (_screenUid == null ||
        FirebaseAuth.instance.currentUser?.uid != _screenUid) {
      return;
    }
    final path = 'houses/${widget.houseId}/habits/$key';
    final update = <String, dynamic>{'time': time};
    if (!ConnectivityService().isOnline) {
      unawaited(
        ConnectivityService().enqueueOfflineData(path, 'update', update),
      );
    }
    // Không chờ ACK mạng: RTDB persistence cập nhật UI ngay cả khi offline,
    // còn ConnectivityService sẽ gửi lại payload khi kết nối trở lại.
    unawaited(() async {
      try {
        await _dbRef.child(path).update(update);
      } catch (_) {
        // Lỗi tạm thời sẽ được listener/retry xử lý; không làm kẹt màn hình.
      }
    }());
    unawaited(HabitReminderService.instance.refresh());
  }

  Future<void> _requestHabitNotificationPermission() async {
    final granted = await NotificationService().requestPermissionAndInit();
    if (!mounted) return;
    if (granted) {
      await HabitReminderService.instance.refresh();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(content: Text(context.tr('event_reminder_permission'))),
    );
  }

  Widget _buildHabitReminderStatus() {
    final service = HabitReminderService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final count = service.scheduledCount;
        final through = service.scheduledThrough;
        final hasSaved = count > 0 && through != null;
        final status = service.status;
        final String? message;
        switch (status) {
          case HabitReminderStatus.permissionDenied:
            message = context.tr('event_reminder_permission');
          case HabitReminderStatus.disabled:
            message = context.tr('event_reminder_disabled');
          case HabitReminderStatus.unsupported:
            message = context.tr('event_reminder_unsupported');
          case HabitReminderStatus.failed:
            message = context.tr('event_reminder_failed');
          case HabitReminderStatus.waiting:
            message = context.tr('habit_reminder_waiting');
          case HabitReminderStatus.ready:
          case HabitReminderStatus.limited:
            message = null;
        }
        final savedText = hasSaved
            ? L10nService().format('habit_reminder_saved', {
                'count': count,
                'date': LocaleDateFormat.dateTime(through),
              })
            : null;
        final detail =
            message ?? savedText ?? context.tr('habit_reminder_empty');
        final showPermission = status == HabitReminderStatus.permissionDenied;
        final showRetry = status == HabitReminderStatus.failed;
        final showSettings = status == HabitReminderStatus.disabled;
        final showLimit = status == HabitReminderStatus.limited;
        final accent = isDark
            ? const Color(0xFFB8E4A9)
            : const Color(0xFF4D7C5B);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.055)
                : const Color(0xFFF2F8EF),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.11)
                  : const Color(0xFFD6E7D1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('habit_reminder_title'),
                          style: SLTheme.quicksand(
                            color: inkColorFor(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          style: SLTheme.quicksand(
                            color: inkColorFor(context).withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                        if (showLimit) ...[
                          const SizedBox(height: 4),
                          Text(
                            context.tr('habit_reminder_limited'),
                            style: SLTheme.quicksand(
                              color: isDark
                                  ? const Color(0xFFFFD28A)
                                  : const Color(0xFF925122),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ] else if (hasSaved) ...[
                          const SizedBox(height: 4),
                          Text(
                            context.tr('habit_reminder_hint'),
                            style: SLTheme.quicksand(
                              color: inkColorFor(
                                context,
                              ).withValues(alpha: 0.62),
                              fontWeight: FontWeight.w600,
                              fontSize: 10.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (showPermission || showRetry || showSettings) ...[
                const SizedBox(height: 9),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    onPressed: showPermission
                        ? _requestHabitNotificationPermission
                        : showSettings
                        ? () => unawaited(app_permission.openAppSettings())
                        : () => unawaited(service.retry()),
                    icon: Icon(
                      showPermission
                          ? Icons.lock_open_rounded
                          : showSettings
                          ? Icons.settings_outlined
                          : Icons.refresh_rounded,
                    ),
                    label: Text(
                      context.tr(
                        showPermission
                            ? 'habit_reminder_enable'
                            : showSettings
                            ? 'home_mcit_a2573b'
                            : 'retry',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color inkColorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF294139);

  @override
  void didUpdateWidget(covariant HabitScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _habitsStream = _watchHabits();
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showSLTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
    final houseId = widget.houseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != _screenUid) return;
    int? habitCount = _observedHabitCount;
    if (habitCount == null && ConnectivityService().isOnline) {
      try {
        final habitSnap = await _dbRef
            .child('houses/$houseId/habits')
            .get()
            .timeout(const Duration(seconds: 3));
        habitCount = habitSnap.value is Map
            ? (habitSnap.value as Map).length
            : 0;
      } catch (_) {
        // Listener chưa có snapshot: hiển thị lỗi thay vì tạo mù vượt giới hạn.
      }
    }
    if (!mounted ||
        widget.houseId != houseId ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    if (habitCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('util_khngticthi_a88c58'))),
      );
      return;
    }
    if (habitCount >= 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('p3_habit_limit_reached')),
          backgroundColor: SLColors.danger,
        ),
      );
      return;
    }

    String? timeString;
    if (_selectedTime != null) {
      timeString =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    }

    final newRef = _dbRef.child('houses/$houseId/habits').push();
    final key = newRef.key;
    final payload = {
      'name': text,
      'creator': widget.myName,
      'time': timeString,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    if (!ConnectivityService().isOnline) {
      ConnectivityService().enqueueOfflineData(
        'houses/$houseId/habits/$key',
        'set',
        payload,
      );
    }
    // RTDB persistence nhận thay đổi ngay cả khi offline; không chờ ACK mạng
    // để thao tác tạo thói quen không treo màn hình khi mất kết nối.
    unawaited(newRef.set(payload).catchError((_) {}));
    unawaited(HabitReminderService.instance.refresh());

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    ActivityHistoryService.instance.add(
      context.tr('util_tomtthique_a49546'),
      houseId: houseId,
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
      builder: (ctx) => SLAlertDialog(
        title: Text(context.tr('p3_habit_delete_title')),
        content: Text(context.tr('p3_habit_delete_message')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('p3_cancel')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,

            onPressed: () {
              Navigator.pop(ctx);
              final path = 'houses/${widget.houseId}/habits/$key';
              if (!ConnectivityService().isOnline) {
                ConnectivityService().enqueueOfflineData(path, 'remove', {});
              }
              _dbRef.child(path).remove();
              unawaited(HabitReminderService.instance.refresh());
            },

            child: Text(context.tr('p3_delete')),
          ),
        ],
      ),
    );
  }

  void _toggleHabitDay(String key, String dateStr, bool currentValue) {
    final parentPath = 'houses/${widget.houseId}/habits/$key/completed_dates';
    final exactPath = '$parentPath/$dateStr';

    if (!ConnectivityService().isOnline) {
      if (currentValue) {
        ConnectivityService().enqueueOfflineData(exactPath, 'remove', {});
      } else {
        ConnectivityService().enqueueOfflineData(parentPath, 'update', {
          dateStr: true,
        });
      }
    }

    if (currentValue) {
      _dbRef.child(exactPath).remove();
    } else {
      _dbRef.child(exactPath).set(true);
    }
    unawaited(HabitReminderService.instance.refresh());
  }

  List<DateTime> _getLast7Days() {
    final today = DateTime.now();
    return List.generate(
      7,
      (index) => CalendarCivilDate.addDays(today, -(6 - index)),
    );
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
        checkDate = CalendarCivilDate.addDays(checkDate, -1);
      } else {
        if (streak == 0 &&
            _formatDateKey(checkDate) == _formatDateKey(DateTime.now())) {
          checkDate = CalendarCivilDate.addDays(checkDate, -1);
          if (completedMap[_formatDateKey(checkDate)] == true) {
            streak++;
            checkDate = CalendarCivilDate.addDays(checkDate, -1);
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
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('util_theodithiq_5cf852')),
        content: Text(context.tr('util_habit_help_body')),
        actions: [
          SLDialogAction(
            primary: true,

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
    _habitFocusNode.dispose();
    super.dispose();
  }

  String _habitMetaLabel(Map<dynamic, dynamic> item) {
    final creator = item['creator']?.toString();
    final time = item['time']?.toString();
    final parts = <String>[];
    if (creator != null && creator.isNotEmpty) {
      parts.add(
        L10nService().format('util_habit_created_by', {'name': creator}),
      );
    }
    if (time != null && time.isNotEmpty) {
      parts.add('⏰ $time');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? Colors.white : const Color(0xFF294139);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.tr('util_theodithiq_362d99'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: inkColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color:
                  (isDark ? const Color(0xFF14251F) : const Color(0xFFF7F4EC))
                      .withValues(alpha: 0.72),
            ),
          ),
        ),
        leading: IconButton(
          tooltip: context.tr('p3_back'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: inkColor,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('util_giithiuthe_3c2cfe'),
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            color: inkColor,
            onPressed: _showHabitInfo,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF14251F), Color(0xFF20372F)]
                : const [Color(0xFFF7F4EC), Color(0xFFE8F1E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(
                width: double.infinity,
                child: Column(children: [Expanded(child: _buildHabitsList())]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF223A31) : Colors.white;
    final inkColor = isDark ? Colors.white : const Color(0xFF294139);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF6F8176);
    final reminderLabel = _selectedTime == null
        ? context.tr('p3_habit_pick_reminder_time')
        : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: isDark ? 0.96 : 0.98),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFDDE8D9),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF476A54,
            ).withValues(alpha: isDark ? 0.08 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEEDF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_task_rounded,
                  color: Color(0xFF4D7C5B),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('p3_habit_add_action'),
                      style: SLTheme.quicksand(
                        color: inkColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('p3_habit_composer_hint'),
                      style: SLTheme.quicksand(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildHabitReminderStatus(),
          const SizedBox(height: 14),
          TextField(
            controller: _habitController,
            focusNode: _habitFocusNode,
            cursorColor: const Color(0xFF4D7C5B),
            style: SLTheme.quicksand(
              color: inkColor,
              fontWeight: FontWeight.w700,
            ),
            maxLength: 50,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: context.tr('util_thiquenmiv_24be39'),
              hintStyle: SLTheme.quicksand(
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
              counterText: '',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF5F8F2),
              prefixIcon: Icon(Icons.edit_note_rounded, color: mutedColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
            ),
            onSubmitted: (_) => _addHabit(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectTime(context),
                  icon: Icon(
                    _selectedTime == null
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_rounded,
                    size: 19,
                  ),
                  label: Text(
                    reminderLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.86)
                        : const Color(0xFF4D6D5A),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : const Color(0xFFC9DDC9),
                    ),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                height: 50,
                child: Semantics(
                  button: true,
                  label: context.tr('p3_habit_add_action'),
                  child: FilledButton(
                    onPressed: _addHabit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4D7C5B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitHero({
    required List<Map<String, dynamic>> items,
    required String todayKey,
  }) {
    var doneToday = 0;
    for (final item in items) {
      final completedMap = item['completed_dates'] != null
          ? Map<dynamic, dynamic>.from(item['completed_dates'])
          : <dynamic, dynamic>{};
      if (completedMap[todayKey] == true) doneToday++;
    }

    final total = items.length;
    final progress = total == 0 ? 0.0 : doneToday / total;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? Colors.white : const Color(0xFF294139);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF668071);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      padding: const EdgeInsets.fromLTRB(18, 17, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF294C3E), Color(0xFF1E3A30)]
              : const [Color(0xFFDCEEDB), Color(0xFFF3EEDC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFD0E2CC),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF486952,
            ).withValues(alpha: isDark ? 0.12 : 0.16),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('p3_habit_today_label'),
                      style: SLTheme.quicksand(
                        color: mutedColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      context.tr('p3_habit_hero_title'),
                      style: SLTheme.quicksand(
                        color: inkColor,
                        fontWeight: FontWeight.w900,
                        fontSize: constraints.maxWidth < 340 ? 19 : 22,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      context.tr('p3_habit_hero_subtitle'),
                      style: SLTheme.quicksand(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress.clamp(0, 1),
                                strokeWidth: 4,
                                backgroundColor: inkColor.withValues(
                                  alpha: 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark
                                      ? const Color(0xFFB8E4A9)
                                      : const Color(0xFF4D7C5B),
                                ),
                              ),
                              Text(
                                '${(progress * 100).round()}%',
                                style: SLTheme.quicksand(
                                  color: inkColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            L10nService().format('p3_habit_progress_label', {
                              'done': doneToday,
                              'total': total,
                            }),
                            style: SLTheme.quicksand(
                              color: inkColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: constraints.maxWidth < 340 ? 104 : 118,
                height: 124,
                child: CustomPaint(
                  painter: _HabitGardenPainter(
                    progress: progress,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyHabitList() {
    return ListView(
      physics: SLResponsive.scrollPhysicsForPlatform(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildHabitHero(
          items: const <Map<String, dynamic>>[],
          todayKey: _formatDateKey(DateTime.now()),
        ),
        _buildInputArea(),
        _buildEmptyHabitState(),
      ],
    );
  }

  void _useHabitSuggestion(String suggestion) {
    setState(() {
      _habitController.value = TextEditingValue(
        text: suggestion,
        selection: TextSelection.collapsed(offset: suggestion.length),
      );
    });
    FocusScope.of(context).requestFocus(_habitFocusNode);
  }

  Widget _buildEmptyHabitState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? Colors.white : const Color(0xFF294139);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF6F8176);
    final suggestions = <({String label, IconData icon})>[
      (
        label: context.tr('p3_habit_suggestion_water'),
        icon: Icons.water_drop_outlined,
      ),
      (
        label: context.tr('p3_habit_suggestion_walk'),
        icon: Icons.directions_walk_rounded,
      ),
      (
        label: context.tr('p3_habit_suggestion_read'),
        icon: Icons.menu_book_rounded,
      ),
      (
        label: context.tr('p3_habit_suggestion_thanks'),
        icon: Icons.favorite_border_rounded,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E332B).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFDCE8D9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8C8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFB66B2C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('p3_habit_empty_title'),
                      style: SLTheme.quicksand(
                        color: inkColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('p3_habit_empty_message'),
                      style: SLTheme.quicksand(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('p3_habit_suggestions_title'),
            style: SLTheme.quicksand(
              color: inkColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final suggestion in suggestions)
                    SizedBox(
                      width: cardWidth,
                      child: Material(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF4F8F1),
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          onTap: () => _useHabitSuggestion(suggestion.label),
                          borderRadius: BorderRadius.circular(17),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  suggestion.icon,
                                  size: 19,
                                  color: isDark
                                      ? const Color(0xFFB8E4A9)
                                      : const Color(0xFF4D7C5B),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    suggestion.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SLTheme.quicksand(
                                      color: inkColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList() {
    return StreamBuilder(
      key: ValueKey(widget.houseId),
      stream: _habitsStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasData) {
          final rawCount = snapshot.data?.snapshot.value;
          _observedHabitCount = rawCount is Map ? rawCount.length : 0;
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            physics: SLResponsive.scrollPhysicsForPlatform(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 4,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: SkeletonContainer.rounded(
                    width: double.infinity,
                    height: 130,
                  ),
                );
              }
              return const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: SkeletonContainer.rounded(
                  width: double.infinity,
                  height: 160,
                ),
              );
            },
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('util_khngticthi_a88c58'),
                  style: SLTheme.quicksand(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _habitsStream = _watchHabits()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('retry')),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return _buildEmptyHabitList();
        }

        final raw = snapshot.data!.snapshot.value;
        if (raw is! Map) {
          return _buildEmptyHabitList();
        }
        final data = Map<dynamic, dynamic>.from(raw);
        final items = data.entries
            .where((e) => e.value is Map)
            .map(
              (e) => {
                'key': e.key,
                ...Map<String, dynamic>.from(e.value as Map),
              },
            )
            .toList();
        if (items.isEmpty) return _buildEmptyHabitList();
        items.sort(
          (a, b) => (a['ts'] as int? ?? 0).compareTo(b['ts'] as int? ?? 0),
        );

        final last7Days = _getLast7Days();
        final todayKey = _formatDateKey(DateTime.now());

        return ListView.builder(
          physics: SLResponsive.scrollPhysicsForPlatform(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: items.isEmpty ? 3 : items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHabitHero(
                items: items.cast<Map<String, dynamic>>(),
                todayKey: todayKey,
              );
            }

            if (index == 1) return _buildInputArea();

            if (items.isEmpty) return _buildEmptyHabitState();

            final item = items[index - 2];
            final completedMap = item['completed_dates'] != null
                ? Map<dynamic, dynamic>.from(item['completed_dates'])
                : {};

            final streak = _calculateHabitStreak(completedMap);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardInk = isDark ? Colors.white : const Color(0xFF294139);
            final cardMuted = isDark
                ? Colors.white.withValues(alpha: 0.68)
                : const Color(0xFF718176);

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: SLSpacing.all20,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF20382F)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFDCE8D9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF476A54,
                    ).withValues(alpha: isDark ? 0.08 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                                color: cardInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            if (item['creator'] != null || item['time'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  _habitMetaLabel(item),
                                  style: SLTheme.quicksand(
                                    color: cardMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.orange.withValues(alpha: 0.2)
                              : const Color(0xFFFFE9C6),
                          borderRadius: SLRadius.mdAll,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Color(0xFFCA7B33),
                              size: 16,
                            ),
                            SLSpacing.w4,
                            Text(
                              L10nService().format('util_habit_streak_days', {
                                'count': streak,
                              }),
                              style: SLTheme.quicksand(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF925122),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: context.tr('p3_habit_pick_reminder_time'),
                        icon: Icon(
                          item['time'] is String &&
                                  (item['time'] as String).trim().isNotEmpty
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: cardMuted,
                          size: 20,
                        ),
                        onSelected: (action) => _handleHabitReminderAction(
                          item['key'].toString(),
                          item['time']?.toString(),
                          action,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'set',
                            child: Text(
                              context.tr('p3_habit_pick_reminder_time'),
                            ),
                          ),
                          if (item['time'] is String &&
                              (item['time'] as String).trim().isNotEmpty)
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Text(context.tr('habit_reminder_remove')),
                            ),
                        ],
                      ),
                      SLSpacing.w4,
                      IconButton(
                        tooltip: context.tr('p3_habit_delete_tooltip'),
                        onPressed: () => _deleteHabit(item['key']),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(Icons.close, color: cardMuted, size: 20),
                      ),
                    ],
                  ),
                  SLSpacing.h20,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: last7Days.map((date) {
                        final dateKey = _formatDateKey(date);
                        final isCompleted = completedMap[dateKey] == true;
                        final isToday =
                            date.day == DateTime.now().day &&
                            date.month == DateTime.now().month;

                        return Semantics(
                          button: true,
                          checked: isCompleted,
                          label: L10nService().format('p3_habit_day_check', {
                            'date': '${date.day}/${date.month}',
                          }),
                          child: SizedBox(
                            width: 48,
                            height: 64,
                            child: GestureDetector(
                              onTap: () => _toggleHabitDay(
                                item['key'],
                                dateKey,
                                isCompleted,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    isToday
                                        ? context.tr('p3_today_short')
                                        : '${date.day}/${date.month}',
                                    style: SLTheme.quicksand(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isToday
                                          ? (isDark
                                                ? Colors.white
                                                : const Color(0xFF4D7C5B))
                                          : cardMuted,
                                    ),
                                  ),
                                  SLSpacing.h8,
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? (isDark
                                                ? const Color(0xFF6BAF70)
                                                : const Color(0xFFCFE8C8))
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : const Color(0xFFF0F5ED)),
                                      borderRadius: SLRadius.mdAll,
                                      border: Border.all(
                                        color: isCompleted
                                            ? const Color(0xFF69A86C)
                                            : (isDark
                                                  ? Colors.white24
                                                  : const Color(0xFFC9DDC9)),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
