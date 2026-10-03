import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'activity_history_service.dart';
import 'drawing_studio_service.dart';
import 'settings_sync_service.dart';

class CriticalDataSyncService {
  static final CriticalDataSyncService _instance =
      CriticalDataSyncService._internal();
  factory CriticalDataSyncService() => _instance;

  CriticalDataSyncService._internal()
    : _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _resolveHouse = _readHouse,
      _backup = (() =>
          SettingsSyncService().backupSettingsToCloud(immediate: true)),
      _migrateHistory = ((house) => ActivityHistoryService.instance
          .migrateLegacyLocalData(houseId: house)),
      _migrateGallery = DrawingStudioService().migrateLegacyLocalGallery,
      _syncGallery = DrawingStudioService().syncPendingLocalGallery;

  @visibleForTesting
  CriticalDataSyncService.forTesting({
    required String? Function() uidProvider,
    required Future<String?> Function(String) houseResolver,
    required Future<void> Function() settingsBackup,
    required Future<void> Function(String?) historyMigration,
    required Future<void> Function(String) galleryMigration,
    required Future<void> Function(String) gallerySync,
  }) : _currentUid = uidProvider,
       _resolveHouse = houseResolver,
       _backup = settingsBackup,
       _migrateHistory = historyMigration,
       _migrateGallery = galleryMigration,
       _syncGallery = gallerySync;

  final String? Function() _currentUid;
  final Future<String?> Function(String) _resolveHouse;
  final Future<void> Function() _backup;
  final Future<void> Function(String?) _migrateHistory;
  final Future<void> Function(String) _migrateGallery;
  final Future<void> Function(String) _syncGallery;
  String? _lastSyncedUserId;
  String? _lastSyncedHouseId;
  DateTime? _lastSyncedAt;
  Future<void>? _syncInFlight;
  String? _inFlightUid;
  String? _inFlightHouse;
  static const Duration _syncCooldown = Duration(seconds: 20);

  static Future<String?> _readHouse(String uid) async {
    final snapshot = await FirebaseDatabase.instance
        .ref('users/$uid/houseId')
        .get()
        .timeout(const Duration(seconds: 8));
    return snapshot.value is String &&
            (snapshot.value as String).trim().isNotEmpty
        ? (snapshot.value as String).trim()
        : null;
  }

  void _guard(String uid) {
    if (_currentUid() != uid) {
      throw FirebaseException(
        plugin: 'critical_data_sync',
        code: 'unauthenticated',
      );
    }
  }

  Future<void> _guardScope(String uid, String? house) async {
    _guard(uid);
    final currentHouse = await _resolveHouse(uid);
    _guard(uid);
    if (currentHouse != house) {
      throw FirebaseException(plugin: 'critical_data_sync', code: 'cancelled');
    }
  }

  Future<void> syncCurrentUserData({
    String? houseId,
    bool force = false,
  }) async {
    final uid = _currentUid();
    if (uid == null) {
      throw FirebaseException(
        plugin: 'critical_data_sync',
        code: 'unauthenticated',
      );
    }
    final house = await _resolveHouse(uid);
    _guard(uid);
    if (houseId?.trim().isNotEmpty == true && houseId!.trim() != house) {
      throw FirebaseException(plugin: 'critical_data_sync', code: 'cancelled');
    }
    while (_syncInFlight != null) {
      final pending = _syncInFlight!;
      if (_inFlightUid == uid && _inFlightHouse == house) return pending;
      try {
        await pending;
      } catch (_) {}
      await _guardScope(uid, house);
    }
    if (!force &&
        _lastSyncedUserId == uid &&
        _lastSyncedHouseId == house &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _syncCooldown) {
      return;
    }

    _inFlightUid = uid;
    _inFlightHouse = house;
    final future = _runSync(uid, house);
    _syncInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
        _inFlightUid = null;
        _inFlightHouse = null;
      }
    }
  }

  Future<void> _runSync(String uid, String? house) async {
    _guard(uid);
    await _backup();
    await _guardScope(uid, house);
    if (house != null) {
      await _migrateHistory(house);
      await _guardScope(uid, house);
      await _migrateGallery(house);
      await _guardScope(uid, house);
      await _syncGallery(house);
      await _guardScope(uid, house);
    }
    _lastSyncedUserId = uid;
    _lastSyncedHouseId = house;
    _lastSyncedAt = DateTime.now();
  }
}
