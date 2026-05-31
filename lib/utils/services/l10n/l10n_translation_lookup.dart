part of '../l10n_service.dart';

class _L10nTranslationLookup {
  const _L10nTranslationLookup();

  String translate(
    String key, {
    required Locale locale,
    required Map<String, Map<String, String>> assetMaps,
    required Map<String, String> assetViValueToKey,
    required Map<String, String> staticViValueToKey,
  }) {
    final rawKey = key.trim();
    if (rawKey.isEmpty) return key;

    final lang = _L10nAssetLoader.supportedLocaleMap.entries
        .firstWhere(
          (entry) => entry.value == locale,
          orElse: () => MapEntry(locale.languageCode, locale),
        )
        .key;
    final isVietnamese = lang == 'vi';
    
    Map<String, String> map;
    Map<String, String>? webParity;
    
    if (isVietnamese) {
      map = _resolvedVi(assetMaps['vi'] ?? const {});
      webParity = _L10nStaticData._viWebParity;
    } else if (lang == 'en') {
      map = _resolvedEn(assetMaps['en'] ?? const {});
      webParity = _L10nStaticData._enWebParity;
    } else {
      map = assetMaps[lang] ?? const {};
      webParity = const {};
    }

    final canonicalKey =
        assetViValueToKey[rawKey] ?? staticViValueToKey[rawKey] ?? rawKey;

    if (webParity.containsKey(canonicalKey)) return webParity[canonicalKey]!;
    if (map.containsKey(canonicalKey)) return map[canonicalKey]!;
    if (webParity.containsKey(rawKey)) return webParity[rawKey]!;
    if (map.containsKey(rawKey)) return map[rawKey]!;

    final commonMap = _commonTranslations[lang] ?? const {};
    if (commonMap.containsKey(canonicalKey)) return commonMap[canonicalKey]!;
    if (commonMap.containsKey(rawKey)) return commonMap[rawKey]!;
    
    // Fallback to English if key not found
    final enMap = _resolvedEn(assetMaps['en'] ?? const {});
    if (enMap.containsKey(canonicalKey)) return enMap[canonicalKey]!;
    if (enMap.containsKey(rawKey)) return enMap[rawKey]!;

    return rawKey;
  }

  static const Map<String, Map<String, String>> _commonTranslations = {
    'zh': {
      'login': '进入小屋',
      'signup': '创建新小屋',
      'password': '小屋密码:',
      'Email đăng nhập:': '登录邮箱:',
      'QUAN TRỌNG': '重要',
      'Tối thiểu 6 ký tự và có số': '至少 6 个字符且包含 1 个数字',
      'Câu hỏi bảo mật (Tuỳ chọn)': '安全问题(可选)',
      'Câu hỏi bảo mật (Tuỳ chọn) (tap)': '安全问题(可选)(点击)',
      'Tôi xác nhận mình đủ 13 tuổi và đồng ý với ': '我确认已满 13 岁并同意',
      'Điều khoản': '条款',
      'Chính sách bảo mật': '隐私政策',
      'HOẶC ĐĂNG KÝ NHANH': '或快速注册',
      'Hướng dẫn': '指南',
      'Liên Hệ': '联系',
    },
    'ja': {
      'login': 'ホームに入る',
      'signup': '新しいホームを作成',
      'password': 'ホームパスワード:',
      'Email đăng nhập:': 'ログインメール:',
      'QUAN TRỌNG': '重要',
      'Tối thiểu 6 ký tự và có số': '6文字以上、数字を1つ含む',
      'Câu hỏi bảo mật (Tuỳ chọn)': '秘密の質問(任意)',
      'Câu hỏi bảo mật (Tuỳ chọn) (tap)': '秘密の質問(任意)(タップ)',
      'Tôi xác nhận mình đủ 13 tuổi và đồng ý với ': '13歳以上であることを確認し、同意します:',
      'Điều khoản': '利用規約',
      'Chính sách bảo mật': 'プライバシーポリシー',
      'HOẶC ĐĂNG KÝ NHANH': 'またはクイック登録',
      'Hướng dẫn': 'ガイド',
      'Liên Hệ': '連絡',
    },
  };

  Map<String, String> _resolvedVi(Map<String, String> assetVi) {
    return assetVi.isEmpty
        ? _L10nStaticData._vi
        : {..._L10nStaticData._vi, ...assetVi};
  }

  Map<String, String> _resolvedEn(Map<String, String> assetEn) {
    return assetEn.isEmpty
        ? _L10nStaticData._en
        : {..._L10nStaticData._en, ...assetEn};
  }
}
