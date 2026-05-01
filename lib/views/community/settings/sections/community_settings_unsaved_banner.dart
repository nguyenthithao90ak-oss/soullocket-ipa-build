import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../widgets/community_settings_components.dart';

class CommunitySettingsUnsavedBanner extends StatelessWidget {
  const CommunitySettingsUnsavedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
        border: Border.all(color: const Color(0xFFFFD8AF)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3C5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Color(0xFFE57A2E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bạn đang có thay đổi chưa lưu. Nhấn "Lưu" ở góc trên để cập nhật cho toàn bộ hồ sơ cộng đồng.',
              style: SLTheme.quicksand(
                fontSize: 13,
                height: 1.4,
                color: SLColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
