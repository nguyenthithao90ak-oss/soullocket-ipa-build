import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../core/fast_backdrop_filter.dart';
import '../../../utils/services/l10n_service.dart';
import 'package:lottie/lottie.dart';

class GenderSelectionDialog extends StatefulWidget {
  final Function(String) onSelected;

  const GenderSelectionDialog({super.key, required this.onSelected});

  @override
  State<GenderSelectionDialog> createState() => _GenderSelectionDialogState();
}

class _GenderSelectionDialogState extends State<GenderSelectionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSelect(String gender) {
    if (_isSelecting) return;
    _isSelecting = true;
    if (mounted) {
      widget.onSelected(gender);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final textScale = mediaQuery.textScaler.scale(1);
    final isCompactLayout = screenSize.width < 380 || screenSize.height < 760 || textScale > 1.05;
    final maxDialogHeight = (screenSize.height - mediaQuery.viewInsets.vertical - 48).clamp(260.0, screenSize.height);

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxDialogHeight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: FastBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCF5F7), // Nền hồng nhạt
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 2), // Viền trắng
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Title Pill ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '✨ ${L10nService().translate('your_gender')} ✨',
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: const Color(0xFFFF4081), // Chữ hồng đậm
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Subtitle ---
                        Text(
                          L10nService().translate('gender_selection_desc'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B6B6B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // --- Avatars Area with Floating Hearts & Curves ---
                        SizedBox(
                          height: compactSize(isCompactLayout) + 115, // Tăng chiều cao đủ chứa Avatar + Chữ không bị tràn
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Floating Decor
                              Positioned(
                                left: -10, top: -10,
                                child: Icon(Icons.favorite, size: 20, color: const Color(0xFFFF80AB).withValues(alpha: 0.7)),
                              ),
                              Positioned(
                                right: -10, top: 30,
                                child: Icon(Icons.favorite, size: 24, color: const Color(0xFFFF80AB).withValues(alpha: 0.8)),
                              ),
                              const Positioned(
                                right: 10, top: -30,
                                child: Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                              ),
                              const Positioned(
                                left: 30, top: 40,
                                child: Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                              ),

                              // Dotted Curve & Center Heart
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _GenderDottedCurvePainter(),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.favorite, size: 24, color: Color(0xFFFF80AB)),
                              ),

                              // Avatars
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _buildOption(
                                      assetPath: 'assets/images/avatar_male.webp',
                                      lottieUrl: 'assets/images/male_avatar_sticker.json',
                                      title: L10nService().translate('gender_male'),
                                      desc: L10nService().translate('gender_male_desc'),
                                      baseColor: const Color(0xFF82B1FF),
                                      shadowColor: const Color(0xFF82B1FF),
                                      compact: isCompactLayout,
                                      onTap: () => _handleSelect('user1'),
                                    ),
                                  ),
                                  const SizedBox(width: 40), // Khoảng cách giữa 2 avatar
                                  Expanded(
                                    child: _buildOption(
                                      assetPath: 'assets/images/avatar_female.webp',
                                      lottieUrl: 'assets/images/female_avatar_sticker.json',
                                      title: L10nService().translate('gender_female'),
                                      desc: L10nService().translate('gender_female_desc'),
                                      baseColor: const Color(0xFFFF80AB),
                                      shadowColor: const Color(0xFFFF80AB),
                                      compact: isCompactLayout,
                                      onTap: () => _handleSelect('user2'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double compactSize(bool compact) => compact ? 90 : 120;

  Widget _buildOption({
    required String assetPath,
    String? lottieUrl,
    required String title,
    required String desc,
    required Color baseColor,
    required Color shadowColor,
    required bool compact,
    required VoidCallback onTap,
  }) {
    final size = compactSize(compact);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // Giữ vùng bấm
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Avatar background with colored glowing border
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: baseColor.withValues(alpha: 0.3), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: lottieUrl != null
                        ? (lottieUrl.startsWith('http')
                            ? Lottie.network(lottieUrl, width: size, height: size, fit: BoxFit.cover, options: LottieOptions(enableMergePaths: true))
                            : Lottie.asset(lottieUrl, width: size, height: size, fit: BoxFit.cover, options: LottieOptions(enableMergePaths: true)))
                        : Image.asset(assetPath, width: size, height: size, fit: BoxFit.cover),
                  ),
                ),

              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1D2335), // Dark text
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A8A8A), // Gray text
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderDottedCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF80AB).withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Vẽ đường cong sine mềm mại đi qua giữa hai avatar
    final startY = size.height / 2 + 10;
    path.moveTo(0, startY + 20);
    path.quadraticBezierTo(size.width * 0.25, startY - 20, size.width / 2, startY);
    path.quadraticBezierTo(size.width * 0.75, startY + 20, size.width, startY - 20);

    // Vẽ nét đứt (dashed line)
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double distance = 0.0;
    
    // Thuật toán chia nét đứt đơn giản dọc theo path
    // Flutter không có sẵn drawDashedPath, ta dùng vòng lặp tạo PathMetric
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final extractPath = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
