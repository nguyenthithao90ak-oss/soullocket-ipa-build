import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/rapid_action_feedback_policy.dart';
import 'device_manager_service.dart';
import 'local_action_throttle_service.dart';
import 'security_protection_service.dart';
import 'security_runtime_risk_service.dart';
import 'security_service.dart';
import 'security_verdict_cache_service.dart';

typedef SecurityPrefsProvider = Future<SharedPreferences> Function();

enum SecurityRiskLevel {
  allow,
  warn,
  block,
}

enum SensitiveActionType {
  loginWithPassword,
  loginWithGoogle,
  loginWithFacebook,
  loginWithApple,
  forgotPasswordSendOtp,
  forgotPasswordReset,
  qrLoginDisplay,
  qrLoginAuthorize,
  verifyPrimaryEmail,
  linkGoogleAccount,
  linkAppleAccount,
  changePassword,
  passwordResetFromSettings,
  setupAppPin,
  changeAppPin,
  pinUnlock,
  forgotPinReset,
  saveSecondaryEmail,
  saveHousePin,
  saveRecoveryInfo,
  deleteAccount,
  exportUserData,
}

class SecurityFlowDecision {
  const SecurityFlowDecision({
    required this.action,
    required this.level,
    required this.title,
    required this.message,
    this.code = '',
  });

  final SensitiveActionType action;
  final SecurityRiskLevel level;
  final String title;
  final String message;
  final String code;

  bool get isAllow => level == SecurityRiskLevel.allow;
}

class _CachedRiskVerdict {
  const _CachedRiskVerdict({
    required this.level,
    required this.code,
    required this.message,
    required this.payload,
  });

  final SecurityRiskLevel? level;
  final String code;
  final String message;
  final Map<String, dynamic> payload;
}

class _SecuritySignalSnapshot {
  const _SecuritySignalSnapshot({
    required this.cachedVerdict,
    required this.isProxyActive,
    required this.isProxyAtLogin,
    required this.isCompromisedDevice,
    required this.trustState,
  });

  final _CachedRiskVerdict? cachedVerdict;
  final bool isProxyActive;
  final bool isProxyAtLogin;
  final bool isCompromisedDevice;
  final DeviceTrustState trustState;
}

class SecurityFlowGuard {
  SecurityFlowGuard({
    SecurityPrefsProvider? prefsProvider,
    DeviceManagerService? deviceManagerService,
    SecurityService? securityService,
    SecurityVerdictCacheService? verdictCacheService,
    LocalActionThrottleService? localActionThrottleService,
    SecurityRuntimeRiskService? runtimeRiskService,
  })  : _deviceManagerService = deviceManagerService ?? DeviceManagerService(),
        _securityService = securityService ?? SecurityService(),
        _verdictCacheService = verdictCacheService ??
            SecurityVerdictCacheService(prefsProvider: prefsProvider),
        _localActionThrottleService =
            localActionThrottleService ?? LocalActionThrottleService.instance,
        _runtimeRiskService =
            runtimeRiskService ?? SecurityRuntimeRiskService.instance;

  static final SecurityFlowGuard instance = SecurityFlowGuard();

  static const Set<SensitiveActionType> _trustedDeviceOnlyActions = {
    SensitiveActionType.qrLoginAuthorize,
    SensitiveActionType.verifyPrimaryEmail,
    SensitiveActionType.linkGoogleAccount,
    SensitiveActionType.linkAppleAccount,
    SensitiveActionType.changePassword,
    SensitiveActionType.passwordResetFromSettings,
    SensitiveActionType.setupAppPin,
    SensitiveActionType.changeAppPin,
    SensitiveActionType.saveSecondaryEmail,
    SensitiveActionType.saveHousePin,
    SensitiveActionType.saveRecoveryInfo,
    SensitiveActionType.exportUserData,
  };

