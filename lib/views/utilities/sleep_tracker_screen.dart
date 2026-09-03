import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../utils/services/core/background_tracking_service.dart';
import '../../utils/services/widget_service.dart';

class SleepTrackerScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const SleepTrackerScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen>
    with TickerProviderStateMixin {
  final _dbRef = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  bool _isTrackingEnabled = false;
  Map<String, dynamic> _presenceData = {};
  Map<String, List<Map<String, dynamic>>> _sleepHistory = {};
  StreamSubscription? _presenceSub;
  StreamSubscription? _historySub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _settingsSub2;

  String _myRole = 'husband';

  String _husbandName = 'Bạn Nam';
  String _wifeName = 'Người ấy';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadPreferences();
    _initData();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isTrackingEnabled = prefs.getBool('is_sleep_tracking_enabled') ?? false;
    });
  }

  Future<void> _toggleTracking(bool value) async {
    if (value) {
      await BackgroundTrackingService.start();
    } else {
      await BackgroundTrackingService.stop();
    }
    if (!mounted) return;
    setState(() {
      _isTrackingEnabled = value;
    });
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _myRole = prefs.getString('il_rel_role') ?? 'husband';

    // Hủy stream cũ trước khi tạo mới (tránh rò rỉ nếu _initData bị gọi lại)
    await _settingsSub?.cancel();
    await _settingsSub2?.cancel();
    await _presenceSub?.cancel();
    await _historySub?.cancel();

    // Chỉ nghe 2 field cần thiết thay vì toàn bộ settings node
    final settingsRef = _dbRef.child('houses/${widget.houseId}/settings');
    _settingsSub = settingsRef.child('nameU1').onValue.listen((event) {
      if (!mounted) return;
      final name = event.snapshot.value as String? ?? 'Bạn Nam';
      setState(() => _husbandName = name);
      _syncWidgetData();
    });
    _settingsSub2 = settingsRef.child('nameU2').onValue.listen((event) {
      if (!mounted) return;
      final name = event.snapshot.value as String? ?? 'Người ấy';
      setState(() => _wifeName = name);
      _syncWidgetData();
    });

    _presenceSub = _dbRef
        .child('houses/${widget.houseId}/presence')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        setState(() {
          _presenceData =
              Map<String, dynamic>.from(event.snapshot.value as Map);
        });
        _syncWidgetData();
      }
    });

    _historySub = _dbRef
        .child('houses/${widget.houseId}/sleep_history')
        .limitToLast(30)
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final history = <String, List<Map<String, dynamic>>>{};

        data.forEach((uid, userHistory) {
          if (userHistory is Map) {
            final sessions = <Map<String, dynamic>>[];
            userHistory.forEach((key, value) {
              sessions.add(Map<String, dynamic>.from(value));
            });
            sessions.sort((a, b) =>
                (b['start_time'] ?? 0).compareTo(a['start_time'] ?? 0));
            history[uid] = sessions;
          }
        });

        setState(() {
          _sleepHistory = history;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _settingsSub?.cancel();
    _settingsSub2?.cancel();
    _presenceSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '--:--';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '';
    final minutes = (ms / (1000 * 60)).round();
    final hours = minutes ~/ 60;
    final remMins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${remMins}m';
    }
    return '${remMins}m';
  }

  void _syncWidgetData() {
    final husbandData = _presenceData['husband'] ?? {};
    final wifeData = _presenceData['wife'] ?? {};

    final isHusbandSleeping = husbandData['sleep_mode'] == true;
    final isWifeSleeping = wifeData['sleep_mode'] == true;

    final husbandStatusText =
        isHusbandSleeping ? '🌙 Đang ngủ 💤' : '☀️ Đang thức';
    final wifeStatusText = isWifeSleeping ? '🌙 Đang ngủ 💤' : '☀️ Đang thức';

    final husbandStartTime =
        (husbandData['sleep_start_time'] as num?)?.toInt() ?? 0;
    final wifeStartTime = (wifeData['sleep_start_time'] as num?)?.toInt() ?? 0;

    final husbandWake = (husbandData['last_screen_on'] as num?)?.toInt() ??
        (husbandData['last_wake_time'] as num?)?.toInt() ??
        0;
    final wifeWake = (wifeData['last_screen_on'] as num?)?.toInt() ??
        (wifeData['last_wake_time'] as num?)?.toInt() ??
        0;

    final husbandTimeStr = isHusbandSleeping
        ? (husbandStartTime > 0
            ? 'Ngủ từ ${_formatTime(husbandStartTime)}'
            : 'Đang ngủ')
        : (husbandWake > 0
            ? 'Thức dậy ${_formatTime(husbandWake)}'
            : 'Đang hoạt động');

    final wifeTimeStr = isWifeSleeping
        ? (wifeStartTime > 0
            ? 'Ngủ từ ${_formatTime(wifeStartTime)}'
            : 'Đang ngủ')
        : (wifeWake > 0
            ? 'Thức dậy ${_formatTime(wifeWake)}'
            : 'Đang hoạt động');

    String summaryText;
    if (isHusbandSleeping && isWifeSleeping) {
      summaryText = 'Cả 2 cùng ngủ 😴';
    } else if (!isHusbandSleeping && !isWifeSleeping) {
      summaryText = 'Cả 2 cùng thức ☀️';
    } else {
      summaryText = 'Một người đang ngủ 🌙';
    }

    WidgetService.updateSleepWidgetData(
      myName: '$_husbandName 🧸',
      partnerName: '$_wifeName 🐰',
      myStatus: husbandStatusText,
      partnerStatus: wifeStatusText,
      myTime: husbandTimeStr,
      partnerTime: wifeTimeStr,
      summary: summaryText,
    );
  }

  Widget _buildStatusCard(String role, String label, bool isMe) {
    final data = _presenceData[role] ?? {};
    final isSleeping = data['sleep_mode'] == true;
    final sleepStatus =
        data['sleep_status'] ?? (isSleeping ? 'sleeping' : 'awake');
    final int sleepStartTime = (data['sleep_start_time'] as num?)?.toInt() ?? 0;
    final int lastScreenOn = (data['last_screen_on'] as num?)?.toInt() ??
        (data['last_wake_time'] as num?)?.toInt() ??
        0;

    final history = _sleepHistory[role] ?? [];
    final lastSession = history.isNotEmpty ? history.first : null;

    final bool isNoonNap = sleepStatus == 'noon_nap';
    final bool isInactive = sleepStatus == 'inactive';
    final bool isActuallySleeping =
        isSleeping && (sleepStatus == 'sleeping' || isNoonNap);

    int wakeUpTimeMs = lastScreenOn;
    if (wakeUpTimeMs <= 0 && lastSession != null) {
      wakeUpTimeMs = (lastSession['end_time'] as num?)?.toInt() ?? 0;
    }

    int lastSleepDurationMs = 0;
    if (lastSession != null) {
      final start = (lastSession['start_time'] as num?)?.toInt() ?? 0;
      final end = (lastSession['end_time'] as num?)?.toInt() ?? 0;
      lastSleepDurationMs = (lastSession['duration_ms'] as num?)?.toInt() ??
          (end > start ? end - start : 0);
    }

    final String emoji = isActuallySleeping
        ? (isNoonNap ? '😴' : '🌛')
        : isInactive
            ? '🌫️'
            : (role == 'husband' ? '🧸' : '🐰');

    final String statusText = isActuallySleeping
        ? (isNoonNap ? 'Đang ngủ trưa 💤' : 'Đang khò khò 💤')
        : isInactive
            ? 'Đang Offline 🌫️'
            : 'Đang thức ó ✨';

    final Color glowColor = isActuallySleeping
        ? (isNoonNap ? const Color(0xFF4DD0E1) : const Color(0xFF9C27B0))
        : isInactive
            ? const Color(0xFF78909C)
            : const Color(0xFFFF4081);

    final Color bgCircleColor = isActuallySleeping
        ? (isNoonNap ? const Color(0xFFE0F7FA) : const Color(0xFFF3E5F5))
        : isInactive
            ? const Color(0xFFECEFF1)
            : const Color(0xFFFFF8E1);

    final Color textColor = isActuallySleeping
        ? (isNoonNap ? const Color(0xFF006064) : const Color(0xFF4A148C))
        : isInactive
            ? const Color(0xFF37474F)
            : const Color(0xFF880E4F);

    final String displayName = isMe ? '$label (Bạn)' : label;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
          decoration: BoxDecoration(
            color: Colors.white
                .withValues(alpha: isActuallySleeping ? 0.55 : 0.75),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.22),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Avatar Badge
              if (isActuallySleeping)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bgCircleColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 36)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgCircleColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.25),
                        blurRadius: 14,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 36)),
                ),
              const SizedBox(height: 12),

              // User Name
              Text(
                displayName,
                style: GoogleFonts.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF3E2723),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Status Tag Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: glowColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // Time badges: Sleep & Wake Time
              if (isActuallySleeping && sleepStartTime > 0) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bedtime_rounded,
                              size: 13, color: Color(0xFF7B1FA2)),
                          const SizedBox(width: 4),
                          Text(
                            'Ngủ lúc ${_formatTime(sleepStartTime)}',
                            style: GoogleFonts.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4A148C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Đã ngủ ${_formatDuration(DateTime.now().millisecondsSinceEpoch - sleepStartTime)}',
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6A1B9A),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isInactive
                                ? Icons.cloud_off_rounded
                                : Icons.wb_sunny_rounded,
                            size: 13,
                            color: isInactive
                                ? const Color(0xFF607D8B)
                                : const Color(0xFFE91E63),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            wakeUpTimeMs > 0
                                ? 'Thức dậy ${_formatTime(wakeUpTimeMs)}'
                                : (isInactive
                                    ? 'Đang Offline'
                                    : 'Đang hoạt động'),
                            style: GoogleFonts.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isInactive
                                  ? const Color(0xFF455A64)
                                  : const Color(0xFFC2185B),
                            ),
                          ),
                        ],
                      ),
                      if (lastSleepDurationMs > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Giấc trước: ${_formatDuration(lastSleepDurationMs)}',
                          style: GoogleFonts.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(String roleOrUid, String label) {
    final history =
        _sleepHistory[roleOrUid] ?? _sleepHistory[_auth.currentUser?.uid] ?? [];
    final now = DateTime.now();
    final Map<int, double> dailyHours = {};
    for (int i = 0; i < 7; i++) {
      dailyHours[i] = 0.0;
    }

    double totalHoursWeek = 0.0;
    int activeDays = 0;

    for (var session in history) {
      final start = (session['start_time'] as num?)?.toInt() ?? 0;
      final durationMs = (session['duration_ms'] as num?)?.toInt() ?? 0;
      if (start == 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(start);
      final daysAgo = now.difference(dt).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        final hrs = durationMs / (1000 * 60 * 60);
        dailyHours[daysAgo] = (dailyHours[daysAgo] ?? 0) + hrs;
      }
    }

    for (int i = 0; i < 7; i++) {
      if ((dailyHours[i] ?? 0) > 0) {
        totalHoursWeek += dailyHours[i]!;
        activeDays++;
      }
    }
    final avgHours = activeDays > 0 ? (totalHoursWeek / activeDays) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: FastBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.9), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF8BBD0).withValues(alpha: 0.3),
                blurRadius: 25,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '7 Ngày Của $label 🌈✨',
                      style: GoogleFonts.quicksand(
                        color: const Color(0xFF3E2723),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8BBD0).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFF48FB1).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      avgHours > 0
                          ? 'Tb: ${avgHours.toStringAsFixed(1)}h/ngày'
                          : '✨ Mục tiêu 8h',
                      style: GoogleFonts.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFC2185B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Bar Chart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final daysAgo = 6 - index;
                  final hours = dailyHours[daysAgo] ?? 0.0;
                  final date = now.subtract(Duration(days: daysAgo));
                  final dayStr = DateFormat('E', 'vi').format(date);
                  final isToday = daysAgo == 0;
                  const target = 8.0;
                  final percentage = min(hours / target, 1.0);

                  List<Color> gradientColors;
                  String emoji;
                  if (hours == 0) {
                    gradientColors = [
                      Colors.white.withValues(alpha: 0.5),
                      Colors.white.withValues(alpha: 0.8)
                    ];
                    emoji = '😶';
                  } else if (hours < 4) {
                    gradientColors = [
                      const Color(0xFFFFAB91),
                      const Color(0xFFFF5722)
                    ];
                    emoji = '😭';
                  } else if (hours < 6) {
                    gradientColors = [
                      const Color(0xFFFFE082),
                      const Color(0xFFFFB300)
                    ];
                    emoji = '🥱';
                  } else if (hours <= 8) {
                    gradientColors = [
                      const Color(0xFFA5D6A7),
                      const Color(0xFF43A047)
                    ];
                    emoji = '😴';
                  } else {
                    gradientColors = [
                      const Color(0xFFF48FB1),
                      const Color(0xFFD81B60)
                    ];
                    emoji = '🥰';
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        hours > 0 ? hours.toStringAsFixed(1) : '-',
                        style: GoogleFonts.quicksand(
                          color: hours > 0
                              ? const Color(0xFF3E2723)
                              : const Color(0xFFB0BEC5),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Column Pillar Container
                      Container(
                        width: 32,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isToday
                                ? const Color(0xFFEC407A)
                                : Colors.white.withValues(alpha: 0.6),
                            width: isToday ? 1.8 : 1.0,
                          ),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          width: 32,
                          height: max(110 * percentage, hours > 0 ? 16.0 : 0.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: hours > 0
                                  ? gradientColors
                                  : [Colors.transparent, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: hours > 0
                                ? [
                                    BoxShadow(
                                      color: gradientColors.last
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Day Label Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isToday
                              ? const Color(0xFFE91E63)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          dayStr,
                          style: GoogleFonts.quicksand(
                            color: isToday
                                ? Colors.white
                                : const Color(0xFF4E342E),
                            fontSize: 13,
                            fontWeight:
                                isToday ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myData = _presenceData[_myRole] ?? {};
    final amISleeping = myData['sleep_mode'] == true;
    final mySleepStatus =
        myData['sleep_status'] ?? (amISleeping ? 'sleeping' : 'awake');

    final List<Color> bgColors;
    if (mySleepStatus == 'noon_nap') {
      bgColors = [
        const Color(0xFFB2EBF2),
        const Color(0xFFE0F7FA),
        const Color(0xFFB2DFDB)
      ];
    } else if (amISleeping) {
      bgColors = [
        const Color(0xFFD1C4E9),
        const Color(0xFFF3E5F5),
        const Color(0xFFC5CAE9)
      ];
    } else if (mySleepStatus == 'inactive') {
      bgColors = [
        const Color(0xFFECEFF1),
        const Color(0xFFCFD8DC),
        const Color(0xFFB0BEC5)
      ];
    } else {
      // Đang thức: Tone Pastel Sunset siêu dễ thương (Hồng Phấn - Cam Nhạt - Vàng Kem)
      bgColors = [
        const Color(0xFFFFD1DC),
        const Color(0xFFFFE4E1),
        const Color(0xFFFFF9C4)
      ];
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Giấc Ngủ Đôi ☁️✨',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: const Color(0xFF3E2723),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
      ),
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Switch Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: FastBackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 1.8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF8BBD0)
                                  .withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC8E6C9)
                                    .withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFAED581)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: const Text('🪄',
                                  style: TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phép thuật cảm biến 🪄✨',
                                    style: GoogleFonts.quicksand(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: const Color(0xFF3E2723),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Tự động ghi nhận giấc ngủ đôi nè ☁️',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 12,
                                      color: const Color(0xFF5D4037),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isTrackingEnabled,
                              activeThumbColor: const Color(0xFFE91E63),
                              activeTrackColor: const Color(0xFFF8BBD0),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.black12,
                              onChanged: _toggleTracking,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Status Cards for Husband & Wife
                  Row(
                    children: [
                      Expanded(
                          child: _buildStatusCard(
                              'husband', _husbandName, _myRole == 'husband')),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _buildStatusCard(
                              'wife', _wifeName, _myRole == 'wife')),
                    ],
                  ),

                  const SizedBox(height: 28),
                  // 7-Day Analytics Charts
                  _buildWeeklyChart('husband', _husbandName),

                  const SizedBox(height: 20),
                  _buildWeeklyChart('wife', _wifeName),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
