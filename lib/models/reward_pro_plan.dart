class RewardProPlan {
  const RewardProPlan({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.points,
    required this.duration,
  });

  final String id;
  final String titleKey;
  final String subtitleKey;
  final int points;
  final Duration duration;

  // Giá khớp catalog PRO_REWARD_PLANS trong functions/vip.js.
  // Server vẫn quyết định số điểm thực sự trừ và quyền được cấp.
  static const all = [
    RewardProPlan(
      id: 'pro_12h',
      titleKey: 'util_gi12gi_9c0202',
      subtitleKey: 'util_tngnhanhth_1c7acb',
      points: 300,
      duration: Duration(hours: 12),
    ),
    RewardProPlan(
      id: 'pro_1d',
      titleKey: 'util_gi1ngy_a2dd38',
      subtitleKey: 'util_dngchodpcb_e94421',
      points: 500,
      duration: Duration(days: 1),
    ),
    RewardProPlan(
      id: 'pro_3d',
      titleKey: 'util_gi3ngy_5c09fc',
      subtitleKey: 'util_cuitunngtn_9e3793',
      points: 1000,
      duration: Duration(days: 3),
    ),
    RewardProPlan(
      id: 'pro_7d',
      titleKey: 'util_gi7ngy_c8c2d1',
      subtitleKey: 'util_mttunmfull_fdb897',
      points: 2000,
      duration: Duration(days: 7),
    ),
    RewardProPlan(
      id: 'pro_30d',
      titleKey: 'util_gi1thng_1e6ebe',
      subtitleKey: 'util_lachntitki_ad5ee5',
      points: 5000,
      duration: Duration(days: 30),
    ),
  ];
}
