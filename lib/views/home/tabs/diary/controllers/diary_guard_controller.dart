import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/app_lifecycle_presence_guard.dart';
import 'package:soullocket_app/utils/services/military_lock_service.dart';
import 'package:soullocket_app/utils/permission_helper.dart';

class DiaryGuardController extends ChangeNotifier {
  DiaryGuardController({
    FirebaseAuth? auth,
    MilitaryLockService? militaryLockService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _militaryLockService = militaryLockService ?? MilitaryLockService() {
    refreshConnectivity();
  }

  final FirebaseAuth _auth;
  final MilitaryLockService _militaryLockService;

  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;
  bool _showDiaryPrivacyNotice = true;
  Future<ConnectivityResult>? _connectivityFuture;

  bool get isAuthenticated => _isAuthenticated;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get showDiaryPrivacyNotice => _showDiaryPrivacyNotice;
  Future<ConnectivityResult>? get connectivityFuture => _connectivityFuture;

  void refreshConnectivity() {
    _connectivityFuture = Connectivity().checkConnectivity().then(
          (results) =>
              results.isNotEmpty ? results.first : ConnectivityResult.none,
        );
    notifyListeners();
  }

  Future<void> loadPrivacyNoticeState() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _auth.currentUser?.uid ?? 'guest';
    final hasSeen = prefs.getBool('il_diary_privacy_seen_$uid') ?? false;
    final nextValue = !hasSeen;
    if (_showDiaryPrivacyNotice == nextValue) {
      return;
    }
    _showDiaryPrivacyNotice = nextValue;
    notifyListeners();
  }

  Future<void> dismissPrivacyNotice() async {
    if (!_showDiaryPrivacyNotice) {
      return;
    }
    _showDiaryPrivacyNotice = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final uid = _auth.currentUser?.uid ?? 'guest';
    await prefs.setBool('il_diary_privacy_seen_$uid', true);
  }

  Future<bool> prepareAccessState({
    required String? houseId,
  }) async {
    final needsUnlock = await _militaryLockService.needsUnlock(
      LockScope.diary,
      houseId: houseId,
    );
    final nextAuthenticated = !needsUnlock;
    final shouldNotify =
        _isCheckingAuth || _isAuthenticated != nextAuthenticated;

    _isCheckingAuth = false;
    _isAuthenticated = nextAuthenticated;

    if (shouldNotify) {
      notifyListeners();
    }
    return nextAuthenticated;
  }

  Future<void> unlockDiary(
    BuildContext context, {
    required String? houseId,
    required Future<void> Function() onUnlocked,
  }) async {
    final authSuccess = await _militaryLockService.requestUnlock(
      context: context,
      scope: LockScope.diary,
      houseId: houseId,
      title: 'Nhật ký tình yêu',
      reason: MilitaryLockService.scopeReason(LockScope.diary),
    );

    _isAuthenticated = authSuccess;
    _isCheckingAuth = false;
    notifyListeners();

    if (authSuccess) {
      await onUnlocked();
    }
  }

  Future<User?> resolveCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return _auth.currentUser;
    }
  }

  Future<bool> ensureGalleryPermission(BuildContext context) async {
    if (kIsWeb) {
      return true;
    }

    if (Platform.isIOS) {
      final status = await app_permission.Permission.photosAddOnly.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }
      if (!context.mounted) {
        return false;
      }

      final requested = await PermissionHelper.requestWithDisclosure(
        context,
        app_permission.Permission.photosAddOnly,
        title: L10nService().translate('diary_upload_permission_title'),
        disclosure: L10nService().translate('diary_upload_permission_ios_desc'),
      );

      if (requested) {
        return true;
      }

      if (!context.mounted) {
        return false;
      }
      final currentStatus =
          await app_permission.Permission.photosAddOnly.status;
      if (currentStatus.isPermanentlyDenied) {
        await AppLifecyclePresenceGuard.guard(app_permission.openAppSettings);
      }
      return false;
    }

    if (!Platform.isAndroid) {
      return true;
    }

    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdkInt >= 29) {
      return true;
    }

    final status = await app_permission.Permission.storage.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }

    final requested = await PermissionHelper.requestWithDisclosure(
      context,
      app_permission.Permission.storage,
      title: L10nService().translate('diary_upload_permission_title'),
      disclosure:
          L10nService().translate('diary_upload_permission_android_desc'),
    );

    if (requested) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }
    final currentStatus = await app_permission.Permission.storage.status;
    if (currentStatus.isPermanentlyDenied) {
      await AppLifecyclePresenceGuard.guard(app_permission.openAppSettings);
    }
    return false;
  }
}
