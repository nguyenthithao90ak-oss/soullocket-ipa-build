import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n_service.dart';

class UpdateCheckerService {
  static Future<void> checkUpdate(BuildContext context) async {
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
        final androidUrl = data['android_url']?.toString() ?? 'https://play.google.com/store/apps/details?id=com.soullocket.app';
        final iosUrl = data['ios_url']?.toString() ?? '';

        if (_shouldUpdate(currentVersion, latestVersion)) {
          final storeUrl = Platform.isAndroid ? androidUrl : iosUrl;
          if (storeUrl.isNotEmpty) {
            // Khắc phục lỗi BuildContext across async gaps bằng cách kiểm tra mounted
            if (!context.mounted) return;
            _showUpdateDialog(context, storeUrl, latestVersion, forceUpdate);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking app update: $e');
    }
  }

  static bool _shouldUpdate(String current, String latest) {
    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
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

  // Hàm helper dịch thuật thông minh tránh warning dead_null_aware_expression
  static String _tr(String key, String fallback) {
    final val = L10nService().translate(key);
    return val == key ? fallback : val;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String storeUrl,
    String latestVersion,
    bool forceUpdate,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return PopScope(
          canPop: !forceUpdate,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withValues(alpha: 0.6) 
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon trang trí
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF6FA3).withValues(alpha: 0.15),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.system_update_rounded,
                          color: Color(0xFFFF6FA3),
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Tiêu đề
                    Text(
                      _tr('home_cập_nhật_app', 'Cập Nhật Phiên Bản Mới'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Nội dung
                    Text(
                      'Phiên bản $latestVersion đã sẵn sàng! Vui lòng cập nhật để trải nghiệm những tính năng mới nhất và duy trì kết nối ổn định cùng người thương nhé.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.8) 
                            : Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Nút bấm hành động
                    Row(
                      children: [
                        if (!forceUpdate) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark 
                                        ? Colors.white.withValues(alpha: 0.2) 
                                        : Colors.black.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _tr('home_để_sau', 'Để sau'),
                                    style: TextStyle(
                                      fontFamily: 'Quicksand',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark 
                                          ? Colors.white.withValues(alpha: 0.7) 
                                          : Colors.black.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(storeUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF85C0), Color(0xFFFF4D94)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              child: Center(
                                child: Text(
                                  _tr('home_cập_nhật_ngay', 'Cập nhật ngay'),
                                  style: const TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
