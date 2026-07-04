import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

class LiveActivitiesService {
  static final LiveActivitiesService _instance = LiveActivitiesService._internal();
  factory LiveActivitiesService() => _instance;
  LiveActivitiesService._internal();

  final _liveActivitiesPlugin = LiveActivities();
  bool _isInitialized = false;
  String? _currentActivityId;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    
    // Khởi tạo Live Activities (Đăng ký App Group nếu có)
    await _liveActivitiesPlugin.init(
      appGroupId: 'group.com.soullocket.app', // Thay đổi theo App Group thực tế
    );
    _isInitialized = true;
  }

  Future<void> startLoveCountdownActivity({
    required DateTime targetDate,
    required String label,
  }) async {
    if (!_isInitialized) return;

    try {
      if (_currentActivityId != null) {
        await _liveActivitiesPlugin.endActivity(_currentActivityId!);
      }

      final activityId = await _liveActivitiesPlugin.createActivity(
        'love_countdown_widget',
        {
          'endTime': (targetDate.millisecondsSinceEpoch ~/ 1000).toString(),
          'label': label,
          'title': 'SoulLocket',
        },
      );
      
      _currentActivityId = activityId;
      debugPrint('[LiveActivitiesService] Started activity: $_currentActivityId');
    } catch (e) {
      debugPrint('[LiveActivitiesService] Error starting activity: $e');
    }
  }

  Future<void> stopActivity() async {
    if (!_isInitialized || _currentActivityId == null) return;
    try {
      await _liveActivitiesPlugin.endActivity(_currentActivityId!);
      _currentActivityId = null;
    } catch (e) {
      debugPrint('[LiveActivitiesService] Error stopping activity: $e');
    }
  }
}
