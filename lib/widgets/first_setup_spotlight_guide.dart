import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';
import 'first_setup_guide_progress.dart';
export 'first_setup_guide_progress.dart';

enum SetupGuideOutcome { completed, dismissed }

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
  final SetupGuideProgress? progress;
  final bool replay;
  final bool Function()? isStillValid;
  static bool _showing = false;

  const FirstSetupSpotlightGuide({
    super.key,
    required this.steps,
    this.onFinished,
    this.progress,
    this.replay = false,
    this.isStillValid,
  });

  static Future<SetupGuideOutcome?> show(
    BuildContext context, {
    required List<FirstSetupSpotlightStep> steps,
    VoidCallback? onFinished,
    SetupGuideProgress? progress,
    bool replay = false,
    bool Function()? isStillValid,
  }) async {
    if (_showing ||
        steps.isEmpty ||
        !context.mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        !(isStillValid?.call() ?? true)) {
      return null;
    }
    if (!replay && progress != null && !progress.shouldOffer) return null;
    _showing = true;
    try {
      return await showGeneralDialog<SetupGuideOutcome>(
        context: context,
        barrierDismissible: false,
        barrierLabel: context.tr('user_guide'),
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => FirstSetupSpotlightGuide(
          steps: steps,
          onFinished: onFinished,
          progress: progress,
          replay: replay,
          isStillValid: isStillValid,
        ),
      );
    } finally {
      _showing = false;
    }
  }

  @override
  State<FirstSetupSpotlightGuide> createState() =>
      _FirstSetupSpotlightGuideState();
}

