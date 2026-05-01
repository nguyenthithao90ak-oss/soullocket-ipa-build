import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';

class RelationshipModeDialog extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const RelationshipModeDialog({
    super.key,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final textScale = mediaQuery.textScaler.scale(1);
    final isCompact =
        screenSize.width < 380 || screenSize.height < 760 || textScale > 1.05;
    final maxDialogHeight =
        (screenSize.height - mediaQuery.viewInsets.vertical - 48)
            .clamp(280.0, screenSize.height)
            .toDouble();

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
            color: const Color(0xFF080614).withOpacity(0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final optionWidth = isCompact
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
                          colors: [Color(0xFFFF6F91), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        L10nService().translate('CHỌN KIỂU TÀI KHOẢN'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      L10nService().translate('Bạn đang ở trạng thái nào?'),
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
                        'Chọn để app biết nên mở chế độ độc thân hay cặp đôi ngay từ đầu.',
                      ),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.58),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: optionWidth,
                          child: _buildOption(
                            emoji: '🩷',
                            title: L10nService().translate('Có người yêu'),
                            description: L10nService().translate(
                              'Mở giao diện cặp đôi, lưu ngày yêu và đồng bộ với người ấy.',
                            ),
                            color: const Color(0xFFFF4081),
                            onTap: () => onSelected('couple'),
                          ),
                        ),
                        SizedBox(
                          width: optionWidth,
                          child: _buildOption(
                            emoji: '✨',
                            title: L10nService().translate('Độc thân'),
                            description: L10nService().translate(
                              'Mở giao diện cá nhân, dùng app một mình trước.',
                            ),
                            color: const Color(0xFF29B6F6),
                            onTap: () => onSelected('single'),
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
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 38),
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
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 11.5,
                color: Colors.white.withOpacity(0.58),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
