import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/app_error_mapper.dart';
import '../../../../../widgets/sensitive_content_guard.dart';

Future<bool> showSettingsEmailOtpDialog({
  required BuildContext context,
  required String title,
  required String email,
  required Future<void> Function() sendCode,
  required Future<void> Function(String otp) verifyCode,
}) async {
  final otpCtrl = TextEditingController();
  var sendStarted = false;
  var isSending = true;
  var isVerifying = false;
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
                  .clamp(240.0, mediaQuery.size.height)
                  .toDouble();
          final maxContentHeight =
              (maxDialogHeight - 180).clamp(120.0, 320.0).toDouble();

          return SensitiveContentGuard(
            child: AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                title,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD81B60),
                ),
              ),
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
                        isSending
                            ? 'Đang gửi mã OTP tới $email.'
                            : isVerifying
                                ? context.tr('home_angkimtram_f1186f')
                                : sendError != null
                                    ? 'Không gửi được mã:\n$sendError'
                                    : verifyError != null
                                        ? 'Mã không hợp lệ:\n$verifyError'
                                        : context.tr('home_nhpm6stipt_fc04d6'),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: (sendError != null || verifyError != null)
                              ? Colors.red
                              : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: otpCtrl,
                        enabled: canConfirm,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        onChanged: (_) {
                          if (verifyError != null) {
                            setDialogState(() => verifyError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: context.tr('home_mxcnhn_ef70d2'),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('home_hy_1e4050')),
                ),
                ElevatedButton(
                  onPressed: canConfirm
                      ? () async {
                          final otp = otpCtrl.text.trim();
                          if (otp.length != 6) return;
                          setDialogState(() {
                            isVerifying = true;
                            verifyError = null;
                          });
                          try {
                            await verifyCode(otp);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (error) {
                            if (ctx.mounted) {
                              setDialogState(() {
                                isVerifying = false;
                                verifyError = AppErrorMapper.resolve(error).message;
                              });
                            }
                          }
                        }
                      : null,
                  child: Text(
                    isSending
                        ? context.tr('home_anggi_6b22c8')
                        : isVerifying
                            ? context.tr('home_angkimtra_92e8dd')
                            : context.tr('home_xcnhn_1e2eb2'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  otpCtrl.dispose();
  return result ?? false;
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
          final maxContentHeight =
              (maxDialogHeight - 180).clamp(140.0, 360.0).toDouble();

          return SensitiveContentGuard(
            child: AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              scrollable: true,
              title: Text(
                context.tr('home_tlimtkhu_2896d3'),
                style: SLTheme.quicksand(fontWeight: FontWeight.bold),
              ),
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
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: context.tr('home_mxcnhn_ef70d2'),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        enabled: canConfirm,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: context.tr('home_mtkhumi_ccef95'),
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
                        Text(
                          sendError ?? verifyError ?? '',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('home_hy_1e4050')),
                ),
                ElevatedButton(
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
                                verifyError = AppErrorMapper.resolve(error).message;
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

  otpCtrl.dispose();
  passwordCtrl.dispose();
  return result ?? false;
}
