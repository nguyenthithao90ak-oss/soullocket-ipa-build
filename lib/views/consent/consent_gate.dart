import 'package:flutter/material.dart';
import '../../core/sl_route.dart';

import '../../utils/services/consent_service.dart';
import '../home/screens/document_viewer_screen.dart';

import '../../utils/app_error_mapper.dart';
import 'widgets/startup_privacy_dialog.dart';

part 'consent_gate/models/consent_models.dart';

class ConsentGate extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onReady;

  const ConsentGate({super.key, required this.child, this.onReady});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

Future<void> _openDoc(
  BuildContext context,
  String title,
  String assetPath,
) async {
  await slPush<void>(
    context,
    DocumentViewerScreen(title: title, assetPath: assetPath),
  );
}

class _ConsentGateState extends State<ConsentGate> {
  static final _pendingDialogs = Expando<Future<_StartupConsentResult?>>();
  final ConsentService _consentService = ConsentService();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      _ensureConsent();
    });
  }

  Future<void> _ensureConsent() async {
    if (_running) return;
    _running = true;
    try {
      if (!mounted) return;
      var hasStartupConsent = _consentService.hasValidConsentSync();
      if (!hasStartupConsent) {
        hasStartupConsent = await _consentService.hasValidConsent();
      }
      if (!hasStartupConsent) {
        if (!mounted) return;
        // Đổi route đăng nhập/Home trong lúc dialog còn mở không được tạo
        // thêm một bản Điều khoản trên cùng Navigator.
        final navigator = Navigator.of(context, rootNavigator: true);
        final pending = _pendingDialogs[navigator] ??=
            _showStartupConsentDialog();
        try {
          await pending;
        } finally {
          if (identical(_pendingDialogs[navigator], pending)) {
            _pendingDialogs[navigator] = null;
          }
        }
        if (!mounted || !await _consentService.hasValidConsent()) return;
      }

      if (!mounted) return;
      Future<void>(() async {
        try {
          await widget.onReady?.call();
        } catch (e) {
          debugPrint(
            'ConsentGate onReady error: ${AppErrorMapper.resolve(e).message}',
          );
        }
      });
    } catch (e) {
      debugPrint('ConsentGate failed: ${AppErrorMapper.resolve(e).message}');
      if (!mounted) return;
    } finally {
      _running = false;
    }
  }

  Future<_StartupConsentResult?> _showStartupConsentDialog() {
    return showDialog<_StartupConsentResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: const Color(0xFFFAF7F2),
      builder: (ctx) => StartupPrivacyDialog(
        onOpenDocument: (title, path) => _openDoc(ctx, title, path),
        onContinue: (level) async {
          await _consentService.recordStartupConsent(level);
          if (ctx.mounted) {
            Navigator.of(ctx).pop(_StartupConsentResult(cookieLevel: level));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
