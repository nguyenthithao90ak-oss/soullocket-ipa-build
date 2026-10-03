import '../../models/widget_appearance.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../core/constants/app_locale_registry.dart';
import 'market_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_config.dart';
import '../../utils/app_error_mapper.dart';
import '../calendar_widget_snapshot.dart';
import '../calendar/holiday_occurrence_resolver.dart';
import '../sleep_tracking_math.dart';
import 'storage/storage_service.dart';
import 'package:soullocket_app/utils/flexible_date_input.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'house_service.dart';
import 'notification_service.dart';
import 'daily_quest_service.dart';
import 'package:soullocket_app/utils/services/health_cycle_service.dart';
import 'soul_event_service.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'holiday_service.dart';

class WidgetService {
  static bool get supportsAndroidWidgets => !kIsWeb && Platform.isAndroid;
  static bool get supportsMobileWidgets =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const String appGroupId = AppConfig.iOSAppGroupId;
  static const String iOSWidgetName = 'WidgetCoupleProvider';
  static const String iOSWidgetCycleName = 'WidgetCycleProvider';
  static const String iOSWidgetCalendarName = 'WidgetCalendarProvider';
  static const String iOSWidgetSoulEventName = 'WidgetSoulEventProvider';
  static const String iOSWidgetSleepName = 'WidgetSleepProvider';
  static const List<String> _iOSCoupleWidgetKinds = <String>[
    iOSWidgetName,
    'WidgetCoupleAccessoryAvatarProvider',
    'WidgetSoulMergeAccessoryProvider',
  ];
  static const List<String> _iOSUtilityWidgetKinds = <String>[
    iOSWidgetCycleName,
    iOSWidgetCalendarName,
    iOSWidgetSoulEventName,
    iOSWidgetSleepName,
  ];
  static const String androidWidgetName = 'WidgetCoupleProvider';
  static const String qualifiedAndroidWidgetName =
      'com.soullocket.app.WidgetCoupleProvider';
  static const String androidWidgetCycleName = 'WidgetCycleProvider';
  static const String qualifiedAndroidWidgetCycleName =
      'com.soullocket.app.WidgetCycleProvider';
  static const String androidWidgetCalendarName = 'WidgetCalendarProvider';
  static const String qualifiedAndroidWidgetCalendarName =
      'com.soullocket.app.WidgetCalendarProvider';
  static const String androidWidgetSoulEventName = 'WidgetSoulEventProvider';
  static const String qualifiedAndroidWidgetSoulEventName =
      'com.soullocket.app.WidgetSoulEventProvider';
  static const String androidWidgetSleepName = 'WidgetSleepProvider';
  static const String qualifiedAndroidWidgetSleepName =
      'com.soullocket.app.WidgetSleepProvider';
  static const String defaultWidgetStyleKey = 'classic';
  static const String defaultHeartStyleKey = '❤️';
  static const Set<String> _supportedWidgetStyleKeys = <String>{
    defaultWidgetStyleKey,
    'countdown',
    'soulevent',
  };
  static const MethodChannel _iosWidgetBridge = MethodChannel(
    'soullocket/widget_ios_bridge',
  );

  // Optimization constants
  static const int maxDiaryImagesForWidget = 12; // 12 ảnh gần nhất
  static const int widgetImageMaxWidth = 320; // Tăng một chút cho chất lượng
  static const int widgetImageMaxHeight = 250;
  static const int widgetImageQuality = 78; // 78% chất lượng JPEG