  static const Set<SensitiveActionType> _proxyWarnActions = {
    SensitiveActionType.loginWithPassword,
    SensitiveActionType.loginWithGoogle,
    SensitiveActionType.loginWithFacebook,
    SensitiveActionType.loginWithApple,
    SensitiveActionType.forgotPasswordSendOtp,
    SensitiveActionType.forgotPasswordReset,
    SensitiveActionType.qrLoginDisplay,
    SensitiveActionType.qrLoginAuthorize,
    SensitiveActionType.verifyPrimaryEmail,
    SensitiveActionType.linkGoogleAccount,
    SensitiveActionType.linkAppleAccount,
    SensitiveActionType.changePassword,
    SensitiveActionType.passwordResetFromSettings,
    SensitiveActionType.setupAppPin,
    SensitiveActionType.changeAppPin,
    SensitiveActionType.pinUnlock,
    SensitiveActionType.forgotPinReset,
    SensitiveActionType.saveSecondaryEmail,
    SensitiveActionType.saveHousePin,
    SensitiveActionType.saveRecoveryInfo,
    SensitiveActionType.deleteAccount,
    SensitiveActionType.exportUserData,
  };

  static const Set<SensitiveActionType> _captureBlockedActions = {
    SensitiveActionType.forgotPasswordReset,
    SensitiveActionType.qrLoginDisplay,
    SensitiveActionType.qrLoginAuthorize,
    SensitiveActionType.verifyPrimaryEmail,
    SensitiveActionType.passwordResetFromSettings,
    SensitiveActionType.setupAppPin,
    SensitiveActionType.changeAppPin,
    SensitiveActionType.pinUnlock,
    SensitiveActionType.forgotPinReset,
  };

  static const Set<String> _captureRiskCodes = {
    'screen_capture',
    'screen_recording',
    'screen_share',
    'overlay',
  };

  static const Set<String> _controlRiskCodes = {
    'control_app',
    'accessibility_abuse',
    'auto_click',
    'macro',
    'remote_control',
  };

  static const Set<String> _integrityRiskCodes = {
    'root',
    'fake_integrity',
    'malware',
    'play_protect',
    'sideload',
    'unlicensed',
    'unrecognized_version',
    'modded_app',
  };

  final DeviceManagerService _deviceManagerService;
  final SecurityService _securityService;
  final SecurityVerdictCacheService _verdictCacheService;
  final LocalActionThrottleService _localActionThrottleService;
  final SecurityRuntimeRiskService _runtimeRiskService;

  Future<void> cacheExternalVerdict({
    SecurityRiskLevel? level,
    String code = '',
    String message = '',
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    await _verdictCacheService.save(
      levelKey: level?.name,
      code: code,
      message: message,
      payload: payload,
    );
  }

  Future<void> clearCachedVerdict() async {
    await _verdictCacheService.clear();
  }

  Future<SecurityFlowDecision> evaluate({
    required SensitiveActionType action,
    String? houseId,
  }) async {
    final signals = await _loadSignals();
    final decisions = <SecurityFlowDecision>[];

    final cachedDecision = _decisionFromCachedVerdict(
      action: action,
      verdict: signals.cachedVerdict,
    );
    if (cachedDecision != null && !cachedDecision.isAllow) {
      decisions.add(cachedDecision);
    }

    if (signals.trustState.isBlocked) {
      decisions.add(
        SecurityFlowDecision(
          action: action,
          level: SecurityRiskLevel.block,
          code: 'device_blocked',
          title: 'Thiết bị đang bị chặn',
          message:
              'Thiết bị này đang bị chặn trên nhà hiện tại nên không thể thực hiện thao tác bảo mật này.',
        ),
      );
    }

    if (signals.isCompromisedDevice) {
      decisions.add(
        SecurityFlowDecision(
          action: action,
          level: SecurityRiskLevel.block,
          code: 'compromised_device',
          title: 'Phát hiện thiết bị rủi ro',
          message:
              'Hệ thống phát hiện dấu hiệu root, jailbreak, fake GPS hoặc can thiệp hệ thống. Tạm khóa thao tác nhạy cảm này để bảo vệ tài khoản.',
        ),
      );
    }

    // Device trust check: thiết bị chờ duyệt → warn (không block), thiết bị bị chặn → block
    if (_trustedDeviceOnlyActions.contains(action)) {
      if (signals.trustState.isPendingApproval) {
        decisions.add(
          SecurityFlowDecision(
            action: action,
            level: SecurityRiskLevel.warn,
            code: 'pending_device',
            title: 'Thiết bị đang chờ duyệt',
            message:
                'Thiết bị này đang chờ duyệt. Hãy duyệt trên máy tin cậy để thực hiện thao tác này, hoặc bỏ qua nếu bạn tin thiết bị này.',
          ),
        );
      } else if (signals.trustState.isBlocked) {
        decisions.add(
          SecurityFlowDecision(
            action: action,
            level: SecurityRiskLevel.block,
            code: 'blocked_device',
            title: 'Thiết bị bị chặn',
            message:
                'Thiết bị này đang bị chặn. Hãy dùng thiết bị tin cậy để mở lại quyền truy cập hoặc liên hệ hỗ trợ.',
          ),
        );
      }
    }

    if (_proxyWarnActions.contains(action) &&
        (signals.isProxyActive || signals.isProxyAtLogin)) {
      decisions.add(
        SecurityFlowDecision(
          action: action,
          level: SecurityRiskLevel.warn,
          code: 'proxy_detected',
          title: 'Cảnh báo kết nối',
          message:
              'Hệ thống phát hiện VPN/Proxy đang bật hoặc vừa được dùng ở lần đăng nhập trước. Nếu đây là bạn, hãy xác minh thêm trước khi tiếp tục.',
        ),
      );
    }

    if (decisions.isEmpty) {
      return SecurityFlowDecision(
        action: action,
        level: SecurityRiskLevel.allow,
        title: '',
        message: '',
      );
    }

    decisions.sort((a, b) => _severityOf(b.level) - _severityOf(a.level));
    return decisions.first;
  }

  Future<bool> guard(
    BuildContext context, {
    required SensitiveActionType action,
    String? houseId,
    Future<bool> Function()? onWarnStepUp,
    String? continueLabel,
  }) async {
    final localTapDecision = await _checkRapidTapProtection(action);
    if (localTapDecision != null) {
      if (!context.mounted) {
        return false;
      }
      if (localTapDecision.code == 'rapid_repeat') {
        if (localTapDecision.message.isEmpty) {
          return false;
        }
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(localTapDecision.message),
            duration: const Duration(seconds: 2),
          ),
        );
        return false;
      }
      await _showDecisionDialog(
        context,
        title: localTapDecision.title,
        message: localTapDecision.message,
        isBlocking: true,
      );
      return false;
    }

