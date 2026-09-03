import 'dart:math';

import 'package:flutter/material.dart';
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
      barrierColor: const Color(0xFF503A43).withValues(alpha: 0.30),
      builder: (dialogContext) {
        String? errorText;

        void submit(StateSetter setDialogState) {
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

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.94),
                            width: 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9B5C71).withValues(alpha: 0.20),
                              blurRadius: 34,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _SecurityRibbon(
                                  label: l10n.translate('Bảo vệ hai bạn'),
                                ),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5EEFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 17,
                                    color: Color(0xFF846FC5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const SizedBox(
                              height: 112,
                              width: 150,
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _CaptchaGuardianPainter(),
                                ),
                              ),
                            ),
                            Text(
                              l10n.translate('Một phép tính nhỏ thôi'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4C3C43),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.translate(
                                'Giúp SoulLocket chắc chắn người đang thao tác thật sự là bạn.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8D7880),
                                height: 1.38,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _EquationCloud(n1: n1, n2: n2),
                            const SizedBox(height: 15),
                            TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => submit(setDialogState),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF5A424C),
                              ),
                              cursorColor: const Color(0xFFE56487),
                              decoration: InputDecoration(
                                hintText: l10n.translate('Nhập kết quả'),
                                hintStyle: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB39DA5),
                                ),
                                errorText: errorText == null
                                    ? null
                                    : l10n.translate(errorText!),
                                errorStyle: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFCB4767),
                                ),
                                prefixIcon: const Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: Color(0xFFE46A8B),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFFF7F7),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 15,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFF0D9DF),
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE77896),
                                    width: 1.6,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCB4767),
                                    width: 1.3,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCB4767),
                                    width: 1.6,
                                  ),
                                ),
                              ),
                              onChanged: (_) {
                                if (errorText == null) return;
                                setDialogState(() => errorText = null);
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 13,
                                  color: Color(0xFF9D8990),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    l10n.translate('Chỉ dùng để xác thực thao tác này'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Quicksand',
                                      fontSize: 9.8,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9D8990),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _CaptchaButton(
                                    label: l10n.translate('Hủy'),
                                    icon: Icons.close_rounded,
                                    primary: false,
                                    onTap: () => Navigator.of(dialogContext).pop(false),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  flex: 2,
                                  child: _CaptchaButton(
                                    label: l10n.translate('Xác nhận'),
                                    icon: Icons.favorite_rounded,
                                    primary: true,
                                    onTap: () => submit(setDialogState),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        left: -5,
                        top: 116,
                        child: _MiniDoodle(
                          icon: Icons.auto_awesome_rounded,
                          color: Color(0xFFD4A34F),
                        ),
                      ),
                      const Positioned(
                        right: -4,
                        top: 152,
                        child: _MiniDoodle(
                          icon: Icons.favorite_rounded,
                          color: Color(0xFFE788A2),
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

class _SecurityRibbon extends StatelessWidget {
  final String label;

  const _SecurityRibbon({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE7EE), Color(0xFFF1EAFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAC4D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, size: 12, color: Color(0xFFD8597B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFFC04D6D),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquationCloud extends StatelessWidget {
  final int n1;
  final int n2;

  const _EquationCloud({required this.n1, required this.n2});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3F6), Color(0xFFF6F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBDDE7)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumberBubble(text: '$n1', rose: true),
            const _MathSymbol(text: '+'),
            _NumberBubble(text: '$n2', rose: false),
            const _MathSymbol(text: '='),
            const _NumberBubble(text: '?', rose: true, question: true),
          ],
        ),
      ),
    );
  }
}

class _NumberBubble extends StatelessWidget {
  final String text;
  final bool rose;
  final bool question;

  const _NumberBubble({
    required this.text,
    required this.rose,
    this.question = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: question
            ? const Color(0xFFFFFDF9)
            : rose
                ? const Color(0xFFFFE3EB)
                : const Color(0xFFEAE3FF),
        shape: BoxShape.circle,
        border: Border.all(
          color: rose ? const Color(0xFFECA0B3) : const Color(0xFFB9A8E9),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: (rose ? const Color(0xFFE45F82) : const Color(0xFF8B73C8))
                .withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Quicksand',
          fontSize: 23,
          fontWeight: FontWeight.w900,
          color: rose ? const Color(0xFFC94F70) : const Color(0xFF725CB2),
        ),
      ),
    );
  }
}

