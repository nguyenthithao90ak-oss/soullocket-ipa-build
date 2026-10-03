import '../core/constants/app_config.dart';

class AppReferralProfile {
  const AppReferralProfile({
    required this.code,
    required this.playInstalls,
    required this.joined,
    required this.storeVisits,
    this.rewardDaysPerJoin = 0,
    this.rewardedReferrals = 0,
    this.pendingRewards = 0,
  });

  static final codePattern = RegExp(r'^SL[A-F0-9]{12}$');
  final String code;
  final int playInstalls;
  final int joined;
  final int storeVisits;
  final int rewardDaysPerJoin;
  final int rewardedReferrals;
  final int pendingRewards;

  bool get rewardsEnabled => rewardDaysPerJoin == 1;
  int get rewardedProHours => rewardedReferrals * 24;

  String get link =>
      AppConfig.webUri('/invite', queryParameters: {'code': code}).toString();

  factory AppReferralProfile.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] as String? ?? '').trim().toUpperCase();
    if (!codePattern.hasMatch(code)) {
      throw const FormatException('invalid referral profile');
    }
    int count(String key) => switch (json[key]) {
      final num n when n.isFinite && n >= 0 => n.toInt(),
      _ => 0,
    };
    return AppReferralProfile(
      code: code,
      playInstalls: count('playInstalls'),
      joined: count('joined'),
      storeVisits: count('storeVisits'),
      // Chỉ quảng bá thưởng khi backend xác nhận chính sách đang hoạt động.
      rewardDaysPerJoin:
          json['rewardStatus'] == 'one_day_pro_per_join' &&
              json['rewardDaysPerJoin'] == 1
          ? 1
          : 0,
      rewardedReferrals: count('rewardedReferrals'),
      pendingRewards: count('pendingRewards'),
    );
  }

  static String? codeFromUri(Uri uri) {
    if (!AppConfig.isTrustedWebUri(uri)) return null;
    final raw = uri.path == '/'
        ? uri.queryParameters['referral']
        : const ['/invite', '/invite/open'].contains(uri.path)
        ? uri.queryParameters['code']
        : null;
    final code = raw?.trim().toUpperCase();
    return code != null && codePattern.hasMatch(code) ? code : null;
  }
}
