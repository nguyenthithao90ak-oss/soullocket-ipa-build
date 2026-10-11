import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/services/giftcode_service.dart';
import '../../utils/services/security_service.dart';
import 'widgets/giftcode_entry_sheet.dart';

/// Điểm nhập Giftcode trong Cài đặt Android.
class GiftcodeScreen extends StatelessWidget {
  const GiftcodeScreen({
    super.key,
    required this.houseId,
    required this.myName,
    this.isDark = false,
  });

  final String houseId;
  final String myName;
  final bool isDark;

  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox.shrink();
    return GiftcodeEntrySheet(
      isDark: isDark,
      onRedeem: (code) async {
        final allowed = await SecurityService().guardAction(
          context,
          'giftcode_redeem',
          content: code,
        );
        if (!allowed || !context.mounted) return null;
        return GiftcodeService().redeemGiftcode(houseId: houseId, code: code);
      },
    );
  }
}
