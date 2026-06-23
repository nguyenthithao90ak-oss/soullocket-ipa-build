part of '../military_lock_service.dart';

class LockSecretRecord {
  final String secret;
  final String? salt;
  final int? pinLength;
  final int? configuredAtEpochMs;

  const LockSecretRecord({
    required this.secret,
    this.salt,
    this.pinLength,
    this.configuredAtEpochMs,
  });
}

enum LockScope {
  app,
  security,
  diary,
  chat,
  privateArea,
}

class _UnlockGuardState {
  final int failedAttempts;
  final int lockUntilEpochMs;

  const _UnlockGuardState({
    required this.failedAttempts,
    required this.lockUntilEpochMs,
  });

  int get remainingLockSeconds {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockUntilEpochMs <= now) {
      return 0;
    }
    return ((lockUntilEpochMs - now) / 1000).ceil();
  }

  bool get isLocked => remainingLockSeconds > 0;
}

class EffectiveLockSettings {
  final bool enabled;
  final bool useBiometrics;
  final int timeoutMinutes;
  final bool militaryMode;
  final Map<String, bool> scopes;
  final LockSecretRecord? secretRecord;

  const EffectiveLockSettings({
    required this.enabled,
    required this.useBiometrics,
    required this.timeoutMinutes,
    required this.militaryMode,
    required this.scopes,
    required this.secretRecord,
  });

  bool get hasConfiguredSecret =>
      (secretRecord?.secret.trim().isNotEmpty ?? false);

  bool isScopeEnabled(LockScope scope) {
    return scopes[MilitaryLockService.scopeKey(scope)] ??
        MilitaryLockService
            .defaultScopeStorageConfig[MilitaryLockService.scopeKey(scope)] ??
        false;
  }
}

class _EffectiveLockSettingsCacheEntry {
  final EffectiveLockSettings settings;
  final int fetchedAtMs;

  const _EffectiveLockSettingsCacheEntry({
    required this.settings,
    required this.fetchedAtMs,
  });
}

class PinRecoveryEmailRecord {
  final String label;
  final String email;
  final String maskedEmail;

  const PinRecoveryEmailRecord({
    required this.label,
    required this.email,
    required this.maskedEmail,
  });
}

class PinRecoveryOptions {
  final String? securityQuestion;
  final List<PinRecoveryEmailRecord> emails;
  final bool canQuickDelete;

  const PinRecoveryOptions({
    required this.securityQuestion,
    required this.emails,
    required this.canQuickDelete,
  });

  bool get hasAnyRecoveryMethod =>
      (securityQuestion?.trim().isNotEmpty ?? false) ||
      emails.isNotEmpty ||
      canQuickDelete;
}

enum _PinRecoveryMethodType {
  securityQuestion,
  email,
  quickDelete,
}

class _PinRecoverySelection {
  final _PinRecoveryMethodType type;
  final PinRecoveryEmailRecord? email;

  const _PinRecoverySelection({
    required this.type,
    this.email,
  });
}
