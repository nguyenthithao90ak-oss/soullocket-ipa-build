import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'offline_cache_service.dart';

enum SecurityProtectionRiskLevel { allow, warn, block }

extension SecurityProtectionRiskLevelX on SecurityProtectionRiskLevel {
  String get key => switch (this) {
    SecurityProtectionRiskLevel.allow => 'allow',
    SecurityProtectionRiskLevel.warn => 'warn',
    SecurityProtectionRiskLevel.block => 'block',
  };

  static SecurityProtectionRiskLevel fromKey(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'block':
        return SecurityProtectionRiskLevel.block;
      case 'warn':
        return SecurityProtectionRiskLevel.warn;
      default:
        return SecurityProtectionRiskLevel.allow;
    }
  }
}

enum SecurityProtectionRolloutStage { logOnly, warnOnly, blockSensitive }

extension SecurityProtectionRolloutStageX on SecurityProtectionRolloutStage {
  String get key => switch (this) {
    SecurityProtectionRolloutStage.logOnly => 'log_only',
    SecurityProtectionRolloutStage.warnOnly => 'warn_only',
    SecurityProtectionRolloutStage.blockSensitive => 'block_sensitive',
  };

  String get adminLabel => switch (this) {
    SecurityProtectionRolloutStage.logOnly => 'Tuần 1 - Chỉ log',
    SecurityProtectionRolloutStage.warnOnly => 'Tuần 2 - Chỉ cảnh báo',
    SecurityProtectionRolloutStage.blockSensitive =>
      'Tuần 3 - Chặn thao tác nhạy cảm',
  };

  String get adminDescription => switch (this) {
    SecurityProtectionRolloutStage.logOnly =>
      'Chỉ ghi nhận sự kiện, không cảnh báo và không chặn người dùng.',
    SecurityProtectionRolloutStage.warnOnly =>
      'Risk warn/block đều hạ xuống mức cảnh báo để theo dõi block nhầm.',
    SecurityProtectionRolloutStage.blockSensitive =>
      'Áp dụng đúng risk allow/warn/block cho các thao tác nhạy cảm.',
  };

  static SecurityProtectionRolloutStage fromKey(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'warn':
      case 'warn_only':
        return SecurityProtectionRolloutStage.warnOnly;
      case 'block':
      case 'block_sensitive':
        return SecurityProtectionRolloutStage.blockSensitive;
      default:
        return SecurityProtectionRolloutStage.logOnly;
    }
  }
}

enum SecurityProtectionReason {
  screenCapture,
  overlay,
  controlApp,
  unofficialBuild,
  unlicensed,
  malware,
  rootIntegrity,
  playProtect,
  unknown,
}

extension SecurityProtectionReasonX on SecurityProtectionReason {
  String get key => switch (this) {
    SecurityProtectionReason.screenCapture => 'screen_capture',
    SecurityProtectionReason.overlay => 'overlay',
    SecurityProtectionReason.controlApp => 'control_app',
    SecurityProtectionReason.unofficialBuild => 'unofficial_build',
    SecurityProtectionReason.unlicensed => 'unlicensed',
    SecurityProtectionReason.malware => 'malware',
    SecurityProtectionReason.rootIntegrity => 'root_integrity',
    SecurityProtectionReason.playProtect => 'play_protect',
    SecurityProtectionReason.unknown => 'unknown',
  };

  String get adminLabel => switch (this) {
    SecurityProtectionReason.screenCapture => 'Quay/chia sẻ màn hình',
    SecurityProtectionReason.overlay => 'Overlay/tapjacking',
    SecurityProtectionReason.controlApp => 'Auto click/điều khiển màn hình',
    SecurityProtectionReason.unofficialBuild => 'Bản build không chính thức',
    SecurityProtectionReason.unlicensed => 'Bản không được cấp phép',
    SecurityProtectionReason.malware => 'Malware/app access risk',
    SecurityProtectionReason.rootIntegrity => 'Root/fake integrity/modded',
    SecurityProtectionReason.playProtect => 'Play Protect verdict',
    SecurityProtectionReason.unknown => 'Khác/không xác định',
  };

