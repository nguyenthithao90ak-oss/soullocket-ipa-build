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
      barrierColor: const Color(0xFF3B2830).withValues(alpha: 0.22),
      builder: (dialogContext) {
        String? errorText;

        void handleSubmit(StateSetter setDialogState) {
          if (controller.text.trim() == answer) {
            Navigator.of(dialogContext).pop(true);
            return;
          }

          setDialogState(() => errorText = 'Kết quả chưa chính xác!');
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }

        Widget buildMathTile(String text, {bool highlight = true}) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: highlight
                  ? const LinearGradient(
                      colors: [Color(0xFFFFF8FA), Color(0xFFFFEAF0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF4EFFF), Color(0xFFFFF7FB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: highlight
                    ? const Color(0xFFFFB8C8)
                    : const Color(0xFFD9C9FF),
              ),
              boxShadow: [
                BoxShadow(
                  color: (highlight
                          ? const Color(0xFFE65372)
                          : const Color(0xFF8F72D8))
                      .withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                text,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: highlight
                      ? SLColors.primary
                      : const Color(0xFF7056B5),
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 22,
              ),
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 390),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFDF9),
                        Color(0xFFFFF1F5),
                        Color(0xFFF4EEFF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SLColors.primary.withValues(alpha: 0.16),
                        blurRadius: 38,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: 18,
                        top: 18,
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 18,
                          color: SLColors.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      Positioned(
                        left: 22,
                        top: 78,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: const Color(0xFF8F72D8)
                              .withValues(alpha: 0.24),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.76),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFFFB8C8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.favorite_rounded,
                                    size: 13,
                                    color: SLColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.translate('Bảo vệ hai bạn'),
                                    style: SLTheme.quicksand(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.35,
                                      color: SLColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 96,
                              height: 90,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFFEAF0)
                                          .withValues(alpha: 0.70),
                                    ),
                                  ),
                                  Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6F91),
                                          Color(0xFFE65372),
                                          Color(0xFF9A78E6),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(23),
                                      boxShadow: [
                                        BoxShadow(
                                          color: SLColors.primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.shield_rounded,
                                      size: 34,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Positioned(
                                    right: 1,
                                    top: 8,
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      size: 16,
                                      color: Color(0xFFFF89A3),
                                    ),
                                  ),
                                  const Positioned(
                                    left: 2,
                                    bottom: 10,
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 15,
                                      color: Color(0xFFFFC75E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.translate('Xác thực bảo mật'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                color: SLColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.translate(
                                'Giải phép tính nhỏ này để SoulLocket chắc chắn người đang thao tác là bạn.',
                              ),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 12.5,
                                height: 1.38,
                                fontWeight: FontWeight.w700,
                                color: SLColors.textSecond,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  width: 1.5,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    buildMathTile(n1.toString()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        '+',
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 23,
                                          color: SLColors.primary,
                                        ),
                                      ),
                                    ),
                                    buildMathTile(n2.toString()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        '=',
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 23,
                                          color: const Color(0xFF8F72D8),
                                        ),
                                      ),
                                    ),
                                    buildMathTile('?', highlight: false),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              textAlign: TextAlign.center,
                              onChanged: (_) {
                                if (errorText == null) return;
                                setDialogState(() => errorText = null);
                              },
                              onSubmitted: (_) =>
                                  handleSubmit(setDialogState),
                              style: SLTheme.quicksand(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: SLColors.textPrimary,
                              ),
                              cursorColor: SLColors.primary,
                              decoration: InputDecoration(
                                hintText: l10n.translate('Nhập kết quả'),
                                hintStyle: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: SLColors.textTertiary,
                                ),
                                errorText: errorText == null
                                    ? null
                                    : l10n.translate(errorText!),
                                errorStyle: SLTheme.quicksand(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFD9435F),
                                ),
                                prefixIcon: const Icon(
                                  Icons.calculate_rounded,
                                  color: SLColors.primary,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.92),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFFC5D2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFFC5D2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: SLColors.primary,
                                    width: 1.8,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD9435F),
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD9435F),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 14,
                                  color: SLColors.textTertiary,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    l10n.translate(
                                      'Chỉ dùng để xác thực thao tác này',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: SLTheme.quicksand(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: SLColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(dialogContext)
                                        .pop(false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: SLColors.textSecond,
                                      side: const BorderSide(
                                        color: Color(0xFFE7D8DD),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(17),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.translate('Hủy'),
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE65372),
                                          Color(0xFFFF7597),
                                          Color(0xFF9A78E6),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(17),
                                      boxShadow: [
                                        BoxShadow(
                                          color: SLColors.primary
                                              .withValues(alpha: 0.22),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          handleSubmit(setDialogState),
                                      icon: const Icon(
                                        Icons.verified_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        l10n.translate('Xác nhận'),
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(17),
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
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    return result ?? false;
  }
}
