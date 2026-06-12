import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/widgets.dart';

import '../../services/home_startup_media_cache.dart';
import '../../services/offline_cache_service.dart';
import '../ui_prefs.dart';

class AppEntryHomeAssetPreparer {
  AppEntryHomeAssetPreparer({
    FirebaseDatabase? database,
    BaseCacheManager? cacheManager,
  })  : _database = database ?? FirebaseDatabase.instance,
        _cacheManager = cacheManager ?? DefaultCacheManager();

  final FirebaseDatabase _database;
  final BaseCacheManager _cacheManager;

  String? _preparedHouseId;
  String? _preparingHouseId;
  Future<void>? _prepareFuture;

  bool get isPreparing => _preparingHouseId != null;

  Future<void>? prepareIfNeeded(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return null;
    if (_preparedHouseId == normalizedHouseId) return null;
    if (_preparingHouseId == normalizedHouseId) return _prepareFuture;

    _preparingHouseId = normalizedHouseId;
    _prepareFuture = _prepare(normalizedHouseId);
    return _prepareFuture;
  }

  Future<void> _prepare(String houseId) async {
    try {
      await UiPrefs.ensureLoaded();
      final urls = <String>{};
      final backgroundUrl = UiPrefs.notifier.value.customBackgroundUrl.trim();
      if (backgroundUrl.isNotEmpty) {
        urls.add(backgroundUrl);
      }

      final settings = await _resolveHomeSettings(houseId);
      if (settings != null) {
        final avatar1 = (settings['avtUser1'] ?? '').toString().trim();
        final avatar2 = (settings['avtUser2'] ?? '').toString().trim();
        if (avatar1.isNotEmpty) urls.add(avatar1);
        if (avatar2.isNotEmpty) urls.add(avatar2);
      }

      for (final url in urls) {
        try {
          final file = await _cacheManager.getSingleFile(url);
          HomeStartupMediaCache.saveFile(url, file);
        } catch (_) {}
      }

      // Preload active Google Fonts to prevent 1s blinking/flickering
      final fontKey = UiPrefs.notifier.value.fontKey;
      TextStyle? selectedUiFont;
      switch (fontKey) {
        case 'patrickHand':
          selectedUiFont = GoogleFonts.patrickHand();
          break;
        case 'dancingScript':
          selectedUiFont = GoogleFonts.dancingScript();
          break;
        case 'caveat':
          selectedUiFont = GoogleFonts.caveat();
          break;
        case 'lora':
          selectedUiFont = GoogleFonts.lora();
          break;
        case 'nunito':
          selectedUiFont = GoogleFonts.nunito();
          break;
        case 'comfortaa':
          selectedUiFont = GoogleFonts.comfortaa();
          break;
        case 'playfair':
          selectedUiFont = GoogleFonts.playfairDisplay();
          break;
        case 'beVietnam':
          selectedUiFont = GoogleFonts.beVietnamPro();
          break;
        case 'quicksand':
        default:
          selectedUiFont = GoogleFonts.quicksand();
          break;
      }

      try {
        await GoogleFonts.pendingFonts([
          GoogleFonts.comfortaa(fontWeight: FontWeight.w900),
          if (selectedUiFont != null) selectedUiFont,
        ]);
      } catch (_) {}

      _preparedHouseId = houseId;
    } finally {
      if (_preparingHouseId == houseId) {
        _preparingHouseId = null;
      }
      _prepareFuture = null;
    }
  }

  Future<Map<String, dynamic>?> _resolveHomeSettings(String houseId) async {
    final cachedSettings = OfflineCacheService.loadCacheSync(
      'home_settings_$houseId',
    );
    if (cachedSettings is Map) {
      return Map<String, dynamic>.from(
        Map<dynamic, dynamic>.from(cachedSettings),
      );
    }

    try {
      final settingsSnap =
          await _database.ref('houses/$houseId/settings').get();
      if (settingsSnap.exists && settingsSnap.value is Map) {
        final settings = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(settingsSnap.value as Map),
        );
        await OfflineCacheService.saveCache(
          'home_settings_$houseId',
          settings,
        );
        return settings;
      }
    } catch (_) {}
    return null;
  }
}
