import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/sl_theme.dart';

class MoodScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const MoodScreen({super.key, required this.houseId, required this.myName});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<DatabaseEvent>? _myMoodSub;
  StreamSubscription<DatabaseEvent>? _otherMoodSub;

  String _myRole = 'user1';
  String _otherRole = 'user2';

  Map<String, dynamic>? _myMood;
  Map<String, dynamic>? _otherMood;

  final List<String> _emojis = ['😀', '😊', '😍', '😴', '😭', '😡', '🤒', '🤯'];

  @override
  void initState() {
    super.initState();
    _determineRole();
  }

  Future<void> _determineRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot =
          await _dbRef.child('houses/${widget.houseId}/settings').get();
      final raw = snapshot.value;
      if (snapshot.exists && raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        if (data['uid1'] == user.uid) {
          _myRole = 'user1';
          _otherRole = 'user2';
        } else {
          _myRole = 'user2';
          _otherRole = 'user1';
        }
        _listenToMoods();
      }
    }
  }

  void _listenToMoods() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _myMoodSub?.cancel();
    _otherMoodSub?.cancel();

    _myMoodSub = _dbRef
        .child('houses/${widget.houseId}/mood_today/$_myRole')
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        if (data['day'] == today) {
          if (mounted) setState(() => _myMood = data);
        } else {
          if (mounted) setState(() => _myMood = null);
        }
      }
    });

    _otherMoodSub = _dbRef
        .child('houses/${widget.houseId}/mood_today/$_otherRole')
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        if (data['day'] == today) {
          if (mounted) setState(() => _otherMood = data);
        } else {
          if (mounted) setState(() => _otherMood = null);
        }
      }
    });
  }

  @override
  void dispose() {
    _myMoodSub?.cancel();
    _otherMoodSub?.cancel();
    super.dispose();
  }

  Future<void> _setMood(String emoji) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _dbRef.child('houses/${widget.houseId}/mood_today/$_myRole').set({
      'e': emoji,
      'day': today,
      'ts': ServerValue.timestamp,
      'a': widget.myName,
    });
  }

  Map<String, dynamic> _calculateCompatibility() {
    if (_myMood == null || _otherMood == null) return {};

    final myEmoji = _myMood!['e'];
    final otherEmoji = _otherMood!['e'];

    final profile = {
      '😀': {'v': 1, 'e': 1},
      '😊': {'v': 1, 'e': 0},
      '😍': {'v': 2, 'e': 1},
      '😴': {'v': 0, 'e': -1},
      '😭': {'v': -1, 'e': -1},
      '😡': {'v': -2, 'e': 1},
      '🤒': {'v': -1, 'e': -1},
      '🤯': {'v': -2, 'e': 1}
    };

    final a = profile[myEmoji] ?? {'v': 0, 'e': 0};
    final b = profile[otherEmoji] ?? {'v': 0, 'e': 0};

    int score =
        (70 - 15 * (a['v']! - b['v']!).abs() - 10 * (a['e']! - b['e']!).abs())
            .toInt();

    if (myEmoji == otherEmoji) score = 100;
    if (a['v']! >= 1 && b['v']! >= 1) score += 10;
    if (a['v']! < 0 && b['v']! < 0) score += 5;

    score = score.clamp(10, 100);

    String text;
    Color color;
    String hint;

    if (score >= 86) {
      text = 'Rất hợp';
      color = Colors.greenAccent;
      hint = 'Hôm nay 2 bạn đang khá đồng điệu.';
    } else if (score >= 70) {
      text = 'Khá hợp';
      color = Colors.blueAccent;
      hint = 'Hôm nay 2 bạn đang khá đồng điệu.';
    } else if (score >= 52) {
      text = 'Bình thường';
      color = Colors.orangeAccent;
      hint = 'Hãy hỏi nhau một câu nhẹ nhàng để hiểu hơn.';
    } else {
      text = 'Cần quan tâm';
      color = Colors.redAccent;
      hint = 'Một người có thể đang mệt/khó chịu. Nhắn một câu quan tâm nhé.';
    }

    return {'score': score, 'text': text, 'color': color, 'hint': hint};
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ts as int);
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final compat = _calculateCompatibility();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, 'TÂM TRẠNG HÔM NAY 🎭'),
      body: SLTheme.background(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: SLSpacing.all20,
                  child: Column(
                    children: [
                      _buildGlassContainer(
                        child: Column(
                          children: [
                            Text(
                              'Cả 2 cùng chọn emoji tâm trạng. Hệ thống tự phân tích tương hợp.',
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                  color: SLTheme.textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                            SLSpacing.h24,
                            Row(
                              children: [
                                _buildMoodAvatar('Bạn', _myMood?['e'],
                                    _formatTime(_myMood?['ts'])),
                                SLSpacing.w20,
                                _buildMoodAvatar('Người ấy', _otherMood?['e'],
                                    _formatTime(_otherMood?['ts'])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SLSpacing.h20,
                      _buildGlassContainer(
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _emojis.length,
                          itemBuilder: (context, index) {
                            final emoji = _emojis[index];
                            final isSelected = _myMood?['e'] == emoji;
                            return GestureDetector(
                              onTap: () => _setMood(emoji),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFF5F7)
                                      : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? SLTheme.primary
                                        : const Color(0xFFE8D5DF),
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 32)),
                              ),
                            );
                          },
                        ),
                      ),
                      SLSpacing.h20,
                      if (compat.isEmpty)
                        _buildGlassContainer(
                          child: Text(
                            'Chờ cả 2 người chọn tâm trạng để phân tích tương hợp.',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                                color: SLTheme.textLight,
                                fontWeight: FontWeight.w700),
                          ),
                        )
                      else
                        _buildGlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: SLTheme.quicksand(
                                          color: SLTheme.textMain,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16),
                                      children: [
                                        const TextSpan(text: 'Tương hợp: '),
                                        TextSpan(
                                            text: compat['text'],
                                            style: TextStyle(
                                                color: compat['color'])),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${compat['score']}%',
                                    style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w900,
                                        color: compat['color'],
                                        fontSize: 22),
                                  ),
                                ],
                              ),
                              SLSpacing.h16,
                              ClipRRect(
                                borderRadius: SLRadius.smAll,
                                child: LinearProgressIndicator(
                                  value: compat['score'] / 100,
                                  backgroundColor: const Color(0xFFE8D5DF),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      compat['color']),
                                  minHeight: 12,
                                ),
                              ),
                              SLSpacing.h16,
                              Text(
                                'Gợi ý: ${compat['hint']}',
                                style: SLTheme.quicksand(
                                    color: SLTheme.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: SLSpacing.all20,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: SLTheme.glassCardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SLTheme.glassBorder, width: 2.5),
        boxShadow: SLTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildMoodAvatar(String label, String? emoji, String time) {
    return Expanded(
      child: Container(
        padding: SLSpacing.all16,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8D5DF), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label,
                style: SLTheme.quicksand(
                    color: SLTheme.textMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            SLSpacing.h8,
            Text(emoji ?? '—', style: const TextStyle(fontSize: 44)),
            SLSpacing.h4,
            Text(time.isEmpty ? '' : time,
                style: SLTheme.quicksand(
                    fontSize: 11,
                    color: SLTheme.textLight,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
