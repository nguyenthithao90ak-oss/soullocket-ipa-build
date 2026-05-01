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
          color: const Color(0xFFFDE8F1),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFB7CF), width: 2),
        ),
        child: const Icon(
          Icons.favorite,
          color: Color(0xFFFF4081),
          size: 30,
        ),
      );
    }
    return GestureDetector(
      onTap: handleTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8F1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFB7CF), width: 2),
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
    );
  }
}
