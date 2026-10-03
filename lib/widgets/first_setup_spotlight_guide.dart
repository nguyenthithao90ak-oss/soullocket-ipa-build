import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  final double? targetBorderRadius;

  final VoidCallback? onNext;

  const FirstSetupSpotlightStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.targetBorderRadius,
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
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        transitionBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
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
  final GlobalKey _overlayKey = GlobalKey();
  final Set<ScrollPosition> _targetScrollPositions = {};
  int? _pendingIndex;
  int _generation = 0;
  bool _frameQueued = false;
  bool _needsSync = false;
  bool _needsScroll = false;

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
      (_) => _queueTargetSync(),
    );
  }

  @override
  void dispose() {
    _targetTimer?.cancel();
    for (final position in _targetScrollPositions) {
      position.removeListener(_onTargetScroll);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _queueTargetSync(scroll: true);
  }

  void _onTargetScroll() => _queueTargetSync();

  void _queueTargetSync({bool scroll = false}) {
    if (!mounted || _closing) return;
    _needsScroll = _needsScroll || scroll;
    if (_frameQueued) return;
    _frameQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameQueued = false;
      final shouldScroll = _needsScroll;
      _needsScroll = false;
      unawaited(_syncTargetRect(scroll: shouldScroll));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _bindTargetScroll(BuildContext? targetContext) {
    final positions = <ScrollPosition>{};
    targetContext?.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        positions.add((element.state as ScrollableState).position);
      }
      return true;
    });
    for (final position in _targetScrollPositions.difference(positions)) {
      position.removeListener(_onTargetScroll);
    }
    for (final position in positions.difference(_targetScrollPositions)) {
      position.addListener(_onTargetScroll);
    }
    _targetScrollPositions
      ..clear()
      ..addAll(positions);
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
    if (!mounted || _closing) return;
    if (_syncing) {
      _needsSync = true;
      _needsScroll = _needsScroll || scroll;
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (!(widget.isStillValid?.call() ?? true)) {
      _closing = true;
      Navigator.of(context).pop();
      return;
    }
    final index = _pendingIndex ?? _index;
    if (index >= widget.steps.length) return;
    final step = widget.steps[index];
    final generation = _generation;
    _syncing = true;
    try {
      final targetContext = step.targetKey.currentContext;
      bool hidden = false;
      targetContext?.visitAncestorElements((element) {
        if (element.widget case Offstage(offstage: true)) hidden = true;
        if (element.widget case Opacity(opacity: 0)) hidden = true;
        return !hidden;
      });
      _bindTargetScroll(hidden ? null : targetContext);
      if (targetContext != null && !hidden && (scroll || _targetRect == null)) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: .35,
          duration: Duration.zero,
        );
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted || _closing || generation != _generation) return;
      if (!(widget.isStillValid?.call() ?? true)) {
        _closing = true;
        Navigator.of(context).pop();
        return;
      }
      final render = targetContext?.findRenderObject();
      final overlay = _overlayKey.currentContext?.findRenderObject();
      Rect? rect;
      if (render is RenderBox &&
          overlay is RenderBox &&
          !hidden &&
          render.attached &&
          render.hasSize &&
          !render.size.isEmpty &&
          overlay.hasSize) {
        final media = MediaQuery.of(context);
        final viewport = Rect.fromLTRB(
          0,
          media.padding.top,
          overlay.size.width,
          math.max(
            media.padding.top,
            overlay.size.height -
                media.padding.bottom -
                media.viewInsets.bottom,
          ),
        );
        var candidate = MatrixUtils.transformRect(
          render.getTransformTo(overlay),
          Offset.zero & render.size,
        );
        RenderObject? ancestor = render.parent;
        while (ancestor != null) {
          if (ancestor is RenderBox &&
              (ancestor is RenderAbstractViewport ||
                  ancestor is RenderClipRect ||
                  ancestor is RenderClipRRect)) {
            final clip = MatrixUtils.transformRect(
              ancestor.getTransformTo(overlay),
              Offset.zero & ancestor.size,
            );
            candidate = candidate.intersect(clip);
          }
          ancestor = ancestor.parent;
        }
        if (candidate.overlaps(viewport) && !candidate.isEmpty) {
          rect = candidate.intersect(viewport);
        }
      }
      if (index != _index || !_sameTargetRect(_targetRect, rect)) {
        setState(() {
          _index = index;
          _targetRect = rect;
          _pendingIndex = null;
        });
      } else {
        _pendingIndex = null;
      }
      if (rect != null && _lastRecorded != index) {
        _lastRecorded = index;
        unawaited(_record(SetupGuideStatus.inProgress));
      }
    } finally {
      _syncing = false;
      if (_needsSync && mounted && !_closing) {
        _needsSync = false;
        _queueTargetSync(scroll: _needsScroll);
      }
    }
  }

  void _next() {
    if (_closing ||
        _pendingIndex != null ||
        _targetRect == null ||
        !(widget.isStillValid?.call() ?? true)) {
      return;
    }
    _step?.onNext?.call();
    if (_index >= widget.steps.length - 1) {
      unawaited(_finish(SetupGuideOutcome.completed));
      return;
    }
    _moveTo(_index + 1);
  }

  void _back() {
    if (_index == 0 || _closing || _pendingIndex != null) return;
    _moveTo(_index - 1);
  }

  void _moveTo(int index) {
    _generation++;
    _pendingIndex = index;
    _queueTargetSync(scroll: true);
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
    if (step == null) return const SizedBox.expand();
    return PopScope<SetupGuideOutcome>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _closing = true;
      },
      child: SizedBox.expand(
        key: _overlayKey,
        child: Material(
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final size = constraints.biggest;
              final safeTop = media.padding.top + 12;
              final safeBottom =
                  media.padding.bottom + media.viewInsets.bottom + 16;
              final usableHeight = math.max(
                80.0,
                size.height - safeTop - safeBottom,
              );
              final targetRect = _targetRect;
              final above = math.max(
                0.0,
                (targetRect?.top ?? safeTop) - safeTop - 16,
              );
              final below = math.max(
                0.0,
                size.height - safeBottom - (targetRect?.bottom ?? safeTop) - 16,
              );
              final showCardAbove = targetRect != null && above > below;
              final available = targetRect == null
                  ? usableHeight * .68
                  : (showCardAbove ? above : below);
              final cardHeight = math.min(
                usableHeight * .68,
                math.max(80.0, available),
              );
              final cardWidth = math.min(size.width - 32, 420.0);
              final targetCenter =
                  targetRect?.center ?? Offset(size.width / 2, 0);
              final cardLeft = (targetCenter.dx - cardWidth / 2).clamp(
                16.0,
                size.width - cardWidth - 16,
              );
              final highlight = targetRect
                  ?.inflate(4)
                  .intersect(Offset.zero & size);
              final radius = highlight == null
                  ? 0.0
                  : math.min(
                      step.targetBorderRadius == null
                          ? _spotlightRadiusFor(highlight)
                          : step.targetBorderRadius! + 4,
                      highlight.shortestSide / 2,
                    );
              return Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('setup-guide-scrim'),
                        painter: _SpotlightPainter(
                          target: highlight ?? Rect.zero,
                          radius: radius,
                          color: const Color(0xFFFFF4E5),
                        ),
                      ),
                    ),
                  ),
                  if (highlight != null)
                    Positioned.fromRect(
                      key: const ValueKey('setup-guide-target'),
                      rect: highlight,
                      child: const IgnorePointer(child: SizedBox.expand()),
                    ),
                  Positioned(
                    left: cardLeft,
                    top: showCardAbove ? safeTop : null,
                    bottom: showCardAbove ? null : safeBottom,
                    width: cardWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: cardHeight),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _sameTargetRect(Rect? previous, Rect? next) {
  if (previous == null || next == null) return previous == next;
  return (previous.left - next.left).abs() < .5 &&
      (previous.top - next.top).abs() < .5 &&
      (previous.right - next.right).abs() < .5 &&
      (previous.bottom - next.bottom).abs() < .5;
}

