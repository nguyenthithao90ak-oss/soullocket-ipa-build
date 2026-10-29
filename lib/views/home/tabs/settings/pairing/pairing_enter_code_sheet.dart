import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_settings_kit.dart';
import 'package:flutter/services.dart';

import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_cute_kit.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_invite_qr_codec.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_qr_scanner_screen.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_quick_connect_sheet.dart';

class PairingEnterCodeSheet extends StatefulWidget {
  const PairingEnterCodeSheet({super.key, this.service, this.onPaired});

  final PairingService? service;

  /// Mặc định phát âm thanh ghép nối; test truyền hàm rỗng.
  final Future<void> Function()? onPaired;

  @override
  State<PairingEnterCodeSheet> createState() => _PairingEnterCodeSheetState();
}

class _PairingEnterCodeSheetState extends State<PairingEnterCodeSheet> {
  static const _requestTimeout = Duration(seconds: 15);
  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  StreamSubscription<String>? _statusSub;

  bool _isLoading = false;
  bool _isRestoring = true;
  bool _isFinalizing = false;
  bool _pairingSoundPlayed = false;
  String? _errorMsg;
  String _status = 'input';

  PairingService get _service => widget.service ?? PairingService.instance;
  bool get _isBusy => _isLoading || _isFinalizing;
  String _t(String key) => context.tr(key);

  @override
  void initState() {
    super.initState();
    unawaited(_restoreState());
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocus.dispose();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _restoreState() async {
    try {
      final request = await _service.getMyPendingOrAcceptedRequest().timeout(
        _requestTimeout,
      );
      if (!mounted || request == null) {
        return;
      }

      final houseId = request['houseId']?.toString();
      final status = request['status']?.toString();
      if (status == 'pending') {
        setState(() => _status = 'waiting');
        _listenToStatus(houseId: houseId);
      } else if (status == 'accepted') {
        unawaited(_handleAcceptedState(houseId: houseId));
      }
    } catch (error) {
      debugPrint('[PairingEnterCode] Cannot restore request state: $error');
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Future<void> _sendRequest() async {
    if (_isLoading || _isFinalizing) {
      return;
    }
    final code = PairingInviteQrCodec.normalizeCode(_codeCtrl.text);
    if (code == null) {
      setState(() => _errorMsg = _t('pairing_ui_code_invalid'));
      _codeFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      // Service quản lý deadline 75 giây và chuẩn bị Auth/App Check.
      // Không cắt Future ghi ở UI: request trên server vẫn có thể đang chạy.
      final status = await _service.sendPairingRequest(code);
      if (!mounted) {
        return;
      }
      if (status == 'accepted') {
        // Mã đúng thì server tự chấp nhận: vào nhà luôn, không cần chờ duyệt.
        unawaited(_handleAcceptedState(code: code));
        return;
      }
      setState(() => _status = 'waiting');
      _listenToStatus(code: code);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMsg = AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('pairing_ui_request_error'),
          ).message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _listenToStatus({String? code, String? houseId}) {
    _statusSub?.cancel();
    _statusSub = _service.listenToMyRequestStatus().listen((status) {
      if (!mounted) {
        return;
      }
      switch (status) {
        case 'accepted':
          unawaited(_handleAcceptedState(code: code, houseId: houseId));
          break;
        case 'rejected':
          if (!_isFinalizing) {
            setState(() => _status = 'rejected');
          }
          break;
        case 'pending':
          if (!_isFinalizing) {
            setState(() => _status = 'waiting');
          }
          break;
        default:
          break;
      }
    });
  }

  Future<void> _handleAcceptedState({String? code, String? houseId}) async {
    if (_isFinalizing || !mounted) {
      return;
    }
    _isFinalizing = true;
    setState(() {
      _status = 'accepted';
      _errorMsg = null;
    });
    try {
      await _service.finalizeMerge(code: code, targetHouseId: houseId);
      if (!mounted) {
        return;
      }
      setState(() => _status = 'success');
      if (!_pairingSoundPlayed) {
        _pairingSoundPlayed = true;
        unawaited(
          (widget.onPaired ?? SoundService().playPaired)().catchError((
            Object error,
          ) {
            debugPrint('[PairingEnterCode] Cannot play sound: $error');
          }),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1900));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = 'input';
          _errorMsg = AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('pairing_ui_finalize_error'),
          ).message;
        });
      }
    } finally {
      _isFinalizing = false;
    }
  }

