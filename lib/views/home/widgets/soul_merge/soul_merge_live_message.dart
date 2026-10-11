import 'dart:async';
import 'package:flutter/material.dart';

/// Chỉ nghe từng tin khi hàng đó được ListView dựng; dispose hủy listener.
class SoulMergeLiveMessage extends StatefulWidget {
  const SoulMergeLiveMessage({
    super.key,
    required this.messageId,
    required this.watch,
    required this.onChanged,
    required this.child,
    this.enabled = true,
  });
  final String messageId;
  final Stream<Map<String, dynamic>?> Function(String) watch;
  final void Function(String, Map<String, dynamic>?) onChanged;
  final Widget child;
  final bool enabled;
  @override
  State<SoulMergeLiveMessage> createState() => _SoulMergeLiveMessageState();
}

class _SoulMergeLiveMessageState extends State<SoulMergeLiveMessage>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>?>? _subscription;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncActivity();
  }

  bool get _shouldListen {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return widget.enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled;
  }

  void _syncActivity() {
    final active = mounted && _shouldListen;
    if (_active == active) return;
    _active = active;
    _subscription?.cancel();
    _subscription = null;
    if (active) _bind();
  }

  void _bind() {
    if (!_active) return;
    _subscription = widget
        .watch(widget.messageId)
        .listen(
          (message) {
            if (mounted && _active) widget.onChanged(widget.messageId, message);
          },
          onError: (Object error) {
            debugPrint('[SoulMerge] Row watch failed');
          },
        );
  }

  @override
  void didUpdateWidget(covariant SoulMergeLiveMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.messageId != widget.messageId) {
      _syncActivity();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncActivity();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
