import 'dart:async';

import '../../../../../services/breakup_service.dart';
import '../../../../../services/notification_service.dart';

class RelationshipActionDescriptor {
  const RelationshipActionDescriptor({
    required this.label,
    required this.description,
    this.requiresHouseId = false,
  });

  final String label;
  final String description;
  final bool requiresHouseId;
}

class SettingsRelationshipPanelState {
  const SettingsRelationshipPanelState({
    required this.isSingle,
    required this.isCoupleConnected,
    required this.houseId,
    required this.breakupRequest,
    required this.isBreakupBusy,
  });

  final bool isSingle;
  final bool isCoupleConnected;
  final String? houseId;
  final BreakupRequestData? breakupRequest;
  final bool isBreakupBusy;

  bool get hasHouseId => (houseId ?? '').trim().isNotEmpty;
  bool get hasActiveBreakupRequest => breakupRequest?.isActive == true;
  bool get canShowQrConnect => SettingsRelationshipActions.canShowQrConnect(
        isSingle: isSingle,
        isCoupleConnected: isCoupleConnected,
        houseId: houseId,
      );
  bool get canWithdrawBreakup =>
      SettingsRelationshipActions.canWithdrawBreakup(breakupRequest);
  String get breakupPrimaryLabel =>
      SettingsRelationshipActions.breakupActionLabel(
        isSingle: isSingle,
        isBusy: isBreakupBusy,
      );
  String get breakupStatusTitle =>
      SettingsRelationshipActions.breakupStatusTitle(
        request: breakupRequest,
        isSingle: isSingle,
      );
  String get breakupStatusDescription =>
      SettingsRelationshipActions.breakupStatusDescription(
        request: breakupRequest,
        isSingle: isSingle,
      );
}

class SettingsRelationshipWatcher {
  SettingsRelationshipWatcher({BreakupService? breakupService})
      : _breakupService = breakupService ?? BreakupService();

  final BreakupService _breakupService;
  StreamSubscription<BreakupRequestData?>? _subscription;
  Timer? _deadlineTimer;

  void bind({
    required String? houseId,
    required void Function(BreakupRequestData? request) onChanged,
    BreakupRequestData? Function()? getFallbackRequest,
  }) {
    clear(onChanged: onChanged);

    final normalizedHouseId = (houseId ?? '').trim();
    if (normalizedHouseId.isEmpty) {
      return;
    }

    _subscription =
        _breakupService.streamBreakupRequest(normalizedHouseId).listen(
      (request) async {
        final nextRequest = request == null
            ? null
            : await _breakupService.evaluateBreakupRequest(normalizedHouseId);
        final effectiveRequest = nextRequest ?? request;
        _scheduleEvaluation(
          houseId: normalizedHouseId,
          request: effectiveRequest,
          onChanged: onChanged,
        );
        onChanged(effectiveRequest);
      },
      onError: (_) {
        onChanged(getFallbackRequest?.call());
      },
    );
  }

  Future<void> refresh({
    required String? houseId,
    required void Function(BreakupRequestData? request) onChanged,
    bool evaluate = true,
  }) async {
    final normalizedHouseId = (houseId ?? '').trim();
    if (normalizedHouseId.isEmpty) {
      clear(onChanged: onChanged);
      return;
    }

    final request = evaluate
        ? await _breakupService.evaluateBreakupRequest(normalizedHouseId)
        : await _breakupService.getBreakupRequest(normalizedHouseId);
    _scheduleEvaluation(
      houseId: normalizedHouseId,
      request: request,
      onChanged: onChanged,
    );
    onChanged(request);
  }

  void clear({
    required void Function(BreakupRequestData? request) onChanged,
  }) {
    dispose();
    onChanged(null);
  }

  void dispose() {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    _subscription?.cancel();
    _subscription = null;
  }

