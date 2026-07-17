import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';

class GenderSelectionDialog extends StatelessWidget {
  final Function(String) onSelected;

  const GenderSelectionDialog({super.key, required this.onSelected});

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: maxDialogHeight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF080614).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4), blurRadius: 40),
                ],
              ),
              child: SingleChildScrollView(
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
                        horizontal: 16,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF0066), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        L10nService().translate('✨ GIỚI TÍNH CỦA BẠN'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      L10nService().translate('Bạn là...'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      L10nService().translate('auth_msg_role_hint'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: optionWidth,
                          child: _buildOption(
                            assetPath: 'assets/images/avatar_male.jpg',
                            title: L10nService().translate('Nam'),
                            desc:
                                L10nService().translate('Giao diện đằng trai'),
                            gradientColors: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
                            compact: isCompactLayout,
                            onTap: () => onSelected('user1'),
                          ),
                        ),
                        SizedBox(
                          width: optionWidth,
                          child: _buildOption(
                            assetPath: 'assets/images/avatar_female.jpg',
                            title: L10nService().translate('Nữ'),
                            desc: L10nService().translate('Giao diện đằng gái'),
                            gradientColors: const [Color(0xFFF77062), Color(0xFFFE5196)],
                            compact: isCompactLayout,
                            onTap: () => onSelected('user2'),
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
    );
  }

  Widget _buildOption({
    required String assetPath,
    required String title,
    required String desc,
    required List<Color> gradientColors,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 22 : 28,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradientColors[0].withValues(alpha: 0.15),
              gradientColors[1].withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: gradientColors[0].withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  assetPath,
                  width: compact ? 64 : 76,
                  height: compact ? 64 : 76,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
