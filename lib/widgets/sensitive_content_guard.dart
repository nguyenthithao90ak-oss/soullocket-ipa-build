import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/services/sensitive_content_service.dart';

class SensitiveContentGuard extends StatefulWidget {
  const SensitiveContentGuard({
    super.key,
    required this.child,
    this.hideOverlays = true,
  });

  final Widget child;
  final bool hideOverlays;

  @override
  State<SensitiveContentGuard> createState() => _SensitiveContentGuardState();
}

class _SensitiveContentGuardState extends State<SensitiveContentGuard>
    with WidgetsBindingObserver {
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isRegistered = true;
    unawaited(
      SensitiveContentService.instance.pushScope(
        hideOverlays: widget.hideOverlays,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SensitiveContentGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRegistered || oldWidget.hideOverlays == widget.hideOverlays) {
      return;
    }
    unawaited(_swapProtection(oldWidget.hideOverlays, widget.hideOverlays));
  }

  Future<void> _swapProtection(
      bool oldHideOverlays, bool newHideOverlays) async {
    await SensitiveContentService.instance.popScope(
      hideOverlays: oldHideOverlays,
    );
    await SensitiveContentService.instance.pushScope(
      hideOverlays: newHideOverlays,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRegistered && state == AppLifecycleState.resumed) {
      unawaited(SensitiveContentService.instance.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isRegistered) {
      unawaited(
        SensitiveContentService.instance.popScope(
          hideOverlays: widget.hideOverlays,
        ),
      );
      _isRegistered = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
