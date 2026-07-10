import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import '../core/sl_theme.dart';
import 'services/app_lifecycle_presence_guard.dart';

class PermissionHelper {
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
    final shouldRequest =
        await _showDisclosureDialog(context, title, disclosure);

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

    final shouldRequest =
        await _showDisclosureDialog(context, title, disclosure);
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
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.whileInUse ||
        status == LocationPermission.always) {
      return true;
    }

    // Removed iOS bypass to enforce disclosure dialog on all platforms

    if (!context.mounted) return false;
    final shouldRequest = await _showDisclosureDialog(context, title, disclosure);
    if (shouldRequest != true) {
      return false;
    }

    final result = await _withLifecyclePresenceGuard(
      Geolocator.requestPermission,
    );

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
    if (!context.mounted) return false;

    // Removed iOS bypass to enforce disclosure dialog on all platforms
    final shouldRequest =
        await _showDisclosureDialog(context, title, disclosure);
    if (shouldRequest != true) {
      return false;
    }

    final result = await _withLifecyclePresenceGuard(
      Geolocator.requestPermission,
    );
    return result == LocationPermission.always;
  }

  static Future<bool?> _showDisclosureDialog(
      BuildContext context, String title, String disclosure) {
    if (!context.mounted) return Future.value(false);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5E35B1),
          ),
        ),
        content: Text(
          disclosure,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E35B1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Tiếp tục',
              style: SLTheme.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
