import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/widgets/pin_pad_setup_modal.dart';
import 'package:soullocket_app/widgets/sensitive_content_guard.dart';
import 'auth_service.dart';
import 'security_flow_guard.dart';
import 'settings_sync_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'offline_cache_service.dart';
import 'secure_storage_service.dart';

part 'military_lock/military_lock_cooldown_evaluator.dart';
part 'military_lock/military_lock_models.dart';
part 'military_lock/military_lock_persistence_adapter.dart';
part 'military_lock/military_lock_rule_engine.dart';

class MilitaryLockService {
  static final MilitaryLockService _instance = MilitaryLockService._internal();
  static const String _prefAppLockEnabled = 'il_app_lock_enabled';
  static const String _prefUseBiometrics = 'il_use_biometrics';
  static const String _prefLockTimeout = 'il_lock_timeout';
  static const String _prefMilitaryMode = 'il_military_mode';
  static const String _prefCustomLock = 'il_custom_lock';
  static const String _prefCustomLockSalt = 'il_custom_lock_salt';
  static const String _prefCustomLockLength = 'il_custom_lock_length';
  static const String _prefCustomLockConfiguredAt =
      'il_custom_lock_configured_at';

  static bool isAuthenticatingBiometrics = false;
  static const Duration pinFlexibleChangeWindow = Duration(hours: 12);

  static const String _prefHouseId = 'il_house_id';
  static const String _prefAuthUid = 'il_auth_uid';
  static const String _prefUnlockFailedAttemptsPrefix =
      'il_unlock_failed_attempts_';
  static const String _prefUnlockLockUntilPrefix = 'il_unlock_lock_until_';
  static const int _unlockMaxAttempts = 5;
  static const Duration _resolvedHouseIdCacheTtl = Duration(minutes: 10);
  static const Duration _effectiveLockSettingsCacheTtl = Duration(seconds: 20);

  factory MilitaryLockService() => _instance;
  MilitaryLockService._internal() {
    _authStateSub = _auth.authStateChanges().listen(_handleAuthStateChanged);
    _activeAuthUid = _normalizedAuthUid(_auth.currentUser);
  }

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();
  final Map<String, _EffectiveLockSettingsCacheEntry>
      _effectiveLockSettingsCache =
      <String, _EffectiveLockSettingsCacheEntry>{};
  final Map<String, Future<EffectiveLockSettings>>
      _effectiveLockSettingsInFlight =
      <String, Future<EffectiveLockSettings>>{};
  // Kept to retain the auth-state listener for the lifetime of the singleton.
  // ignore: unused_field
  // ignore: cancel_subscriptions, unused_field
  StreamSubscription<User?>? _authStateSub;

  String? _cachedResolvedHouseId;
  String? _cachedResolvedHouseAuthUid;
  int _cachedResolvedHouseIdAtMs = 0;
  Future<String?>? _resolveHouseIdFuture;
  String? _activeAuthUid;

  final Map<LockScope, bool> _unlockedSession = {
    for (final scope in LockScope.values) scope: false,
  };

