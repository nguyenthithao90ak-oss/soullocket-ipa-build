import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'aurora_tab_switcher.dart';

/// Main presentation shell for the redesigned authentication card.
/// Auth callbacks and business logic are intentionally kept outside this file.
class AuroraLoginShell extends StatelessWidget {
  final bool compact;
  final bool isLoginTab;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;
  final Widget authSection;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenContact;

  const AuroraLoginShell({
    super.key,
    required this.compact,
    required this.isLoginTab,
    required this.onSelectLogin,
    required this.onSelectRegister,
    required this.authSection,
    required this.onOpenGuide,
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 18 : 24,
        compact ? 16 : 24,
        compact ? 16 : 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocketBrandHeader(compact: compact, l10n: l10n),
          SizedBox(height: compact ? 16 : 20),
          AuroraTabSwitcher(
            isLoginTab: isLoginTab,
            onSelectLogin: onSelectLogin,
            onSelectRegister: onSelectRegister,
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(fade),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(isLoginTab ? 'cute_login' : 'cute_register'),
              child: authSection,
            ),
          ),
          const SizedBox(height: 15),
          _TinyHelpRow(
            compact: compact,
            l10n: l10n,
            onOpenGuide: onOpenGuide,
            onOpenContact: onOpenContact,
          ),
        ],
      ),
    );
  }
}

class _LocketBrandHeader extends StatelessWidget {
  final bool compact;
  final L10nService l10n;

  const _LocketBrandHeader({required this.compact, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 90 : 102,
          height: compact ? 82 : 92,
          child: const RepaintBoundary(
            child: CustomPaint(
              painter: _LocketBadgePainter(),
            ),
          ),
        ),
        const SizedBox(height: 2),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFD95078), Color(0xFF8C72C9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: Text(
            'SoulLocket',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: compact ? 30 : 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF3D8DF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: Color(0xFFC49342),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.translate('Nơi lưu giữ những khoảnh khắc yêu thương'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7B666E),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TinyHelpRow extends StatelessWidget {
  final bool compact;
  final L10nService l10n;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenContact;

  const _TinyHelpRow({
    required this.compact,
    required this.l10n,
    required this.onOpenGuide,
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniHelpButton(
            icon: Icons.menu_book_rounded,
            label: l10n.translate('Hướng dẫn'),
            onTap: onOpenGuide,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _MiniHelpButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.translate('Hỗ trợ'),
            onTap: onOpenContact,
          ),
        ),
      ],
    );
  }
}

class _MiniHelpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniHelpButton({
    required this.icon,
    required this.label,
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
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF8).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEDDE2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFD45A7C)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF725D66),
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

class _LocketBadgePainter extends CustomPainter {
  const _LocketBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final short = math.min(size.width, size.height);

    final shadowPaint = Paint()
      ..color = const Color(0xFFB14D6B).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawCircle(center.translate(0, 6), short * 0.34, shadowPaint);

    final outer = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD5DF), Color(0xFFD9CCFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: short * 0.36));
    canvas.drawCircle(center, short * 0.35, outer);

    final rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, short * 0.31, rim);

    final face = Paint()..color = const Color(0xFFFFFBF8);
    canvas.drawCircle(center, short * 0.26, face);

    final heart = Path()
      ..moveTo(center.dx, center.dy + short * 0.08)
      ..cubicTo(
        center.dx - short * 0.22,
        center.dy - short * 0.06,
        center.dx - short * 0.13,
        center.dy - short * 0.24,
        center.dx,
        center.dy - short * 0.10,
      )
      ..cubicTo(
        center.dx + short * 0.13,
        center.dy - short * 0.24,
        center.dx + short * 0.22,
        center.dy - short * 0.06,
        center.dx,
        center.dy + short * 0.08,
      );
    canvas.drawPath(heart, Paint()..color = const Color(0xFFE8698B));

    final eyePaint = Paint()
      ..color = const Color(0xFF684D58)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final eyeY = center.dy - short * 0.025;
    canvas.drawLine(
      Offset(center.dx - short * 0.073, eyeY),
      Offset(center.dx - short * 0.045, eyeY + 1),
      eyePaint,
    );
    canvas.drawLine(
      Offset(center.dx + short * 0.045, eyeY + 1),
      Offset(center.dx + short * 0.073, eyeY),
      eyePaint,
    );

    final loopPaint = Paint()
      ..color = const Color(0xFF9879C9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final loopRect = Rect.fromCenter(
      center: Offset(center.dx, size.height * 0.11),
      width: short * 0.18,
      height: short * 0.18,
    );
    canvas.drawArc(loopRect, math.pi, math.pi, false, loopPaint);

    final sparkle = Paint()
      ..color = const Color(0xFFD6A34E)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final s = Offset(size.width * 0.84, size.height * 0.30);
    canvas.drawLine(Offset(s.dx - 5, s.dy), Offset(s.dx + 5, s.dy), sparkle);
    canvas.drawLine(Offset(s.dx, s.dy - 5), Offset(s.dx, s.dy + 5), sparkle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
