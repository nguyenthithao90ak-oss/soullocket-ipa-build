import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final _liveActivities = LiveActivities();
  String? _activityId;

  Future<void> init() async {
    try {
      await _liveActivities.init(appGroupId: 'group.com.soullocket.app');
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
