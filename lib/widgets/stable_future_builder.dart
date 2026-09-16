import 'dart:async';
import 'package:flutter/widgets.dart';

/// Khởi tạo Future theo định danh dữ liệu, không theo mỗi lần build.
/// Đổi scope phải bỏ snapshot cũ, nhất là ảnh riêng tư/người dùng khác.
class StableFutureBuilder<T> extends StatefulWidget {
  const StableFutureBuilder({
    super.key,
    required this.requestKey,
    required this.load,
    required this.builder,
    this.initialData,
  });

  final Object requestKey;
  final Future<T> Function() load;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  State<StableFutureBuilder<T>> createState() => _StableFutureBuilderState<T>();
}

class _StableFutureBuilderState<T> extends State<StableFutureBuilder<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = Future<T>.sync(widget.load);
  }

  @override
  void didUpdateWidget(covariant StableFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) {
      _future = Future<T>.sync(widget.load);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    key: ValueKey(widget.requestKey),
    future: _future,
    initialData: widget.initialData,
    builder: widget.builder,
  );
}
