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
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/house_settings_service.dart';
import 'package:soullocket_app/utils/services/location_service.dart';
import 'package:soullocket_app/utils/services/love_insight_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/presence_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_service.dart';
import 'package:soullocket_app/utils/services/utilities/note_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';

final GetIt locator = GetIt.instance;

/// Đăng ký toàn bộ singleton service cho app.
///
/// Thứ tự nhóm theo domain giúp dễ audit khi phát triển:
/// - House: ngôi nhà (cặp đôi/độc thân), thành viên, settings.
/// - Realtime: presence + notification + location.
/// - Storage: secure storage, offline cache.
/// - Insight/Utility: love insight, utility chung, note.
void setupLocator() {
  // ── House domain ────────────────────────────────────────────────────────
  locator.registerLazySingleton(() => HouseService());
  locator.registerLazySingleton(() => HouseSettingsService());

  // ── Realtime / Presence ─────────────────────────────────────────────────
  locator.registerLazySingleton(() => PresenceService());
  locator.registerLazySingleton(() => NotificationService());
  locator.registerLazySingleton(() => LocationService());

  // ── Storage & Cache ─────────────────────────────────────────────────────
  locator.registerLazySingleton(() => StorageService());

  // ── Insight / Utility ───────────────────────────────────────────────────
  locator.registerLazySingleton(() => LoveInsightService());
  locator.registerLazySingleton(() => UtilityService());
  locator.registerLazySingleton(() => NoteService());
}