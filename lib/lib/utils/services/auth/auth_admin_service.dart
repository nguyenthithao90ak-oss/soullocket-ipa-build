import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/core/constants/app_config.dart';
import 'auth_support.dart';

class AuthAdminService {
  AuthAdminService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    DatabaseReference? databaseRef,
  })  : _firebaseAuth = firebaseAuth,
        _databaseRef = databaseRef;

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final DatabaseReference? _databaseRef;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  DatabaseReference get _db => _databaseRef ?? FirebaseDatabase.instance.ref();

  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    return isUserAdmin(_auth.currentUser, forceRefresh: forceRefresh);
  }

  Future<bool> isUserAdmin(
    firebase_auth.User? user, {
    bool forceRefresh = false,
  }) async {
    if (user == null) return false;

    try {
      final tokenResult = await user.getIdTokenResult(forceRefresh).timeout(
            const Duration(seconds: 3),
          );
      final hasClaim = hasAdminClaim(tokenResult.claims);

      if (hasClaim) {
        final adminSnapshot =
            await _db.child('admins/${user.uid}').get().timeout(
                  const Duration(seconds: 3),
                );
        if (adminSnapshot.exists) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isMaintenanceModeEnabled() async {
    try {
      final snapshot = await _db
          .child(AppConfig.maintenanceModePath)
          .get()
          .timeout(const Duration(seconds: 2));
      if (snapshot.exists) {
        return snapshot.value == true;
      }

      final legacySnapshot = await _db
          .child(AppConfig.legacyMaintenanceModePath)
          .get()
          .timeout(const Duration(seconds: 2));
      return legacySnapshot.value == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getSystemBlockReason(
    String email, {
    bool allowAdminBypass = false,
    bool forceRefreshAdmin = false,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    var isAdmin = false;
    if (allowAdminBypass) {
      final currentUser = _auth.currentUser;
      final currentEmail = currentUser?.email?.trim().toLowerCase() ?? '';
      if (currentEmail.isNotEmpty && currentEmail == normalizedEmail) {
        isAdmin = await isCurrentUserAdmin(forceRefresh: forceRefreshAdmin);
      }
    }

    final isMaintenanceMode = await isMaintenanceModeEnabled();
    if (isMaintenanceMode) {
      return 'Hệ thống đang trong chế độ bảo trì. Vui lòng quay lại sau.';
    }

    try {
      final bannedSnapshot = await _db
          .child('banned_users/${normalizeEmailKey(normalizedEmail)}')
          .get()
          .timeout(const Duration(seconds: 2));
      if (bannedSnapshot.exists && !isAdmin) {
        return 'Tài khoản này đã bị khóa truy cập. Vui lòng liên hệ quản trị viên.';
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String?> getCurrentUserBlockReason() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) return null;
    return getSystemBlockReason(
      email,
      allowAdminBypass: true,
    );
  }
}
