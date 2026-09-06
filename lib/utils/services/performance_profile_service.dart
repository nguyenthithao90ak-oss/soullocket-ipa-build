import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

enum PerformanceTier { low, medium, high }

class PerformanceProfileService {
  PerformanceProfileService._();

  static final PerformanceProfileService instance =
      PerformanceProfileService._();

  static const String _prefKey = 'il_performance_tier_preference';
  PerformanceTier _currentTier = PerformanceTier.medium;

  PerformanceTier get currentTier => _currentTier;

  bool get isLiteMode => _currentTier == PerformanceTier.low;
  bool get enableComplexAnimations => _currentTier != PerformanceTier.low;
  bool get enableGlowAndShadows => _currentTier == PerformanceTier.high;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        _currentTier = _parseTier(saved);
        return;
      }

      // Auto-detect based on hardware/platform characteristics
      _currentTier = _detectHardwareTier();
    } catch (_) {
      _currentTier = PerformanceTier.medium;
    }
  }

  Future<void> setTier(PerformanceTier tier) async {
    _currentTier = tier;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, tier.name);
    } catch (error) {
      debugPrint('[PerformanceProfileService] Cannot persist tier: $error');
    }
  }

  PerformanceTier _parseTier(String name) {
    return PerformanceTier.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PerformanceTier.medium,
    );
  }

  PerformanceTier _detectHardwareTier() {
    if (kIsWeb) {
      return PerformanceTier.medium;
    }

    try {
      // Platform.numberOfProcessors returns the number of logical processors
      final processors = Platform.numberOfProcessors;

      if (processors <= 4) {
        return PerformanceTier.low;
      } else if (processors <= 6) {
        return PerformanceTier.medium;
      } else {
        return PerformanceTier.high;
      }
    } catch (_) {
      return PerformanceTier.medium;
    }
  }
}
