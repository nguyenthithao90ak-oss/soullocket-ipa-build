import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class MemoryShareAllowanceGateResult {
  const MemoryShareAllowanceGateResult({
    required this.allow,
    required this.remainingCredits,
    this.rewardGranted = 0,
    this.requiresAd = false,
  });

  final bool allow;
  final int remainingCredits;
  final int rewardGranted;
  final bool requiresAd;
}

class MemoryShareAllowanceService {
  static const String _createCountKey = 'memory_share_create_count_v1';
  static const String _creditsKey = 'memory_share_allowance_credits_v1';

  Future<int> getCreateCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_createCountKey) ?? 0;
  }

  Future<int> getCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_creditsKey) ?? 0;
  }

  Future<bool> requiresCreditForNextCreate() async {
    final createCount = await getCreateCount();
    final nextCount = createCount + 1;
    return nextCount >= 2 && nextCount.isEven;
  }

  Future<MemoryShareAllowanceGateResult> allowNextCreate({
    required Future<bool> Function() showRewardedAd,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final createCount = prefs.getInt(_createCountKey) ?? 0;
    final nextCount = createCount + 1;
    var credits = prefs.getInt(_creditsKey) ?? 0;
    final requiresCredit = nextCount >= 2 && nextCount.isEven;

    var rewardGranted = 0;
    if (requiresCredit && credits <= 0) {
      final watched = await showRewardedAd();
      if (!watched) {
        return const MemoryShareAllowanceGateResult(
          allow: false,
          remainingCredits: 0,
          requiresAd: true,
        );
      }
      rewardGranted = Random().nextBool() ? 2 : 5;
      credits += rewardGranted;
      await prefs.setInt(_creditsKey, credits);
    }

    if (requiresCredit && credits > 0) {
      credits -= 1;
      await prefs.setInt(_creditsKey, credits);
      rewardGranted = 0;
    }

    await prefs.setInt(_createCountKey, nextCount);
    return MemoryShareAllowanceGateResult(
      allow: true,
      remainingCredits: credits,
      rewardGranted: rewardGranted,
      requiresAd: requiresCredit,
    );
  }
}
