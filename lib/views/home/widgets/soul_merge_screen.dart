import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../utils/helpers/bump_detector.dart';
import '../../../utils/services/soul_merge_service.dart';
import '../../../core/sl_theme.dart';

class SoulMergeScreen extends StatefulWidget {
  const SoulMergeScreen({super.key});

  @override
  State<SoulMergeScreen> createState() => _SoulMergeScreenState();
}

class _SoulMergeScreenState extends State<SoulMergeScreen>
    with SingleTickerProviderStateMixin {
  late BumpDetector _bumpDetector;
  final SoulMergeService _mergeService = SoulMergeService();
  StreamSubscription<Map<String, int>>? _mergeTimesSub;

  bool _isMerged = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Memory photos lists and timers
  List<String> _memoryUrls = [];
  final List<ExplodingPhoto> _activePhotos = [];
  final List<({Offset position, UniqueKey id})> _activeParticleExplosions = [];
  Timer? _explosionTimer;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bumpDetector = BumpDetector(
      threshold: 3.5, // Sensitive enough for a gentle bump
      onBump: _handleLocalBump,
    );
    _bumpDetector.start();

    // Clear previous bumps to start fresh
    unawaited(_mergeService.clearBumps());

    _mergeTimesSub = _mergeService.watchMergeTimes().listen((mergeTimes) {
      debugPrint('[SoulMergeScreen] watchMergeTimes update: $mergeTimes');
      if (mergeTimes.length >= 2) {
        final uids = mergeTimes.keys.toList();
        final time1 = mergeTimes[uids[0]]!;
        final time2 = mergeTimes[uids[1]]!;
        final diff = (time1 - time2).abs();
        debugPrint('[SoulMergeScreen] Time diff between bumps: ${diff}ms');
        // If bumped within 1.5 seconds of each other (using unified server timestamps)
        if (diff < 1500) {
          _triggerMerge();
        }
      }
    });
  }

  void _handleLocalBump() {
    if (_isMerged) return;
    debugPrint('[SoulMergeScreen] _handleLocalBump triggered (bump or tap)');
    _mergeService.reportBump();
    HapticFeedback.mediumImpact();
  }

  Future<List<String>> _fetchMemoryUrls() async {
    try {
      final houseId = await _mergeService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return const [];

      final dbRef = FirebaseDatabase.instance.ref();
      final memoriesSnap = await dbRef.child('houses/$houseId/memories').limitToLast(30).get();
      final diarySnap = await dbRef.child('houses/$houseId/diary').limitToLast(30).get();

      final urls = <String>{};
      
      void extractUrls(dynamic raw) {
        if (raw is Map) {
          raw.forEach((_, value) {
            if (value is Map) {
              final imageUrl = (value['url'] ?? value['imageUrl'] ?? value['thumbUrl'] ?? '').toString().trim();
              if (imageUrl.isNotEmpty) {
                urls.add(imageUrl);
              }
            }
          });
        }
      }

      extractUrls(memoriesSnap.value);
      extractUrls(diarySnap.value);
      return urls.toList();
    } catch (e) {
      debugPrint('[SoulMergeScreen] _fetchMemoryUrls error: $e');
      return const [];
    }
  }

  void _triggerMerge() async {
    if (_isMerged) return;
    debugPrint('[SoulMergeScreen] Merging triggered!');
    setState(() {
      _isMerged = true;
    });
    _bumpDetector.stop();
    _pulseController.stop();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      HapticFeedback.heavyImpact();
    });

    // Fetch memory urls and start explosion loop
    final urls = await _fetchMemoryUrls();
    if (mounted) {
      setState(() {
        _memoryUrls = urls;
      });
      if (_memoryUrls.isNotEmpty) {
        _startPhotoExplosions();
      }
    }
  }

  void _startPhotoExplosions() {
    _explosionTimer?.cancel();
    _spawnPhotoExplosion();
    _explosionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _spawnPhotoExplosion();
    });
  }

  void _spawnPhotoExplosion() {
    if (_memoryUrls.isEmpty) return;
    final randomUrl = _memoryUrls[_random.nextInt(_memoryUrls.length)];
    
    final size = MediaQuery.of(context).size;
    final double x = 30 + _random.nextDouble() * (size.width - 200);
    final double y = 140 + _random.nextDouble() * (size.height - 380);
    final position = Offset(x, y);

    final photo = ExplodingPhoto(
      url: randomUrl,
      position: position,
      angle: (_random.nextDouble() - 0.5) * 0.4, // Slight rotation
      targetScale: 0.8 + _random.nextDouble() * 0.4,
    );

    final particleId = UniqueKey();

    setState(() {
      _activePhotos.add(photo);
      _activeParticleExplosions.add((position: position, id: particleId));
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _activeParticleExplosions.removeWhere((item) => item.id == particleId);
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _activePhotos.removeWhere((p) => p.id == photo.id);
        });
      }
    });
  }

  @override
  void dispose() {
    _bumpDetector.stop();
    _mergeTimesSub?.cancel();
    _pulseController.dispose();
    _explosionTimer?.cancel();
    unawaited(_mergeService.clearBumps());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0533),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A0533),
                  Color(0xFF4A0033),
                ],
              ),
            ),
          ),
          
          if (!_isMerged)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _handleLocalBump,
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4F93).withValues(alpha: 0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFF4F93),
                            size: 100,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Text(
                    'Soul Merge',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Text(
                          'Hãy mở màn hình này trên cả hai máy, sau đó cụng nhẹ hai điện thoại vào nhau để ghép nối linh hồn.',
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '*(Nếu thiết bị không hỗ trợ cảm biến, chạm trực tiếp vào hình trái tim trên cả 2 máy cùng lúc để ghép nối)*',
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            color: const Color(0xFFFF7FB2),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 1. Particle explosions (behind photos)
            for (final explosion in _activeParticleExplosions)
              ParticleExplosionWidget(key: explosion.id, position: explosion.position),

            // 2. Popping Polaroids (foreground)
            for (final photo in _activePhotos)
              ExplodingPhotoWidget(key: photo.id, photo: photo),

            // 3. Merged Header Text
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Đã Kết Nối!',
                      style: SLTheme.quicksand(
                        color: const Color(0xFFFF4F93),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFF4F93).withValues(alpha: 0.5),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kỷ niệm đang tràn ngập tâm hồn hai bạn...',
                      style: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ExplodingPhoto {
  final String url;
  final Offset position;
  final double angle;
  final double targetScale;
  final UniqueKey id = UniqueKey();
  
  ExplodingPhoto({
    required this.url,
    required this.position,
    required this.angle,
    required this.targetScale,
  });
}

class ExplodingPhotoWidget extends StatefulWidget {
  final ExplodingPhoto photo;
  const ExplodingPhotoWidget({super.key, required this.photo});

  @override
  State<ExplodingPhotoWidget> createState() => _ExplodingPhotoWidgetState();
}

class _ExplodingPhotoWidgetState extends State<ExplodingPhotoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Popping entrance and fading exit
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: widget.photo.targetScale)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30, // Popping entrance in first 30% of time
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(widget.photo.targetScale),
        weight: 50, // Holds size
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.photo.targetScale, end: 0.5)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20, // Shrinks out at the end
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.photo.position.dx,
      top: widget.photo.position.dy,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: widget.photo.angle,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          width: 140,
          height: 170,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.photo.url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.purple.shade100,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Polaroid-style bottom bar with a cute heart
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF4F93),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Particle {
  final Offset velocity;
  final Color color;
  double scale;
  
  Particle({
    required this.velocity,
    required this.color,
    this.scale = 1.0,
  });
}

class ParticleExplosionWidget extends StatefulWidget {
  final Offset position;
  const ParticleExplosionWidget({super.key, required this.position});

  @override
  State<ParticleExplosionWidget> createState() => _ParticleExplosionWidgetState();
}

class _ParticleExplosionWidgetState extends State<ParticleExplosionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create 16 particles spreading outwards
    final colors = [
      const Color(0xFFFF4F93),
      const Color(0xFFFF8E53),
      const Color(0xFFFFEA79),
      const Color(0xFF84FF84),
      const Color(0xFF84D7FF),
    ];
    for (int i = 0; i < 16; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 2.0 + _random.nextDouble() * 4.0;
      _particles.add(
        Particle(
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          color: colors[_random.nextInt(colors.length)],
          scale: 3.0 + _random.nextDouble() * 4.0,
        ),
      );
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx + 70, // Center of the 140 width polaroid
      top: widget.position.dy + 85,  // Center of the 170 height polaroid
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              progress: progress,
            ),
          );
        },
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final particle in particles) {
      final offset = particle.velocity * (progress * 40.0);
      final opacity = 1.0 - progress;
      paint.color = particle.color.withValues(alpha: opacity);
      
      final radius = particle.scale * (1.0 - progress * 0.5);
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
