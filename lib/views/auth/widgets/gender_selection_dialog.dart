import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';

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
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF080614).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40),
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
                      L10nService().translate(
                        'Để ứng dụng hiển thị đúng giao diện\nmà không cần lật lại sau nhé!',
                      ),
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
                            emoji: '👨',
                            title: L10nService().translate('Nam'),
                            desc:
                                L10nService().translate('Giao diện đằng trai'),
                            color: const Color(0xFF29B6F6),
                            compact: isCompactLayout,
                            onTap: () => onSelected('user1'),
                          ),
                        ),
                        SizedBox(
                          width: optionWidth,
                          child: _buildOption(
                            emoji: '👩',
                            title: L10nService().translate('Nữ'),
                            desc: L10nService().translate('Giao diện đằng gái'),
                            color: const Color(0xFFFF4081),
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
    );
  }

  Widget _buildOption({
    required String emoji,
    required String title,
    required String desc,
    required Color color,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 18 : 20,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: compact ? 38 : 42),
              textScaler: const TextScaler.linear(1.0),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
