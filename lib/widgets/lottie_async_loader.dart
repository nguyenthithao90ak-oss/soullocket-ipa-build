import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/storage/storage_download_cache_helper.dart';
import 'package:soullocket_app/utils/screen_activity_mixin.dart';
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

class _LottieAsyncLoaderState extends State<LottieAsyncLoader>
    with ScreenActivityMixin<LottieAsyncLoader> {
  static const int _maxRamCacheSize = 50;
  static final Map<String, File> _ramCache = {};

  bool _shouldLoad = false;
  File? _cachedFile;
  Timer? _loadTimer;
  int _loadGeneration = 0;
  bool _loadScheduled = false;

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
    _resetForUrl();
  }

  @override
  void didUpdateWidget(covariant LottieAsyncLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resetForUrl();
  }

  void _resetForUrl() {
    _loadTimer?.cancel();
    _loadGeneration++;
    _loadScheduled = false;
    final cleanUrl = widget.url.trim();
    _cachedFile = _ramCache[cleanUrl];
    _shouldLoad = _cachedFile != null;
    if (_cachedFile == null) _scheduleLoadWhenActive();
  }

  @override
  void onScreenActivityChanged(bool active) {
    if (!active) {
      _loadTimer?.cancel();
      _loadScheduled = false;
      return;
    }
    if (_cachedFile != null) {
      if (!_shouldLoad && mounted) setState(() => _shouldLoad = true);
      return;
    }
    _scheduleLoadWhenActive();
  }

  void _scheduleLoadWhenActive() {
    if (kIsWeb ||
        !isScreenActive ||
        _loadScheduled ||
        _cachedFile != null ||
        widget.url.trim().isEmpty) {
      return;
    }
    _loadScheduled = true;
    final generation = _loadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !isScreenActive ||
          generation != _loadGeneration ||
          _cachedFile != null) {
        _loadScheduled = false;
        return;
      }
      void start() {
        _loadTimer = null;
        if (!mounted ||
            !isScreenActive ||
            generation != _loadGeneration ||
            _cachedFile != null) {
          _loadScheduled = false;
          return;
        }
        setState(() => _shouldLoad = true);
        unawaited(_preloadLottie(widget.url.trim(), generation));
      }

      if (widget.loadDelay <= Duration.zero) {
        start();
      } else {
        _loadTimer = Timer(widget.loadDelay, start);
      }
    });
  }

  Future<void> _preloadLottie(String cleanUrl, int generation) async {
    if (kIsWeb || cleanUrl.isEmpty) return;
    File? file;

    try {
      file = await const StorageDownloadCacheHelper()
          .getCachedNetworkFile(
            cleanUrl,
            namespace: 'lottie_anims',
            ttl: const Duration(days: 30),
          );
      if (file != null && file.existsSync()) {
        _cacheRamFile(cleanUrl, file);
        if (mounted && generation == _loadGeneration) {
          setState(() {
            _cachedFile = file;
          });
        }
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/widgets/lottie_async_loader.dart: $error',
      );
    } finally {
      if (generation == _loadGeneration) _loadScheduled = false;
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _loadGeneration++;
    super.dispose();
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
