import 'package:flutter/material.dart';

/// Xác nhận chỉ những hàng đã vào viewport; không coi cache/ListView tải sẵn là đã xem.
class SoulMergeMessageVisibility extends StatefulWidget {
  const SoulMergeMessageVisibility({
    super.key,
    required this.onVisible,
    required this.child,
  });
  final VoidCallback onVisible;
  final Widget child;
  @override
  State<SoulMergeMessageVisibility> createState() =>
      _SoulMergeMessageVisibilityState();
}

class _SoulMergeMessageVisibilityState extends State<SoulMergeMessageVisibility>
    with WidgetsBindingObserver {
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant SoulMergeMessageVisibility old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void didChangeMetrics() => _schedule();
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          !TickerMode.valuesOf(context).enabled ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        return;
      }
      final box = context.findRenderObject();
      if (box is! RenderBox ||
          !box.hasSize ||
          !box.attached ||
          box.size.isEmpty) {
        return;
      }
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      final view = MediaQuery.of(context);
      final screen = Rect.fromLTRB(
        0,
        view.padding.top,
        view.size.width,
        view.size.height - view.viewInsets.bottom - view.padding.bottom,
      );
      final visible = bounds.intersect(screen);
      if (!visible.isEmpty &&
          visible.height >= box.size.height * .7 &&
          visible.width > 0) {
        widget.onVisible();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return widget.child;
  }
}
