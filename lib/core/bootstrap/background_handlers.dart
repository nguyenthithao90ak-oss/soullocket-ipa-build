import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/bootstrap/app_bootstrap.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/incoming_call_notifications.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/views/home/widgets/floating_bubble_widget.dart';
import 'package:soullocket_app/views/home/widgets/soul_merge/bubble_chat_controller.dart';
import 'package:soullocket_app/views/home/widgets/soul_merge/firebase_bubble_chat_transport.dart';
import 'package:soullocket_app/views/home/widgets/soul_merge/soul_bubble_app.dart';
import 'package:soullocket_app/utils/soul_bubble_overlay.dart';

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
    if (type == 'soul_merge_call' || screen == 'soul_merge_call') {
      await IncomingCallNotifications.handleBackgroundPush(message.data);
      return;
    }
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
              UiCopy.text('copy_ed5fd66064f8');
          final senderName =
              message.data['senderName']?.toString() ??
              UiCopy.text('copy_145933221191');
          await WidgetService.syncSoulMergeWidgetData(
            message: text.toString(),
            senderName: senderName,
          );
        } catch (error) {
          debugPrint('[FCM] Soul Merge widget sync skipped: $error');
        }
      }
      try {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final uid = FirebaseAuth.instance.currentUser?.uid;
        bool allowed() =>
            FirebaseAuth.instance.currentUser?.uid == uid &&
            prefs.getString('il_auth_uid') == uid &&
            SoulBubbleOverlay.acceptsPush(
              message.data,
              uid: uid,
              houseId: prefs.getString('il_house_id'),
              enabledUid: prefs.getString(SoulBubbleOverlay.uidKey),
              enabledHouse: prefs.getString(SoulBubbleOverlay.houseKey),
              enabled: prefs.getBool(SoulBubbleOverlay.enabledKey) == true,
              preference: prefs.getBool,
              now: DateTime.now(),
            );
        if (allowed() &&
            await FlutterOverlayWindow.isPermissionGranted() &&
            !await FlutterOverlayWindow.isActive()) {
          if (FirebaseAuth.instance.currentUser?.uid != uid) return;
          await L10nService().init();
          await prefs.reload();
          if (allowed() && !await FlutterOverlayWindow.isActive()) {
            await SoulBubbleOverlay.show();
          }
        }
      } catch (error) {
        debugPrint('[Overlay] Background start skipped:  ${error.runtimeType}');
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

  // Engine nổi có isolate riêng; nạp catalog trước khi dựng giao diện.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final l10n = L10nService();
  await l10n.init();
  runApp(
    SoulBubbleApp(
      l10n: l10n,
      themeKey: prefs.getString('il_theme_key') ?? 'theme-default',
      home: const _SoulBubbleSession(),
    ),
  );
}

/// Bootstrap sở hữu controller; giao diện không tự tạo Firebase/service.
class _SoulBubbleSession extends StatefulWidget {
  const _SoulBubbleSession();

  @override
  State<_SoulBubbleSession> createState() => _SoulBubbleSessionState();
}

class _SoulBubbleSessionState extends State<_SoulBubbleSession> {
  late final _chat = SoulBubbleChatController(
    transport: FirebaseSoulBubbleChatTransport(),
  );

  @override
  Widget build(BuildContext context) =>
      FloatingBubbleWidget(chatController: _chat);

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }
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
                Expanded(
                  child: Text(
                    L10nService().translate('debug_error_details_title'),
                    style: const TextStyle(
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
