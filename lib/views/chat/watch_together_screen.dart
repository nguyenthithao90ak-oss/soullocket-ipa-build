import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/services/chat_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/services/webrtc_service.dart';
import '../../utils/services/ad_suppression_guard.dart';
import '../../utils/services/sound_service.dart';
import 'watch_together_voice_call.dart';
import 'package:soullocket_app/views/home/tabs/short_video_cached_video_controller.dart'
    if (dart.library.html) 'package:soullocket_app/views/home/tabs/short_video_cached_video_controller_web.dart';

class WatchTogetherScreen extends StatefulWidget {
  final String myHouseId;
  final String targetHouseId;
  final String targetName;
  final String? initialUrl;

  const WatchTogetherScreen({
    super.key,
    required this.myHouseId,
    required this.targetHouseId,
    required this.targetName,
    this.initialUrl,
  });

  @override
  State<WatchTogetherScreen> createState() => _WatchTogetherScreenState();
}

class _WatchTogetherScreenState extends State<WatchTogetherScreen> {
  late final VoidCallback _releaseSoundQuiet;
  final ChatService _chatService = ChatService();
  final TextEditingController _urlController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  WebViewController? _webViewController;

  StreamSubscription<DatabaseEvent>? _watchSubscription;
  Timer? _localSyncDebounce;
  final ValueNotifier<bool> _isLoadingVN = ValueNotifier<bool>(false);
  final ValueNotifier<double> _progressVN = ValueNotifier<double>(0.0);
  String? _currentUrl;

  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? _loadingVideoController;
  bool _isVideoPlayer = false;
  int _videoLoadGeneration = 0;
  bool _isHost = false;
  bool _isApplyingRemoteSync = false;
  bool _sharing = false;
  int _shareGeneration = 0;
  int? _lastSyncedPositionBucket;
  bool? _lastSyncedIsPlaying;
  late final String _syncClientId;

  bool _lastKnownIsPlaying = false;
  Duration _lastKnownPosition = Duration.zero;
  DateTime _lastTickTime = DateTime.now();

  // Voice Call State
  final WebRTCService _webrtc = WebRTCService();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late final WatchVoiceCallController _voiceCall;
  final ValueNotifier<bool> _micMutedVN = ValueNotifier<bool>(false);
  Future<void>? _rendererInitialization;
  bool _rendererDisposed = false;

