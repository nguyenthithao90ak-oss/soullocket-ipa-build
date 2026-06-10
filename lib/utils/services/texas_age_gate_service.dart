import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Texas SB 2420 Age Gate Service.
///
/// Uses Google Play Age Signals API (age-sign:0.0.3) to determine if
/// the user is a minor and should have restricted content access.
class TexasAgeGateService {
  TexasAgeGateService._internal();

  static final TexasAgeGateService _instance = TexasAgeGateService._internal();
  factory TexasAgeGateService() => _instance;

  static const MethodChannel _channel = MethodChannel('soul_locket/age_signal');

  /// Cached age classification. Null until resolved.
  AgeClassification? _classification;

  /// Whether the signal has been resolved at least once.
  bool get isResolved => _classification != null;

  /// Returns the cached age classification.
  AgeClassification? get classification => _classification;

  /// Requests the age signal from the native Play Age Signals API.
  ///
  /// On non-Android platforms or when the API is unavailable, defaults to
  /// [AgeClassification.unknown] so the app remains functional outside Texas.
  Future<AgeClassification> resolveAgeSignal() async {
    if (_classification != null) return _classification!;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _classification = AgeClassification.unknown;
      return _classification!;
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getAgeSignal',
      );

      if (result == null) {
        _classification = AgeClassification.unknown;
        return _classification!;
      }

      final raw = result['classification'] as String?;
      _classification = _parseClassification(raw);
      return _classification!;
    } on PlatformException {
      // Age Signals API not available or not set up yet.
      _classification = AgeClassification.unknown;
      return _classification!;
    } catch (_) {
      _classification = AgeClassification.unknown;
      return _classification!;
    }
  }

  /// Convenience: true if the user is identified as a minor.
  bool get isMinor => _classification == AgeClassification.minor;

  /// Convenience: true if the user is identified as an adult.
  bool get isAdult => _classification == AgeClassification.adult;

  AgeClassification _parseClassification(String? raw) {
    if (raw == null) return AgeClassification.unknown;
    switch (raw.toUpperCase()) {
      case 'MINOR':
        return AgeClassification.minor;
      case 'ADULT':
        return AgeClassification.adult;
      default:
        return AgeClassification.unknown;
    }
  }
}

enum AgeClassification { minor, adult, unknown }
