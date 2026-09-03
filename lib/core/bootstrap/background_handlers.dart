import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/bootstrap/app_bootstrap.dart';
import 'package:soullocket_app/core/sl_theme.dart';
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
    await initializeFirebaseBootstrap();

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
          final text =
              message.notification?.body ??
              message.data['text'] ??
              'Có tin nhắn mới 💕';
          final senderName =
              message.data['senderName']?.toString() ?? 'Người ấy';
          await WidgetService.syncSoulMergeWidgetData(
            message: text.toString(),
            senderName: senderName,
          );
        } catch (error) {
          debugPrint('[FCM] Soul Merge widget sync skipped: $error');
        }
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
    debugPrint(
      'FCM background bootstrap error: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('core_err_fcm_bg_init_failed')).message}',
    );
    unawaited(
      ErrorLoggerService.instance.logError(
        error,
        stackTrace,
        reason: 'fcm_background_bootstrap_error',
        fatal: false,
      ),
    );
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
    } catch (error) {
      debugPrint('[Overlay] Local sync file read skipped: $error');
    }

    if (houseId == null || houseId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Đảm bảo lấy dữ liệu mới nhất từ isolate chính
      houseId =
          prefs.getString('overlay_house_id') ?? prefs.getString('il_house_id');
      role =
          prefs.getString('overlay_role') ??
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
      } catch (error) {
        debugPrint('[Overlay] Partner name lookup skipped: $error');
      }
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
  // Log error to Crashlytics in background (non-blocking)
  unawaited(
    ErrorLoggerService.instance.logError(
      details.exception,
      details.stack,
      reason: 'ErrorWidget.builder',
      fatal: false,
    ),
  );

  final l10n = L10nService();

  return Material(
    color: SLColors.darkBgMain,
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: SLColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  color: SLColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('core_err_widget_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SLColors.darkTextPrimary,
                  decoration: TextDecoration.none,
                  fontFamily: 'Quicksand',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.translate('core_err_widget_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: SLColors.darkTextSecond,
                  decoration: TextDecoration.none,
                  fontFamily: 'Quicksand',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  try {
                    SystemNavigator.pop();
                  } catch (error) {
                    debugPrint('System navigator close skipped: $error');
                  }
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(l10n.translate('core_err_widget_close')),
                style: FilledButton.styleFrom(
                  backgroundColor: SLColors.primary,
                  foregroundColor: SLColors.textInverse,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SLRadius.sm),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 20),
                _ErrorDetailsSection(details: details),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ErrorDetailsSection extends StatefulWidget {
  final FlutterErrorDetails details;
  const _ErrorDetailsSection({required this.details});

  @override
  State<_ErrorDetailsSection> createState() => _ErrorDetailsSectionState();
}

class _ErrorDetailsSectionState extends State<_ErrorDetailsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SLColors.darkBgCard,
          borderRadius: BorderRadius.circular(SLRadius.sm),
          border: Border.all(color: SLColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bug_report_rounded,
                  size: 14,
                  color: SLColors.danger,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Debug: Error Details',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SLColors.darkTextSecond,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: SLColors.darkTextSecond,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(
                widget.details.exception.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: SLColors.darkTextSecond,
                  decoration: TextDecoration.none,
                  fontFamily: 'monospace',
                ),
                maxLines: 20,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
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
  unawaited(
    ErrorLoggerService.instance.logError(
      error,
      stackTrace,
      reason: 'uncaught_zone_error',
      fatal: true,
    ),
  );
  unawaited(
    RevenueSecurityTelemetryService.instance.logSystemEvent(
      type: 'uncaught_zone_error',
      reason: mappedError.message,
    ),
  );
}
