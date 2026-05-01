import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final _L10nLocaleState _state = _L10nLocaleState();
  final _L10nTranslationLookup _lookup = const _L10nTranslationLookup();
  final _L10nFormatHelper _formatHelper = const _L10nFormatHelper();

  Locale get locale => _state.currentLocale;

  Future<void> init({AssetBundle? bundle}) async {
    if (bundle != null) {
      _state.assetBundle = bundle;
    }
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('il_lang') ?? 'vi';
    await _ensureAssetTranslationsLoaded();
    _state.currentLocale = Locale(langCode);
    notifyListeners();
  }

  Future<void> setLocale(String langCode) async {
    _state.currentLocale = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('il_lang', langCode);
    await _ensureAssetTranslationsLoaded();
    notifyListeners();
  }

  String translate(String key) {
    return _lookup.translate(
      key,
      locale: _state.currentLocale,
      assetVi: _state.assetVi,
      assetEn: _state.assetEn,
      assetViValueToKey: _state.assetViValueToKey,
      staticViValueToKey: _viValueToKey,
    );
  }

  String format(String key, [Map<String, Object?> params = const {}]) {
    return _formatHelper.format(translate(key), params);
  }

  Future<void> _ensureAssetTranslationsLoaded() async {
    await const _L10nAssetLoader().ensureLoaded(_state);
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
