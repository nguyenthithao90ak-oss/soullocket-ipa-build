import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/activity_history_service.dart';

// ============================================================
// PHASE 37: DAILY LOVE CHALLENGE — GRA FULLSTACK
// ============================================================

class DailyChallengeService {
  static final DailyChallengeService _i = DailyChallengeService._();
  factory DailyChallengeService() => _i;
  DailyChallengeService._();
  final _db = FirebaseDatabase.instance;

  Future<String> _resolvedActivityRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    return role;
  }

  static const List<Map<String, String>> _challengePool = [
    {'text': 'Compliment người ấy 3 lần hôm nay 💬', 'icon': '💬'},
    {'text': 'Nấu một bữa ăn cùng nhau tối nay 🍳', 'icon': '🍳'},
    {'text': 'Gửi 5 ảnh kỷ niệm đẹp nhất cho nhau 📸', 'icon': '📸'},
    {'text': 'Viết 1 thư tình ngắn ít nhất 50 chữ ✍️', 'icon': '✍️'},
    {'text': 'Gọi điện thoại nói chuyện ít nhất 30 phút 📞', 'icon': '📞'},
    {'text': 'Đặt hẹn đi xem phim hoặc ăn tối tuần này 🎬', 'icon': '🎬'},
    {'text': 'Nói "anh/em yêu em/anh" lúc 12h đêm nay 🌙', 'icon': '🌙'},
    {'text': 'Làm 1 điều bất ngờ nho nhỏ cho người ấy 🎁', 'icon': '🎁'},
  ];

  Map<String, String> getTodaysChallenge() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _challengePool[dayOfYear % _challengePool.length];
  }

  Future<void> markChallengeComplete(String houseId, String uid) async {
    final today = DateTime.now().toString().substring(0, 10);
    await _db.ref('houses/$houseId/daily_challenge/$today/$uid').set({
      'completed': true,
      'ts': ServerValue.timestamp,
    });
    // Tăng streak
    await _db
        .ref('houses/$houseId/challenge_streak/$uid')
        .set(ServerValue.increment(1));
  }

  Future<void> markChallengeCompleteWithTimeline(
    String houseId,
    String uid,
  ) async {
    final today = DateTime.now().toString().substring(0, 10);
    final todayRef = _db.ref('houses/$houseId/daily_challenge/$today/$uid');
    final existing = await todayRef.get();
    if (existing.exists && existing.value is Map) {
      final data = Map<dynamic, dynamic>.from(existing.value as Map);
      if (data['completed'] == true) {
        return;
      }
    }

    await markChallengeComplete(houseId, uid);
    try {
      final role = await _resolvedActivityRole();
      await ActivityHistoryService.instance.add(
        'đã hoàn thành thử thách hôm nay',
        houseId: houseId,
        role: role,
      );
    } catch (_) {}
  }

  Future<int> getStreak(String houseId, String uid) async {
    final snap = await _db.ref('houses/$houseId/challenge_streak/$uid').get();
    return (snap.value as int?) ?? 0;
  }

  Stream<Map<dynamic, dynamic>?> listenToTodayProgress(String houseId) {
    final today = DateTime.now().toString().substring(0, 10);
    return _db.ref('houses/$houseId/daily_challenge/$today').onValue.map((e) {
      final raw = e.snapshot.value;
      if (!e.snapshot.exists || raw is! Map) return null;
      return Map<dynamic, dynamic>.from(raw);
    });
  }
}

class DailyChallengeScreen extends StatefulWidget {
  final String houseId;
  final String myUid;
  const DailyChallengeScreen(
      {super.key, required this.houseId, required this.myUid});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen>
    with TickerProviderStateMixin {
  final _svc = DailyChallengeService();
  late AnimationController _confettiCtrl;
  bool _myDone = false;
  bool _partnerDone = false;
  int _streak = 0;
  late Map<String, String> _todayChallenge;

  @override
  void initState() {
    super.initState();
    _todayChallenge = _svc.getTodaysChallenge();
    _confettiCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _loadData();

    _svc.listenToTodayProgress(widget.houseId).listen((data) {
      if (data == null || !mounted) return;
      setState(() {
        _myDone = data[widget.myUid]?['completed'] == true;
        _partnerDone = data.entries
            .any((e) => e.key != widget.myUid && e.value['completed'] == true);
      });
    });
  }

  Future<void> _loadData() async {
    final streak = await _svc.getStreak(widget.houseId, widget.myUid);
    if (mounted) setState(() => _streak = streak);
  }

  Future<void> _complete() async {
    await _svc.markChallengeCompleteWithTimeline(widget.houseId, widget.myUid);
    _confettiCtrl.forward(from: 0);
    _loadData();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: SLSpacing.all24,
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white)),
                  Expanded(
                      child: Text('Thử Thách Hôm Nay 🔥',
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20))),
                  SLSpacing.gapW(48),
                ]),
                SLSpacing.gapH(30),
                // Streak badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    SLSpacing.w8,
                    Text('Streak $_streak ngày',
                        style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ]),
                ),
                SLSpacing.gapH(30),
                // Challenge card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: SLRadius.xlAll,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(_todayChallenge['icon']!,
                          style: const TextStyle(fontSize: 60)),
                      SLSpacing.h16,
                      Text('THÁCH THỨC HÔM NAY',
                          style: SLTheme.quicksand(
                              color: Colors.grey,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 1.5)),
                      SLSpacing.h8,
                      Text(_todayChallenge['text']!,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                              color: const Color(0xFF11998e),
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                    ],
                  ),
                ),
                SLSpacing.gapH(30),
                // Progress of both
                Row(children: [
                  Expanded(child: _buildPlayerStatus('Bạn', _myDone)),
                  SLSpacing.w16,
                  Expanded(child: _buildPlayerStatus('Người ấy', _partnerDone)),
                ]),
                SLSpacing.gapH(30),
                // Complete button
                if (!_myDone)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _complete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll),
                        elevation: 0,
                      ),
                      child: Text('✅ HOÀN THÀNH THÁCH THỨC!',
                          style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: const Color(0xFF11998e))),
                    ),
                  )
                else
                  Column(children: [
                    const Text('🎉', style: TextStyle(fontSize: 50)),
                    Text('Bạn đã hoàn thành hôm nay!',
                        style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerStatus(String name, bool done) {
    return Container(
      padding: SLSpacing.all16,
      decoration: BoxDecoration(
        color: done ? Colors.white : Colors.white24,
        borderRadius: SLRadius.lgAll,
      ),
      child: Column(children: [
        Text(done ? '✅' : '⏳', style: const TextStyle(fontSize: 28)),
        SLSpacing.h8,
        Text(name,
            style: SLTheme.quicksand(
                color: done ? const Color(0xFF11998e) : Colors.white,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
