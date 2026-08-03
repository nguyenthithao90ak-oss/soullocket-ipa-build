import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/services/consent_service.dart';
import 'package:soullocket_app/utils/services/presence_service.dart';
import 'package:soullocket_app/utils/services/secure_storage_service.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'auth_support.dart';

class AuthHouseContextService {
  static const String _authUidPrefsKey = 'il_auth_uid';

  AuthHouseContextService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    DatabaseReference? databaseRef,
    ConsentService? consentService,
    SharedPreferencesProvider? sharedPreferencesProvider,
    HttpGet? httpGet,
    NowProvider? nowProvider,
  })  : _firebaseAuth = firebaseAuth,
        _databaseRef = databaseRef,
        _consentService = consentService,
        _sharedPreferencesProvider =
            sharedPreferencesProvider ?? SharedPreferences.getInstance,
        _httpGet = httpGet ?? http.get,
        _nowProvider = nowProvider ?? DateTime.now;

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final DatabaseReference? _databaseRef;
  final ConsentService? _consentService;
  final SharedPreferencesProvider _sharedPreferencesProvider;
  final HttpGet _httpGet;
  final NowProvider _nowProvider;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  DatabaseReference get _db => _databaseRef ?? FirebaseDatabase.instance.ref();
  ConsentService get _consent => _consentService ?? ConsentService();

  Future<SharedPreferences> get _prefs => _sharedPreferencesProvider();

  // --- Static in-memory houseId cache (dùng chung toàn app) ---
  static String? _memHouseId;
  static DateTime? _memHouseIdTime;
  static const _kMemHouseIdTtl = Duration(minutes: 5);

  /// Ghi nhớ houseId vào memory cache — gọi sau khi resolve thành công.
  static void setMemHouseId(String houseId) {
    if (houseId.isEmpty) return;
    _memHouseId = houseId;
    _memHouseIdTime = DateTime.now();
  }

  /// Đọc houseId nhanh: memory → SharedPrefs → SecureStorage → null (caller tự fallback RTDB).
  static Future<String?> quickHouseId() async {
    // 1. Memory cache
    if (_memHouseId != null &&
        _memHouseIdTime != null &&
        DateTime.now().difference(_memHouseIdTime!) < _kMemHouseIdTtl) {
      return _memHouseId;
    }
    // 2. SharedPrefs / SecureStorage
    try {
      final prefs = await SharedPreferences.getInstance();
      String cached = prefs.getString('il_house_id')?.trim() ?? '';
      if (cached.isEmpty) {
        cached = (await SecureStorageService.instance
                    .read(SecureStorageService.keyHouseId))
                ?.trim() ??
            '';
      }
      if (cached.isNotEmpty) {
        _memHouseId = cached;
        _memHouseIdTime = DateTime.now();
        return cached;
      }
    } catch (_) {}
    return null;
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

  Future<String?> getCachedRelationshipModeForEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;
    final prefs = await _prefs;
    return normalizeRelationshipMode(
      prefs.getString(relationshipModePrefsKey(normalizedEmail)),
    );
  }

  Future<void> cacheRelationshipModeForEmail(String email, String mode) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedMode = normalizeRelationshipMode(mode);
    if (normalizedEmail.isEmpty || normalizedMode == null) return;

    final prefs = await _prefs;
    await prefs.setString('il_rel_mode', normalizedMode);
    await prefs.setString(
      relationshipModePrefsKey(normalizedEmail),
      normalizedMode,
    );
  }

  Future<void> savePendingRelationshipModeForCurrentUser(String mode) async {
    final normalizedMode = normalizeRelationshipMode(mode);
    final user = _auth.currentUser;
    if (normalizedMode == null || user == null) return;

    await _db.child('users/${user.uid}/pendingRelationshipMode').set(
          normalizedMode,
        );

    final email = user.email?.trim().toLowerCase() ?? '';
    if (email.isNotEmpty) {
      await cacheRelationshipModeForEmail(email, normalizedMode);
    }
  }

  Future<String?> syncRelationshipModeForCurrentUser({
    firebase_auth.User? user,
    String? houseId,
  }) async {
    final resolvedUser = user ?? _auth.currentUser;
    final email = resolvedUser?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return null;

    String? resolvedHouseId = houseId?.trim();
    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      resolvedHouseId = await quickHouseId();
    }
    String? remoteMode;
    String? pendingMode;

    try {
      if (resolvedUser != null) {
        if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
          final results = await Future.wait([
            _db
                .child('houses/$resolvedHouseId/settings/relationshipMode')
                .get()
                .timeout(const Duration(seconds: 3)),
            _db
                .child('users/${resolvedUser.uid}/pendingRelationshipMode')
                .get()
                .timeout(const Duration(seconds: 3)),
          ]);
          remoteMode = normalizeRelationshipMode(results[0].value?.toString());
          pendingMode = normalizeRelationshipMode(results[1].value?.toString());
        } else {
          final results = await Future.wait([
            _db
                .child('users/${resolvedUser.uid}/houseId')
                .get()
                .timeout(const Duration(seconds: 3)),
            _db
                .child('users/${resolvedUser.uid}/pendingRelationshipMode')
                .get()
                .timeout(const Duration(seconds: 3)),
          ]);
          resolvedHouseId = results[0].value?.toString().trim();
          pendingMode = normalizeRelationshipMode(results[1].value?.toString());

          if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
            final modeSnap = await _db
                .child('houses/$resolvedHouseId/settings/relationshipMode')
                .get()
                .timeout(const Duration(seconds: 3));
            remoteMode = normalizeRelationshipMode(modeSnap.value?.toString());
          }
        }
      }
    } catch (_) {}

    final finalRemoteMode = remoteMode ?? pendingMode;
    if (finalRemoteMode != null) {
      await cacheRelationshipModeForEmail(email, finalRemoteMode);
      return finalRemoteMode;
    }

    final cachedMode = await getCachedRelationshipModeForEmail(email);
    if (cachedMode != null) {
      final prefs = await _prefs;
      await prefs.setString('il_rel_mode', cachedMode);
    }
    return cachedMode;
  }

  Future<String?> getDeviceId() async {
    return SecurityService().getDeviceId();
  }

  Future<void> checkBanStatus(
    String? houseId, {
    required Future<void> Function() onForcedSignOut,
  }) async {
    final allowSecurityDeviceSignals =
        await _consent.isSecurityDeviceSignalsAllowed();
    String? currentIp;
    if (allowSecurityDeviceSignals) {
      try {
        final response = await _httpGet(
          Uri.parse('https://get.geojs.io/v1/ip/geo.json'),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final resolvedIp = (data['ip'] ?? '').toString().trim();
          if (resolvedIp.isNotEmpty) {
            currentIp = resolvedIp;
          }
        }
      } catch (_) {}
    }

    if (currentIp != null) {
      try {
        final cleanIp = currentIp.replaceAll('.', '_');
        final bannedSnap = await _db.child('banned_ips/$cleanIp').get();
        if (bannedSnap.exists) {
          await onForcedSignOut();
          throw 'IP của bạn đã bị hệ thống chặn truy cập vĩnh viễn.';
        }
      } catch (error) {
        if (error is String) rethrow;
      }
    }

    if (houseId != null) {
      try {
        final deviceId = await getDeviceId();
        if (deviceId != null) {
          final securitySnapshot = await _db
              .child('houses/$houseId/security/devices/$deviceId')
              .get();
          if (securitySnapshot.exists) {
            final data = _asStringDynamicMap(securitySnapshot.value);
            if (data != null) {
              if (data['status'] == 'blocked') {
                await onForcedSignOut();
                throw 'Thiết bị này đã bị chủ nhà chặn truy cập vĩnh viễn.';
              }
              if (data['status'] == 'deleted') {
                final deletedAt = data['deleted_at'] as int?;
                if (deletedAt != null) {
                  final diff =
                      _nowProvider().millisecondsSinceEpoch - deletedAt;
                  if (diff < 3600000) {
                    final minutesLeft = 60 - (diff / 60000).floor();
                    await onForcedSignOut();
                    throw 'Thiết bị này vừa bị xóa khỏi nhà. Vui lòng thử lại sau $minutesLeft phút.';
                  }
                }
              }
            }
          }
        }
      } catch (error) {
        if (error is String) rethrow;
      }
    }
  }

  Future<String> detectAutoRole(String? houseId) async {
    if (houseId == null) return 'user1';

    try {
      final houseSettingsSnap =
          await _db.child('houses/$houseId/settings').get();
      if (!houseSettingsSnap.exists) return 'user1';
      final settings = _asStringDynamicMap(houseSettingsSnap.value);

      if (settings != null && settings['relationshipMode'] == 'single') {
        return 'user1';
      }

      final presenceSnap = await _db.child('houses/$houseId/presence').get();
      final presence = _asStringDynamicMap(presenceSnap.value);
      if (presence != null) {
        final u1Map = _asStringDynamicMap(presence['user1']);
        final u2Map = _asStringDynamicMap(presence['user2']);

        final u1Online =
            u1Map != null && PresenceService.isPresenceOnline(u1Map);
        final u2Online =
            u2Map != null && PresenceService.isPresenceOnline(u2Map);

        if (u1Online && !u2Online) return 'user2';
        if (!u1Online && u2Online) return 'user1';

        final prefs = await _prefs;
        final prevRole = prefs.getString('il_role');
        if (prevRole == 'user1' || prevRole == 'user2') {
          return prevRole!;
        }

        final u1Seen = int.tryParse(u1Map?['lastSeen']?.toString() ?? '0') ?? 0;
        final u2Seen = int.tryParse(u2Map?['lastSeen']?.toString() ?? '0') ?? 0;

        if (u1Seen > 0 && u2Seen == 0) return 'user2';
        if (u2Seen > 0 && u1Seen == 0) return 'user1';
        if (u1Seen > u2Seen) return 'user2';
        if (u2Seen > u1Seen) return 'user1';
      }

      final prefs = await _prefs;
      final prevRole = prefs.getString('il_role');
      if (prevRole == 'user1' || prevRole == 'user2') {
        return prevRole!;
      }
      return '';
    } catch (_) {
      final prefs = await _prefs;
      final prevRole = prefs.getString('il_role');
      if (prevRole == 'user1' || prevRole == 'user2') {
        return prevRole!;
      }
      return '';
    }
  }

  Map<String, dynamic> buildPublicRecoveryMeta(String email) {
    final normalized = normalizeSecurityEmail(email);
    return {
      'recovery_hint': normalized.isEmpty ? '' : maskEmail(normalized),
      'recovery_ready': normalized.isNotEmpty,
    };
  }

  Future<void> _restoreRoleFromDatabase(
    String houseId,
    String uid,
    SharedPreferences prefs,
  ) async {
    final localRole = prefs.getString('il_role');
    if (localRole != null && (localRole == 'user1' || localRole == 'user2')) {
      return;
    }
    try {
      final memberSnap = await _db.child('houses/$houseId/members/$uid').get();
      if (memberSnap.exists) {
        final data = memberSnap.value;
        if (data is Map) {
          final role = data['role']?.toString().trim();
          if (role == 'user1' || role == 'user2') {
            await prefs.setString('il_role', role!);
            await SecureStorageService.instance
                .write(SecureStorageService.keyRole, role);
            return;
          }
        }
      }
      final ownerUidSnap = await _db.child('houses/$houseId/owner_uid').get();
      String? ownerUid = ownerUidSnap.value?.toString().trim();
      if (ownerUid == null || ownerUid.isEmpty) {
        final ownerUidSnap2 = await _db.child('houses/$houseId/ownerUid').get();
        ownerUid = ownerUidSnap2.value?.toString().trim();
      }
      if (ownerUid != null && ownerUid.isNotEmpty) {
        final localRole = prefs.getString('il_role');
        if (localRole == 'user1' || localRole == 'user2') {
          try {
            await _db.child('houses/$houseId/members/$uid/role').set(localRole);
          } catch (_) {}
          return;
        }

        final resolvedRole = (ownerUid == uid) ? 'user1' : 'user2';
        await prefs.setString('il_role', resolvedRole);
        await SecureStorageService.instance
            .write(SecureStorageService.keyRole, resolvedRole);
      }
    } catch (_) {}
  }

  Future<String?> resolveCurrentHouseId({firebase_auth.User? user}) async {
    final prefs = await _prefs;
    String cachedHouseId = prefs.getString('il_house_id')?.trim() ?? '';
    if (cachedHouseId.isEmpty) {
      cachedHouseId = (await SecureStorageService.instance
                  .read(SecureStorageService.keyHouseId))
              ?.trim() ??
          '';
    }
    String cachedAuthUid = prefs.getString(_authUidPrefsKey)?.trim() ?? '';
    if (cachedAuthUid.isEmpty) {
      cachedAuthUid = (await SecureStorageService.instance
                  .read(SecureStorageService.keyAuthUid))
              ?.trim() ??
          '';
    }
    final resolvedUser = user ?? _auth.currentUser;
    if (cachedHouseId.isNotEmpty) {
      if (resolvedUser != null && cachedAuthUid == resolvedUser.uid) {
        final localRole = prefs.getString('il_role');
        if (localRole == null ||
            (localRole != 'user1' && localRole != 'user2')) {
          await _restoreRoleFromDatabase(
              cachedHouseId, resolvedUser.uid, prefs);
        }
        return cachedHouseId;
      }
      await prefs.remove('il_house_id');
      await prefs.remove('il_role');
      await SecureStorageService.instance
          .delete(SecureStorageService.keyHouseId);
      await SecureStorageService.instance.delete(SecureStorageService.keyRole);
    }

    if (resolvedUser == null) return null;

    try {
      final primarySnap =
          await _db.child('users/${resolvedUser.uid}/houseId').get();
      final primaryValue = primarySnap.value?.toString().trim() ?? '';
      if (primaryValue.isNotEmpty) {
        await prefs.setString('il_house_id', primaryValue);
        setMemHouseId(primaryValue);
        await prefs.setString(_authUidPrefsKey, resolvedUser.uid);
        await SecureStorageService.instance
            .write(SecureStorageService.keyHouseId, primaryValue);
        await SecureStorageService.instance
            .write(SecureStorageService.keyAuthUid, resolvedUser.uid);
        await _restoreRoleFromDatabase(primaryValue, resolvedUser.uid, prefs);
        return primaryValue;
      }
    } catch (_) {}

    try {
      final legacySnap =
          await _db.child('users/${resolvedUser.uid}/house_id').get();
      final legacyValue = legacySnap.value?.toString().trim() ?? '';
      if (legacyValue.isNotEmpty) {
        await _db
            .child('users/${resolvedUser.uid}')
            .update({'houseId': legacyValue});
        await prefs.setString('il_house_id', legacyValue);
        setMemHouseId(legacyValue);
        await prefs.setString(_authUidPrefsKey, resolvedUser.uid);
        await SecureStorageService.instance
            .write(SecureStorageService.keyHouseId, legacyValue);
        await SecureStorageService.instance
            .write(SecureStorageService.keyAuthUid, resolvedUser.uid);
        await _restoreRoleFromDatabase(legacyValue, resolvedUser.uid, prefs);
        return legacyValue;
      }
    } catch (_) {}

    return null;
  }

  Future<void> syncSecurityEmailForCurrentUser({
    firebase_auth.User? user,
    String? email,
    String? houseId,
  }) async {
    final resolvedUser = user ?? _auth.currentUser;
    if (resolvedUser == null) return;

    final normalizedEmail = _resolveProviderEmail(
      resolvedUser,
      preferredEmail: email,
    );
    if (!normalizedEmail.contains('@')) return;

    final resolvedHouseId = (houseId?.trim().isNotEmpty ?? false)
        ? houseId!.trim()
        : await resolveCurrentHouseId(user: resolvedUser);

    final updates = <String, dynamic>{
      'users/${resolvedUser.uid}/email': normalizedEmail,
    };

    if (resolvedHouseId != null && resolvedHouseId.isNotEmpty) {
      final publicMeta = buildPublicRecoveryMeta(normalizedEmail);
      updates['houses/$resolvedHouseId/security/email'] = normalizedEmail;
      updates['houses_public/$resolvedHouseId/recovery_hint'] =
          publicMeta['recovery_hint'];
      updates['houses_public/$resolvedHouseId/recovery_ready'] =
          publicMeta['recovery_ready'];
    }

    await _db.update(updates);
  }

  String _resolveProviderEmail(
    firebase_auth.User user, {
    String? preferredEmail,
  }) {
    final preferred = normalizeSecurityEmail(preferredEmail ?? '');
    if (preferred.contains('@')) return preferred;

    final direct = normalizeSecurityEmail(user.email ?? '');
    if (direct.contains('@')) return direct;

    for (final provider in user.providerData) {
      final providerEmail = normalizeSecurityEmail(provider.email ?? '');
      if (providerEmail.contains('@')) return providerEmail;
    }
    return '';
  }
}
