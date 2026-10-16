import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/routing/single_open_gate.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/military_lock_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';
import 'package:soullocket_app/utils/sl_notice.dart';
import 'package:soullocket_app/views/home/tabs/settings/settings_links_manager_screen.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/local_guide_companion.dart';
import 'package:url_launcher/url_launcher.dart';

import 'calendar_screen.dart';
import 'capsule_screen.dart';
import 'cinema_screen.dart';
import 'collage_maker_screen.dart';
import 'creative_diary_screen.dart';
import 'diary_export_screen.dart';
import 'drawing_studio_screen.dart';
import 'finance_screen.dart';
import 'friendly_chat_screen.dart';
import 'habit_screen.dart';
import 'health_screen.dart';
import 'local_album_screen.dart';
import 'love_card_screen.dart';
import 'shared_notes_screen.dart';
import 'reward_store_screen.dart';
import 'secret_vault_screen.dart';
import 'sleep_tracker_screen.dart';
import 'soul_events/soul_events_screen.dart';
import 'tarot/tarot_screen.dart';
import 'voice_screen.dart';
import 'wheel/wheel_screen.dart';

/// Mở một tiện ích theo ID; tab Tiện ích và lối tắt đã ghim ở trang Nhà
/// dùng chung để luôn ra cùng một màn hình và cùng bước khóa.
abstract final class UtilityLauncher {
  static final SingleOpenGate _openGate = SingleOpenGate();

