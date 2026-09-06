import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/app_lifecycle_presence_guard.dart';
import '../../../../../utils/services/military_lock_service.dart';
import '../../../../../utils/permission_helper.dart';

class DiaryGuardController extends ChangeNotifier {
  DiaryGuardController({
    FirebaseAuth? auth,
    MilitaryLockService? militaryLockService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _militaryLockService = militaryLockService ?? MilitaryLockService() {
    refreshConnectivity();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
    _connectivityFuture = Connectivity()
        .checkConnectivity()
        .then(
          (results) =>
              results.isNotEmpty ? results.first : ConnectivityResult.none,
        )
        .catchError((_) => ConnectivityResult.none);
    if (!_disposed) notifyListeners();
  }

  Future<void> loadPrivacyNoticeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final uid = _auth.currentUser?.uid ?? 'guest';
      final hasSeen = prefs.getBool('il_diary_privacy_seen_$uid') ?? false;
      final nextValue = !hasSeen;
      if (_showDiaryPrivacyNotice == nextValue) {
        return;
      }
      _showDiaryPrivacyNotice = nextValue;
      if (!_disposed) notifyListeners();
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/diary/controllers/diary_guard_controller.dart: $error',
      );
    }
  }

  Future<void> dismissPrivacyNotice() async {
    if (!_showDiaryPrivacyNotice || _disposed) {
      return;
    }
    _showDiaryPrivacyNotice = false;
    if (!_disposed) notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _auth.currentUser?.uid ?? 'guest';
      await prefs.setBool('il_diary_privacy_seen_$uid', true);
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/diary/controllers/diary_guard_controller.dart: $error',
      );
    }
  }

  Future<bool> prepareAccessState({required String? houseId}) async {
    bool nextAuthenticated;
    try {
      final needsUnlock = await _militaryLockService.needsUnlock(
        LockScope.diary,
        houseId: houseId,
      );
      nextAuthenticated = !needsUnlock;
    } catch (_) {
      nextAuthenticated = false;
    }
    // Guard: controller có thể bị dispose trong khi await ở trên
    if (_disposed) return nextAuthenticated;

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
    bool authSuccess;
    try {
      authSuccess = await _militaryLockService.requestUnlock(
        context: context,
        scope: LockScope.diary,
        houseId: houseId,
        title: context.tr('home_nhtktnhyu_bd2683'),
        reason: MilitaryLockService.scopeReason(LockScope.diary),
      );
    } catch (_) {
      authSuccess = false;
    }

    if (_disposed) return;
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
      // Silently ensure token is fresh — handles emulator clock drift / expired
      // cached tokens without breaking the caller. Errors surface later if unresolvable.
      try {
        await currentUser.getIdToken(false).timeout(const Duration(seconds: 3));
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/home/tabs/diary/controllers/diary_guard_controller.dart: $error',
        );
      }
      return currentUser;
    }

    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return _auth.currentUser;
    }
  }

  Future<bool> ensureGalleryPermission(BuildContext context) async {
    try {
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
          disclosure: L10nService().translate(
            'diary_upload_permission_ios_desc',
          ),
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
        disclosure: L10nService().translate(
          'diary_upload_permission_android_desc',
        ),
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
    } catch (_) {
      return false;
    }
  }
}
