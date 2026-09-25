import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../../utils/services/infrastructure/cloudflare_r2_service.dart';
import '../../../../../utils/services/private_media_url_service.dart';
import '../../../../../utils/services/l10n_service.dart';

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
  final Stream<String?>? authChanges;
  final String? Function()? currentUid;

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
    this.authChanges,
    this.currentUid,
  });

  @override
  State<DiaryMemoryVideoPlayer> createState() => DiaryMemoryVideoPlayerState();
}

class DiaryMemoryVideoPlayerState extends State<DiaryMemoryVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  int _generation = 0;
  bool _foreground = true;
  StreamSubscription<String?>? _auth;
  Timer? _expiry;
  String? _uid;
  String? get _currentUid => widget.currentUid != null
      ? widget.currentUid!()
      : FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (widget.requireFreshAuthorization) {
      _uid = _currentUid;
      _auth =
          (widget.authChanges ??
                  FirebaseAuth.instance.authStateChanges().map(
                    (user) => user?.uid,
                  ))
              .listen((uid) {
                if (uid != _uid) _invalidateAuthorization();
              }, onError: (Object _) => _invalidateAuthorization());
    }
    if (_foreground) unawaited(_initVideo());
  }

  @override
  void didUpdateWidget(covariant DiaryMemoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.houseId != widget.houseId ||
        oldWidget.memoryId != widget.memoryId) {
      unawaited(_initVideo());
    } else if (oldWidget.isActive != widget.isActive) {
      unawaited(_syncPlayback());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (widget.requireFreshAuthorization) {
      if (_foreground) {
        unawaited(_initVideo());
      } else {
        _invalidateAuthorization();
      }
      return;
    }
    // Khi quay lại ứng dụng, để người dùng chủ động phát tiếp.
    if (!_foreground) unawaited(_syncPlayback());
  }

  void _invalidateAuthorization() {
    ++_generation;
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
      if (widget.isActive && _foreground && !widget.previewOnly) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _hasError = true);
      }
    }
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
      _expiry?.cancel();
      _expiry = Timer(
        Duration(milliseconds: lifetime),
        () => unawaited(_initVideo()),
      );
    }
    return result.url;
  }

  Future<void> _releaseController() async {
    final previous = _controller;
    _controller = null;
    if (previous != null) await previous.dispose();
  }

  Future<void> _initVideo() async {
    final generation = ++_generation;
    final oldPosition = _controller?.value.position ?? Duration.zero;
    _expiry?.cancel();
    bool current() =>
        mounted &&
        generation == _generation &&
        (!widget.requireFreshAuthorization ||
            (_foreground && _uid != null && _uid == _currentUid));
    setState(() {
      _initialized = false;
      _hasError = false;
    });
    await _releaseController();
    for (var attempt = 0; attempt < 2 && current(); attempt++) {
      VideoPlayerController? candidate;
      try {
        var url = attempt == 0 && !widget.requireFreshAuthorization
            ? widget.url.trim()
            : '';
        if (url.isEmpty) {
          url = await _freshUrl(
            generation,
          ).timeout(widget.initializationTimeout);
        }
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
        candidate =
            widget.controllerFactory?.call(uri) ??
            VideoPlayerController.networkUrl(uri);
        _controller = candidate;
        await candidate.initialize().timeout(widget.initializationTimeout);
        if (!current()) return;
        await candidate.setLooping(true);
        if (widget.previewOnly) await candidate.setVolume(0);
        if (oldPosition > Duration.zero && !widget.previewOnly) {
          await candidate.seekTo(oldPosition);
        }
        if (!current()) return;
        setState(() => _initialized = true);
        await _syncPlayback();
        return;
      } catch (_) {
        if (!current()) return;
        _initialized = false;
        if (identical(_controller, candidate)) await _releaseController();
      }
    }
    if (current()) setState(() => _hasError = true);
  }

  @override
  void dispose() {
    ++_generation;
    _expiry?.cancel();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_releaseController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
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
              L10nService().translate('memory_video_play_error'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _initialized = false;
                });
                _initVideo();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(L10nService().translate('core_retry')),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (!_initialized || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (value.hasError) {
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
                  L10nService().translate('memory_video_play_error'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _initialized = false;
                    });
                    _initVideo();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(L10nService().translate('core_retry')),
                ),
              ],
            ),
          );
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
                            child: VideoPlayer(controller),
                          ),
                        ),
                      )
                    : Center(
                        child: AspectRatio(
                          aspectRatio: value.aspectRatio > 0
                              ? value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(controller),
                        ),
                      ),
              ),
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
