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
            ? 'Phát hiện lớp phủ màn hình hoặc chạm bị che khuất. Hãy tắt app nổi rồi thử lại.'
            : 'Phát hiện lớp phủ màn hình. Nếu bạn đang bật app nổi, hãy tắt rồi thử lại.';
      case SecurityProtectionReason.screenCapture:
        return verdict.shouldBlock
            ? 'Phát hiện quay hoặc chia sẻ màn hình trên thao tác nhạy cảm. Hãy tắt rồi thử lại.'
            : 'Phát hiện chia sẻ màn hình. Hãy xác minh đây là thao tác của bạn trước khi tiếp tục.';
      case SecurityProtectionReason.controlApp:
        return verdict.shouldBlock
            ? 'Phát hiện bấm quá nhanh hoặc dấu hiệu auto click/macro. Hãy tắt công cụ tự động rồi thử lại.'
            : 'Bạn đang thao tác quá nhanh. Nếu có bật auto click, macro hoặc remote control thì hãy tắt đi.';
      case SecurityProtectionReason.unofficialBuild:
        return 'Ứng dụng hiện tại không được nhận diện là bản phát hành chuẩn. Hãy dùng bản chính thức rồi thử lại.';
      case SecurityProtectionReason.unlicensed:
        return 'Thiết bị hoặc bản cài đặt này chưa được cấp phép. Hãy cài lại bản chính thức rồi thử lại.';
      case SecurityProtectionReason.malware:
        return 'Thiết bị có dấu hiệu rủi ro ứng dụng độc hại. Hãy kiểm tra bảo mật thiết bị trước khi thử lại.';
      case SecurityProtectionReason.rootIntegrity:
        return 'Thiết bị có dấu hiệu root, fake GPS hoặc can thiệp hệ thống. Tạm khóa thao tác để bảo vệ tài khoản.';
      case SecurityProtectionReason.playProtect:
        return 'Play Protect đang trả về cảnh báo rủi ro. Hãy xử lý cảnh báo bảo mật rồi thử lại.';
      case SecurityProtectionReason.unknown:
        return fallback ??
            (verdict.shouldBlock
                ? 'Hệ thống tạm khóa thao tác này vì phát hiện rủi ro bảo mật.'
                : 'Hệ thống phát hiện tín hiệu bất thường. Hãy kiểm tra lại rồi thử tiếp.');
    }
  }
}
