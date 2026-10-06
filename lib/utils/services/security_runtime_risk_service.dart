import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';

import 'security_protection_analytics_service.dart';
import 'security_protection_service.dart';

class SecurityRuntimeRiskService {
  SecurityRuntimeRiskService({
    SecurityProtectionRolloutService? rolloutService,
    SecurityProtectionAnalyticsService? analyticsService,
  })  : _rolloutService = rolloutService ?? SecurityProtectionRolloutService(),
        _analyticsService =
            analyticsService ?? SecurityProtectionAnalyticsService();

  static final SecurityRuntimeRiskService instance =
      SecurityRuntimeRiskService();

  final SecurityProtectionRolloutService _rolloutService;
  final SecurityProtectionAnalyticsService _analyticsService;

  Future<SecurityProtectionVerdict> resolveRisk({
    required SecurityProtectionRiskLevel rawRisk,
    required String actionId,
    required String screenId,
    required String reasonCode,
    List<String> signals = const <String>[],
    String source = 'runtime_guard',
    String eventType = 'risk_detected',
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final verdict = await _rolloutService.resolveVerdict(
      rawRisk: rawRisk,
      actionId: actionId,
      screenId: screenId,
      reasonCode: reasonCode,
      signals: signals,
    );

    unawaited(
      _analyticsService.logDecision(
        verdict: verdict,
        eventType: eventType,
        source: source,
        extra: extra,
      ),
    );
    return verdict;
  }

  Duration defaultCacheTtl(SecurityProtectionVerdict verdict) {
    switch (verdict.reason) {
      case SecurityProtectionReason.overlay:
      case SecurityProtectionReason.screenCapture:
        return const Duration(seconds: 30);
      case SecurityProtectionReason.controlApp:
        return const Duration(seconds: 45);
      case SecurityProtectionReason.unofficialBuild:
      case SecurityProtectionReason.unlicensed:
      case SecurityProtectionReason.malware:
      case SecurityProtectionReason.rootIntegrity:
      case SecurityProtectionReason.playProtect:
        return const Duration(minutes: 5);
      case SecurityProtectionReason.unknown:
        return const Duration(seconds: 30);
    }
  }

  String messageFor(
    SecurityProtectionVerdict verdict, {
    String? fallback,
  }) {
    switch (verdict.reason) {
      case SecurityProtectionReason.overlay:
        return verdict.shouldBlock
            ? UiCopy.text('copy_4c65019179ad')
            : UiCopy.text('copy_7da0d9f6f26a');
      case SecurityProtectionReason.screenCapture:
        return verdict.shouldBlock
            ? UiCopy.text('copy_480f32f85e37')
            : UiCopy.text('copy_da5a08d7d4ca');
      case SecurityProtectionReason.controlApp:
        return verdict.shouldBlock
            ? UiCopy.text('copy_dd1db30752e2')
            : UiCopy.text('copy_36b1ce9c9c38');
      case SecurityProtectionReason.unofficialBuild:
        return UiCopy.text('copy_5825f9687a75');
      case SecurityProtectionReason.unlicensed:
        return UiCopy.text('copy_1616dd499a1d');
      case SecurityProtectionReason.malware:
        return UiCopy.text('copy_876a1960810c');
      case SecurityProtectionReason.rootIntegrity:
        return UiCopy.text('copy_6e66ce81de1d');
      case SecurityProtectionReason.playProtect:
        return UiCopy.text('copy_31a4006da755');
      case SecurityProtectionReason.unknown:
        return fallback ??
            (verdict.shouldBlock
                ? UiCopy.text('copy_1ef37447bbe1')
                : UiCopy.text('copy_6d464d269ffe'));
    }
  }
}
