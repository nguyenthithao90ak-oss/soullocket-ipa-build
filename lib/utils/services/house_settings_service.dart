import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'single_match_service.dart';
import 'activity_history_service.dart';
import '../models/house_settings.dart';
import '../utils/flexible_date_input.dart';
import 'device_manager_service.dart';
import 'offline_cache_service.dart';

/// HouseSettingsService - realtime listener cho settings nhà
/// Kết hợp với HouseService hiện tại (HouseService lo phần tạo nhà)
class HouseSettingsService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final DeviceManagerService _deviceManagerService = DeviceManagerService();
  static const Duration startDateChangeCooldown = Duration(days: 3);

  static int? _readEpochMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<Map<String, dynamic>> getStartDateChangePolicy(String houseId) async {
    const isLocked = false;
    const shouldWarn = false;



    return {
      'isLocked': isLocked,
      'shouldWarn': shouldWarn,
      'cooldownUntil': null,
    };
  }

  String _withRefreshToken(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final separator = trimmed.contains('?') ? '&' : '?';
    return '$trimmed${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic>? _asStringDynamicMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  String _normalizeRole(String? value) {
    return value?.trim() == 'user2' ? 'user2' : 'user1';
  }

  Future<String> _resolvedActivityRole() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return _normalizeRole(prefs.getString('il_role'));
  }

  Future<void> _recordSpaceActivity(String houseId, String text) async {
    try {
      final role = await _resolvedActivityRole();
      await ActivityHistoryService.instance.add(
        text,
        houseId: houseId,
        role: role,
      );
    } catch (_) {}
  }

  Stream<HouseSettings?> streamSettings(String houseId) {
    return _dbRef.child('houses/$houseId/settings').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      try {
        return HouseSettings.fromMap(raw);
      } catch (_) {
        return null;
      }
    });
  }

  Future<HouseSettings?> fetchSettings(String houseId) async {
    final cacheKey = 'house_settings_$houseId';
    final cachedData = OfflineCacheService.getMemoryCache(cacheKey);
    if (cachedData is HouseSettings) {
      return cachedData;
    }

    final snap = await _dbRef.child('houses/$houseId/settings').get();
    if (!snap.exists || snap.value == null) return null;
    final raw = snap.value;
    if (raw is! Map) return null;
    final settings = HouseSettings.fromMap(raw);
    OfflineCacheService.setMemoryCache(cacheKey, settings, const Duration(minutes: 5));
    return settings;
  }

  void _invalidateCache(String houseId) {
    OfflineCacheService.clearMemoryCache('house_settings_$houseId');
    OfflineCacheService.clearMemoryCache('house_profile_$houseId');
  }

  Future<void> _ensureCurrentDeviceCanModifySharedInfo(
    String houseId, {
    bool allowPendingApproval = true,
    bool bypassTrustGate = false,
  }) async {
    if (bypassTrustGate) {
      return;
    }

    // 🔓 DISABLED: Bỏ kiểm tra thiết bị tin cậy — cho phép thay đổi thông tin chung trên mọi thiết bị
    return;
    /*
    final trustState = await _deviceManagerService.getCurrentDeviceTrustState(
        autoApprove: true);

    // ✅ Luôn cho phép nếu là thiết bị tin cậy HOẶC thiết bị đang chờ duyệt 12h
    if (trustState.isTrusted || trustState.isPendingApproval) return;

    if (trustState.isBlocked) {
      throw 'Thiết bị này đã bị chặn nên không thể thay đổi thông tin chung.';
    }

    final unlockAtMs = trustState.autoApproveAtMs;
    final unlockLabel =
        unlockAtMs > 0 ? _formatDateTime(unlockAtMs) : 'sau đủ 12 giờ';
    throw 'Thiết bị này chưa đủ tin cậy để thay đổi thông tin chung. '
        'Hãy duyệt thiết bị ở máy tin cậy hoặc đợi đến $unlockLabel.';
    */
  }

  Future<void> updateIdentityBundle({
    required String houseId,
    required String houseName,
    required String nameU1,
    required String nameU2,
    required String startDate,
    required String dobU1,
    required String dobU2,
    required String dayUnit,
    String? greetingQuote,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(
      houseId,
      bypassTrustGate: true,
    );
    final safeHouseName = houseName.trim();
    final safeNameU1 = nameU1.trim();
    final safeNameU2 = nameU2.trim();
    final safeStartDate = startDate.trim().isEmpty
        ? ''
        : DateInputUtils.normalizeToIsoDate(
            startDate,
            firstYear: 1900,
            lastYear: DateTime.now().year,
          );
    final safeDobU1 = dobU1.trim().isEmpty
        ? ''
        : DateInputUtils.normalizeToIsoDate(
            dobU1,
            firstYear: 1900,
            lastYear: DateTime.now().year,
          );
    final safeDobU2 = dobU2.trim().isEmpty
        ? ''
        : DateInputUtils.normalizeToIsoDate(
            dobU2,
            firstYear: 1900,
            lastYear: DateTime.now().year,
          );
    final safeDayUnit = dayUnit.trim().isEmpty ? 'ngày yêu' : dayUnit.trim();
    final safeGreetingQuote = (greetingQuote ?? '').trim();

    if (safeHouseName.isEmpty || safeHouseName.length > 30) {
      throw 'Tên nhà phải từ 1 đến 30 ký tự.';
    }
    if (safeNameU1.isEmpty) {
      throw 'Tên người thứ 1 không được để trống.';
    }
    if (safeStartDate == null) {
      throw 'Định dạng ngày yêu không hợp lệ.';
    }
    if (safeStartDate.isNotEmpty) {
      final parsedStart = DateTime.tryParse(safeStartDate);
      if (parsedStart == null) {
        throw 'Định dạng ngày yêu không hợp lệ.';
      }
      if (parsedStart.isAfter(DateTime.now())) {
        throw 'Ngày yêu không được ở tương lai.';
      }
    }
    if (safeDobU1 == null || safeDobU2 == null) {
      throw 'Định dạng ngày sinh không hợp lệ.';
    }
    for (final dob in [safeDobU1, safeDobU2]) {
      if (dob.isEmpty) continue;
      if (DateTime.tryParse(dob) == null) {
        throw 'Định dạng ngày sinh không hợp lệ.';
      }
    }

    await _dbRef.update({
      'houses/$houseId/houseName': safeHouseName,
      'houses/$houseId/settings/houseName': safeHouseName,
      'houses/$houseId/settings/nameU1': safeNameU1,
      'houses/$houseId/settings/nameU2': safeNameU2,
      'houses/$houseId/settings/startDate': safeStartDate,
      'houses/$houseId/settings/dobU1': safeDobU1,
      'houses/$houseId/settings/dobU2': safeDobU2,
      'houses/$houseId/settings/dayUnit': safeDayUnit,
      'houses/$houseId/settings/greetingQuote': safeGreetingQuote,
      'houses/$houseId/settings/countdownTopLabel': safeGreetingQuote,
      'houses/$houseId/settings/countdownBottomLabel': safeDayUnit,
      'houses/$houseId/settings/updatedAt': ServerValue.timestamp,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        displayName: safeNameU1,
        houseName: safeHouseName,
        dobU1: safeDobU1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
    _invalidateCache(houseId);
    await _recordSpaceActivity(
      houseId,
      'đã làm mới thông tin không gian chung',
    );
  }

  String _formatDateTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$min';
  }

  Future<void> updateField(String houseId, String field, dynamic value) async {
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
    await _dbRef.child('houses/$houseId/settings/$field').set(value);
    _invalidateCache(houseId);
  }

  Future<void> updateAvatar(
    String houseId,
    String role,
    String url, {
    bool syncHouseAvatar = false,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(
      houseId,
      allowPendingApproval: true,
    );
    final refreshedUrl = _withRefreshToken(url);
    final field = role == 'user1' ? 'avtUser1' : 'avtUser2';
    final updates = <String, dynamic>{
      'houses/$houseId/settings/$field': refreshedUrl,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
    };

    if (syncHouseAvatar) {
      updates.addAll({
        'houses/$houseId/settings/houseAvatar': refreshedUrl,
        'houses/$houseId/avatar': refreshedUrl,
        'houses/$houseId/houseAvatar': refreshedUrl,
        ...SingleMatchService.profileIndexUpdates(
          houseId: houseId,
          avatarUrl: refreshedUrl,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      });
    }

    await _dbRef.update(updates);
    _invalidateCache(houseId);
  }

  Future<void> updateHouseAvatarOnly({
    required String houseId,
    required String avatarUrl,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(
      houseId,
      allowPendingApproval: true,
    );

    final safeAvatarUrl = _withRefreshToken(avatarUrl);
    if (safeAvatarUrl.isEmpty || safeAvatarUrl.length > 2048) {
      throw 'Avatar hồ sơ không hợp lệ.';
    }

    await _dbRef.update({
      'houses/$houseId/settings/houseAvatar': safeAvatarUrl,
      'houses/$houseId/avatar': safeAvatarUrl,
      'houses/$houseId/houseAvatar': safeAvatarUrl,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        avatarUrl: safeAvatarUrl,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
    _invalidateCache(houseId);
  }

  Future<void> updateProfilePresentation({
    required String houseId,
    String? headerImageUrl,
    String? headerThemeKey,
    double? avatarSizePx,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(
      houseId,
      allowPendingApproval: true,
    );

    final updates = <String, dynamic>{
      'houses/$houseId/updatedAt': ServerValue.timestamp,
    };

    if (headerImageUrl != null) {
      final safeHeaderImageUrl = headerImageUrl.trim();
      if (safeHeaderImageUrl.length > 2048) {
        throw 'Ảnh nền hồ sơ quá dài hoặc không hợp lệ.';
      }
      updates.addAll({
        'houses/$houseId/settings/profileHeaderImageUrl': safeHeaderImageUrl,
      });
    }

    if (headerThemeKey != null) {
      final safeHeaderThemeKey = headerThemeKey.trim();
      if (safeHeaderThemeKey.length > 40) {
        throw 'Mã nền hồ sơ không hợp lệ.';
      }
      updates.addAll({
        'houses/$houseId/settings/profileHeaderThemeKey': safeHeaderThemeKey,
      });
    }

    if (avatarSizePx != null) {
      final safeAvatarSize = avatarSizePx.clamp(60, 180).toDouble();
      updates.addAll({
        'houses/$houseId/settings/profileAvatarSizePx': safeAvatarSize,
      });
    }

    if (updates.length <= 5) {
      return;
    }

    await _dbRef.update(updates);
    _invalidateCache(houseId);
  }

  Future<void> updateHouseName(String houseId, String newName) async {
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.length > 30) {
      throw 'Tên nhà phải từ 1 đến 30 ký tự.';
    }

    await _dbRef.update({
      'houses/$houseId/houseName': trimmed,
      'houses/$houseId/settings/houseName': trimmed,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        houseName: trimmed,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
    _invalidateCache(houseId);
    await _recordSpaceActivity(
      houseId,
      'đã đổi tên không gian thành "$trimmed"',
    );
  }

  Future<void> updateStartDate(
    String houseId,
    String dateStr, {
    bool startCooldown = false,
  }) async {
    final safeDate = DateInputUtils.normalizeToIsoDate(
      dateStr,
      firstYear: 1900,
      lastYear: DateTime.now().year,
    );
    final parsed = safeDate == null ? null : DateTime.tryParse(safeDate);
    if (parsed == null) {
      throw 'Định dạng ngày không hợp lệ (YYYY-MM-DD).';
    }
    if (parsed.isAfter(DateTime.now())) {
      throw 'Ngày yêu không được ở tương lai!';
    }
    final settingsSnap = await _dbRef.child('houses/$houseId/settings').get();
    final settings = _asStringDynamicMap(settingsSnap.value) ?? {};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final changeCount = (_readEpochMs(settings['startDateChangeCount']) ?? 0) + 1;
    const nextCooldownUntil = null;


    try {
      // Split into two updates to guarantee optimistic event propagation to deep listeners
      await _dbRef.child('houses/$houseId/settings').update({
        'startDate': safeDate,
        'startDateChangedAt': nowMs,
        'startDateChangeCount': changeCount,
        'startDateCooldownUntil': nextCooldownUntil,
        'updatedAt': ServerValue.timestamp,
      });
      await _dbRef.child('houses/$houseId').update({
        'updatedAt': ServerValue.timestamp,
      });
      
      _invalidateCache(houseId);
    } on FirebaseException catch (fe) {
      if (fe.code == 'permission-denied') {
        throw 'Hệ thống từ chối cập nhật ngày yêu. Có thể do lỗi phân quyền hoặc cấu hình bảo mật.';
      }
      rethrow;
    }

    await _recordSpaceActivity(
      houseId,
      'đã cập nhật mốc ngày của không gian',
    );
  }

  Future<void> updateCountdownLabels({
    required String houseId,
    String? topLabel,
    String? bottomLabel,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
    final hasTopLabel = topLabel != null;
    final hasBottomLabel = bottomLabel != null;
    if (!hasTopLabel && !hasBottomLabel) return;

    final safeTopLabel = (topLabel ?? '').trim();
    final safeBottomLabel = (bottomLabel ?? '').trim();

    if (safeTopLabel.length > 22) {
      throw 'Chữ phía trên chỉ được tối đa 22 ký tự.';
    }
    if (safeBottomLabel.length > 22) {
      throw 'Chữ phía dưới chỉ được tối đa 22 ký tự.';
    }

    final updates = <String, dynamic>{
      'houses/$houseId/settings/updatedAt': ServerValue.timestamp,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
    };

    if (hasTopLabel) {
      updates.addAll({
        'houses/$houseId/settings/greetingQuote': safeTopLabel,
        'houses/$houseId/settings/countdownTopLabel': safeTopLabel,
      });
    }

    if (hasBottomLabel) {
      updates.addAll({
        'houses/$houseId/settings/dayUnit': safeBottomLabel,
        'houses/$houseId/settings/countdownBottomLabel': safeBottomLabel,
      });
    }

    await _dbRef.update(updates);
    _invalidateCache(houseId);
    final activityText = hasTopLabel && hasBottomLabel
        ? 'đã chỉnh lại chữ ở vòng đếm ngày'
        : hasTopLabel
            ? 'đã chỉnh dòng chữ phía trên vòng đếm ngày'
            : 'đã chỉnh dòng chữ phía dưới vòng đếm ngày';
    await _recordSpaceActivity(houseId, activityText);
  }

  Future<void> updateHomeUiSettings({
    required String houseId,
    String? fallingEffectKey,
    String? countdownStyleKey,
    double? countdownSizePx,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
    final safeHouseId = houseId.trim();
    final safeFallingEffectKey = fallingEffectKey?.trim();
    final safeCountdownStyleKey = countdownStyleKey?.trim();
    final updates = <String, dynamic>{
      'houses/$safeHouseId/settings/updatedAt': ServerValue.timestamp,
      'houses/$safeHouseId/updatedAt': ServerValue.timestamp,
    };

    if (safeFallingEffectKey != null && safeFallingEffectKey.isNotEmpty) {
      updates.addAll({
        'houses/$safeHouseId/settings/fallingEffect': safeFallingEffectKey,
      });
    }
    if (safeCountdownStyleKey != null && safeCountdownStyleKey.isNotEmpty) {
      updates.addAll({
        'houses/$safeHouseId/settings/countdownStyle': safeCountdownStyleKey,
      });
    }
    if (countdownSizePx != null) {
      updates.addAll({
        'houses/$safeHouseId/settings/countdownSizePx': countdownSizePx,
      });
    }

    if (updates.length <= 2) {
      return;
    }

    await _dbRef.update(updates);
    _invalidateCache(houseId);
  }

  Future<Map<String, dynamic>?> fetchHouseProfile(String houseId) async {
    final cacheKey = 'house_profile_$houseId';
    final cachedData = OfflineCacheService.getMemoryCache(cacheKey);
    if (cachedData is Map<String, dynamic>) {
      return cachedData;
    }

    try {
      final snap = await _dbRef
          .get()
          .timeout(const Duration(seconds: 3));
      if (!snap.exists || snap.value == null) return null;
      final profile = _asStringDynamicMap(snap.value);
      OfflineCacheService.setMemoryCache(cacheKey, profile, const Duration(minutes: 5));
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isCoupleConnected(String houseId) async {
    try {
      final snap = await _dbRef
          .child('houses/$houseId/members')
          .get()
          .timeout(const Duration(seconds: 3));
      if (!snap.exists || snap.value == null) return false;
      final raw = snap.value;
      if (raw is! Map) return false;
      final map = Map<dynamic, dynamic>.from(raw);
      return map.length >= 2;
    } catch (_) {
      return false; // Trả về false nếu offline hoặc lỗi
    }
  }

  Future<void> changeRelationshipMode({
    required String houseId,
    required String newMode,
    Duration cooldown = const Duration(hours: 24),
  }) async {
    throw 'Chế độ Độc thân / Có người ấy chỉ được chọn khi tạo nhà lần đầu và không thể đổi lại trong Cài đặt.';
  }
}