  String? _normalizedAuthUid(User? user) {
    final trimmed = user?.uid.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void _handleAuthStateChanged(User? user) {
    final nextUid = _normalizedAuthUid(user);
    if (_activeAuthUid == nextUid) {
      return;
    }

    _activeAuthUid = nextUid;
    _resolveHouseIdFuture = null;
    _effectiveLockSettingsCache.clear();
    _effectiveLockSettingsInFlight.clear();
    _cachedResolvedHouseId = null;
    _cachedResolvedHouseAuthUid = null;
    _cachedResolvedHouseIdAtMs = 0;
    for (final scope in LockScope.values) {
      _unlockedSession[scope] = false;
    }
  }

  static const Map<LockScope, bool> defaultScopeConfig = {
    LockScope.app: true,
    LockScope.security: false,
    LockScope.diary: false,
    LockScope.chat: false,
    LockScope.privateArea: false,
  };

  static const Map<String, bool> defaultScopeStorageConfig = {
    'app': true,
    'security': false,
    'diary': false,
    'chat': false,
    'private': false,
  };

  static Map<String, bool> normalizeScopeStorageConfig(
    Map<String, bool> scopeMap, {
    required bool enabled,
  }) {
    return _MilitaryLockRuleEngine.normalizeScopeStorageConfig(
      scopeMap,
      enabled: enabled,
    );
  }

  Future<bool> isAppLockEnabled({String? houseId}) async {
    final settings = await getEffectiveLockSettings(houseId: houseId);
    return settings.enabled;
  }

  Future<bool> isScopeEnabled(LockScope scope, {String? houseId}) async {
    final settings = await getEffectiveLockSettings(houseId: houseId);
    return settings.isScopeEnabled(scope);
  }

  Future<int> getLockTimeoutMinutes({String? houseId}) async {
    final settings = await getEffectiveLockSettings(houseId: houseId);
    return settings.timeoutMinutes;
  }

  Future<bool> isMilitaryModeEnabled() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return prefs.getBool(_prefMilitaryMode) ?? false;
  }

  Future<String?> resolveHouseId({String? houseId}) async {
    return _resolveHouseId(houseId: houseId);
  }

  Future<String?> getCustomLock(String? houseId) async {
    return getEffectiveLockSecret(houseId: houseId);
  }

  Future<String?> getEffectiveLockSecret({String? houseId}) async {
    final secretRecord = await getEffectiveLockSecretData(houseId: houseId);
    return secretRecord?.secret;
  }

  Future<EffectiveLockSettings> getEffectiveLockSettings({
    String? houseId,
  }) async {
    return _getEffectiveLockSettings(houseId: houseId);
  }

  Future<LockSecretRecord?> getEffectiveLockSecretData({
    String? houseId,
  }) async {
    return _getEffectiveLockSecretData(houseId: houseId);
  }

  LockSecretRecord createStoredLockSecret(String customLock) {
    return _createStoredLockSecret(customLock);
  }

  bool canRevealPlaintextLock({
    required String secret,
    String? salt,
  }) {
    return _canRevealPlaintextLock(secret: secret, salt: salt);
  }

  Future<void> saveLocalLockSettings({
    required bool enabled,
    required bool useBiometrics,
    required int timeoutMinutes,
    required bool militaryMode,
    required String customLock,
    String? customLockSalt,
    int? customLockLength,
    int? configuredAtEpochMs,
    required Map<String, bool> scopeMap,
  }) async {
    await _saveLocalLockSettings(
      enabled: enabled,
      useBiometrics: useBiometrics,
      timeoutMinutes: timeoutMinutes,
      militaryMode: militaryMode,
      customLock: customLock,
      customLockSalt: customLockSalt,
      customLockLength: customLockLength,
      configuredAtEpochMs: configuredAtEpochMs,
      scopeMap: scopeMap,
    );
  }

  Future<void> resetLocalLockSettings({int timeoutMinutes = 0}) async {
    await _resetLocalLockSettings(timeoutMinutes: timeoutMinutes);
  }

  Future<bool> verifyPin(String houseId, String inputPin) async {
    final expected = await getEffectiveLockSecretData(houseId: houseId);
    if (expected == null || !_hasConfiguredSecret(expected.secret)) {
      return false;
    }

    final result = await _attemptUnlock(
      expectedSecret: expected,
      attempt: inputPin.trim(),
      houseId: houseId,
    );
    return result.status == PinUnlockStatus.success;
  }

  bool isScopeUnlocked(LockScope scope) {
    if (kIsWeb && scope == LockScope.privateArea) {
      // On Web, Private Vault is strictly re-authenticated on refresh/re-entry
      return false;
    }
    return _unlockedSession[scope] ?? false;
  }

  void markScopeUnlocked(LockScope scope) {
    _unlockedSession[scope] = true;
    if (scope == LockScope.app) {
      _unlockedSession[LockScope.app] = true;
    }
  }

