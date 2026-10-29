import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_delivery_policy.dart';
import 'services/l10n_service.dart';

/// Lựa chọn mở cửa sổ nổi gắn với phiên, khác quyền SYSTEM_ALERT_WINDOW.
abstract final class SoulBubbleOverlay {
  static const enabledKey = 'soul_bubble_enabled';
  static const uidKey = 'soul_bubble_uid';
  static const houseKey = 'soul_bubble_house';

  static bool acceptsPush(
    Map<String, dynamic> data, {
    required String? uid,
    required String? houseId,
    required String? enabledUid,
    required String? enabledHouse,
    required bool enabled,
    required bool? Function(String) preference,
    required DateTime now,
  }) =>
      enabled &&
      uid != null &&
      houseId != null &&
      houseId.isNotEmpty &&
      enabledUid == uid &&
      enabledHouse == houseId &&
      NotificationDeliveryPolicy.screen(data) == 'soul_merge' &&
      NotificationDeliveryPolicy.matchesScope(
        data,
        uid: uid,
        houseId: houseId,
      ) &&
      !NotificationDeliveryPolicy.expired(data, now) &&
      NotificationDeliveryPolicy.allowsLocal(data, preference);

  static Future<void> enable(String uid, String houseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(uidKey, uid);
    await prefs.setString(houseKey, houseId);
    await prefs.setBool(enabledKey, true);
  }

  static Future<void> close() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, false);
    await FlutterOverlayWindow.closeOverlay();
  }

  static Future<void> show() => FlutterOverlayWindow.showOverlay(
    enableDrag: true,
    height: 80,
    width: 80,
    alignment: OverlayAlignment.centerRight,
    positionGravity: PositionGravity.auto,
    dismissConfig: const OverlayDismissConfig(
      backgroundColor: Color(0xEB251D2C),
      activeBackgroundColor: Color(0xFFBF3E69),
      borderColor: Color(0x66FFFFFF),
      borderWidth: 1,
    ),
    notificationIcon: 'ic_stat_soullocket',
    overlayTitle: L10nService().translate('p4_soul_overlay_title'),
    overlayContent: L10nService().translate('p4_soul_overlay_content'),
  );

  /// Native service mở launcher ngay cả khi màn Soul Merge đã dispose.
  static Future<void> openApp() async {
    await const MethodChannel(
      'x-slayer/overlay',
    ).invokeMethod('openSoulLocket').timeout(const Duration(seconds: 3));
  }
}
