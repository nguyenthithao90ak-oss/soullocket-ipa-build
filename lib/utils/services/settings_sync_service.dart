import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'offline_cache_service.dart';

class SettingsBackupStatus {
  final bool hasCloudBackup;
  final DateTime? cloudUpdatedAt;
  final DateTime? localBackupAt;

  const SettingsBackupStatus({
    required this.hasCloudBackup,
    required this.cloudUpdatedAt,
    required this.localBackupAt,
  });
}

class SettingsRestoreResult {
  final bool found;
  final int restoredCount;

  const SettingsRestoreResult({required this.found, this.restoredCount = 0});
}

class SettingsSyncService {
  static const String lastBackupAtPrefKey = 'il_settings_last_cloud_backup_at';
  static const String ownerUidPrefKey = 'il_settings_owner_uid';
  static const String restoreNoticePendingPrefKey =
      'il_settings_restore_notice_pending';
  static const String restoreNoticeUidPrefKey =
      'il_settings_restore_notice_uid';
  static const List<String> _legacySecretKeys = ['il_imgbb_api_key'];
  static const List<String> _legacyCloudSensitiveKeys = [
    'il_app_lock_enabled',
    'il_lock_scope_app',
    'il_lock_scope_security',
    'il_lock_scope_diary',
    'il_lock_scope_chat',
    'il_lock_scope_private',
    'il_military_mode',
    'il_use_biometrics',
    'il_lock_timeout',
    'il_custom_lock',
    'il_custom_lock_salt',
    'il_custom_lock_length',
    'il_custom_lock_configured_at',
  ];
  static const List<String> _stringKeys = [
    'il_theme_key',
    'il_falling_effect',
    'il_avatar_frame',
    'il_countdown_shape',
    'il_countdown_style',
    'il_countdown_top_label',
    'il_countdown_bottom_label',
    'il_countdown_text_color',
    'il_font_key',
    'il_home_block_tone',
    'il_custom_background_url',
    'il_auto_reply_text',
    'il_greeting_quote_text',
    'il_love_unit_text',
    'il_brand_mark_key',
    'il_home_layout_key',
    'il_friendly_chat_persona',
    'il_good_morning_time',
    'il_good_night_time',
  ];
  static const List<String> _boolKeys = [
    'il_home_show_timer',
    'il_home_show_house_name',
    'il_transparent_mode',
    'il_show_avatar_frame_icon',
    'il_confetti_fx',
    'il_show_weather',
    'il_show_status',
    'il_notif_anniversary',
    'il_notif_post',
    'il_notif_chat',
    'il_notif_friend',
    'il_notif_heart',
    'il_smart_reminder_diary',
    'il_smart_reminder_capsule',
    'il_smart_reminder_love_note',
    'il_smart_reminder_sleep',
  ];
  static const List<String> _numberKeys = [
    'il_avatar_size',
    'il_countdown_size',
  ];
  static const List<String> _widgetStringKeys = [
    'il_widget_theme',
    'il_widget_style',
    'il_widget_heart_style',
    'il_widget_heart_color',
    'il_widget_preview_size',
    'il_widget_diary_layout',
    'il_widget_sticker',
    'il_widget_photo_frame',
    'il_widget_season_mode',
    'il_widget_custom_event_title',
    'il_widget_custom_event_date',
    'il_widget_custom_event_color',
  ];
  static const List<String> _widgetBoolKeys = [
    'il_widget_show_diary',
    'il_widget_heart_animated',
    'il_widget_use_custom_event',
  ];
  static final SettingsSyncService _instance = SettingsSyncService._internal();
  factory SettingsSyncService() => _instance;
  SettingsSyncService._internal()
    : _db = FirebaseDatabase.instance.ref(),
      _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _prefs = _loadPrefs,
      _reloadUiPrefs = UiPrefs.reload,
      _debounce = const Duration(seconds: 2);

