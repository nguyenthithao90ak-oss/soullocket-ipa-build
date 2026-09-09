import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../app_error_mapper.dart';
import 'consent_service.dart';
import 'error_logger_service.dart';

/// Đồng bộ lựa chọn tại thiết bị với SDK; không thay thế UMP hoặc quyền hệ điều hành.
class PrivacyCollectionService {
  static final instance = PrivacyCollectionService();

  PrivacyCollectionService({
    Future<void> Function(bool)? analytics,
    Future<void> Function(bool)? diagnostics,
  }) : _analytics = analytics ?? _applyAnalytics,
       _diagnostics =
           diagnostics ?? ErrorLoggerService.instance.setCollectionAllowed;

  final Future<void> Function(bool) _analytics;
  final Future<void> Function(bool) _diagnostics;
  Future<void> _pending = Future.value();
  bool _listening = false;
  bool? _lastApplied;
  static bool _webAnalyticsStarted = false;

  Future<void> initialize() async {
    if (!_listening) {
      ConsentService.optionalCollectionAllowed.addListener(_onChanged);
      _listening = true;
    }
    await ConsentService().refreshCollectionPermission();
    _onChanged();
    await settled;
  }

  Future<void> get settled async {
    // Một lần tắt do lỗi có thể nối thêm việc vào hàng đợi trong khi đang chờ.
    Future<void> pending;
    do {
      pending = _pending;
      await pending;
    } while (!identical(pending, _pending));
  }

  void _onChanged() {
    // Serialize để lần bật chậm không ghi đè một lần rút đồng ý đến sau.
    final requested = ConsentService.optionalCollectionAllowed.value;
    _pending = _pending.then((_) async {
      final allowed =
          requested && ConsentService.optionalCollectionAllowed.value;
      if (_lastApplied == allowed) return;
      try {
        await _analytics(
          requested && ConsentService.optionalCollectionAllowed.value,
        );
        await _diagnostics(
          requested && ConsentService.optionalCollectionAllowed.value,
        );
        // Nếu lựa chọn đổi giữa hai SDK, phải áp dụng lại lần tắt đang chờ.
        _lastApplied = allowed == ConsentService.optionalCollectionAllowed.value
            ? allowed
            : null;
      } catch (error) {
        _lastApplied = null;
        ConsentService.optionalCollectionAllowed.value = false;
        // Nếu một SDK thất bại, cố tắt cả hai; không tự coi là đã áp dụng thành công.
        debugPrint(
          'Privacy SDK settings failed: ${AppErrorMapper.resolve(error).message}',
        );
        for (final apply in [_analytics, _diagnostics]) {
          try {
            await apply(false);
          } catch (_) {
            debugPrint(
              'Privacy SDK disable failed; retry on next initialization.',
            );
          }
        }
      }
    });
  }

  static Future<void> _applyAnalytics(bool allowed) async {
    // Không tạo Analytics trên Web khi chưa đồng ý: SDK có thể tự gửi event khi tạo.
    if (kIsWeb && !_webAnalyticsStarted && !allowed) return;
    if (kIsWeb) _webAnalyticsStarted = true;
    final analytics = FirebaseAnalytics.instance;
    // Analytics consent không cấp quyền dùng dữ liệu cho quảng cáo.
    await analytics.setAnalyticsCollectionEnabled(false);
    await analytics.setConsent(
      analyticsStorageConsentGranted: allowed,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    if (allowed && ConsentService.optionalCollectionAllowed.value) {
      await analytics.setAnalyticsCollectionEnabled(true);
    } else {
      await analytics.resetAnalyticsData();
    }
  }

  @visibleForTesting
  Future<void> dispose() async {
    ConsentService.optionalCollectionAllowed.removeListener(_onChanged);
    _listening = false;
    await settled;
  }
}
