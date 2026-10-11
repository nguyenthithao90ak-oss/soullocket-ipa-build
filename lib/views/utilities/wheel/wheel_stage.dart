import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import 'wheel_design.dart';

class WheelStage extends StatelessWidget {
  const WheelStage({
    super.key,
    required this.items,
    required this.rotation,
    required this.angle,
    required this.spinning,
    required this.selectedIndex,
    required this.onSpin,
  });

  final List<String> items;
  final Listenable rotation;
  final double Function() angle;
  final bool spinning;
  final int? selectedIndex;
  final VoidCallback? onSpin;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.4).toDouble();
    return Container(
      decoration: WheelDesign.cardDecoration,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        children: [
          Text(
            context.tr('util_vngquaynhm_856e66'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: WheelDesign.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'ui_utilities_for_example_who_cooks_who_washes_the_85f0e7',
            ),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: WheelDesign.muted,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = min(constraints.maxWidth, 330.0);
              final hubSize = max(64.0, size * 0.26);
              return SizedBox.square(
                dimension: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFF4E9),
                        border: Border.all(color: Colors.white, width: 5),
                        boxShadow: [
                          BoxShadow(
                            color: WheelDesign.accent.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(13),
                      child: AnimatedBuilder(
                        animation: rotation,
                        // Mảnh và chữ chỉ vẽ lại khi dữ liệu đổi, không mỗi frame.
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const ValueKey('wheel-disc'),
                            painter: _WheelDiscPainter(
                              items: items,
                              selectedIndex: selectedIndex,
                              direction: direction,
                              textScale: textScale,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        builder: (context, child) =>
                            Transform.rotate(angle: angle(), child: child),
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      child: SizedBox(
                        width: 28,
                        height: 40,
                        child: CustomPaint(painter: _WheelPointerPainter()),
                      ),
                    ),
                    Container(
                      width: hubSize,
                      height: hubSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: WheelDesign.ink.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: onSpin == null && !spinning
                            ? WheelDesign.muted
                            : WheelDesign.accent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const ValueKey('wheel-spin-hub'),
                          customBorder: const CircleBorder(),
                          onTap: onSpin,
                          child: Semantics(
                            button: true,
                            enabled: onSpin != null,
                            label: context.tr(
                              spinning
                                  ? 'util_angquay_3580ce'
                                  : 'util_btuquay_5c5ee8',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    spinning
                                        ? Icons.autorenew_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        context.tr('ui_utilities_spin_962324'),
                                        style: SLTheme.quicksand(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WheelDiscPainter extends CustomPainter {
  const _WheelDiscPainter({
    required this.items,
    required this.selectedIndex,
    required this.direction,
    required this.textScale,
  });

  final List<String> items;
  final int? selectedIndex;
  final TextDirection direction;
  final double textScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..color = WheelDesign.border);
    if (items.isEmpty) return;
    final sweep = 2 * pi / items.length;
    final divider = Paint()
      ..color = const Color(0xFFFFFCFA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < items.length; i++) {
      final color = WheelDesign.choiceColor(i);
      final start = -pi / 2 + i * sweep;
      final mid = start + sweep / 2;
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [Color.lerp(color, Colors.white, 0.35)!, color],
          [0.18, 1],
        );
      canvas.drawArc(rect, start, sweep, true, paint);
      canvas.drawLine(
        center,
        center + Offset(cos(start), sin(start)) * radius,
        divider,
      );
      if (selectedIndex == i) {
        canvas.drawArc(
          rect.deflate(4),
          start + 0.025,
          max(0.0, sweep - 0.05),
          false,
          Paint()
            ..color = WheelDesign.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }

      final numberedOnly = items.length > 10;
      final numberRadius = radius * (numberedOnly ? 0.64 : 0.85);
      final numberCenter = center + Offset(cos(mid), sin(mid)) * numberRadius;
      final numberSize = min(12.0, radius * sin(sweep / 2) * 0.5);
      if (numberSize >= 5) {
        canvas.drawCircle(
          numberCenter,
          numberSize,
          Paint()..color = Colors.white.withValues(alpha: 0.68),
        );
      }
      final number = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: SLTheme.quicksand(
            fontSize: items.length > 16 ? 9 : 10,
            fontWeight: FontWeight.w900,
            color: WheelDesign.ink,
          ),
        ),
        textDirection: direction,
      )..layout();
      number.paint(
        canvas,
        numberCenter - Offset(number.width, number.height) / 2,
      );
      if (numberedOnly) continue;

      final labelCenter = center + Offset(cos(mid), sin(mid)) * radius * 0.59;
      final labelWidth = min(
        radius * 0.74,
        2 * sin(sweep / 2) * radius * 0.59 * 0.84,
      );
      final label = TextPainter(
        text: TextSpan(
          text: items[i],
          style: SLTheme.quicksand(
            fontSize: (items.length > 6 ? 11 : 13) * textScale,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: WheelDesign.ink,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: direction,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth);
      label.paint(canvas, labelCenter - Offset(label.width, label.height) / 2);
    }
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = const Color(0xFFFFFCFA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelDiscPainter oldDelegate) =>
      !listEquals(oldDelegate.items, items) ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.direction != direction ||
      oldDelegate.textScale != textScale;
}

class _WheelPointerPainter extends CustomPainter {
  const _WheelPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..cubicTo(3, 23, 0, 18, 0, 12)
      ..cubicTo(0, -4, size.width, -4, size.width, 12)
      ..cubicTo(size.width, 18, size.width - 3, 23, size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, WheelDesign.ink.withValues(alpha: 0.25), 3, true);
    canvas.drawPath(path, Paint()..color = WheelDesign.accent);
    canvas.drawCircle(
      Offset(size.width / 2, 12),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPointerPainter oldDelegate) => false;
}
