import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _SleepTrackerScreenState extends State<SleepTrackerScreen> with TickerProviderStateMixin {
  final _dbRef = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  bool _isTrackingEnabled = false;
  Map<String, dynamic> _presenceData = {};
  Map<String, List<Map<String, dynamic>>> _sleepHistory = {};
  StreamSubscription? _presenceSub;
  StreamSubscription? _historySub;
  StreamSubscription? _settingsSub;
  
  String _myRole = 'husband'; // safe default, updated in _initData()

  String _husbandName = 'Bạn Nam';
  String _wifeName = 'Người ấy';

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadPreferences();
    _initData();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTrackingEnabled = prefs.getBool('is_sleep_tracking_enabled') ?? false;
    });
  }

  Future<void> _toggleTracking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sleep_tracking_enabled', value);
    setState(() {
      _isTrackingEnabled = value;
    });
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _myRole = prefs.getString('il_rel_role') ?? 'husband';

    _settingsSub = _dbRef.child('houses/${widget.houseId}/settings').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final settings = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _husbandName = settings['nameU1'] ?? 'Bạn Nam';
          _wifeName = settings['nameU2'] ?? 'Người ấy';
        });
      }
    });

    _presenceSub = _dbRef.child('houses/${widget.houseId}/presence').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _presenceData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });

    _historySub = _dbRef.child('houses/${widget.houseId}/sleep_history').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final history = <String, List<Map<String, dynamic>>>{};
        
        data.forEach((uid, userHistory) {
          if (userHistory is Map) {
            final sessions = <Map<String, dynamic>>[];
            userHistory.forEach((key, value) {
              sessions.add(Map<String, dynamic>.from(value));
            });
            sessions.sort((a, b) => (b['start_time'] ?? 0).compareTo(a['start_time'] ?? 0));
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
    _presenceSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '--:--';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('HH:mm').format(dt);
  }

  Widget _buildStatusCard(String role, String label, bool isMe) {
    final data = _presenceData[role] ?? {};
    final isSleeping = data['sleep_mode'] == true;
    final sleepStatus = data['sleep_status'] ?? (isSleeping ? 'sleeping' : 'awake');
    final sleepStartTime = data['sleep_start_time'] ?? 0;

    // Xác định trạng thái hiển thị
    final bool isNoonNap = sleepStatus == 'noon_nap';
    final bool isInactive = sleepStatus == 'inactive';
    final bool isActuallySleeping = isSleeping && (sleepStatus == 'sleeping' || isNoonNap);

    // Cấu hình theo trạng thái
    final String emoji = isActuallySleeping
        ? (isNoonNap ? '😴' : '🌛')
        : isInactive
            ? '🌫️'
            : '☀️';
    final String statusText = isActuallySleeping
        ? (isNoonNap ? 'Đang ngủ trưa 💤' : 'Khò khò 💤')
        : isInactive
            ? 'Không hoạt động'
            : 'Đang thức ó ✨';
    final Color glowColor = isActuallySleeping
        ? (isNoonNap ? const Color(0xFF80DEEA) : const Color(0xFF9575CD))
        : isInactive
            ? const Color(0xFF90A4AE)
            : const Color(0xFFFFAB91);
    final Color bgCircleColor = isActuallySleeping
        ? (isNoonNap
            ? const Color(0xFFB2EBF2).withOpacity(0.7)
            : const Color(0xFFE1BEE7).withOpacity(0.6))
        : isInactive
            ? const Color(0xFFCFD8DC).withOpacity(0.4)
            : const Color(0xFFFFF59D).withOpacity(0.9);
    final Color textColor = isActuallySleeping
        ? (isNoonNap ? const Color(0xFF00838F) : const Color(0xFF512DA8))
        : isInactive
            ? const Color(0xFF546E7A)
            : const Color(0xFF3E2723);

    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isActuallySleeping ? 0.35 : isInactive ? 0.4 : 0.65),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isActuallySleeping)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgCircleColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: bgCircleColor.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgCircleColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: bgCircleColor.withOpacity(0.6),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
                ),
              const SizedBox(height: 16),
              Text(
                label,
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF5D4037),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                statusText,
                style: GoogleFonts.quicksand(
                  fontSize: isInactive ? 14 : 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              // Badge cho "Không hoạt động"
              if (isInactive)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF546E7A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Offline / Tắt máy',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF78909C),
                      ),
                    ),
                  ),
                ),
              if (isActuallySleeping && sleepStartTime > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Từ ${_formatTime(sleepStartTime)}',
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildWeeklyChart(String uid, String label) {
    final history = _sleepHistory[uid] ?? [];
    final now = DateTime.now();
    final Map<int, double> dailyHours = {};
    for (int i = 0; i < 7; i++) {
      dailyHours[i] = 0.0;
    }
    
    for (var session in history) {
      final start = session['start_time'] ?? 0;
      final durationMs = session['duration_ms'] ?? 0;
      if (start == 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(start);
      final daysAgo = now.difference(dt).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        dailyHours[daysAgo] = (dailyHours[daysAgo] ?? 0) + (durationMs / (1000 * 60 * 60));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFCDD2).withOpacity(0.25),
                blurRadius: 25,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '7 Ngày Của $label 🌈',
                      style: GoogleFonts.quicksand(
                        color: const Color(0xFF4E342E),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text('✨', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final daysAgo = 6 - index; 
                  final hours = dailyHours[daysAgo] ?? 0.0;
                  final date = now.subtract(Duration(days: daysAgo));
                  final dayStr = DateFormat('E', 'vi').format(date);
                  const target = 8.0; 
                  final percentage = min(hours / target, 1.0);
                  
                  Color barColor;
                  String emoji;
                  if (hours == 0) {
                    barColor = Colors.white.withOpacity(0.6);
                    emoji = '😶';
                  } else if (hours < 4) {
                    barColor = const Color(0xFFFF8A65); 
                    emoji = '😭';
                  } else if (hours < 6) {
                    barColor = const Color(0xFFFFCA28); 
                    emoji = '🥱';
                  } else if (hours <= 8) {
                    barColor = const Color(0xFF66BB6A); 
                    emoji = '😴';
                  } else {
                    barColor = const Color(0xFFEC407A); 
                    emoji = '🐷';
                  }
                      
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 6),
                      if (hours > 0)
                        Text(
                          hours.toStringAsFixed(1),
                          style: GoogleFonts.quicksand(
                            color: const Color(0xFF5D4037),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        width: 32,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.elasticOut,
                          width: 32,
                          height: 110 * percentage,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: hours > 0 
                                  ? [barColor.withOpacity(0.6), barColor] 
                                  : [Colors.transparent, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: hours > 0 ? [
                              BoxShadow(
                                color: barColor.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ] : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        dayStr,
                        style: GoogleFonts.quicksand(
                          color: const Color(0xFF4E342E),
                          fontSize: 14,
                          fontWeight: daysAgo == 0 ? FontWeight.w900 : FontWeight.w700,
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
    final mySleepStatus = myData['sleep_status'] ?? (amISleeping ? 'sleeping' : 'awake');

    final List<Color> bgColors;
    if (mySleepStatus == 'noon_nap') {
      // Nghỉ trưa: xanh cyan mát mẻ
      bgColors = [const Color(0xFFB2EBF2), const Color(0xFFE0F7FA), const Color(0xFFB2DFDB)];
    } else if (amISleeping) {
      // Ngủ đêm: tím mộng mơ
      bgColors = [const Color(0xFFD1C4E9), const Color(0xFFB2EBF2), const Color(0xFFC5CAE9)];
    } else if (mySleepStatus == 'inactive') {
      // Không hoạt động / offline: xám tro
      bgColors = [const Color(0xFFECEFF1), const Color(0xFFCFD8DC), const Color(0xFFB0BEC5)];
    } else {
      // Đang thức: cam ấm
      bgColors = [const Color(0xFFFFE0B2), const Color(0xFFFFCDD2), const Color(0xFFFFF9C4)];
    }


    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Giấc Ngủ ☁️💤',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: const Color(0xFF4E342E),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4E342E)),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFAED581).withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('🪄', style: TextStyle(fontSize: 28)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phép thuật cảm biến',
                                    style: GoogleFonts.quicksand(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      color: const Color(0xFF3E2723),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tự động ghi nhận giấc ngủ',
                                    style: GoogleFonts.quicksand(
                                      fontSize: 13,
                                      color: const Color(0xFF5D4037),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isTrackingEnabled,
                              activeColor: const Color(0xFF81C784),
                              activeTrackColor: const Color(0xFFC8E6C9),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.black12,
                              onChanged: _toggleTracking,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildStatusCard('husband', _husbandName, _myRole == 'husband')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatusCard('wife', _wifeName, _myRole == 'wife')),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  _buildWeeklyChart(_myRole == 'husband' ? _auth.currentUser!.uid : 'husband', _husbandName), // Normally partner UID is unknown, using role as fallback if not me
                  
                  const SizedBox(height: 24),
                  _buildWeeklyChart(_myRole == 'wife' ? _auth.currentUser!.uid : 'wife', _wifeName),
                  
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