  @visibleForTesting
  SettingsSyncService.forTesting({
    required DatabaseReference database,
    required String? Function() uidProvider,
    required Future<SharedPreferences> Function() preferences,
    required Future<void> Function() reloadPreferences,
    Duration debounceDuration = const Duration(seconds: 2),
  }) : _db = database,
       _currentUid = uidProvider,
       _prefs = preferences,
       _reloadUiPrefs = reloadPreferences,
       _debounce = debounceDuration;

  final DatabaseReference _db;
  final String? Function() _currentUid;
  final Future<SharedPreferences> Function() _prefs;
  final Future<void> Function() _reloadUiPrefs;
  final Duration _debounce;
  Timer? _backupDebounceTimer;
  Completer<void>? _backupCompleter;
  String? _pendingUid;
  int _generation = 0;
  Future<void> _operations = Future<void>.value();
  final Set<String> _pendingCloudWrites = {};

  static Iterable<String> get _syncKeys => [
    ..._stringKeys,
    ..._boolKeys,
    ..._numberKeys,
    'il_home_block_order',
  ];
  static Iterable<String> get _widgetKeys => [
    ..._widgetStringKeys,
    ..._widgetBoolKeys,
  ];
  static Future<SharedPreferences> _loadPrefs() async =>
      OfflineCacheService.getPrefsSync() ??
      await SharedPreferences.getInstance();

  static FirebaseException _failure(String code) =>
      FirebaseException(plugin: 'settings_sync', code: code);

  void _guard(String uid, int generation) {
    if (_currentUid() != uid || _generation != generation) {
      throw _failure('unauthenticated');
    }
  }

  void _guardCloudWrite(String uid) {
    if (_pendingCloudWrites.contains(uid)) {
      throw _failure('failed-precondition');
    }
  }

  Future<Result> _serialize<Result>(Future<Result> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _cancelPendingBackup() {
    _backupDebounceTimer?.cancel();
    _backupDebounceTimer = null;
    final pending = _backupCompleter;
    _backupCompleter = null;
    _pendingUid = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(_failure('cancelled'));
    }
  }

  Future<void> backupSettingsToCloud({bool immediate = false}) {
    final uid = _currentUid();
    if (uid == null) return Future<void>.error(_failure('unauthenticated'));
    if (_pendingUid != null && _pendingUid != uid) _cancelPendingBackup();
    _backupCompleter ??= Completer<void>();
    _pendingUid = uid;
    final completer = _backupCompleter!;
    final generation = _generation;
    _backupDebounceTimer?.cancel();
    void execute() {
      _backupDebounceTimer = null;
      _backupCompleter = null;
      _pendingUid = null;
      _serialize(() => _executeBackup(uid, generation)).then(
        (_) => completer.complete(),
        onError: (Object error, StackTrace stack) =>
            completer.completeError(error, stack),
      );
    }

    if (immediate) {
      execute();
    } else {
      _backupDebounceTimer = Timer(_debounce, execute);
    }
    return completer.future;
  }

  Future<String> _resolveHouseId(String uid, int generation) async {
    _guard(uid, generation);
    final snapshot = await _db
        .child('users/$uid/houseId')
        .get()
        .timeout(const Duration(seconds: 8));
    _guard(uid, generation);
    final houseId = snapshot.value;
    if (houseId != null && houseId is! String) throw _failure('invalid-backup');
    return (houseId as String?)?.trim().isNotEmpty == true
        ? (houseId as String).trim()
        : 'local';
  }

  bool _validValue(String key, Object? value, {bool widget = false}) {
    if ((widget ? _widgetStringKeys : _stringKeys).contains(key)) {
      return value is String && value.length <= 4096;
    }
    if ((widget ? _widgetBoolKeys : _boolKeys).contains(key)) {
      return value is bool;
    }
    if (_numberKeys.contains(key)) {
      return value is num && value.isFinite && value > 0 && value <= 4096;
    }
    return key == 'il_home_block_order' &&
        value is List &&
        value.length <= 32 &&
        value.every((item) => item is String && item.length <= 128);
  }

