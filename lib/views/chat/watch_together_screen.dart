import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
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
  bool _isVideoPlayer = false;
  bool _isHost = false;
  bool _isApplyingRemoteSync = false;
  int? _lastSyncedPositionBucket;
  bool? _lastSyncedIsPlaying;
  late final String _syncClientId;

  bool _lastKnownIsPlaying = false;
  Duration _lastKnownPosition = Duration.zero;
  DateTime _lastTickTime = DateTime.now();

  // Voice Call State
  final WebRTCService _webrtc = WebRTCService();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final ValueNotifier<bool> _isCallingVN = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _micMutedVN = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    AdSuppressionGuard.instance.suppressAds();
    _syncClientId =
        '${widget.myHouseId}_${DateTime.now().millisecondsSinceEpoch}';

    _remoteRenderer.initialize();
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
                    '🚨 [WatchTogether] Chặn URL không an toàn (chỉ cho phép HTTPS).');
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
    AdSuppressionGuard.instance.resumeAds();
    _localSyncDebounce?.cancel();
    _watchSubscription?.cancel();
    _urlController.dispose();
    _progressVN.dispose();

    _videoPlayerController?.removeListener(_handleVideoPlayerSyncTick);
    _videoPlayerController?.dispose();
    _remoteRenderer.dispose();
    if (_isCallingVN.value) _webrtc.hangUp();
    super.dispose();
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
      final Map<String, dynamic> data =
          decoded.map((key, value) => MapEntry(key.toString(), value));
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
    } catch (_) {}
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
    } catch (_) {
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
          'Watch together listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể đồng bộ phòng xem chung.',
          ).message}',
        );
      },
    );
  }

  Future<void> _shareCurrentUrl() async {
    final normalized = _normalizeUrl(_urlController.text);
    if (normalized == null) {
      _showSnack('Link chưa hợp lệ', isError: true);
      return;
    }

    _isHost = true;
    _resetPlaybackSyncCache();
    await _watchRef.set({
      'url': normalized,
      'sharedBy': widget.myHouseId,
      'isPlaying': false,
      'positionSec': 0.0,
      'updatedAt': ServerValue.timestamp,
      'originClientId': _syncClientId,
    });
    await _chatService.sendWatchInvite(
      widget.myHouseId,
      widget.targetHouseId,
      url: normalized,
    );
    await _loadUrl(normalized);
    _showSnack('Đã mời ${widget.targetName} vào xem chung');
  }

  Future<void> _toggleVoiceCall() async {
    if (_isCallingVN.value) {
      await _webrtc.hangUp();
      _isCallingVN.value = false;
      _micMutedVN.value = false;
      _showSnack('Đã kết thúc gọi thoại');
      return;
    }

    try {
      await _webrtc.openUserMedia(includeVideo: false);

      final roomRef = _dbRef.child('calls/$_sharedRoomId');
      final snap = await roomRef.get();
      if (snap.exists && snap.child('offer').exists) {
        await _webrtc.joinRoom(_sharedRoomId, _remoteRenderer);
      } else {
        await _webrtc.createRoom(_remoteRenderer, targetHouseId: _sharedRoomId);
      }

      _isCallingVN.value = true;
      _showSnack('Đã kết nối cuộc gọi thoại.');
    } catch (e) {
      _showSnack('Chưa thể kết nối cuộc gọi thoại lúc này. Vui lòng thử lại.',
          isError: true);
    }
  }

  void _toggleMic() {
    _micMutedVN.value = !_micMutedVN.value;
    _webrtc.toggleMic(_micMutedVN.value);
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
    _currentUrl = url;
    _urlController.text = url;
    _resetPlaybackSyncCache();

    _lastKnownIsPlaying = false;
    _lastKnownPosition = Duration.zero;
    _lastTickTime = DateTime.now();

    final isVideoFile = url.toLowerCase().endsWith('.mp4') ||
        url.contains('firebasestorage.googleapis.com');

    if (isVideoFile) {
      _isVideoPlayer = true;
      if (!kIsWeb) {
        _webViewController?.loadHtmlString(
            '<html><body style="background: black;"></body></html>');
      }
      final oldController = _videoPlayerController;
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController!.initialize();
      _videoPlayerController!.addListener(_handleVideoPlayerSyncTick);
      oldController?.dispose();
    } else {
      _isVideoPlayer = false;
      _videoPlayerController?.pause();
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
      SnackBar(
        content: Text(text),
        backgroundColor:
            isError ? const Color(0xFFD81B60) : const Color(0xFF2E7D32),
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
            'XEM CHUNG',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
        ),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _isCallingVN,
          builder: (context, isCalling, child) {
            return FloatingActionButton.extended(
              onPressed: _toggleVoiceCall,
              backgroundColor: isCalling ? Colors.red : const Color(0xFF2E7D32),
              icon: Icon(isCalling ? Icons.call_end : Icons.call),
              label: Text(
                isCalling ? 'Kết thúc gọi' : 'Gọi thoại',
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
                'Tính năng Xem Chung hiện chưa hỗ trợ trên Web.',
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
          'XEM CHUNG',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD81B60),
          ),
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _isCallingVN,
        builder: (context, isCalling, child) {
          return FloatingActionButton.extended(
            onPressed: _toggleVoiceCall,
            backgroundColor: isCalling ? Colors.red : const Color(0xFF2E7D32),
            icon: Icon(isCalling ? Icons.call_end : Icons.call),
            label: Text(
              isCalling ? 'Kết thúc gọi' : 'Gọi thoại',
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
                              'Xem cùng ${widget.targetName}',
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: const Color(0xFF8A1E46),
                              ),
                            ),
                            SLSpacing.gapH(2),
                            Text(
                              'Dán một link video hoặc website để hai bạn mở cùng lúc.',
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
                        'Tự đồng bộ link hiện tại',
                      ),
                      _buildInfoChip(
                        Icons.favorite_rounded,
                        'Mời nhanh qua đoạn chat',
                      ),
                      _buildInfoChip(
                        Icons.smart_display_rounded,
                        'Hợp với YouTube nhất',
                      ),
                    ],
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isCallingVN,
                    builder: (context, isCalling, child) {
                      if (!isCalling) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SLSpacing.h12,
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: SLRadius.lgAll,
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.record_voice_over_rounded,
                                    color: Colors.green),
                                SLSpacing.w8,
                                Expanded(
                                  child: Text(
                                    'Đang trong cuộc gọi thoại. Vui lòng nói chuyện trực tiếp.',
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
                      labelText: 'Dán link video hoặc website',
                      hintText: 'youtube.com, tiktok.com, vnexpress.net...',
                      labelStyle:
                          SLTheme.quicksand(fontWeight: FontWeight.w800),
                      hintStyle: SLTheme.quicksand(fontWeight: FontWeight.w700),
                      prefixIcon: const Icon(Icons.link_rounded,
                          color: Color(0xFFD81B60)),
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
                            color: Color(0xFFD81B60), width: 2),
                      ),
                    ),
                  ),
                  SLSpacing.h12,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cinema chỉ nhận link để xem chung, app không còn tải video từ máy lên.',
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
                          'Chia sẻ link',
                          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h12,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                                ? 'Đang chia sẻ: $_currentUrl'
                                : 'Chưa có link nào được chia sẻ trong phòng xem này.',
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
                                child: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 48),
                              ),
                          ],
                        ),
                      )
                    else if (hasUrl && !kIsWeb)
                      WebViewWidget(
                        controller: _webViewController!,
                        gestureRecognizers: {
                          Factory<VerticalDragGestureRecognizer>(
                              () => VerticalDragGestureRecognizer()),
                          Factory<HorizontalDragGestureRecognizer>(
                              () => HorizontalDragGestureRecognizer()),
                          Factory<ScaleGestureRecognizer>(
                              () => ScaleGestureRecognizer()),
                          Factory<TapGestureRecognizer>(
                              () => TapGestureRecognizer()),
                          Factory<PanGestureRecognizer>(
                              () => PanGestureRecognizer()),
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
                                'Chưa có nội dung để xem cùng',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              SLSpacing.h8,
                              Text(
                                'Dán một link rồi bấm "Chia sẻ link" để mời ${widget.targetName} vào phòng xem chung này.',
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
                                  )
                                ]),
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
                                        'Đang tải... ${(value * 100).toInt()}%',
                                        style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF6D5C63),
                                        ),
                                      );
                                    }),
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
                              }),
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
