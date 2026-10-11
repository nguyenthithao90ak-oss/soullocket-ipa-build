import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'l10n_service.dart';

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

  // Bản Android hiện chưa có phần native cho kênh này: mỗi lần gọi đều ném MissingPluginException
  // (log thành "Máy chủ đang bận"). Gặp một lần thì bỏ qua các lần gọi còn lại trong phiên.
  static bool _channelMissing = false;

  /// Hiển thị notification nếu đang bật và trên Android.
  Future<void> show({
    required String nameU1,
    required String nameU2,
    required String avatarU1,
    required String avatarU2,
    required String startDate,
  }) async {
    if (!_isAndroid || _channelMissing) return;

    final loveDaysText = _buildLoveDaysText(startDate);
    if (loveDaysText.isEmpty) return;

    try {
      await _channel.invokeMethod<bool>('showLoveStatusNotification', {
        'nameU1': nameU1.trim().isEmpty
            ? L10nService().translate('home_bnnam_123ef2')
            : nameU1.trim(),
        'nameU2': nameU2.trim().isEmpty
            ? L10nService().translate('home_bnn_babaec')
            : nameU2.trim(),
        'avatarU1': avatarU1,
        'avatarU2': avatarU2,
        'loveDaysText': loveDaysText,
      });
    } on MissingPluginException {
      _channelMissing = true;
    } catch (e) {
      debugPrint(
        '[LoveStatusNotif] show error: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  /// Ẩn notification.
  Future<void> hide() async {
    if (!_isAndroid || _channelMissing) return;
    try {
      await _channel.invokeMethod<bool>('hideLoveStatusNotification');
    } on MissingPluginException {
      _channelMissing = true;
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

  /// Tính thời gian bên nhau và định dạng bằng ngôn ngữ đang chọn.
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

      return L10nService().format('love_status_duration', {
        'years': years,
        'months': months,
        'days': days,
      });
    } catch (_) {
      return '';
    }
  }
}
