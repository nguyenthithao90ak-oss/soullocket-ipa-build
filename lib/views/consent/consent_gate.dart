import 'package:flutter/material.dart';

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
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DocumentViewerScreen(title: title, assetPath: assetPath),
    ),
  );
}

class _ConsentGateState extends State<ConsentGate> {
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
        final result = await _showStartupConsentDialog();
        if (result == null || !mounted) return;
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
      barrierColor: const Color(0xFF18191B),
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