  static SecurityProtectionReason fromKey(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'screen_capture':
        return SecurityProtectionReason.screenCapture;
      case 'overlay':
        return SecurityProtectionReason.overlay;
      case 'control_app':
        return SecurityProtectionReason.controlApp;
      case 'unofficial_build':
        return SecurityProtectionReason.unofficialBuild;
      case 'unlicensed':
        return SecurityProtectionReason.unlicensed;
      case 'malware':
        return SecurityProtectionReason.malware;
      case 'root_integrity':
        return SecurityProtectionReason.rootIntegrity;
      case 'play_protect':
        return SecurityProtectionReason.playProtect;
      default:
        return SecurityProtectionReason.unknown;
    }
  }

  static SecurityProtectionReason fromReasonCode(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return SecurityProtectionReason.unknown;
    }
    if (normalized.contains('CAPTURE') ||
        normalized.contains('RECORDER') ||
        normalized.contains('SCREEN_SHARE')) {
      return SecurityProtectionReason.screenCapture;
    }
    if (normalized.contains('OVERLAY') ||
        normalized.contains('OBSCURED') ||
        normalized.contains('TAPJACK')) {
      return SecurityProtectionReason.overlay;
    }
    if (normalized.contains('CONTROL') ||
        normalized.contains('AUTO_CLICK') ||
        normalized.contains('ACCESSIBILITY_ABUSE') ||
        normalized.contains('REMOTE_CONTROL')) {
      return SecurityProtectionReason.controlApp;
    }
    if (normalized.contains('UNRECOGNIZED_VERSION') ||
        normalized.contains('SIDELOAD') ||
        normalized.contains('MODDED') ||
        normalized.contains('PLAY_RECOGNIZED') &&
            normalized.contains('FALSE')) {
      return SecurityProtectionReason.unofficialBuild;
    }
    if (normalized.contains('UNLICENSED')) {
      return SecurityProtectionReason.unlicensed;
    }
    if (normalized.contains('MALWARE') ||
        normalized.contains('APP_ACCESS_RISK')) {
      return SecurityProtectionReason.malware;
    }
    if (normalized.contains('ROOT') ||
        normalized.contains('FAKE_INTEGRITY') ||
        normalized.contains('DEVICE_INTEGRITY') ||
        normalized.contains('NO_INTEGRITY') ||
        normalized.contains('MEETS_BASIC_INTEGRITY') ||
        normalized.contains('MEETS_DEVICE_INTEGRITY')) {
      return SecurityProtectionReason.rootIntegrity;
    }
    if (normalized.contains('PLAY_PROTECT')) {
      return SecurityProtectionReason.playProtect;
    }
    return SecurityProtectionReason.unknown;
  }
}

class SecurityProtectionRolloutConfig {
  final SecurityProtectionRolloutStage stage;
  final Map<SecurityProtectionReason, bool> enabledReasons;
  final String note;
  final int updatedAtMs;
  final String updatedBy;

  const SecurityProtectionRolloutConfig({
    required this.stage,
    required this.enabledReasons,
    required this.note,
    required this.updatedAtMs,
    required this.updatedBy,
  });

  factory SecurityProtectionRolloutConfig.fallback() {
    return SecurityProtectionRolloutConfig(
      stage: SecurityProtectionRolloutStage.logOnly,
      enabledReasons: {
        for (final reason in SecurityProtectionReason.values) reason: true,
      },
      note: '',
      updatedAtMs: 0,
      updatedBy: '',
    );
  }

  factory SecurityProtectionRolloutConfig.fromMap(Map<Object?, Object?>? raw) {
    if (raw == null || raw.isEmpty) {
      return SecurityProtectionRolloutConfig.fallback();
    }

    final rolloutMap = Map<Object?, Object?>.from(raw);
    final enabledRaw = rolloutMap['enabledReasons'];
    final enabledMap = <SecurityProtectionReason, bool>{
      for (final reason in SecurityProtectionReason.values) reason: true,
    };
    if (enabledRaw is Map) {
      final map = Map<Object?, Object?>.from(enabledRaw);
      for (final entry in map.entries) {
        enabledMap[SecurityProtectionReasonX.fromKey(entry.key?.toString())] =
            entry.value == true;
      }
    }

    return SecurityProtectionRolloutConfig(
      stage: SecurityProtectionRolloutStageX.fromKey(
        rolloutMap['stage']?.toString(),
      ),
      enabledReasons: enabledMap,
      note: rolloutMap['note']?.toString() ?? '',
      updatedAtMs: _readInt(rolloutMap['updatedAt']),
      updatedBy: rolloutMap['updatedBy']?.toString() ?? '',
    );
  }

