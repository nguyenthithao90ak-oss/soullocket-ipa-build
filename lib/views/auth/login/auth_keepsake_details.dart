import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'auth_visual_style.dart';

/// Sticker vector tĩnh: nét luôn rõ ở Android/Web và không tải thêm ảnh mạng.
class AuthKeepsakeSticker extends StatelessWidget {
  const AuthKeepsakeSticker({
    super.key,
    this.size = 130,
    this.recovery = false,
  });
  final double size;
  final bool recovery;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _KeepsakeStickerPainter(
            dark: AuthVisualStyle.of(context).dark,
            recovery: recovery,
          ),
        ),
      ),
    ),
  );
}

class _KeepsakeStickerPainter extends CustomPainter {
  const _KeepsakeStickerPainter({required this.dark, required this.recovery});
  final bool dark;
  final bool recovery;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);
    final rose = dark ? const Color(0xFFEFADC2) : const Color(0xFFAD3D60);
    final outline = dark ? const Color(0xFF805D6C) : const Color(0xFFDCA4B7);
    final paper = dark ? const Color(0xFF44313D) : const Color(0xFFFFFDFA);
    final blush = dark ? const Color(0xFF6D4053) : const Color(0xFFF5CFDD);
    final fill = Paint();
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void heart(double x, double y, double scale, Color color) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      final shape = Path()
        ..moveTo(0, 5)
        ..cubicTo(-16, -5, -12, -16, -5, -13)
        ..quadraticBezierTo(-1, -12, 0, -8)
        ..cubicTo(7, -22, 24, -7, 0, 5)
        ..close();
      canvas.drawPath(shape, fill..color = color);
      canvas.restore();
    }

    void star(double x, double y, double r) {
      final shape = Path()
        ..moveTo(x, y - r)
        ..quadraticBezierTo(x + 2, y - 2, x + r, y)
        ..quadraticBezierTo(x + 2, y + 2, x, y + r)
        ..quadraticBezierTo(x - 2, y + 2, x - r, y)
        ..quadraticBezierTo(x - 2, y - 2, x, y - r)
        ..close();
      canvas.drawPath(shape, fill..color = const Color(0xFFC8A16C));
    }

    canvas.drawCircle(
      const Offset(80, 84),
      64,
      fill..color = blush.withValues(alpha: .25),
    );
    canvas.drawOval(
      const Rect.fromLTWH(36, 133, 93, 11),
      fill..color = rose.withValues(alpha: .08),
    );
    star(133, 38, 9);
    star(23, 106, 7);
    heart(27, 42, .65, blush);
    canvas.drawCircle(const Offset(140, 105), 3, fill..color = outline);
    canvas.save();
    canvas.translate(80, 86);
    canvas.rotate(recovery ? .08 : -.10);
    canvas.translate(-80, -86);
    if (recovery) {
      final shackle = RRect.fromRectAndRadius(
        const Rect.fromLTWH(57, 30, 47, 61),
        const Radius.circular(24),
      );
      canvas.drawRRect(
        shackle,
        pen
          ..color = paper
          ..strokeWidth = 13,
      );
      canvas.drawRRect(
        shackle,
        pen
          ..color = outline
          ..strokeWidth = 2,
      );
      final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 65, 85, 70),
        const Radius.circular(23),
      );
      canvas.drawRRect(body.inflate(5), fill..color = paper);
      canvas.drawRRect(body, fill..color = blush);
      canvas.drawRRect(
        body,
        pen
          ..color = outline
          ..strokeWidth = 2,
      );
      heart(80, 101, 1, rose);
      canvas.drawLine(
        const Offset(80, 102),
        const Offset(80, 114),
        pen
          ..color = rose
          ..strokeWidth = 4,
      );
      canvas.drawArc(
        const Rect.fromLTWH(52, 112, 12, 7),
        0,
        math.pi,
        false,
        pen
          ..color = rose
          ..strokeWidth = 1.8,
      );
      canvas.drawArc(
        const Rect.fromLTWH(96, 112, 12, 7),
        0,
        math.pi,
        false,
        pen,
      );
    } else {
      final note = RRect.fromRectAndRadius(
        const Rect.fromLTWH(43, 34, 74, 84),
        const Radius.circular(12),
      );
      canvas.drawRRect(note.inflate(5), fill..color = paper);
      canvas.drawRRect(note, fill..color = paper);
      canvas.drawRRect(
        note,
        pen
          ..color = outline
          ..strokeWidth = 2,
      );
      heart(80, 60, .85, rose);
      canvas.drawLine(
        const Offset(63, 72),
        const Offset(97, 72),
        pen..color = outline,
      );
      canvas.drawLine(const Offset(67, 80), const Offset(93, 80), pen);
      final envelope = RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 76, 110, 60),
        const Radius.circular(13),
      );
      canvas.drawRRect(envelope.inflate(5), fill..color = paper);
      canvas.drawRRect(envelope, fill..color = blush);
      canvas.drawRRect(envelope, pen..color = outline);
      final fold = Path()
        ..moveTo(28, 81)
        ..lineTo(70, 108)
        ..quadraticBezierTo(80, 115, 90, 108)
        ..lineTo(132, 81);
      canvas.drawPath(fold, pen);
      canvas.drawLine(const Offset(29, 132), const Offset(59, 105), pen);
      canvas.drawLine(const Offset(131, 132), const Offset(102, 105), pen);
      canvas.drawCircle(const Offset(80, 111), 13, fill..color = paper);
      heart(80, 116, .55, rose);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KeepsakeStickerPainter oldDelegate) =>
      dark != oldDelegate.dark || recovery != oldDelegate.recovery;
}

