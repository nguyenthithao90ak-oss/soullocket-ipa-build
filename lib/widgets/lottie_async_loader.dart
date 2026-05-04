import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../views/ui_prefs.dart';

/// Lazy-loads Lottie animations only when the widget is rendered.
/// Saves 50-200KB per animation by deferring network requests.
class LottieAsyncLoader extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Duration loadDelay;

  const LottieAsyncLoader({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.errorWidget,
    this.loadDelay = const Duration(milliseconds: 100),
  });

  @override
  State<LottieAsyncLoader> createState() => _LottieAsyncLoaderState();
}

class _LottieAsyncLoaderState extends State<LottieAsyncLoader> {
  bool _shouldLoad = false;

  @override
  void initState() {
    super.initState();
    // Delay loading to ensure the widget is rendered first.
    Future.delayed(widget.loadDelay, () {
      if (mounted) {
        setState(() => _shouldLoad = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectProfile = UiPrefs.resolveEffectProfile(
      state: UiPrefs.notifier.value,
      isWeb: kIsWeb,
    );
    if (!effectProfile.premiumEffects) {
      return widget.errorWidget ??
          SizedBox(width: widget.width, height: widget.height);
    }

    if (!_shouldLoad) {
      // Show placeholder while waiting for load.
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox.shrink(),
        ),
      );
    }

    return Lottie.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) =>
          widget.errorWidget ?? const SizedBox.shrink(),
    );
  }
}
