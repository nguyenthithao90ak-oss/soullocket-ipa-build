// ignore: avoid_web_libraries_in_flutter
import '../../utils/web_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/sl_theme.dart';
import '../../services/image_picker_recovery_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/permission_helper.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';

class LoveSurpriseScreen extends StatefulWidget {
  final String houseId;

  const LoveSurpriseScreen({super.key, required this.houseId});

  @override
  State<LoveSurpriseScreen> createState() => _LoveSurpriseScreenState();
}

class _LoveSurpriseScreenState extends State<LoveSurpriseScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isRequestingPermissions = false;
  bool _permissionDenied = false;
  final ValueNotifier<double> _progressVN = ValueNotifier<double>(0.0);
  String? _webIframeUrl;
  final String _iframeId = '3d-iframe-view';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsAndInit();
    });
  }

  @override
  void dispose() {
    _progressVN.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionsAndInit() async {
    if (_controller != null || _isRequestingPermissions) return;
    if (kIsWeb) {
      _initWebView();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isRequestingPermissions = true;
        _permissionDenied = false;
      });
    }

    final granted = await PermissionHelper.requestAllWithDisclosure(
      context,
      [Permission.camera],
      title: context.tr('util_chophpcame_4e6a7a'),
      disclosure:
          context.tr('util_tnhnngbtng_cd452c'),
    );

    if (!mounted) return;
    if (!granted) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRequestingPermissions = false;
          _permissionDenied = true;
        });
      }
      return;
    }

    _initWebView();
  }

  // ignore: unused_element
  Future<bool?> _showPermissionDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text(context.tr('util_chophpcame_4e6a7a')),
        content: Text(
          context.tr('util_tnhnngbtng_cd452c'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('util_sau_8a3721')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('util_tiptc_555f1f')),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    final picker = ImagePicker();
    if (params.acceptTypes.any((type) => type.contains('image'))) {
      if (params.mode == FileSelectorMode.openMultiple) {
        final List<XFile> images = await AppLifecyclePresenceGuard.guard(
          () => ImagePickerRecoveryService.instance.pickMultiImage(
            picker: picker,
          ),
        );
        return images.map((image) => image.path).toList();
      } else {
        final XFile? image = await AppLifecyclePresenceGuard.guard(
          () => ImagePickerRecoveryService.instance.pickImage(
            picker: picker,
            source: ImageSource.gallery,
          ),
        );
        return image == null ? [] : [image.path];
      }
    }
    return [];
  }

  void _initWebView() async {
    final errFallback = context.tr('util_khngthtitr_27cecf');
    try {
      if (kIsWeb) {
        _webIframeUrl =
            '3d.html?v=20260422c&hid=${Uri.encodeComponent(widget.houseId)}';
        registerWebView(
          _iframeId,
          _webIframeUrl!,
          isLocalAsset: true,
          allow:
              'autoplay; fullscreen; camera; accelerometer; gyroscope; encrypted-media',
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final controller = WebViewController(
        onPermissionRequest: (request) {
          request.grant();
        },
      )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (!mounted) return;
              _progressVN.value = progress / 100;
            },
            onPageStarted: (_) {
              if (!mounted) return;
              _progressVN.value = 0.0;
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              if (mounted) {
                _progressVN.value = 1.0;
                setState(() {
                  _isLoading = false;
                });
                // Hide the web's back button since we have flutter's appbar
                _controller?.runJavaScript(
                    "var btn = document.getElementById('back-home-btn'); if(btn) btn.style.display = 'none';");
              }
            },
          ),
        );

      if (controller.platform is AndroidWebViewController) {
        if (kDebugMode) {
          AndroidWebViewController.enableDebugging(true);
        }
        (controller.platform as AndroidWebViewController)
            .setOnShowFileSelector(_androidFilePicker);
      }

      // In Android/iOS, if we load HTML via String, WebView might fail to load local assets (like 3D models/images)
      // because the base URL is not set to the assets folder.
      // So we load it via Flutter's local asset URL pattern
      await controller.loadFlutterAsset('assets/3d.html');

      if (mounted) {
        if (!mounted) return;
        setState(() {
          _controller = controller;
          _isRequestingPermissions = false;
          _permissionDenied = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi load HTML: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: errFallback,
      ).message}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRequestingPermissions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showBlockingLoader =
        !kIsWeb && _isLoading && _controller == null;
    final bool showTopProgress = !kIsWeb && _isLoading && _controller != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!kIsWeb && _controller == null && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: SLRadius.xlAll,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Padding(
                    padding: SLSpacing.all20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFFd4af37),
                          size: 36,
                        ),
                        SLSpacing.h12,
                        Text(
                          context.tr('util_cnquyncame_93ab68'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SLSpacing.h8,
                        Text(
                          _permissionDenied
                              ? context.tr('util_bnchacpquy_baadfd')
                              : context.tr('util_quynschcxi_8badae'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        SLSpacing.h16,
                        FilledButton(
                          onPressed: _requestPermissionsAndInit,
                          child: Text(context.tr('util_cpquynngay_9d73e5')),
                        ),
                        if (_permissionDenied) ...[
                          SLSpacing.h8,
                          TextButton(
                            onPressed: () {
                              AppLifecyclePresenceGuard.guard(
                                openAppSettings,
                              );
                            },
                            child: Text(context.tr('util_mcitngdng_12ea88')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (kIsWeb && _webIframeUrl != null)
            HtmlElementView(viewType: _iframeId),
          if (!kIsWeb && _controller != null)
            WebViewWidget(
              controller: _controller!,
              gestureRecognizers: {
                Factory<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer()),
                Factory<HorizontalDragGestureRecognizer>(
                    () => HorizontalDragGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
                Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
              },
            ),
          IgnorePointer(
            ignoring: !showBlockingLoader,
            child: AnimatedOpacity(
              opacity: showBlockingLoader ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFd4af37)),
                      SLSpacing.h16,
                      ValueListenableBuilder<double>(
                          valueListenable: _progressVN,
                          builder: (context, value, _) {
                            return Text(
                              L10nService().format('util_loading_3d_percent', {'percent': (value * 100).toInt()}),
                              style: const TextStyle(
                                color: Color(0xFFd4af37),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showTopProgress)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                  valueListenable: _progressVN,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.transparent,
                      color: const Color(0xFFd4af37),
                      minHeight: 3,
                    );
                  }),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.36),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}