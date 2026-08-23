import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to remember whether the anniversary dialog was already shown today.
String _anniversaryShownPrefKey(int days) =>
    'anniv_shown_${days}_${DateTime.now().toIso8601String().split('T')[0]}';

/// Returns true if it is an anniversary milestone day (multiple of 100, or 30, 200, 300 … days, 1/2/3… years).
bool isAnniversaryMilestone(int days) {
  if (days <= 0) return false;
  // Every 100 days
  if (days % 100 == 0) return true;
  // Monthly milestones: ~30 days apart
  if (days % 30 == 0) return true;
  return false;
}

/// Checks if we should show the anniversary dialog today and whether it was already shown.
Future<bool> shouldShowAnniversaryDialog(int days) async {
  if (!isAnniversaryMilestone(days)) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = _anniversaryShownPrefKey(days);
    final alreadyShown = prefs.getBool(key) ?? false;
    if (!alreadyShown) {
      await prefs.setBool(key, true);
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// A beautiful full-screen celebration dialog shown on anniversary milestone days.
class AnniversaryCelebrationDialog extends StatefulWidget {
  final int days;
  final String coupleLabel; // e.g. "Bạn Nam & Bạn"
  final String dayUnit; // e.g. "ngày yêu"

  const AnniversaryCelebrationDialog({
    super.key,
    required this.days,
    required this.coupleLabel,
    required this.dayUnit,
  });

  @override
  State<AnniversaryCelebrationDialog> createState() =>
      _AnniversaryCelebrationDialogState();
}

class _AnniversaryCelebrationDialogState
    extends State<AnniversaryCelebrationDialog> with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  final Random _rng = Random(7);
  late final List<_Confetti> _confettiList;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);

    _confettiList = List.generate(40, (i) => _Confetti.random(_rng));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _particleCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.days % 365 == 0) {
      final years = widget.days ~/ 365;
      return '🎊 Tròn $years năm bên nhau! 🎊';
    }
    if (widget.days % 100 == 0) {
      return '💖 Tròn ${widget.days} ${widget.dayUnit}! 💖';
    }
    if (widget.days % 30 == 0) {
      final months = widget.days ~/ 30;
      return '🌸 Tròn $months tháng bên nhau! 🌸';
    }
    return '💝 Kỷ niệm ${widget.days} ${widget.dayUnit}! 💝';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main Card ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6FA3),
                      Color(0xFFFF3D88),
                      Color(0xFFAD1457),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3D88).withValues(alpha: 0.55),
                      blurRadius: 40,
                      spreadRadius: 4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      // Confetti layer
                      AnimatedBuilder(
                        animation: _particleCtrl,
                        builder: (_, _) {
                          return CustomPaint(
                            size: const Size(double.infinity, 380),
                            painter: _ConfettiPainter(
                              progress: _particleCtrl.value,
                              confetti: _confettiList,
                            ),
                          );
                        },
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sparkle top decoration
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (_, _) => Text(
                                    '✨',
                                    style: TextStyle(
                                      fontSize: 22 + _pulseCtrl.value * 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (_, _) => Text(
                                    '🎉',
                                    style: TextStyle(
                                      fontSize: 28 + _pulseCtrl.value * 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (_, _) => Text(
                                    '✨',
                                    style: TextStyle(
                                      fontSize: 22 + _pulseCtrl.value * 6,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Title with shimmer
                            AnimatedBuilder(
                              animation: _shimmerCtrl,
                              builder: (_, child) {
                                return ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      begin: Alignment(
                                          -1.5 + _shimmerCtrl.value * 3.5, 0),
                                      end: Alignment(
                                          -0.5 + _shimmerCtrl.value * 3.5, 0),
                                      colors: const [
                                        Colors.white,
                                        Color(0xFFFFE88A),
                                        Colors.white,
                                      ],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcIn,
                                  child: child!,
                                );
                              },
                              child: Text(
                                _title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.comfortaa(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Days number — big glowing number
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, _) {
                                return Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                            alpha:
                                                0.25 + _pulseCtrl.value * 0.20),
                                        blurRadius: 24 + _pulseCtrl.value * 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xFFFF80AB),
                                          Color(0xFFFF3D88),
                                        ],
                                      ),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        width: 3,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${widget.days}',
                                            style: GoogleFonts.comfortaa(
                                              fontSize: 54,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 12,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            widget.dayUnit,
                                            style: GoogleFonts.comfortaa(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // Couple label
                            if (widget.coupleLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  '❤️  ${widget.coupleLabel}  ❤️',
                                  style: GoogleFonts.comfortaa(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Motivational message
                            Text(
                              _milestoneMessage(widget.days),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.comfortaa(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Close button
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: AnimatedBuilder(
                                animation: _pulseCtrl,
                                builder: (_, child) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 36, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                              alpha: 0.3 +
                                                  _pulseCtrl.value * 0.25),
                                          blurRadius:
                                              16 + _pulseCtrl.value * 12,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '💖  Yêu lắm!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFD81B60),
                                        fontFamily:
                                            GoogleFonts.comfortaa().fontFamily,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating stars outside the card
              _buildFloatingStar(top: -18, left: 30, size: 26),
              _buildFloatingStar(top: -12, right: 24, size: 20),
              _buildFloatingStar(bottom: -14, left: 50, size: 22),
              _buildFloatingStar(bottom: -10, right: 36, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingStar({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, _) {
          return Transform.scale(
            scale: 0.85 + _pulseCtrl.value * 0.3,
            child: Text('⭐', style: TextStyle(fontSize: size)),
          );
        },
      ),
    );
  }

  String _milestoneMessage(int days) {
    if (days % 365 == 0) {
      final y = days ~/ 365;
      return 'Thật tuyệt vời! $y năm yêu nhau đã đến 🥂\nMỗi ngày bên nhau là một món quà vô giá. Chúc hai bạn mãi mãi hạnh phúc nhé! 💕';
    }
    if (days == 100) {
      return 'Tròn 100 ngày yêu thương! 🎊\nHành trình ngọt ngào nhất đang bắt đầu. Hãy tiếp tục viết câu chuyện đẹp cùng nhau nào! 🌹';
    }
    if (days == 200) {
      return 'Hai trăm ngày bên nhau rồi đấy! 💫\nTình yêu của hai bạn ngày càng thêm đậm đà. Mãi mãi nhé! 🌸';
    }
    if (days % 100 == 0) {
      return 'Một cột mốc thật đáng nhớ! 🎉\n$days ngày bên nhau – thật tự hào! Tiếp tục yêu thương nhau nhiều hơn nữa nhé! 💖';
    }
    if (days % 30 == 0) {
      final m = days ~/ 30;
      return 'Tròn $m tháng bên nhau! 🌙\nMỗi khoảnh khắc nhỏ đều trở thành ký ức ngọt ngào. Yêu mãi nha! 💝';
    }
    return 'Chúc mừng kỷ niệm $days ngày! 🥳\nHãy tận hưởng từng khoảnh khắc bên nhau nào! 🌺';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Confetti {
  final double x; // 0..1 horizontal position
  final double startY; // 0..1 start vertical position
  final double speed; // fall speed multiplier
  final Color color;
  final double size;
  final double rotation;

  const _Confetti({
    required this.x,
    required this.startY,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotation,
  });

  factory _Confetti.random(Random rng) {
    const colors = [
      Color(0xFFFFD700),
      Color(0xFFFFFFFF),
      Color(0xFFFF80AB),
      Color(0xFF69F0AE),
      Color(0xFF40C4FF),
      Color(0xFFFF6E40),
      Color(0xFFEA80FC),
    ];
    return _Confetti(
      x: rng.nextDouble(),
      startY: -rng.nextDouble(),
      speed: 0.3 + rng.nextDouble() * 0.7,
      color: colors[rng.nextInt(colors.length)],
      size: 4 + rng.nextDouble() * 8,
      rotation: rng.nextDouble() * 2 * pi,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Confetti> confetti;

  const _ConfettiPainter({required this.progress, required this.confetti});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in confetti) {
      final y = ((p.startY + progress * p.speed * 1.4) % 1.2) * size.height;
      final x = p.x * size.width;
      final rotAngle = p.rotation + progress * 3;
      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotAngle);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

/// Helper to show the dialog.
Future<void> showAnniversaryCelebrationDialog(
  BuildContext context, {
  required int days,
  required String coupleLabel,
  required String dayUnit,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    builder: (_) => AnniversaryCelebrationDialog(
      days: days,
      coupleLabel: coupleLabel,
      dayUnit: dayUnit,
    ),
  );
}
