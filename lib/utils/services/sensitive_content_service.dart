import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'security_protection_service.dart';
import 'security_runtime_risk_service.dart';
import 'security_verdict_cache_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

class SensitiveContentService {
  SensitiveContentService._() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  static final SensitiveContentService instance = SensitiveContentService._();

  static const MethodChannel _channel =
      MethodChannel('soul_locket/app_control');
  static const String _methodSetSensitiveProtection = 'setSensitiveProtection';
  static const String _methodProtectedTouchRejected =
      'onProtectedTouchRejected';

  final SecurityRuntimeRiskService _runtimeRiskService =
      SecurityRuntimeRiskService.instance;
  final SecurityVerdictCacheService _verdictCacheService =
      SecurityVerdictCacheService.instance;

  int _protectedScopeCount = 0;
  int _overlayProtectedScopeCount = 0;
  int _lastProtectedTouchSignalAtMs = 0;
  Future<void> _operationQueue = Future<void>.value();

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> pushScope({bool hideOverlays = true}) async {
    if (!_isSupported) return;
    _protectedScopeCount += 1;
    if (hideOverlays) {
      _overlayProtectedScopeCount += 1;
    }
    await _enqueueApply();
  }

  Future<void> popScope({bool hideOverlays = true}) async {
    if (!_isSupported) return;
    if (_protectedScopeCount > 0) {
      _protectedScopeCount -= 1;
    }
    if (hideOverlays && _overlayProtectedScopeCount > 0) {
      _overlayProtectedScopeCount -= 1;
    }
    await _enqueueApply();
  }

  Future<void> refresh() async {
    if (!_isSupported) return;
    await _enqueueApply();
  }

  Future<void> _enqueueApply() {
    _operationQueue =
        _operationQueue.catchError((_) {}).then((_) => _applyCurrentState());
    return _operationQueue;
  }

  Future<void> _applyCurrentState() async {
    final enabled = _protectedScopeCount > 0;
    final hideOverlays = enabled && _overlayProtectedScopeCount > 0;

    try {
      await _channel.invokeMethod<void>(
        _methodSetSensitiveProtection,
        <String, Object?>{
          'enabled': enabled,
          'hideOverlays': hideOverlays,
        },
      );
    } on PlatformException catch (error) {
      debugPrint('SensitiveContentService failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể áp dụng bảo vệ nội dung.',
      ).message}');
    }
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method != _methodProtectedTouchRejected) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastProtectedTouchSignalAtMs < 1200) {
      return;
    }
    _lastProtectedTouchSignalAtMs = nowMs;

    try {
      final rawArgs = call.arguments;
      final args =
          rawArgs is Map ? Map<Object?, Object?>.from(rawArgs) : const {};
      final reasonCode =
          (args['reasonCode']?.toString().trim().toLowerCase() ?? 'overlay');
      final rawSignals = args['signals'];
      final signals = rawSignals is List
          ? rawSignals
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : const <String>['obscured_touch'];

      final verdict = await _runtimeRiskService.resolveRisk(
        rawRisk: SecurityProtectionRiskLevel.block,
        actionId: 'protected_touch_rejected',
        screenId: 'sensitive_content_service',
        reasonCode: reasonCode.isEmpty ? 'overlay' : reasonCode,
        signals: signals,
        source: 'native_overlay_guard',
        eventType: 'protected_touch_rejected',
      );

      if (verdict.effectiveRisk == SecurityProtectionRiskLevel.allow) {
        return;
      }

      await _verdictCacheService.save(
        levelKey: verdict.effectiveRisk.key,
        code: verdict.reasonCode,
        message: _runtimeRiskService.messageFor(verdict),
        payload: <String, dynamic>{
          'source': 'native_overlay_guard',
          'screenId': 'sensitive_content_service',
          'actionId': 'protected_touch_rejected',
          'signals': verdict.signals,
        },
        ttl: _runtimeRiskService.defaultCacheTtl(verdict),
      );
    } catch (error) {
      debugPrint('SensitiveContentService signal handling failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể xử lý tín hiệu bảo vệ nội dung.',
      ).message}');
    }
  }
}