class AuthKeepsakeHeader extends StatelessWidget {
  const AuthKeepsakeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.wide = false,
    this.recovery = false,
  });
  final String title;
  final String subtitle;
  final bool wide;
  final bool recovery;

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackArtwork =
            wide ||
            constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(14) > 19;
        final heading = Text(
          title,
          style: style
              .text(size: wide ? 44 : 30, height: 1.12, weight: FontWeight.w700)
              .copyWith(letterSpacing: wide ? -1.4 : -.8),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AuthStickerBadge(icon: Icons.favorite_rounded, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('auth_refresh_brand'),
                    style: style
                        .text(size: 19, weight: FontWeight.w700)
                        .copyWith(letterSpacing: -.6),
                  ),
                ),
                if (stackArtwork && !wide)
                  AuthKeepsakeSticker(size: 58, recovery: recovery),
              ],
            ),
            SizedBox(height: wide ? 28 : 14),
            if (stackArtwork)
              heading
            else
              Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 8),
                  AuthKeepsakeSticker(size: 116, recovery: recovery),
                ],
              ),
            SizedBox(height: stackArtwork ? 12 : 2),
            Text(
              subtitle,
              style: style.text(
                size: wide ? 16 : 13,
                color: style.muted,
                height: 1.5,
              ),
            ),
            if (wide) ...[
              const SizedBox(height: 24),
              AuthKeepsakeSticker(size: 230, recovery: recovery),
            ],
          ],
        );
      },
    );
  }
}

class AuthStickerBadge extends StatelessWidget {
  const AuthStickerBadge({super.key, required this.icon, this.size = 34});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: style.accentFill,
          borderRadius: BorderRadius.circular(size * .34),
          border: Border.all(color: style.surface, width: 2),
          boxShadow: [
            BoxShadow(
              color: style.accent.withValues(alpha: .07),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: size * .49, color: style.accent),
      ),
    );
  }
}

class AuthKeepsakeCard extends StatelessWidget {
  const AuthKeepsakeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: style.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: style.border),
          ),
          child: Padding(padding: padding, child: child),
        ),
        Positioned(
          top: -6,
          right: 28,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Transform.rotate(
                angle: .07,
                child: Container(
                  width: 48,
                  height: 13,
                  decoration: BoxDecoration(
                    color: style.accentFill.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: style.accent.withValues(alpha: .10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