  /// Kiểm tra quyền theo chế độ, nhà hiện tại và các tiện ích đặc biệt rồi mở.
  static Future<void> open(
    BuildContext context, {
    required String id,
    required String? houseId,
    required String myName,
    required String relationshipMode,
    Future<bool> Function()? beforeOpen,
  }) {
    return _openGate.run(() async {
      try {
        await _openInternal(
          context,
          id: id,
          houseId: houseId,
          myName: myName,
          relationshipMode: relationshipMode,
          beforeOpen: beforeOpen,
        );
      } catch (error, stackTrace) {
        // Callback tile không await Future này; luôn ghi nhận và nhả gate
        // để một route lỗi không làm mọi tiện ích phía sau mất phản hồi.
        debugPrint('[Utilities] Không mở được tiện ích $id: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  static Future<void> _openInternal(
    BuildContext context, {
    required String id,
    required String? houseId,
    required String myName,
    required String relationshipMode,
    Future<bool> Function()? beforeOpen,
  }) async {
    if (!context.mounted) return;
    if (!UtilityService.isUtilityAllowed(id, relationshipMode)) {
      final blockedMessage = UtilityService.blockedMessageForMode(
        id,
        relationshipMode,
      );
      SLNotice.showInfo(
        context,
        blockedMessage.isNotEmpty
            ? blockedMessage
            : context.tr('home_tinchnychd_6061d1'),
      );
      return;
    }
    if (id == 'local_album') {
      await slPush<void>(context, const LocalAlbumScreen());
      return;
    }
    if (id == 'understand_me') {
      final opened = await launchUrl(
        AppConfig.webUri('/hieutuihong'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        SLNotice.showInfo(context, context.tr('understand_me_web_open_failed'));
      }
      return;
    }
    final resolvedHouseId = houseId?.trim() ?? '';
    if (resolvedHouseId.isEmpty) {
      SLNotice.showInfo(context, context.tr('home_angtidliun_f42fcd'));
      return;
    }
    if (id == 'couple_connect') {
      await slPush<void>(
        context,
        SettingsLinksManagerScreen(houseId: resolvedHouseId),
      );
      return;
    }
    if (beforeOpen != null && !await beforeOpen()) return;
    if (!context.mounted) return;
    await _openScreenInternal(
      context,
      id: id,
      houseId: resolvedHouseId,
      myName: myName,
      relationshipMode: relationshipMode,
    );
  }

  /// Mở màn hình của tiện ích (đã qua kiểm tra quyền); Kho riêng tư hỏi mở khóa.
  static Future<void> openScreen(
    BuildContext context, {
    required String id,
    required String houseId,
    required String myName,
    required String relationshipMode,
  }) {
    return _openGate.run(() async {
      try {
        await _openScreenInternal(
          context,
          id: id,
          houseId: houseId,
          myName: myName,
          relationshipMode: relationshipMode,
        );
      } catch (error, stackTrace) {
        debugPrint('[Utilities] Không mở được tiện ích $id: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  static Future<void> _openScreenInternal(
    BuildContext context, {
    required String id,
    required String houseId,
    required String myName,
    required String relationshipMode,
  }) async {
    if (!context.mounted) return;
    Widget? screen;
    switch (id) {
      case 'note':
        screen = SharedNotesScreen(houseId: houseId, myName: myName);
      case 'friendly_chat':
        screen = FriendlyChatScreen(houseId: houseId, myName: myName);
      case 'finance':
        screen = FinanceScreen(houseId: houseId, myName: myName);
      case 'habit':
        screen = HabitScreen(houseId: houseId, myName: myName);
      case 'drawing':
        screen = DrawingStudioScreen(houseId: houseId, myName: myName);
      case 'voice':
        screen = VoiceScreen(houseId: houseId, myName: myName);
      case 'calendar':
        screen = CalendarScreen(houseId: houseId, myName: myName);
      case 'capsule':
        screen = CapsuleScreen(houseId: houseId, myName: myName);
      case 'cinema':
        screen = CinemaScreen(houseId: houseId, myName: myName);
      case 'wheel':
        screen = WheelScreen(houseId: houseId);
      case 'vault':
        final lockService = MilitaryLockService();
        if (kIsWeb) {
          // Buộc khóa lại trước khi vào để yêu cầu mật khẩu mỗi lần F5 hoặc thoát
          lockService.lockScope(LockScope.privateArea);
        }
        final unlocked = await lockService.requestUnlock(
          context: context,
          scope: LockScope.privateArea,
          houseId: houseId,
          title: MilitaryLockService.getScopeTitle(LockScope.privateArea),
          reason: MilitaryLockService.scopeReason(LockScope.privateArea),
        );
        if (!unlocked || !context.mounted) return;
        screen = SecretVaultScreen(houseId: houseId);
      case 'surprise_maker':
        final uid = FirebaseAuth.instance.currentUser?.uid;
        screen = uid == null
            ? null
            : LoveCardScreen(houseId: houseId, myUid: uid);
      case 'diary_export':
        screen = DiaryExportScreen(houseId: houseId);
      case 'tarot':
        screen = TarotScreen(
          houseId: houseId,
          relationshipMode: relationshipMode,
          myName: myName,
        );
      case 'collage':
        screen = CollageMakerScreen(houseId: houseId);
      case 'store':
        screen = const RewardStoreScreen();
      case 'creative_diary':
        screen = CreativeDiaryScreen(houseId: houseId);
      case 'local_album':
        screen = const LocalAlbumScreen();
      case 'health':
        screen = HealthScreen(houseId: houseId);
      case 'sleep_tracker':
        screen = SleepTrackerScreen(houseId: houseId, myName: myName);
      case 'soul_events':
        screen = const SoulEventsScreen();
    }
    if (!context.mounted) return;
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('home_tinchnyang_612f3d'))),
      );
      return;
    }
    final previousSurface = LocalGuideContextNotifier.instance.surface;
    LocalGuideContextNotifier.instance.setUtility(id);
    try {
      await slPush(context, screen);
    } finally {
      switch (previousSurface.type) {
        case LocalGuideSurfaceType.settings:
          LocalGuideContextNotifier.instance.setSettings();
        case LocalGuideSurfaceType.utility:
          LocalGuideContextNotifier.instance.setUtility(previousSurface.id);
        case LocalGuideSurfaceType.home:
          LocalGuideContextNotifier.instance.setHomeTab(0);
        case LocalGuideSurfaceType.diary:
          LocalGuideContextNotifier.instance.setHomeTab(1);
        case LocalGuideSurfaceType.utilities:
          LocalGuideContextNotifier.instance.setHomeTab(2);
        case LocalGuideSurfaceType.fun:
          LocalGuideContextNotifier.instance.setHomeTab(3);
        case LocalGuideSurfaceType.update:
          LocalGuideContextNotifier.instance.setHomeTab(4);
      }
    }
  }
}
