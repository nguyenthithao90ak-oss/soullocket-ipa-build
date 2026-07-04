import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'offline_cache_service.dart';
import 'secure_storage_service.dart';

class JoinHouseResult {
  final bool success;
  final String? errorCode;
  final String errorMessage;

  const JoinHouseResult.ok()
      : success = true,
        errorCode = null,
        errorMessage = '';

  const JoinHouseResult.fail(this.errorCode, this.errorMessage)
      : success = false;
}

class JoinHouseError {
  static const notFound = 'TARGET_NOT_FOUND';
  static const alreadyFull = 'TARGET_ALREADY_FULL';
  static const selfJoin = 'CANNOT_SELF_JOIN';
  static const notLoggedIn = 'NOT_LOGGED_IN';
  static const cooldown = 'COOLDOWN_ACTIVE';
  static const alreadyJoined = 'ALREADY_JOINED';
  static const unknown = 'UNKNOWN_ERROR';
}

class CoupleService {
  static final CoupleService _instance = CoupleService._internal();

  factory CoupleService() => _instance;
  CoupleService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<JoinHouseResult> joinHouse(String targetHouseId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const JoinHouseResult.fail(
          JoinHouseError.notLoggedIn,
          'Bạn cần đăng nhập trước.',
        );
      }

      final normalizedTargetHouseId = targetHouseId.trim();
      if (normalizedTargetHouseId.isEmpty) {
        return const JoinHouseResult.fail(
          JoinHouseError.notFound,
          'Mã nhà không tồn tại. Vui lòng kiểm tra lại.',
        );
      }

      final callable = _functions.httpsCallable('joinHouseSecure');
      final response = await callable.call(<String, dynamic>{
        'houseId': normalizedTargetHouseId,
      });
      final payload = Map<String, dynamic>.from(response.data as Map);
      final resolvedHouseId =
          payload['houseId']?.toString().trim().isNotEmpty == true
              ? payload['houseId'].toString().trim()
              : normalizedTargetHouseId;
      final assignedRole =
          payload['assignedRole']?.toString().trim().isNotEmpty == true
              ? payload['assignedRole'].toString().trim()
              : 'user2';

      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      await SecureStorageService.instance
          .write(SecureStorageService.keyHouseId, resolvedHouseId);
      await SecureStorageService.instance
          .write(SecureStorageService.keyAuthUid, user.uid);
      await SecureStorageService.instance
          .write(SecureStorageService.keyRole, assignedRole);
      await SecureStorageService.instance
          .write(SecureStorageService.keyRelMode, 'couple');
      await prefs.remove('il_house_id');
      await prefs.remove('il_auth_uid');
      await prefs.remove('il_role');
      await prefs.remove('il_rel_mode');
      await prefs.remove('il_single_connect_qr_pending_$resolvedHouseId');

      return const JoinHouseResult.ok();
    } on FirebaseFunctionsException catch (error) {
      final mappedCode = switch (error.code) {
        'not-found' => JoinHouseError.notFound,
        'already-exists' => JoinHouseError.alreadyJoined,
        'resource-exhausted' => JoinHouseError.alreadyFull,
        'failed-precondition' => JoinHouseError.selfJoin,
        'unauthenticated' => JoinHouseError.notLoggedIn,
        _ => JoinHouseError.unknown,
      };
      return JoinHouseResult.fail(
        mappedCode,
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Không thể tham gia nhà này lúc này.',
      );
    } catch (e) {
      final resolvedMessage = AppErrorMapper.resolve(e).message;
      return JoinHouseResult.fail(
        JoinHouseError.unknown,
        resolvedMessage.isNotEmpty
            ? resolvedMessage
            : 'Không thể tham gia nhà này lúc này.',
      );
    }
  }

  Future<bool> isCoupleConnected(String houseId) async {
    final snap = await _db.ref('houses/$houseId/members').get();
    return _toMap(snap.value).length >= 2;
  }

  Stream<bool> coupleStatusStream(String houseId) {
    return _db.ref('houses/$houseId/members').onValue.map((event) {
      return _toMap(event.snapshot.value).length >= 2;
    });
  }

  Future<void> disconnectCouple(String houseId, String uid) async {
    final leavingRole = await _resolveMemberRole(houseId: houseId, uid: uid);

    await _db.ref('houses/$houseId/members/$uid').remove();
    await _db.ref('houses/$houseId/presence/$uid').remove();
    if (leavingRole != null) {
      await _db.ref('houses/$houseId/presence/$leavingRole').remove();
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.ref().update({
      'houses/$houseId/settings/relationshipMode': 'single',
      'house_profiles/$houseId/relationshipMode': 'single',
      'house_profiles/$houseId/settings/relationshipMode': 'single',
      'houses_public/$houseId/relationshipMode': 'single',
      'houses_public/$houseId/settings/relationshipMode': 'single',
      'houses/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updatedAt': ServerValue.timestamp,
      'house_profiles/$houseId/updated_at': ServerValue.timestamp,
      'houses_public/$houseId/updatedAt': ServerValue.timestamp,
      'houses_public/$houseId/updated_at': ServerValue.timestamp,
      ...SingleMatchService.profileIndexUpdates(
        houseId: houseId,
        relationshipMode: 'single',
        updatedAt: nowMs,
      ),
    });
    await _db.ref('users/$uid/house_id').remove();
    await _db.ref('users/$uid/houseId').remove();
  }

  Future<String?> _resolveMemberRole({
    required String houseId,
    required String uid,
  }) async {
    final membersSnap = await _db.ref('houses/$houseId/members').get();
    final ownerUidSnap = await _db.ref('houses/$houseId/owner_uid').get();
    final members = _toMap(membersSnap.value);
    final ownerUid = ownerUidSnap.value?.toString().trim();
    return _findMemberRole(
      members: members,
      uid: uid,
      ownerUid: ownerUid,
    );
  }

  String? _findMemberRole({
    required Map<String, dynamic> members,
    required String uid,
    String? ownerUid,
  }) {
    if (!members.containsKey(uid)) {
      return null;
    }

    final raw = members[uid];
    if (raw is Map) {
      final normalized = _normalizeRole(raw['role']);
      if (normalized != null) {
        return normalized;
      }
    }

    if ((ownerUid ?? '').isNotEmpty && ownerUid == uid) {
      return 'user1';
    }

    return 'user2';
  }

  String? _normalizeRole(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == 'user1' || value == 'user2') {
      return value;
    }
    return null;
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }
}