  @override
  void initState() {
    super.initState();
    _releaseSoundQuiet = SoundService().holdQuiet();
    AdSuppressionGuard.instance.suppressAds();
    _syncClientId =
        '${widget.myHouseId}_${DateTime.now().millisecondsSinceEpoch}';

    final rendererInitialization = _initializeRemoteRenderer();
    _rendererInitialization = rendererInitialization;
    unawaited(
      rendererInitialization.catchError((Object error) {
        debugPrint(
          'WatchTogether renderer init failed: ${AppErrorMapper.resolve(error).message}',
        );
      }),
    );
    _voiceCall = WatchVoiceCallController(
      transport: WatchVoiceRtcTransport(
        service: _webrtc,
        renderer: _remoteRenderer,
        rendererInitialization: rendererInitialization,
        myHouseId: widget.myHouseId,
        targetHouseId: widget.targetHouseId,
        database: FirebaseDatabase.instance,
      ),
      myHouseId: widget.myHouseId,
      targetHouseId: widget.targetHouseId,
      onEnded: _onVoiceCallEnded,
    );
    if (!kIsWeb) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'WatchSyncChannel',
          onMessageReceived: (message) {
            _handleWebPlaybackMessage(message.message);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              final url = request.url.toLowerCase();
              if (!url.startsWith('https://')) {
                debugPrint(
                  '🚨 [WatchTogether] Chặn URL không an toàn (chỉ cho phép HTTPS).',
                );
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onProgress: (int progress) {
              if (!mounted) return;
              _progressVN.value = progress / 100;
            },
            onPageStarted: (_) {
              if (!mounted) return;
              _progressVN.value = 0.0;
              _isLoadingVN.value = true;
            },
            onPageFinished: (_) {
              if (!mounted) return;
              _progressVN.value = 1.0;
              _isLoadingVN.value = false;
              _injectWebPlaybackBridge();
            },
          ),
        );
    }

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
    }

    if (!kIsWeb) {
      _listenSharedRoom();
    }
  }

  @override
  void dispose() {
    _videoLoadGeneration++;
    _shareGeneration++;
    _releaseSoundQuiet();
    AdSuppressionGuard.instance.resumeAds();
    _localSyncDebounce?.cancel();
    _watchSubscription?.cancel();
    _urlController.dispose();
    _progressVN.dispose();
    _isLoadingVN.dispose();
    _micMutedVN.dispose();

    _videoPlayerController?.removeListener(_handleVideoPlayerSyncTick);
    _videoPlayerController?.dispose();
    _loadingVideoController?.dispose();
    final voiceCleanup = _voiceCall.end();
    _voiceCall.dispose();
    unawaited(voiceCleanup.whenComplete(_disposeRemoteRenderer));
    super.dispose();
  }

  Future<void> _initializeRemoteRenderer() => _remoteRenderer.initialize();

  Future<void> _disposeRemoteRenderer() async {
    if (_rendererDisposed) return;
    _rendererDisposed = true;
    final rendererInitialization = _rendererInitialization;
    if (rendererInitialization != null) {
      try {
        await rendererInitialization;
      } catch (_) {
        // Hàm dispose an toàn bên dưới vẫn xử lý được renderer khởi tạo dở.
      }
    }
    await disposeVideoRendererSafely(_remoteRenderer);
  }

  String get _sharedRoomId {
    final ids = [widget.myHouseId, widget.targetHouseId]..sort();
    return '${ids.first}_${ids.last}';
  }

  DatabaseReference get _watchRef =>
      _dbRef.child('chats/$_sharedRoomId/watchTogether');

  void _resetPlaybackSyncCache() {
    _lastSyncedPositionBucket = null;
    _lastSyncedIsPlaying = null;
  }

  void _scheduleLocalPlaybackSync({
    bool force = false,
    bool? isPlaying,
    double? positionSec,
  }) {
    if (!_isHost || _currentUrl == null || _isApplyingRemoteSync) return;
    _localSyncDebounce?.cancel();
    _localSyncDebounce = Timer(
      force ? Duration.zero : const Duration(milliseconds: 280),
      () async {
        await _pushLocalPlaybackState(
          isPlaying: isPlaying,
          positionSec: positionSec,
          force: force,
        );
      },
    );
  }

  Future<void> _pushLocalPlaybackState({
    bool? isPlaying,
    double? positionSec,
    bool force = false,
  }) async {
    if (!_isHost || _currentUrl == null || _isApplyingRemoteSync) return;

    bool resolvedIsPlaying = isPlaying ?? false;
    double resolvedPosition = positionSec ?? 0.0;

    if (_isVideoPlayer && _videoPlayerController != null) {
      final controller = _videoPlayerController!;
      if (!controller.value.isInitialized) return;
      resolvedIsPlaying = isPlaying ?? controller.value.isPlaying;
      resolvedPosition =
          positionSec ?? (controller.value.position.inMilliseconds / 1000.0);
    }

    if (resolvedPosition.isNaN || resolvedPosition.isInfinite) {
      resolvedPosition = 0.0;
    }

    final positionBucket = resolvedPosition.floor();
    if (!force &&
        _lastSyncedIsPlaying == resolvedIsPlaying &&
        _lastSyncedPositionBucket == positionBucket) {
      return;
    }

    _lastSyncedIsPlaying = resolvedIsPlaying;
    _lastSyncedPositionBucket = positionBucket;

    await _watchRef.update({
      'isPlaying': resolvedIsPlaying,
      'positionSec': resolvedPosition,
      'lastUpdatedAt': ServerValue.timestamp,
      'originClientId': _syncClientId,
    });
  }

  void _handleVideoPlayerSyncTick() {
    if (!_isVideoPlayer || _videoPlayerController == null) return;
    final controller = _videoPlayerController!;
    if (!controller.value.isInitialized) return;

    final now = DateTime.now();
    final isPlaying = controller.value.isPlaying;
    final position = controller.value.position;

    // Detect play/pause state change
    bool stateChanged = isPlaying != _lastKnownIsPlaying;

    // Detect manual seek:
    // We only consider it a seek if the position actually changed (posDiffMs > 100)
    // and the change is significantly different from the elapsed real time.
    final posDiffMs =
        (position.inMilliseconds - _lastKnownPosition.inMilliseconds).abs();
    final timeDiffMs = now.difference(_lastTickTime).inMilliseconds;
    bool seeked = posDiffMs > 100 && (posDiffMs - timeDiffMs).abs() > 1500;

    _lastKnownIsPlaying = isPlaying;
    _lastKnownPosition = position;
    _lastTickTime = now;

    if (stateChanged || seeked) {
      _scheduleLocalPlaybackSync(
        force: true,
        isPlaying: isPlaying,
        positionSec: position.inMilliseconds / 1000.0,
      );
    }
  }

  void _handleWebPlaybackMessage(String rawMessage) {
    if (!mounted || !_isHost || _isApplyingRemoteSync) return;
    try {
      final parsed = rawMessage.trim();
      if (parsed.isEmpty) return;
      final decoded = jsonDecode(parsed);
      if (decoded is! Map) return;
      final Map<String, dynamic> data = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (data.isEmpty) return;
      final eventName = data['event']?.toString() ?? '';

      // Skip 'timeupdate' events to avoid continuous sync
      if (eventName == 'timeupdate') return;

      final isPlaying = data['isPlaying'] == true;
      final positionSec = (data['positionSec'] as num?)?.toDouble() ?? 0.0;
      _scheduleLocalPlaybackSync(
        force: true,
        isPlaying: isPlaying,
        positionSec: positionSec,
      );
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/chat/watch_together_screen.dart: $error',
      );
    }
  }

  void _injectWebPlaybackBridge() {
    if (kIsWeb || _webViewController == null) return;
    _webViewController!.runJavaScript('''
      (function() {
        function send(eventName, video) {
          if (!video || !window.WatchSyncChannel) return;
          window.WatchSyncChannel.postMessage(JSON.stringify({
            event: eventName,
            isPlaying: !video.paused,
            positionSec: Number(video.currentTime || 0)
          }));
        }
        function bind(video) {
          if (!video || video.dataset.slWatchSyncBound === '1') return false;
          video.dataset.slWatchSyncBound = '1';
          ['play', 'pause', 'seeking', 'seeked', 'ended'].forEach(function(name) {
            video.addEventListener(name, function() {
              send(name, video);
            });
          });
          video.addEventListener('timeupdate', function() {
            var nextSecond = Math.floor(Number(video.currentTime || 0));
            var lastSecond = Number(video.dataset.slWatchSyncSecond || '-1');
            if (!video.paused && nextSecond !== lastSecond) {
              video.dataset.slWatchSyncSecond = String(nextSecond);
              send('timeupdate', video);
            }
          });
          send('ready', video);
          return true;
        }
        window.__slWatchSyncAttach = function() {
          return bind(document.querySelector('video'));
        };
        if (!window.__slWatchSyncAttach()) {
          var attempts = 0;
          var waitTimer = setInterval(function() {
            attempts += 1;
            if (window.__slWatchSyncAttach() || attempts >= 30) {
              clearInterval(waitTimer);
            }
          }, 1000);
        }
      })();
    ''');
  }

  Future<void> _applyRemotePlaybackState({
    required bool isPlaying,
    required double positionSec,
  }) async {
    _isApplyingRemoteSync = true;
    try {
      if (_isVideoPlayer &&
          _videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized) {
        final controller = _videoPlayerController!;
        final currentPos = controller.value.position.inMilliseconds / 1000.0;
        if ((currentPos - positionSec).abs() > 2) {
          await controller.seekTo(
            Duration(milliseconds: (positionSec * 1000).toInt()),
          );
        }
        if (isPlaying && !controller.value.isPlaying) {
          await controller.play();
        } else if (!isPlaying && controller.value.isPlaying) {
          await controller.pause();
        }
        return;
      }

      if (!kIsWeb && _currentUrl != null) {
        if (isPlaying) {
          await _webViewController?.runJavaScript(
            'document.querySelector("video")?.play();',
          );
        } else {
          await _webViewController?.runJavaScript(
            'document.querySelector("video")?.pause();',
          );
        }

        await _webViewController?.runJavaScript('''
          (function() {
            var v = document.querySelector("video");
            if (v && Math.abs(v.currentTime - $positionSec) > 2) {
              v.currentTime = $positionSec;
            }
          })();
        ''');
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/chat/watch_together_screen.dart: $error',
      );
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _isApplyingRemoteSync = false;
      });
    }
  }

  void _listenSharedRoom() {
    _watchSubscription = _watchRef.onValue.listen(
      (event) async {
        if (!mounted) return;
        final raw = event.snapshot.value;
        if (raw is! Map) return;
        final data = Map<String, dynamic>.from(raw);
        _isHost = data['sharedBy']?.toString() == widget.myHouseId;

        final url = data['url']?.toString();
        if (url != null && url.isNotEmpty && url != _currentUrl) {
          await _loadUrl(url);
        }

        if (data['originClientId']?.toString() == _syncClientId) {
          return;
        }

        final isPlaying = data['isPlaying'] == true;
        final positionSec = (data['positionSec'] as num?)?.toDouble() ?? 0.0;
        _applyRemotePlaybackState(
          isPlaying: isPlaying,
          positionSec: positionSec,
        );
      },
      onError: (Object error) {
        debugPrint(
          'Watch together listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('ui_chat_unable_to_synchronize_shared_viewing_room_471db9')).message}',
        );
      },
    );
  }

  Future<void> _shareCurrentUrl() async {
    if (!mounted || _sharing) return;
    final normalized = _normalizeUrl(_urlController.text);
    if (normalized == null) {
      _showSnack(
        context.tr('ui_chat_the_link_is_not_valid_87babc'),
        isError: true,
      );
      return;
    }

    _sharing = true;
    final generation = ++_shareGeneration;
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    bool current() =>
        mounted &&
        generation == _shareGeneration &&
        ownerUid != null &&
        FirebaseAuth.instance.currentUser?.uid == ownerUid;
    try {
      if (!current()) return;
      await _watchRef
          .set({
            'url': normalized,
            'sharedBy': widget.myHouseId,
            'isPlaying': false,
            'positionSec': 0.0,
            'updatedAt': ServerValue.timestamp,
            'originClientId': _syncClientId,
          })
          .timeout(const Duration(seconds: 12));
      if (!current()) return;
      _isHost = true;
      _resetPlaybackSyncCache();
      await _chatService
          .sendWatchInvite(
            widget.myHouseId,
            widget.targetHouseId,
            url: normalized,
          )
          .timeout(const Duration(seconds: 12));
      if (!current()) return;
      await _loadUrl(normalized);
      if (!mounted || !current()) return;
      _showSnack(
        L10nScope.of(context).format(
          'ui_chat_invited_value1_to_watch_together_0a1b58',
          {'value1': widget.targetName},
        ),
      );
    } catch (error) {
      debugPrint(
        'WatchTogether share failed: ${AppErrorMapper.resolve(error).message}',
      );
      if (mounted && current()) {
        _showSnack(
          context.tr(
            'ui_chat_unable_to_synchronize_shared_viewing_room_471db9',
          ),
          isError: true,
        );
      }
    } finally {
      if (generation == _shareGeneration) _sharing = false;
    }
  }

  Future<void> _toggleVoiceCall() async {
    if (!mounted) return;
    if (_voiceCall.active) {
      await _voiceCall.end();
    } else {
      await _voiceCall.start();
    }
  }

  void _onVoiceCallEnded(WatchVoiceEndReason reason) {
    if (!mounted) return;
    _micMutedVN.value = false;
    final key = switch (reason) {
      WatchVoiceEndReason.busy => 'p4_call_busy',
      WatchVoiceEndReason.timeout => 'p4_call_setup_timeout',
      WatchVoiceEndReason.failed => 'p4_call_connection_failed',
      _ => 'ui_chat_voice_call_ended_2efe56',
    };
    _showSnack(
      context.tr(key),
      isError:
          reason == WatchVoiceEndReason.busy ||
          reason == WatchVoiceEndReason.timeout ||
          reason == WatchVoiceEndReason.failed,
    );
  }

  String _voiceStatusText(WatchVoicePhase phase) => switch (phase) {
    WatchVoicePhase.connected => context.tr(
      'ui_chat_on_a_voice_call_please_talk_directly_3d3bff',
    ),
    WatchVoicePhase.preparing => L10nScope.of(context).format(
      'p4_call_initializing',
      {'type': context.tr('p4_call_audio_label')},
    ),
    WatchVoicePhase.connecting => L10nScope.of(
      context,
    ).format('p4_call_connecting', {'type': context.tr('p4_call_audio_label')}),
    WatchVoicePhase.ending => context.tr('p4_call_end'),
    _ => context.tr('p4_call_waiting'),
  };

  void _toggleMic() {
    _micMutedVN.value = !_micMutedVN.value;
    _voiceCall.mute(_micMutedVN.value);
  }

  String? _normalizeUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    // Nâng cấp http:// thành https://, nếu không có scheme thì tự thêm https://
    String withScheme = input;
    if (input.startsWith('http://')) {
      withScheme = input.replaceFirst('http://', 'https://');
    } else if (!input.startsWith('https://')) {
      withScheme = 'https://$input';
    }

    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'https') return null; // Chỉ chấp nhận https

    return uri.toString();
  }

  Future<void> _loadUrl(String url) async {
    if (!mounted) return;
    final generation = ++_videoLoadGeneration;
    _loadingVideoController?.dispose();
    _loadingVideoController = null;
    _currentUrl = url;
    _urlController.text = url;
    _resetPlaybackSyncCache();

    _lastKnownIsPlaying = false;
    _lastKnownPosition = Duration.zero;
    _lastTickTime = DateTime.now();

    final isVideoFile =
        url.toLowerCase().endsWith('.mp4') ||
        url.contains('firebasestorage.googleapis.com');

    if (isVideoFile) {
      _isVideoPlayer = true;
      if (!kIsWeb) {
        _webViewController?.loadHtmlString(
          '<html><body style="background: black;"></body></html>',
        );
      }
      final oldController = _videoPlayerController;
      _videoPlayerController = null;
      oldController?.removeListener(_handleVideoPlayerSyncTick);
      oldController?.dispose();

      VideoPlayerController? newController;
      try {
        // Chỉ dùng file đã có trong cache; cache miss phát trực tiếp URL để
        // tránh kéo cả video về máy trước khi trình phát cần dữ liệu.
        newController = await createCachedVideoController(url);
        if (!mounted || generation != _videoLoadGeneration) {
          newController?.dispose();
          return;
        }
        newController ??= VideoPlayerController.networkUrl(Uri.parse(url));
        _loadingVideoController = newController;
        await newController.initialize().timeout(const Duration(seconds: 20));
      } catch (_) {
        newController?.dispose();
        if (mounted && generation == _videoLoadGeneration) {
          _loadingVideoController = null;
          setState(() => _isVideoPlayer = false);
        }
        return;
      }

      if (!mounted || generation != _videoLoadGeneration) {
        newController.dispose();
        return;
      }
      _videoPlayerController = newController;
      _loadingVideoController = null;
      newController.addListener(_handleVideoPlayerSyncTick);
    } else {
      _isVideoPlayer = false;
      final oldController = _videoPlayerController;
      _videoPlayerController = null;
      oldController?.removeListener(_handleVideoPlayerSyncTick);
      oldController?.dispose();
      if (!kIsWeb) {
        await _webViewController?.loadRequest(Uri.parse(url));
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(
        content: Text(text),
        backgroundColor: isError
            ? const Color(0xFFD81B60)
            : const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F1F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            context.tr('ui_chat_watch_together_0bf9d9'),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
        ),
        floatingActionButton: ValueListenableBuilder<WatchVoicePhase>(
          valueListenable: _voiceCall,
          builder: (context, phase, child) {
            final isCalling = phase != WatchVoicePhase.idle;
            return FloatingActionButton.extended(
              onPressed: _toggleVoiceCall,
              backgroundColor: isCalling ? Colors.red : const Color(0xFF2E7D32),
              icon: Icon(isCalling ? Icons.call_end : Icons.call),
              label: Text(
                isCalling
                    ? context.tr('ui_chat_end_call_005e85')
                    : context.tr('p4_soul_voice_call'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            );
          },
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: SLSpacing.all24,
              child: Text(
                context.tr(
                  'ui_chat_the_view_together_feature_is_not_currently_0d69a2',
                ),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF6D5C63),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final hasUrl = (_currentUrl ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          context.tr('ui_chat_watch_together_0bf9d9'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD81B60),
          ),
        ),
      ),
      floatingActionButton: ValueListenableBuilder<WatchVoicePhase>(
        valueListenable: _voiceCall,
        builder: (context, phase, child) {
          final isCalling = phase != WatchVoicePhase.idle;
          return FloatingActionButton.extended(
            onPressed: _toggleVoiceCall,
            backgroundColor: isCalling ? Colors.red : const Color(0xFF2E7D32),
            icon: Icon(isCalling ? Icons.call_end : Icons.call),
            label: Text(
              isCalling
                  ? context.tr('ui_chat_end_call_005e85')
                  : context.tr('p4_soul_voice_call'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              padding: SLSpacing.all16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4F8), Color(0xFFFFE9F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: SLRadius.xlAll,
                border: Border.all(color: const Color(0x18D81B60)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD81B60),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.ondemand_video_rounded,
                          color: Colors.white,
                        ),
                      ),
                      SLSpacing.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              L10nScope.of(context).format(
                                'ui_chat_watch_with_value1_c3b958',
                                {'value1': widget.targetName},
                              ),
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: const Color(0xFF8A1E46),
                              ),
                            ),
                            SLSpacing.gapH(2),
                            Text(
                              context.tr(
                                'ui_chat_paste_a_video_or_website_link_for_c070b4',
                              ),
                              style: SLTheme.quicksand(
                                color: const Color(0xFF6D5C63),
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h12,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.sync_rounded,
                        context.tr(
                          'ui_chat_automatically_synchronize_the_current_link_18dedc',
                        ),
                      ),
                      _buildInfoChip(
                        Icons.favorite_rounded,
                        context.tr(
                          'ui_chat_please_quickly_join_the_chat_d6d57c',
                        ),
                      ),
                      _buildInfoChip(
                        Icons.smart_display_rounded,
                        context.tr('ui_chat_most_suitable_for_youtube_304fff'),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<WatchVoicePhase>(
                    valueListenable: _voiceCall,
                    builder: (context, phase, child) {
                      final isCalling = phase != WatchVoicePhase.idle;
                      if (!isCalling) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SLSpacing.h12,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: SLRadius.lgAll,
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.record_voice_over_rounded,
                                  color: Colors.green,
                                ),
                                SLSpacing.w8,
                                Expanded(
                                  child: Text(
                                    _voiceStatusText(phase),
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _micMutedVN,
                                  builder: (context, isMuted, child) {
                                    return IconButton(
                                      onPressed: _toggleMic,
                                      icon: Icon(
                                        isMuted ? Icons.mic_off : Icons.mic,
                                        color: isMuted
                                            ? Colors.red
                                            : Colors.green.shade700,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SLSpacing.h12,
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    style: SLTheme.quicksand(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'ui_chat_paste_the_video_or_website_link_c57bcb',
                      ),
                      hintText: context.tr(
                        'ui_chat_youtube_com_tiktok_com_vnexpress_net_774b33',
                      ),
                      labelStyle: SLTheme.quicksand(
                        fontWeight: FontWeight.w800,
                      ),
                      hintStyle: SLTheme.quicksand(fontWeight: FontWeight.w700),
                      prefixIcon: const Icon(
                        Icons.link_rounded,
                        color: Color(0xFFD81B60),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: SLRadius.lgAll,
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: SLRadius.lgAll,
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: SLRadius.lgAll,
                        borderSide: const BorderSide(
                          color: Color(0xFFD81B60),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  SLSpacing.h12,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr(
                          'ui_chat_paste_a_video_or_website_link_to_1c7cc5',
                        ),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                          fontSize: 12.5,
                        ),
                      ),
                      SLSpacing.h8,
                      ElevatedButton.icon(
                        onPressed: _shareCurrentUrl,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD81B60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.lgAll,
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: Text(
                          context.tr('ui_chat_share_links_16f770'),
                          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h12,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: SLRadius.lgAll,
                      border: Border.all(color: const Color(0x14D81B60)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: hasUrl
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SLSpacing.w8,
                        Expanded(
                          child: Text(
                            hasUrl
                                ? L10nScope.of(context).format(
                                    'ui_chat_sharing_value1_0fb070',
                                    {'value1': _currentUrl},
                                  )
                                : context.tr(
                                    'ui_chat_no_links_have_been_shared_in_this_144603',
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6D5C63),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: SLRadius.xlAll,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (_isVideoPlayer &&
                        _videoPlayerController != null &&
                        _videoPlayerController!.value.isInitialized)
                      GestureDetector(
                        onTap: () {
                          if (_videoPlayerController!.value.isPlaying) {
                            _videoPlayerController!.pause();
                          } else {
                            _videoPlayerController!.play();
                          }
                          setState(() {});
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio:
                                  _videoPlayerController!.value.aspectRatio,
                              child: RepaintBoundary(
                                child: VideoPlayer(_videoPlayerController!),
                              ),
                            ),
                            if (!_videoPlayerController!.value.isPlaying)
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (hasUrl && !kIsWeb)
                      WebViewWidget(
                        controller: _webViewController!,
                        gestureRecognizers: {
                          Factory<VerticalDragGestureRecognizer>(
                            () => VerticalDragGestureRecognizer(),
                          ),
                          Factory<HorizontalDragGestureRecognizer>(
                            () => HorizontalDragGestureRecognizer(),
                          ),
                          Factory<ScaleGestureRecognizer>(
                            () => ScaleGestureRecognizer(),
                          ),
                          Factory<TapGestureRecognizer>(
                            () => TapGestureRecognizer(),
                          ),
                          Factory<PanGestureRecognizer>(
                            () => PanGestureRecognizer(),
                          ),
                        },
                      )
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFF0F5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 44,
                                  color: Color(0xFFD81B60),
                                ),
                              ),
                              SLSpacing.h16,
                              Text(
                                context.tr(
                                  'ui_chat_there_is_no_content_to_view_yet_ec972c',
                                ),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              SLSpacing.h8,
                              Text(
                                L10nScope.of(context).format(
                                  'ui_chat_paste_a_link_and_tap_share_link_594080',
                                  {'value1': widget.targetName},
                                ),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Smooth loading indicator overlay
                    ValueListenableBuilder<bool>(
                      valueListenable: _isLoadingVN,
                      builder: (context, isLoading, child) {
                        return IgnorePointer(
                          ignoring: !isLoading,
                          child: AnimatedOpacity(
                            opacity: isLoading ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.9),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: SLRadius.lgAll,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Color(0xFFD81B60),
                                  ),
                                ),
                                SLSpacing.w8,
                                ValueListenableBuilder<double>(
                                  valueListenable: _progressVN,
                                  builder: (context, value, _) {
                                    return Text(
                                      L10nScope.of(context).format(
                                        'ui_chat_loading_value1_0250bc',
                                        {'value1': (value * 100).toInt()},
                                      ),
                                      style: SLTheme.quicksand(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF6D5C63),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    ValueListenableBuilder<bool>(
                      valueListenable: _isLoadingVN,
                      builder: (context, isLoading, child) {
                        if (!isLoading) return const SizedBox.shrink();
                        return Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ValueListenableBuilder<double>(
                            valueListenable: _progressVN,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.transparent,
                                color: const Color(0xFFD81B60),
                                minHeight: 3,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: const Color(0x18D81B60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFD81B60)),
          SLSpacing.w8,
          Text(
            label,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF7A5566),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
