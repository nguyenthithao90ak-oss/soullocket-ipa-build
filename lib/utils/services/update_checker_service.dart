import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import '../resilient_http.dart';

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
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        return null;
      }

      // 1. Lấy thông tin phiên bản ứng dụng trên thiết bị
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Lấy cấu hình phiên bản (Ưu tiên R2 CDN HTTP GET -> Fallback RTDB)
      // Kiểm tra phiên bản là lớp bảo vệ bổ sung, không được giữ người dùng
      // ở màn khởi động khi CDN/RTDB đang chậm. Home vẫn có lần kiểm tra nền
      // sau đó và bản cập nhật bắt buộc vẫn được hiện ngay khi nhận được.
      final data = await _fetchAppConfigData().timeout(
        const Duration(seconds: 3),
      );

      if (data != null) {
        final latestVersion = data['latest_version']?.toString().trim() ?? '';
        if (latestVersion.isEmpty) return null;

        final configuredForceUpdate =
            data['force_update'] == true ||
            data['force_update']?.toString().toLowerCase() == 'true';
        final androidUrl =
            data['android_url']?.toString() ??
            AppConfig.androidStoreUrl;
        final iosUrl = data['ios_url']?.toString() ?? AppConfig.iOSStoreUrl;

        final needsUpdate = _shouldUpdate(currentVersion, latestVersion);
        if (needsUpdate) {
          // Bất kỳ phiên bản nào thấp hơn bản phát hành đều phải cập nhật.
          // Cờ force_update chỉ còn là cấu hình tương thích với server cũ.
          final forceUpdate = configuredForceUpdate || needsUpdate;
          final storeUrl = switch (defaultTargetPlatform) {
            TargetPlatform.android => androidUrl.trim(),
            TargetPlatform.iOS => iosUrl.trim(),
            _ => '',
          };
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

  static Future<Map<dynamic, dynamic>?> _fetchAppConfigData() async {
    // ⚡ Ưu tiên đọc qua HTTP GET từ Cloudflare R2 CDN (0đ băng thông RTDB)
    final r2Domain = AppConfig.r2PublicDomain.trim();
    if (r2Domain.isNotEmpty) {
      try {
        final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        final cdnUrl = Uri.parse(
          '${r2Domain.replaceAll(RegExp(r'/+$'), '')}/app_config.json?v=$cacheBuster',
        );
        final response = await ResilientHttp.get(cdnUrl);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            return Map<dynamic, dynamic>.from(decoded);
          }
        }
      } catch (e) {
        debugPrint('[UpdateChecker] CDN fetch skipped/fallback to RTDB: $e');
      }
    }

    // Fallback về Firebase Realtime Database nếu R2 CDN chưa có file hoặc lỗi mạng
    final dbRef = FirebaseDatabase.instance.ref('app_config');
    final snapshots = await Future.wait([
      dbRef.child('latest_version').get(),
      dbRef.child('force_update').get(),
      dbRef.child('android_url').get(),
      dbRef.child('ios_url').get(),
    ]).timeout(const Duration(seconds: 5));
    final data = <dynamic, dynamic>{
      if (snapshots[0].exists) 'latest_version': snapshots[0].value,
      if (snapshots[1].exists) 'force_update': snapshots[1].value,
      if (snapshots[2].exists) 'android_url': snapshots[2].value,
      if (snapshots[3].exists) 'ios_url': snapshots[3].value,
    };
    return data.isEmpty ? null : data;
  }

  static bool _shouldUpdate(String current, String latest) {
    try {
      final currentParts = current
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final latestParts = latest
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
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
