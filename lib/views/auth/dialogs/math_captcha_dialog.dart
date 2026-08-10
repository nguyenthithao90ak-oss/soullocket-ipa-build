import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../core/fast_backdrop_filter.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

class MathCaptchaDialog {
  const MathCaptchaDialog._();

  static Future<bool> show(BuildContext context) async {
    final random = Random();
    final n1 = random.nextInt(9) + 1;
    final n2 = random.nextInt(9) + 1;
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
            errorText = 'Kết quả chưa chính xác!';
          });

          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: FastBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: -5,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section with Pattern/Gradient Background
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFF0F5).withValues(alpha: 0.8),
                              const Color(0xFFFFF7FB).withValues(alpha: 0.4),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: Column(
                          children: [
                            // Security Icon Badge
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFFFE4EC), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4081).withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.shield_rounded,
                                  size: 34,
                                  color: Color(0xFFD81B60),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              l10n.translate('Xác thực bảo mật'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                color: const Color(0xFF2C1B22),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.translate('Vui lòng giải phép toán bên dưới để tiếp tục.'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7A6B74),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(
                          children: [
                            // Math Expression Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF8FA),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFFE4EC), width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$n1',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 28,
                                      color: const Color(0xFFD81B60),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      '+',
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 24,
                                        color: const Color(0xFFFF80AB),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$n2',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 28,
                                      color: const Color(0xFFD81B60),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      '=',
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 24,
                                        color: const Color(0xFFB09BA6),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '?',
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 28,
                                      color: const Color(0xFF7A6B74),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Input Field
                            TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              textAlign: TextAlign.center,
                              onChanged: (_) {
                                if (errorText == null) return;
                                setDialogState(() => errorText = null);
                              },
                              onSubmitted: (_) => handleSubmit(setDialogState),
                              style: SLTheme.quicksand(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2C1B22),
                                letterSpacing: 2,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.translate('Nhập kết quả...'),
                                hintStyle: SLTheme.quicksand(
                                  fontSize: 15,
                                  color: const Color(0xFFB09BA6),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                                errorText: errorText == null ? null : l10n.translate(errorText!),
                                errorStyle: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFE53935),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFFFC0CB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFFFC0CB), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFFF4081), width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.translate('Hủy'),
                                      style: SLTheme.quicksand(
                                        color: const Color(0xFF8A7682),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFD81B60), Color(0xFFFF4081)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF4081).withValues(alpha: 0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => handleSubmit(setDialogState),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        l10n.translate('Xác nhận'),
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
