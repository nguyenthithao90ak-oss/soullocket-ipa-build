import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';
import '../../../../../utils/screen_activity_mixin.dart';
import '../../../../../utils/services/infrastructure/cloudflare_r2_service.dart';
import '../../../../../utils/services/private_media_url_service.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/media_data_preferences.dart';
import 'diary_video_buffer_cache.dart';

class DiaryMemoryVideoPlayer extends StatefulWidget {
  final String url;
  final bool isActive;
  final Duration initializationTimeout;
  final VideoPlayerController Function(Uri)? controllerFactory;
  final Future<String> Function()? resolveUrl;
  final String? houseId;
  final String? memoryId;
  final bool requireFreshAuthorization;
  final bool previewOnly;
  final Widget? loadingPoster;
  final Stream<String?>? authChanges;
  final String? Function()? currentUid;
  final DiaryVideoBufferCache? bufferCache;
  final MediaDataPreferences? dataPreferences;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final Stream<List<ConnectivityResult>>? connectivityChanges;

  /// Nơi công bố controller của video đang phát để màn xem hiện thanh tua ở lớp giao
  /// diện (ngoài vùng phóng to). Chỉ trang đang hiển thị mới ghi vào đây.
  final ValueNotifier<VideoPlayerController?>? controlsTarget;

  const DiaryMemoryVideoPlayer({
    super.key,
    required this.url,
    this.houseId,
    this.memoryId,
    this.isActive = true,
    this.initializationTimeout = const Duration(seconds: 20),
    this.controllerFactory,
    this.resolveUrl,
    this.requireFreshAuthorization = false,
    this.previewOnly = false,
    this.loadingPoster,
    this.authChanges,
    this.currentUid,
    this.bufferCache,
    this.dataPreferences,
    this.checkConnectivity,
    this.connectivityChanges,
    this.controlsTarget,
  });

  @override
  State<DiaryMemoryVideoPlayer> createState() => DiaryMemoryVideoPlayerState();
}

