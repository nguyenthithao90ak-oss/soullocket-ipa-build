import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';

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
  final _L10nTranslationLookup _lookup = _L10nTranslationLookup();
  final _L10nFormatHelper _formatHelper = const _L10nFormatHelper();

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

  Future<void> init({AssetBundle? bundle}) async {
    if (bundle != null) {
      _state.assetBundle = bundle;
    }
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final langCode = _normalizeLangCode(prefs.getString('il_lang'));
    await _ensureAssetTranslationsLoaded();
    _state.currentLocale = _localeForLangCode(langCode);
    notifyListeners();
  }

  Future<void> setLocale(String langCode) async {
    final normalizedLangCode = _normalizeLangCode(langCode);
    _state.currentLocale = _localeForLangCode(normalizedLangCode);
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString('il_lang', normalizedLangCode);
    await _ensureAssetTranslationsLoaded();
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

  String translateActiveDays(int count) {
    final lang = localeCode;
    switch (lang) {
      case 'vi':
        return '$count ngày tích cực';
      case 'en':
        return '$count active days';
      case 'ko':
        return '$count일 연속 활동';
      case 'zh':
        return '$count 天活跃';
      case 'zh-TW':
        return '$count 天活躍';
      case 'ja':
        return '$count日間のアクティブ';
      case 'th':
        return '$count วันที่ใช้งาน';
      case 'id':
        return '$count hari aktif';
      case 'es':
        return '$count días activos';
      case 'pt':
        return '$count dias ativos';
      case 'fr':
        return '$count jours actifs';
      case 'de':
        return '$count active Tage';
      case 'it':
        return '$count giorni attivi';
      case 'ru':
        return '$count активных дней';
      case 'tr':
        return '$count aktif gün';
      case 'ar':
        return '$count أيام نشطة';
      case 'hi':
        return '$count सक्रिय दिन';
      default:
        return '$count active days';
    }
  }

  String translateMemoriesPerMonth(int count) {
    final lang = localeCode;
    switch (lang) {
      case 'vi':
        return '$count kỷ niệm/tháng';
      case 'en':
        return '$count memories/month';
      case 'ko':
        return '월평균 $count개 추억';
      case 'zh':
        return '$count 个回忆/月';
      case 'zh-TW':
        return '$count 個回憶/月';
      case 'ja':
        return '$count個の思い出/月';
      case 'th':
        return '$count ความทรงจำ/เดือน';
      case 'id':
        return '$count memori/bulan';
      case 'es':
        return '$count recuerdos/mes';
      case 'pt':
        return '$count memórias/mês';
      case 'fr':
        return '$count souvenirs/mois';
      case 'de':
        return '$count Erinnerungen/Monat';
      case 'it':
        return '$count ricordi/mese';
      case 'ru':
        return '$count воспом./мес.';
      case 'tr':
        return '$count anı/ay';
      case 'ar':
        return '$count ذكريات/شهر';
      case 'hi':
        return '$count यादें/महीना';
      default:
        return '$count memories/month';
    }
  }

  String translatePositivity(int percent) {
    final lang = localeCode;
    switch (lang) {
      case 'vi':
        return '$percent% tích cực';
      case 'en':
        return '$percent% positive';
      case 'ko':
        return '$percent% 긍정적';
      case 'zh':
        return '$percent% 积极';
      case 'zh-TW':
        return '$percent% 積極';
      case 'ja':
        return '$percent% ポジティブ';
      case 'th':
        return '$percent% เชิงบวก';
      case 'id':
        return '$percent% positif';
      case 'es':
        return '$percent% positivo';
      case 'pt':
        return '$percent% positivo';
      case 'fr':
        return '$percent% positif';
      case 'de':
        return '$percent% positiv';
      case 'it':
        return '$percent% positivo';
      case 'ru':
        return '$percent% позитива';
      case 'tr':
        return '$percent% pozitif';
      case 'ar':
        return '$percent% إيجابي';
      case 'hi':
        return '$percent% सकारात्मक';
      default:
        return '$percent% positive';
    }
  }

  String translateThisMonth(int count) {
    final lang = localeCode;
    switch (lang) {
      case 'vi':
        return '+$count tháng này';
      case 'en':
        return '+$count this month';
      case 'ko':
        return '이번 달 +$count';
      case 'zh':
        return '本月 +$count';
      case 'zh-TW':
        return '本月 +$count';
      case 'ja':
        return '今月 +$count';
      case 'th':
        return '+$count เดือนนี้';
      case 'id':
        return '+$count bulan ini';
      case 'es':
        return '+$count este mes';
      case 'pt':
        return '+$count este mês';
      case 'fr':
        return '+$count ce mois-ci';
      case 'de':
        return '+$count diesen Monat';
      case 'it':
        return '+$count questo mese';
      case 'ru':
        return '+$count в этом месяце';
      case 'tr':
        return '+$count bu ay';
      case 'ar':
        return '+$count هذا الشهر';
      case 'hi':
        return '+$count इस महीने';
      default:
        return '+$count this month';
    }
  }

  String translatePartnerMessage(String name) {
    final lang = localeCode;
    switch (lang) {
      case 'vi':
        return 'Lời nhắn từ $name';
      case 'en':
        return 'Message from $name';
      case 'ko':
        return '$name님의 메시지';
      case 'zh':
        return '$name的留言';
      case 'zh-TW':
        return '$name的留言';
      case 'ja':
        return '$nameからのメッセージ';
      case 'th':
        return 'ข้อความจาก $name';
      case 'id':
        return 'Pesan dari $name';
      case 'es':
        return 'Mensaje de $name';
      case 'pt':
        return 'Mensagem de $name';
      case 'fr':
        return 'Message de $name';
      case 'de':
        return 'Nachricht von $name';
      case 'it':
        return 'Messaggio da $name';
      case 'ru':
        return 'Сообщение от $name';
      case 'tr':
        return '$name kişisinden mesaj';
      case 'ar':
        return 'رسالة من $name';
      case 'hi':
        return '$name का संदेश';
      default:
        return 'Message from $name';
    }
  }

  String translateRecordsCount(int count) {
    final lang = localeCode;
    switch (lang) {
      case 'vi':
        return '$count bản ghi';
      case 'en':
        return '$count records';
      case 'ko':
        return '$count개 녹음';
      case 'zh':
        return '$count 条记录';
      case 'zh-TW':
        return '$count 條記錄';
      case 'ja':
        return '$count件の録音';
      case 'th':
        return '$count รายการบันทึก';
      case 'id':
        return '$count rekaman';
      case 'es':
        return '$count grabaciones';
      case 'pt':
        return '$count gravações';
      case 'fr':
        return '$count enregistrements';
      case 'de':
        return '$count Aufnahmen';
      case 'it':
        return '$count registrazioni';
      case 'ru':
        return '$count записей';
      case 'tr':
        return '$count kayıt';
      case 'ar':
        return '$count تسجيلات';
      case 'hi':
        return '$count रिकॉर्डिंग';
      default:
        return '$count records';
    }
  }

  String _normalizeLangCode(String? value) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      for (final locale in _L10nAssetLoader.supportedLocales) {
        if (locale.toLowerCase() == normalized.toLowerCase()) {
          return locale;
        }
      }
    }

    try {
      final systemLocale =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      for (final locale in _L10nAssetLoader.supportedLocales) {
        if (locale.toLowerCase() == systemLocale.toLowerCase()) {
          return locale;
        }
      }
    } catch (_) {}

    return 'en';
  }

  Locale _localeForLangCode(String langCode) {
    return _L10nAssetLoader.supportedLocaleMap[langCode] ??
        const Locale('en', 'US');
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
