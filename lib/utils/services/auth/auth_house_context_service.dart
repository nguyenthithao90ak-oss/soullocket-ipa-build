import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/services/presence_service.dart';
import 'package:soullocket_app/utils/services/secure_storage_service.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'auth_support.dart';

class AuthHouseContextService {
  static const String _authUidPrefsKey = 'il_auth_uid';

  AuthHouseContextService({
    this._firebaseAuth,
    this._databaseRef,
    SharedPreferencesProvider? sharedPreferencesProvider,
    NowProvider? nowProvider,
  }) : _sharedPreferencesProvider =
           sharedPreferencesProvider ?? SharedPreferences.getInstance,
       _nowProvider = nowProvider ?? DateTime.now;

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final DatabaseReference? _databaseRef;
  final SharedPreferencesProvider _sharedPreferencesProvider;
  final NowProvider _nowProvider;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  DatabaseReference get _db => _databaseRef ?? FirebaseDatabase.instance.ref();

  Future<SharedPreferences> get _prefs => _sharedPreferencesProvider();

  // --- Static in-memory houseId cache (dùng chung toàn app) ---
  static String? _memHouseId;
  static String? _memAuthUid;
  static DateTime? _memHouseIdTime;
  static const _kMemHouseIdTtl = Duration(minutes: 5);

  /// Ghi nhớ houseId vào memory cache — gọi sau khi resolve thành công.
  static void setMemHouseId(String houseId, {required String uid}) {
    if (houseId.isEmpty || uid.isEmpty) return;
    _memHouseId = houseId;
    _memAuthUid = uid;
    _memHouseIdTime = DateTime.now();
  }

  static void clearMemHouseId() {
    _memHouseId = null;
    _memAuthUid = null;
    _memHouseIdTime = null;
  }

  /// Đọc houseId nhanh: memory → SharedPrefs → SecureStorage → null (caller tự fallback RTDB).
  static Future<String?> quickHouseId({
    firebase_auth.FirebaseAuth? firebaseAuth,
  }) async {
    final auth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      clearMemHouseId();
      return null;
    }
    // 1. Memory cache
    if (_memHouseId != null &&
        _memAuthUid == uid &&
        _memHouseIdTime != null &&
        DateTime.now().difference(_memHouseIdTime!) < _kMemHouseIdTtl) {
      return _memHouseId;
    }
    // 2. SharedPrefs / SecureStorage
    try {
      final prefs = await SharedPreferences.getInstance();
      String cached = prefs.getString('il_house_id')?.trim() ?? '';
      String ownerUid = prefs.getString(_authUidPrefsKey)?.trim() ?? '';
      if (cached.isEmpty) {
        cached =
            (await SecureStorageService.instance.read(
              SecureStorageService.keyHouseId,
            ))?.trim() ??
            '';
        ownerUid =
            (await SecureStorageService.instance.read(
              SecureStorageService.keyAuthUid,
            ))?.trim() ??
            '';
      }
      if (cached.isNotEmpty &&
          ownerUid == uid &&
          auth.currentUser?.uid == uid) {
        setMemHouseId(cached, uid: uid);
        return cached;
      }
    } catch (error) {
      debugPrint('[AuthHouseContext] Không đọc được house cache: $error');
    }
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

    await _db
        .child('users/${user.uid}/pendingRelationshipMode')
        .set(normalizedMode);

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
    if (email.isEmpty || _auth.currentUser?.uid != resolvedUser?.uid) {
      return null;
    }

