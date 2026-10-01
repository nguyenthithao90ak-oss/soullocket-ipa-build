import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../utils/services/l10n_service.dart';

class DiaryImageLoading extends StatefulWidget {
  const DiaryImageLoading({super.key});

  @override
  State<DiaryImageLoading> createState() => _DiaryImageLoadingState();
}

class _DiaryImageLoadingState extends State<DiaryImageLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );
  Timer? _delay;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _show = true);
      _updateAnimation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  void _updateAnimation() {
    if (_show &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: !_show
          ? const SizedBox.expand()
          : ListenableBuilder(
              listenable: L10nService(),
              builder: (context, _) {
                final label = context.tr('diary_image_loading_wait');
                return Semantics(
                  label: label,
                  excludeSemantics: true,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, _) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(3, (index) {
                                  final pulse =
                                      MediaQuery.disableAnimationsOf(context)
                                      ? 1.0
                                      : (math.sin(
                                                  (_animation.value -
                                                          index / 3) *
                                                      math.pi *
                                                      2,
                                                ) +
                                                1) /
                                            2;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: Opacity(
                                      opacity: 0.35 + pulse * 0.65,
                                      child: Transform.scale(
                                        scale: 0.75 + pulse * 0.25,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: colors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const SizedBox.square(
                                            dimension: 5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              label,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
