import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/heart_burst_service.dart';

class InteractiveHeartLauncher extends StatefulWidget {
  final String houseId;
  final String role;
  final Widget child;

  const InteractiveHeartLauncher({
    super.key,
    required this.houseId,
    required this.role,
    required this.child,
  });

  @override
  State<InteractiveHeartLauncher> createState() => _InteractiveHeartLauncherState();
}

class _InteractiveHeartLauncherState extends State<InteractiveHeartLauncher>
    with TickerProviderStateMixin {
  final List<_FloatingHeartItem> _hearts = [];
  final math.Random _random = math.Random();
  StreamSubscription? _burstSub;

  @override
  void initState() {
    super.initState();
    _listenPartnerBursts();
  }

  @override
  void didUpdateWidget(covariant InteractiveHeartLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId || oldWidget.role != widget.role) {
      _listenPartnerBursts();
    }
  }

  void _listenPartnerBursts() {
    _burstSub?.cancel();
    if (widget.houseId.isEmpty) return;

    _burstSub = HeartBurstService.instance
        .streamPartnerBursts(
          houseId: widget.houseId,
          myRole: widget.role,
        )
        .listen((event) {
          if (event != null && mounted) {
            _spawnHearts(count: event.count, emoji: event.emoji);
            HapticFeedback.mediumImpact();
          }
        });
  }

  @override
  void dispose() {
    _burstSub?.cancel();
    for (final h in _hearts) {
      h.controller.dispose();
    }
    super.dispose();
  }

  void _spawnHearts({int count = 6, String emoji = '💖'}) {
    for (int i = 0; i < count; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1400 + _random.nextInt(600)),
      );

      final item = _FloatingHeartItem(
        id: UniqueKey().toString(),
        controller: ctrl,
        startX: 0.2 + _random.nextDouble() * 0.6,
        targetX: 0.1 + _random.nextDouble() * 0.8,
        size: 24.0 + _random.nextDouble() * 18.0,
        emoji: emoji,
      );

      setState(() => _hearts.add(item));

      ctrl.forward().then((_) {
        if (mounted) {
          setState(() {
            _hearts.removeWhere((h) => h.id == item.id);
          });
          ctrl.dispose();
        }
      });
    }
  }

  void _onLaunchTap() {
    HapticFeedback.lightImpact();
    _spawnHearts(count: 8, emoji: '💖');
    HeartBurstService.instance.sendHeartBurst(
      houseId: widget.houseId,
      senderRole: widget.role,
      emoji: '💖',
      count: 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        widget.child,
        // Floating hearts animation overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: _hearts.map((heart) {
                return AnimatedBuilder(
                  animation: heart.controller,
                  builder: (context, child) {
                    final progress = heart.controller.value;
                    final currentY = size.height * (1.0 - progress * 0.85);
                    final currentX = size.width *
                        (heart.startX + (heart.targetX - heart.startX) * progress);
                    final opacity = (1.0 - progress).clamp(0.0, 1.0);
                    final scale = 0.6 + 0.8 * progress;

                    return Positioned(
                      left: currentX - heart.size / 2,
                      top: currentY,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: Text(
                            heart.emoji,
                            style: TextStyle(fontSize: heart.size),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
        // Floating Launcher Button (Bottom Right)
        if (widget.houseId.isNotEmpty)
          Positioned(
            right: 18,
            bottom: MediaQuery.paddingOf(context).bottom + 85,
            child: GestureDetector(
              onTap: _onLaunchTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D75), Color(0xFFFF8A00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2D75).withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💖', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'Gõ tim nhớ bạn',
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingHeartItem {
  final String id;
  final AnimationController controller;
  final double startX;
  final double targetX;
  final double size;
  final String emoji;

  _FloatingHeartItem({
    required this.id,
    required this.controller,
    required this.startX,
    required this.targetX,
    required this.size,
    required this.emoji,
  });
}
