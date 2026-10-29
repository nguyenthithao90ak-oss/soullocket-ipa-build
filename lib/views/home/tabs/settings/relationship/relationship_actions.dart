import 'dart:async';
import 'package:soullocket_app/utils/breakup_notice_copy.dart';

import '../../../../../utils/services/breakup_service.dart';
import '../../../../../utils/services/notification_service.dart';
import '../../../../../utils/services/l10n_service.dart';

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
    this.currentUid,
  });

  final bool isSingle;
  final bool isCoupleConnected;
  final String? houseId;
  final BreakupRequestData? breakupRequest;
  final bool isBreakupBusy;
  final String? currentUid;

  bool get hasHouseId => (houseId ?? '').trim().isNotEmpty;
  bool get hasActiveBreakupRequest => breakupRequest?.isActive == true;
  bool get canShowQrConnect => SettingsRelationshipActions.canShowQrConnect(
        isSingle: isSingle,
        isCoupleConnected: isCoupleConnected,
        houseId: houseId,
      );
  bool get canWithdrawBreakup =>
      SettingsRelationshipActions.canWithdrawBreakup(
        breakupRequest,
        currentUid: currentUid,
      );
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
  SettingsRelationshipWatcher({
    BreakupService? breakupService,
    Stream<BreakupRequestData?> Function(String houseId)? streamBreakupRequest,
    Future<BreakupRequestData?> Function(String houseId)? evaluateBreakupRequest,
    Future<BreakupRequestData?> Function(String houseId)? getBreakupRequest,
  }) : _breakupService = breakupService,
       _streamBreakupRequest = streamBreakupRequest,
       _evaluateBreakupRequest = evaluateBreakupRequest,
       _getBreakupRequest = getBreakupRequest;

  final BreakupService? _breakupService;
  BreakupService get _service => _breakupService ?? BreakupService();
  final Stream<BreakupRequestData?> Function(String houseId)?
  _streamBreakupRequest;
  final Future<BreakupRequestData?> Function(String houseId)?
  _evaluateBreakupRequest;
  final Future<BreakupRequestData?> Function(String houseId)? _getBreakupRequest;
  StreamSubscription<BreakupRequestData?>? _subscription;
  Timer? _deadlineTimer;
  int _generation = 0;
  int _retryAttempt = 0;
  int? _retryTargetAt;
  String? _retryHouseId;

  void bind({
    required String? houseId,
    required void Function(BreakupRequestData? request) onChanged,
    BreakupRequestData? Function()? getFallbackRequest,
  }) {
    clear(onChanged: onChanged);
    final generation = _generation;

    final normalizedHouseId = (houseId ?? '').trim();
    if (normalizedHouseId.isEmpty) {
      return;
    }

    _subscription =
        (_streamBreakupRequest?.call(normalizedHouseId) ??
                _service.streamBreakupRequest(normalizedHouseId))
            .listen(
      (request) async {
        final nextRequest = request == null
            ? null
            : await (_evaluateBreakupRequest?.call(normalizedHouseId) ??
                _service.evaluateBreakupRequest(normalizedHouseId));
        if (generation != _generation) return;
        final effectiveRequest = nextRequest ?? request;
        _scheduleEvaluation(
          houseId: normalizedHouseId,
          request: effectiveRequest,
          onChanged: onChanged,
          generation: generation,
        );
        onChanged(effectiveRequest);
      },
      onError: (_) {
        if (generation != _generation) return;
        onChanged(getFallbackRequest?.call());
      },
    );
  }

  Future<void> refresh({
    required String? houseId,
    required void Function(BreakupRequestData? request) onChanged,
    bool evaluate = true,
  }) async {
    final generation = _generation;
    final normalizedHouseId = (houseId ?? '').trim();
    if (normalizedHouseId.isEmpty) {
      clear(onChanged: onChanged);
      return;
    }

    final request = evaluate
        ? await (_evaluateBreakupRequest?.call(normalizedHouseId) ??
            _service.evaluateBreakupRequest(normalizedHouseId))
        : await (_getBreakupRequest?.call(normalizedHouseId) ??
            _service.getBreakupRequest(normalizedHouseId));
    if (generation != _generation) return;
    _scheduleEvaluation(
      houseId: normalizedHouseId,
      request: request,
      onChanged: onChanged,
      generation: generation,
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
    _generation++;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _retryAttempt = 0;
    _retryTargetAt = null;
    _retryHouseId = null;
  }

  void _scheduleEvaluation({
    required String houseId,
    required BreakupRequestData? request,
    required void Function(BreakupRequestData? request) onChanged,
    required int generation,
  }) {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;

    if (request == null) {
      _retryAttempt = 0;
      _retryTargetAt = null;
      _retryHouseId = null;
      return;
    }

    var targetAt = 0;
    if (request.isPending && request.expireAt > 0) {
      targetAt = request.expireAt;
    } else if (request.isScheduled && request.deleteAt > 0) {
      targetAt = request.deleteAt;
    }
    if (targetAt <= 0) {
      _retryAttempt = 0;
      _retryTargetAt = null;
      _retryHouseId = null;
      return;
    }

    if (_retryTargetAt != targetAt || _retryHouseId != houseId) {
      _retryAttempt = 0;
      _retryTargetAt = targetAt;
      _retryHouseId = houseId;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final delayMs = (targetAt - now).clamp(0, 2147483647);
    if (delayMs == 0) {
      // Không gọi refresh đệ quy ngay khi server vẫn trả request cũ (ví dụ
      // mạng/App Check lỗi). Backoff có trần để tránh vòng gọi nóng.
      final retrySeconds = breakupRetryDelay(_retryAttempt).inSeconds;
      _retryAttempt = (_retryAttempt + 1).clamp(0, 6);
      _deadlineTimer = Timer(Duration(seconds: retrySeconds), () {
        if (generation != _generation) return;
        unawaited(
          refresh(
            houseId: houseId,
            onChanged: onChanged,
          ),
        );
      });
      return;
    }

    _retryAttempt = 0;

    _deadlineTimer = Timer(
      Duration(milliseconds: delayMs),
      () {
        if (generation != _generation) return;
        unawaited(
          refresh(
            houseId: houseId,
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}

/// Backoff dùng cho request đã quá hạn nhưng server chưa đổi trạng thái.
/// Tách thành hàm thuần để regression test không cần khởi tạo Firebase.
Duration breakupRetryDelay(int attempt) {
  final exponent = attempt.clamp(0, 6);
  return Duration(seconds: 1 << exponent);
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
      title: isSingleRelationship
          ? L10nService().translate('home_xadliunh_bbb016')
          : L10nService().translate('home_yucuchiata_be1aa9'),
      body: isSingleRelationship
          ? L10nService().translate('home_yucuxadliu_357698')
          : L10nService().translate('home_yucuchiata_df645c'),
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
      title: L10nService().translate('home_rtliyucu_29ae92'),
      body: L10nService().translate('home_yucuchiata_742234'),
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
      return L10nService().translate('home_tikhoncthn_f0f6e1');
    }
    if (isCoupleConnected) {
      return L10nService().translate('home_chcngiyuan_5a4216');
    }
    return L10nService().translate('home_bnanglungc_13a19a');
  }

  static String panelNote({
    required bool isSingle,
  }) {
    if (isSingle) {
      return L10nService().translate('home_lucthnllun_57771d');
    }
    return L10nService().translate('home_luchcngiyu_28baaf');
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
    // Nút mở màn Ghép nối (mã mời 12 số), không còn quét "mã nhà" như trước.
    return RelationshipActionDescriptor(
      label: L10nService().translate('pairing_ui_dashboard_start_title'),
      description: L10nService().translate('pairing_ui_dashboard_subtitle'),
      requiresHouseId: true,
    );
  }

  static String breakupActionLabel({
    required bool isSingle,
    required bool isBusy,
  }) {
    if (isBusy) {
      return L10nService().translate('home_angxlyucu_0b316c');
    }
    return isSingle
        ? L10nService().translate('home_xadliunh_bbb016')
        : L10nService().translate('home_chiatayxad_3b2b07');
  }

  static bool canWithdrawBreakup(
    BreakupRequestData? request, {
    String? currentUid,
  }) {
    if (request == null || !request.isActive || request.isProcessing) {
      return false;
    }

    final uid = (currentUid ?? '').trim();
    if (uid.isEmpty || request.requestedByUid.trim() != uid) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (request.isPending && request.expireAt > 0 && request.expireAt <= now) {
      return false;
    }
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
      return L10nService().translate('home_angxlxadli_9bb5cf');
    }
    if (request.isScheduled) {
      return L10nService().translate('home_lnlchxadli_6e8028');
    }
    return isSingle
        ? L10nService().translate('home_angchxadli_e9699c')
        : L10nService().translate('home_angchxlchi_6eafab');
  }

  static String breakupStatusDescription({
    required BreakupRequestData? request,
    required bool isSingle,
  }) {
    if (request == null || !request.isActive) {
      return '';
    }
    return BreakupNoticeCopy.details(request);
  }

  static String statusLabel({
    required bool isSingle,
  }) {
    return isSingle
        ? L10nService().translate('home_cthn_4e27b8')
        : L10nService().translate('home_angyu_cea065');
  }

}