class _FirstSetupSpotlightGuideState extends State<FirstSetupSpotlightGuide>
    with WidgetsBindingObserver {
  int _index = 0;
  Rect? _targetRect;
  Timer? _targetTimer;
  bool _closing = false;
  bool _syncing = false;
  int? _lastRecorded;

  @override
  void initState() {
    super.initState();
    _index = widget.steps.isEmpty
        ? 0
        : (widget.replay ? 0 : widget.progress?.step ?? 0).clamp(
            0,
            widget.steps.length - 1,
          );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncTargetRect(scroll: true),
    );
    // Theo dõi target tải muộn chỉ trong thời gian tour đang mở.
    _targetTimer = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _syncTargetRect(),
    );
  }

  @override
  void dispose() {
    _targetTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncTargetRect(scroll: true),
    );
  }

  Future<void> _record(SetupGuideStatus status) async {
    try {
      await widget.progress?.save(status, _index);
    } catch (_) {
      // Không chặn đọc hướng dẫn nếu bộ nhớ cục bộ không ghi được.
    }
  }

  FirstSetupSpotlightStep? get _step {
    if (widget.steps.isEmpty || _index >= widget.steps.length) return null;
    return widget.steps[_index];
  }

  Future<void> _syncTargetRect({bool scroll = false}) async {
    if (!mounted || _syncing || _closing) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (!(widget.isStillValid?.call() ?? true)) {
      _closing = true;
      Navigator.of(context).pop();
      return;
    }
    final step = _step;
    if (step == null) return;
    _syncing = true;
    try {
      final targetContext = step.targetKey.currentContext;
      bool hidden = false;
      targetContext?.visitAncestorElements((element) {
        if (element.widget case Offstage(offstage: true)) hidden = true;
        if (element.widget case Opacity(opacity: 0)) hidden = true;
        return !hidden;
      });
      if (targetContext != null && !hidden && (scroll || _targetRect == null)) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: .5,
          duration: Duration.zero,
        );
      }
      if (!mounted || _closing) return;
      final render = targetContext?.findRenderObject();
      Rect? rect;
      if (render is RenderBox &&
          !hidden &&
          render.attached &&
          render.hasSize &&
          !render.size.isEmpty) {
        final candidate = render.localToGlobal(Offset.zero) & render.size;
        final viewport = Offset.zero & MediaQuery.sizeOf(context);
        if (candidate.overlaps(viewport)) rect = candidate.intersect(viewport);
      }
      if (_targetRect != rect) setState(() => _targetRect = rect);
      if (rect != null && _lastRecorded != _index) {
        _lastRecorded = _index;
        unawaited(_record(SetupGuideStatus.inProgress));
      }
    } finally {
      _syncing = false;
    }
  }

  void _next() {
    if (_closing ||
        _targetRect == null ||
        !(widget.isStillValid?.call() ?? true)) {
      return;
    }
    final currentStep = _step;
    currentStep?.onNext?.call();
    if (_index >= widget.steps.length - 1) {
      _finish(SetupGuideOutcome.completed);
      return;
    }
    setState(() {
      _index++;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncTargetRect(scroll: true),
    );
  }

  void _back() {
    if (_index == 0 || _closing) return;
    setState(() {
      _index--;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncTargetRect(scroll: true),
    );
  }

  Future<void> _finish(SetupGuideOutcome outcome) async {
    if (_closing || !(widget.isStillValid?.call() ?? true)) return;
    _closing = true;
    await _record(
      outcome == SetupGuideOutcome.completed
          ? SetupGuideStatus.completed
          : SetupGuideStatus.dismissed,
    );
    if (!mounted) return;
    if (outcome == SetupGuideOutcome.completed) widget.onFinished?.call();
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final targetRect = _targetRect;
    if (step == null) {
      return const SizedBox.expand();
    }

    final media = MediaQuery.of(context);
    final size = media.size;
    final safeTop = media.padding.top + 12;
    final safeBottom = media.padding.bottom + 16;
    final cardWidth = math.min(size.width - 32, 390.0);
    final targetCenter = targetRect?.center ?? Offset(size.width / 2, 0);
    final showCardAbove = targetCenter.dy > size.height * 0.54;
    final cardLeft = (targetCenter.dx - cardWidth / 2).clamp(
      16.0,
      size.width - cardWidth - 16,
    );

    final targetHighlightRect = targetRect?.inflate(8) ?? Rect.zero;
    final targetRadius = _spotlightRadiusFor(targetHighlightRect);

    return PopScope<SetupGuideOutcome>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _closing = true;
      },
      child: SizedBox.expand(
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
              if (targetRect != null)
                Positioned.fromRect(
                  rect: targetHighlightRect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(targetRadius),
                        border: Border.all(
                          color: step.color.withValues(alpha: 0.92),
                          width: 2.4,
                        ),
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
                top: showCardAbove ? safeTop : null,
                bottom: showCardAbove
                    ? null
                    : safeBottom + media.viewInsets.bottom,
                width: cardWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      80,
                      (size.height -
                              safeTop -
                              safeBottom -
                              media.viewInsets.bottom) *
                          .62,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: _SpotlightCard(
                      step: step,
                      index: _index,
                      total: widget.steps.length,
                      onSkip: () => _finish(SetupGuideOutcome.dismissed),
                      onNext: targetRect == null
                          ? () => _syncTargetRect(scroll: true)
                          : _next,
                      onBack: _index > 0 ? _back : null,
                      targetReady: targetRect != null,
                      isLast: _index >= widget.steps.length - 1,
                    ),
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
      ..addRRect(RRect.fromRectAndRadius(target, Radius.circular(radius)));
    final path = Path.combine(PathOperation.difference, overlay, cutout);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.66),
    );

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
  final VoidCallback? onBack;
  final bool targetReady;

  const _SpotlightCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onNext,
    required this.isLast,
    this.onBack,
    this.targetReady = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
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
          if (!targetReady) ...[
            Text(context.tr('guide_target_unavailable')),
            const SizedBox(height: 12),
          ],
          LinearProgressIndicator(
            value: (index + 1) / total,
            color: const Color(0xFFAC4E6C),
            backgroundColor: const Color(0xFFF0E7E9),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
              if (onBack != null)
                TextButton(
                  onPressed: onBack,
                  child: Text(context.tr('settings_back_btn')),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFAC4E6C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: onNext,
                child: Text(
                  !targetReady
                      ? context.tr('core_retry')
                      : isLast
                      ? L10nService().translate('core_done')
                      : L10nService().translate('core_next'),
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