  void _scheduleEvaluation({
    required String houseId,
    required BreakupRequestData? request,
    required void Function(BreakupRequestData? request) onChanged,
  }) {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;

    if (request == null) {
      return;
    }

    var targetAt = 0;
    if (request.isPending && request.expireAt > 0) {
      targetAt = request.expireAt;
    } else if (request.isScheduled && request.deleteAt > 0) {
      targetAt = request.deleteAt;
    }
    if (targetAt <= 0) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final delayMs = (targetAt - now).clamp(0, 2147483647);
    if (delayMs == 0) {
      unawaited(
        refresh(
          houseId: houseId,
          onChanged: onChanged,
        ),
      );
      return;
    }

    _deadlineTimer = Timer(
      Duration(milliseconds: delayMs),
      () => unawaited(
        refresh(
          houseId: houseId,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class SettingsRelationshipActionRunner {
  SettingsRelationshipActionRunner({BreakupService? breakupService})
      : _breakupService = breakupService ?? BreakupService();

  final BreakupService _breakupService;

  Future<BreakupActionResult> requestBreakup({
    required String houseId,
    required String role,
    required String userName,
    required String userUid,
    required bool isSingleRelationship,
    bool pinRequired = false,
  }) async {
    final result = await _breakupService.requestBreakup(
      houseId: houseId,
      role: role,
      userName: userName,
      userUid: userUid,
      pinRequired: pinRequired,
      isSingleRelationship: isSingleRelationship,
    );

    if (!result.success) {
      return result;
    }

    await NotificationService().sendHouseNotification(
      houseId: houseId,
      title: isSingleRelationship ? 'Xóa dữ liệu nhà' : 'Yêu cầu chia tay',
      body: isSingleRelationship
          ? 'Yêu cầu xóa dữ liệu đã được khởi tạo.'
          : 'Yêu cầu chia tay đã được khởi tạo.',
    );
    return result;
  }

  Future<BreakupActionResult> withdrawBreakup({
    required String houseId,
    required String role,
    required String userName,
    String? currentUid,
  }) async {
    final result = await _breakupService.cancelBreakupRequest(
      houseId: houseId,
      role: role,
      userName: userName,
      currentUid: currentUid,
    );

    if (!result.success) {
      return result;
    }

    await NotificationService().sendHouseNotification(
      houseId: houseId,
      title: 'Rút lại yêu cầu',
      body: 'Yêu cầu chia tay / xóa dữ liệu đã được rút lại.',
    );
    return result;
  }
}

class SettingsRelationshipActions {
  const SettingsRelationshipActions._();

  static String panelDescription({
    required bool isSingle,
    required bool isCoupleConnected,
  }) {
    if (isSingle) {
      return 'Tài khoản độc thân giữ luồng một mình. Khi sẵn sàng, bạn vẫn có thể quét QR để vào chung nhà với người ấy.';
    }
    if (isCoupleConnected) {
      return 'Chế độ có người yêu đang hoạt động ổn định. Hai thiết bị có thể đăng nhập cùng một tài khoản để đồng bộ dữ liệu.';
    }
    return 'Bạn đang ở luồng có người yêu nhưng chưa đủ 2 người. App sẽ ưu tiên nhắc hoàn tất kết nối để mở đầy đủ trải nghiệm đôi.';
  }

  static String panelNote({
    required bool isSingle,
  }) {
    if (isSingle) {
      return 'Lưu ý: Độc thân là luồng trải nghiệm một mình. Nếu sau này muốn vào chung nhà, bạn có thể quét QR bất cứ lúc nào.';
    }
    return 'Lưu ý: Chế độ Có người yêu được chốt từ lúc tạo nhà. Khi chưa đủ 2 người, app sẽ ưu tiên bước kết nối trước các tính năng đôi.';
  }

  static bool canShowQrConnect({
    required bool isSingle,
    required bool isCoupleConnected,
    required String? houseId,
  }) {
    return houseId != null &&
        houseId.trim().isNotEmpty &&
        (isSingle || !isCoupleConnected);
  }

  static RelationshipActionDescriptor qrConnectAction({
    required bool isSingle,
  }) {
    return RelationshipActionDescriptor(
      label: isSingle ? 'Quét QR vào chung nhà' : 'Hoàn tất kết nối QR',
      description: isSingle
          ? 'Mở luồng vào chung nhà với người ấy.'
          : 'Hoàn tất bước ghép đôi còn thiếu.',
      requiresHouseId: true,
    );
  }

  static String breakupActionLabel({
    required bool isSingle,
    required bool isBusy,
  }) {
    if (isBusy) {
      return 'Đang xử lý yêu cầu...';
    }
    return isSingle ? 'Xóa dữ liệu nhà' : 'Chia tay / Xóa dữ liệu';
  }

  static bool canWithdrawBreakup(BreakupRequestData? request) {
    if (request == null || !request.isActive || request.isProcessing) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (request.isScheduled &&
        request.deleteAt > 0 &&
        request.deleteAt <= now) {
      return false;
    }
    return true;
  }

  static String breakupStatusTitle({
    required BreakupRequestData? request,
    required bool isSingle,
  }) {
    if (request == null || !request.isActive) {
      return '';
    }
    if (request.isProcessing) {
      return 'Đang xử lý xóa dữ liệu';
    }
    if (request.isScheduled) {
      return 'Đã lên lịch xóa dữ liệu';
    }
    return isSingle ? 'Đang chờ xóa dữ liệu' : 'Đang chờ xử lý chia tay';
  }

  static String breakupStatusDescription({
    required BreakupRequestData? request,
    required bool isSingle,
  }) {
    if (request == null || !request.isActive) {
      return '';
    }
    if (request.isProcessing) {
      return 'Hệ thống đang dọn dữ liệu và đóng nhà vĩnh viễn.';
    }
    if (request.isScheduled) {
      return 'Dữ liệu sẽ bị xóa vào ${_formatDateTime(request.deleteAt)} nếu bạn không rút lại trước hạn.';
    }
    if (isSingle) {
      return 'Tài khoản độc thân đã lên lịch xóa dữ liệu sau 3 ngày và vẫn có thể rút lại trước hạn.';
    }
    final expireLabel = request.expireAt > 0
        ? _formatDateTime(request.expireAt)
        : 'khi có thay đổi mới';
    return 'Yêu cầu đang chờ thiết bị bên kia hoặc hệ thống tự xử lý đến $expireLabel.';
  }

  static String statusLabel({
    required bool isSingle,
  }) {
    return isSingle ? 'Độc thân' : 'Đang yêu';
  }

  static String _formatDateTime(int value) {
    if (value <= 0) {
      return 'không xác định';
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(value);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} lúc $hour:$minute';
  }
}
