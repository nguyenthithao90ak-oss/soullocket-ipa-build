part of '../../main_home_tab.dart';
// ignore_for_file: unused_element

extension _MainHomeRelationshipActionExt on _MainHomeTabState {
  Widget _buildRelationshipCenterAction({
    required bool isSingle,
  }) {
    final interactionType = _centerInteractionType(isSingle: isSingle);
    final title = switch (interactionType) {
      'connect' => 'Kết nối',
      'hot' => 'Nhắc uống nước',
      'warmth' => 'Nhắc mặc ấm',
      _ => 'Gửi nỗi nhớ',
    };
    final icon = switch (interactionType) {
      'connect' => Icons.qr_code_rounded,
      'hot' => Icons.local_fire_department_rounded,
      'warmth' => Icons.cloud_rounded,
      _ => Icons.favorite_rounded,
    };
    final VoidCallback handleTap = interactionType == 'connect'
        ? _openCoupleConnect
        : () {
            _handleSendInteraction(
              interactionType,
              _emojiForInteractionType(interactionType),
            );
          };

    if (isSingle) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1F7), Color(0xFFFFD9E7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFB7CF), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6F9F).withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.favorite,
          color: Color(0xFFFF4081),
          size: 30,
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: handleTap,
        radius: 42,
        containedInkWell: true,
        customBorder: const CircleBorder(),
        splashColor: const Color(0xFFFF6F9F).withValues(alpha: 0.10),
        highlightColor: const Color(0xFFFF6F9F).withValues(alpha: 0.06),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1F7), Color(0xFFFFD9E7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFB7CF), width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6F9F).withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF4081),
                size: 34,
              ),
            ),
            SLSpacing.h8,
            Text(
              title,
              style: _uiTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD81B60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
