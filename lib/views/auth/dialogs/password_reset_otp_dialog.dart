import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../widgets/sensitive_content_guard.dart';

class PasswordResetOtpDialog {
  const PasswordResetOtpDialog._();

  static Future<bool> show({
    required BuildContext context,
    required String fullEmail,
    required String maskedEmail,
    required Future<bool> Function() onGuard,
    required Future<void> Function(String email) sendOtpEmail,
    required Future<void> Function(String otp, String newPassword) verifyCode,
  }) async {
    final canContinue = await onGuard();
    if (!canContinue) {
      return false;
    }

    if (!context.mounted) return false;

    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    var sendStarted = false;
    var isSending = true;
    var isVerifying = false;
    var isObscure = false;
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
        otpController.clear();
        newPasswordController.clear();
      });

      try {
        await sendOtpEmail(fullEmail);
        if (!dialogContext.mounted) return;
        setDialogState(() => isSending = false);
      } catch (e) {
        if (!dialogContext.mounted) return;
        setDialogState(() {
          isSending = false;
          sendError = AppErrorMapper.resolve(e).message;
        });
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (!sendStarted) {
              sendStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted) {
                  startSend(dialogContext, setDialogState);
                }
              });
            }

            final isBusy = isSending || isVerifying;
            final canConfirm = !isBusy && sendError == null;

            return SensitiveContentGuard(
              child: SLAlertDialog(
                title: Text(
                  L10nService().translate('auth_reset_password_by_code'),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSending
                            ? L10nService().format('auth_reset_sending_code', {
                                'email': maskedEmail,
                              })
                            : isVerifying
                                ? L10nService()
                                    .translate('auth_reset_checking_code')
                                : sendError != null
                                    ? L10nService().format(
                                        'auth_reset_send_error',
                                        {'error': sendError},
                                      )
                                    : verifyError != null
                                        ? L10nService().format(
                                            'auth_reset_verify_error',
                                            {'error': verifyError},
                                          )
                                        : L10nService().format(
                                            'auth_reset_code_sent',
                                            {'email': maskedEmail},
                                          ),
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: (sendError != null || verifyError != null)
                              ? Colors.red
                              : SLColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      SLSpacing.h16,
                      TextField(
                        controller: otpController,
                        enabled: canConfirm,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        onChanged: (value) {
                          if (verifyError != null) {
                            setDialogState(() => verifyError = null);
                          }
                        },
                        style: SLTheme.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                        decoration: InputDecoration(
                          labelText: L10nService().translate('home_mxcnhn_ef70d2'),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                        ),
                      ),
                      SLSpacing.h12,
                      TextField(
                        controller: newPasswordController,
                        enabled: canConfirm,
                        obscureText: isObscure,
                        onChanged: (value) {
                          if (verifyError != null) {
                            setDialogState(() => verifyError = null);
                          }
                        },
                        style: SLTheme.quicksand(),
                        decoration: InputDecoration(
                          labelText: L10nService().translate('auth_action_new_password_label'),
                          helperText: L10nService().translate('Tối thiểu 6 ký tự'),
                          border: OutlineInputBorder(
                            borderRadius: SLRadius.mdAll,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isObscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                            onPressed: canConfirm
                                ? () => setDialogState(
                                      () => isObscure = !isObscure,
                                    )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  SLDialogAction(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(L10nService().translate('core_cancel')),
                  ),
                  if (sendError != null || verifyError != null)
                    SLDialogAction(
                      onPressed: () => startSend(dialogContext, setDialogState),
                      child: Text(L10nService().translate('home_gili_11a40e')),
                    ),
                  SLDialogAction(
                    primary: true,

                    onPressed: canConfirm
                        ? () async {
                            final otp = otpController.text.trim();
                            final newPassword = newPasswordController.text;
                            if (otp.length != 6) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SLSnackBar(
                                  content: Text(
                                    L10nService().translate('home_vuilngnhp6_526103'),
                                  ),
                                ),
                              );
                              return;
                            }
                            if (newPassword.length < 6) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SLSnackBar(
                                  content: Text(
                                    L10nService().translate('auth_action_weak_password_snack'),
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isVerifying = true;
                              verifyError = null;
                            });

                            try {
                              await verifyCode(otp, newPassword);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isVerifying = false;
                                verifyError = AppErrorMapper.resolve(e).message;
                              });
                            }
                          }
                        : null,
                    child: Text(
                      isSending
                          ? L10nService().translate('home_anggi_6b22c8')
                          : isVerifying
                          ? L10nService().translate('Đang kiểm tra...')
                          : L10nService().translate('change_password'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      otpController.dispose();
      newPasswordController.dispose();
    });
    return result ?? false;
  }
}
