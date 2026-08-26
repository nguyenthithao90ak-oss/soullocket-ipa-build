import 'dart:math';

import 'package:flutter/material.dart';
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

        Widget buildMathNumberBox(String text, {required bool isPink}) {
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4081).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                text,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: isPink ? const Color(0xFFE91E63) : const Color(0xFF424242),
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF5F7), // Rất nhạt, gần như trắng hồng
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header Icon Area ---
                  Padding(
                    padding: const EdgeInsets.only(top: 32, bottom: 16),
                    child: SizedBox(
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Các vòng tròn lan tỏa
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFEBF1).withValues(alpha: 0.5),
                            ),
                          ),
                          Container(
                            width: 85,
                            height: 85,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFEBF1),
                            ),
                          ),
                          // Khiên 3D
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4081), Color(0xFFF50057)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4081).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.verified_user_rounded, // Khiên có dấu tick
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Trái tim bay lượn (Trái)
                          Positioned(
                            left: 20,
                            top: 40,
                            child: Icon(Icons.favorite, size: 16, color: const Color(0xFFFF80AB).withValues(alpha: 0.8)),
                          ),
                          // Trái tim bay lượn (Phải dưới)
                          Positioned(
                            right: 30,
                            bottom: 20,
                            child: Icon(Icons.favorite, size: 20, color: const Color(0xFFFF80AB).withValues(alpha: 0.6)),
                          ),
                          // Trái tim nhỏ xíu (Phải trên)
                          Positioned(
                            right: 20,
                            top: 30,
                            child: Icon(Icons.favorite, size: 12, color: const Color(0xFFFF80AB).withValues(alpha: 0.9)),
                          ),
                          // Tia sáng (Stars)
                          Positioned(
                            left: 50,
                            top: 10,
                            child: Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                          ),
                          Positioned(
                            right: 40,
                            top: 15,
                            child: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- Tiêu đề & Subtitle ---
                  Text(
                    l10n.translate('Xác thực bảo mật'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: const Color(0xFF1E1E1E),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('Vui lòng giải phép toán bên dưới để tiếp tục.'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Math Box ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F6), // Nền hồng siêu nhạt
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 2), // Viền trắng nổi khối
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4081).withValues(alpha: 0.03),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ô số 1
                          buildMathNumberBox(n1.toString(), isPink: true),
                          // Dấu +
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '+',
                              style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 24, color: const Color(0xFFFF4081)),
                            ),
                          ),
                          // Ô số 2
                          buildMathNumberBox(n2.toString(), isPink: true),
                          // Dấu =
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '=',
                              style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 24, color: const Color(0xFFFF4081)),
                            ),
                          ),
                          // Ô Dấu hỏi
                          buildMathNumberBox('?', isPink: false),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Input Field ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
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
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1E1E),
                      ),
                      cursorColor: const Color(0xFFFF4081),
                      decoration: InputDecoration(
                        errorText: errorText == null ? null : l10n.translate(errorText!),
                        errorStyle: SLTheme.quicksand(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFE53935)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFFF4081), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFFF4081), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFFF4081), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Helper Text ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.translate('Kết quả của phép tính trên'),
                        style: SLTheme.quicksand(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Buttons ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: Row(
                      children: [
                        // Hủy
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              l10n.translate('Hủy'),
                              style: SLTheme.quicksand(
                                color: const Color(0xFF757575),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Xác nhận
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4081).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () => handleSubmit(setDialogState),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.translate('Xác nhận'),
                                    style: SLTheme.quicksand(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_outline, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