  Future<void> _cancelRequest() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _service.cancelMyRequest().timeout(_requestTimeout);
      if (mounted) {
        setState(() {
          _status = 'input';
          _errorMsg = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMsg = AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('pairing_ui_cancel_error'),
          ).message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scanCode() async {
    final code = await slPush<String>(
      context,
      const PairingQrScannerScreen(),
      fullscreenDialog: true,
    );
    if (!mounted || code == null) {
      return;
    }
    _setCode(code);
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) {
      return;
    }
    final code = PairingInviteQrCodec.normalizeCode(data?.text);
    if (code == null) {
      if (mounted) {
        setState(() => _errorMsg = _t('pairing_ui_clipboard_invalid'));
      }
      return;
    }
    _setCode(code);
  }

  void _setCode(String code) {
    _codeCtrl.value = TextEditingValue(
      text: PairingInviteQrCodec.formatCode(code),
      selection: TextSelection.collapsed(
        offset: PairingInviteQrCodec.formatCode(code).length,
      ),
    );
    setState(() => _errorMsg = null);
  }

  @override
  Widget build(BuildContext context) {
    return PairingCuteDialogFrame(
      cardKey: const ValueKey<String>('pairing-enter-card'),
      canPop: !_isBusy,
      showClose: _status != 'success',
      closeTooltip: _t('pairing_ui_close'),
      onClose: _isBusy ? null : () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _buildStateBody(),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            SLSettingsNotice(tone: SLSettingsTone.danger, message: _errorMsg!),
          ],
        ],
      ),
    );
  }

  Widget _buildStateBody() {
    if (_isRestoring) return _buildRestoringState();
    return switch (_status) {
      'waiting' => _buildWaitingState(),
      'accepted' => _buildAcceptedState(),
      'rejected' => _buildRejectedState(),
      'success' => _buildSuccessState(),
      _ => _buildInputState(),
    };
  }

  Widget _buildRestoringState() {
    return SizedBox(
      key: const ValueKey<String>('restoring'),
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: PairingCutePalette.rose),
            const SizedBox(height: 14),
            Text(
              _t('pairing_ui_loading'),
              style: SLTheme.quicksand(
                color: PairingCutePalette.plumSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputState() {
    return Column(
      key: const ValueKey<String>('input'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PairingCuteHeader(
          badge: const PairingCoupleHeartBadge(
            size: 58,
            centerIcon: Icons.qr_code_scanner_rounded,
          ),
          title: _t('pairing_ui_enter_title'),
          subtitle: _t('pairing_ui_enter_subtitle'),
        ),
        const SizedBox(height: 18),
        PairingCuteTicket(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PairingCuteTag(
                  icon: Icons.favorite_border_rounded,
                  label: _t('pairing_ui_code_label'),
                ),
              ),
              const SizedBox(height: 10),
              Semantics(
                label: _t('pairing_ui_code_label'),
                child: PairingCuteCodeField(
                  controller: _codeCtrl,
                  focusNode: _codeFocus,
                  readOnly: _isLoading,
                  hintText: _t('pairing_ui_code_hint'),
                  inputFormatters: const <TextInputFormatter>[
                    PairingCodeInputFormatter(),
                  ],
                  onSubmitted: (_) => _sendRequest(),
                  onChanged: (_) {
                    if (_errorMsg != null) {
                      setState(() => _errorMsg = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  PairingCuteChip(
                    icon: Icons.content_paste_rounded,
                    label: _t('pairing_ui_paste'),
                    onPressed: _isLoading ? null : _pasteCode,
                  ),
                  PairingCuteChip(
                    icon: Icons.qr_code_scanner_rounded,
                    label: _t('pairing_ui_scan_action'),
                    onPressed: _isLoading ? null : _scanCode,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PairingCutePillButton(
          label: _t('pairing_quick_connect_action'),
          icon: Icons.favorite_rounded,
          height: 54,
          loading: _isLoading,
          onPressed: _isLoading ? null : _sendRequest,
        ),
        const SizedBox(height: 16),
        PairingCuteNote(
          icon: Icons.shield_outlined,
          message: _t('pairing_ui_recipient_notice'),
        ),
      ],
    );
  }

  Widget _buildWaitingState() {
    return PairingCuteStatusPanel(
      key: const ValueKey<String>('waiting'),
      icon: Icons.mark_email_read_outlined,
      iconColor: PairingCutePalette.violet,
      title: _t('pairing_ui_wait_title'),
      body: _t('pairing_ui_wait_body'),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: PairingCutePalette.rose,
              ),
            ),
          ),
          const SizedBox(height: 18),
          PairingCutePillButton(
            label: _t('pairing_ui_cancel_request'),
            icon: Icons.close_rounded,
            filled: false,
            loading: _isLoading,
            onPressed: _isLoading ? null : _cancelRequest,
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedState() {
    return PairingCuteStatusPanel(
      key: const ValueKey<String>('accepted'),
      icon: Icons.sync_rounded,
      iconColor: PairingCutePalette.mintDeep,
      title: _t('pairing_ui_accepting_title'),
      body: _t('pairing_ui_accepting_body'),
      footer: const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: PairingCutePalette.mintDeep,
        ),
      ),
    );
  }

  Widget _buildRejectedState() {
    return PairingCuteStatusPanel(
      key: const ValueKey<String>('rejected'),
      icon: Icons.person_off_outlined,
      title: _t('pairing_ui_rejected_title'),
      body: _t('pairing_ui_rejected_body'),
      footer: PairingCutePillButton(
        label: _t('pairing_ui_try_again'),
        icon: Icons.refresh_rounded,
        onPressed: _isLoading
            ? null
            : () {
                setState(() {
                  _status = 'input';
                  _errorMsg = null;
                });
              },
      ),
    );
  }

  Widget _buildSuccessState() {
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('success'),
      tween: Tween<double>(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: PairingCuteStatusPanel(
        icon: Icons.favorite_rounded,
        badge: const PairingCoupleHeartBadge(size: 80, together: true),
        title: _t('pairing_ui_success_title'),
        body: _t('pairing_ui_success_body'),
        footer: const SizedBox(height: 8),
      ),
    );
  }
}
