import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SnowGlobePhotoItem {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  String url;

  SnowGlobePhotoItem({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.url,
  });
}

class SnowGlobePhotoLayer extends StatefulWidget {
  final List<String> photoUrls;
  final double circleSize;
  final bool enableMotion;

  const SnowGlobePhotoLayer({
    super.key,
    required this.photoUrls,
    required this.circleSize,
    this.enableMotion = true,
  });

  @override
  State<SnowGlobePhotoLayer> createState() => _SnowGlobePhotoLayerState();
}

class _SnowGlobePhotoLayerState extends State<SnowGlobePhotoLayer>
    with TickerProviderStateMixin {
  late List<SnowGlobePhotoItem> _items;
  Ticker? _ticker;
  StreamSubscription? _accelSub;

  double _gravityX = 0;
  double _gravityY = 9.81; // default gravity down
  final double _friction = 0.985;
  final double _restitution = 0.5; // bounce factor

  @override
  void initState() {
    super.initState();
    _initItems();
    if (widget.enableMotion) {
      _startPhysics();
    }
  }

  void _initItems() {
    _items = [];
    final random = Random();
    final itemRadius = widget.circleSize * 0.12;
    for (int i = 0; i < widget.photoUrls.length; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final r = random.nextDouble() * (widget.circleSize / 2 * 0.5);
      _items.add(SnowGlobePhotoItem(
        x: r * cos(angle),
        y: r * sin(angle),
        vx: (random.nextDouble() - 0.5) * 50,
        vy: (random.nextDouble() - 0.5) * 50,
        radius: itemRadius,
        url: widget.photoUrls[i],
      ));
    }
  }

  void _startPhysics() {
    _accelSub = accelerometerEventStream().listen((event) {
      if (mounted) {
        _gravityX = -event.x;
        _gravityY = event.y;
      }
    });

    _ticker = createTicker(_onTick)..start();
  }

  void _stopPhysics() {
    _accelSub?.cancel();
    _accelSub = null;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _items.isEmpty) return;

    const dt = 1 / 60.0;
    const double gravityMultiplier = 150.0;

    for (var item in _items) {
      item.vx += _gravityX * gravityMultiplier * dt;
      item.vy += _gravityY * gravityMultiplier * dt;

      item.vx *= _friction;
      item.vy *= _friction;

      item.x += item.vx * dt;
      item.y += item.vy * dt;
    }

    final containerRadius = widget.circleSize / 2;

    // Boundary collision
    for (var item in _items) {
      final dist = sqrt(item.x * item.x + item.y * item.y);
      if (dist + item.radius > containerRadius) {
        final overlap = (dist + item.radius) - containerRadius;
        if (dist > 0) {
          final nx = item.x / dist;
          final ny = item.y / dist;
          item.x -= nx * overlap;
          item.y -= ny * overlap;

          final dot = item.vx * nx + item.vy * ny;
          if (dot > 0) {
            item.vx -= (1 + _restitution) * dot * nx;
            item.vy -= (1 + _restitution) * dot * ny;
          }
        }
      }
    }

    // Photo-to-photo collision
    for (int i = 0; i < _items.length; i++) {
      for (int j = i + 1; j < _items.length; j++) {
        final itemA = _items[i];
        final itemB = _items[j];

        final dx = itemB.x - itemA.x;
        final dy = itemB.y - itemA.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = itemA.radius + itemB.radius;

        if (dist < minDist && dist > 0) {
          final overlap = minDist - dist;
          final nx = dx / dist;
          final ny = dy / dist;

          itemA.x -= nx * overlap * 0.5;
          itemA.y -= ny * overlap * 0.5;
          itemB.x += nx * overlap * 0.5;
          itemB.y += ny * overlap * 0.5;

          final relVx = itemB.vx - itemA.vx;
          final relVy = itemB.vy - itemA.vy;
          final dot = relVx * nx + relVy * ny;

          if (dot < 0) {
            final impulse = -(1 + _restitution) * dot * 0.5;
            itemA.vx -= impulse * nx;
            itemA.vy -= impulse * ny;
            itemB.vx += impulse * nx;
            itemB.vy += impulse * ny;
          }
        }
      }
    }

    // Safety guard against NaN which causes layout crashes (e.g. on emulators)
    final double maxBounds = widget.circleSize * 2.0;
    for (var item in _items) {
      if (item.x.isNaN || item.x.isInfinite) item.x = 0;
      if (item.y.isNaN || item.y.isInfinite) item.y = 0;
      if (item.vx.isNaN || item.vx.isInfinite) item.vx = 0;
      if (item.vy.isNaN || item.vy.isInfinite) item.vy = 0;

      // Cực kỳ quan trọng: Giới hạn toạ độ để chống văng app khi giả lập gửi event siêu lớn
      item.x = item.x.clamp(-maxBounds, maxBounds);
      item.y = item.y.clamp(-maxBounds, maxBounds);
      item.vx = item.vx.clamp(-5000.0, 5000.0);
      item.vy = item.vy.clamp(-5000.0, 5000.0);
    }

    setState(() {});
  }

  @override
  void didUpdateWidget(covariant SnowGlobePhotoLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableMotion != oldWidget.enableMotion) {
      if (widget.enableMotion) {
        _startPhysics();
      } else {
        _stopPhysics();
      }
    }

    bool sizeChanged = widget.circleSize != oldWidget.circleSize;
    if (sizeChanged) {
      final newItemRadius = widget.circleSize * 0.12;
      for (var item in _items) {
        item.radius = newItemRadius;
      }
    }

    if (widget.photoUrls.length != oldWidget.photoUrls.length) {
      _initItems();
    } else {
      bool changed = sizeChanged;
      for (int i = 0; i < widget.photoUrls.length; i++) {
        if (_items.length > i && _items[i].url != widget.photoUrls[i]) {
          _items[i].url = widget.photoUrls[i];
          changed = true;
        }
      }
      if (changed && mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _stopPhysics();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: widget.circleSize,
      height: widget.circleSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: _items.map((item) {
          return Positioned(
            left: (widget.circleSize / 2) + item.x - item.radius,
            top: (widget.circleSize / 2) + item.y - item.radius,
            width: item.radius * 2,
            height: item.radius * 2,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  memCacheWidth: 200, // Tối ưu RAM: chỉ nạp ảnh nháp 200px
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFFFE3EC),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFFF5E92),
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
