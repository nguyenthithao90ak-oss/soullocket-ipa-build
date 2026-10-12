import 'package:flutter/material.dart';

/// Tranh mặc định cũng là nền dự phòng khi ảnh riêng chưa tải được.
class DefaultHomeBackgroundImage extends StatelessWidget {
  const DefaultHomeBackgroundImage({super.key});

  static const assetPath = 'assets/images/home/home_default_canvas_couple.webp';

  @override
  Widget build(BuildContext context) => Image.asset(
    assetPath,
    fit: BoxFit.cover,
    filterQuality: FilterQuality.low,
    cacheWidth: 1080,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF8EEE3)),
  );
}

/// Giữ ảnh đã giải mã trong lúc tải ảnh mới, không nhận kết quả phiên cũ.
class HomeBackgroundImage extends StatefulWidget {
  const HomeBackgroundImage({
    super.key,
    required this.scopeKey,
    required this.imageKey,
    required this.loadImage,
  });

  final String scopeKey;
  final String imageKey;
  final Future<ImageProvider<Object>> Function() loadImage;

  @override
  State<HomeBackgroundImage> createState() => _HomeBackgroundImageState();
}

class _HomeBackgroundImageState extends State<HomeBackgroundImage> {
  ImageProvider<Object>? _provider;
  ImageProvider<Object>? _decodedProvider;
  int _generation = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant HomeBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey) {
      _decodedProvider = null;
    }
    if (oldWidget.scopeKey != widget.scopeKey ||
        oldWidget.imageKey != widget.imageKey) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final generation = ++_generation;
    _provider = null;
    _failed = false;
    try {
      final provider = await widget.loadImage();
      if (!mounted || generation != _generation) return;
      setState(() => _provider = provider);
    } catch (_) {
      // Lỗi mạng có thể chứa URL đã ký; không ghi lỗi hoặc URL ra log.
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _decodedProvider = null;
      });
    }
  }

  Widget _previousOrDefault() {
    final previous = _decodedProvider;
    if (_failed || previous == null) return const DefaultHomeBackgroundImage();
    return Image(
      image: previous,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const DefaultHomeBackgroundImage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return _previousOrDefault();
    final generation = _generation;
    return Image(
      key: ValueKey((widget.scopeKey, widget.imageKey, generation)),
      image: provider,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, synchronous) {
        if (frame == null && !synchronous) return _previousOrDefault();
        // Chỉ frame của ảnh mới được xác nhận; frame của fallback không tính.
        _decodedProvider = provider;
        return child;
      },
      errorBuilder: (_, _, _) => const DefaultHomeBackgroundImage(),
    );
  }
}
