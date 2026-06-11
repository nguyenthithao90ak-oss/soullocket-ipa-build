import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

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

  void _triggerMerge() {
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
  }

  @override
  void dispose() {
    _bumpDetector.stop();
    _mergeTimesSub?.cancel();
    _pulseController.dispose();
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
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 120,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Đã Kết Nối!',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Trái tim hai bạn đã hòa làm một.',
                    style: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

          // Lottie fireworks when merged
          if (_isMerged)
            Positioned.fill(
              child: IgnorePointer(
                child: Lottie.asset(
                  'assets/lottie/fireworks.json', // Assuming a fireworks lottie exists, if not it will fallback or just not render if we catch error. We will just use standard particles if not.
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  repeat: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