  void _checkOwner(SharedPreferences prefs, String uid) {
    final owner = prefs.getString(ownerUidPrefKey);
    final legacyUid = prefs.getString('il_auth_uid');
    if ((owner != null && owner != uid) ||
        (owner == null && legacyUid != null && legacyUid != uid)) {
      throw _failure('unauthenticated');
    }
  }

  Future<void> _executeBackup(String uid, int generation) async {
    _guard(uid, generation);
    _guardCloudWrite(uid);
    final prefs = await _prefs();
    _guard(uid, generation);
    _checkOwner(prefs, uid);
    final houseId = await _resolveHouseId(uid, generation);
    final settings = <String, Object?>{};
    for (final key in _syncKeys) {
      final value = prefs.get(key);
      if (value != null) {
        if (!_validValue(key, value)) throw _failure('invalid-backup');
        settings[key] = value;
      }
    }
    final widgets = <String, Object?>{};
    for (final key in _widgetKeys) {
      final value = prefs.get('${key}_${uid}_$houseId');
      if (value != null) {
        if (!_validValue(key, value, widget: true)) {
          throw _failure('invalid-backup');
        }
        widgets[key] = value;
      }
    }
    _guard(uid, generation);
    final cloudWrite = _db.child('users/$uid/settings').update({
      for (final key in _syncKeys) key: null,
      for (final key in _legacyCloudSensitiveKeys) key: null,
      for (final key in _legacySecretKeys) key: null,
      ...settings,
      '_widgets': {'houseId': houseId, 'values': widgets},
      '_meta': {'schemaVersion': 3, 'updatedAt': ServerValue.timestamp},
    });
    _pendingCloudWrites.add(uid);
    final acknowledged = cloudWrite.then<void>(
      (_) => _pendingCloudWrites.remove(uid),
      onError: (Object error, StackTrace stack) {
        _pendingCloudWrites.remove(uid);
        Error.throwWithStackTrace(error, stack);
      },
    );
    await acknowledged.timeout(const Duration(seconds: 12));
    _guard(uid, generation);
    await _writePref(prefs, ownerUidPrefKey, uid);
    _guard(uid, generation);
    await _writePref(
      prefs,
      lastBackupAtPrefKey,
      DateTime.now().toIso8601String(),
    );
    _guard(uid, generation);
    for (final key in _legacySecretKeys) {
      await _writePref(prefs, key, null);
      _guard(uid, generation);
    }
  }

  Map<String, Object?> _decode(Object? raw, String uid, String houseId) {
    if (raw is! Map) throw _failure('invalid-backup');
    final result = <String, Object?>{};
    for (final key in _syncKeys) {
      final value = raw[key];
      if (value != null) {
        if (!_validValue(key, value)) throw _failure('invalid-backup');
        result[key] = _numberKeys.contains(key)
            ? (value as num).toDouble()
            : key == 'il_home_block_order'
            ? List<String>.from(value as List)
            : value;
      }
    }
    final widgetPayload = raw['_widgets'];
    if (widgetPayload != null && widgetPayload is! Map) {
      throw _failure('invalid-backup');
    }
    final widgetValues =
        widgetPayload is Map && widgetPayload['houseId'] == houseId
        ? widgetPayload['values']
        : null;
    if (widgetValues != null && widgetValues is! Map) {
      throw _failure('invalid-backup');
    }
    for (final key in _widgetKeys) {
      final scopedKey = '${key}_${uid}_$houseId';
      final value = widgetValues is Map ? widgetValues[key] : raw[scopedKey];
      if (value != null) {
        if (!_validValue(key, value, widget: true)) {
          throw _failure('invalid-backup');
        }
        result[scopedKey] = value;
      }
    }
    final meta = raw['_meta'];
    final version = meta is Map ? meta['schemaVersion'] : null;
    if (version != null && version != 2 && version != 3) {
      throw _failure('invalid-backup');
    }
    if (result.isEmpty && version != 3) throw _failure('invalid-backup');
    return result;
  }

