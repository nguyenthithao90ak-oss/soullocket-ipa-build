import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_invite_qr_codec.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_qr_scanner_screen.dart';

class PairingEnterCodeSheet extends StatefulWidget {
  const PairingEnterCodeSheet({super.key});

  @override
  State<PairingEnterCodeSheet> createState() => _PairingEnterCodeSheetState();
}

class _PairingEnterCodeSheetState extends State<PairingEnterCodeSheet> {
  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  StreamSubscription<String>? _statusSub;

  bool _isLoading = false;
  bool _isRestoring = true;
  bool _isFinalizing = false;
  String? _errorMsg;
  String _status = 'input';

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
      final request = await PairingService.instance
          .getMyPendingOrAcceptedRequest();
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
      await PairingService.instance.sendPairingRequest(code);
      if (!mounted) {
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
    _statusSub = PairingService.instance.listenToMyRequestStatus().listen((
      status,
    ) {
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
      await PairingService.instance.finalizeMerge(
        code: code,
        targetHouseId: houseId,
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = 'success');
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
    if (_isLoading) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await PairingService.instance.cancelMyRequest();
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
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const PairingQrScannerScreen(),
        fullscreenDialog: true,
      ),
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFCFAF9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              24,
              10,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SLColors.ink.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isRestoring) _buildRestoringState(),
                    if (!_isRestoring && _status == 'input') _buildInputState(),
                    if (!_isRestoring && _status == 'waiting')
                      _buildWaitingState(),
                    if (!_isRestoring && _status == 'accepted')
                      _buildAcceptedState(),
                    if (!_isRestoring && _status == 'rejected')
                      _buildRejectedState(),
                    if (!_isRestoring && _status == 'success')
                      _buildSuccessState(),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      _EntryErrorNotice(message: _errorMsg!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestoringState() {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: SLColors.primary),
            const SizedBox(height: 14),
            Text(
              _t('pairing_ui_loading'),
              style: SLTheme.quicksand(
                color: SLColors.textSecond,
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
        _buildHeader(
          icon: Icons.qr_code_scanner_rounded,
          title: _t('pairing_ui_enter_title'),
          subtitle: _t('pairing_ui_enter_subtitle'),
        ),
        const SizedBox(height: 16),
        _buildRecipientNotice(),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _scanCode,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: const Color(0xFFB9516D),
            side: const BorderSide(color: Color(0xFFEACDD5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 21),
          label: Text(
            _t('pairing_ui_scan_action'),
            style: SLTheme.quicksand(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                _t('pairing_ui_code_label'),
                style: SLTheme.quicksand(
                  color: SLColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _isLoading ? null : _pasteCode,
              icon: const Icon(Icons.content_paste_rounded, size: 15),
              label: Text(
                _t('pairing_ui_paste'),
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB9516D),
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
        Semantics(
          label: _t('pairing_ui_code_label'),
          child: TextField(
            controller: _codeCtrl,
            focusNode: _codeFocus,
            readOnly: _isLoading,
            autofocus: false,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendRequest(),
            onChanged: (_) {
              if (_errorMsg != null) {
                setState(() => _errorMsg = null);
              }
            },
            inputFormatters: const <TextInputFormatter>[
              _PairingCodeInputFormatter(),
            ],
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: SLColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
            decoration: InputDecoration(
              hintText: _t('pairing_ui_code_hint'),
              hintStyle: SLTheme.quicksand(
                color: SLColors.textTertiary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.6,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFFE8DDDC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: Color(0xFFB9516D),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _isLoading ? null : _sendRequest,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFFB9516D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : const Icon(Icons.arrow_forward_rounded, size: 19),
          label: Text(
            _t('pairing_ui_request_action'),
            style: SLTheme.quicksand(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFCEDF0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFB9516D), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: SLTheme.quicksand(
                  color: SLColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: _t('pairing_ui_close'),
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close_rounded,
                color: SLColors.textSecond,
                size: 21,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: SLTheme.quicksand(
            color: SLColors.textSecond,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF714352), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t('pairing_ui_recipient_notice'),
              style: SLTheme.quicksand(
                color: SLColors.textSecond,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return _StatusPanel(
      key: const ValueKey<String>('waiting'),
      icon: Icons.mark_email_read_outlined,
      iconColor: const Color(0xFF714352),
      title: _t('pairing_ui_wait_title'),
      body: _t('pairing_ui_wait_body'),
      footer: Column(
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: Color(0xFF714352),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _isLoading ? null : _cancelRequest,
            style: OutlinedButton.styleFrom(
              foregroundColor: SLColors.textSecond,
              side: const BorderSide(color: SLColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              _t('pairing_ui_cancel_request'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(
              _t('pairing_ui_close'),
              style: SLTheme.quicksand(
                color: SLColors.textSecond,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedState() {
    return _StatusPanel(
      key: const ValueKey<String>('accepted'),
      icon: Icons.sync_rounded,
      iconColor: const Color(0xFF4C9A79),
      title: _t('pairing_ui_accepting_title'),
      body: _t('pairing_ui_accepting_body'),
      footer: const Padding(
        padding: EdgeInsets.only(top: 8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF4C9A79),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedState() {
    return _StatusPanel(
      key: const ValueKey<String>('rejected'),
      icon: Icons.person_off_outlined,
      iconColor: const Color(0xFFC9576E),
      title: _t('pairing_ui_rejected_title'),
      body: _t('pairing_ui_rejected_body'),
      footer: FilledButton(
        onPressed: _isLoading
            ? null
            : () {
                setState(() {
                  _status = 'input';
                  _errorMsg = null;
                });
              },
        style: FilledButton.styleFrom(
          backgroundColor: SLColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _t('pairing_ui_try_again'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w800),
        ),
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
      child: _StatusPanel(
        icon: Icons.favorite_rounded,
        iconColor: SLColors.primary,
        title: _t('pairing_ui_success_title'),
        body: _t('pairing_ui_success_body'),
        footer: const SizedBox.shrink(),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.footer,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
      decoration: BoxDecoration(
        color: SLColors.bgSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SLColors.borderLight),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 31),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: SLColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: SLColors.textSecond,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          footer,
        ],
      ),
    );
  }
}

class _EntryErrorNotice extends StatelessWidget {
  const _EntryErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SLColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SLColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: SLColors.danger,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: SLTheme.quicksand(
                color: const Color(0xFF9A344C),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingCodeInputFormatter extends TextInputFormatter {
  const _PairingCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > PairingInviteQrCodec.codeLength
        ? digits.substring(0, PairingInviteQrCodec.codeLength)
        : digits;
    final grouped = StringBuffer();
    for (var index = 0; index < limited.length; index++) {
      if (index > 0 && index % 4 == 0) {
        grouped.write('-');
      }
      grouped.write(limited[index]);
    }

    final text = grouped.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
