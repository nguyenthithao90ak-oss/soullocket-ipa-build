import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_config.dart';
import 'storage_service.dart';
import '../utils/flexible_date_input.dart';

class WidgetService {
  static const String appGroupId = AppConfig.iOSAppGroupId;
  static const String iOSWidgetName = 'WidgetCoupleProvider';
  static const String androidWidgetName = 'WidgetCoupleProvider';
  static const String qualifiedAndroidWidgetName =
      'com.soullocket.app.WidgetCoupleProvider';
  static const String defaultWidgetStyleKey = 'classic';
  static const String defaultHeartStyleKey = '❤️';
  static const Set<String> _supportedHeartStyleKeys = <String>{
    '🤍',
    '🤎',
    '♥️',
    '❣️',
    '❤️',
    '💞',
    '🖤',
    '💟',
    '❤️‍🔥',
    '🩷',
    '🩶',
    '🩵',
    '💘',
    '❤️‍🩹',
    '💓',
  };
  static const Set<String> _supportedWidgetStyleKeys = <String>{
    defaultWidgetStyleKey,
    'countdown',
  };
  static const MethodChannel _iosWidgetBridge = MethodChannel(
    'soullocket/widget_ios_bridge',
  );

  // Optimization constants
  static const int maxDiaryImagesForWidget = 10; // 10 ảnh gần nhất
  static const int widgetImageMaxWidth = 320; // Tăng một chút cho chất lượng
  static const int widgetImageMaxHeight = 250;
  static const int widgetImageQuality = 78; // 78% chất lượng JPEG

  static bool _didBootstrap = false;
  static final Map<String, Object?> _runtimeWidgetData = <String, Object?>{};
  static final StorageService _storageService = StorageService();
  static Future<void> ensureInitialized({bool forceUpdate = false}) async {
    if (kIsWeb) return;

    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
    } catch (e) {
      debugPrint('Widget setAppGroupId error: $e');
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
  } catch (error, stackTrace) {
    debugPrint('Widget bootstrap error: $error');
    debugPrintStack(stackTrace: stackTrace);
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

  static Future<void> refreshWidgetShell() async {
    if (kIsWeb) return;
    if (!_didBootstrap) {
      await ensureInitialized();
    }
    await _dispatchWidgetUpdate();
  }

  static Future<void> _dispatchWidgetUpdate() async {
    if (kIsWeb) return;
    if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: iOSWidgetName);
      return;
    }
    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      qualifiedAndroidName: qualifiedAndroidWidgetName,
    );
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
    if (showDiaryOnWidget) {
      return (
        showDiaryOnWidget: true,
        heartAnimated: false,
      );
    }
    return (
      showDiaryOnWidget: false,
      heartAnimated: heartAnimated,
    );
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

  static Future<void> _saveWidgetDataIfChanged<T>(String key, T value) async {
    final existing = _runtimeWidgetData.containsKey(key)
        ? _runtimeWidgetData[key]
        : await HomeWidget.getWidgetData<T>(key);
    if (existing == value) return;
    await HomeWidget.saveWidgetData<T>(key, value);
    _runtimeWidgetData[key] = value;
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
    await _saveIfMissing<bool>('heartAnimated', true);
    await _saveIfMissing<String>('heartStyleKey', defaultHeartStyleKey);
    await _saveIfMissing<String>('heartColorKey', 'rose');
    await _saveIfMissing<String>('diaryLayoutKey', 'single');
    await _saveIfMissing<String>('seasonModeKey', 'auto');
    await _saveIfMissing<String>('seasonResolvedKey', 'none');
    await _saveIfMissing<String>('loveDateText', '');
    await _saveIfMissing<String>('diaryImagePaths', '[]');
    await _saveIfMissing<String>('diaryImageUrlSignature', '');
    await _saveIfMissing<int>('diaryImageCount', 0);
  }

  static String normalizeHeartStyleKey(String? value) {
    final trimmed = value?.trim() ?? '';
    if (_supportedHeartStyleKeys.contains(trimmed)) {
      return trimmed;
    }
    return defaultHeartStyleKey;
  }

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
    final normalizedWidgetStyleKey =
        normalizeWidgetStyleKey(storedWidgetStyleKey);
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
      debugPrint('Widget cleanup error ($prefix): $e');
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

    final limitedUrls =
        urls.take(maxDiaryImagesForWidget).toList(growable: false);
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

      await _dispatchWidgetUpdate();
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  static Future<void> updateWidgetTheme(String bgTheme) async {
    try {
      await ensureInitialized();
      await _saveWidgetDataIfChanged<String>('bgTheme', bgTheme);
      await _dispatchWidgetUpdate();
    } catch (e) {
      debugPrint('Error updating widget theme: $e');
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
      await _dispatchWidgetUpdate();
    } catch (e) {
      debugPrint('Error updating widget appearance: $e');
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
      debugPrint('Widget shared container copy error: $e');
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
          '✅ Widget image saved: ${(compressedBytes.length / 1024).toStringAsFixed(2)}KB');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error downloading/compressing image: $e');
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
        return file.path;
      }

      final sourceFile = await _storageService.getCachedNetworkFile(
        url,
        namespace: 'widget_avatar',
        cacheKey: filename,
      );
      if (sourceFile != null && await sourceFile.exists()) {
        await file.writeAsBytes(await sourceFile.readAsBytes(), flush: true);
        return file.path;
      }
    } catch (e) {
      debugPrint('Error downloading image for widget: $e');
    }
    return null;
  }
}
