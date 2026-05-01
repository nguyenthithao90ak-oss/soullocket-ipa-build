import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/single_match_service.dart';
import 'activity_history_service.dart';
import '../models/house_settings.dart';
import '../utils/flexible_date_input.dart';
import 'device_manager_service.dart';

/// HouseSettingsService - realtime listener cho settings nhÃ 
/// Káº¿t há»£p vá»›i HouseService hiá»‡n táº¡i (HouseService lo pháº§n táº¡o nhÃ )
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
    final snap = await _dbRef.child('houses/$houseId/settings').get();
    final settings = _asStringDynamicMap(snap.value) ?? {};
    final now = DateTime.now().millisecondsSinceEpoch;

    final isLocked = false;
    final shouldWarn = false;

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

  Future<String> _resolvedActivityRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('il_role') ?? 'user1').trim();
    return role == 'user2' ? 'user2' : 'user1';
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
    final snap = await _dbRef.child('houses/$houseId/settings').get();
    if (!snap.exists || snap.value == null) return null;
    final raw = snap.value;
    if (raw is! Map) return null;
    return HouseSettings.fromMap(raw);
  }

  Future<void> _ensureCurrentDeviceCanModifySharedInfo(
    String houseId, {
    bool allowPendingApproval = true,
  }) async {
    final trustState = await _deviceManagerService.getCurrentDeviceTrustState(
        autoApprove: true);
    if (trustState.isTrusted) return;
    if (allowPendingApproval && trustState.isPendingApproval) return;
    if (trustState.isBlocked) {
      throw 'Thiáº¿t bá»‹ nÃ y Ä‘Ã£ bá»‹ cháº·n nÃªn khÃ´ng thá»ƒ thay Ä‘á»•i thÃ´ng tin chung.';
    }

    final unlockAtMs = trustState.autoApproveAtMs;
    final unlockLabel =
        unlockAtMs > 0 ? _formatDateTime(unlockAtMs) : 'sau Ä‘á»§ 12 giá»';
    throw 'Thiáº¿t bá»‹ nÃ y Ä‘ang chá» duyá»‡t nÃªn chÆ°a thá»ƒ thay Ä‘á»•i thÃ´ng tin chung. '
        'HÃ£y duyá»‡t thiáº¿t bá»‹ á»Ÿ mÃ¡y tin cáº­y hoáº·c Ä‘á»£i Ä‘áº¿n $unlockLabel.';
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
      'house_profiles/$houseId/$field': refreshedUrl,
      'house_profiles/$houseId/settings/$field': refreshedUrl,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updated_at': ServerValue.timestamp,
      'houses_public/$houseId/updatedAt': ServerValue.timestamp,
      'houses_public/$houseId/updated_at': ServerValue.timestamp,
    };

    if (syncHouseAvatar) {
      updates.addAll({
        'houses/$houseId/settings/houseAvatar': refreshedUrl,
        'houses/$houseId/avatar': refreshedUrl,
        'houses/$houseId/houseAvatar': refreshedUrl,
        'house_profiles/$houseId/avatar': refreshedUrl,
        'house_profiles/$houseId/houseAvatar': refreshedUrl,
        'house_profiles/$houseId/settings/houseAvatar': refreshedUrl,
        'houses_public/$houseId/avatar': refreshedUrl,
        'houses_public/$houseId/houseAvatar': refreshedUrl,
        'houses_public/$houseId/settings/houseAvatar': refreshedUrl,
        ...SingleMatchService.profileIndexUpdates(
          houseId: houseId,
          avatarUrl: refreshedUrl,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      });
    }

    await _dbRef.update(updates);
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
      throw 'Avatar há»“ sÆ¡ khÃ´ng há»£p lá»‡.';
    }

    await _dbRef.update({
      'houses/$houseId/settings/houseAvatar': safeAvatarUrl,
      'houses/$houseId/avatar': safeAvatarUrl,
      'houses/$houseId/houseAvatar': safeAvatarUrl,
      'house_profiles/$houseId/avatar': safeAvatarUrl,
      'house_profiles/$houseId/houseAvatar': safeAvatarUrl,
      'house_profiles/$houseId/settings/houseAvatar': safeAvatarUrl,
      'houses_public/$houseId/avatar': safeAvatarUrl,
      'houses_public/$houseId/houseAvatar': safeAvatarUrl,
      'houses_public/$houseId/settings/houseAvatar': safeAvatarUrl,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updated_at': ServerValue.timestamp,
      'houses_public/$houseId/updatedAt': ServerValue.timestamp,
      'houses_public/$houseId/updated_at': ServerValue.timestamp,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        avatarUrl: safeAvatarUrl,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
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
      'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updated_at': ServerValue.timestamp,
      'houses_public/$houseId/updatedAt': ServerValue.timestamp,
      'houses_public/$houseId/updated_at': ServerValue.timestamp,
    };

    if (headerImageUrl != null) {
      final safeHeaderImageUrl = headerImageUrl.trim();
      if (safeHeaderImageUrl.length > 2048) {
        throw 'áº¢nh ná»n há»“ sÆ¡ quÃ¡ dÃ i hoáº·c khÃ´ng há»£p lá»‡.';
      }
      updates.addAll({
        'houses/$houseId/settings/profileHeaderImageUrl': safeHeaderImageUrl,
        'house_profiles/$houseId/profileHeaderImageUrl': safeHeaderImageUrl,
        'house_profiles/$houseId/settings/profileHeaderImageUrl':
            safeHeaderImageUrl,
        'houses_public/$houseId/profileHeaderImageUrl': safeHeaderImageUrl,
        'houses_public/$houseId/settings/profileHeaderImageUrl':
            safeHeaderImageUrl,
      });
    }

    if (headerThemeKey != null) {
      final safeHeaderThemeKey = headerThemeKey.trim();
      if (safeHeaderThemeKey.length > 40) {
        throw 'MÃ£ ná»n há»“ sÆ¡ khÃ´ng há»£p lá»‡.';
      }
      updates.addAll({
        'houses/$houseId/settings/profileHeaderThemeKey': safeHeaderThemeKey,
        'house_profiles/$houseId/profileHeaderThemeKey': safeHeaderThemeKey,
        'house_profiles/$houseId/settings/profileHeaderThemeKey':
            safeHeaderThemeKey,
        'houses_public/$houseId/profileHeaderThemeKey': safeHeaderThemeKey,
        'houses_public/$houseId/settings/profileHeaderThemeKey':
            safeHeaderThemeKey,
      });
    }

    if (avatarSizePx != null) {
      final safeAvatarSize = avatarSizePx.clamp(60, 180).toDouble();
      updates.addAll({
        'houses/$houseId/settings/profileAvatarSizePx': safeAvatarSize,
        'house_profiles/$houseId/profileAvatarSizePx': safeAvatarSize,
        'house_profiles/$houseId/settings/profileAvatarSizePx': safeAvatarSize,
        'houses_public/$houseId/profileAvatarSizePx': safeAvatarSize,
        'houses_public/$houseId/settings/profileAvatarSizePx': safeAvatarSize,
      });
    }

    if (updates.length <= 5) {
      return;
    }

    await _dbRef.update(updates);
  }

  Future<void> updateHouseName(String houseId, String newName) async {
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.length > 30) {
      throw 'TÃªn nhÃ  pháº£i tá»« 1 Ä‘áº¿n 30 kÃ½ tá»±.';
    }

    await _dbRef.update({
      'houses/$houseId/houseName': trimmed,
      'houses/$houseId/settings/houseName': trimmed,
      'house_profiles/$houseId/houseName': trimmed,
      'house_profiles/$houseId/settings/houseName': trimmed,
      'houses_public/$houseId/houseName': trimmed,
      'houses_public/$houseId/settings/houseName': trimmed,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updated_at': ServerValue.timestamp,
      'houses_public/$houseId/updatedAt': ServerValue.timestamp,
      'houses_public/$houseId/updated_at': ServerValue.timestamp,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        houseName: trimmed,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
    await _recordSpaceActivity(
      houseId,
      'Ä‘Ã£ Ä‘á»•i tÃªn khÃ´ng gian thÃ nh "$trimmed"',
    );
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
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
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
    final safeDayUnit = dayUnit.trim().isEmpty ? 'ngÃ y yÃªu' : dayUnit.trim();
    final safeGreetingQuote = (greetingQuote ?? '').trim();

    if (safeHouseName.isEmpty || safeHouseName.length > 30) {
      throw 'TÃªn nhÃ  pháº£i tá»« 1 Ä‘áº¿n 30 kÃ½ tá»±.';
    }
    if (safeNameU1.isEmpty) {
      throw 'TÃªn ngÆ°á»i thá»© 1 khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.';
    }
    if (safeStartDate == null) {
      throw 'Äá»‹nh dáº¡ng ngÃ y yÃªu khÃ´ng há»£p lá»‡.';
    }
    if (safeStartDate.isNotEmpty) {
      final parsedStart = DateTime.tryParse(safeStartDate);
      if (parsedStart == null) {
        throw 'Äá»‹nh dáº¡ng ngÃ y yÃªu khÃ´ng há»£p lá»‡.';
      }
      if (parsedStart.isAfter(DateTime.now())) {
        throw 'NgÃ y yÃªu khÃ´ng Ä‘Æ°á»£c á»Ÿ tÆ°Æ¡ng lai.';
      }
    }
    if (safeDobU1 == null || safeDobU2 == null) {
      throw 'Äá»‹nh dáº¡ng ngÃ y sinh khÃ´ng há»£p lá»‡.';
    }
    for (final dob in [safeDobU1, safeDobU2]) {
      if (dob.isEmpty) continue;
      if (DateTime.tryParse(dob) == null) {
        throw 'Äá»‹nh dáº¡ng ngÃ y sinh khÃ´ng há»£p lá»‡.';
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
      'house_profiles/$houseId/houseName': safeHouseName,
      'house_profiles/$houseId/nameU1': safeNameU1,
      'house_profiles/$houseId/nameU2': safeNameU2,
      'house_profiles/$houseId/startDate': safeStartDate,
      'house_profiles/$houseId/dayUnit': safeDayUnit,
      'house_profiles/$houseId/settings/houseName': safeHouseName,
      'house_profiles/$houseId/settings/nameU1': safeNameU1,
      'house_profiles/$houseId/settings/nameU2': safeNameU2,
      'house_profiles/$houseId/settings/startDate': safeStartDate,
      'house_profiles/$houseId/settings/dayUnit': safeDayUnit,
      'house_profiles/$houseId/settings/greetingQuote': safeGreetingQuote,
      'house_profiles/$houseId/settings/countdownTopLabel': safeGreetingQuote,
      'house_profiles/$houseId/settings/countdownBottomLabel': safeDayUnit,
      'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updated_at': ServerValue.timestamp,
      'houses_public/$houseId/houseName': safeHouseName,
      'houses_public/$houseId/startDate': safeStartDate,
      'houses_public/$houseId/dayUnit': safeDayUnit,
      'houses_public/$houseId/settings/houseName': safeHouseName,
      'houses_public/$houseId/settings/startDate': safeStartDate,
      'houses_public/$houseId/settings/dayUnit': safeDayUnit,
      'houses_public/$houseId/settings/greetingQuote': safeGreetingQuote,
      'houses_public/$houseId/settings/countdownTopLabel': safeGreetingQuote,
      'houses_public/$houseId/settings/countdownBottomLabel': safeDayUnit,
      'houses_public/$houseId/updatedAt': ServerValue.timestamp,
      'houses_public/$houseId/updated_at': ServerValue.timestamp,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        displayName: safeNameU1,
        houseName: safeHouseName,
        dobU1: safeDobU1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
    await _recordSpaceActivity(
      houseId,
      'Ä‘Ã£ lÃ m má»›i thÃ´ng tin khÃ´ng gian chung',
    );
  }

  Future<void> updateStartDate(
    String houseId,
    String dateStr, {
    bool startCooldown = false,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
    final safeDate = DateInputUtils.normalizeToIsoDate(
      dateStr,
      firstYear: 1900,
      lastYear: DateTime.now().year,
    );
    final parsed = safeDate == null ? null : DateTime.tryParse(safeDate);
    if (parsed == null) {
      throw 'Äá»‹nh dáº¡ng ngÃ y khÃ´ng há»£p lá»‡ (YYYY-MM-DD).';
    }
    if (parsed.isAfter(DateTime.now())) {
      throw 'NgÃ y yÃªu khÃ´ng Ä‘Æ°á»£c á»Ÿ tÆ°Æ¡ng lai!';
    }
    final settingsSnap = await _dbRef.child('houses/$houseId/settings').get();
    final settings = _asStringDynamicMap(settingsSnap.value) ?? {};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final changeCount = (_readEpochMs(settings['startDateChangeCount']) ?? 0) + 1;
    final nextCooldownUntil = null;

    try {
      await _dbRef.update({
        'houses/$houseId/settings/startDate': safeDate,
        'houses/$houseId/settings/startDateChangedAt': nowMs,
        'houses/$houseId/settings/startDateChangeCount': changeCount,
        'houses/$houseId/settings/startDateCooldownUntil': nextCooldownUntil,
        'houses/$houseId/settings/updatedAt': ServerValue.timestamp,
        'houses/$houseId/updatedAt': ServerValue.timestamp,
        'house_profiles/$houseId/startDate': safeDate,
        'house_profiles/$houseId/settings/startDate': safeDate,
        'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
        'house_profiles/$houseId/updated_at': ServerValue.timestamp,
        'houses_public/$houseId/startDate': safeDate,
        'houses_public/$houseId/settings/startDate': safeDate,
        'houses_public/$houseId/updatedAt': ServerValue.timestamp,
        'houses_public/$houseId/updated_at': ServerValue.timestamp,
      });
    } on FirebaseException catch (fe) {
      if (fe.code == 'permission-denied') {
        throw 'Há»‡ thá»‘ng tá»« chá»‘i cáº­p nháº­t ngÃ y yÃªu. CÃ³ thá»ƒ do lá»—i phÃ¢n quyá»n hoáº·c cáº¥u hÃ¬nh báº£o máº­t.';
      }
      rethrow;
    }

    await _recordSpaceActivity(
      houseId,
      'Ä‘Ã£ cáº­p nháº­t má»‘c ngÃ y cá»§a khÃ´ng gian',
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
      throw 'Chá»¯ phÃ­a trÃªn chá»‰ Ä‘Æ°á»£c tá»‘i Ä‘a 22 kÃ½ tá»±.';
    }
    if (safeBottomLabel.length > 22) {
      throw 'Chá»¯ phÃ­a dÆ°á»›i chá»‰ Ä‘Æ°á»£c tá»‘i Ä‘a 22 kÃ½ tá»±.';
    }

    final updates = <String, dynamic>{
      'houses/$houseId/settings/updatedAt': ServerValue.timestamp,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updated_at': ServerValue.timestamp,
      'houses_public/$houseId/updatedAt': ServerValue.timestamp,
      'houses_public/$houseId/updated_at': ServerValue.timestamp,
    };

    if (hasTopLabel) {
      updates.addAll({
        'houses/$houseId/settings/greetingQuote': safeTopLabel,
        'houses/$houseId/settings/countdownTopLabel': safeTopLabel,
        'house_profiles/$houseId/settings/greetingQuote': safeTopLabel,
        'house_profiles/$houseId/settings/countdownTopLabel': safeTopLabel,
        'houses_public/$houseId/settings/greetingQuote': safeTopLabel,
        'houses_public/$houseId/settings/countdownTopLabel': safeTopLabel,
      });
    }

    if (hasBottomLabel) {
      updates.addAll({
        'houses/$houseId/settings/dayUnit': safeBottomLabel,
        'houses/$houseId/settings/countdownBottomLabel': safeBottomLabel,
        'house_profiles/$houseId/dayUnit': safeBottomLabel,
        'house_profiles/$houseId/settings/dayUnit': safeBottomLabel,
        'house_profiles/$houseId/settings/countdownBottomLabel':
            safeBottomLabel,
        'houses_public/$houseId/dayUnit': safeBottomLabel,
        'houses_public/$houseId/settings/dayUnit': safeBottomLabel,
        'houses_public/$houseId/settings/countdownBottomLabel': safeBottomLabel,
      });
    }

    await _dbRef.update(updates);
    final activityText = hasTopLabel && hasBottomLabel
        ? 'Ä‘Ã£ chá»‰nh láº¡i chá»¯ á»Ÿ vÃ²ng Ä‘áº¿m ngÃ y'
        : hasTopLabel
            ? 'Ä‘Ã£ chá»‰nh dÃ²ng chá»¯ phÃ­a trÃªn vÃ²ng Ä‘áº¿m ngÃ y'
            : 'Ä‘Ã£ chá»‰nh dÃ²ng chá»¯ phÃ­a dÆ°á»›i vÃ²ng Ä‘áº¿m ngÃ y';
    await _recordSpaceActivity(houseId, activityText);
  }

  Future<void> updateHomeUiSettings({
    required String houseId,
    String? fallingEffectKey,
    String? countdownStyleKey,
  }) async {
    await _ensureCurrentDeviceCanModifySharedInfo(houseId);
    final updates = <String, dynamic>{
      'houses/$houseId/settings/updatedAt': ServerValue.timestamp,
      'houses/$houseId/updatedAt': ServerValue.timestamp,
    };

    if (fallingEffectKey != null) {
      updates['houses/$houseId/settings/fallingEffect'] =
          fallingEffectKey.trim();
    }
    if (countdownStyleKey != null) {
      updates['houses/$houseId/settings/countdownStyle'] =
          countdownStyleKey.trim();
    }

    if (updates.length <= 2) {
      return;
    }

    await _dbRef.update(updates);
  }

  Future<Map<String, dynamic>?> fetchHouseProfile(String houseId) async {
    try {
      final snap = await _dbRef
          .child('house_profiles/$houseId')
          .get()
          .timeout(const Duration(seconds: 3));
      if (!snap.exists || snap.value == null) return null;
      return _asStringDynamicMap(snap.value);
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
      return false; // Tráº£ vá» false náº¿u offline hoáº·c lá»—i
    }
  }

  Future<void> changeRelationshipMode({
    required String houseId,
    required String newMode,
    Duration cooldown = const Duration(hours: 24),
  }) async {
    throw 'Cháº¿ Ä‘á»™ Äá»™c thÃ¢n / CÃ³ ngÆ°á»i áº¥y chá»‰ Ä‘Æ°á»£c chá»n khi táº¡o nhÃ  láº§n Ä‘áº§u vÃ  khÃ´ng thá»ƒ Ä‘á»•i láº¡i trong CÃ i Ä‘áº·t.';
  }
}
