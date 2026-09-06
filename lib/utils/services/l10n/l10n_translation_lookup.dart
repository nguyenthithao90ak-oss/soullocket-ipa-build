part of '../l10n_service.dart';

class _L10nTranslationLookup {
  _L10nTranslationLookup();

  /// LRU cache: key="lang|rawKey" → translation. Tránh lookup lặp.
  static const int _cacheMax = 1024;
  final LinkedHashMap<String, String> _resultCache =
      LinkedHashMap<String, String>();

  /// Bỏ các giá trị fallback đã tra trước khi file dịch từ assets tải xong.
  /// Nếu giữ cache cũ, một key mới có thể bị hiển thị nguyên tên key cho đến
  /// khi ứng dụng được khởi động lại.
  void clearCache() => _resultCache.clear();

  String _cacheKey(String lang, String rawKey, bool isSingle) =>
      '$lang|$rawKey|$isSingle';

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

    final prefs = OfflineCacheService.getPrefsSync();
    final isSingle = prefs?.getString('il_rel_mode') == 'single';

    // ⚡ Cache hit
    final ck = _cacheKey(lang, rawKey, isSingle);
    final cached = _resultCache[ck];
    if (cached != null) return cached;

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

    String? result;

    if (isSingle) {
      final singleCanonicalKey = '${canonicalKey}_single';
      final singleRawKey = '${rawKey}_single';

      if (webParity.containsKey(singleCanonicalKey)) {
        result = webParity[singleCanonicalKey];
      }
      if (result == null && map.containsKey(singleCanonicalKey)) {
        result = map[singleCanonicalKey];
      }
      if (result == null && webParity.containsKey(singleRawKey)) {
        result = webParity[singleRawKey];
      }
      if (result == null && map.containsKey(singleRawKey)) {
        result = map[singleRawKey];
      }

      if (result == null) {
        final commonMap = _commonTranslations[lang] ?? const {};
        if (commonMap.containsKey(singleCanonicalKey)) {
          result = commonMap[singleCanonicalKey];
        }
        if (result == null && commonMap.containsKey(singleRawKey)) {
          result = commonMap[singleRawKey];
        }
      }

      if (result == null) {
        final enMap = _resolvedEn(assetMaps['en'] ?? const {});
        if (enMap.containsKey(singleCanonicalKey)) {
          result = enMap[singleCanonicalKey];
        }
        if (result == null && enMap.containsKey(singleRawKey)) {
          result = enMap[singleRawKey];
        }
      }
    }

    if (result == null && webParity.containsKey(canonicalKey)) {
      result = webParity[canonicalKey];
    }
    if (result == null && map.containsKey(canonicalKey)) {
      result = map[canonicalKey];
    }
    if (result == null && webParity.containsKey(rawKey)) {
      result = webParity[rawKey];
    }
    if (result == null && map.containsKey(rawKey)) {
      result = map[rawKey];
    }

    if (result == null) {
      final commonMap = _commonTranslations[lang] ?? const {};
      if (commonMap.containsKey(canonicalKey)) {
        result = commonMap[canonicalKey];
      }
      if (result == null && commonMap.containsKey(rawKey)) {
        result = commonMap[rawKey];
      }
    }

    if (result == null) {
      final enMap = _resolvedEn(assetMaps['en'] ?? const {});
      if (enMap.containsKey(canonicalKey)) {
        result = enMap[canonicalKey];
      }
      if (result == null && enMap.containsKey(rawKey)) {
        result = enMap[rawKey];
      }
    }

    result ??= rawKey;

    // ⚡ Lưu cache, LRU evict nếu quá ngưỡng
    if (_resultCache.length >= _cacheMax) {
      _resultCache.remove(_resultCache.keys.first);
    }
    _resultCache[ck] = result;

    return result;
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
