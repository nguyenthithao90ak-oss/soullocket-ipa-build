import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'admob_service.dart';
import 'notification_service.dart';

class DailyQuestService {
  static final DailyQuestService _instance = DailyQuestService._internal();
  factory DailyQuestService() => _instance;
  DailyQuestService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AdMobService _adMob = AdMobService();
  final NotificationService _notification = NotificationService();

  static const questsConfig = {
    'partner_interaction': {
      'target': 3,
      'points': 10,
      'title': 'Gửi tín hiệu tình yêu',
      'desc': 'Gửi tương tác (3 lần)',
      'icon': '💌'
    },
    'map_checkin': {
      'target': 1,
      'points': 25,
      'title': 'Check-in cùng nhau',
      'desc': 'Lưu 1 vị trí mới',
      'icon': '📍'
    },
    'diary_entry': {
      'target': 1,
      'points': 20,
      'title': 'Nhật ký chung',
      'desc': 'Đăng 1 ảnh / Ghi chú',
      'icon': '📸'
    },
    'simultaneous_online': {
      'target': 1,
      'points': 25,
      'title': 'Tương tác đồng thời',
      'desc': 'Cả hai cùng online',
      'icon': '✨'
    },
  };

  String _getTodayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  DatabaseReference? _getTodayQuestRef() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _dbRef.child('users/${user.uid}/daily_quests/${_getTodayKey()}');
  }

  Stream<Map<String, dynamic>> streamQuests() {
    final ref = _getTodayQuestRef();
    if (ref == null) return Stream.value({});
    return ref.onValue.map((event) {
      final val = event.snapshot.value;
      if (val is Map) {
        return Map<String, dynamic>.from(val);
      }
      return {};
    });
  }

  Future<void> recordProgress(String questId) async {
    if (_auth.currentUser == null) return;

    final config = questsConfig[questId];
    if (config == null) return;

    final title = config['title'] as String;
    final result = await _adMob.recordDailyQuestProgress(questId);
    final granted = (result?['granted'] as num?)?.toInt() ?? 0;
    if (granted > 0) {
      _onQuestCompleted(granted, title);
    }
  }

  void _onQuestCompleted(int points, String title) {
    _notification.showLocalNotification(
      title: 'Nhiệm vụ hoàn thành! 🎉',
      body: 'Bạn đã hoàn thành "$title" và nhận được +$points điểm.',
      data: {'screen': 'reward_store'},
      dedupeKey: 'quest_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
