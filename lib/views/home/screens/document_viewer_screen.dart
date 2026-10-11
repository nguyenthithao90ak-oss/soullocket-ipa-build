import 'dart:convert';

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
import 'widgets/reader_surface_design.dart';

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
  String? _loadedHtml;
  String? _readerCss;
  int _appearanceRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshReaderAppearance();
  }

  Future<void> _refreshReaderAppearance() async {
    final html = _loadedHtml;
    if (html == null || !mounted) return;
    final appearance = DocumentReaderAppearance.of(context);
    final css = appearance.css;
    if (css == _readerCss) return;
    if (kIsWeb) {
      final viewId =
          'sl-doc-reader-${identityHashCode(this)}-${++_appearanceRevision}';
      final registeredId = createWebIframe(viewId, appearance.applyTo(html));
      if (!mounted) return;
      setState(() {
        _readerCss = css;
        _webViewId = registeredId ?? viewId;
      });
      return;
    }
    final controller = _mobileController;
    if (controller == null) return;
    final revision = ++_appearanceRevision;
    final background = ReaderSurfacePalette.of(context).canvas;
    try {
      await controller.setBackgroundColor(background);
      if (!mounted || revision != _appearanceRevision) return;
      // Chỉ đổi CSS để giữ nguyên vị trí đọc và không điều hướng lại tài liệu.
      await controller.runJavaScript('''
(function () {
  var style = document.getElementById('sl-reader-appearance');
  if (!style) {
    style = document.createElement('style');
    style.id = 'sl-reader-appearance';
    document.head.appendChild(style);
  }
  style.textContent = ${jsonEncode(css)};
})();
''');
      if (mounted && revision == _appearanceRevision) _readerCss = css;
    } catch (_) {
      // Giữ nguyên trang đang đọc nếu bridge native chưa sẵn sàng.
    }
  }

  Future<void> _loadContent() async {
    try {
      final assetPath = localizedDocumentAssetPath(
        widget.assetPath,
        languageCode: L10nService().localeCode,
      );
      final raw = await rootBundle.loadString(assetPath);
      final prepared = prepareDocumentHtml(
        raw,
        publicBaseUri: Uri.parse(AppConfig.webBaseUrl),
      );
      if (!mounted) return;
      _loadedHtml = prepared;
      final appearance = DocumentReaderAppearance.of(context);
      _readerCss = appearance.css;
      final styledHtml = appearance.applyTo(prepared);
      final background = ReaderSurfacePalette.of(context).canvas;

      if (kIsWeb) {
        // Generate a unique-per-instance key so the factory isn't re-registered
        final viewId =
            'sl-doc-${assetPath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
        final registeredId = createWebIframe(viewId, styledHtml);
        if (mounted) {
          setState(() {
            _webViewId = registeredId ?? viewId;
            _isLoading = false;
          });
        }
      } else {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(background)
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
        await controller.loadHtmlString(styledHtml);
        if (mounted) {
          setState(() => _mobileController = controller);
          _refreshReaderAppearance();
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
    final palette = ReaderSurfacePalette.of(context);
    Widget content;

    if (_hasError) {
      content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: palette.accent,
              ),
              SLSpacing.h12,
              Text(
                context.tr('home_khngthtini_145744'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  height: 1.5,
                  color: palette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
      backgroundColor: palette.canvas,
      appBar: ReaderSurfacePalette.appBar(context, title: widget.title),
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            ExcludeSemantics(
              excluding: !_isLoading || _hasError,
              child: AnimatedOpacity(
                opacity: _isLoading && !_hasError ? 1.0 : 0.0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_isLoading || _hasError,
                  child: ColoredBox(
                    color: palette.canvas.withValues(alpha: .94),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: palette.accent),
                            SLSpacing.h16,
                            Text(
                              L10nService().format('home_loading_percent', {
                                'percent': (_progress * 100).toInt(),
                              }),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                color: palette.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  color: palette.accent,
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
