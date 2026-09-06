import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';
import 'package:lottie/lottie.dart';

import 'package:soullocket_app/views/ui_prefs.dart';

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
  static const int _maxRamCacheSize = 50;
  static final Map<String, File> _ramCache = {};

  bool _shouldLoad = false;
  File? _cachedFile;

  static void _cacheRamFile(String url, File file) {
    if (_ramCache.containsKey(url)) {
      _ramCache.remove(url);
    } else if (_ramCache.length >= _maxRamCacheSize) {
      _ramCache.remove(_ramCache.keys.first);
    }
    _ramCache[url] = file;
  }

  @override
  void initState() {
    super.initState();
    final cleanUrl = widget.url.trim();
    if (_ramCache.containsKey(cleanUrl)) {
      _cachedFile = _ramCache[cleanUrl];
      _shouldLoad = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _shouldLoad = true);
          _preloadLottie();
        }
      });
    }
  }

  Future<void> _preloadLottie() async {
    if (kIsWeb) return;
    final cleanUrl = widget.url.trim();
    if (_ramCache.containsKey(cleanUrl)) return;

    try {
      final file = await const StorageDownloadCacheHelper()
          .getCachedNetworkFile(
            cleanUrl,
            namespace: 'lottie_anims',
            ttl: const Duration(days: 30),
          );
      if (file != null && file.existsSync()) {
        _cacheRamFile(cleanUrl, file);
        if (mounted) {
          setState(() {
            _cachedFile = file;
          });
        }
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/widgets/lottie_async_loader.dart: $error',
      );
    }
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
        child: const Center(child: SizedBox.shrink()),
      );
    }

    if (_cachedFile != null) {
      return Lottie.file(
        _cachedFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        frameRate: const FrameRate(30),
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ?? const SizedBox.shrink(),
      );
    }

    return Lottie.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      frameRate: const FrameRate(30),
      errorBuilder: (context, error, stackTrace) =>
          widget.errorWidget ?? const SizedBox.shrink(),
    );
  }
}
