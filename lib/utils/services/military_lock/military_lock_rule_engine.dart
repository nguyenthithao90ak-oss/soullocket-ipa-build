part of '../military_lock_service.dart';

abstract final class _MilitaryLockRuleEngine {
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
      return 'Hãy đặt mã PIN từ 4 đến 8 số.';
    }

    final isNumericPin = RegExp(r'^\d{4,8}$').hasMatch(trimmed);
    if (!isNumericPin) {
      return 'Mã PIN phải là dãy số từ 4 đến 8 chữ số.';
    }
    if (trimmed.split('').toSet().length == 1) {
      return 'Mã PIN không nên dùng cùng 1 chữ số lặp lại.';
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
      return 'Mã PIN không nên là dãy số quen thuộc dễ đoán.';
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
    switch (scope) {
      case LockScope.security:
        return 'security';
      case LockScope.diary:
        return 'diary';
      case LockScope.chat:
        return 'chat';
      case LockScope.privateArea:
        return 'private';
      case LockScope.app:
      default:
        return 'app';
    }
  }

  static String getScopeTitle(LockScope scope) {
    switch (scope) {
      case LockScope.security:
        return 'Khu bảo mật';
      case LockScope.diary:
        return 'Nhật ký tình yêu';
      case LockScope.chat:
        return 'Lời nhắn yêu thương';
      case LockScope.privateArea:
        return 'Kho bí mật';
      case LockScope.app:
      default:
        return 'Cánh cửa trái tim';
    }
  }

  static String scopeReason(LockScope scope) {
    switch (scope) {
      case LockScope.security:
        return 'Xác thực để vào khu vực bảo mật của hai bạn.';
      case LockScope.diary:
        return 'Xác thực để xem nhật ký riêng tư.';
      case LockScope.chat:
        return 'Xác thực để mở phần tin nhắn riêng.';
      case LockScope.privateArea:
        return 'Xác thực để mở kho bí mật.';
      case LockScope.app:
      default:
        return 'Xác thực để mở khóa SoulLocket.';
    }
  }

  static String scopePrefKey(LockScope scope) {
    switch (scope) {
      case LockScope.security:
        return 'il_lock_scope_security';
      case LockScope.diary:
        return 'il_lock_scope_diary';
      case LockScope.chat:
        return 'il_lock_scope_chat';
      case LockScope.privateArea:
        return 'il_lock_scope_private';
      case LockScope.app:
      default:
        return 'il_lock_scope_app';
    }
  }

  static bool defaultScopeValue(LockScope scope) {
    return MilitaryLockService.defaultScopeConfig[scope] ?? false;
  }
}
