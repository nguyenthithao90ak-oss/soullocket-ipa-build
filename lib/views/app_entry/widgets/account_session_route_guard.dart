import 'dart:async';

import 'package:flutter/material.dart';

/// Đóng màn/dialog của phiên cũ, kể cả khi Auth thay đổi ngoài nút đăng xuất.
class AccountSessionRouteGuard extends StatefulWidget {
  const AccountSessionRouteGuard({
    super.key,
    required this.uidChanges,
    required this.initialUid,
    required this.child,
  });

  final Stream<String?> uidChanges;
  final String? initialUid;
  final Widget child;

  @override
  State<AccountSessionRouteGuard> createState() => _AccountSessionRouteGuardState();
}

class _AccountSessionRouteGuardState extends State<AccountSessionRouteGuard> {
  StreamSubscription<String?>? _subscription;
  String? _uid;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _uid = widget.initialUid;
    _subscribe();
  }

  void _subscribe() {
    _subscription = widget.uidChanges.listen((nextUid) {
      if (nextUid == _uid) return;
      final hadAccount = _uid != null;
      _uid = nextUid;
      if (!hadAccount) return;
      final revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
        Navigator.maybeOf(context, rootNavigator: true)
            ?.popUntil((route) => route.isFirst);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  @override
  void didUpdateWidget(covariant AccountSessionRouteGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uidChanges != widget.uidChanges) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
