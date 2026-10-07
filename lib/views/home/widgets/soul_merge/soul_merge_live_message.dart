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

class _SoulMergeLiveMessageState extends State<SoulMergeLiveMessage> {
  StreamSubscription<Map<String, dynamic>?>? _subscription;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    if (!widget.enabled) return;
    _subscription = widget
        .watch(widget.messageId)
        .listen(
          (message) {
            if (mounted) widget.onChanged(widget.messageId, message);
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
      _subscription?.cancel();
      _bind();
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
