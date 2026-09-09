import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Conditional import – only resolves on web
import 'document_viewer_web.dart';
import 'document_html.dart';
import '../../../core/constants/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/sl_theme.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  WebViewController? _mobileController;
  String? _webViewId;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final assetPath = localizedDocumentAssetPath(
        widget.assetPath,
        languageCode: L10nService().locale.languageCode,
      );
      final raw = await rootBundle.loadString(assetPath);
      final prepared = prepareDocumentHtml(
        raw,
        publicBaseUri: Uri.parse(AppConfig.webBaseUrl),
      );

      if (kIsWeb) {
        // Generate a unique-per-instance key so the factory isn't re-registered
        final viewId =
            'sl-doc-${assetPath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
        final registeredId = createWebIframe(viewId, prepared);
        if (mounted) {
          setState(() {
            _webViewId = registeredId ?? viewId;
            _isLoading = false;
          });
        }
      } else {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) async {
                final uri = Uri.tryParse(request.url);
                if (uri?.scheme == 'mailto') {
                  try {
                    await launchUrl(uri!, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    // Địa chỉ email vẫn hiển thị để người dùng sao chép thủ công.
                  }
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onProgress: (int progress) {
                if (mounted) {
                  setState(() => _progress = progress / 100);
                }
              },
              onPageStarted: (_) {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _progress = 0.0;
                  });
                }
              },
              onPageFinished: (_) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _progress = 1.0;
                  });
                }
              },
              onWebResourceError: (_) {
                if (mounted) setState(() => _isLoading = false);
              },
            ),
          );
        // Use utf8.encode to handle special characters correctly without base64 to reduce rendering overhead
        await controller.loadHtmlString(prepared);
        if (mounted) {
          setState(() => _mobileController = controller);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_hasError) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFD81B60)),
            SLSpacing.h12,
            Text(
              context.tr('home_khngthtini_145744'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else if (kIsWeb && _webViewId != null) {
      content = HtmlElementView(viewType: _webViewId!);
    } else if (!kIsWeb && _mobileController != null) {
      content = WebViewWidget(controller: _mobileController!);
    } else {
      content = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFD81B60),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          content,
          AnimatedOpacity(
            opacity: _isLoading && !_hasError ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_isLoading || _hasError,
              child: Container(
                color: Colors.white.withValues(alpha: 0.9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFD81B60)),
                      SLSpacing.h16,
                      Text(
                        L10nService().format('home_loading_percent', {
                          'percent': (_progress * 100).toInt(),
                        }),
                        style: const TextStyle(
                          color: Color(0xFFD81B60),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!kIsWeb && _isLoading && !_hasError)
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
