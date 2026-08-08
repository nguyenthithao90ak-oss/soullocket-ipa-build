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
    final isCompactLayout =
        screenSize.width < 380 || screenSize.height < 760 || textScale > 1.05;
    final maxDialogHeight =
        (screenSize.height - mediaQuery.viewInsets.vertical - 48)
            .clamp(260.0, screenSize.height);

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxDialogHeight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: FastBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C).withOpacity(0.92), // Nền tối dark mode
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final optionWidth = isCompactLayout
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF48FB1).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                '✨ ${L10nService().translate('GIỚI TÍNH CỦA BẠN')} ✨',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  color: const Color(0xFFF48FB1),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              L10nService().translate(
                                  'Để ứng dụng hiển thị đúng giao diện\nmà không cần lật lại sau nhé!'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _buildOption(
                                    assetPath: 'assets/images/avatar_male.jpg',
                                    lottieUrl:
                                        'assets/images/male_avatar_sticker.json',
                                    title: L10nService().translate('Nam'),
                                    desc: L10nService().translate('Bạn Nam'),
                                    baseColor: const Color(0xFF81D4FA),
                                    shadowColor: const Color(0xFF03A9F4),
                                    emoji: '👦🏻',
                                    compact: isCompactLayout,
                                    onTap: () => _handleSelect('user1'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildOption(
                                    assetPath:
                                        'assets/images/avatar_female.jpg',
                                    lottieUrl:
                                        'assets/images/female_avatar_sticker.json',
                                    title: L10nService().translate('Nữ'),
                                    desc: L10nService().translate('Bạn Nữ'),
                                    baseColor: const Color(0xFFF48FB1),
                                    shadowColor: const Color(0xFFE91E63),
                                    emoji: '👧🏻',
                                    compact: isCompactLayout,
                                    onTap: () => _handleSelect('user2'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

  Widget _buildOption({
    required String assetPath,
    String? lottieUrl,
    required String title,
    required String desc,
    required Color baseColor,
    required Color shadowColor,
    required String emoji,
    required bool compact,
    required VoidCallback onTap,
  }) {
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: lottieUrl != null
                        ? (lottieUrl.startsWith('http')
                            ? Lottie.network(
                                lottieUrl,
                                width: compact ? 80 : 90,
                                height: compact ? 80 : 90,
                                fit: BoxFit.cover,
                                options: LottieOptions(enableMergePaths: true),
                              )
                            : Lottie.asset(
                                lottieUrl,
                                width: compact ? 80 : 90,
                                height: compact ? 80 : 90,
                                fit: BoxFit.cover,
                                options: LottieOptions(enableMergePaths: true),
                              ))
                        : Image.asset(
                            assetPath,
                            width: compact ? 80 : 90,
                            height: compact ? 80 : 90,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  bottom: -10,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C3E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
