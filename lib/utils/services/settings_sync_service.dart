import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import '../views/ui_prefs.dart';
import '../app_error_mapper.dart';
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

class SettingsSyncService {
  static const String lastBackupAtPrefKey = 'il_settings_last_cloud_backup_at';
  static const String restoreNoticePendingPrefKey =
      'il_settings_restore_notice_pending';
  static const String restoreNoticeUidPrefKey =
      'il_settings_restore_notice_uid';
  static const List<String> _legacySecretKeys = [
    'il_imgbb_api_key',
  ];
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
  static const List<String> _legacyGlobalWidgetKeys = [
    'il_widget_theme',
    'il_widget_style',
    'il_widget_show_diary',
    'il_widget_heart_animated',
    'il_widget_heart_style',
    'il_widget_heart_color',
    'il_widget_preview_size',
    'il_widget_diary_layout',
    'il_widget_season_mode',
  ];
  static final SettingsSyncService _instance = SettingsSyncService._internal();
  factory SettingsSyncService() => _instance;
  SettingsSyncService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> _syncKeys = [
    'il_theme_key',
    'il_lang',
    'il_falling_effect',
    'il_avatar_size',
    'il_countdown_size',
    'il_avatar_frame',
    'il_countdown_style',
    'il_countdown_top_label',
    'il_countdown_bottom_label',
    'il_font_key',
    'il_home_block_tone',
    'il_lite_mode',
    'il_graphics_quality',
    'il_custom_background_url',
    'il_touch_sound',
    'il_confetti_fx',
    'il_music_autoplay',
    'il_notifications_enabled',
    'il_notif_anniversary',
    'il_notif_post',
    'il_notif_chat',
    'il_notif_friend',
    'il_notif_heart',
    'il_smart_reminder_diary',
    'il_smart_reminder_capsule',
    'il_smart_reminder_love_note',
    'il_show_weather',
    'il_show_status',
    'il_home_show_house_name',
    'il_home_show_timer',
    'il_auto_reply_text',
    'il_greeting_quote_text',
    'il_love_unit_text',
    'il_vault_timeout_mins',
    'il_transparent_mode',
    'il_brand_mark_key',
  ];

  Future<void> backupSettingsToCloud() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await _purgeLegacySensitivePrefs(prefs);
    final Map<String, dynamic> settings = {};
    final Map<String, dynamic> houseBackup = {};
    final legacyCloudRemovals = <String, dynamic>{
      for (final key in _legacyCloudSensitiveKeys) key: null,
      for (final key in _legacySecretKeys) key: null,
    };

