import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

/// Service hiển thị persistent notification trên thanh trạng thái Android
/// với avatar cặp đôi, tên, trái tim, và số ngày yêu.
///
/// Trên iOS/Web: tự động skip (không hỗ trợ ongoing notification).
class LoveStatusNotificationService {
  LoveStatusNotificationService._();
  static final LoveStatusNotificationService instance =
      LoveStatusNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('soul_locket/love_status_notification');

  static const String _prefKeyEnabled = 'il_love_status_notification_enabled';

  /// Hiển thị notification nếu đang bật và trên Android.
  Future<void> show({
    required String nameU1,
    required String nameU2,
    required String avatarU1,
    required String avatarU2,
    required String startDate,
  }) async {
    if (!_isAndroid) return;

    final loveDaysText = _buildLoveDaysText(startDate);
    if (loveDaysText.isEmpty) return;

    try {
      await _channel.invokeMethod<bool>('showLoveStatusNotification', {
        'nameU1': nameU1.trim().isEmpty ? 'Anh' : nameU1.trim(),
        'nameU2': nameU2.trim().isEmpty ? 'Em' : nameU2.trim(),
        'avatarU1': avatarU1,
        'avatarU2': avatarU2,
        'loveDaysText': loveDaysText,
      });
    } catch (e) {
      debugPrint(
        '[LoveStatusNotif] show error: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  /// Ẩn notification.
  Future<void> hide() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('hideLoveStatusNotification');
    } catch (e) {
      debugPrint(
        '[LoveStatusNotif] hide error: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  /// Kiểm tra pref và cập nhật notification nếu bật.
  /// Gọi sau khi load house settings xong.
  Future<void> updateIfNeeded({
    required String nameU1,
    required String nameU2,
    required String avatarU1,
    required String avatarU2,
    required String startDate,
  }) async {
    if (!_isAndroid) return;

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefKeyEnabled) ?? true;

    if (!enabled) {
      await hide();
      return;
    }

    await show(
      nameU1: nameU1,
      nameU2: nameU2,
      avatarU1: avatarU1,
      avatarU2: avatarU2,
      startDate: startDate,
    );
  }

  /// Bật/tắt notification. Lưu pref.
  Future<void> setEnabled(bool enabled) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
    if (!enabled) {
      await hide();
    }
  }

  /// Đọc trạng thái bật/tắt hiện tại.
  Future<bool> isEnabled() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? true;
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Tính text "In love for X Year Y Months Z Days" từ startDate string.
  String _buildLoveDaysText(String startDate) {
    if (startDate.trim().isEmpty) return '';
    try {
      final start = DateTime.parse(startDate.trim());
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (today.isBefore(start)) return '';

      int years = today.year - start.year;
      int months = today.month - start.month;
      int days = today.day - start.day;

      if (days < 0) {
        months--;
        final prevMonth = DateTime(today.year, today.month, 0);
        days += prevMonth.day;
      }
      if (months < 0) {
        years--;
        months += 12;
      }

      final parts = <String>[];
      if (years > 0) parts.add('$years Year${years > 1 ? 's' : ''}');
      if (months > 0) parts.add('$months Month${months > 1 ? 's' : ''}');
      if (days > 0 || parts.isEmpty) {
        parts.add('$days Day${days > 1 ? 's' : ''}');
      }

      return 'In love for ${parts.join(' ')}';
    } catch (_) {
      return '';
    }
  }
}
