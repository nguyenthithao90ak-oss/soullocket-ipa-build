import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lottie/lottie.dart';

import '../views/ui_prefs.dart';

/// Lazy-loads and caches Lottie animations.
/// Resolves and caches network requests on disk for instant subsequent loading and offline playback.
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
  File? _cachedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _shouldLoad = true);
        _preloadLottie();
      }
    });
  }

  Future<void> _preloadLottie() async {
    if (kIsWeb) return;
    try {
      final file = await DefaultCacheManager().getSingleFile(widget.url);
      if (mounted) {
        setState(() {
          _cachedFile = file;
        });
      }
    } catch (_) {}
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

    if (_cachedFile != null) {
      return Lottie.file(
        _cachedFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ?? const SizedBox.shrink(),
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
