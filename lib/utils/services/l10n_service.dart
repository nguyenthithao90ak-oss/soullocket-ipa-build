import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';
import '../../core/constants/app_locale_registry.dart';

part 'l10n/l10n_asset_loader.dart';
part 'l10n/l10n_format_helper.dart';
part 'l10n/l10n_locale_state.dart';
part 'l10n/l10n_translation_lookup.dart';
part 'l10n/l10n_translations.dart';
part 'l10n/l10n_web_parity_translations.dart';
part 'l10n/l10n_value_to_key_helper.dart';

class L10nService extends ChangeNotifier {
  static final L10nService _instance = L10nService._internal();
  static final Map<String, String> _viValueToKey =
      _L10nValueToKeyHelper.buildFromSources([
        _L10nStaticData._vi,
        _L10nStaticData._viWebParity,
      ]);

  factory L10nService() => _instance;
  L10nService._internal();

  @visibleForTesting
  L10nService.forTesting();

  final _L10nLocaleState _state = _L10nLocaleState();
  final _L10nTranslationLookup _lookup = _L10nTranslationLookup();
  final _L10nFormatHelper _formatHelper = const _L10nFormatHelper();
  int _localeRequest = 0;
  Future<void>? _preferenceWrite;

  Locale get locale => _state.currentLocale;
  String get localeCode {
    final locale = _state.currentLocale;
    return _L10nAssetLoader.supportedLocales.firstWhere(
      (code) => _L10nAssetLoader.supportedLocaleMap[code] == locale,
      orElse: () => locale.languageCode,
    );
  }

  List<Locale> get supportedLocales => _L10nAssetLoader.supportedLocales
      .map(_localeForLangCode)
      .toList(growable: false);

  bool get isAutoSystem {
    final prefs = OfflineCacheService.getPrefsSync();
    final saved = prefs?.getString('il_lang');
    return saved == null || saved.isEmpty || saved == 'auto';
  }

  String getSystemDetectedLocaleCode() {
    return AppLocaleRegistry.detect(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
  }

  Future<void> init({AssetBundle? bundle}) async {
    final request = ++_localeRequest;
    if (bundle != null) {
      _state.useAssetBundle(bundle);
      _lookup.clearCache();
    }
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final langCode = _normalizeLangCode(prefs.getString('il_lang'));
    if (request != _localeRequest) return;
    await _ensureAssetTranslationsLoaded(langCode);
    if (request != _localeRequest) return;
    _lookup.clearCache();
    _state.currentLocale = _localeForLangCode(langCode);
    notifyListeners();
  }

  Future<void> setLocale(String langCode) async {
    final request = ++_localeRequest;
    final normalizedLangCode = _normalizeLangCode(langCode);
    await _ensureAssetTranslationsLoaded(normalizedLangCode);
    if (request != _localeRequest) return;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    if (request != _localeRequest) return;
    // Tuần tự hoá lưu lựa chọn, tránh tác vụ chậm ghi đè ngôn ngữ mới hơn.
    final previousWrite = _preferenceWrite;
    final write = () async {
      if (previousWrite != null) {
        try {
          await previousWrite;
        } catch (_) {
          // Lần lưu trước lỗi không được khóa lựa chọn mới.
        }
      }
      if (request != _localeRequest) return;
      await prefs.setString('il_lang', langCode);
    }();
    _preferenceWrite = write;
    try {
      await write;
    } finally {
      if (identical(_preferenceWrite, write)) _preferenceWrite = null;
    }
    if (request != _localeRequest) return;
    // Chỉ đổi giao diện khi gói dịch đã sẵn sàng (hoặc có fallback khi lỗi).
    _state.currentLocale = _localeForLangCode(normalizedLangCode);
    _lookup.clearCache();
    notifyListeners();
  }

  String translate(String key) {
    return _lookup.translate(
      key,
      locale: _state.currentLocale,
      assetMaps: _state.assetMaps,
      assetViValueToKey: _state.assetViValueToKey,
      staticViValueToKey: _viValueToKey,
    );
  }

  String format(String key, [Map<String, Object?> params = const {}]) {
    return _formatHelper.format(translate(key), params);
  }

  String translateActiveDays(int count) =>
      format('global_active_days', {'count': count});

  String translateMemoriesPerMonth(int count) =>
      format('global_memories_month', {'count': count});

  String translatePositivity(int percent) =>
      format('global_positivity', {'percent': percent});

  String translateThisMonth(int count) =>
      format('global_this_month', {'count': count});

  String translatePartnerMessage(String name) =>
      format('global_partner_message', {'name': name});

  String translateRecordsCount(int count) =>
      format('global_records', {'count': count});

  String _normalizeLangCode(String? value) =>
      AppLocaleRegistry.canonicalCode(value) ?? getSystemDetectedLocaleCode();

  Locale _localeForLangCode(String langCode) {
    return _L10nAssetLoader.supportedLocaleMap[langCode] ??
        const Locale('en', 'US');
  }

  Future<void> _ensureAssetTranslationsLoaded(String localeCode) async {
    await const _L10nAssetLoader().ensureLoaded(_state, localeCode);
  }
}

class L10nScope extends InheritedNotifier<L10nService> {
  const L10nScope({
    super.key,
    required L10nService notifier,
    required super.child,
  }) : super(notifier: notifier);

  static L10nService of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<L10nScope>()?.notifier ??
        L10nService();
  }
}

extension TransContext on BuildContext {
  String tr(String key) => L10nScope.of(this).translate(key);
}