class DiaryMemoryVideoPlayerState extends State<DiaryMemoryVideoPlayer>
    with WidgetsBindingObserver, ScreenActivityMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasPlaybackFrame = false;
  Duration _frameStartPosition = Duration.zero;
  bool _hasError = false;
  bool _wifiBlocked = false;
  bool _wifiOnly = false;
  StreamSubscription<List<ConnectivityResult>>? _network;
  late final _dataPreferences =
      widget.dataPreferences ?? MediaDataPreferences.instance;

  int _generation = 0;
  bool _foreground = true;
  bool _resumeWhenVisible = true;
  StreamSubscription<String?>? _auth;
  int _authBinding = 0;
  Timer? _expiry;
  Timer? _initializationDeadline;
  Timer? _bufferingDeadline;
  Duration? _bufferingPosition;
  bool _authorized = false;
  Duration _resumePosition = Duration.zero;
  final _localReleasing = <VideoPlayerController, Future<void>>{};
  final _releaseTransitions = <Future<void>>{};
  String? _uid;
  VideoPlayerController? _published;
  DiaryVideoBuffer? _buffer;
  Duration _authorizationLifetime = const Duration(seconds: 100);
  Object get _bufferKey => (
    _uid,
    widget.houseId,
    widget.memoryId,
    widget.requireFreshAuthorization ? null : widget.url,
    widget.requireFreshAuthorization,
  );
  String? get _currentUid => widget.currentUid != null
      ? widget.currentUid!()
      : FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _dataPreferences.addListener(_onDataPreferencesChanged);
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _bindAuthorization();
    if (_foreground && (widget.isActive || widget.previewOnly)) {
      unawaited(_initVideo());
    }
  }

  void _bindAuthorization() {
    final binding = ++_authBinding;
    unawaited(_auth?.cancel());
    _auth = null;
    _uid = widget.requireFreshAuthorization || widget.bufferCache != null
        ? _currentUid
        : null;
    widget.bufferCache?.bindSession(
      _uid,
      widget.authChanges ??
          FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
    );
    if (!widget.requireFreshAuthorization) return;
    _auth =
        (widget.authChanges ??
                FirebaseAuth.instance.authStateChanges().map(
                  (user) => user?.uid,
                ))
            .listen(
              (uid) {
                if (binding == _authBinding && uid != _uid) {
                  _invalidateAuthorization();
                }
              },
              onError: (Object _) {
                if (binding == _authBinding) _invalidateAuthorization();
              },
            );
  }

  void _onDataPreferencesChanged() {
    if (mounted && _foreground) unawaited(_initVideo());
  }

  void _watchNetwork(bool wifiOnly) {
    _wifiOnly = wifiOnly;
    if (!wifiOnly) {
      unawaited(_network?.cancel());
      _network = null;
      return;
    }
    _network ??=
        (widget.connectivityChanges ?? Connectivity().onConnectivityChanged)
            .listen(
              (connections) {
                final blocked = !connections.contains(ConnectivityResult.wifi);
                if (mounted && _foreground && blocked != _wifiBlocked) {
                  unawaited(_initVideo());
                }
              },
              onError: (Object _) {
                if (mounted && _foreground) unawaited(_initVideo());
              },
            );
  }

  @override
  void didUpdateWidget(covariant DiaryMemoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requireFreshAuthorization !=
        widget.requireFreshAuthorization) {
      _bindAuthorization();
    }
    if (oldWidget.url != widget.url ||
        oldWidget.houseId != widget.houseId ||
        oldWidget.memoryId != widget.memoryId ||
        oldWidget.requireFreshAuthorization !=
            widget.requireFreshAuthorization) {
      unawaited(_initVideo(resetPosition: true));
    } else if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive && !widget.previewOnly) {
        _deactivateVideo();
        return;
      }
      if (widget.isActive && _controller == null) {
        unawaited(_initVideo());
        return;
      }
      // Đổi phát/dừng sau khung hình: thanh tua ở lớp giao diện cũng nghe controller này.
      unawaited(
        _afterBuild().then((_) async {
          if (!mounted) return;
          await _syncPlayback();
          await _syncControlsTarget();
        }),
      );
    } else if (oldWidget.controlsTarget != widget.controlsTarget) {
      unawaited(_syncControlsTarget());
    }
  }

  /// Chờ hết khung hình đang dựng; notifier/controller đổi giữa lúc build sẽ đánh dấu
  /// widget ngoài cây con cần build lại và Flutter báo lỗi.
  Future<void> _afterBuild() async {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  @override
  void onScreenActivityChanged(bool active) {
    _watchBuffering();
    if (!active) {
      _resumeWhenVisible =
          isScreenForeground &&
          widget.isActive &&
          !widget.previewOnly &&
          (!_initialized || _controller?.value.isPlaying == true);
      unawaited(_afterBuild().then((_) => _syncPlayback()));
    } else if (_resumeWhenVisible && _initialized) {
      _resumeWhenVisible = false;
      unawaited(_afterBuild().then((_) => _syncPlayback()));
    }
    unawaited(_syncControlsTarget());
  }

  Future<void> _syncControlsTarget() async {
    final target = widget.controlsTarget;
    if (target == null) return;
    await _afterBuild();
    final controller = _controller;
    final wanted =
        mounted &&
        controller != null &&
        _initialized &&
        !_hasError &&
        widget.isActive &&
        isScreenActive &&
        !widget.previewOnly;
    if (wanted) {
      target.value = controller;
    } else if (_published != null && identical(target.value, _published)) {
      // Chỉ gỡ controller của chính trang này, không gỡ của trang khác đang phát.
      target.value = null;
    }
    _published = wanted ? controller : null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _resumeWhenVisible = false;
    _watchBuffering();
    if (widget.requireFreshAuthorization) {
      if (_foreground) {
        unawaited(_initVideo());
      } else {
        _invalidateAuthorization();
      }
      return;
    }
    // Khi quay lại ứng dụng, để người dùng chủ động phát tiếp.
    if (_foreground && _wifiOnly) {
      unawaited(_initVideo());
      return;
    }
    if (!_foreground) {
      if (!_initialized) {
        _deactivateVideo();
      } else {
        unawaited(_syncPlayback());
      }
    } else if (_controller == null && widget.isActive) {
      unawaited(_initVideo());
    }
  }

  void _invalidateAuthorization() {
    ++_generation;
    _authorized = false;
    _initializationDeadline?.cancel();
    widget.bufferCache?.clear();
    _expiry?.cancel();
    unawaited(_releaseController());
    if (mounted) {
      setState(() {
        _initialized = false;
        _hasError = true;
      });
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    try {
      if (widget.isActive &&
          !_wifiBlocked &&
          _foreground &&
          isScreenActive &&
          !widget.previewOnly) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _hasError = true);
        unawaited(_syncControlsTarget());
      }
    }
  }

  void _watchBuffering() {
    final controller = _controller;
    if (!_hasPlaybackFrame &&
        mounted &&
        controller != null &&
        _initialized &&
        !_hasError &&
        _foreground &&
        isScreenActive &&
        (widget.isActive || widget.previewOnly) &&
        (!widget.requireFreshAuthorization || _authorized)) {
      final value = controller.value;
      // Initialized chỉ bảo đảm metadata đã có. Giữ poster đến khi đồng hồ
      // phát thực sự đổi và hết đệm; rebuffer sau đó không phủ lại poster.
      if (value.isInitialized &&
          !value.isBuffering &&
          value.size.width > 0 &&
          value.size.height > 0 &&
          value.position != _frameStartPosition) {
        _hasPlaybackFrame = true;
      }
    }
    if (!mounted ||
        controller == null ||
        !_initialized ||
        _hasError ||
        !_foreground ||
        !isScreenActive ||
        !widget.isActive ||
        widget.previewOnly ||
        !controller.value.isPlaying ||
        !controller.value.isBuffering) {
      _bufferingDeadline?.cancel();
      _bufferingDeadline = null;
      _bufferingPosition = null;
      return;
    }
    final position = controller.value.position;
    if (_bufferingDeadline != null && _bufferingPosition == position) return;
    _bufferingDeadline?.cancel();
    _bufferingPosition = position;
    final generation = _generation;
    _bufferingDeadline = Timer(widget.initializationTimeout, () {
      if (!mounted ||
          generation != _generation ||
          !identical(_controller, controller)) {
        return;
      }
      _resumePosition = controller.value.position;
      ++_generation;
      _authorized = false;
      _expiry?.cancel();
      unawaited(_releaseController());
      setState(() {
        _initialized = false;
        _hasError = true;
      });
    });
  }

  Future<String> _freshUrl(int generation) async {
    if (widget.resolveUrl != null) return widget.resolveUrl!();
    if (widget.houseId?.isNotEmpty != true ||
        widget.memoryId?.isNotEmpty != true) {
      throw StateError('Missing media reference');
    }
    final result = await PrivateMediaUrlService().resolve(
      houseId: widget.houseId!,
      mediaId: widget.memoryId!,
      kind: 'memory_image',
    );
    if (widget.requireFreshAuthorization &&
        mounted &&
        generation == _generation) {
      final lifetime =
          result.expiresAt - DateTime.now().millisecondsSinceEpoch - 5000;
      if (lifetime <= 0) throw StateError('Expired authorization');
      _authorizationLifetime = Duration(milliseconds: lifetime);
      _expiry?.cancel();
      _expiry = Timer(
        Duration(milliseconds: lifetime),
        () => unawaited(_initVideo()),
      );
    }
    return result.url;
  }

  Future<void> _releaseController({bool keepBuffer = false}) {
    final work = _releaseControllerNow(
      keepBuffer: keepBuffer,
    ).catchError((Object _) {});
    _releaseTransitions.add(work);
    widget.bufferCache?.trackRelease(work);
    unawaited(work.then((_) => _releaseTransitions.remove(work)));
    return work;
  }

  Future<void> _releaseControllerNow({bool keepBuffer = false}) async {
    final previous = _controller;
    final buffer = _buffer;
    final cache = widget.bufferCache;
    final cacheGeneration = cache?.generation;
    final cacheKey = _bufferKey;
    _controller = null;
    _buffer = null;
    _hasPlaybackFrame = false;
    _frameStartPosition = Duration.zero;
    if (previous == null) return;
    _bufferingDeadline?.cancel();
    _bufferingDeadline = null;
    _bufferingPosition = null;
    previous.removeListener(_watchBuffering);
    // Gỡ khỏi thanh tua trước khi giải phóng để lớp giao diện không dùng controller đã hủy.
    final target = widget.controlsTarget;
    if (target != null && identical(target.value, previous)) {
      await _afterBuild();
      if (identical(target.value, previous)) target.value = null;
    }
    if (identical(_published, previous)) _published = null;
    if (keepBuffer && cache != null && buffer != null) {
      try {
        await previous.pause();
        cache.store(cacheKey, buffer, generation: cacheGeneration!);
        return;
      } catch (_) {
        // Player lỗi không được giữ lại để tái sử dụng.
      }
    }
    await _disposeController(previous);
  }

  Future<void> _disposeController(VideoPlayerController controller) {
    final cache = widget.bufferCache;
    if (cache != null) return cache.release(controller);
    final pending = _localReleasing[controller];
    if (pending != null) return pending;
    final work = Future<void>.sync(
      controller.dispose,
    ).catchError((Object _) {});
    _localReleasing[controller] = work;
    unawaited(
      work.then((_) {
        if (identical(_localReleasing[controller], work)) {
          _localReleasing.remove(controller);
        }
      }),
    );
    return work;
  }

  Future<void> _waitForReleases() async {
    while (_releaseTransitions.isNotEmpty) {
      await Future.wait(_releaseTransitions.toList());
    }
    await widget.bufferCache?.waitForReleases();
    while (_localReleasing.isNotEmpty) {
      await Future.wait(_localReleasing.values.toList());
    }
  }

  void _deactivateVideo() {
    _resumePosition = _controller?.value.position ?? _resumePosition;
    ++_generation;
    _initializationDeadline?.cancel();
    _expiry?.cancel();
    final keepBuffer = _initialized && !_hasError && _foreground;
    unawaited(_releaseController(keepBuffer: keepBuffer));
    _authorized = false;
    setState(() {
      _initialized = false;
      _hasError = false;
    });
  }

  Future<void> _initVideo({bool resetPosition = false}) async {
    if (!mounted) return;
    final generation = ++_generation;
    _resumePosition = resetPosition
        ? Duration.zero
        : _controller?.value.position ?? _resumePosition;
    final oldPosition = _resumePosition;
    _expiry?.cancel();
    _initializationDeadline?.cancel();
    _authorized = false;
    bool current() =>
        mounted &&
        generation == _generation &&
        _foreground &&
        (widget.isActive || widget.previewOnly) &&
        (!widget.requireFreshAuthorization ||
            (_foreground && _uid != null && _uid == _currentUid));
    setState(() {
      _initialized = false;
      _hasError = false;
      _wifiBlocked = false;
    });
    if (!current()) {
      await _releaseController();
      return;
    }
    // Một deadline chung cho quyền, native initialize và cấu hình. Native chậm
    // vẫn bị hàng rào disposal giữ lại; bấm thử lại không sinh thêm decoder.
    _initializationDeadline = Timer(widget.initializationTimeout, () {
      if (!current()) return;
      ++_generation;
      _authorized = false;
      _expiry?.cancel();
      unawaited(_releaseController());
      setState(() {
        _initialized = false;
        _hasError = true;
      });
    });
    await _releaseController();
    await _waitForReleases();
    if (!current()) return;
    // PageView có thể dựng trước trang bên cạnh; chỉ cấp URL và decoder khi mở.
    if (!widget.isActive && !widget.previewOnly) return;
    try {
      final settings = await _dataPreferences.read();
      if (!current()) return;
      _watchNetwork(settings.wifiOnlyVideos);
      if (settings.wifiOnlyVideos &&
          !await _dataPreferences.canStartVideo(
            checkConnectivity: widget.checkConnectivity,
          )) {
        if (!current()) return;
        _initializationDeadline?.cancel();
        widget.bufferCache?.clear();
        setState(() => _wifiBlocked = true);
        return;
      }
    } catch (_) {
      if (!current()) return;
      _initializationDeadline?.cancel();
      setState(() => _hasError = true);
      return;
    }
    if (!current()) return;
    for (var attempt = 0; attempt < 2 && current(); attempt++) {
      VideoPlayerController? candidate;
      try {
        final hasResolver =
            widget.resolveUrl != null ||
            (widget.houseId?.isNotEmpty == true &&
                widget.memoryId?.isNotEmpty == true);
        var url =
            !widget.requireFreshAuthorization && (attempt == 0 || !hasResolver)
            ? widget.url.trim()
            : '';
        if (url.isEmpty) url = await _freshUrl(generation);
        if (!current()) return;
        if (url.isEmpty) throw StateError('Missing media URL');
        final uri = Uri.parse(
          widget.requireFreshAuthorization
              ? url
              : CloudflareR2Service.resolveVideoUrl(url),
        );
        if (widget.requireFreshAuthorization && uri.scheme != 'https') {
          throw StateError('Invalid media URL');
        }
        if (widget.requireFreshAuthorization) {
          setState(() => _authorized = true);
        }
        // Video riêng tư vẫn xin quyền mới ở trên trước khi lấy buffer cũ.
        final cached = attempt == 0 && !widget.previewOnly
            ? widget.bufferCache?.take(_bufferKey)
            : null;
        if (cached == null) {
          // Cache có thể vừa loại một decoder lỗi/hết hạn khi take().
          await _waitForReleases();
          if (!current()) return;
        }
        candidate =
            cached?.controller ??
            widget.controllerFactory?.call(uri) ??
            VideoPlayerController.networkUrl(uri);
        _buffer =
            cached ??
            DiaryVideoBuffer(candidate, validFor: _authorizationLifetime);
        if (cached != null && widget.requireFreshAuthorization) {
          _expiry?.cancel();
          _expiry = Timer(cached.remaining, () => unawaited(_initVideo()));
        }
        _controller = candidate;
        candidate.addListener(_watchBuffering);
        if (cached == null) {
          await candidate.initialize();
        }
        if (!current()) return;
        await candidate.setLooping(true);
        if (widget.previewOnly) await candidate.setVolume(0);
        if (oldPosition > Duration.zero && !widget.previewOnly) {
          await candidate.seekTo(oldPosition);
        }
        if (!current()) return;
        _hasPlaybackFrame = false;
        _frameStartPosition = candidate.value.position;
        setState(() => _initialized = true);
        await _syncPlayback();
        if (!current()) return;
        _watchBuffering();
        await _syncControlsTarget();
        if (!current()) return;
        _initializationDeadline?.cancel();
        return;
      } catch (_) {
        if (!current()) return;
        _initialized = false;
        if (candidate == null) {
          // Quyền/App Check/quota đã bị từ chối: không gọi lại mù.
          break;
        }
        if (identical(_controller, candidate)) await _releaseController();
        await _waitForReleases();
      }
    }
    if (current()) {
      _initializationDeadline?.cancel();
      _authorized = false;
      if (widget.requireFreshAuthorization) widget.bufferCache?.clear();
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    ++_generation;
    ++_authBinding;
    _initializationDeadline?.cancel();
    _bufferingDeadline?.cancel();
    _dataPreferences.removeListener(_onDataPreferencesChanged);
    unawaited(_network?.cancel());
    _expiry?.cancel();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _releaseController(
        keepBuffer:
            _initialized &&
            !_hasError &&
            _foreground &&
            !widget.previewOnly &&
            (!widget.requireFreshAuthorization || _uid == _currentUid),
      ),
    );
    super.dispose();
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _initialized = false;
    });
    _initVideo();
  }

  Widget _errorView() {
    final message = L10nService().translate('memory_video_play_error');
    if (widget.previewOnly) {
      // Ô xem trước trong lưới rất nhỏ: chỉ một biểu tượng co theo ô, không chữ/nút
      // (khung lỗi đầy đủ cao ~140 px làm tràn ô). Chạm vào ô mở màn xem có nút thử lại.
      return Semantics(
        label: message,
        child: const Center(
          child: FractionallySizedBox(
            widthFactor: 0.42,
            heightFactor: 0.42,
            child: FittedBox(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(L10nService().translate('core_retry')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive && !widget.previewOnly) {
      return const SizedBox.expand();
    }
    if (_wifiBlocked) {
      final message = L10nService().translate('media_data_wifi_required');
      return Center(
        child: Semantics(
          label: message,
          child: widget.previewOnly
              ? const Icon(Icons.wifi_rounded, color: Colors.white, size: 28)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: _retry,
                        child: Text(L10nService().translate('core_retry')),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    if (_hasError) {
      return _errorView();
    }

    final controller = _controller;
    if (!_initialized || controller == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_foreground &&
              (!widget.requireFreshAuthorization || _authorized) &&
              widget.loadingPoster != null)
            widget.loadingPoster!,
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      child: VideoPlayer(controller),
      builder: (context, value, child) {
        if (value.hasError) {
          return _errorView();
        }

        final isPlaying = value.isPlaying;
        final isBuffering = value.isBuffering;
        final size = value.size;
        final hasValidSize = size.width > 0 && size.height > 0;

        return GestureDetector(
          onTap: () {
            if (widget.previewOnly || !widget.isActive || !_foreground) return;
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: hasValidSize
                    ? Center(
                        child: FittedBox(
                          fit: widget.previewOnly
                              ? BoxFit.cover
                              : BoxFit.contain,
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: child!,
                          ),
                        ),
                      )
                    : Center(
                        child: AspectRatio(
                          aspectRatio: value.aspectRatio > 0
                              ? value.aspectRatio
                              : 16 / 9,
                          child: child!,
                        ),
                      ),
              ),
              if (!_hasPlaybackFrame &&
                  _foreground &&
                  (!widget.requireFreshAuthorization || _authorized) &&
                  widget.loadingPoster != null)
                Positioned.fill(child: widget.loadingPoster!),
              if (isBuffering)
                const CircularProgressIndicator(color: Colors.white)
              else if (!isPlaying)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
