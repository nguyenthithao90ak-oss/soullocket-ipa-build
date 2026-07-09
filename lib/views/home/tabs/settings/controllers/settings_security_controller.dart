import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../../../utils/services/military_lock_service.dart';
import '../security/device_trust_guard.dart';

class SettingsSecurityShellState {
  const SettingsSecurityShellState({
    required this.isSecurityLocked,
    required this.isCheckingSecurityLock,
    required this.isDevicePending,
    required this.devicePendingMessage,
    required this.devicePendingUnlockAtMs,
  });

  const SettingsSecurityShellState.initial()
      : isSecurityLocked = false,
        isCheckingSecurityLock = true,
        isDevicePending = false,
        devicePendingMessage = '',
        devicePendingUnlockAtMs = 0;

  final bool isSecurityLocked;
  final bool isCheckingSecurityLock;
  final bool isDevicePending;
  final String devicePendingMessage;
  final int devicePendingUnlockAtMs;

  SettingsSecurityShellState copyWith({
    bool? isSecurityLocked,
    bool? isCheckingSecurityLock,
    bool? isDevicePending,
    String? devicePendingMessage,
    int? devicePendingUnlockAtMs,
  }) {
    return SettingsSecurityShellState(
      isSecurityLocked: isSecurityLocked ?? this.isSecurityLocked,
      isCheckingSecurityLock:
          isCheckingSecurityLock ?? this.isCheckingSecurityLock,
      isDevicePending: isDevicePending ?? this.isDevicePending,
      devicePendingMessage: devicePendingMessage ?? this.devicePendingMessage,
      devicePendingUnlockAtMs:
          devicePendingUnlockAtMs ?? this.devicePendingUnlockAtMs,
    );
  }
}

class SettingsModifyGuardResult {
  const SettingsModifyGuardResult({
    required this.canModify,
    required this.isPendingDevice,
    required this.isTrustUnavailable,
    required this.pendingMessage,
    required this.pendingUnlockAtMs,
  });

  final bool canModify;
  final bool isPendingDevice;
  final bool isTrustUnavailable;
  final String pendingMessage;
  final int pendingUnlockAtMs;
}

class SettingsSecurityController {
  SettingsSecurityController({
    MilitaryLockService? militaryLockService,
    DeviceTrustGuard? deviceTrustGuard,
  })  : _militaryLockService = militaryLockService ?? MilitaryLockService(),
        _deviceTrustGuard = deviceTrustGuard ?? DeviceTrustGuard();

  final MilitaryLockService _militaryLockService;
  final DeviceTrustGuard _deviceTrustGuard;

  Future<SettingsModifyGuardResult> ensureSharedInfoEditable({
    bool autoApprove = true,
    int fallbackUnlockAtMs = 0,
  }) async {
    final trust = await _deviceTrustGuard.resolve(
      autoApprove: autoApprove,
      fallbackUnlockAtMs: fallbackUnlockAtMs,
    );
    return SettingsModifyGuardResult(
      canModify: trust.isTrusted,
      isPendingDevice: trust.isPendingDevice,
      isTrustUnavailable: trust.isTrustUnavailable,
      pendingMessage: trust.pendingMessage,
      pendingUnlockAtMs: trust.autoApproveAtMs,
    );
  }

  Future<SettingsSecurityShellState> resolveSecurityShellState({
    required BuildContext context,
    required String? houseId,
    required SettingsSecurityShellState currentState,
  }) async {
    final effectiveSettings =
        await _militaryLockService.getEffectiveLockSettings(houseId: houseId);
    final isAppLockEnabled = effectiveSettings.enabled;
    final isScopeSecurityEnabled =
        effectiveSettings.isScopeEnabled(LockScope.security);

    if (!isAppLockEnabled || !isScopeSecurityEnabled) {
      return currentState.copyWith(
        isDevicePending: false,
        devicePendingMessage: '',
        devicePendingUnlockAtMs: 0,
        isSecurityLocked: false,
        isCheckingSecurityLock: false,
      );
    }

    final trust = await _deviceTrustGuard.resolve(
      fallbackUnlockAtMs: currentState.devicePendingUnlockAtMs,
    );
    if (!context.mounted) {
      return currentState;
    }
    if (!trust.isTrusted) {
      return currentState.copyWith(
        isDevicePending: trust.isPendingDevice,
        devicePendingMessage: trust.pendingMessage,
        devicePendingUnlockAtMs: trust.autoApproveAtMs,
        isSecurityLocked: false,
        isCheckingSecurityLock: false,
      );
    }

    var authSuccess = false;
    try {
      authSuccess = await _militaryLockService.requestUnlock(
        context: context,
        scope: LockScope.security,
        houseId: houseId,
        title: context.tr('home_khubomt_2143a3'),
        reason: MilitaryLockService.scopeReason(LockScope.security),
        effectiveSettings: effectiveSettings,
      );
    } catch (_) {
      authSuccess = false;
    }

    return currentState.copyWith(
      isDevicePending: false,
      devicePendingMessage: '',
      devicePendingUnlockAtMs: 0,
      isSecurityLocked: !authSuccess,
      isCheckingSecurityLock: false,
    );
  }

  Future<bool> authenticateLockSettingsChange({
    required BuildContext context,
    required String? houseId,
    required bool allowBiometrics,
    bool requireExistingLock = true,
  }) async {
    if (!requireExistingLock) {
      return true;
    }
    return _militaryLockService.authenticateForSettingsChange(
      context: context,
      houseId: houseId,
      allowBiometrics: allowBiometrics,
    );
  }
}
