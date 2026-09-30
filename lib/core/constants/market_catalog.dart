/// Cấu hình trải nghiệm; không quyết định quyền mua hàng hay nơi phát hành.
class MarketProfile {
  const MarketProfile(this.code, this.locales, this.stage, this.shareChannels);
  final String code;
  final List<String> locales;
  final String stage;
  final List<String> shareChannels;
  String get nameKey => 'market_$code';
}

abstract final class MarketCatalog {
  static const profiles = <MarketProfile>[
    MarketProfile('ALL', ['en'], 'global', ['System']),
    MarketProfile('VN', ['vi'], 'A', ['Zalo', 'Messenger']),
    MarketProfile('TH', ['th'], 'A', ['LINE']),
    MarketProfile('ID', ['id'], 'A', ['WhatsApp']),
    MarketProfile('PH', ['tl', 'en'], 'A', ['Messenger', 'Facebook']),
    MarketProfile('MY', ['ms', 'en', 'zh'], 'A', ['WhatsApp']),
    MarketProfile('JP', ['ja'], 'A', ['LINE']),
    MarketProfile('KR', ['ko'], 'A', ['KakaoTalk']),
    MarketProfile('TW', ['zh-TW'], 'A', ['LINE']),
    MarketProfile('US', ['en', 'es'], 'A', ['SMS']),
    MarketProfile('BR', ['pt'], 'A', ['WhatsApp']),
    MarketProfile('IN', ['hi', 'en'], 'A', ['WhatsApp']),
    MarketProfile('GB', ['en'], 'B', ['WhatsApp', 'SMS']),
    MarketProfile('CA', ['en', 'fr'], 'B', ['SMS', 'WhatsApp']),
    MarketProfile('AU', ['en'], 'B', ['SMS', 'WhatsApp']),
    MarketProfile('SG', ['en', 'zh', 'ms'], 'B', ['WhatsApp']),
    MarketProfile('MX', ['es'], 'B', ['WhatsApp']),
    MarketProfile('AR', ['es'], 'B', ['WhatsApp']),
    MarketProfile('CO', ['es'], 'B', ['WhatsApp']),
    MarketProfile('ES', ['es'], 'B', ['WhatsApp']),
    MarketProfile('FR', ['fr'], 'B', ['WhatsApp']),
    MarketProfile('DE', ['de'], 'B', ['WhatsApp']),
    MarketProfile('IT', ['it'], 'B', ['WhatsApp']),
    MarketProfile('NL', ['nl'], 'C', ['WhatsApp']),
    MarketProfile('PL', ['pl'], 'C', ['Messenger', 'WhatsApp']),
    MarketProfile('TR', ['tr'], 'C', ['WhatsApp']),
    MarketProfile('SA', ['ar', 'en'], 'C', ['WhatsApp']),
    MarketProfile('AE', ['ar', 'en'], 'C', ['WhatsApp']),
    MarketProfile('EG', ['ar', 'en'], 'C', ['WhatsApp', 'Messenger']),
    MarketProfile('CN', ['zh'], 'review', ['System']),
    MarketProfile('RU', ['ru'], 'review', ['Telegram']),
    MarketProfile('PT', ['pt'], 'maintain', ['WhatsApp']),
    MarketProfile('HK', ['zh-TW', 'en'], 'maintain', ['System']),
    MarketProfile('MO', ['zh-TW'], 'maintain', ['System']),
  ];
  static const holidayPackCodes = [
    'ALL',
    'VN',
    'KR',
    'JP',
    'CN',
    'TW',
    'TH',
    'ES',
    'BR',
    'RU',
  ];

  static MarketProfile? find(String? code) {
    final normalized = code?.trim().toUpperCase();
    for (final profile in profiles) {
      if (profile.code == normalized) return profile;
    }
    return null;
  }

  static List<String> defaultHolidayPacks(String code) => [
    'ALL',
    if (code == 'HK' || code == 'MO')
      'CN'
    else if (code != 'ALL' && holidayPackCodes.contains(code))
      code,
  ];
}
