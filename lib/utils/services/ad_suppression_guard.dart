import 'package:flutter/foundation.dart';

class AdSuppressionGuard {
  AdSuppressionGuard._();

  static final AdSuppressionGuard instance = AdSuppressionGuard._();

  final ValueNotifier<bool> _isSuppressed = ValueNotifier<bool>(false);

  ValueListenable<bool> get isSuppressedListenable => _isSuppressed;

  bool get isSuppressed => _isSuppressed.value;

  /// Call this when starting a critical flow (e.g. starting a call, opening camera)
  void suppressAds() {
    _isSuppressed.value = true;
  }

  /// Call this when exiting a critical flow to resume normal ad flow
  void resumeAds() {
    _isSuppressed.value = false;
  }

  /// Check if ads should be shown right now
  bool get shouldShowAd => !isSuppressed;
}
