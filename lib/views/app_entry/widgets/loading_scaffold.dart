import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../core/sl_theme.dart';

class LoadingScaffold extends StatefulWidget {
  const LoadingScaffold({super.key});

  @override
  State<LoadingScaffold> createState() => _LoadingScaffoldState();
}

class _LoadingScaffoldState extends State<LoadingScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFFBF8),
        accentColor: SLColors.primary,
        secondaryAccent: SLColors.accentPurple,
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 720),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: Transform.scale(
                          scale: 0.96 + (0.04 * value),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _loadingController,
                          builder: (context, child) {
                            final pulse = 1 +
                                (_loadingController.value < 0.5 ? 1 : -1) *
                                    0.02;
                            return Transform.scale(
                              scale: pulse,
                              child: child,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD81B60)
                                      .withValues(alpha: 0.22),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 0,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.asset(
                                'assets/icon.png',
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'SoulLocket',
                          style: SLTheme.quicksand(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: SLColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('app_entry_angmnginhc_763d46'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: SLTheme.authChipText,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _SoftLoadingBar(controller: _loadingController),
                        const SizedBox(height: 16),
                        _LoadingDots(controller: _loadingController),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: child,
                  ),
                  child: Text(
                    context.tr('app_entry_ktniantonv_c00306'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SLTheme.authMutedTextColor,
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

class _SoftLoadingBar extends StatelessWidget {
  final Animation<double> controller;

  const _SoftLoadingBar({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 184,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFD7E5)),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return Align(
                alignment: Alignment(-1 + controller.value * 2, 0),
                child: Container(
                  width: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x00D81B60),
                        Color(0xFFD81B60),
                        Color(0x00D81B60),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  final Animation<double> controller;

  const _LoadingDots({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (controller.value + index * 0.18) % 1;
            final opacity = phase < 0.5 ? 0.35 + phase : 0.85 - phase * 0.5;
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD81B60).withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}
