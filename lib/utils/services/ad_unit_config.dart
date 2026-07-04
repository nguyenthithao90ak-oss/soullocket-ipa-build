import 'dart:io';
import 'package:flutter/foundation.dart';

/// Quản lý tất cả Ad Unit IDs (Android + iOS) cho AdMob.
/// Debug mode tự động dùng Google Test IDs.
/// Release mode dùng ID thật từ AdMob Console (ca-app-pub-6165771694697009).
class AdUnitConfig {
  AdUnitConfig._();

  // ─── ANDROID IDs ─────────────────────────────────────────────
  // Có thể được override bởi Firebase remote config lúc runtime
  static String androidRewardedMainId =
      'ca-app-pub-6165771694697009/3441513253';
  static String androidRewardedCheckinId =
      'ca-app-pub-6165771694697009/9710840883';
  static String androidRewardedSoulGameId =
      'ca-app-pub-6165771694697009/5113438527';
  static String androidBannerId = 'ca-app-pub-6165771694697009/5949757521';
  static String androidInterstitialId =
      'ca-app-pub-6165771694697009/6283299015';
  static String androidAppOpenId = 'ca-app-pub-6165771694697009/3305781889';

  // ─── iOS IDs ─────────────────────────────────────────────────
  static String iosRewardedMainId = 'ca-app-pub-6165771694697009/8781411712';
  static String iosRewardedCheckinId = 'ca-app-pub-6165771694697009/8342428018';
  static String iosRewardedSoulGameId =
      'ca-app-pub-6165771694697009/5716264675';
  static String iosBannerId = 'ca-app-pub-6165771694697009/6458500706';
  static String iosInterstitialId = 'ca-app-pub-6165771694697009/1798124404';
  static String iosAppOpenId = 'ca-app-pub-6165771694697009/7141026983';

  // ─── GETTERS (auto-switch debug ↔ release) ───────────────────

  static String get rewardedMainId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    return Platform.isIOS ? iosRewardedMainId : androidRewardedMainId;
  }

  static String get rewardedCheckinId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    return Platform.isIOS ? iosRewardedCheckinId : androidRewardedCheckinId;
  }

  static String get rewardedSoulGameId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    return Platform.isIOS ? iosRewardedSoulGameId : androidRewardedSoulGameId;
  }

  static String get bannerId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111';
    }
    return Platform.isIOS ? iosBannerId : androidBannerId;
  }

  static String get interstitialId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/1033173712';
    }
    return Platform.isIOS ? iosInterstitialId : androidInterstitialId;
  }

  static String get appOpenId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/5575463023'
          : 'ca-app-pub-3940256099942544/9257395921';
    }
    return Platform.isIOS ? iosAppOpenId : androidAppOpenId;
  }
}