  bool isReasonEnabled(SecurityProtectionReason reason) {
    return enabledReasons[reason] ?? true;
  }

  SecurityProtectionRolloutConfig copyWith({
    SecurityProtectionRolloutStage? stage,
    Map<SecurityProtectionReason, bool>? enabledReasons,
    String? note,
    int? updatedAtMs,
    String? updatedBy,
  }) {
    return SecurityProtectionRolloutConfig(
      stage: stage ?? this.stage,
      enabledReasons: enabledReasons ?? this.enabledReasons,
      note: note ?? this.note,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toStorageMap({required String actorId}) {
    return {
      'stage': stage.key,
      'note': note,
      'updatedBy': actorId,
      'updatedAt': ServerValue.timestamp,
      'enabledReasons': {
        for (final entry in enabledReasons.entries) entry.key.key: entry.value,
      },
    };
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'stage': stage.key,
      'note': note,
      'updatedBy': updatedBy,
      'updatedAt': updatedAtMs,
      'enabledReasons': {
        for (final entry in enabledReasons.entries) entry.key.key: entry.value,
      },
    };
  }
}

class SecurityProtectionVerdict {
  final SecurityProtectionRiskLevel rawRisk;
  final SecurityProtectionRiskLevel effectiveRisk;
  final SecurityProtectionRolloutStage rolloutStage;
  final SecurityProtectionReason reason;
  final String reasonCode;
  final String actionId;
  final String screenId;
  final List<String> signals;
  final bool reasonEnabled;

  const SecurityProtectionVerdict({
    required this.rawRisk,
    required this.effectiveRisk,
    required this.rolloutStage,
    required this.reason,
    required this.reasonCode,
    required this.actionId,
    required this.screenId,
    required this.signals,
    required this.reasonEnabled,
  });

  bool get shouldWarn => effectiveRisk == SecurityProtectionRiskLevel.warn;
  bool get shouldBlock => effectiveRisk == SecurityProtectionRiskLevel.block;
}

class SecurityProtectionRolloutService {
  SecurityProtectionRolloutService._internal();

  static final SecurityProtectionRolloutService _instance =
      SecurityProtectionRolloutService._internal();

  factory SecurityProtectionRolloutService() => _instance;

  static const String configPath = 'app_config/security_protection_rollout';
  static const String _prefsCacheKey =
      'il_security_protection_rollout_cache_v1';
  static const String _prefsFetchedAtKey =
      'il_security_protection_rollout_fetched_at_v1';
  static const Duration _cacheTtl = Duration(minutes: 5);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  SecurityProtectionRolloutConfig? _memoryCache;
  DateTime? _memoryFetchedAt;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??=
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
  }