double _spotlightRadiusFor(Rect rect) {
  final shortestSide = rect.shortestSide;
  final longestSide = rect.longestSide;
  if (shortestSide <= 72 && (longestSide - shortestSide).abs() <= 18) {
    return shortestSide / 2;
  }
  return math.min(20, shortestSide / 2);
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
    canvas.drawPath(path, Paint()..color = const Color(0xA6141018));

    canvas.drawRRect(
      RRect.fromRectAndRadius(target, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.target != target ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
  }
}

const _guideAccent = Color(0xFF965C6C);
const _guideInk = Color(0xFF3D343A);
const _guideMuted = Color(0xFF756770);

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
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final nextButton = FilledButton.icon(
      key: const ValueKey('setup-guide-next'),
      style: FilledButton.styleFrom(
        backgroundColor: _guideAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onNext,
      icon: Icon(
        !targetReady
            ? Icons.refresh_rounded
            : isLast
            ? Icons.check_rounded
            : isRtl
            ? Icons.arrow_back_rounded
            : Icons.arrow_forward_rounded,
        size: 18,
      ),
      iconAlignment: IconAlignment.end,
      label: Text(
        context.tr(
          !targetReady
              ? 'core_retry'
              : isLast
              ? 'core_done'
              : 'core_next',
        ),
        textAlign: TextAlign.center,
        style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
    final skip = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: _guideMuted,
        minimumSize: const Size(48, 48),
      ),
      onPressed: onSkip,
      child: Text(
        context.tr('core_skip'),
        style: SLTheme.quicksand(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
    final back = onBack == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _guideInk,
              minimumSize: const Size(48, 48),
            ),
            onPressed: onBack,
            child: Text(
              context.tr('settings_back_btn'),
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
    return Container(
      key: const ValueKey('setup-guide-card'),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DDD8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        key: const ValueKey('setup-guide-card-clip'),
        borderRadius: BorderRadius.circular(19),
        child: SingleChildScrollView(
          key: ValueKey(index),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    context.tr('guide_tour_label'),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _guideMuted,
                    ),
                  ),
                  Text(
                    L10nService().format('guide_step_counter', {
                      'current': index + 1,
                      'total': total,
                    }),
                    textDirection: Directionality.of(context),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _guideAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: step.color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(step.icon, color: step.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.title,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _guideInk,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                step.description,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _guideMuted,
                  height: 1.5,
                ),
              ),
              if (!targetReady) ...[
                const SizedBox(height: 12),
                Text(
                  context.tr('guide_target_unavailable'),
                  style: SLTheme.quicksand(fontSize: 12, color: _guideMuted),
                ),
              ],
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: (index + 1) / total,
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
                color: _guideAccent,
                backgroundColor: const Color(0xFFEEE4E7),
              ),
              const SizedBox(height: 16),
              nextButton,
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [skip, ?back],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
