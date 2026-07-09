import 'dart:async';

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
    return RelationshipActionDescriptor(
      label: isSingle
          ? L10nService().translate('home_qutqrvochu_d848a8')
          : L10nService().translate('home_honttktniq_937193'),
      description: isSingle
          ? L10nService().translate('home_mlungvochu_aabe86')
          : L10nService().translate('home_honttbcghp_90b64c'),
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
    if (request.isProcessing) {
      return L10nService().translate('home_hthngangdn_fae73f');
    }
    if (request.isScheduled) {
      return 'Dữ liệu sẽ bị xóa vào ${_formatDateTime(request.deleteAt)} nếu bạn không rút lại trước hạn.';
    }
    if (isSingle) {
      return L10nService().translate('home_tikhoncthn_7650c0');
    }
    final expireLabel = request.expireAt > 0
        ? _formatDateTime(request.expireAt)
        : L10nService().translate('home_khicthayim_65b886');
    return 'Yêu cầu đang chờ thiết bị bên kia hoặc hệ thống tự xử lý đến $expireLabel.';
  }

  static String statusLabel({
    required bool isSingle,
  }) {
    return isSingle
        ? L10nService().translate('home_cthn_4e27b8')
        : L10nService().translate('home_angyu_cea065');
  }

  static String _formatDateTime(int value) {
    if (value <= 0) {
      return L10nService().translate('home_khngxcnh_fb806e');
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(value);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} lúc $hour:$minute';
  }
}
