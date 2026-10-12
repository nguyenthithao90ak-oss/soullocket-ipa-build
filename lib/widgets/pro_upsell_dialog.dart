import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_config.dart';
import '../core/sl_route.dart';
import '../utils/services/l10n_service.dart';
import '../utils/services/pro_feature_limits.dart';
import '../utils/services/purchase_service.dart';
import '../utils/services/utility_service.dart';
import '../views/premium/premium_store_screen.dart';
import 'sl_dialog.dart';
import 'utility_vip_badge.dart';

/// Kiểm tra tài khoản PRO cho tiện ích chạy trên máy. Lỗi mạng thì dùng
/// trạng thái đã biết gần nhất; chưa biết thì coi là tài khoản thường.
/// Bản build không bán PRO (SHOW_PURCHASE_UI=false) không khóa tiện ích
/// vì người dùng không có cách nâng cấp.
Future<bool> checkProAccess() async {
  if (!AppConfig.isPurchaseEnabled) return true;
  try {
    final access = await PurchaseService().getVipAccessInfo().timeout(
      const Duration(seconds: 5),
    );
    return access.isVip;
  } catch (_) {
    return UtilityService.proAccess.value ?? false;
  }
}

/// Dùng một lượt miễn phí trong ngày của [usage]. PRO không bị đếm lượt.
/// Trả về false khi tài khoản thường đã hết lượt hôm nay.
Future<bool> useDailyFreeTurn(DailyFreeUsage usage, int limit) async {
  final uid = _usageUid();
  if (await usage.canUse(uid, limit)) {
    if (!await checkProAccess()) await usage.record(uid);
    return true;
  }
  return checkProAccess();
}

String _usageUid() {
  try {
    return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  } catch (_) {
    // Chưa khởi tạo Firebase (preview/test): đếm chung một lượt khách.
    return 'guest';
  }
}

/// Hộp thoại mời nâng cấp PRO dùng chung cho các tiện ích có hạn mức.
/// Trả về true khi người dùng mở cửa hàng PRO.
Future<bool> showProUpsell(
  BuildContext context, {
  required String message,
  String houseId = '',
  String myName = '',
}) async {
  final openStore = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => SLAlertDialog(
      icon: const UtilityVipBadge(),
      title: Text(dialogContext.tr('pro_upsell_title')),
      content: Text(message),
      actions: [
        SLDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(dialogContext.tr('p5_later')),
        ),
        if (AppConfig.isPurchaseEnabled)
          SLDialogAction(
            key: const ValueKey('pro-upsell-upgrade'),
            primary: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('p6_upgrade_vip')),
          ),
      ],
    ),
  );
  if (openStore != true || !context.mounted) return false;
  await slPush(context, PremiumStoreScreen(houseId: houseId, myName: myName));
  // Quay lại từ cửa hàng: làm mới trạng thái PRO cho lần dùng tiếp theo.
  unawaited(checkProAccess());
  return true;
}