  static bool _didBootstrap = false;
  static int _sleepSyncRevision = 0;
  static int _calendarSyncRevision = 0;
  static final Map<String, Object?> _runtimeWidgetData = <String, Object?>{};
  static final StorageService _storageService = StorageService();
  static Future<void> ensureInitialized({bool forceUpdate = false}) async {
    if (kIsWeb) return;

    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      if (!_didBootstrap) {
        await _seedDefaultWidgetData();
        await _migrateLegacyStatusPlaceholders();
        await _normalizeStoredWidgetData();
        _didBootstrap = true;
      }

      if (forceUpdate) {
        await refreshWidgetShell();
      }
    } catch (error) {
      debugPrint(
        'Widget bootstrap error: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể khởi tạo widget lúc này.').message}',
      );
    }
  }

  static Future<void> requestPinWidget() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await ensureInitialized(forceUpdate: true);
    await HomeWidget.requestPinWidget(
      androidName: androidWidgetName,
      qualifiedAndroidName: qualifiedAndroidWidgetName,
    );
    await refreshWidgetShell();
  }

  static Future<void> requestPinCycleWidget() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await ensureInitialized(forceUpdate: true);
    await HomeWidget.requestPinWidget(
      androidName: androidWidgetCycleName,
      qualifiedAndroidName: qualifiedAndroidWidgetCycleName,
    );
    final houseId = await HouseService().getCurrentHouseId();
    if (houseId != null && houseId.isNotEmpty) {
      await syncCycleWidgetData(houseId: houseId);
    }
  }

  static Future<void> refreshWidgetShell() async {
    if (kIsWeb) return;
    if (!_didBootstrap) {
      await ensureInitialized();
    }
    await _dispatchWidgetUpdate();
  }

  static Future<void> _dispatchWidgetUpdate({
    bool includeUtilities = false,
  }) async {
    if (kIsWeb) return;
    if (Platform.isIOS) {
      for (final kind in <String>[
        ..._iOSCoupleWidgetKinds,
        if (includeUtilities) ..._iOSUtilityWidgetKinds,
      ]) {
        await HomeWidget.updateWidget(iOSName: kind);
      }
      return;
    }
    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      qualifiedAndroidName: qualifiedAndroidWidgetName,
    );
    if (includeUtilities) {
      for (final pair in <({String name, String qualified})>[
        (
          name: androidWidgetCycleName,
          qualified: qualifiedAndroidWidgetCycleName,
        ),
        (
          name: androidWidgetCalendarName,
          qualified: qualifiedAndroidWidgetCalendarName,
        ),
        (
          name: androidWidgetSoulEventName,
          qualified: qualifiedAndroidWidgetSoulEventName,
        ),
        (
          name: androidWidgetSleepName,
          qualified: qualifiedAndroidWidgetSleepName,
        ),
      ]) {
        await HomeWidget.updateWidget(
          androidName: pair.name,
          qualifiedAndroidName: pair.qualified,
        );
      }
    }
  }

  // Chỉ đổi tên provider theo nền tảng; App Group được khởi tạo trước khi ghi dữ liệu.
  static Future<void> _updateAuxiliaryWidget({
    required String androidName,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {
    if (!supportsMobileWidgets) return;
    if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: iOSName);
    } else {
      await HomeWidget.updateWidget(
        androidName: androidName,
        qualifiedAndroidName: qualifiedAndroidName,
      );
    }
  }

  static Future<void> _refreshSoulEventWidgets() async {
    await _updateAuxiliaryWidget(
      androidName: androidWidgetSoulEventName,
      qualifiedAndroidName: qualifiedAndroidWidgetSoulEventName,
      iOSName: iOSWidgetSoulEventName,
    );
    // Widget Cặp đôi cũng có thể đang chọn tab Kỷ niệm.
    if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: iOSWidgetName);
    }
  }

  static Future<void> resetWidgetState({bool refresh = true}) async {
    if (kIsWeb) return;

    _sleepSyncRevision++;
    await ensureInitialized();
    await HomeWidget.saveWidgetData<String>(
      'sleep_snapshot_v2',
      jsonEncode({
        'version': 2,
        'people': [
          const SleepPersonSnapshot(
            state: 'unknown',
            source: 'unknown',
          ).toMap(''),
          const SleepPersonSnapshot(
            state: 'unknown',
            source: 'unknown',
          ).toMap(''),
        ],
      }),
    );
    await HomeWidget.saveWidgetData<bool>('se_has_event', false);
    await _updateAuxiliaryWidget(
      androidName: androidWidgetSleepName,
      qualifiedAndroidName: qualifiedAndroidWidgetSleepName,
      iOSName: iOSWidgetSleepName,
    );
    await _refreshSoulEventWidgets();
    _runtimeWidgetData.clear();
    _didBootstrap = false;
    await ensureInitialized(forceUpdate: refresh);
  }

  /// Clears the in-memory widget data cache so that the next call to any
  /// sync method forces a full re-write to the shared HomeWidget storage,
  /// which ensures iOS WidgetKit receives fresh data and reloads the timeline.
  static void invalidateRuntimeCache() {
    _runtimeWidgetData.clear();
  }

  static String resolveSeasonEffect({
    required String seasonModeKey,
    String loveDate = '',
    String birthday1 = '',
    String birthday2 = '',
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final mode = seasonModeKey.trim().toLowerCase();

    switch (mode) {
      case 'none':
        return 'none';
      case 'valentine':
      case 'anniversary':
      case 'birthday':
        return mode;
      case 'auto':
      default:
        if (_isMonthDayMatch(today, month: 2, day: 14)) {
          return 'valentine';
        }
        if (_isAnniversaryWindow(loveDate, today, windowDays: 2)) {
          return 'anniversary';
        }
        if (_isBirthdayMatch(birthday1, today) ||
            _isBirthdayMatch(birthday2, today)) {
          return 'birthday';
        }
        return 'none';
    }
  }

  static String seasonLabel(String seasonKey) {
    switch (seasonKey.trim().toLowerCase()) {
      case 'valentine':
        return 'Valentine';
      case 'anniversary':
        return 'Kỷ niệm yêu';
      case 'birthday':
        return 'Sinh nhật';
      case 'none':
      default:
        return '';
    }
  }

  static ({bool showDiaryOnWidget, bool heartAnimated})
  normalizeWidgetDisplayMode({
    required bool showDiaryOnWidget,
    required bool heartAnimated,
  }) {
    return (showDiaryOnWidget: showDiaryOnWidget, heartAnimated: heartAnimated);
  }

  static String normalizeWidgetStyleKey(String? value) {
    final trimmed = value?.trim().toLowerCase() ?? '';
    if (_supportedWidgetStyleKeys.contains(trimmed)) {
      return trimmed;
    }
    return defaultWidgetStyleKey;
  }

  static bool _isMonthDayMatch(
    DateTime now, {
    required int month,
    required int day,
  }) {
    return now.month == month && now.day == day;
  }

  static bool _isBirthdayMatch(String raw, DateTime now) {
    final parsed = DateInputUtils.parse(
      raw,
      firstYear: 1900,
      lastYear: 2100,
      allowMissingYear: true,
      fallbackYear: now.year,
    );
    return parsed != null && parsed.month == now.month && parsed.day == now.day;
  }

  static bool _isAnniversaryWindow(
    String raw,
    DateTime now, {
    int windowDays = 2,
  }) {
    final parsed = DateInputUtils.parse(raw, firstYear: 1900, lastYear: 2100);
    if (parsed == null) return false;
    final anchor = DateTime(now.year, parsed.month, parsed.day);
    final today = DateTime(now.year, now.month, now.day);
    return (today.difference(anchor).inDays).abs() <= windowDays;
  }

  static Future<void> _saveIfMissing<T>(String key, T value) async {
    final existing = await HomeWidget.getWidgetData<T>(key);
    if (existing != null) {
      _runtimeWidgetData[key] = existing;
    }
    final shouldWrite =
        existing == null || (existing is String && existing.trim().isEmpty);
    if (shouldWrite) {
      await HomeWidget.saveWidgetData<T>(key, value);
      _runtimeWidgetData[key] = value;
    }
  }

  static Future<T?> _readWidgetData<T>(String key) async {
    if (_runtimeWidgetData.containsKey(key)) {
      return _runtimeWidgetData[key] as T?;
    }
    final value = await HomeWidget.getWidgetData<T>(key);
    if (value != null) {
      _runtimeWidgetData[key] = value;
    }
    return value;
  }

  static Future<bool> _saveWidgetDataIfChanged<T>(String key, T value) async {
    final existing = _runtimeWidgetData.containsKey(key)
        ? _runtimeWidgetData[key]
        : await HomeWidget.getWidgetData<T>(key);
    if (existing == value) return false;
    await HomeWidget.saveWidgetData<T>(key, value);
    _runtimeWidgetData[key] = value;
    return true;
  }

  static Future<void> _seedDefaultWidgetData() async {
    await _saveIfMissing<String>('name1', 'Bạn');
    await _saveIfMissing<String>('name2', 'Người ấy');
    await _saveIfMissing<String>('daysText', '0 ngày');
    await _saveIfMissing<String>('status1', 'Chạm để đồng bộ');
    await _saveIfMissing<String>('status2', 'Mở app để cập nhật');
    await _saveIfMissing<bool>('isOnline1', false);
    await _saveIfMissing<bool>('isOnline2', false);
    await _saveIfMissing<String>('weather1', '');
    await _saveIfMissing<String>('weather2', '');
    await _saveIfMissing<String>('stars1', '--');
    await _saveIfMissing<String>('stars2', '--');
    await _saveIfMissing<String>('bgTheme', 'pink');
    await _saveIfMissing<String>('widgetStyleKey', defaultWidgetStyleKey);
    await _saveIfMissing<bool>('showDiaryOnWidget', false);
    // Keep widget heart fixed (no random animation) by default.
    await _saveIfMissing<bool>('heartAnimated', false);
    await _saveIfMissing<String>('heartStyleKey', defaultHeartStyleKey);
    await _saveIfMissing<String>('widgetStickerKey', 'none');
    await _saveIfMissing<String>('photoFrameKey', 'rounded');
    await _saveIfMissing<String>('heartColorKey', 'rose');
    await _saveIfMissing<String>('diaryLayoutKey', 'single');
    await _saveIfMissing<String>('seasonModeKey', 'auto');
    await _saveIfMissing<String>('seasonResolvedKey', 'none');
    await _saveIfMissing<String>('loveDateText', '');
    await _saveIfMissing<String>('startDateRaw', '');
    await _saveIfMissing<String>('dayUnitText', 'ngày');
    await _saveIfMissing<String>('diaryImagePaths', '[]');
    await _saveIfMissing<String>('diaryImageUrlSignature', '');
    await _saveIfMissing<int>('diaryImageCount', 0);
    await _saveIfMissing<bool>('cycle_enabled', false);
    await _saveIfMissing<String>('cycle_phase', 'menstruation');
    await _saveIfMissing<String>('cycle_phase_label', '🩸 Giai đoạn Hành kinh');
    await _saveIfMissing<String>('cycle_next_period_in', '');
    await _saveIfMissing<String>('cycle_tip', '');
    await _saveIfMissing<String>('cycle_progress', '0.0');
    await _saveIfMissing<bool>('calendar_enabled', false);
    await _saveIfMissing<int>('calendar_payload_version', 2);
    await _saveIfMissing<String>('calendar_next_date_key', '');
    await _saveIfMissing<String>('calendar_locale', 'en');
    await _saveIfMissing<String>('calendar_market_code', 'ALL');
    await _saveIfMissing<String>('calendar_time_zone', '');
    await _saveIfMissing<String>('calendar_countdown', '');
    await _saveIfMissing<String>('calendar_next_date', '');
    await _saveIfMissing<String>('calendar_events_text', '');
  }

  static String normalizeHeartStyleKey(String? value) =>
      WidgetAppearance.normalizeHeart(value);

  static Future<void> _normalizeStoredWidgetData() async {
    final storedHeartStyleKey = await HomeWidget.getWidgetData<String>(
      'heartStyleKey',
    );
    final normalizedHeartStyleKey = normalizeHeartStyleKey(storedHeartStyleKey);
    if (storedHeartStyleKey != normalizedHeartStyleKey) {
      await HomeWidget.saveWidgetData<String>(
        'heartStyleKey',
        normalizedHeartStyleKey,
      );
    }
    _runtimeWidgetData['heartStyleKey'] = normalizedHeartStyleKey;

    final storedWidgetStyleKey = await HomeWidget.getWidgetData<String>(
      'widgetStyleKey',
    );
    final normalizedWidgetStyleKey = normalizeWidgetStyleKey(
      storedWidgetStyleKey,
    );
    if (storedWidgetStyleKey != normalizedWidgetStyleKey) {
      await HomeWidget.saveWidgetData<String>(
        'widgetStyleKey',
        normalizedWidgetStyleKey,
      );
    }
    _runtimeWidgetData['widgetStyleKey'] = normalizedWidgetStyleKey;
  }

  static String _normalizeLoveDateText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return DateInputUtils.normalizeForDisplay(
      trimmed,
      firstYear: 1900,
      lastYear: 2100,
    );
  }

  static Future<void> _migrateLegacyStatusPlaceholders() async {
    const legacyPlaceholders = <String>{
      'Chạm để đồng bộ',
      'Mở app để cập nhật',
      'Mở app để đồng bộ',
    };

    for (final key in const ['status1', 'status2']) {
      final value = await HomeWidget.getWidgetData<String>(key);
      final normalized = value?.trim();
      if (normalized != null && legacyPlaceholders.contains(normalized)) {
        await HomeWidget.saveWidgetData<String>(key, '');
        _runtimeWidgetData[key] = '';
      }
    }
  }

  static Future<void> _cleanupOldFiles({
    required String prefix,
    required String suffix,
    required List<String> keepPaths,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) return;

      final files = dir.listSync();
      for (final file in files) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          if (fileName.startsWith(prefix) && fileName.endsWith(suffix)) {
            if (!keepPaths.contains(file.path)) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Widget cleanup error ($prefix): ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể dọn dữ liệu widget lúc này.').message}',
      );
    }
  }

  static Future<void> _saveDiaryImages(
    List<String> diaryImageUrls, {
    required bool enabled,
  }) async {
    final urls = diaryImageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (!enabled || urls.isEmpty) {
      await _saveWidgetDataIfChanged<String>('diaryImagePaths', '[]');
      await _saveWidgetDataIfChanged<String>('diaryImageUrlSignature', '');
      await _saveWidgetDataIfChanged<int>('diaryImageCount', 0);
      await _cleanupOldFiles(prefix: 'diary_', suffix: '.jpg', keepPaths: []);
      return;
    }

    final limitedUrls = urls
        .take(maxDiaryImagesForWidget)
        .toList(growable: false);
    final nextSignature = _stableFileToken(limitedUrls.join('|'));
    final savedSignature =
        (await _readWidgetData<String>('diaryImageUrlSignature'))?.trim() ?? '';
    final savedPathsRaw =
        (await _readWidgetData<String>('diaryImagePaths'))?.trim() ?? '[]';
    if (savedSignature == nextSignature && savedPathsRaw != '[]') {
      return;
    }

    final savedPaths = <String>[];
    final localPaths = <String>[];
    for (final url in limitedUrls) {
      final localPath = await _downloadAndCompressImage(
        url,
        'diary_${_stableFileToken(url)}.jpg',
        useExisting: true,
      );
      if (localPath == null) continue;
      if (!localPaths.contains(localPath)) {
        localPaths.add(localPath);
      }

      final widgetPath = await _widgetReadablePath(
        localPath,
        sharedFileName: 'diary_${_stableFileToken(url)}.jpg',
      );
      if (!savedPaths.contains(widgetPath)) {
        savedPaths.add(widgetPath);
      }
    }

    await _saveWidgetDataIfChanged<String>(
      'diaryImagePaths',
      jsonEncode(savedPaths),
    );
    await _saveWidgetDataIfChanged<String>(
      'diaryImageUrlSignature',
      savedPaths.isEmpty ? '' : nextSignature,
    );
    await _saveWidgetDataIfChanged<int>('diaryImageCount', savedPaths.length);

    await _cleanupOldFiles(
      prefix: 'diary_',
      suffix: '.jpg',
      keepPaths: localPaths,
    );
  }

  static Future<void> updateWidget({
    required String name1,
    required String name2,
    required String daysText,
    String? avatarUrl1,
    String? avatarUrl2,
    String status1 = 'Đang hoạt động',
    String status2 = 'Đang hoạt động',
    bool isOnline1 = true,
    bool isOnline2 = true,
    String weather1 = '',
    String weather2 = '',
    String stars1 = '--',
    String stars2 = '--',
    String bgTheme = 'pink',
    String widgetStyleKey = defaultWidgetStyleKey,
    bool showDiaryOnWidget = false,
    bool heartAnimated = true,
    String heartStyleKey = defaultHeartStyleKey,
    String heartColorKey = 'rose',
    String diaryLayoutKey = 'single',
    String widgetStickerKey = 'none',
    String photoFrameKey = 'rounded',
    String seasonModeKey = 'auto',
    String loveDate = '',
    String birthday1 = '',
    String birthday2 = '',
    List<String> diaryImageUrls = const [],
    int battery1 = -1,
    int battery2 = -1,
    bool isCharging1 = false,
    bool isCharging2 = false,
  }) async {
    try {
      await ensureInitialized();
      final normalizedWidgetStyleKey = normalizeWidgetStyleKey(widgetStyleKey);
      final displayMode = normalizeWidgetDisplayMode(
        showDiaryOnWidget: showDiaryOnWidget,
        heartAnimated: heartAnimated,
      );
      final normalizedHeartStyleKey = normalizeHeartStyleKey(heartStyleKey);
      final themeChanged = await _saveWidgetDataIfChanged<String>(
        'bgTheme',
        bgTheme,
      );
      final motionChanged = await _saveWidgetDataIfChanged<bool>(
        'heartAnimated',
        displayMode.heartAnimated,
      );
      await _saveWidgetDataIfChanged<String>('name1', name1);
      await _saveWidgetDataIfChanged<String>('name2', name2);
      await _saveWidgetDataIfChanged<String>('daysText', daysText);
      await _saveWidgetDataIfChanged<String>('status1', status1);
      await _saveWidgetDataIfChanged<String>('status2', status2);
      await _saveWidgetDataIfChanged<bool>('isOnline1', isOnline1);
      await _saveWidgetDataIfChanged<bool>('isOnline2', isOnline2);
      await _saveWidgetDataIfChanged<String>('weather1', weather1);
      await _saveWidgetDataIfChanged<String>('weather2', weather2);
      await _saveWidgetDataIfChanged<String>('stars1', stars1);
      await _saveWidgetDataIfChanged<String>('stars2', stars2);
      await _saveWidgetDataIfChanged<String>(
        'widgetStyleKey',
        normalizedWidgetStyleKey,
      );
      await _saveWidgetDataIfChanged<bool>(
        'showDiaryOnWidget',
        displayMode.showDiaryOnWidget,
      );
      await _saveWidgetDataIfChanged<String>(
        'heartStyleKey',
        normalizedHeartStyleKey,
      );
      await _saveWidgetDataIfChanged<String>('heartColorKey', heartColorKey);
      await _saveWidgetDataIfChanged<String>('diaryLayoutKey', diaryLayoutKey);
      await _saveWidgetDataIfChanged<String>(
        'widgetStickerKey',
        WidgetAppearance.normalizeSticker(widgetStickerKey),
      );
      await _saveWidgetDataIfChanged<String>(
        'photoFrameKey',
        WidgetAppearance.normalizePhotoFrame(photoFrameKey),
      );
      await _saveWidgetDataIfChanged<String>('seasonModeKey', seasonModeKey);
      await _saveWidgetDataIfChanged<String>(
        'seasonResolvedKey',
        resolveSeasonEffect(
          seasonModeKey: seasonModeKey,
          loveDate: loveDate,
          birthday1: birthday1,
          birthday2: birthday2,
        ),
      );
      await _saveWidgetDataIfChanged<String>(
        'loveDateText',
        _normalizeLoveDateText(loveDate),
      );
      await _saveWidgetDataIfChanged<String>('startDateRaw', loveDate.trim());
      await _saveWidgetDataIfChanged<String>(
        'dayUnitText',
        daysText.trim().replaceFirst(RegExp(r'^\d+\s*'), '').trim().isEmpty
            ? L10nService().translate('comm_ngy_41ec10')
            : daysText.trim().replaceFirst(RegExp(r'^\d+\s*'), '').trim(),
      );
      // Battery of each user (partner perspective)
      if (battery1 >= 0) {
        await _saveWidgetDataIfChanged<int>('battery1', battery1);
        await _saveWidgetDataIfChanged<bool>('isCharging1', isCharging1);
      }
      if (battery2 >= 0) {
        await _saveWidgetDataIfChanged<int>('battery2', battery2);
        await _saveWidgetDataIfChanged<bool>('isCharging2', isCharging2);
      }

      final normalizedAvatarUrl1 = avatarUrl1?.trim() ?? '';
      if (normalizedAvatarUrl1.isNotEmpty) {
        final currentAvatar1Url =
            (await _readWidgetData<String>('avatar1Url'))?.trim() ?? '';
        final currentAvatar1Path =
            (await _readWidgetData<String>('avatar1Path'))?.trim() ?? '';
        if (currentAvatar1Url != normalizedAvatarUrl1 ||
            currentAvatar1Path.isEmpty) {
          final path1 = await _downloadImage(
            normalizedAvatarUrl1,
            'avatar1_${_stableFileToken(normalizedAvatarUrl1)}.webp',
            useExisting: true,
          );
          if (path1 != null) {
            final widgetPath1 = await _widgetReadablePath(
              path1,
              sharedFileName:
                  'avatar1_${_stableFileToken(normalizedAvatarUrl1)}.webp',
            );
            await _saveWidgetDataIfChanged<String>('avatar1Path', widgetPath1);
            await _saveWidgetDataIfChanged<String>(
              'avatar1Url',
              normalizedAvatarUrl1,
            );
            await _cleanupOldFiles(
              prefix: 'avatar1_',
              suffix: '.webp',
              keepPaths: [path1],
            );
          }
        }
      }

      final normalizedAvatarUrl2 = avatarUrl2?.trim() ?? '';
      if (normalizedAvatarUrl2.isNotEmpty) {
        final currentAvatar2Url =
            (await _readWidgetData<String>('avatar2Url'))?.trim() ?? '';
        final currentAvatar2Path =
            (await _readWidgetData<String>('avatar2Path'))?.trim() ?? '';
        if (currentAvatar2Url != normalizedAvatarUrl2 ||
            currentAvatar2Path.isEmpty) {
          final path2 = await _downloadImage(
            normalizedAvatarUrl2,
            'avatar2_${_stableFileToken(normalizedAvatarUrl2)}.webp',
            useExisting: true,
          );
          if (path2 != null) {
            final widgetPath2 = await _widgetReadablePath(
              path2,
              sharedFileName:
                  'avatar2_${_stableFileToken(normalizedAvatarUrl2)}.webp',
            );
            await _saveWidgetDataIfChanged<String>('avatar2Path', widgetPath2);
            await _saveWidgetDataIfChanged<String>(
              'avatar2Url',
              normalizedAvatarUrl2,
            );
            await _cleanupOldFiles(
              prefix: 'avatar2_',
              suffix: '.webp',
              keepPaths: [path2],
            );
          }
        }
      }

      await _saveDiaryImages(
        diaryImageUrls,
        enabled: displayMode.showDiaryOnWidget,
      );

      await _dispatchWidgetUpdate(
        includeUtilities: themeChanged || motionChanged,
      );
    } catch (e) {
      debugPrint(
        'Error updating widget: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể cập nhật widget lúc này.').message}',
      );
    }
  }

  static Future<void> updateWidgetTheme(String bgTheme) async {
    try {
      await ensureInitialized();
      await _saveWidgetDataIfChanged<String>('bgTheme', bgTheme);
      await _dispatchWidgetUpdate(includeUtilities: true);
    } catch (e) {
      debugPrint(
        'Error updating widget theme: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể cập nhật giao diện widget lúc này.').message}',
      );
    }
  }

  static Future<void> updateWidgetAppearance({
    required String bgTheme,
    String widgetStyleKey = defaultWidgetStyleKey,
    required bool showDiaryOnWidget,
    required bool heartAnimated,
    required String heartStyleKey,
    required String heartColorKey,
    String diaryLayoutKey = 'single',
    String widgetStickerKey = 'none',
    String photoFrameKey = 'rounded',
    String seasonModeKey = 'auto',
    String loveDate = '',
    String birthday1 = '',
    String birthday2 = '',
    List<String> diaryImageUrls = const [],
  }) async {
    try {
      await ensureInitialized();
      final normalizedWidgetStyleKey = normalizeWidgetStyleKey(widgetStyleKey);
      final displayMode = normalizeWidgetDisplayMode(
        showDiaryOnWidget: showDiaryOnWidget,
        heartAnimated: heartAnimated,
      );
      final normalizedHeartStyleKey = normalizeHeartStyleKey(heartStyleKey);
      await _saveWidgetDataIfChanged<String>('bgTheme', bgTheme);
      await _saveWidgetDataIfChanged<String>(
        'widgetStyleKey',
        normalizedWidgetStyleKey,
      );
      await _saveWidgetDataIfChanged<bool>(
        'showDiaryOnWidget',
        displayMode.showDiaryOnWidget,
      );
      await _saveWidgetDataIfChanged<bool>(
        'heartAnimated',
        displayMode.heartAnimated,
      );
      await _saveWidgetDataIfChanged<String>(
        'heartStyleKey',
        normalizedHeartStyleKey,
      );
      await _saveWidgetDataIfChanged<String>('heartColorKey', heartColorKey);
      await _saveWidgetDataIfChanged<String>('diaryLayoutKey', diaryLayoutKey);
      await _saveWidgetDataIfChanged<String>(
        'widgetStickerKey',
        WidgetAppearance.normalizeSticker(widgetStickerKey),
      );
      await _saveWidgetDataIfChanged<String>(
        'photoFrameKey',
        WidgetAppearance.normalizePhotoFrame(photoFrameKey),
      );
      await _saveWidgetDataIfChanged<String>('seasonModeKey', seasonModeKey);
      await _saveWidgetDataIfChanged<String>(
        'seasonResolvedKey',
        resolveSeasonEffect(
          seasonModeKey: seasonModeKey,
          loveDate: loveDate,
          birthday1: birthday1,
          birthday2: birthday2,
        ),
      );
      await _saveWidgetDataIfChanged<String>(
        'loveDateText',
        _normalizeLoveDateText(loveDate),
      );
      await _saveDiaryImages(
        diaryImageUrls,
        enabled: displayMode.showDiaryOnWidget,
      );
      await _dispatchWidgetUpdate(includeUtilities: true);
    } catch (e) {
      debugPrint(
        'Error updating widget appearance: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể cập nhật giao diện widget lúc này.').message}',
      );
    }
  }

  static String _stableFileToken(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  static Future<String> _widgetReadablePath(
    String sourcePath, {
    required String sharedFileName,
  }) async {
    if (kIsWeb || !Platform.isIOS) return sourcePath;

    try {
      final sharedPath = await _iosWidgetBridge.invokeMethod<String>(
        'copyFileToAppGroup',
        <String, dynamic>{
          'groupId': appGroupId,
          'sourcePath': sourcePath,
          'fileName': sharedFileName,
        },
      );
      if (sharedPath != null && sharedPath.trim().isNotEmpty) {
        return sharedPath;
      }
    } catch (e) {
      debugPrint(
        'Widget shared container copy error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể sao chép dữ liệu widget sang vùng chia sẻ.').message}',
      );
    }

    return sourcePath;
  }

  static Future<String?> _downloadAndCompressImage(
    String url,
    String filename, {
    bool useExisting = false,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');

      // 🔄 Nếu file đã tồn tại, sử dụng nó (tiết kiệm băng thông)
      if (useExisting && await file.exists()) {
        final fileSize = await file.length();
        // Kiểm tra nếu file hợp lệ (> 100 bytes)
        if (fileSize > 100) {
          return file.path;
        }
      }

      // ⬇️ Tải ảnh từ URL
      final bytes = await _storageService.downloadBytesWithCache(
        url,
        namespace: 'widget_diary',
        cacheKey: filename,
      );
      if (bytes == null || bytes.isEmpty) {
        debugPrint('Failed to resolve widget diary image: $url');
        return null;
      }

      // 📦 Compress ảnh để tiết kiệm băng thông + dung lượng
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: widgetImageMaxHeight,
        minWidth: widgetImageMaxWidth,
        quality: widgetImageQuality, // 78% chất lượng
      );

      // 💾 Lưu ảnh đã compress
      await file.writeAsBytes(compressedBytes, flush: true);
      debugPrint(
        '✅ Widget image saved: ${(compressedBytes.length / 1024).toStringAsFixed(2)}KB',
      );
      return file.path;
    } catch (e) {
      debugPrint(
        '❌ Error downloading/compressing image: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể tải hoặc nén ảnh widget.').message}',
      );
    }
    return null;
  }

  static Future<String?> _downloadImage(
    String url,
    String filename, {
    bool useExisting = false,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      if (useExisting && await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 100) {
          return file.path;
        }
      }

      final sourceFile = await _storageService.getCachedNetworkFile(
        url,
        namespace: 'widget_avatar',
        cacheKey: filename,
      );
      if (sourceFile != null && await sourceFile.exists()) {
        final bytes = await sourceFile.readAsBytes();
        try {
          final compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            minHeight: 180,
            minWidth: 180,
            quality: 80,
          );
          await file.writeAsBytes(compressedBytes, flush: true);
          debugPrint(
            '✅ Widget avatar compressed and saved: ${(compressedBytes.length / 1024).toStringAsFixed(2)}KB',
          );
        } catch (compressErr) {
          debugPrint(
            '⚠️ Error compressing widget avatar, fallback to raw: $compressErr',
          );
          await file.writeAsBytes(bytes, flush: true);
        }
        return file.path;
      }
    } catch (e) {
      debugPrint(
        'Error downloading image for widget: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể tải ảnh cho widget.').message}',
      );
    }
    return null;
  }

  static Future<void> checkAndProcessPendingWidgetActions() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final actionStr = await HomeWidget.getWidgetData<String>(
        'pendingWidgetAction',
      );
      if (actionStr == null || actionStr.trim().isEmpty) return;

      final parts = actionStr.split('_');
      if (parts.isEmpty) return;
      final actionType = parts[0];

      final prefs = await SharedPreferences.getInstance();
      final lastProcessedAction =
          prefs.getString('il_last_processed_widget_action') ?? '';
      if (lastProcessedAction == actionStr) {
        await HomeWidget.saveWidgetData<String>('pendingWidgetAction', '');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final houseId = await HouseService().getCurrentHouseId();
      if (houseId == null || houseId.trim().isEmpty) return;

      final currentRole = prefs.getString('il_role') == 'user2'
          ? 'user2'
          : 'user1';
      final partnerRole = currentRole == 'user1' ? 'user2' : 'user1';

      final data = await HouseService().getHouseSettings(houseId);
      if (data == null) return;
      final myName =
          (currentRole == 'user1' ? data['nameU1'] : data['nameU2'])
              ?.toString()
              .trim() ??
          'Bạn';
      final partnerName =
          (partnerRole == 'user1' ? data['nameU1'] : data['nameU2'])
              ?.toString()
              .trim() ??
          'Người ấy';
      final myAvatar =
          (currentRole == 'user1' ? data['avtUser1'] : data['avtUser2'])
              ?.toString()
              .trim() ??
          '';

      final String title;
      final String body;
      final String message;
      final String notificationBody;

      switch (actionType) {
        case 'heart':
        default:
          title = '$myName gửi ngàn nỗi nhớ';
          body = '$partnerName sẽ thấy nỗi nhớ này ngay khi online.';
          message = 'Nhớ bạn nhiều lắm!';
          notificationBody = 'mở app để nhận nỗi nhớ ngay nhé.';
          break;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'type': 'miss',
        'emoji': '❤️',
        'from': myName,
        'fromUid': user.uid,
        'fromRole': currentRole,
        'fromRoleLabel': currentRole == 'user1' ? 'User 1' : 'User 2',
        'fromAvatar': myAvatar,
        'toRole': partnerRole,
        'toName': partnerName,
        'title': title,
        'body': body,
        'message': message,
        'sentAt': nowMs,
        'ts': ServerValue.timestamp,
      };

      final dbRef = FirebaseDatabase.instance.ref();
      final inboxRef = dbRef
          .child('houses/$houseId/partner_inbox/$partnerRole')
          .push();
      await dbRef.child('houses/$houseId/alerts').push().set(payload);
      await inboxRef.set({...payload, 'timestamp': ServerValue.timestamp});
      await dbRef.child('houses/$houseId/interactions/miss').set({
        ...payload,
        'timestamp': ServerValue.timestamp,
      });

      try {
        await NotificationService().sendPartnerNotification(
          houseId: houseId,
          title: title,
          body: '$partnerName $notificationBody',
          data: {
            'screen': 'home',
            'type': 'partner_care',
            'careType': 'miss',
            'houseId': houseId,
          },
        );
      } catch (error) {
        debugPrint('Widget partner notification failed: $error');
      }

      try {
        await DailyQuestService().recordProgress('partner_interaction');
      } catch (error) {
        debugPrint('Widget daily quest progress failed: $error');
      }

      await prefs.setString('il_last_processed_widget_action', actionStr);
      await HomeWidget.saveWidgetData<String>('pendingWidgetAction', '');

      debugPrint('Processed quick heart from interactive widget!');
    } catch (e) {
      debugPrint('Error processing pending widget actions: $e');
    }
  }

  static Future<String?> startLiveActivity({
    required String title,
    required String label,
    required DateTime endTime,
  }) async {
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      final String? activityId = await _iosWidgetBridge
          .invokeMethod<String>('startLiveActivity', <String, dynamic>{
            'title': title,
            'label': label,
            'endTimeMs': endTime.millisecondsSinceEpoch.toDouble(),
          });
      return activityId;
    } catch (e) {
      debugPrint('Error starting Live Activity: $e');
      return null;
    }
  }

  static Future<bool> updateLiveActivity({
    required String activityId,
    required String label,
    required DateTime endTime,
  }) async {
    if (kIsWeb || !Platform.isIOS) return false;
    try {
      final bool? success = await _iosWidgetBridge
          .invokeMethod<bool>('updateLiveActivity', <String, dynamic>{
            'activityId': activityId,
            'label': label,
            'endTimeMs': endTime.millisecondsSinceEpoch.toDouble(),
          });
      return success ?? false;
    } catch (e) {
      debugPrint('Error updating Live Activity: $e');
      return false;
    }
  }

  static Future<bool> endLiveActivity({required String activityId}) async {
    if (kIsWeb || !Platform.isIOS) return false;
    try {
      final bool? success = await _iosWidgetBridge.invokeMethod<bool>(
        'endLiveActivity',
        <String, dynamic>{'activityId': activityId},
      );
      return success ?? false;
    } catch (e) {
      debugPrint('Error ending Live Activity: $e');
      return false;
    }
  }

  static Future<void> syncCycleWidgetData({required String houseId}) =>
      _syncCycleWidgetData(
        () => HealthCycleService().getCycleSettings(houseId),
      );

  static Future<void> updateCycleWidgetData({required Object? cycleData}) =>
      _syncCycleWidgetData(() async {
        return cycleData is Map
            ? CycleSettings.fromMap(Map<String, dynamic>.from(cycleData))
            : null;
      });

  static Future<void> _syncCycleWidgetData(
    Future<CycleSettings?> Function() loadSettings,
  ) async {
    if (!supportsMobileWidgets) return;
    try {
      await ensureInitialized();
      final hasConsent = await SharedPreferences.getInstance().then(
        (prefs) => prefs.getBool('il_health_consent') ?? false,
      );
      if (!hasConsent) {
        await _saveWidgetDataIfChanged<bool>('cycle_enabled', false);
        await _updateAuxiliaryWidget(
          androidName: androidWidgetCycleName,
          qualifiedAndroidName: qualifiedAndroidWidgetCycleName,
          iOSName: iOSWidgetCycleName,
        );
        return;
      }

      final settings = await loadSettings();
      if (settings == null) {
        await _saveWidgetDataIfChanged<bool>('cycle_enabled', false);
        await _updateAuxiliaryWidget(
          androidName: androidWidgetCycleName,
          qualifiedAndroidName: qualifiedAndroidWidgetCycleName,
          iOSName: iOSWidgetCycleName,
        );
        return;
      }

      final state = HealthCycleService().calculateCurrentState(settings);

      await _saveWidgetDataIfChanged<bool>('cycle_enabled', true);
      await _saveWidgetDataIfChanged<String>('cycle_phase', state.phase.name);
      await _saveWidgetDataIfChanged<String>(
        'cycle_phase_label',
        state.phaseLabel,
      );
      await _saveWidgetDataIfChanged<String>(
        'cycle_next_period_in',
        '${L10nService().translate('p3_health_next_period')}: '
            '${state.nextPeriodIn == 0 ? L10nService().translate('milestone_today') : L10nService().format('milestone_days_left', {'days': state.nextPeriodIn})}',
      );
      await _saveWidgetDataIfChanged<String>(
        'cycle_next_period_days',
        state.nextPeriodIn.toString(),
      );
      await _saveWidgetDataIfChanged<String>(
        'cycle_days_label',
        L10nService().translate('p3_health_days_remaining'),
      );
      await _saveWidgetDataIfChanged<String>('cycle_tip', state.tip);
      await _saveWidgetDataIfChanged<String>(
        'cycle_progress',
        (state.progressPercent / 100.0).toStringAsFixed(3),
      );

      await _updateAuxiliaryWidget(
        androidName: androidWidgetCycleName,
        qualifiedAndroidName: qualifiedAndroidWidgetCycleName,
        iOSName: iOSWidgetCycleName,
      );
    } catch (e) {
      debugPrint(
        'Error syncing cycle widget: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  static Future<String> _formatCalendarDate(
    DateTime date, {
    bool full = false,
  }) async {
    final locale = AppLocaleRegistry.formattingLocale(
      L10nService().locale,
      MarketService.instance.marketCode,
    );
    final strings = await GlobalMaterialLocalizations.delegate.load(locale);
    return full ? strings.formatFullDate(date) : strings.formatMediumDate(date);
  }

  static Future<void> syncCalendarWidgetData({
    required String houseId,
    Object? calendarData,
  }) async {
    if (!supportsMobileWidgets) return;
    final revision = ++_calendarSyncRevision;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final initialScope = '$uid\u0000$houseId';
    bool active() => revision == _calendarSyncRevision &&
        FirebaseAuth.instance.currentUser?.uid == uid &&
        '$uid\u0000$houseId' == initialScope;
    try {
      await ensureInitialized();
      if (!active()) return;
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      final planEvent = await CalendarWidgetSnapshot.resolve(
        now: today,
        calendarData: calendarData,
        loadPage: (afterKey, limit) async {
          final query = FirebaseDatabase.instance
              .ref('houses/$houseId/calendar')
              .orderByKey();
          final pageQuery = afterKey == null
              ? query.startAt(CalendarWidgetSnapshot.dateKeyFor(today))
              : query.startAfter(afterKey);
          final snap = await pageQuery.limitToFirst(limit).get();
          return snap.value is Map
              ? Map<String, dynamic>.from(snap.value as Map)
              : <String, dynamic>{};
        },
      );
      if (!active()) return;

      final todayDate = DateTime(today.year, today.month, today.day);
      final nextHoliday = _nextHolidayWidgetSnapshot(todayDate);
      final nextEvent = _mergeCalendarWidgetSnapshots(planEvent, nextHoliday);

      if (nextEvent == null) {
        if (!active()) return;
        await _saveWidgetDataIfChanged<bool>('calendar_enabled', false);
        await _saveWidgetDataIfChanged<int>('calendar_payload_version', 2);
        await _saveWidgetDataIfChanged<String>('calendar_next_date_key', '');
        await _saveWidgetDataIfChanged<String>('calendar_events_text', '');
        await _updateAuxiliaryWidget(
          androidName: androidWidgetCalendarName,
          qualifiedAndroidName: qualifiedAndroidWidgetCalendarName,
          iOSName: iOSWidgetCalendarName,
        );
        return;
      }

      final diffDays = SoulEvent.daysBetween(nextEvent.date, todayMidnight);
      String countdownText = '';
      if (diffDays == 0) {
        countdownText = L10nService().translate('milestone_today');
      } else if (diffDays == 1) {
        countdownText = L10nService().translate('milestone_tomorrow');
      } else {
        countdownText = L10nService().format('milestone_days_left', {
          'days': diffDays,
        });
      }

      final dateLabel = await _formatCalendarDate(nextEvent.date, full: true);
      if (!active()) return;

      final eventsText = nextEvent.titles.map((title) => '• $title').join('\n');

      await _saveWidgetDataIfChanged<bool>('calendar_enabled', true);
      await _saveWidgetDataIfChanged<int>('calendar_payload_version', 2);
      await _saveWidgetDataIfChanged<String>(
        'calendar_countdown',
        countdownText,
      );
      await _saveWidgetDataIfChanged<String>('calendar_next_date', dateLabel);
      await _saveWidgetDataIfChanged<String>(
        'calendar_next_date_key',
        CalendarWidgetSnapshot.dateKeyFor(nextEvent.date),
      );
      await _saveWidgetDataIfChanged<String>(
        'calendar_locale',
        L10nService().locale.toLanguageTag(),
      );
      await _saveWidgetDataIfChanged<String>(
        'calendar_market_code',
        MarketService.instance.marketCode,
      );
      await _saveWidgetDataIfChanged<String>(
        'calendar_time_zone',
        MarketService.instance.preferences.timeZoneId ?? '',
      );
      await _saveWidgetDataIfChanged<String>(
        'calendar_events_text',
        eventsText,
      );
      if (!active()) return;

      await _updateAuxiliaryWidget(
        androidName: androidWidgetCalendarName,
        qualifiedAndroidName: qualifiedAndroidWidgetCalendarName,
        iOSName: iOSWidgetCalendarName,
      );
    } catch (e) {
      debugPrint(
        'Error syncing calendar widget: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  static CalendarWidgetSnapshot? _nextHolidayWidgetSnapshot(DateTime today) {
    final holidays = HolidayService.getApplicableHolidays();
    final occurrences = HolidayOccurrenceResolver.nextOccurrences(
      holidays,
      from: today,
    );
    if (occurrences.isEmpty) return null;
    final date = occurrences.first.date;
    final titles = occurrences
        .where((occurrence) => occurrence.date == date)
        .map((occurrence) => HolidayService.getLocalizedName(occurrence.holiday))
        .toList(growable: false);
    return CalendarWidgetSnapshot(date: date, titles: titles);
  }

  static CalendarWidgetSnapshot? _mergeCalendarWidgetSnapshots(
    CalendarWidgetSnapshot? plan,
    CalendarWidgetSnapshot? holiday,
  ) {
    if (plan == null) return holiday;
    if (holiday == null) return plan;
    if (holiday.date.isBefore(plan.date)) return holiday;
    if (holiday.date.isAfter(plan.date)) return plan;
    return CalendarWidgetSnapshot(
      date: plan.date,
      titles: List.unmodifiable([...plan.titles, ...holiday.titles]),
    );
  }

  static Future<void> requestPinCalendarWidget() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await ensureInitialized(forceUpdate: true);
    await HomeWidget.requestPinWidget(
      androidName: androidWidgetCalendarName,
      qualifiedAndroidName: qualifiedAndroidWidgetCalendarName,
    );
    final houseId = await HouseService().getCurrentHouseId();
    if (houseId != null && houseId.isNotEmpty) {
      await syncCalendarWidgetData(houseId: houseId);
    }
  }

  static Future<void> syncSoulEventWidgetData({required String houseId}) async {
    if (kIsWeb) return;
    await ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final useCustom = prefs.getBool('widget_use_custom_event') ?? false;

      if (useCustom) {
        final customTitle = prefs.getString('widget_custom_event_title') ?? '';
        final customDate = prefs.getString('widget_custom_event_date') ?? '';
        final customColor =
            prefs.getString('widget_custom_event_color') ?? '#EC4899';

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        DateTime? parsedDate = DateInputUtils.parse(
          customDate,
          firstYear: 1900,
          lastYear: 2100,
        );

        var displayDate = customDate.isEmpty ? '--/--/----' : customDate;
        var targetDateKey = '';
        await _saveWidgetDataIfChanged<bool>(
          'se_has_event',
          parsedDate != null,
        );
        String daysStr = '0';
        String labelStr = L10nService().translate(
          'p8_events_days_remaining_label',
        );
        if (parsedDate != null) {
          final nextDate = SoulEvent(
            id: 'custom-widget',
            title: customTitle,
            dateMs: parsedDate.millisecondsSinceEpoch,
            civilDate: SoulEvent.dateKey(parsedDate),
            category: 'all',
            colorHex: customColor,
            createdAt: 0,
            isAnniversary: true,
          ).calculateNextOccurrence(today)!;
          targetDateKey = SoulEvent.dateKey(nextDate);
          displayDate = await _formatCalendarDate(nextDate);
          final diff = SoulEvent.daysBetween(nextDate, today);
          final isToday = SoulEvent.daysBetween(nextDate, today) == 0;
          if (isToday) {
            daysStr = L10nService().translate('p8_events_today_upper');
            labelStr = '🎉';
          } else {
            daysStr = diff.toString();
            labelStr = L10nService().translate(
              'p8_events_days_remaining_label',
            );
          }
        }

        await _saveWidgetDataIfChanged(
          'se_title',
          customTitle.isEmpty
              ? L10nService().translate('p8_events_title')
              : customTitle,
        );
        await _saveWidgetDataIfChanged('se_target_date', targetDateKey);
        await _saveWidgetDataIfChanged('se_date', displayDate);
        await _saveWidgetDataIfChanged('se_days', daysStr);
        await _saveWidgetDataIfChanged('se_label', labelStr);
        await _saveWidgetDataIfChanged('se_color', customColor);

        await _refreshSoulEventWidgets();
        return;
      }

      final service = SoulEventService();
      final events = await service.getEvents(houseId);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      SoulEvent? topEvent;
      int minDays = 99999;

      for (final event in events) {
        if (!event.isPinned) continue;

        final nextDate = event.calculateNextOccurrence(today);
        if (nextDate != null) {
          final diff = SoulEvent.daysBetween(nextDate, today);
          if (diff >= 0 && diff < minDays) {
            minDays = diff;
            topEvent = event;
          }
        }
      }

      // Fallback: nearest upcoming event if no pinned event
      if (topEvent == null && events.isNotEmpty) {
        for (final event in events) {
          final nextDate = event.calculateNextOccurrence(today);
          if (nextDate != null) {
            final diff = SoulEvent.daysBetween(nextDate, today);
            if (diff >= 0 && diff < minDays) {
              minDays = diff;
              topEvent = event;
            }
          }
        }
      }

      await _saveWidgetDataIfChanged<bool>('se_has_event', topEvent != null);
      if (topEvent != null) {
        final nextDate = topEvent.calculateNextOccurrence(today)!;
        await _saveWidgetDataIfChanged(
          'se_target_date',
          SoulEvent.dateKey(nextDate),
        );
        final isToday = SoulEvent.daysBetween(nextDate, today) == 0;

        await _saveWidgetDataIfChanged('se_title', topEvent.title);
        await _saveWidgetDataIfChanged(
          'se_date',
          await _formatCalendarDate(nextDate),
        );

        if (isToday) {
          await _saveWidgetDataIfChanged(
            'se_days',
            L10nService().translate('p8_events_today_upper'),
          );
          await _saveWidgetDataIfChanged('se_label', '🎉');
        } else {
          await _saveWidgetDataIfChanged('se_days', minDays.toString());
          await _saveWidgetDataIfChanged(
            'se_label',
            L10nService().translate('p8_events_days_remaining_label'),
          );
        }

        final colorHex = topEvent.colorHex.isNotEmpty
            ? topEvent.colorHex
            : '#FF4D94';
        await _saveWidgetDataIfChanged('se_color', colorHex);
      } else {
        await _saveWidgetDataIfChanged(
          'se_title',
          L10nService().translate('p8_events_title'),
        );
        await _saveWidgetDataIfChanged('se_target_date', '');
        await _saveWidgetDataIfChanged('se_date', '--/--/----');
        await _saveWidgetDataIfChanged('se_days', '0');
        await _saveWidgetDataIfChanged(
          'se_label',
          L10nService().translate('p8_events_days_remaining_label'),
        );
        await _saveWidgetDataIfChanged('se_color', '#FF4D94');
      }

      await _refreshSoulEventWidgets();
    } catch (e) {
      debugPrint(
        'Error syncing soul event widget: \${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  static Future<void> requestPinSoulEventWidget() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await ensureInitialized(forceUpdate: true);
    await HomeWidget.requestPinWidget(
      androidName: androidWidgetSoulEventName,
      qualifiedAndroidName: qualifiedAndroidWidgetSoulEventName,
    );
    final houseId = await HouseService().getCurrentHouseId();
    if (houseId != null && houseId.isNotEmpty) {
      await syncSoulEventWidgetData(houseId: houseId);
    }
  }

  static Future<void> syncSoulMergeWidgetData({
    required String message,
    required String senderName,
  }) async {
    try {
      await ensureInitialized();
      await _saveWidgetDataIfChanged<String>('soulMergeMessage', message);
      await _saveWidgetDataIfChanged<String>('soulMergeSenderName', senderName);

      if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: iOSWidgetName);
      }
    } catch (e) {
      debugPrint(
        'Error syncing soul merge widget: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }

  /// Bản ghi v2 nguyên khối: UI/native không suy trạng thái từ text cũ.
  static Future<void> syncSleepWidgetData({
    required String houseId,
    Map<dynamic, dynamic>? presenceData,
  }) async {
    if (!supportsMobileWidgets || houseId.isEmpty) return;
    final revision = ++_sleepSyncRevision;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || await HouseService().getCurrentHouseId() != houseId) {
      return;
    }
    final raw =
        presenceData ??
        (await FirebaseDatabase.instance.ref('houses/$houseId/presence').get())
            .value;
    final data = raw is Map ? raw : <dynamic, dynamic>{};
    await ensureInitialized();
    if (revision != _sleepSyncRevision ||
        FirebaseAuth.instance.currentUser?.uid != uid ||
        await HouseService().getCurrentHouseId() != houseId) {
      return;
    }
    final name1 =
        await HomeWidget.getWidgetData<String>('name1') ??
        L10nService().translate('p3_sleep_default_me');
    final name2 =
        await HomeWidget.getWidgetData<String>('name2') ??
        L10nService().translate('p3_sleep_default_partner');
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshot = jsonEncode({
      'version': 2,
      'houseId': houseId,
      'uid': uid,
      'people': [
        SleepPersonSnapshot.fromPresence(
          sleepRoleData(data, 'user1'),
          now,
        ).toMap(name1),
        SleepPersonSnapshot.fromPresence(
          sleepRoleData(data, 'user2'),
          now,
        ).toMap(name2),
      ],
    });
    if (revision != _sleepSyncRevision ||
        FirebaseAuth.instance.currentUser?.uid != uid ||
        await HouseService().getCurrentHouseId() != houseId) {
      return;
    }
    await _saveWidgetDataIfChanged<String>('sleep_snapshot_v2', snapshot);
    await _updateAuxiliaryWidget(
      androidName: androidWidgetSleepName,
      qualifiedAndroidName: qualifiedAndroidWidgetSleepName,
      iOSName: iOSWidgetSleepName,
    );
  }

  static Future<void> updateSleepWidgetData({
    required String myName,
    required String partnerName,
    required String myStatus,
    required String partnerStatus,
    required String myTime,
    required String partnerTime,
    required String summary,
  }) async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
      await _saveWidgetDataIfChanged<String>('sleep_my_name', myName);
      await _saveWidgetDataIfChanged<String>('sleep_partner_name', partnerName);
      await _saveWidgetDataIfChanged<String>('sleep_my_status', myStatus);
      await _saveWidgetDataIfChanged<String>(
        'sleep_partner_status',
        partnerStatus,
      );
      await _saveWidgetDataIfChanged<String>('sleep_my_time', myTime);
      await _saveWidgetDataIfChanged<String>('sleep_partner_time', partnerTime);
      await _saveWidgetDataIfChanged<String>('sleep_summary', summary);

      await _updateAuxiliaryWidget(
        androidName: androidWidgetSleepName,
        qualifiedAndroidName: qualifiedAndroidWidgetSleepName,
        iOSName: iOSWidgetSleepName,
      );
    } catch (e) {
      debugPrint('[WidgetService] updateSleepWidgetData error: $e');
    }
  }
}
