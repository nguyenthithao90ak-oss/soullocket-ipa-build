import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_history_service.dart';
import 'drawing_studio_service.dart';
import 'offline_cache_service.dart';
import 'settings_sync_service.dart';

class CriticalDataSyncService {
  static final CriticalDataSyncService _instance =
      CriticalDataSyncService._internal();

  factory CriticalDataSyncService() => _instance;
  CriticalDataSyncService._internal();

  final DrawingStudioService _drawingStudioService = DrawingStudioService();
  bool _isSyncing = false;
  String? _lastSyncedUserId;
  String? _lastSyncedHouseId;
  DateTime? _lastSyncedAt;
  Future<void>? _syncInFlight;

  static const Duration _syncCooldown = Duration(seconds: 20);

  Future<void> syncCurrentUserData(
      {String? houseId, bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final resolvedHouseId = await _resolveHouseId(houseId);
    if (_syncInFlight != null) {
      return _syncInFlight!;
    }
    if (!force && _shouldSkipSync(user.uid, resolvedHouseId)) {
      return;
    }

    final future = _runSync(
      userId: user.uid,
      houseId: resolvedHouseId,
    );
    _syncInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
      }
    }
  }

  bool _shouldSkipSync(String userId, String? houseId) {
    if (_isSyncing) {
      return true;
    }
    if (_lastSyncedUserId != userId) {
      return false;
    }
    if ((_lastSyncedHouseId ?? '') != (houseId ?? '')) {
      return false;
    }
    final lastSyncedAt = _lastSyncedAt;
    if (lastSyncedAt == null) {
      return false;
    }
    return DateTime.now().difference(lastSyncedAt) < _syncCooldown;
  }

  Future<void> _runSync({
    required String userId,
    required String? houseId,
  }) async {
    _isSyncing = true;
    try {
      await SettingsSyncService().backupSettingsToCloud();
      await ActivityHistoryService.instance
          .migrateLegacyLocalData(houseId: houseId);
      if (houseId != null && houseId.isNotEmpty) {
        await _drawingStudioService.migrateLegacyLocalGallery(houseId);
        await _drawingStudioService.syncPendingLocalGallery(houseId);
      }
      _lastSyncedUserId = userId;
      _lastSyncedHouseId = houseId;
      _lastSyncedAt = DateTime.now();
    } finally {
      _isSyncing = false;
    }
  }

  Future<String?> _resolveHouseId(String? houseId) async {
    final trimmed = houseId?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final cached = prefs.getString('il_house_id')?.trim() ?? '';
    final cachedAuthUid = prefs.getString('il_auth_uid')?.trim() ?? '';
    if (cached.isNotEmpty) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && cachedAuthUid == currentUid) {
        return cached;
      }
      await prefs.remove('il_house_id');
      await prefs.remove('il_role');
    }
    return null;
  }
}