  void lockAllScopes() {
    for (final scope in LockScope.values) {
      _unlockedSession[scope] = false;
    }
  }

  void lockScope(LockScope scope) {
    _unlockedSession[scope] = false;
  }

  Future<bool> hasConfiguredLock({String? houseId}) async {
    final settings = await getEffectiveLockSettings(houseId: houseId);
    return settings.hasConfiguredSecret;
  }

  Future<bool> needsUnlock(LockScope scope, {String? houseId}) async {
    final settings = await getEffectiveLockSettings(houseId: houseId);
    return _needsUnlockWithSettings(scope, settings);
  }

  bool _needsUnlockWithSettings(
    LockScope scope,
    EffectiveLockSettings settings,
  ) {
    return _MilitaryLockRuleEngine.needsUnlockWithSettings(
      this,
      scope,
      settings,
    );
  }

  Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestUnlock({
    required BuildContext context,
    required LockScope scope,
    String? houseId,
    String? title,
    String? reason,
    bool allowBiometrics = true,
    bool forcePrompt = false,
    bool markUnlockedOnSuccess = true,
    EffectiveLockSettings? effectiveSettings,
  }) async {
    final resolvedSettings =
        effectiveSettings ?? await getEffectiveLockSettings(houseId: houseId);

    if (!forcePrompt && !_needsUnlockWithSettings(scope, resolvedSettings)) {
      return true;
    }

    final bool wantBiometrics =
        allowBiometrics && resolvedSettings.useBiometrics;
    final resolvedTitle = title ?? getScopeTitle(scope);
    final resolvedReason =
        reason ?? 'Xác thực để mở ${resolvedTitle.toLowerCase()}.';

    if (!context.mounted) {
      return false;
    }
    final canContinue = await SecurityFlowGuard.instance.guard(
      context,
      action: SensitiveActionType.pinUnlock,
      houseId: houseId,
    );
    if (!canContinue) {
      return false;
    }

    if (wantBiometrics) {
      final bioSuccess = await _authenticateWithDevice(
        localizedReason: resolvedReason,
      );
      if (bioSuccess) {
        if (markUnlockedOnSuccess) {
          markScopeUnlocked(scope);
        }
        return true;
      }
    }

    final expectedSecret = resolvedSettings.secretRecord;
    if (!context.mounted) return false;
    if (expectedSecret == null || expectedSecret.secret.trim().isEmpty) {
      _showSnack(
        context,
        'Chưa có mật khẩu hoặc PIN cho Khóa app. Hãy vào Cài đặt để thiết lập.',
        isError: true,
      );
      return false;
    }

    final pinSuccess = await _showUnlockDialog(
      context: context,
      title: resolvedTitle,
      expectedSecret: expectedSecret,
      reason: resolvedReason,
      houseId: houseId,
      wantBiometrics: wantBiometrics,
    );

    if (pinSuccess && markUnlockedOnSuccess) {
      markScopeUnlocked(scope);
    }
    return pinSuccess;
  }

  Future<bool> authenticateForSettingsChange({
    required BuildContext context,
    String? houseId,
    required bool allowBiometrics,
  }) async {
    if (allowBiometrics) {
      final bioSuccess = await _authenticateWithDevice(
        localizedReason: 'Xác thực để thay đổi cài đặt khóa ứng dụng.',
      );
      if (bioSuccess) return true;
    }

    final expectedSecret = await getEffectiveLockSecretData(houseId: houseId);
    if (!context.mounted) return false;
    if (expectedSecret == null || expectedSecret.secret.trim().isEmpty) {
      return true;
    }

    return _showUnlockDialog(
      context: context,
      title: 'Xác thực cài đặt khóa',
      expectedSecret: expectedSecret,
      reason: 'Nhập mã khóa hiện tại để thay đổi cài đặt bảo mật.',
      houseId: houseId,
      wantBiometrics: allowBiometrics,
    );
  }