  Future<SecurityProtectionRolloutConfig> fetchConfig({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _memoryCache != null &&
        _memoryFetchedAt != null &&
        DateTime.now().difference(_memoryFetchedAt!) <= _cacheTtl) {
      return _memoryCache!;
    }

    final prefs = await _getPrefs();
    final fetchedAtMs = prefs.getInt(_prefsFetchedAtKey) ?? 0;
    final cachedJson = prefs.getString(_prefsCacheKey);
    if (!forceRefresh &&
        cachedJson != null &&
        cachedJson.trim().isNotEmpty &&
        fetchedAtMs > 0) {
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
      if (DateTime.now().difference(fetchedAt) <= _cacheTtl) {
        try {
          final cachedMap = jsonDecode(cachedJson);
          if (cachedMap is Map) {
            final config = SecurityProtectionRolloutConfig.fromMap(cachedMap);
            _rememberConfig(config);
            return config;
          }
        } catch (e) {
          debugPrint(
            'Security rollout cache decode failed: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể đọc cache bảo vệ bảo mật.').message}',
          );
        }
      }
    }

    try {
      final snapshot = await _db.child(configPath).get();
      final raw = snapshot.value;
      final config = raw is Map
          ? SecurityProtectionRolloutConfig.fromMap(raw)
          : SecurityProtectionRolloutConfig.fallback();
      await _persistCache(config);
      _rememberConfig(config);
      return config;
    } catch (e) {
      debugPrint(
        'Security rollout fetch failed, fallback cache: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể tải cấu hình bảo vệ bảo mật.').message}',
      );
      if (cachedJson != null && cachedJson.trim().isNotEmpty) {
        try {
          final cachedMap = jsonDecode(cachedJson);
          if (cachedMap is Map) {
            final config = SecurityProtectionRolloutConfig.fromMap(cachedMap);
            _rememberConfig(config);
            return config;
          }
        } catch (cacheError) {
          debugPrint(
            'Security rollout fallback cache decode failed: $cacheError',
          );
        }
      }
      final fallback = SecurityProtectionRolloutConfig.fallback();
      _rememberConfig(fallback);
      return fallback;
    }
  }

  Stream<SecurityProtectionRolloutConfig> watchConfig() {
    return _db.child(configPath).onValue.map((event) {
      final raw = event.snapshot.value;
      final config = raw is Map
          ? SecurityProtectionRolloutConfig.fromMap(raw)
          : SecurityProtectionRolloutConfig.fallback();
      unawaited(_persistCache(config));
      _rememberConfig(config);
      return config;
    });
  }

  Future<void> saveConfig(
    SecurityProtectionRolloutConfig config, {
    required String actorId,
  }) async {
    await _db.child(configPath).set(config.toStorageMap(actorId: actorId));
    final hydrated = config.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      updatedBy: actorId,
    );
    await _persistCache(hydrated);
    _rememberConfig(hydrated);
  }

  Future<SecurityProtectionVerdict> resolveVerdict({
    required SecurityProtectionRiskLevel rawRisk,
    required String actionId,
    required String screenId,
    String? reasonCode,
    SecurityProtectionReason? reason,
    List<String> signals = const <String>[],
  }) async {
    final config = await fetchConfig();
    return resolveVerdictSync(
      config: config,
      rawRisk: rawRisk,
      actionId: actionId,
      screenId: screenId,
      reasonCode: reasonCode,
      reason: reason,
      signals: signals,
    );
  }

  SecurityProtectionVerdict resolveVerdictSync({
    required SecurityProtectionRolloutConfig config,
    required SecurityProtectionRiskLevel rawRisk,
    required String actionId,
    required String screenId,
    String? reasonCode,
    SecurityProtectionReason? reason,
    List<String> signals = const <String>[],
  }) {
    final resolvedReason =
        reason ?? SecurityProtectionReasonX.fromReasonCode(reasonCode);
    final reasonEnabled = config.isReasonEnabled(resolvedReason);
    final effectiveRisk = _applyRollout(
      config.stage,
      rawRisk: rawRisk,
      reasonEnabled: reasonEnabled,
    );

    return SecurityProtectionVerdict(
      rawRisk: rawRisk,
      effectiveRisk: effectiveRisk,
      rolloutStage: config.stage,
      reason: resolvedReason,
      reasonCode: (reasonCode ?? resolvedReason.key).trim(),
      actionId: actionId.trim(),
      screenId: screenId.trim(),
      signals: signals
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      reasonEnabled: reasonEnabled,
    );
  }

  SecurityProtectionRiskLevel _applyRollout(
    SecurityProtectionRolloutStage stage, {
    required SecurityProtectionRiskLevel rawRisk,
    required bool reasonEnabled,
  }) {
    if (!reasonEnabled) {
      return SecurityProtectionRiskLevel.allow;
    }

    switch (stage) {
      case SecurityProtectionRolloutStage.logOnly:
        return SecurityProtectionRiskLevel.allow;
      case SecurityProtectionRolloutStage.warnOnly:
        if (rawRisk == SecurityProtectionRiskLevel.allow) {
          return SecurityProtectionRiskLevel.allow;
        }
        return SecurityProtectionRiskLevel.warn;
      case SecurityProtectionRolloutStage.blockSensitive:
        return rawRisk;
    }
  }

  Future<void> _persistCache(SecurityProtectionRolloutConfig config) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(_prefsCacheKey, jsonEncode(config.toCacheMap()));
    await prefs.setInt(
      _prefsFetchedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _rememberConfig(SecurityProtectionRolloutConfig config) {
    _memoryCache = config;
    _memoryFetchedAt = DateTime.now();
  }
}

int _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
