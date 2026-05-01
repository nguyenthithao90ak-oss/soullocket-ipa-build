import 'package:flutter/foundation.dart';

import '../../../../../services/device_manager_service.dart';

class DeviceTrustGuardState {
  const DeviceTrustGuardState({
    required this.isTrusted,
    required this.isPendingDevice,
    required this.isTrustUnavailable,
    required this.pendingMessage,
    required this.autoApproveAtMs,
  });

  const DeviceTrustGuardState.trusted()
      : isTrusted = true,
        isPendingDevice = false,
        isTrustUnavailable = false,
        pendingMessage = '',
        autoApproveAtMs = 0;

  const DeviceTrustGuardState.unavailable({
    String message =
        'Không thể xác minh độ tin cậy của thiết bị. Hãy kiểm tra mạng rồi thử lại.',
  })  : isTrusted = false,
        isPendingDevice = false,
        isTrustUnavailable = true,
        pendingMessage = message,
        autoApproveAtMs = 0;

  final bool isTrusted;
  final bool isPendingDevice;
  final bool isTrustUnavailable;
  final String pendingMessage;
  final int autoApproveAtMs;
}

class DeviceTrustGuard {
  DeviceTrustGuard({DeviceManagerService? deviceManagerService})
      : _deviceManagerService = deviceManagerService ?? DeviceManagerService();

  final DeviceManagerService _deviceManagerService;

  DeviceTrustGuardState _pendingState({
    DeviceTrustState? trustState,
    int fallbackUnlockAtMs = 0,
  }) {
    return DeviceTrustGuardState(
      isTrusted: false,
      isPendingDevice: true,
      isTrustUnavailable: false,
      pendingMessage: buildPendingMessage(
        trustState: trustState,
        fallbackUnlockAtMs: fallbackUnlockAtMs,
      ),
      autoApproveAtMs: trustState?.autoApproveAtMs ?? fallbackUnlockAtMs,
    );
  }

  String formatPendingUnlockDate(int epochMs) {
    if (epochMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} lúc $hh:$min';
  }

  String buildPendingMessage({
    DeviceTrustState? trustState,
    int fallbackUnlockAtMs = 0,
  }) {
    final unlockAtMs = trustState?.autoApproveAtMs ?? fallbackUnlockAtMs;
    final unlockLabel = formatPendingUnlockDate(unlockAtMs);
    final waitMessage = unlockLabel.isNotEmpty
        ? 'Hãy duyệt trên thiết bị tin cậy hoặc đợi đến $unlockLabel.'
        : 'Hãy duyệt trên thiết bị tin cậy. Thời điểm tự được tin cậy sẽ hiển thị ngay khi hệ thống trả về.';
    return 'Thiết bị này đang chờ duyệt nên tạm thời chưa thể chỉnh sửa Cài đặt. '
        '$waitMessage';
  }

  Future<DeviceTrustGuardState> resolve({
    bool autoApprove = true,
    int fallbackUnlockAtMs = 0,
  }) async {
    if (kIsWeb) {
      return const DeviceTrustGuardState.trusted();
    }

    try {
      // Thử lần 1 không timeout cứng để tránh false-unknown trên mạng chậm.
      final trustState = await _loadTrustStateWithRetry(autoApprove: autoApprove);

      if (trustState.isTrusted) {
        return const DeviceTrustGuardState.trusted();
      }

      if (trustState.isPendingApproval) {
        return _pendingState(
          trustState: trustState,
          fallbackUnlockAtMs: fallbackUnlockAtMs,
        );
      }

      if (trustState.isBlocked) {
        return const DeviceTrustGuardState.unavailable(
          message:
              'Thiết bị này đang bị chặn. Hãy dùng thiết bị tin cậy để mở lại quyền truy cập.',
        );
      }

      // Chỉ báo unavailable khi thực sự không đọc được trạng thái.
      if (!trustState.exists || trustState.status == 'unknown') {
        return const DeviceTrustGuardState.unavailable();
      }

      return const DeviceTrustGuardState.unavailable();
    } catch (_) {
      return const DeviceTrustGuardState.unavailable();
    }
  }

  /// Thử đọc trust state 2 lần để tránh trả về unknown do lỗi mạng thoáng qua.
  Future<DeviceTrustState> _loadTrustStateWithRetry({
    bool autoApprove = true,
  }) async {
    final first = await _deviceManagerService.getCurrentDeviceTrustState(
      autoApprove: autoApprove,
    );
    // Kết quả rõ ràng → trả về ngay.
    if (first.isTrusted || first.isPendingApproval || first.isBlocked) {
      return first;
    }
    if (first.exists && first.status != 'unknown') {
      return first;
    }
    // Lần 2 — retry khi lần đầu trả về unknown/not-exists.
    return _deviceManagerService.getCurrentDeviceTrustState(
      autoApprove: autoApprove,
    );
  }
}