class _MathSymbol extends StatelessWidget {
  final String text;

  const _MathSymbol({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Quicksand',
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF8C7580),
        ),
      ),
    );
  }
}

class _CaptchaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _CaptchaButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFFE65F83), Color(0xFF9A7BD3)],
                  )
                : null,
            color: primary ? null : const Color(0xFFFFF8F7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFE9DDE1),
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: const Color(0xFFE65F83).withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: primary ? Colors.white : const Color(0xFF816B73),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: primary ? Colors.white : const Color(0xFF735E66),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDoodle extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniDoodle({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}

class _CaptchaGuardianPainter extends CustomPainter {
  const _CaptchaGuardianPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.53);

    final shadow = Paint()
      ..color = const Color(0xFF9B6678).withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, size.height * 0.28),
        width: size.width * 0.54,
        height: size.height * 0.16,
      ),
      shadow,
    );

    final cloudPaint = Paint()..color = const Color(0xFFFFF2F6);
    canvas.drawCircle(Offset(center.dx - 38, center.dy + 8), 24, cloudPaint);
    canvas.drawCircle(Offset(center.dx - 12, center.dy - 4), 31, cloudPaint);
    canvas.drawCircle(Offset(center.dx + 22, center.dy + 1), 27, cloudPaint);
    canvas.drawCircle(Offset(center.dx + 43, center.dy + 13), 20, cloudPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(1, 14),
          width: 112,
          height: 42,
        ),
        const Radius.circular(20),
      ),
      cloudPaint,
    );

    final shield = Path()
      ..moveTo(center.dx, center.dy - 39)
      ..quadraticBezierTo(center.dx + 34, center.dy - 28, center.dx + 30, center.dy + 8)
      ..quadraticBezierTo(center.dx + 23, center.dy + 34, center.dx, center.dy + 47)
      ..quadraticBezierTo(center.dx - 23, center.dy + 34, center.dx - 30, center.dy + 8)
      ..quadraticBezierTo(center.dx - 34, center.dy - 28, center.dx, center.dy - 39)
      ..close();

    final shieldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE9698B), Color(0xFF9A7BD4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: center, width: 70, height: 90));
    canvas.drawPath(shield, shieldPaint);

    final inner = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(shield, inner);

    final heartCenter = center.translate(0, 5);
    final heart = Path()
      ..moveTo(heartCenter.dx, heartCenter.dy + 10)
      ..cubicTo(
        heartCenter.dx - 22,
        heartCenter.dy - 3,
        heartCenter.dx - 12,
        heartCenter.dy - 20,
        heartCenter.dx,
        heartCenter.dy - 8,
      )
      ..cubicTo(
        heartCenter.dx + 12,
        heartCenter.dy - 20,
        heartCenter.dx + 22,
        heartCenter.dy - 3,
        heartCenter.dx,
        heartCenter.dy + 10,
      );
    canvas.drawPath(heart, Paint()..color = Colors.white);

    final eyePaint = Paint()
      ..color = const Color(0xFF6A4D58)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      heartCenter.translate(-7, -1),
      heartCenter.translate(-3, 0),
      eyePaint,
    );
    canvas.drawLine(
      heartCenter.translate(3, 0),
      heartCenter.translate(7, -1),
      eyePaint,
    );

    final starPaint = Paint()
      ..color = const Color(0xFFD5A246)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final star = Offset(size.width * 0.84, size.height * 0.20);
    canvas.drawLine(star.translate(-6, 0), star.translate(6, 0), starPaint);
    canvas.drawLine(star.translate(0, -6), star.translate(0, 6), starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
