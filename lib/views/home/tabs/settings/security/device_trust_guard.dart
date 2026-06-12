import 'package:flutter/foundation.dart';

import '../../../../../services/device_manager_service.dart';
import '../../../../../utils/services/l10n_service.dart';

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

  DeviceTrustGuardState.unavailable({
    String? message,
  })  : isTrusted = false,
        isPendingDevice = false,
        isTrustUnavailable = true,
        pendingMessage = message ?? L10nService().translate('home_khngthxcmi_2b9511'),
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
        : L10nService().translate('home_hyduyttrnt_a5b595');
    return '${L10nService().translate('home_thitbnyang_707b26')}$waitMessage';
  }

  Future<DeviceTrustGuardState> resolve({
    bool autoApprove = true,
    int fallbackUnlockAtMs = 0,
  }) async {
    if (kIsWeb) {
      return const DeviceTrustGuardState.trusted();
    }

    try {
      final trustState = await _deviceManagerService
          .getCurrentDeviceTrustState(autoApprove: autoApprove)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => const DeviceTrustState(
              houseId: '',
              deviceId: 'unknown',
              status: 'unknown',
              firstSeenAtMs: 0,
              autoApproveAtMs: 0,
              exists: false,
              isAdmin: false,
            ),
          );

      if (trustState.isTrusted) {
        return const DeviceTrustGuardState.trusted();
      }

      if (trustState.status == 'pending') {
        return _pendingState(
          trustState: trustState,
          fallbackUnlockAtMs: fallbackUnlockAtMs,
        );
      }

      if (trustState.isBlocked) {
        return DeviceTrustGuardState.unavailable(
          message:
              L10nService().translate('home_thitbnyang_23704c'),
        );
      }

      if (!trustState.exists || trustState.status == 'unknown') {
        return DeviceTrustGuardState.unavailable();
      }

      return DeviceTrustGuardState.unavailable();
    } catch (_) {
      return DeviceTrustGuardState.unavailable();
    }
  }
}
