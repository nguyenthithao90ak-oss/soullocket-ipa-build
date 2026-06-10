import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';

class FirstSetupSpotlightStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  final VoidCallback? onNext;

  const FirstSetupSpotlightStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.onNext,
  });
}

class FirstSetupSpotlightGuide extends StatefulWidget {
  final List<FirstSetupSpotlightStep> steps;
  final VoidCallback? onFinished;

  const FirstSetupSpotlightGuide({
    super.key,
    required this.steps,
    this.onFinished,
  });

  static Future<void> show(
    BuildContext context, {
    required List<FirstSetupSpotlightStep> steps,
    VoidCallback? onFinished,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'First setup spotlight guide',
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => FirstSetupSpotlightGuide(
        steps: steps,
        onFinished: onFinished,
      ),
    );
  }

  @override
  State<FirstSetupSpotlightGuide> createState() => _FirstSetupSpotlightGuideState();
}

class _FirstSetupSpotlightGuideState extends State<FirstSetupSpotlightGuide> {
  int _index = 0;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTargetRect());
  }

  FirstSetupSpotlightStep? get _step {
    if (widget.steps.isEmpty || _index >= widget.steps.length) return null;
    return widget.steps[_index];
  }

  void _syncTargetRect() {
    if (!mounted) return;
    final step = _step;
    if (step == null) {
      _finish();
      return;
    }

    final context = step.targetKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _next(skipMissing: true);
      return;
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & renderObject.size;
    });
  }

  void _next({bool skipMissing = false}) {
    final currentStep = _step;
    if (!skipMissing) {
      currentStep?.onNext?.call();
    }
    if (_index >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTargetRect());
  }

  void _finish() {
    widget.onFinished?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final targetRect = _targetRect;
    if (step == null || targetRect == null) {
      return const SizedBox.expand();
    }

    final media = MediaQuery.of(context);
    final size = media.size;
    final safeTop = media.padding.top + 12;
    final safeBottom = media.padding.bottom + 16;
    final cardWidth = math.min(size.width - 32, 390.0);
    final targetCenter = targetRect.center;
    final showCardAbove = targetCenter.dy > size.height * 0.54;
    final cardTop = showCardAbove
        ? math.max(safeTop, targetRect.top - 210)
        : math.min(size.height - safeBottom - 190, targetRect.bottom + 18);
    final cardLeft = (targetCenter.dx - cardWidth / 2).clamp(16.0, size.width - cardWidth - 16);

    final targetHighlightRect = targetRect.inflate(8);
    final targetRadius = _spotlightRadiusFor(targetHighlightRect);

    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  target: targetHighlightRect,
                  radius: targetRadius,
                  color: step.color,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: targetHighlightRect,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(targetRadius),
                    border: Border.all(color: step.color.withValues(alpha: 0.92), width: 2.4),
                    boxShadow: [
                      BoxShadow(
                        color: step.color.withValues(alpha: 0.36),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: cardLeft,
              top: cardTop,
              width: cardWidth,
              child: _SpotlightCard(
                step: step,
                index: _index,
                total: widget.steps.length,
                onSkip: _finish,
                onNext: _next,
                isLast: _index >= widget.steps.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _spotlightRadiusFor(Rect rect) {
  final shortestSide = rect.shortestSide;
  final longestSide = rect.longestSide;
  if (shortestSide <= 72 && (longestSide - shortestSide).abs() <= 18) {
    return shortestSide / 2;
  }
  return math.min(28, shortestSide / 2);
}

class _SpotlightPainter extends CustomPainter {
  final Rect target;
  final double radius;
  final Color color;

  const _SpotlightPainter({
    required this.target,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(
        RRect.fromRectAndRadius(target, Radius.circular(radius)),
      );
    final path = Path.combine(PathOperation.difference, overlay, cutout);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.66));

    canvas.drawRRect(
      RRect.fromRectAndRadius(target, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.target != target ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
  }
}

class _SpotlightCard extends StatelessWidget {
  final FirstSetupSpotlightStep step;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool isLast;

  const _SpotlightCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onNext,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBFD), Color(0xFFFFEEF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(step.icon, color: step.color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                    height: 1.18,
                  ),
                ),
              ),
              Text(
                '${index + 1}/$total',
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: step.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.description,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SLColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  L10nService().translate('core_skip'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF7A6570),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: step.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: onNext,
                child: Text(
                  isLast ? L10nService().translate('core_done') : L10nService().translate('core_next'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
