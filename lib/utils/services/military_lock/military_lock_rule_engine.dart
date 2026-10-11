part of '../military_lock_service.dart';

abstract final class _MilitaryLockRuleEngine {
  static const Map<LockScope, String> _scopeTitleKeys = {
    LockScope.security: 'copy_55d99fbf9a7e',
    LockScope.diary: 'copy_05bf144d9e9b',
    LockScope.chat: 'copy_f145b5a01af0',
    LockScope.privateArea: 'copy_1dbbda9c5242',
    LockScope.app: 'copy_c90a7435320d',
  };

  static const Map<LockScope, String> _scopeReasonKeys = {
    LockScope.security: 'copy_9f56b248ba23',
    LockScope.diary: 'copy_a09ff40e8800',
    LockScope.chat: 'copy_3815ae07482d',
    LockScope.privateArea: 'copy_a5ea805f62d0',
    LockScope.app: 'copy_d573a3201d39',
  };

  static const Map<LockScope, String> _scopeKeys = {
    LockScope.security: 'security',
    LockScope.diary: 'diary',
    LockScope.chat: 'chat',
    LockScope.privateArea: 'private',
    LockScope.app: 'app',
  };

  static const Map<LockScope, String> _scopePrefKeys = {
    LockScope.security: 'il_lock_scope_security',
    LockScope.diary: 'il_lock_scope_diary',
    LockScope.chat: 'il_lock_scope_chat',
    LockScope.privateArea: 'il_lock_scope_private',
    LockScope.app: 'il_lock_scope_app',
  };

  static Map<String, bool> normalizeScopeStorageConfig(
    Map<String, bool> scopeMap, {
    required bool enabled,
  }) {
    final normalized = <String, bool>{
      ...MilitaryLockService.defaultScopeStorageConfig,
      'app': scopeMap['app'] ??
          MilitaryLockService.defaultScopeStorageConfig['app']!,
      'security': scopeMap['security'] ??
          MilitaryLockService.defaultScopeStorageConfig['security']!,
      'diary': scopeMap['diary'] ??
          MilitaryLockService.defaultScopeStorageConfig['diary']!,
      'chat': scopeMap['chat'] ??
          MilitaryLockService.defaultScopeStorageConfig['chat']!,
      'private': scopeMap['private'] ??
          MilitaryLockService.defaultScopeStorageConfig['private']!,
    };

    if (!enabled) {
      return Map<String, bool>.from(
        MilitaryLockService.defaultScopeStorageConfig,
      );
    }

    if (!normalized.values.any((value) => value)) {
      normalized['app'] = true;
    }
    return normalized;
  }

  static bool hasConfiguredSecret(String? value) {
    return value?.trim().isNotEmpty ?? false;
  }

  static bool needsUnlockWithSettings(
    MilitaryLockService service,
    LockScope scope,
    EffectiveLockSettings settings,
  ) {
    if (!settings.enabled) return false;
    if (!settings.hasConfiguredSecret) return false;
    if (!settings.isScopeEnabled(scope)) return false;
    if (scope == LockScope.app) {
      return !service.isScopeUnlocked(LockScope.app);
    }
    return !(service.isScopeUnlocked(LockScope.app) ||
        service.isScopeUnlocked(scope));
  }

  static String? validateCustomLock(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return UiCopy.text('copy_c94862e5678c');
    }

    final isNumericPin = RegExp(r'^\d{4,8}$').hasMatch(trimmed);
    if (!isNumericPin) {
      return UiCopy.text('copy_131d9155cbac');
    }
    if (trimmed.split('').toSet().length == 1) {
      return UiCopy.text('copy_cb3bc92f765a');
    }

    var ascending = true;
    var descending = true;
    for (var i = 1; i < trimmed.length; i++) {
      final previous = int.parse(trimmed[i - 1]);
      final current = int.parse(trimmed[i]);
      if (current != previous + 1) {
        ascending = false;
      }
      if (current != previous - 1) {
        descending = false;
      }
    }
    if (ascending || descending) {
      return UiCopy.text('copy_4ac036378812');
    }

    return null;
  }

  static bool canQuickDeleteFromSecret(LockSecretRecord secretRecord) {
    final configuredAt = secretRecord.configuredAtEpochMs;
    if (configuredAt == null || configuredAt <= 0) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - configuredAt) <
        MilitaryLockService.pinFlexibleChangeWindow.inMilliseconds;
  }

  static String scopeKey(LockScope scope) {
    return _scopeKeys[scope] ?? _scopeKeys[LockScope.app]!;
  }

  static String getScopeTitle(LockScope scope) {
    final key = _scopeTitleKeys[scope] ?? _scopeTitleKeys[LockScope.app]!;
    return UiCopy.text(key);
  }

  static String scopeReason(LockScope scope) {
    final key = _scopeReasonKeys[scope] ?? _scopeReasonKeys[LockScope.app]!;
    return UiCopy.text(key);
  }

  static String scopePrefKey(LockScope scope) {
    return _scopePrefKeys[scope] ?? _scopePrefKeys[LockScope.app]!;
  }

  static bool defaultScopeValue(LockScope scope) {
    return MilitaryLockService.defaultScopeConfig[scope] ?? false;
  }
}
