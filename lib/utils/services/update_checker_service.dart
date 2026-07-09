import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final bool needsUpdate;
  final String storeUrl;
  final String latestVersion;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.needsUpdate,
    required this.storeUrl,
    required this.latestVersion,
    required this.forceUpdate,
  });
}

class UpdateCheckerService {
  static Future<AppUpdateInfo?> checkUpdate() async {
    try {
      // 1. Lấy thông tin phiên bản ứng dụng trên thiết bị
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Lấy cấu hình phiên bản từ Firebase Realtime Database
      final dbRef = FirebaseDatabase.instance.ref('app_config');
      final event = await dbRef.once().timeout(const Duration(seconds: 5));
      final rawData = event.snapshot.value;

      if (rawData is Map) {
        final data = Map<dynamic, dynamic>.from(rawData);
        final latestVersion = data['latest_version']?.toString() ?? '1.0.0';
        final forceUpdate = data['force_update'] == true;
        final androidUrl = data['android_url']?.toString() ??
            'https://play.google.com/store/apps/details?id=com.soullocket.app';
        final iosUrl = data['ios_url']?.toString() ?? '';

        if (_shouldUpdate(currentVersion, latestVersion)) {
          final storeUrl = Platform.isAndroid ? androidUrl : iosUrl;
          if (storeUrl.isNotEmpty) {
            return AppUpdateInfo(
              needsUpdate: true,
              storeUrl: storeUrl,
              latestVersion: latestVersion,
              forceUpdate: forceUpdate,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking app update: $e');
    }
    return null;
  }

  static bool _shouldUpdate(String current, String latest) {
    try {
      final currentParts =
          current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts =
          latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final length = math.max(currentParts.length, latestParts.length);
      for (int i = 0; i < length; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final latestPart = i < latestParts.length ? latestParts[i] : 0;
        if (latestPart > currentPart) return true;
        if (currentPart > latestPart) return false;
      }
    } catch (_) {
      return current != latest;
    }
    return false;
  }
}
