import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'admob_service.dart';

import 'notification_service.dart';
import 'l10n_service.dart';
import '../../models/reward_missions.dart';

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
      'title': 'companion_journey_quest_partner_interaction',
      'desc': 'reward_store_partner_hint',
      'icon': '💌',
    },
    'map_checkin': {
      'target': 1,
      'points': 25,
      'title': 'companion_journey_quest_map_checkin',
      'desc': 'reward_store_map_hint',
      'icon': '📍',
    },
    'diary_entry': {
      'target': 1,
      'points': 20,
      'title': 'companion_journey_quest_diary_entry',
      'desc': 'reward_store_diary_hint',
      'icon': '📸',
    },
    'simultaneous_online': {
      'target': 1,
      'points': 25,
      'title': 'companion_journey_quest_simultaneous_online',
      'desc': 'reward_store_online_hint',
      'icon': '✨',
    },
  };

  String _getTodayKey() {
    return rewardDayKey();
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

    final normalizedQuestId = questId.trim();
    if (normalizedQuestId.isEmpty) return;

    final config = questsConfig[normalizedQuestId];
    if (config == null) return;

    try {
      final title = L10nService().translate(config['title'] as String);
      final result = await _adMob.recordDailyQuestProgress(normalizedQuestId);
      final granted = (result?['granted'] as num?)?.toInt() ?? 0;
      if (granted > 0) {
        _onQuestCompleted(granted, title);
      }
    } catch (e) {
      debugPrint(
        'Daily quest progress error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể ghi tiến độ nhiệm vụ ngày.').message}',
      );
    }
  }

  void _onQuestCompleted(int points, String title) {
    _notification.showLocalNotification(
      title: '${L10nService().translate('reward_store_completed')} · $title',
      body: L10nService()
          .translate('ad_reward_points_received')
          .replaceAll('{points}', '$points'),
      data: {'screen': 'reward_store'},
      dedupeKey: 'quest_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
