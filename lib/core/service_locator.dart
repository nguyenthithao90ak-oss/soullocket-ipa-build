/// Service Locator (GetIt) — đăng ký các dependency cho toàn app.
///
/// File này chỉ đăng ký các service core/dùng chung. Các feature service khác
/// được tự khởi tạo lazy hoặc đăng ký tại module riêng (xem `services.dart`).
///
/// Pattern sử dụng:
/// ```dart
/// final house = locator<HouseService>();
/// ```
///
/// Khi thêm service mới:
/// 1. Tạo file trong `lib/utils/services/<domain>/<name>_service.dart`.
/// 2. Nếu là core (dùng toàn app), đăng ký tại đây bằng `registerLazySingleton`.
/// 3. Nếu là feature riêng, dùng `services.dart` để export hoặc đăng ký tại view.
library;

import 'package:get_it/get_it.dart';
import '../utils/services/map_place_search_service.dart';
import '../utils/services/app_referral_service.dart';
import '../utils/services/games/soul_block_memory_service.dart';
import '../utils/services/soul_merge_memories.dart';
import '../utils/services/market_service.dart';
import '../utils/services/media_data_preferences.dart';
import '../utils/services/calendar_reminder_service.dart';
import '../utils/services/habit_reminder_service.dart';
import 'package:soullocket_app/utils/services/companion_rewards_service.dart';
import 'package:soullocket_app/utils/services/privacy_collection_service.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/house_settings_service.dart';
import 'package:soullocket_app/utils/services/home_shared_note_service.dart';
import 'package:soullocket_app/utils/services/home_couple_decor_sync_service.dart';
import 'package:soullocket_app/utils/services/home_drawing_service.dart';
import 'package:soullocket_app/utils/services/location_service.dart';
import 'package:soullocket_app/utils/services/love_insight_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/notification_installation_service.dart';
import 'package:soullocket_app/utils/services/system_call_bridge.dart';
import 'package:soullocket_app/utils/services/soul_event_reminder_service.dart';
import 'package:soullocket_app/utils/services/presence_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_service.dart';
import 'package:soullocket_app/utils/services/infrastructure/cloudflare_data_service.dart';
import 'package:soullocket_app/utils/services/notebook/notebook_d1_client.dart';
import '../utils/services/finance/finance_d1_client.dart';
import 'package:soullocket_app/utils/services/utilities/note_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';

final GetIt locator = GetIt.instance;

/// Đăng ký toàn bộ singleton service cho app.
///
/// Thứ tự nhóm theo domain giúp dễ audit khi phát triển:
/// - House: ngôi nhà (cặp đôi/độc thân), thành viên, settings.
/// - Realtime: presence + notification + location.
/// - Storage: secure storage, offline cache.
/// - Insight/Utility: love insight, utility chung, note.
void setupLocator() {
  locator.registerLazySingleton(
    () => AppReferralService(),
    dispose: (service) => service.dispose(),
  );
  locator.registerFactory(() => SoulBlockMemoryService());
  locator.registerFactory(() => FinanceD1Client());
  locator.registerFactory(() => SoulMergeMemories());
  locator.registerLazySingleton(() => MarketService.instance);
  locator.registerLazySingleton(
    () => CompanionRewardsService(),
    dispose: (s) => s.dispose(),
  );
  locator.registerLazySingleton(() => PrivacyCollectionService.instance);
  locator.registerLazySingleton(
    () => SoundService(),
    dispose: (s) => s.dispose(),
  );
  // ── House domain ────────────────────────────────────────────────────────
  locator.registerLazySingleton(() => HouseService());
  locator.registerLazySingleton(() => HouseSettingsService());
  locator.registerLazySingleton(() => HomeSharedNoteService());
  locator.registerLazySingleton(
    () => HomeCoupleDecorSyncService(),
    dispose: (service) => service.dispose(),
  );
  locator.registerLazySingleton(() => HomeDrawingService());

  // ── Realtime / Presence ─────────────────────────────────────────────────
  locator.registerLazySingleton(() => PresenceService());
  locator.registerLazySingleton(() => NotificationInstallationService());
  locator.registerLazySingleton(() => SystemCallBridge.instance);
  locator.registerLazySingleton(() => NotificationService());
  locator.registerLazySingleton(() => SoulEventReminderService.instance);
  locator.registerLazySingleton(() => CalendarReminderService.instance);
  locator.registerLazySingleton(() => HabitReminderService.instance);
  locator.registerLazySingleton(() => LocationService());

  // ── Storage & Cache ─────────────────────────────────────────────────────
  locator.registerLazySingleton(() => MediaDataPreferences.instance);
  locator.registerLazySingleton(() => StorageService());
  locator.registerLazySingleton(
    () => CloudflareDataService(),
    dispose: (service) => service.dispose(),
  );
  locator.registerLazySingleton(
    () => NotebookD1Client(),
    dispose: (client) => client.dispose(),
  );

  // ── Insight / Utility ───────────────────────────────────────────────────
  locator.registerLazySingleton(() => MapPlaceSearchService());
  locator.registerLazySingleton(() => LoveInsightService());
  locator.registerLazySingleton(() => UtilityService());
  locator.registerLazySingleton(() => NoteService());
}