  Future<SettingsBackupStatus> getBackupStatus() async {
    final uid = _currentUid();
    if (uid == null) {
      return const SettingsBackupStatus(
        hasCloudBackup: false,
        cloudUpdatedAt: null,
        localBackupAt: null,
      );
    }
    final generation = _generation;
    _guardCloudWrite(uid);
    final prefs = await _prefs();
    _guard(uid, generation);
    final houseId = await _resolveHouseId(uid, generation);
    final snapshot = await _db
        .child('users/$uid/settings')
        .get()
        .timeout(const Duration(seconds: 8));
    _guard(uid, generation);
    _guardCloudWrite(uid);
    if (snapshot.exists) _decode(snapshot.value, uid, houseId);
    final raw = snapshot.value;
    final meta = raw is Map ? raw['_meta'] : null;
    final updatedAt = meta is Map ? meta['updatedAt'] : null;
    return SettingsBackupStatus(
      hasCloudBackup: snapshot.exists,
      cloudUpdatedAt: updatedAt is num && updatedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(updatedAt.toInt())
          : null,
      localBackupAt: prefs.getString(ownerUidPrefKey) == uid
          ? DateTime.tryParse(prefs.getString(lastBackupAtPrefKey) ?? '')
          : null,
    );
  }

  Future<SettingsRestoreResult> restoreSettingsFromCloud(String uid) {
    final generation = _generation;
    _cancelPendingBackup();
    return _serialize(() => _restore(uid, generation));
  }

  Future<SettingsRestoreResult> _restore(String uid, int generation) async {
    _guard(uid, generation);
    _guardCloudWrite(uid);
    final houseId = await _resolveHouseId(uid, generation);
    final snapshot = await _db
        .child('users/$uid/settings')
        .get()
        .timeout(const Duration(seconds: 8));
    _guard(uid, generation);
    if (!snapshot.exists) return const SettingsRestoreResult(found: false);
    final restored = _decode(snapshot.value, uid, houseId);
    if (await _resolveHouseId(uid, generation) != houseId) {
      throw _failure('cancelled');
    }
    final prefs = await _prefs();
    _guard(uid, generation);
    _checkOwner(prefs, uid);
    final hadLocalBackupMarker =
        prefs.getString(ownerUidPrefKey) == uid &&
        (prefs.getString(lastBackupAtPrefKey) ?? '').isNotEmpty;
    final rawSettings = snapshot.value as Map;
    final widgetPayload = rawSettings['_widgets'];
    final restoreWidgets = widgetPayload is Map
        ? widgetPayload['houseId'] == houseId
        : _widgetKeys.any(
            (key) => rawSettings.containsKey('${key}_${uid}_$houseId'),
          );
    final keys = <String>{
      ..._syncKeys,
      ..._widgetKeys,
      if (restoreWidgets)
        for (final key in _widgetKeys) '${key}_${uid}_$houseId',
      ..._legacySecretKeys,
      ownerUidPrefKey,
      lastBackupAtPrefKey,
      restoreNoticePendingPrefKey,
      restoreNoticeUidPrefKey,
    };
    final previous = {for (final key in keys) key: prefs.get(key)};
    try {
      for (final key in keys) {
        _guard(uid, generation);
        await _writePref(prefs, key, restored[key]);
        _guard(uid, generation);
      }
      await _writePref(prefs, ownerUidPrefKey, uid);
      _guard(uid, generation);
      await _writePref(
        prefs,
        lastBackupAtPrefKey,
        DateTime.now().toIso8601String(),
      );
      _guard(uid, generation);
      if (!hadLocalBackupMarker) {
        await _writePref(prefs, restoreNoticeUidPrefKey, uid);
        _guard(uid, generation);
        await _writePref(prefs, restoreNoticePendingPrefKey, true);
        _guard(uid, generation);
      }
      // Always reload so missing keys fall back to defaults instead of
      // inheriting the previous account's local state.
      await _reloadUiPrefs();
      _guard(uid, generation);
    } catch (error, stack) {
      if (_currentUid() == uid && _generation == generation) {
        for (final entry in previous.entries) {
          _guard(uid, generation);
          await _writePref(prefs, entry.key, entry.value);
        }
        await _reloadUiPrefs();
      }
      Error.throwWithStackTrace(error, stack);
    }
    return SettingsRestoreResult(found: true, restoredCount: restored.length);
  }