    final decision = await evaluate(action: action, houseId: houseId);
    if (decision.isAllow || !context.mounted) {
      return decision.isAllow;
    }

    if (decision.level == SecurityRiskLevel.block) {
      await _showDecisionDialog(
        context,
        title: decision.title,
        message: decision.message,
        isBlocking: true,
      );
      return false;
    }

    final confirmed = await _showDecisionDialog(
      context,
      title: decision.title,
      message: decision.message,
      isBlocking: false,
      continueLabel: continueLabel,
      requiresStepUp: onWarnStepUp != null,
    );
    if (confirmed != true) {
      return false;
    }

    if (onWarnStepUp == null) {
      return true;
    }

    try {
      return await onWarnStepUp();
    } catch (_) {
      return false;
    }
  }

  Future<_SecuritySignalSnapshot> _loadSignals() async {
    final cachedVerdictFuture = _readCachedVerdict();
    final proxyFuture = _securityService.isProxyOrVpnActive();
    final compromisedFuture = _securityService.isDeviceCompromised();
    final trustFuture = _loadTrustStateWithRetry();

    return _SecuritySignalSnapshot(
      cachedVerdict: await cachedVerdictFuture,
      isProxyActive: await proxyFuture,
      isProxyAtLogin: _securityService.isProxyAtLogin,
      isCompromisedDevice: await compromisedFuture,
      trustState: await trustFuture,
    );
  }

  Future<DeviceTrustState> _loadTrustStateWithRetry() async {
    final first = await _deviceManagerService.getCurrentDeviceTrustState(
        autoApprove: true);
    if (first.isTrusted || first.isPendingApproval || first.isBlocked) {
      return first;
    }
    if (first.exists && first.status != 'unknown') {
      return first;
    }
    return _deviceManagerService.getCurrentDeviceTrustState(autoApprove: true);
  }

  Future<_CachedRiskVerdict?> _readCachedVerdict() async {
    final cached = await _verdictCacheService.read();
    if (cached == null) {
      return null;
    }

    return _CachedRiskVerdict(
      level: _parseRiskLevel(cached.levelKey ?? ''),
      code: cached.code,
      message: cached.message,
      payload: cached.payload,
    );
  }

  Future<SecurityFlowDecision?> _checkRapidTapProtection(
    SensitiveActionType action,
  ) async {
    final throttle = _localActionThrottleService.registerAttempt(
      'sensitive_action_${action.name}',
      minInterval: const Duration(milliseconds: 900),
      maxAttempts: 4,
      burstWindow: const Duration(seconds: 4),
    );
    if (throttle.isAllowed) {
      return null;
    }

    if (!shouldShowRapidActionWarning(throttle.remainingCooldown)) {
      return SecurityFlowDecision(
        action: action,
        level: SecurityRiskLevel.block,
        code: 'rapid_repeat',
        title: '',
        message: '',
      );
    }

    if (throttle.isRapidRepeat) {
      final waitMs = throttle.remainingCooldown.inMilliseconds;
      final visibleWaitMs = waitMs.clamp(250, 5000);
      return SecurityFlowDecision(
        action: action,
        level: SecurityRiskLevel.block,
        code: 'rapid_repeat',
        title: 'Bạn đang bấm quá nhanh',
        message:
            'Hãy chờ ${_formatMilliseconds(visibleWaitMs)} rồi thử lại để tránh gửi lặp thao tác bảo mật.',
      );
    }

    final verdict = await _runtimeRiskService.resolveRisk(
      rawRisk: SecurityProtectionRiskLevel.block,
      actionId: action.name,
      screenId: 'security_flow_guard',
      reasonCode: 'auto_click',
      signals: <String>[
        'rapid_tap_local',
        'attempt_count:${throttle.attemptCount}',
        'window_ms:${throttle.window.inMilliseconds}',
      ],
      source: 'security_flow_guard',
      eventType: 'rapid_tap_sensitive_action',
      extra: <String, Object?>{
        'attemptCount': throttle.attemptCount,
        'windowMs': throttle.window.inMilliseconds,
      },
    );

    final ttl = _runtimeRiskService.defaultCacheTtl(verdict);
    final message = _runtimeRiskService.messageFor(
      verdict,
      fallback:
          'Phát hiện thao tác nhạy cảm lặp bất thường. Hãy tắt auto click hoặc chờ một lúc rồi thử lại.',
    );

    if (verdict.effectiveRisk != SecurityProtectionRiskLevel.allow) {
      await cacheExternalVerdict(
        level: _toSecurityRiskLevel(verdict.effectiveRisk),
        code: verdict.reasonCode,
        message: message,
        payload: <String, dynamic>{
          'source': 'security_flow_guard',
          'screenId': 'security_flow_guard',
          'actionId': action.name,
          'signals': verdict.signals,
          'expiresAtMs':
              DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds,
        },
      );
    }

    return SecurityFlowDecision(
      action: action,
      level: SecurityRiskLevel.block,
      code: verdict.reasonCode.isEmpty ? 'auto_click' : verdict.reasonCode,
      title: _cachedVerdictTitle(SecurityRiskLevel.block, 'auto_click'),
      message: message,
    );
  }

  SecurityFlowDecision? _decisionFromCachedVerdict({
    required SensitiveActionType action,
    required _CachedRiskVerdict? verdict,
  }) {
    if (verdict == null) return null;

    var level = verdict.level;
    if (level == null || level == SecurityRiskLevel.allow) {
      level = _fallbackLevelFromCode(
        action: action,
        code: verdict.code,
      );
    }
    if (level == null || level == SecurityRiskLevel.allow) {
      return null;
    }

    final title = _cachedVerdictTitle(level, verdict.code);
    final message = verdict.message.isNotEmpty
        ? verdict.message
        : _cachedVerdictMessage(
            action: action,
            code: verdict.code,
            level: level,
          );

    return SecurityFlowDecision(
      action: action,
      level: level,
      code: verdict.code,
      title: title,
      message: message,
    );
  }

  SecurityRiskLevel? _fallbackLevelFromCode({
    required SensitiveActionType action,
    required String code,
  }) {
    if (code.isEmpty) return null;
    if (_captureRiskCodes.contains(code)) {
      return _captureBlockedActions.contains(action)
          ? SecurityRiskLevel.block
          : SecurityRiskLevel.warn;
    }
    if (_controlRiskCodes.contains(code) ||
        _integrityRiskCodes.contains(code)) {
      return SecurityRiskLevel.block;
    }
    return SecurityRiskLevel.warn;
  }

  String _cachedVerdictTitle(SecurityRiskLevel level, String code) {
    if (_captureRiskCodes.contains(code)) {
      return level == SecurityRiskLevel.block
          ? 'Tắt quay màn hình trước khi tiếp tục'
          : 'Cảnh báo quay màn hình';
    }
    if (_controlRiskCodes.contains(code)) {
      return level == SecurityRiskLevel.block
          ? 'Tắt công cụ điều khiển trước khi tiếp tục'
          : 'Cảnh báo điều khiển tự động';
    }
    if (_integrityRiskCodes.contains(code)) {
      return 'Rủi ro bảo mật trên thiết bị';
    }
    return level == SecurityRiskLevel.block
        ? 'Thao tác đang bị khóa'
        : 'Cảnh báo bảo mật';
  }

  String _cachedVerdictMessage({
    required SensitiveActionType action,
    required String code,
    required SecurityRiskLevel level,
  }) {
    if (_captureRiskCodes.contains(code)) {
      if (_captureBlockedActions.contains(action)) {
        return 'Hãy tắt quay màn hình, chia sẻ màn hình hoặc ứng dụng phủ màn hình rồi thử lại.';
      }
      return 'Hệ thống phát hiện dấu hiệu quay màn hình hoặc overlay. Nếu đây là bạn, hãy tắt nó trước khi tiếp tục.';
    }

    if (_controlRiskCodes.contains(code)) {
      return 'Hãy tắt auto click, macro, remote control hoặc accessibility can thiệp rồi thử lại.';
    }

    switch (code) {
      case 'sideload':
      case 'unlicensed':
      case 'unrecognized_version':
      case 'modded_app':
        return 'Hãy cài và sử dụng bản chính thức của ứng dụng rồi thử lại.';
      case 'malware':
      case 'play_protect':
        return 'Hãy quét Play Protect, kiểm tra phần mềm độc hại và khởi động lại thiết bị trước khi thử lại.';
      case 'root':
      case 'fake_integrity':
        return 'Thiết bị đang có dấu hiệu can thiệp hệ thống. Tạm khóa thao tác nhạy cảm này để bảo vệ tài khoản.';
      default:
        return level == SecurityRiskLevel.block
            ? 'Hệ thống tạm khóa thao tác nhạy cảm này vì phát hiện rủi ro bảo mật.'
            : 'Hệ thống phát hiện rủi ro bảo mật mức cảnh báo. Nếu đây là bạn, hãy xác minh thêm trước khi tiếp tục.';
    }
  }

  SecurityRiskLevel? _parseRiskLevel(String raw) {
    switch (raw) {
      case 'allow':
        return SecurityRiskLevel.allow;
      case 'warn':
        return SecurityRiskLevel.warn;
      case 'block':
        return SecurityRiskLevel.block;
      default:
        return null;
    }
  }

  int _severityOf(SecurityRiskLevel level) {
    switch (level) {
      case SecurityRiskLevel.allow:
        return 0;
      case SecurityRiskLevel.warn:
        return 1;
      case SecurityRiskLevel.block:
        return 2;
    }
  }

  SecurityRiskLevel _toSecurityRiskLevel(SecurityProtectionRiskLevel level) {
    switch (level) {
      case SecurityProtectionRiskLevel.allow:
        return SecurityRiskLevel.allow;
      case SecurityProtectionRiskLevel.warn:
        return SecurityRiskLevel.warn;
      case SecurityProtectionRiskLevel.block:
        return SecurityRiskLevel.block;
    }
  }

  String _formatMilliseconds(int value) {
    if (value >= 1000) {
      final seconds = (value / 1000).toStringAsFixed(value >= 2000 ? 0 : 1);
      return '$seconds giây';
    }
    return '$value ms';
  }

  Future<bool?> _showDecisionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isBlocking,
    String? continueLabel,
    bool requiresStepUp = false,
  }) {
    final accent =
        isBlocking ? const Color(0xFFC62828) : const Color(0xFFD81B60);
    final icon = isBlocking ? Icons.block_rounded : Icons.warning_amber_rounded;

    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: !isBlocking,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(icon, color: accent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          actions: [
            if (!isBlocking)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Dừng lại'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(!isBlocking),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isBlocking
                    ? 'Đã hiểu'
                    : continueLabel ??
                        (requiresStepUp ? 'Xác minh thêm' : 'Vẫn tiếp tục'),
              ),
            ),
          ],
        );
      },
    );
  }
}
