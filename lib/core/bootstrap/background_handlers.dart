import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/bootstrap/app_bootstrap.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/views/home/widgets/floating_bubble_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FCM Background Message Handler
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId ?? 'unknown'}');
  try {
    if (Firebase.apps.isEmpty) {
      await initializeFirebaseBootstrap();
    }
    FirebaseDatabase.instance.setPersistenceEnabled(true);

    // Hiển thị bong bóng tâm hồn / chat nếu app ở background
    final type = message.data['type']?.toString() ?? '';
    final screen = message.data['screen']?.toString() ?? '';
    if (type == 'soul_merge' ||
        screen == 'soul_merge' ||
        type == 'chat' ||
        screen == 'chat') {
      // Đồng bộ iOS Widget cho Soul Merge
      if (type == 'soul_merge' || screen == 'soul_merge') {
        try {
          final text = message.notification?.body ??
              message.data['text'] ??
              'Có tin nhắn mới 💕';
          final senderName =
              message.data['senderName']?.toString() ?? 'Người ấy';
          await WidgetService.syncSoulMergeWidgetData(
              message: text.toString(), senderName: senderName);
        } catch (_) {}
      }
      try {
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        if (granted) {
          final active = await FlutterOverlayWindow.isActive();
          if (!active) {
            await FlutterOverlayWindow.showOverlay(
              enableDrag: true,
              height: 100,
              width: 100,
              alignment: OverlayAlignment.centerRight,
              overlayTitle: 'Bong bóng tâm hồn',
              overlayContent: 'Lời thì thầm đang kết nối...',
            );
          }
        }
      } catch (e) {
        debugPrint('Error showing overlay in background: $e');
      }
    }
  } catch (error, stackTrace) {
    debugPrint('FCM background bootstrap error: ${AppErrorMapper.resolve(
      error,
      fallbackMessage: L10nService().translate('core_err_fcm_bg_init_failed'),
    ).message}');
    unawaited(ErrorLoggerService.instance.logError(
      error,
      stackTrace,
      reason: 'fcm_background_bootstrap_error',
      fatal: false,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay Entry Point (floating bubble)
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeFirebaseBootstrap();
  } catch (e) {
    debugPrint('[Overlay] Firebase init error: $e');
  }

  String? houseId;
  String? role;
  String? partnerName;
  try {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/overlay_sync.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        houseId = data['houseId']?.toString();
        role = data['role']?.toString();
        partnerName = data['partnerName']?.toString();
      }
    } catch (_) {}

    if (houseId == null || houseId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Đảm bảo lấy dữ liệu mới nhất từ isolate chính
      houseId =
          prefs.getString('overlay_house_id') ?? prefs.getString('il_house_id');
      role = prefs.getString('overlay_role') ??
          prefs.getString('il_role') ??
          'user1';
      partnerName = prefs.getString('overlay_partner_name');
    }

    if (houseId == null || houseId.isEmpty) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final snap = await FirebaseDatabase.instance.ref('users/$uid').get();
          final userData = snap.value as Map?;
          if (userData != null) {
            houseId = userData['houseId']?.toString();
            role = userData['role']?.toString() ?? 'user1';
          }
        }
      } catch (e) {
        debugPrint('[Overlay] Fallback Firebase fetch error: $e');
      }
    }

    if (partnerName == null || partnerName.isEmpty) {
      // Đọc tên partner từ settings nếu có
      try {
        final houseIdLocal = houseId;
        if (houseIdLocal != null && houseIdLocal.isNotEmpty) {
          final snap = await FirebaseDatabase.instance
              .ref('houses/$houseIdLocal/settings')
              .child(role == 'user2' ? 'nameU1' : 'nameU2')
              .get();
          partnerName = snap.value?.toString();
        }
      } catch (_) {}
    }
  } catch (e) {
    debugPrint('[Overlay] prefs read error: $e');
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FloatingBubbleWidget(
        initialHouseId: houseId,
        initialRole: role ?? 'user1',
        initialPartnerName: partnerName ?? 'Người ấy',
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Widget Builder
// ─────────────────────────────────────────────────────────────────────────────

Widget buildDefaultErrorWidget(FlutterErrorDetails details) {
  return Material(
    color: const Color(0xFF110820),
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.favorite,
            color: Color(0xFFAD1457),
            size: 44,
          ),
          const SizedBox(height: 12),
          const Text(
            'Có lỗi nhỏ xảy ra, vui lòng thử lại 💕',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE53935),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Zone error handlers
// ─────────────────────────────────────────────────────────────────────────────

void handleZoneError(Object error, StackTrace stackTrace) {
  final mappedError = AppErrorMapper.resolve(
    error,
    fallbackMessage: L10nService().translate('core_err_uncaught_start'),
  );
  debugPrint('Uncaught zone error: ${mappedError.message}');
  unawaited(ErrorLoggerService.instance.logError(
    error,
    stackTrace,
    reason: 'uncaught_zone_error',
    fatal: true,
  ));
  unawaited(
    RevenueSecurityTelemetryService.instance.logSystemEvent(
      type: 'uncaught_zone_error',
      reason: mappedError.message,
    ),
  );
}