  String? validateCustomLock(String value) {
    return _MilitaryLockRuleEngine.validateCustomLock(value);
  }

  Future<bool> authenticateWithDeviceForTest() async {
    if (isAuthenticatingBiometrics) return false;
    if (!await canUseBiometrics()) return false;
    isAuthenticatingBiometrics = true;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Xác thực để kiểm tra tính năng FaceID/Vân tay',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Kiểm tra sinh trắc học',
            cancelButton: 'Hủy',
            signInHint: 'Chạm cảm biến hoặc nhìn vào camera',
          ),
          IOSAuthMessages(
            localizedFallbackTitle: 'Dùng mã PIN',
            cancelButton: 'Hủy',
          ),
        ],
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('[MilitaryLock] Test Biometric error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra sinh trắc học.',
      ).message}');
      return false;
    } finally {
      isAuthenticatingBiometrics = false;
    }
  }

  Future<bool> _authenticateWithDevice({
    required String localizedReason,
  }) async {
    if (isAuthenticatingBiometrics) return false;
    if (!await canUseBiometrics()) return false;
    isAuthenticatingBiometrics = true;
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Xác thực sinh trắc học',
            cancelButton: 'Dùng mã PIN',
            signInHint: 'Chạm cảm biến hoặc nhìn vào camera',
          ),
          IOSAuthMessages(
            localizedFallbackTitle: 'Dùng mã PIN',
            cancelButton: 'Hủy',
          ),
        ],
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('[MilitaryLock] Biometric error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xác thực sinh trắc học.',
      ).message}');
      return false;
    } finally {
      isAuthenticatingBiometrics = false;
    }
  }

  Future<bool> _showUnlockDialog({
    required BuildContext context,
    required String title,
    required LockSecretRecord expectedSecret,
    required String reason,
    String? houseId,
    bool wantBiometrics = false,
  }) async {
    final normalizedExpectedSecret = expectedSecret.secret.trim();
    final bool hashedSecret = _isStoredSha256(normalizedExpectedSecret);
    final bool numericOnly = expectedSecret.pinLength != null ||
        (!hashedSecret && RegExp(r'^\d+$').hasMatch(normalizedExpectedSecret));
    final unlockState = await _getUnlockGuardState(houseId: houseId);
    if (!context.mounted) {
      return false;
    }

    final recoveryOptions = await getPinRecoveryOptions(houseId: houseId);
    if (!context.mounted) {
      return false;
    }
    final canStartPinRecovery = recoveryOptions.hasAnyRecoveryMethod;
    final forgotPinHint = recoveryOptions.emails.isNotEmpty
        ? recoveryOptions.emails.first.maskedEmail
        : null;

    if (numericOnly) {
      final pin = await PinPadSetupModal.show(
        context,
        title: title,
        subtitle: reason,
        isUnlock: true,
        unlockPinLength: expectedSecret.pinLength,
        initialLockSeconds: unlockState.remainingLockSeconds,
        enableForgotPin:
            canStartPinRecovery || _canQuickDeleteFromSecret(expectedSecret),
        forgotPinHint: forgotPinHint,
        onForgotPin: () => startPinRecoveryAndReset(
          context: context,
          houseId: houseId,
        ),
        unlockValidator: (attempt) => _attemptUnlock(
          expectedSecret: expectedSecret,
          attempt: attempt,
          houseId: houseId,
        ),
        enableBiometrics: wantBiometrics,
        onBiometricPressed: () async {
          final bioSuccess = await _authenticateWithDevice(
            localizedReason: reason,
          );
          if (bioSuccess && context.mounted) {
            Navigator.of(context).pop('');
          }
        },
      );
      return pin != null;
    }

    final controller = TextEditingController();
    bool obscureText = true;
    bool isSubmitting = false;
    String? errorText;
    int remainingLockSeconds = unlockState.remainingLockSeconds;
    Future<void> Function(void Function(void Function()))? restartCountdown;
    final bool? unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            restartCountdown ??= (applyState) async {
              if (remainingLockSeconds <= 0) {
                return;
              }

              while (remainingLockSeconds > 0 && dialogContext.mounted) {
                await Future<void>.delayed(const Duration(seconds: 1));
                if (!dialogContext.mounted || remainingLockSeconds <= 0) {
                  break;
                }
                applyState(() {
                  remainingLockSeconds -= 1;
                  if (remainingLockSeconds > 0) {
                    errorText = _blockedUnlockMessage(remainingLockSeconds);
                    return;
                  }
                  errorText = null;
                });
              }
            };

            Future<void> submitUnlock() async {
              if (isSubmitting || remainingLockSeconds > 0) {
                return;
              }

              final attempt = controller.text.trim();
              setDialogState(() {
                isSubmitting = true;
              });

              final result = await _attemptUnlock(
                expectedSecret: expectedSecret,
                attempt: attempt,
                houseId: houseId,
              );
              if (!dialogContext.mounted) {
                return;
              }

              if (result.status == PinUnlockStatus.success) {
                Navigator.of(dialogContext).pop(true);
                return;
              }

              setDialogState(() {
                isSubmitting = false;
                controller.clear();
                errorText = result.message ?? 'Mã khóa chưa đúng. Hãy thử lại.';
                remainingLockSeconds = result.remainingLockSeconds;
              });

              if (result.status == PinUnlockStatus.blocked &&
                  result.remainingLockSeconds > 0) {
                await restartCountdown?.call(setDialogState);
              }
            }

            return SensitiveContentGuard(
              child: Dialog(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                child: FastBackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: SLSpacing.all20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: Color(0xFFD81B60), size: 48),
                        SLSpacing.h16,
                        Text(title,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD81B60))),
                        SLSpacing.h8,
                        Text(reason,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6D5A74))),
                        SLSpacing.h20,
                        TextField(
                          controller: controller,
                          enabled: remainingLockSeconds == 0 && !isSubmitting,
                          obscureText: obscureText,
                          onSubmitted: (_) {
                            submitUnlock();
                          },
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu khóa',
                            errorText: errorText,
                            suffixIcon: IconButton(
                              icon: Icon(obscureText
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded),
                              onPressed:
                                  remainingLockSeconds > 0 || isSubmitting
                                      ? null
                                      : () => setDialogState(
                                          () => obscureText = !obscureText),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: SLRadius.lgAll),
                          ),
                        ),
                        SLSpacing.h20,
                        Row(
                          children: [
                            if (wantBiometrics) ...[
                              IconButton(
                                icon: Icon(
                                  defaultTargetPlatform == TargetPlatform.iOS
                                      ? Icons.face_retouching_natural_rounded
                                      : Icons.fingerprint_rounded,
                                  color: const Color(0xFFD81B60),
                                ),
                                onPressed:
                                    remainingLockSeconds > 0 || isSubmitting
                                        ? null
                                        : () async {
                                            final bioSuccess =
                                                await _authenticateWithDevice(
                                              localizedReason: reason,
                                            );
                                            if (bioSuccess &&
                                                dialogContext.mounted) {
                                              Navigator.of(dialogContext)
                                                  .pop(true);
                                            }
                                          },
                              ),
                              SLSpacing.w8,
                            ],
                            Expanded(
                                child: TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Để sau'))),
                            SLSpacing.w12,
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed:
                                    remainingLockSeconds > 0 || isSubmitting
                                        ? null
                                        : submitUnlock,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD81B60),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: SLRadius.lgAll)),
                                child: const Text('Mở khóa'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    return unlocked ?? false;
  }

  Future<PinRecoveryOptions> getPinRecoveryOptions({
    String? houseId,
  }) async {
    return _getPinRecoveryOptions(houseId: houseId);
  }

  // ignore: unused_element
  String? _buildPinRecoveryHint(PinRecoveryOptions options) {
    final items = <String>[];
    if ((options.securityQuestion?.trim().isNotEmpty ?? false)) {
      items.add('câu hỏi bảo mật');
    }
    for (final email in options.emails) {
      items.add(email.label.toLowerCase());
    }
    if (options.canQuickDelete) {
      items.add('xóa PIN vừa đặt');
    }
    if (items.isEmpty) {
      return null;
    }
    return items.join(' · ');
  }

  Future<int?> getPinConfiguredAtEpochMs({String? houseId}) async {
    return _getPinConfiguredAtEpochMs(houseId: houseId);
  }

  Future<bool> canChangePinWithoutCurrentAuth({String? houseId}) async {
    return _canChangePinWithoutCurrentAuth(houseId: houseId);
  }

  Future<void> disableLockPin({String? houseId}) async {
    await _disableLockPin(houseId: houseId);
  }

  Future<void> updateLockPin({
    required String newPin,
    String? houseId,
  }) async {
    await _updateLockPin(newPin: newPin, houseId: houseId);
  }

  Future<bool> startPinRecoveryAndReset({
    required BuildContext context,
    String? houseId,
  }) async {
    final canContinue = await SecurityFlowGuard.instance.guard(
      context,
      action: SensitiveActionType.forgotPinReset,
      houseId: houseId,
    );
    if (!canContinue) {
      return false;
    }

    final recoveryOptions = await getPinRecoveryOptions(houseId: houseId);
    if (!context.mounted) {
      return false;
    }
    if (!recoveryOptions.hasAnyRecoveryMethod) {
      _showSnack(
        context,
        'Chưa có câu hỏi bảo mật, email phụ hoặc email chính để khôi phục mã PIN.',
        isError: true,
      );
      return false;
    }
    {
      final selection = await _showRecoveryMethodPicker(
        context: context,
        options: recoveryOptions,
      );
      if (selection == null || !context.mounted) {
        return false;
      }

      if (selection.type == _PinRecoveryMethodType.quickDelete) {
        await disableLockPin(houseId: houseId);
        if (!context.mounted) {
          return false;
        }
        _showSnack(
          context,
          'Đã xóa mã PIN vừa đặt để bạn vào lại app.',
        );
        return true;
      }

      bool verified = false;
      if (selection.type == _PinRecoveryMethodType.securityQuestion) {
        final resolvedHouseId = await resolveHouseId(houseId: houseId);
        if (!context.mounted) {
          return false;
        }
        if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
          _showSnack(
            context,
            'Không tìm thấy nhà để kiểm tra câu hỏi bảo mật.',
            isError: true,
          );
          return false;
        }
        verified = await _showSecurityQuestionRecoveryDialog(
          context: context,
          houseId: resolvedHouseId,
          question: recoveryOptions.securityQuestion ?? '',
        );
      } else {
        final selectedEmail = selection.email;
        if (selectedEmail == null) {
          return false;
        }
        verified = await _showRecoveryOtpDialog(
          context: context,
          recoveryEmail: selectedEmail,
        );
      }
      if (!verified || !context.mounted) {
        return false;
      }

      final firstPin = await PinPadSetupModal.show(
        context,
        title: 'Đặt mã PIN mới',
        subtitle: 'Nhập mã PIN mới để thay thế mã cũ.',
      );
      if (firstPin == null || !context.mounted) {
        return false;
      }

      final confirmedPin = await PinPadSetupModal.show(
        context,
        title: 'Xác nhận mã PIN mới',
        subtitle: 'Nhập lại đúng mã PIN mới để hoàn tất khôi phục.',
        isConfirming: true,
        firstPin: firstPin,
      );
      if (confirmedPin == null || !context.mounted) {
        return false;
      }

      await updateLockPin(
        newPin: confirmedPin,
        houseId: houseId,
      );
      if (!context.mounted) {
        return false;
      }

      _showSnack(
        context,
        'Đã đặt lại mã PIN mới thành công.',
      );
      return true;
    }
    /*
    // ignore: dead_code
    if (!recoveryOptions.hasAnyRecoveryMethod) {
      _showSnack(
        context,
        'Bạn chưa thêm email khôi phục cho mã PIN. Hãy vào Cài đặt > Bảo mật để bổ sung.',
        isError: true,
      );
      return false;
    }

    final verified = await _showRecoveryOtpDialog(
      context: context,
      recoveryEmail: recoveryEmail,
    );
    if (!verified || !context.mounted) {
      return false;
    }

    final firstPin = await PinPadSetupModal.show(
      context,
      title: 'Đặt mã PIN mới',
      subtitle:
          'Nhập mã PIN mới để thay thế mã cũ. Mã chỉ vừa được xác thực qua email khôi phục.',
    );
    if (firstPin == null || !context.mounted) {
      return false;
    }

    final confirmedPin = await PinPadSetupModal.show(
      context,
      title: 'Xác nhận mã PIN mới',
      subtitle: 'Nhập lại đúng mã PIN mới để hoàn tất khôi phục.',
      isConfirming: true,
      firstPin: firstPin,
    );
    if (confirmedPin == null || !context.mounted) {
      return false;
    }

    await updateLockPin(
      newPin: confirmedPin,
      houseId: houseId,
    );
    if (!context.mounted) {
      return false;
    }

    _showSnack(
      context,
      'Đã đặt lại mã PIN mới qua email khôi phục.',
    );
    return true;
    */
  }

  Future<_PinRecoverySelection?> _showRecoveryMethodPicker({
    required BuildContext context,
    required PinRecoveryOptions options,
  }) async {
    return showModalBottomSheet<_PinRecoverySelection>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(
                    width: 44,
                    child: Divider(thickness: 4),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quên mã PIN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chọn cách khôi phục ngay từ màn hình khóa.',
                ),
                const SizedBox(height: 16),
                if ((options.securityQuestion?.trim().isNotEmpty ?? false))
                  _buildRecoveryMethodTile(
                    icon: Icons.quiz_rounded,
                    title: 'Trả lời câu hỏi bảo mật',
                    subtitle: options.securityQuestion!,
                    onTap: () => Navigator.of(sheetContext).pop(
                      const _PinRecoverySelection(
                        type: _PinRecoveryMethodType.securityQuestion,
                      ),
                    ),
                  ),
                for (final email in options.emails)
                  _buildRecoveryMethodTile(
                    icon: Icons.mark_email_read_rounded,
                    title: 'Nhận mã qua ${email.label.toLowerCase()}',
                    subtitle: email.maskedEmail,
                    onTap: () => Navigator.of(sheetContext).pop(
                      _PinRecoverySelection(
                        type: _PinRecoveryMethodType.email,
                        email: email,
                      ),
                    ),
                  ),
                if (options.canQuickDelete)
                  _buildRecoveryMethodTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Xóa mã PIN vừa đặt',
                    subtitle:
                        'Chỉ có trong 12 giờ đầu để tránh đặt nhầm rồi quên.',
                    onTap: () => Navigator.of(sheetContext).pop(
                      const _PinRecoverySelection(
                        type: _PinRecoveryMethodType.quickDelete,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecoveryMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD1E1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFD81B60)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD81B60),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showSecurityQuestionRecoveryDialog({
    required BuildContext context,
    required String houseId,
    required String question,
  }) async {
    final answerController = TextEditingController();
    var isChecking = false;
    String? errorText;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return SensitiveContentGuard(
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Câu hỏi bảo mật'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      question,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: answerController,
                      enabled: !isChecking,
                      decoration: InputDecoration(
                        labelText: 'Câu trả lời',
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isChecking
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: isChecking
                        ? null
                        : () async {
                            final answer = answerController.text.trim();
                            if (answer.isEmpty) {
                              setDialogState(() {
                                errorText = 'Vui lòng nhập câu trả lời.';
                              });
                              return;
                            }
                            setDialogState(() {
                              isChecking = true;
                              errorText = null;
                            });
                            final matched =
                                await _authService.verifySecurityAnswer(
                              houseId,
                              answer,
                            );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            if (matched) {
                              Navigator.of(dialogContext).pop(true);
                              return;
                            }
                            setDialogState(() {
                              isChecking = false;
                              errorText = 'Câu trả lời chưa đúng.';
                            });
                          },
                    child: Text(
                      isChecking ? 'Đang kiểm tra...' : 'Xác nhận',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    answerController.dispose();
    return verified ?? false;
  }

  Future<bool> _showRecoveryOtpDialog({
    required BuildContext context,
    required PinRecoveryEmailRecord recoveryEmail,
  }) async {
    final otpController = TextEditingController();
    var sendStarted = false;
    var isSending = true;
    var isVerifying = false;
    String? errorText;

    Future<void> sendCode(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      setDialogState(() {
        isSending = true;
        errorText = null;
        otpController.clear();
      });

      try {
        await _authService.sendOtpEmail(recoveryEmail.email);
        if (!dialogContext.mounted) {
          return;
        }
        setDialogState(() {
          isSending = false;
        });
      } catch (e) {
        if (!dialogContext.mounted) {
          return;
        }
        setDialogState(() {
          isSending = false;
          errorText = AppErrorMapper.resolve(e).message;
        });
      }
    }

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (!sendStarted) {
              sendStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted) {
                  sendCode(dialogContext, setDialogState);
                }
              });
            }

            final canSubmit = !isSending && !isVerifying;
            return SensitiveContentGuard(
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Khôi phục mã PIN'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSending
                          ? 'Đang gửi mã xác nhận 6 số tới ${recoveryEmail.maskedEmail}...'
                          : 'Mã xác nhận chỉ được gửi tới email khôi phục ${recoveryEmail.maskedEmail}. Nhập mã để đặt lại PIN.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpController,
                      enabled: canSubmit,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Mã xác nhận',
                        counterText: '',
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isVerifying
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: isVerifying
                        ? null
                        : () => sendCode(dialogContext, setDialogState),
                    child: const Text('Gửi lại'),
                  ),
                  ElevatedButton(
                    onPressed: canSubmit
                        ? () async {
                            final otp = otpController.text.trim();
                            if (otp.length != 6) {
                              setDialogState(() {
                                errorText = 'Vui lòng nhập đủ 6 số.';
                              });
                              return;
                            }

                            setDialogState(() {
                              isVerifying = true;
                              errorText = null;
                            });

                            try {
                              await _authService.validateEmailOTP(
                                recoveryEmail.email,
                                otp,
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(true);
                              }
                            } catch (e) {
                              if (!dialogContext.mounted) {
                                return;
                              }
                              setDialogState(() {
                                isVerifying = false;
                                errorText = AppErrorMapper.resolve(e).message;
                              });
                            }
                          }
                        : null,
                    child: Text(
                      isVerifying ? 'Đang kiểm tra...' : 'Xác nhận',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    otpController.dispose();
    return verified ?? false;
  }

  void _showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
      ),
    );
  }

  bool _hasConfiguredSecret(String? value) {
    return _MilitaryLockRuleEngine.hasConfiguredSecret(value);
  }

  bool _canQuickDeleteFromSecret(LockSecretRecord secretRecord) {
    return _MilitaryLockRuleEngine.canQuickDeleteFromSecret(secretRecord);
  }

  static String scopeKey(LockScope scope) {
    return _MilitaryLockRuleEngine.scopeKey(scope);
  }

  static String getScopeTitle(LockScope scope) {
    return _MilitaryLockRuleEngine.getScopeTitle(scope);
  }

  static String scopeReason(LockScope scope) {
    return _MilitaryLockRuleEngine.scopeReason(scope);
  }

  String _scopePrefKey(LockScope scope) {
    return _MilitaryLockRuleEngine.scopePrefKey(scope);
  }

  bool _defaultScopeValue(LockScope scope) {
    return _MilitaryLockRuleEngine.defaultScopeValue(scope);
  }
}
