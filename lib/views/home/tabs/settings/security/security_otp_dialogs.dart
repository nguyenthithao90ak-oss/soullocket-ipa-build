import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../widgets/sensitive_content_guard.dart';
import '../../../../../widgets/sl_settings_kit.dart';

TextStyle get _otpTextStyle => SLTheme.quicksand(
  fontSize: 20,
  fontWeight: FontWeight.w800,
  letterSpacing: 6,
  color: SLSettingsColors.ink,
);

Future<bool> showSettingsEmailOtpDialog({
  required BuildContext context,
  required String title,
  required String email,
  required Future<void> Function() sendCode,
  required Future<void> Function(String otp) verifyCode,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SettingsEmailOtpDialog(
        title: title,
        email: email,
        sendCode: sendCode,
        verifyCode: verifyCode,
      ),
    ) ??
    false;

class _SettingsEmailOtpDialog extends StatefulWidget {
  const _SettingsEmailOtpDialog({
    required this.title,
    required this.email,
    required this.sendCode,
    required this.verifyCode,
  });

  final String title;
  final String email;
  final Future<void> Function() sendCode;
  final Future<void> Function(String otp) verifyCode;

  @override
  State<_SettingsEmailOtpDialog> createState() =>
      _SettingsEmailOtpDialogState();
}

class _SettingsEmailOtpDialogState extends State<_SettingsEmailOtpDialog> {
  final _otpCtrl = TextEditingController();
  Timer? _resendTimer;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _closed = false;
  int _resendSeconds = 0;
  String? _sendError;
  String? _verifyError;

  bool get _active => mounted && !_closed;
  bool get _busy => _isSending || _isVerifying;
  bool get _canConfirm => !_busy && _otpCtrl.text.trim().length == 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active) unawaited(_send());
    });
  }

  Future<void> _send() async {
    if (!_active || _busy || _resendSeconds > 0) return;
    setState(() {
      _isSending = true;
      _sendError = null;
      _verifyError = null;
      _otpCtrl.clear();
    });
    String? failure;
    try {
      await widget.sendCode();
    } catch (error) {
      failure = AppErrorMapper.resolve(error).message;
    }
    if (!_active) return;
    setState(() {
      _isSending = false;
      _sendError = failure;
      _resendSeconds = 60;
    });
    // Không tự gửi lại sau timeout: thư cũ có thể vẫn đến. Chờ đủ cooldown
    // trước lần gửi tiếp theo để không thay mã hoặc tiêu quota liên tục.
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_active) {
        timer.cancel();
        return;
      }
      final remaining = (60 - timer.tick).clamp(0, 60);
      setState(() => _resendSeconds = remaining);
      if (remaining == 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _verify() async {
    if (!_active || !_canConfirm) return;
    final otp = _otpCtrl.text.trim();
    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });
    try {
      await widget.verifyCode(otp);
      if (_active) _close(true);
    } catch (error) {
      if (!_active) return;
      setState(() {
        _isVerifying = false;
        _verifyError = AppErrorMapper.resolve(error).message;
      });
    }
  }

  void _close(bool result) {
    if (!_active) return;
    _closed = true;
    _resendTimer?.cancel();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _closed = true;
    _resendTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final message = _isSending
        ? l10n.format('ui_home_sending_otp_code_to_value1_3b4e18', {
            'value1': widget.email,
          })
        : _isVerifying
        ? context.tr('home_angkimtram_f1186f')
        : _verifyError ??
              _sendError ??
              l10n.format('home_otp_sent_to_email', {'email': widget.email});
    final hasError = _sendError != null || _verifyError != null;
    final mediaQuery = MediaQuery.of(context);
    final maxDialogHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 48)
            .clamp(240.0, mediaQuery.size.height)
            .toDouble();
    final maxContentHeight = (maxDialogHeight - 180)
        .clamp(120.0, 320.0)
        .toDouble();

    return PopScope<bool>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _closed = true;
          _resendTimer?.cancel();
        }
      },
      child: SensitiveContentGuard(
        child: SLAlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          scrollable: true,
          title: Text(widget.title),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: maxContentHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: hasError
                          ? SLSettingsColors.danger
                          : SLSettingsColors.ink,
                      height: 1.35,
                    ),
                  ),
                  if (!_busy) ...[
                    const SizedBox(height: 8),
                    Text(context.tr('home_nhpm6stipt_fc04d6')),
                  ],
                  const SizedBox(height: 16),
                  // Kết quả gửi bị timeout vẫn cho nhập mã đã nhận. Server tiếp
                  // tục xác minh OTP và cấp proof trước mọi yêu cầu xóa.
                  TextField(
                    controller: _otpCtrl,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() => _verifyError = null),
                    onSubmitted: (_) => unawaited(_verify()),
                    style: _otpTextStyle,
                    decoration: slSettingsInputDecoration(
                      label: context.tr('home_mxcnhn_ef70d2'),
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('settings-email-otp-resend'),
                    onPressed: !_busy && _resendSeconds == 0 ? _send : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(
                      _resendSeconds > 0
                          ? l10n.format('settings_email_retry_in', {
                              'seconds': _resendSeconds,
                            })
                          : context.tr('forgot_pwd_btn_resend_otp'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SLDialogAction(
              onPressed: () => _close(false),
              child: Text(context.tr('home_hy_1e4050')),
            ),
            SLDialogAction(
              primary: true,
              onPressed: _canConfirm ? _verify : null,
              child: Text(
                _isSending
                    ? context.tr('home_anggi_6b22c8')
                    : _isVerifying
                    ? context.tr('home_angkimtra_92e8dd')
                    : context.tr('home_xcnhn_1e2eb2'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showSettingsPasswordResetOtpDialog({
  required BuildContext context,
  required String email,
  required Future<void> Function() sendCode,
  required Future<void> Function(String otp, String newPassword) verifyCode,
}) async {
  final otpCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  var sendStarted = false;
  var isSending = true;
  var isVerifying = false;
  var obscure = true;
  String? sendError;
  String? verifyError;

  Future<void> startSend(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    setDialogState(() {
      isSending = true;
      sendError = null;
      verifyError = null;
      otpCtrl.clear();
      passwordCtrl.clear();
    });

    try {
      await sendCode();
      if (!dialogContext.mounted) return;
      setDialogState(() => isSending = false);
    } catch (error) {
      if (!dialogContext.mounted) return;
      setDialogState(() {
        isSending = false;
        sendError = AppErrorMapper.resolve(error).message;
      });
    }
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!sendStarted) {
            sendStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) {
                startSend(ctx, setDialogState);
              }
            });
          }

          final isBusy = isSending || isVerifying;
          final canConfirm = !isBusy && sendError == null;
          final mediaQuery = MediaQuery.of(ctx);
          final maxDialogHeight =
              (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 48)
                  .clamp(260.0, mediaQuery.size.height)
                  .toDouble();
          final maxContentHeight = (maxDialogHeight - 180)
              .clamp(140.0, 360.0)
              .toDouble();

          return SensitiveContentGuard(
            child: SLAlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              scrollable: true,
              title: Text(context.tr('home_tlimtkhu_2896d3')),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: maxContentHeight,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: otpCtrl,
                        enabled: canConfirm,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,
                        style: _otpTextStyle,
                        decoration: slSettingsInputDecoration(
                          label: context.tr('home_mxcnhn_ef70d2'),
                        ).copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        enabled: canConfirm,
                        obscureText: obscure,
                        style: slSettingsInputTextStyle(),
                        decoration: slSettingsInputDecoration(
                          label: context.tr('home_mtkhumi_ccef95'),
                          suffixIcon: IconButton(
                            onPressed: canConfirm
                                ? () => setDialogState(() => obscure = !obscure)
                                : null,
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (sendError != null || verifyError != null) ...[
                        const SizedBox(height: 12),
                        SLSettingsNotice(
                          tone: SLSettingsTone.danger,
                          message: sendError ?? verifyError ?? '',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                SLDialogAction(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('home_hy_1e4050')),
                ),
                SLDialogAction(
                  primary: true,

                  onPressed: canConfirm
                      ? () async {
                          final otp = otpCtrl.text.trim();
                          final newPassword = passwordCtrl.text;
                          if (otp.length != 6 || newPassword.length < 6) {
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            verifyError = null;
                          });
                          try {
                            await verifyCode(otp, newPassword);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (error) {
                            if (ctx.mounted) {
                              setDialogState(() {
                                isVerifying = false;
                                verifyError =
                                    AppErrorMapper.resolve(error).message;
                              });
                            }
                          }
                        }
                      : null,
                  child: Text(
                    isSending
                        ? context.tr('home_anggi_6b22c8')
                        : isVerifying
                            ? context.tr('home_angi_b39515')
                            : context.tr('home_cpnht_3b7db4'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  Future.delayed(const Duration(milliseconds: 300), () {
    otpCtrl.dispose();
    passwordCtrl.dispose();
  });
  return result ?? false;
}
