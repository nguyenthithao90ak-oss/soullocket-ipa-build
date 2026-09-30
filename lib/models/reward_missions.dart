class RewardMission {
  const RewardMission(this.id, this.kind, this.target, this.points, this.icon);

  final String id;
  final String kind;
  final int target;
  final int points;
  final String icon;

  static const all = [
    RewardMission('partner_interaction', 'activity', 3, 10, '💌'),
    RewardMission('map_checkin', 'activity', 1, 25, '📍'),
    RewardMission('diary_entry', 'activity', 1, 20, '📸'),
    RewardMission('simultaneous_online', 'activity', 1, 25, '✨'),
    RewardMission('streak_2', 'streak', 2, 5, '🌱'),
    RewardMission('streak_3', 'streak', 3, 10, '🌷'),
    RewardMission('streak_7', 'streak', 7, 25, '🌸'),
    RewardMission('video_3', 'video', 3, 10, '🎬'),
    RewardMission('video_5', 'video', 5, 15, '🎞️'),
    RewardMission('video_10', 'video', 10, 25, '🌟'),
    RewardMission('video_20', 'video', 20, 50, '🎁'),
  ];

  int progress(Map<String, dynamic> data) {
    final value = data[id];
    final raw = value is Map ? value['progress'] : null;
    return raw is num && raw.isFinite ? raw.toInt().clamp(0, target) : 0;
  }

  bool completed(Map<String, dynamic> data) =>
      data[id] is Map && (data[id] as Map)['done'] == true;
}

DateTime rewardCalendarNow([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));

String rewardDayKey([DateTime? now]) {
  final date = rewardCalendarNow(now);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