    for (final key in _syncKeys) {
      final value = prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    // Also backup widget settings
    for (final key in prefs.getKeys()) {
      if (key.startsWith('il_widget_theme_') ||
          key.startsWith('il_widget_style_') ||
          key.startsWith('il_widget_show_diary_') ||
          key.startsWith('il_widget_heart_animated_') ||
          key.startsWith('il_widget_heart_style_') ||
          key.startsWith('il_widget_heart_color_') ||
          key.startsWith('il_widget_preview_size_') ||
          key.startsWith('il_widget_diary_layout_') ||
          key.startsWith('il_widget_season_mode_')) {
        final value = prefs.get(key);
        if (value != null) {
          settings[key] = value;
        }
      }
    }

    if (settings.isNotEmpty) {
      settings['_meta'] = {
        'schemaVersion': 2,
        'updatedAt': ServerValue.timestamp,
      };
      await _db.child('users/${user.uid}/settings').set(settings);
    } else if (legacyCloudRemovals.isNotEmpty) {
      await _db.child('users/${user.uid}/settings').update(legacyCloudRemovals);
    }

    for (final key in const [
      'il_greeting_quote_text',
      'il_love_unit_text',
      'il_notifications_enabled',
      'il_notif_anniversary',
      'il_notif_post',
      'il_notif_chat',
      'il_notif_friend',
      'il_notif_heart',
      'il_smart_reminder_diary',
      'il_smart_reminder_capsule',
      'il_smart_reminder_love_note',
      'il_show_weather',
      'il_show_status',
      'il_home_show_house_name',
      'il_home_show_timer',
      'il_auto_reply_text',
    ]) {
      final value = prefs.get(key);
      if (value != null) {
        houseBackup[key] = value;
      }
    }

    final houseId = await _resolveHouseId(prefs, user.uid);
    if (houseId != null && houseId.isNotEmpty && houseBackup.isNotEmpty) {
      houseBackup['updatedAt'] = ServerValue.timestamp;
      houseBackup['schemaVersion'] = 1;
      await _db.child('houses/$houseId/settings/clientBackups/${user.uid}').set(
            houseBackup,
          );
    }

    await prefs.setString(
      lastBackupAtPrefKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<SettingsBackupStatus> getBackupStatus() async {
    final user = _auth.currentUser;
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final localBackupAt =
        DateTime.tryParse(prefs.getString(lastBackupAtPrefKey) ?? '');

    if (user == null) {
      return SettingsBackupStatus(
        hasCloudBackup: false,
        cloudUpdatedAt: null,
        localBackupAt: localBackupAt,
      );
    }

    final snapshot = await _db.child('users/${user.uid}/settings/_meta').get();
    DateTime? cloudUpdatedAt;
    if (snapshot.exists && snapshot.value is Map) {
      final meta = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final rawUpdatedAt = meta['updatedAt'];
      final updatedAtMs = rawUpdatedAt is int
          ? rawUpdatedAt
          : int.tryParse(rawUpdatedAt?.toString() ?? '');
      if (updatedAtMs != null && updatedAtMs > 0) {
        cloudUpdatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
      }
    }

    return SettingsBackupStatus(
      hasCloudBackup: snapshot.exists,
      cloudUpdatedAt: cloudUpdatedAt,
      localBackupAt: localBackupAt,
    );
  }

  Future<void> restoreSettingsFromCloud(String uid) async {
    try {
      final snapshot = await _db.child('users/$uid/settings').get();
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      final hadLocalBackupMarker =
          (prefs.getString(lastBackupAtPrefKey) ?? '').isNotEmpty;
      await _purgeLegacySensitivePrefs(prefs);
      await _clearLocalSyncedSettingsFromPrefs(
        prefs,
        reloadUiPrefs: false,
      );

      if (snapshot.exists && snapshot.value != null) {
        final settings = Map<String, dynamic>.from(snapshot.value as Map);
        final legacyRemovals = <String, dynamic>{};
        var restoredAnySetting = false;

        for (final entry in settings.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key.startsWith('_')) {
            continue;
          }
          if (_legacySecretKeys.contains(key) ||
              _legacyCloudSensitiveKeys.contains(key)) {
            legacyRemovals[key] = null;
            continue;
          }

          if (value is String) {
            await prefs.setString(key, value);
            restoredAnySetting = true;
          } else if (value is bool) {
            await prefs.setBool(key, value);
            restoredAnySetting = true;
          } else if (value is int) {
            await prefs.setInt(key, value);
            restoredAnySetting = true;
          } else if (value is double) {
            await prefs.setDouble(key, value);
            restoredAnySetting = true;
          } else if (value is num) {
            await prefs.setDouble(key, value.toDouble());
            restoredAnySetting = true;
          }
        }

        if (legacyRemovals.isNotEmpty) {
          await _db.child('users/$uid/settings').update(legacyRemovals);
        }

        if (restoredAnySetting) {
          await prefs.setString(
            lastBackupAtPrefKey,
            DateTime.now().toIso8601String(),
          );
          if (!hadLocalBackupMarker) {
            await prefs.setBool(restoreNoticePendingPrefKey, true);
            await prefs.setString(restoreNoticeUidPrefKey, uid);
          }
        }
      }

      // Always reload so missing keys fall back to defaults instead of
      // inheriting the previous account's local state.
      await UiPrefs.reload();
    } catch (e) {
      debugPrint('Error restoring settings: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể khôi phục cài đặt.',
      ).message}');
    }
  }

  Future<bool> consumePendingRestoreNotice(String uid) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final pending = prefs.getBool(restoreNoticePendingPrefKey) ?? false;
    final pendingUid = prefs.getString(restoreNoticeUidPrefKey);

    if (!pending || pendingUid != uid) {
      return false;
    }

    await prefs.setBool(restoreNoticePendingPrefKey, false);
    await prefs.remove(restoreNoticeUidPrefKey);
    return true;
  }

  Future<void> clearLocalSyncedSettings({
    bool reloadUiPrefs = true,
  }) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await _clearLocalSyncedSettingsFromPrefs(
      prefs,
      reloadUiPrefs: reloadUiPrefs,
    );
  }

  Future<void> _purgeLegacySensitivePrefs(SharedPreferences prefs) async {
    for (final key in _legacySecretKeys) {
      await prefs.remove(key);
    }
  }

  Future<void> _clearLocalSyncedSettingsFromPrefs(
    SharedPreferences prefs, {
    required bool reloadUiPrefs,
  }) async {
    final keysToRemove = <String>{
      ..._syncKeys,
      ..._legacyGlobalWidgetKeys,
    };

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    if (reloadUiPrefs) {
      await UiPrefs.reload();
    }
  }

  Future<String?> _resolveHouseId(SharedPreferences prefs, String uid) async {
    final cached = prefs.getString('il_house_id')?.trim() ?? '';
    final cachedAuthUid = prefs.getString('il_auth_uid')?.trim() ?? '';
    if (cached.isNotEmpty) {
      if (cachedAuthUid == uid) {
        return cached;
      }
      await prefs.remove('il_house_id');
      await prefs.remove('il_role');
    }

    try {
      final snap = await _db.child('users/$uid/houseId').get();
      final houseId = snap.value?.toString().trim() ?? '';
      if (houseId.isNotEmpty) {
        await prefs.setString('il_house_id', houseId);
        await prefs.setString('il_auth_uid', uid);
        return houseId;
      }
    } catch (_) {}
    return null;
  }
}
