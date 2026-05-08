import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/services/admob_service.dart';
import 'package:soullocket_app/utils/web_helpers.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../../core/sl_theme.dart';

class WebUrlViewerScreen extends StatefulWidget {
  final String title;
  final String url;
  final bool isLocalAsset;
  final bool immersive;
  final String? initialJavaScript;

  const WebUrlViewerScreen({
    super.key,
    required this.title,
    required this.url,
    this.isLocalAsset = false,
    this.immersive = false,
    this.initialJavaScript,
  });

  @override
  State<WebUrlViewerScreen> createState() => _WebUrlViewerScreenState();
}

class _WebUrlViewerScreenState extends State<WebUrlViewerScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0.0;
  String? _loadError;
  late final String _viewId;
  late final String _normalizedMobileAssetPath;
  late final String _normalizedWebAssetPath;

  String _normalizeAssetPath(String path) {
    return path.replaceAll('\\', '/');
  }

  String _assetPathForMobile(String path) {
    final normalized = _normalizeAssetPath(path);
    return normalized.startsWith('assets/') ? normalized : 'assets/$normalized';
  }

  String _assetPathForWeb(String path) {
    final normalized = _normalizeAssetPath(path);
    return normalized.startsWith('assets/')
        ? normalized.substring('assets/'.length)
        : normalized;
  }

  bool get _isTrustedContent => widget.isLocalAsset;

  bool _isHttpsUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        (uri.host.isNotEmpty || uri.authority.isNotEmpty);
  }

  bool _isExpectedLocalAssetUrl(String url) {
    final lowerUrl = url.toLowerCase();
    final mobileAssetPath = _normalizedMobileAssetPath.toLowerCase();
    final webAssetPath = _normalizedWebAssetPath.toLowerCase();
    final encodedMobileAssetPath =
        Uri.encodeFull(_normalizedMobileAssetPath).toLowerCase();
    final encodedWebAssetPath =
        Uri.encodeFull(_normalizedWebAssetPath).toLowerCase();

    if (lowerUrl.startsWith('file:///android_asset/flutter_assets/')) {
      return lowerUrl.contains('/flutter_assets/$mobileAssetPath') ||
          lowerUrl.contains('/flutter_assets/$encodedMobileAssetPath');
    }

    if (lowerUrl.startsWith('flutter-asset://')) {
      return lowerUrl.contains(mobileAssetPath) ||
          lowerUrl.contains(encodedMobileAssetPath);
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (host == 'appassets.androidplatform.net' ||
        host == 'localhost' ||
        host == '127.0.0.1') {
      return path.contains(mobileAssetPath) ||
          path.contains(webAssetPath) ||
          path.contains(encodedMobileAssetPath) ||
          path.contains(encodedWebAssetPath);
    }

    return false;
  }

  bool _isAllowedNavigation(String url) {
    if (widget.isLocalAsset) {
      return _isExpectedLocalAssetUrl(url);
    }

    return _isHttpsUrl(url);
  }

  void _setLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _loadError = message;
      _isLoading = false;
      _progress = 0.0;
    });
  }

  Future<void> _applyInitialJavaScript() async {
    if (kIsWeb) return;
    final js = widget.initialJavaScript?.trim() ?? '';
    if (js.isEmpty) return;
    try {
      await _controller?.runJavaScript(js);
    } catch (_) {}
  }

  WebViewController _createController() {
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: false,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{
          PlaybackMediaTypes.audio,
          PlaybackMediaTypes.video,
        },
      );
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);

    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    if (_isTrustedContent) {
      controller.addJavaScriptChannel(
        'FlutterGameChannel',
        onMessageReceived: (message) {
          if (!mounted) return;
          if (_isMessage(message.message, 'soul_game_close')) {
            Navigator.of(context).maybePop();
          } else if (_isMessage(message.message, 'soul_game_request_revive')) {
            _handleRevive();
          }
        },
      );
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          if (_isAllowedNavigation(request.url)) {
            return NavigationDecision.navigate;
          }

          debugPrint('🚨 [Security] Chặn mở URL không an toàn: ${request.url}');
          return NavigationDecision.prevent;
        },
        onProgress: (int progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress / 100;
          });
        },
        onPageStarted: (_) {
          if (!mounted) return;
          setState(() {
            _loadError = null;
            _isLoading = true;
            _progress = 0.0;
          });
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _progress = 1.0;
          });
          _applyInitialJavaScript();
        },
        onWebResourceError: (error) {
          _setLoadError('Không thể tải nội dung web an toàn.');
        },
      ),
    );

    return controller;
  }

  bool _isMessage(Object? data, String action) {
    if (data == action) return true;
    if (data is Map && data['type'] == action) return true;
    return false;
  }

  Future<void> _handleRevive() async {
    if (kIsWeb) {
      // Trên Web: Hồi sinh ngay lập tức không cần xem quảng cáo
      sendWebMessageToIframe(_viewId, '{"action":"revive"}');
      return;
    }

    final adMob = AdMobService();
    setState(() {
      _isLoading = true;
    });
    final success = await adMob.showRewardedAd();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      _controller?.runJavaScript('if(window.Game) { window.Game.revive(); }');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chưa hoàn thành video, không thể hồi sinh.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _normalizedMobileAssetPath = _assetPathForMobile(widget.url);
    _normalizedWebAssetPath = _assetPathForWeb(widget.url);

    if (kIsWeb) {
      if (!widget.isLocalAsset && !_isHttpsUrl(widget.url)) {
        _isLoading = false;
        _loadError = 'Chỉ hỗ trợ liên kết HTTPS an toàn.';
        _viewId = 'iframe-blocked-${DateTime.now().millisecondsSinceEpoch}';
        return;
      }

      registerWebMessageHandler((data) {
        if (!mounted) return;
        if (_isMessage(data, 'soul_game_close')) {
          Navigator.of(context).maybePop();
        } else if (_isMessage(data, 'soul_game_request_revive')) {
          _handleRevive();
        }
      });
      _viewId = 'iframe-${DateTime.now().millisecondsSinceEpoch}';
      registerWebView(
        _viewId,
        widget.isLocalAsset ? _normalizedWebAssetPath : widget.url,
        isLocalAsset: widget.isLocalAsset,
        allow:
            'autoplay; fullscreen; microphone; camera; midi; vr; accelerometer; gyroscope; payment; ambient-light-sensor; encrypted-media; usb',
      );
      _isLoading = false;
    } else {
      _controller = _createController();

      if (widget.isLocalAsset) {
        _controller?.loadFlutterAsset(_normalizedMobileAssetPath);
      } else if (_isHttpsUrl(widget.url)) {
        _controller?.loadRequest(Uri.parse(widget.url));
      } else {
        _loadError = 'Chỉ hỗ trợ liên kết HTTPS an toàn.';
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      clearWebMessageHandler();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: widget.immersive,
      appBar: widget.immersive
          ? null
          : AppBar(
              title: Text(widget.title),
              backgroundColor: const Color(0xFFD81B60),
              foregroundColor: Colors.white,
            ),
      body: Stack(
        children: [
          if (_loadError != null)
            Center(
              child: Padding(
                padding: SLSpacing.all24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFD81B60),
                      size: 44,
                    ),
                    SLSpacing.h16,
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD81B60),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_loadError == null && kIsWeb) HtmlElementView(viewType: _viewId),
          if (_loadError == null && !kIsWeb && _controller != null)
            WebViewWidget(
              controller: _controller!,
            ),

          // Smooth loading indicator overlay (Removed blocking black screen)
          if (kIsWeb && _isLoading && _loadError == null)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: SLRadius.lgAll,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFD81B60),
                    ),
                    SLSpacing.h16,
                    Text(
                      'Đang tải...',
                      style: TextStyle(
                        color: Color(0xFFD81B60),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Linear progress bar at the top
          if (!kIsWeb && _isLoading && _loadError == null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                color: const Color(0xFFD81B60),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}