    String? resolvedHouseId = houseId?.trim();
    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      resolvedHouseId = await quickHouseId(firebaseAuth: _auth);
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
    } catch (error) {
      debugPrint('[AuthHouseContext] Không tải được relationship mode: $error');
    }

    final finalRemoteMode = remoteMode ?? pendingMode;
    if (_auth.currentUser?.uid != resolvedUser?.uid) return null;
    if (finalRemoteMode != null) {
      await cacheRelationshipModeForEmail(email, finalRemoteMode);
      return finalRemoteMode;
    }

    final cachedMode = await getCachedRelationshipModeForEmail(email);
    if (cachedMode != null) {
      final prefs = await _prefs;
      if (_auth.currentUser?.uid != resolvedUser?.uid) return null;
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
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (houseId != null && houseId.trim().isNotEmpty) {
      try {
        final token = await _auth.currentUser?.getIdTokenResult();
        final isAdmin = hasAdminClaim(token?.claims);
        // Không đọc nguyên nhà: vùng này có các trường bảo mật bị giới hạn riêng.
        const fields = [
          'isBanned',
          'banned',
          'banUntil',
          'bannedUntil',
          'banReason',
        ];
        final snapshots = await Future.wait(
          fields.map(
            (field) => _db.child('houses/${houseId.trim()}/$field').get(),
          ),
        );
        if (_auth.currentUser?.uid != uid) return;
        final house = <String, dynamic>{
          for (var i = 0; i < fields.length; i++) fields[i]: snapshots[i].value,
        };
        final banned = house['isBanned'] == true || house['banned'] == true;
        final bannedUntil =
            int.tryParse(
              (house['banUntil'] ?? house['bannedUntil'] ?? 0).toString(),
            ) ??
            0;
        final banIsActive =
            banned &&
            (bannedUntil <= 0 ||
                bannedUntil > _nowProvider().millisecondsSinceEpoch);
        if (banIsActive && !isAdmin) {
          final reason = house['banReason']?.toString().trim();
          await onForcedSignOut();
          throw reason == null || reason.isEmpty
              ? 'Tài khoản này đã bị khóa truy cập. Vui lòng liên hệ quản trị viên.'
              : 'Tài khoản này đã bị khóa: $reason';
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
          if (_auth.currentUser?.uid != uid) return;
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
      final houseSettingsSnap = await _db
          .child('houses/$houseId/settings')
          .get();
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
    if (_auth.currentUser?.uid != uid) return;
    final localRole = prefs.getString('il_role');
    if (localRole != null && (localRole == 'user1' || localRole == 'user2')) {
      return;
    }
    try {
      final memberSnap = await _db.child('houses/$houseId/members/$uid').get();
      if (_auth.currentUser?.uid != uid) return;
      if (memberSnap.exists) {
        final data = memberSnap.value;
        if (data is Map) {
          final role = data['role']?.toString().trim();
          if (role == 'user1' || role == 'user2') {
            await prefs.setString('il_role', role!);
            if (_auth.currentUser?.uid != uid) return;
            await SecureStorageService.instance.write(
              SecureStorageService.keyRole,
              role,
            );
            return;
          }
        }
      }
      final ownerUidSnap = await _db.child('houses/$houseId/owner_uid').get();
      if (_auth.currentUser?.uid != uid) return;
      String? ownerUid = ownerUidSnap.value?.toString().trim();
      if (ownerUid == null || ownerUid.isEmpty) {
        final ownerUidSnap2 = await _db.child('houses/$houseId/ownerUid').get();
        if (_auth.currentUser?.uid != uid) return;
        ownerUid = ownerUidSnap2.value?.toString().trim();
      }
      if (ownerUid != null && ownerUid.isNotEmpty) {
        final localRole = prefs.getString('il_role');
        if (localRole == 'user1' || localRole == 'user2') {
          try {
            await _db.child('houses/$houseId/members/$uid/role').set(localRole);
          } catch (error) {
            debugPrint(
              '[AuthHouseContext] Không đồng bộ được member role: $error',
            );
          }
          return;
        }

        final resolvedRole = (ownerUid == uid) ? 'user1' : 'user2';
        await prefs.setString('il_role', resolvedRole);
        if (_auth.currentUser?.uid != uid) return;
        await SecureStorageService.instance.write(
          SecureStorageService.keyRole,
          resolvedRole,
        );
      }
    } catch (error) {
      debugPrint('[AuthHouseContext] Không khôi phục được role: $error');
    }
  }

  Future<String?> resolveCurrentHouseId({firebase_auth.User? user}) async {
    final resolvedUser = user ?? _auth.currentUser;
    if (resolvedUser == null || _auth.currentUser?.uid != resolvedUser.uid) {
      return null;
    }
    final prefs = await _prefs;
    if (_auth.currentUser?.uid != resolvedUser.uid) return null;
    String cachedHouseId = prefs.getString('il_house_id')?.trim() ?? '';
    String cachedAuthUid = prefs.getString(_authUidPrefsKey)?.trim() ?? '';
    if (cachedHouseId.isEmpty) {
      cachedHouseId =
          (await SecureStorageService.instance.read(
            SecureStorageService.keyHouseId,
          ))?.trim() ??
          '';
      cachedAuthUid =
          (await SecureStorageService.instance.read(
            SecureStorageService.keyAuthUid,
          ))?.trim() ??
          '';
    }
    if (_auth.currentUser?.uid != resolvedUser.uid) return null;
    if (cachedHouseId.isNotEmpty) {
      if (cachedAuthUid == resolvedUser.uid) {
        final localRole = prefs.getString('il_role');
        if (localRole == null ||
            (localRole != 'user1' && localRole != 'user2')) {
          await _restoreRoleFromDatabase(
            cachedHouseId,
            resolvedUser.uid,
            prefs,
          );
        }
        if (_auth.currentUser?.uid != resolvedUser.uid) return null;
        setMemHouseId(cachedHouseId, uid: resolvedUser.uid);
        return cachedHouseId;
      }
      await prefs.remove('il_house_id');
      if (_auth.currentUser?.uid != resolvedUser.uid) return null;
      await prefs.remove('il_role');
    }

    if (_auth.currentUser?.uid != resolvedUser.uid) return null;

    try {
      final primarySnap = await _db
          .child('users/${resolvedUser.uid}/houseId')
          .get();
      if (_auth.currentUser?.uid != resolvedUser.uid) return null;
      final primaryValue = primarySnap.value?.toString().trim() ?? '';
      if (primaryValue.isNotEmpty) {
        if (!await _cacheResolvedHouseId(
          resolvedUser.uid,
          primaryValue,
          prefs,
        )) {
          return null;
        }
        await _restoreRoleFromDatabase(primaryValue, resolvedUser.uid, prefs);
        if (_auth.currentUser?.uid != resolvedUser.uid) return null;
        return primaryValue;
      }
    } catch (error) {
      debugPrint('[AuthHouseContext] Không đọc được houseId chính: $error');
    }

    if (_auth.currentUser?.uid != resolvedUser.uid) return null;
    try {
      final legacySnap = await _db
          .child('users/${resolvedUser.uid}/house_id')
          .get();
      if (_auth.currentUser?.uid != resolvedUser.uid) return null;
      final legacyValue = legacySnap.value?.toString().trim() ?? '';
      if (legacyValue.isNotEmpty) {
        await _db.child('users/${resolvedUser.uid}').update({
          'houseId': legacyValue,
        });
        if (!await _cacheResolvedHouseId(
          resolvedUser.uid,
          legacyValue,
          prefs,
        )) {
          return null;
        }
        await _restoreRoleFromDatabase(legacyValue, resolvedUser.uid, prefs);
        if (_auth.currentUser?.uid != resolvedUser.uid) return null;
        return legacyValue;
      }
    } catch (error) {
      debugPrint('[AuthHouseContext] Không đọc được houseId legacy: $error');
    }

    return null;
  }

  Future<bool> _cacheResolvedHouseId(
    String uid,
    String houseId,
    SharedPreferences prefs,
  ) async {
    if (_auth.currentUser?.uid != uid) return false;
    await prefs.setString('il_house_id', houseId);
    if (_auth.currentUser?.uid != uid) return false;
    await prefs.setString(_authUidPrefsKey, uid);
    if (_auth.currentUser?.uid != uid) return false;
    await SecureStorageService.instance.write(
      SecureStorageService.keyHouseId,
      houseId,
    );
    if (_auth.currentUser?.uid != uid) return false;
    await SecureStorageService.instance.write(
      SecureStorageService.keyAuthUid,
      uid,
    );
    if (_auth.currentUser?.uid != uid) return false;
    setMemHouseId(houseId, uid: uid);
    return true;
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
