import 'package:flutter/widgets.dart';

/// Nguồn duy nhất cho ngôn ngữ hiển thị, asset và lựa chọn trong Settings.
abstract final class AppLocaleRegistry {
  static const options = [
    (code: 'vi', badge: 'VN', title: 'Tiếng Việt'),
    (code: 'en', badge: 'US', title: 'English'),
    (code: 'zh', badge: 'CN', title: '中文 (简体)'),
    (code: 'zh-TW', badge: 'TW', title: '中文 (繁體)'),
    (code: 'ja', badge: 'JP', title: '日本語'),
    (code: 'ko', badge: 'KR', title: '한국어'),
    (code: 'th', badge: 'TH', title: 'ภาษาไทย'),
    (code: 'id', badge: 'ID', title: 'Bahasa Indonesia'),
    (code: 'es', badge: 'ES', title: 'Español'),
    (code: 'pt', badge: 'PT', title: 'Português'),
    (code: 'fr', badge: 'FR', title: 'Français'),
    (code: 'de', badge: 'DE', title: 'Deutsch'),
    (code: 'it', badge: 'IT', title: 'Italiano'),
    (code: 'ru', badge: 'RU', title: 'Русский'),
    (code: 'hi', badge: 'IN', title: 'हिन्दी'),
    (code: 'tr', badge: 'TR', title: 'Türkçe'),
    (code: 'ar', badge: 'SA', title: 'العربية'),
    (code: 'ms', badge: 'MY', title: 'Bahasa Melayu'),
    (code: 'tl', badge: 'PH', title: 'Tagalog'),
    (code: 'nl', badge: 'NL', title: 'Nederlands'),
    (code: 'pl', badge: 'PL', title: 'Polski'),
  ];

  static const localeMap = <String, Locale>{
    'vi': Locale('vi', 'VN'),
    'en': Locale('en', 'US'),
    'zh': Locale('zh', 'CN'),
    'zh-TW': Locale('zh', 'TW'),
    'ja': Locale('ja', 'JP'),
    'ko': Locale('ko', 'KR'),
    'th': Locale('th', 'TH'),
    'id': Locale('id', 'ID'),
    'es': Locale('es', 'ES'),
    'pt': Locale('pt', 'PT'),
    'fr': Locale('fr', 'FR'),
    'de': Locale('de', 'DE'),
    'it': Locale('it', 'IT'),
    'ru': Locale('ru', 'RU'),
    'hi': Locale('hi', 'IN'),
    'tr': Locale('tr', 'TR'),
    'ar': Locale('ar', 'SA'),
    'ms': Locale('ms', 'MY'),
    'tl': Locale('tl', 'PH'),
    'nl': Locale('nl', 'NL'),
    'pl': Locale('pl', 'PL'),
  };

  static List<String> get codes => localeMap.keys.toList(growable: false);

  static String? canonicalCode(String? raw) {
    final value = raw?.trim().replaceAll('_', '-').toLowerCase();
    if (value == null || value.isEmpty || value == 'auto') return null;
    final parts = value.split('-');
    if (parts.first == 'zh') {
      if (parts.contains('hans')) return 'zh';
      if (parts.contains('hant')) return 'zh-TW';
      return parts.contains('hant') ||
              parts.contains('tw') ||
              parts.contains('hk') ||
              parts.contains('mo')
          ? 'zh-TW'
          : 'zh';
    }
    final language = parts.first == 'fil' ? 'tl' : parts.first;
    return localeMap.containsKey(language) ? language : null;
  }

  /// Biến thể định dạng có trong Flutter/CLDR, tách khỏi mã asset bản dịch.
  static Locale formattingLocale(Locale language, String marketCode) {
    const regions = <String, Set<String>>{
      'en': {'US', 'GB', 'CA', 'AU', 'IN', 'SG'},
      'fr': {'FR', 'CA'},
      'es': {'ES', 'MX', 'AR', 'CO', 'US'},
      'pt': {'PT', 'BR'},
      'ar': {'SA', 'AE', 'EG'},
    };
    final region = marketCode.toUpperCase();
    return regions[language.languageCode]?.contains(region) == true
        ? Locale(language.languageCode, region)
        : language;
  }

  static String detect(Iterable<Locale> preferred) {
    for (final locale in preferred) {
      final code = canonicalCode(locale.toLanguageTag());
      if (code != null) return code;
    }
    return 'en';
  }
}
