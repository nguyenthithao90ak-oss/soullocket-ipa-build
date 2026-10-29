import 'package:flutter/foundation.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'services/app_lifecycle_presence_guard.dart';

class LocationPermissionAccess {
  const LocationPermissionAccess(this.permission, {this.restricted = false});

  final LocationPermission permission;
  final bool restricted;

  bool get granted =>
      !restricted &&
      (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always);
  bool get blocked =>
      restricted || permission == LocationPermission.deniedForever;
}

class PermissionHelper {
  static bool _locationRequestBlocked = false;

  /// Android checkPermission không giữ deniedForever; kết hợp trạng thái OS
  /// và kết quả request vừa nhận. Chỉ đọc, không bật hộp thoại xin quyền.
  static Future<LocationPermissionAccess> checkLocationAccess() async {
    var permission = await Geolocator.checkPermission().timeout(
      const Duration(seconds: 6),
    );
    var restricted = false;
    if (!kIsWeb &&
        permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final status = await Permission.locationWhenInUse.status.timeout(
          const Duration(seconds: 3),
        );
        restricted = status.isRestricted;
        if (permission == LocationPermission.denied &&
            status.isPermanentlyDenied) {
          permission = LocationPermission.deniedForever;
        }
      } catch (_) {
        // Nền tảng không hỗ trợ: vẫn giữ kết quả từ Geolocator.
      }
    }
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _locationRequestBlocked = false;
    } else if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _locationRequestBlocked &&
        permission == LocationPermission.denied) {
      permission = LocationPermission.deniedForever;
    }
    return LocationPermissionAccess(permission, restricted: restricted);
  }

  @visibleForTesting
  static void resetLocationRequestResultForTesting() {
    _locationRequestBlocked = false;
  }

  /// Request permission (Permission Handler) with a Prominent Disclosure dialog.
  /// Returns [true] if permission is granted, [false] otherwise.
  static Future<bool> requestWithDisclosure(
    BuildContext context,
    Permission permission, {
    required String title,
    required String disclosure,
  }) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return false;
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      final result = await _withLifecyclePresenceGuard(permission.request);
      return result.isGranted || result.isLimited;
    }

    if (!context.mounted) return false;
    final shouldRequest = await _showDisclosureDialog(
      context,
      title,
      disclosure,
    );

    if (shouldRequest == true) {
      final result = await _withLifecyclePresenceGuard(permission.request);
      return result.isGranted || result.isLimited;
    }

    return false;
  }

  /// Request multiple Permission Handler permissions behind one disclosure.
  static Future<bool> requestAllWithDisclosure(
    BuildContext context,
    List<Permission> permissions, {
    required String title,
    required String disclosure,
  }) async {
    final pending = <Permission>[];

    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) {
        continue;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return false;
      }
      pending.add(permission);
    }

    if (pending.isEmpty) return true;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      for (final permission in pending) {
        final result = await _withLifecyclePresenceGuard(permission.request);
        if (!result.isGranted && !result.isLimited) {
          return false;
        }
      }
      return true;
    }

    if (!context.mounted) return false;

    final shouldRequest = await _showDisclosureDialog(
      context,
      title,
      disclosure,
    );
    if (shouldRequest != true) return false;

    for (final permission in pending) {
      final result = await _withLifecyclePresenceGuard(permission.request);
      if (!result.isGranted && !result.isLimited) {
        return false;
      }
    }

    return true;
  }

  static Future<bool> requestLocationWithDisclosure(
    BuildContext context, {
    required String title,
    required String disclosure,
  }) async {
    final access = await checkLocationAccess();
    if (access.granted) {
      return true;
    }

    if (!context.mounted) return false;
    if (access.blocked) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => SLAlertDialog(
          scrollable: true,
          title: Text(ctx.tr('map_refresh_permission_blocked')),
          content: Text(
            ctx.tr(
              access.restricted
                  ? 'map_refresh_permission_restricted_body'
                  : 'map_refresh_permission_blocked_body',
            ),
          ),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('map_refresh_not_now')),
            ),
            SLDialogAction(
              primary: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('map_refresh_open_settings')),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await _withLifecyclePresenceGuard(Geolocator.openAppSettings);
      }
      return false;
    }
    final accepted = await _showDisclosureDialog(context, title, disclosure);
    if (accepted != true || !context.mounted) return false;

    final result = await _withLifecyclePresenceGuard(
      Geolocator.requestPermission,
    );

    _locationRequestBlocked = result == LocationPermission.deniedForever;

    return result == LocationPermission.always ||
        result == LocationPermission.whileInUse;
  }

  static Future<bool> requestBackgroundLocationWithDisclosure(
    BuildContext context, {
    required String title,
    required String disclosure,
  }) async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.always) {
      return true;
    }

    final result = await _withLifecyclePresenceGuard(
      Geolocator.requestPermission,
    );
    return result == LocationPermission.always;
  }

  static Future<bool?> _showDisclosureDialog(
    BuildContext context,
    String title,
    String disclosure,
  ) {
    if (!context.mounted) return Future.value(false);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SLAlertDialog(
        scrollable: true,

        title: Text(title),
        content: Text(disclosure),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('map_refresh_not_now')),
          ),
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('map_refresh_continue')),
          ),
        ],
      ),
    );
  }

  static Future<T> _withLifecyclePresenceGuard<T>(
    Future<T> Function() action,
  ) async {
    return AppLifecyclePresenceGuard.guard(action);
  }
}
