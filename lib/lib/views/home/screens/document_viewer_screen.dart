import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Conditional import – only resolves on web
import 'document_viewer_web.dart';
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
      final raw = await rootBundle.loadString(widget.assetPath);
      final processed = _processHtmlForPlatform(raw);
      final prepared = _prepareHtmlDocument(processed);

      if (kIsWeb) {
        // Generate a unique-per-instance key so the factory isn't re-registered
        final viewId =
            'sl-doc-${widget.assetPath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
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
          ..setNavigationDelegate(NavigationDelegate(
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
          ));
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

  String _prepareHtmlDocument(String html) {
    const viewport =
        '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">';
    final isIOS = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);
    final platformStyles = isIOS ? '''
  #vip, a[href="#vip"] {
    display: none !important;
  }
''' : '';
    final sharedStyles = '''
<style id="sl-inject">
  :root { color-scheme: light; }
  html, body { 
    max-width: 100vw; 
    overflow-x: hidden; 
    overflow-y: auto;
    margin: 0; 
    padding: 0;
    -webkit-overflow-scrolling: touch;
  }
  body {
    -webkit-text-size-adjust: 100%;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    background: #fff;
    color: #333;
    line-height: 1.6;
    padding: 16px;
    box-sizing: border-box;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }
  img, video, canvas, iframe { 
    max-width: 100%; 
    height: auto; 
    border-radius: 0px;
  }
  table { 
    display: block; 
    width: 100%; 
    overflow-x: auto; 
    border-collapse: collapse; 
  }
  a { 
    word-break: break-word; 
    color: #D81B60;
  }
  p, div, li, span {
    max-width: 100%;
  }
  
  /* Reset app wrapper styles if any exists in html */
  .app-wrapper, .document-container, .content-box {
    background: transparent !important;
    border-radius: 0 !important;
    box-shadow: none !important;
    padding: 0 !important;
    margin: 0 !important;
    max-width: none !important;
    border: none !important;
  }

  .page, .hero, .section, .summary-card, .feature-card, .tech-card, .callout, .contact-box, .toc a {
    background: transparent !important;
    border: none !important;
    border-radius: 0 !important;
    box-shadow: none !important;
    backdrop-filter: none !important;
  }

  .hero, .section, .summary-card, .feature-card, .tech-card, .callout, .contact-box, .toc a {
    padding: 0 !important;
    margin: 0 0 16px 0 !important;
  }

  .page {
    max-width: none !important;
    padding: 0 !important;
  }

  .hero::before,
  .hero::after {
    display: none !important;
  }

  .summary-grid,
  .feature-grid,
  .tech-grid,
  .stack,
  .toc {
    display: block !important;
    gap: 0 !important;
    margin-top: 16px !important;
  }

  .summary-card,
  .feature-card,
  .tech-card {
    margin-bottom: 14px !important;
  }
  $platformStyles
</style>
''';
    final hasHtml = RegExp(r'<html[\s>]', caseSensitive: false).hasMatch(html);
    final hasHead = RegExp(r'<head[\s>]', caseSensitive: false).hasMatch(html);
    final hasVp = RegExp(
      r'''<meta[^>]+name=["']viewport["']''',
      caseSensitive: false,
    ).hasMatch(html);

    if (hasHtml && hasHead) {
      final inject = '${hasVp ? '' : '$viewport\n'}$sharedStyles';
      return html.replaceFirst(
          RegExp(r'</head>', caseSensitive: false), '$inject</head>');
    }
    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8">
$viewport
$sharedStyles
</head><body>$html</body></html>''';
  }

  String _processHtmlForPlatform(String html) {
    final isIOS = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);
    if (!isIOS) return html;

    var result = html;

    // 1. Process huong_dan.html
    if (widget.assetPath.contains('huong_dan.html')) {
      // Hide VIP/reward/giftcode section with flexible matching.
      result = result.replaceAll(
        RegExp(
          r'''<section[^>]*id=["']vip["'][^>]*>[\s\S]*?</section>''',
          caseSensitive: false,
        ),
        '',
      );
      result = result.replaceAll(
        RegExp(
          r'<h[1-6][^>]*>\s*\d+\.?\s*VIP[^<]*</h[1-6]>[\s\S]*?(?=<h[1-6][^>]*>\s*\d+\.?\s*Khắc phục sự cố|</section>|$)',
          caseSensitive: false,
        ),
        '',
      );

      // Hide TOC/quick-nav links to VIP section.
      result = result.replaceAll(
        RegExp(
          r'''<a[^>]*href=["']#vip["'][^>]*>[\s\S]*?</a>''',
          caseSensitive: false,
        ),
        '',
      );
      result = result.replaceAll(
        RegExp(
          r'<a[^>]*>\s*\d+\.?\s*VIP[^<]*</a>',
          caseSensitive: false,
        ),
        '',
      );

      // Renumber troubleshooting heading/link if needed.
      result = result.replaceAll('7. Khắc phục sự cố', '6. Khắc phục sự cố');
      result = result.replaceAll('7. Khắc phục sự cố thường gặp', '6. Khắc phục sự cố thường gặp');

      // Remove VIP troubleshooting row.
      result = result.replaceAll(
        RegExp(
          r'<tr>\s*<td>\s*VIP[^<]*</td>[\s\S]*?</tr>',
          caseSensitive: false,
        ),
        '',
      );

      // Clean up text mentions.
      result = result
          .replaceAll(', VIP, reward', '')
          .replaceAll('và một phần trạng thái VIP.', '.')
          .replaceAll('và có thể bị giới hạn theo VIP hoặc reward.', '.')
          .replaceAll('gói VIP, ', '');
    }

    // 2. Process terms.html
    if (widget.assetPath.contains('terms.html')) {
      // Hide section 7 (vip) completely
      result = result.replaceFirst(
        RegExp(r'<section\s+class="section"\s+id="vip">[\s\S]*?</section>'), 
        ''
      );
      // Hide/remove VIP link in toc
      result = result.replaceFirst(
        RegExp(r'<a\s+href="#vip">5\. VIP, quảng cáo và phần thưởng</a>'), 
        ''
      );
      // Renumber TOC
      result = result
        .replaceAll('6. Bảo mật và thiết bị', '5. Bảo mật và thiết bị')
        .replaceAll('7. Giới hạn trách nhiệm', '6. Giới hạn trách nhiệm')
        .replaceAll('8. Liên hệ', '7. Liên hệ');
      // Renumber headings
      result = result
        .replaceAll('8. Bảo mật, khóa app và trách nhiệm của bạn', '7. Bảo mật, khóa app và trách nhiệm của bạn')
        .replaceAll('9. Sở hữu trí tuệ của SoulLocket', '8. Sở hữu trí tuệ của SoulLocket')
        .replaceAll('10. Tạm ngừng, khóa hoặc chấm dứt dịch vụ', '9. Tạm ngừng, khóa hoặc chấm dứt dịch vụ')
        .replaceAll('11. Giới hạn trách nhiệm', '10. Giới hạn trách nhiệm')
        .replaceAll('12. Chính sách liên quan', '11. Chính sách liên quan')
        .replaceAll('13. Cập nhật điều khoản', '12. Cập nhật điều khoản')
        .replaceAll('14. Liên hệ', '13. Liên hệ');
      // Clean up text mentions
      result = result
        .replaceAll(', VIP và dịch vụ hỗ trợ', ' và dịch vụ hỗ trợ')
        .replaceAll(', VIP, gọi video', ', gọi video')
        .replaceAll('<li>Tính năng VIP/Premium, quảng cáo thưởng', '<li>Quảng cáo thưởng');
    }

    // 3. Process about.html
    if (widget.assetPath.contains('about.html')) {
      // Hide VIP card
      result = result.replaceFirst(
        RegExp(r'<div\s+class="card">\s*<strong>Có lớp miễn phí, thưởng và trả phí</strong>[\s\S]*?</div>'), 
        ''
      );
      // Clean up text mentions
      result = result
        .replaceAll(', reward, VIP', '');
    }

    return result;
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
                  fontWeight: FontWeight.w700),
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
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.w900)),
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
                        L10nService().format('home_loading_percent', {'percent': (_progress * 100).toInt()}),
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
