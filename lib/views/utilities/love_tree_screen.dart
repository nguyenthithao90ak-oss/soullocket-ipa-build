import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/love_tree_service.dart';
import '../../core/sl_theme.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

class LoveTreeScreen extends StatefulWidget {
  final String houseId;

  const LoveTreeScreen({super.key, required this.houseId});

  @override
  State<LoveTreeScreen> createState() => _LoveTreeScreenState();
}

class _LoveTreeScreenState extends State<LoveTreeScreen>
    with SingleTickerProviderStateMixin {
  final LoveTreeService _treeService = LoveTreeService();
  bool _sending = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _readHealth(Map<dynamic, dynamic> map) {
    final raw = map['health'];
    if (raw is int) return raw.clamp(0, 100);
    if (raw is double) return raw.round().clamp(0, 100);
    return 50;
  }

  int _readLevel(Map<dynamic, dynamic> map, int health) {
    final raw = map['level'];
    if (raw is int) return raw.clamp(1, 99);
    return (1 + (health / 16).floor()).clamp(1, 99);
  }

  String _stateText(int health) {
    if (health >= 85) return 'Nở hoa rực rỡ';
    if (health >= 65) return 'Xanh tốt';
    if (health >= 40) return 'Đang lớn dần';
    if (health >= 20) return 'Hơi thiếu chăm sóc';
    return 'Đang héo úa';
  }

  Future<void> _nurture({required int water, required int fertilizer}) async {
    if (_sending) return;
    setState(() => _sending = true);
    await _treeService.nurtureTree(widget.houseId,
        waterAmount: water, fertilizerAmount: fertilizer);
    if (!mounted) return;
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'NUÔI CÂY TÌNH YÊU',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298), Color(0xFF3FA34D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Map<dynamic, dynamic>>(
            stream: _treeService.listenToTreeStatus(widget.houseId),
            builder: (context, snapshot) {
              final tree = snapshot.data ?? {};
              final health = _readHealth(tree);
              final level = _readLevel(tree, health);
              final progress = (health / 100).clamp(0.0, 1.0);

              return SingleChildScrollView(
                padding: SLSpacing.all16,
                child: Column(
                  children: [
                    _glassCard(
                      child: Column(
                        children: [
                          Text(
                            'Level $level • ${_stateText(health)}',
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                          SLSpacing.h8,
                          Text(
                            'Sức khỏe cây: $health/100',
                            style: SLTheme.quicksand(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SLSpacing.h12,
                          ClipRRect(
                            borderRadius: SLRadius.smAll,
                            child: LinearProgressIndicator(
                              minHeight: 12,
                              value: progress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFA5D6A7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SLSpacing.h16,
                    _glassCard(
                      child: GestureDetector(
                        onTap: () => _nurture(water: 2, fertilizer: 0),
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.45,
                          width: double.infinity,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _LoveTreePainter(
                                  health: health,
                                  sway: _controller.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.h16,
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sending
                                ? null
                                : () => _nurture(water: 12, fertilizer: 0),
                            icon: const Icon(Icons.water_drop,
                                color: Colors.white),
                            label: Text(
                              'Tưới nước',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF00ACC1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: SLRadius.mdAll),
                            ),
                          ),
                        ),
                        SLSpacing.w12,
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sending
                                ? null
                                : () => _nurture(water: 4, fertilizer: 10),
                            icon: const Icon(Icons.spa, color: Colors.white),
                            label: Text(
                              'Bón phân',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF6D4C41),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: SLRadius.mdAll),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h8,
                    Text(
                      'Chạm vào cây để tưới nhanh +2 sức khỏe',
                      style: SLTheme.quicksand(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: SLRadius.xlAll,
      child: Container(
        padding: SLSpacing.all16,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: SLRadius.xlAll,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: child,
      ),
    );
  }
}

class _LoveTreePainter extends CustomPainter {
  final int health;
  final double sway;

  _LoveTreePainter({required this.health, required this.sway});

  @override
  void paint(Canvas canvas, Size size) {
    final trunkPaint = Paint()..color = const Color(0xFF6D4C41);
    final leafColor = Color.lerp(const Color(0xFF8D6E63),
        const Color(0xFF43A047), (health / 100).clamp(0.0, 1.0))!;
    final leafPaint = Paint()..color = leafColor;
    final flowerPaint = Paint()..color = const Color(0xFFFFC1E3);

    final ground = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.45);
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.16, size.height * 0.82, size.width * 0.68,
            size.height * 0.13),
        ground);

    final swayOffset = math.sin(sway * math.pi * 2) * 7;
    final baseX = size.width * 0.5;
    final trunkTop = size.height * 0.42;
    final trunkBottom = size.height * 0.84;

    final trunkPath = Path()
      ..moveTo(baseX - 20, trunkBottom)
      ..quadraticBezierTo(baseX - 12 + swayOffset, size.height * 0.62,
          baseX - 8 + swayOffset, trunkTop)
      ..lineTo(baseX + 8 + swayOffset, trunkTop)
      ..quadraticBezierTo(
          baseX + 12 + swayOffset, size.height * 0.62, baseX + 20, trunkBottom)
      ..close();
    canvas.drawPath(trunkPath, trunkPaint);

    final branchPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(baseX + swayOffset, size.height * 0.53),
        Offset(baseX - 70 + swayOffset, size.height * 0.45), branchPaint);
    canvas.drawLine(Offset(baseX + swayOffset, size.height * 0.56),
        Offset(baseX + 80 + swayOffset, size.height * 0.44), branchPaint);
    canvas.drawLine(Offset(baseX + swayOffset, size.height * 0.48),
        Offset(baseX + 16 + swayOffset, size.height * 0.35), branchPaint);

    final leafCount = 18 + (health ~/ 4);
    final rnd = math.Random(health + 97);
    for (var i = 0; i < leafCount; i++) {
      final x = baseX + swayOffset + rnd.nextDouble() * 180 - 90;
      final y = size.height * 0.23 + rnd.nextDouble() * 130;
      final r = 8.0 + rnd.nextDouble() * 7;
      canvas.drawCircle(Offset(x, y), r, leafPaint);
    }

    if (health >= 82) {
      for (var i = 0; i < 12; i++) {
        final x = baseX + swayOffset + rnd.nextDouble() * 170 - 85;
        final y = size.height * 0.24 + rnd.nextDouble() * 120;
        canvas.drawCircle(Offset(x, y), 4.5, flowerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoveTreePainter oldDelegate) {
    return oldDelegate.health != health || oldDelegate.sway != sway;
  }
}
