import 'package:flutter/material.dart';

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
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                title: Text(
                  L10nService().translate('auth_reset_password_by_code'),
                  style: SLTheme.quicksand(
                    color: SLColors.primaryActive,
                    fontWeight: FontWeight.bold,
                  ),
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
                          labelText: dialogContext.tr('Mã xác nhận'),
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
                          labelText: dialogContext.tr('Mật khẩu mới'),
                          helperText: dialogContext.tr('Tối thiểu 6 ký tự'),
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
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(dialogContext.tr('Hủy'), style: SLTheme.quicksand()),
                  ),
                  if (sendError != null || verifyError != null)
                    TextButton(
                      onPressed: () => startSend(dialogContext, setDialogState),
                      child: Text(
                        'Gửi lại',
                        style: SLTheme.quicksand(
                          color: SLColors.primaryActive,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SLColors.primaryActive,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: SLRadius.smAll,
                      ),
                    ),
                    onPressed: canConfirm
                        ? () async {
                            final otp = otpController.text.trim();
                            final newPassword = newPasswordController.text;
                            if (otp.length != 6) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vui lòng nhập đủ 6 số mã xác nhận.',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (newPassword.length < 6) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mật khẩu mới phải có ít nhất 6 ký tự.',
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
                          ? 'Đang gửi...'
                          : isVerifying
                              ? 'Đang kiểm tra...'
                              : 'Đổi mật khẩu',
                      style: SLTheme.quicksand(fontWeight: FontWeight.bold),
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