  Future<void> prepareForSignIn(String uid) async {
    _generation++;
    _cancelPendingBackup();
    final generation = _generation;
    await _serialize(() async {
      _guard(uid, generation);
      final prefs = await _prefs();
      _guard(uid, generation);
      final localOwner =
          prefs.getString(ownerUidPrefKey) ?? prefs.getString('il_auth_uid');
      if (localOwner != uid) {
        await _clearPrefs(prefs, uid, generation);
        _guard(uid, generation);
        await _reloadUiPrefs();
      }
      _guard(uid, generation);
      await _writePref(prefs, ownerUidPrefKey, uid);
      _guard(uid, generation);
    });
    try {
      await restoreSettingsFromCloud(uid);
    } catch (error) {
      _guard(uid, generation);
      debugPrint(
        '[SettingsSyncService] Optional sign-in restore failed: $error',
      );
    }
  }

  Future<bool> consumePendingRestoreNotice(String uid) async {
    final generation = _generation;
    _guard(uid, generation);
    final prefs = await _prefs();
    _guard(uid, generation);
    if (prefs.getBool(restoreNoticePendingPrefKey) != true ||
        prefs.getString(restoreNoticeUidPrefKey) != uid) {
      return false;
    }
    await _writePref(prefs, restoreNoticePendingPrefKey, false);
    _guard(uid, generation);
    await _writePref(prefs, restoreNoticeUidPrefKey, null);
    _guard(uid, generation);
    return true;
  }

  Future<void> clearLocalSyncedSettings({bool reloadUiPrefs = true}) {
    _generation++;
    _cancelPendingBackup();
    final generation = _generation;
    final uid = _currentUid();
    return _serialize(() async {
      final prefs = await _prefs();
      await _clearPrefs(prefs, uid, generation);
      if (reloadUiPrefs) await _reloadUiPrefs();
    });
  }

  Future<void> _clearPrefs(
    SharedPreferences prefs,
    String? uid,
    int generation,
  ) async {
    final owner =
        prefs.getString(ownerUidPrefKey) ?? prefs.getString('il_auth_uid');
    final keys = <String>{
      ..._syncKeys,
      ..._widgetKeys,
      ..._legacySecretKeys,
      ownerUidPrefKey,
      lastBackupAtPrefKey,
      restoreNoticePendingPrefKey,
      restoreNoticeUidPrefKey,
      if (owner != null)
        for (final key in prefs.getKeys())
          if (_widgetKeys.any((base) => key.startsWith('${base}_${owner}_')))
            key,
    };
    for (final key in keys) {
      if (_generation != generation || _currentUid() != uid) {
        throw _failure('unauthenticated');
      }
      await _writePref(prefs, key, null);
    }
  }

  Future<void> _writePref(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    final bool saved;
    if (value == null) {
      saved = await prefs.remove(key);
    } else if (value is String) {
      saved = await prefs.setString(key, value);
    } else if (value is bool) {
      saved = await prefs.setBool(key, value);
    } else if (value is int) {
      saved = await prefs.setInt(key, value);
    } else if (value is double) {
      saved = await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      saved = await prefs.setStringList(key, value);
    } else {
      throw _failure('invalid-backup');
    }
    if (!saved) throw _failure('persistence-failed');
  }
}
