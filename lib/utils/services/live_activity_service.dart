import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

import '../../core/constants/app_config.dart';

class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final _liveActivities = LiveActivities();
  String? _activityId;

  // Live Activity chỉ có trên iOS (Dynamic Island/màn khóa). Trên Android plugin trả
  // PlatformException ở mỗi lần gọi, nên bỏ qua để khỏi tốn lượt gọi kênh native vô ích.
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> init() async {
    if (!_supported) return;
    try {
      await _liveActivities.init(appGroupId: AppConfig.iOSAppGroupId);
    } catch (e) {
      debugPrint('[LiveActivityService] Init error: $e');
    }
  }

  Future<void> startOrUpdateActivity({
    required String avatar1,
    required String avatar2,
    required int days,
    required String title,
  }) async {
    if (!_supported) return;
    try {
      final areActivitiesEnabled = await _liveActivities.areActivitiesEnabled();
      if (!areActivitiesEnabled) return;

      final data = {
        'avatar1': avatar1,
        'avatar2': avatar2,
        'days': days,
        'title': title,
      };

      if (_activityId == null) {
        _activityId =
            await _liveActivities.createActivity('couple_activity', data);
        debugPrint('[LiveActivityService] Started Activity: $_activityId');
      } else {
        await _liveActivities.updateActivity(_activityId!, data);
        debugPrint('[LiveActivityService] Updated Activity: $_activityId');
      }
    } catch (e) {
      debugPrint('[LiveActivityService] startOrUpdateActivity error: $e');
    }
  }

  Future<void> endActivity() async {
    if (!_supported) return;
    try {
      if (_activityId != null) {
        await _liveActivities.endActivity(_activityId!);
        _activityId = null;
        debugPrint('[LiveActivityService] Ended Activity');
      } else {
        await _liveActivities.endAllActivities();
      }
    } catch (e) {
      debugPrint('[LiveActivityService] endActivity error: $e');
    }
  }
}
