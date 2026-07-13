import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

class MathCaptchaDialog {
  const MathCaptchaDialog._();

  static Future<bool> show(BuildContext context) async {
    final random = Random();
    final n1 = random.nextInt(10) + 1;
    final n2 = random.nextInt(10) + 1;
    final answer = (n1 + n2).toString();
    final controller = TextEditingController();
    final l10n = L10nService();

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;

        void handleSubmit(StateSetter setDialogState) {
          if (controller.text.trim() == answer) {
            Navigator.of(dialogContext).pop(true);
            return;
          }

          setDialogState(() {
            errorText = 'Xác thực không chính xác!';
          });

          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              l10n.translate('Xác thực Captcha'),
              style: SLTheme.quicksand(
                color: SLColors.danger,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('auth_msg_prove_not_robot'),
                    style: SLTheme.quicksand(),
                  ),
                  SLSpacing.h8,
                  Text(
                    '$n1 + $n2 = ?',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: SLColors.textSecond,
                    ),
                  ),
                  SLSpacing.h16,
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (errorText == null) return;
                      setDialogState(() => errorText = null);
                    },
                    onSubmitted: (_) => handleSubmit(setDialogState),
                    style: SLTheme.quicksand(),
                    decoration: InputDecoration(
                      hintText: l10n.translate('Nhập kết quả'),
                      hintStyle: SLTheme.quicksand(fontSize: 14),
                      errorText:
                          errorText == null ? null : l10n.translate(errorText!),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: SLRadius.smAll,
                        borderSide: const BorderSide(color: SLColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: SLRadius.smAll,
                        borderSide: const BorderSide(color: SLColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: SLRadius.smAll,
                        borderSide:
                            const BorderSide(color: SLColors.danger, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: SLRadius.smAll,
                        borderSide: const BorderSide(
                            color: SLColors.danger, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: SLRadius.smAll,
                        borderSide:
                            const BorderSide(color: SLColors.danger, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  l10n.translate('Hủy'),
                  style: SLTheme.quicksand(
                    color: SLColors.textSecond,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => handleSubmit(setDialogState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SLColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: SLRadius.smAll),
                ),
                child: Text(
                  l10n.translate('Xác nhận'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      controller.dispose();
    });
    return result ?? false;
  }
}
