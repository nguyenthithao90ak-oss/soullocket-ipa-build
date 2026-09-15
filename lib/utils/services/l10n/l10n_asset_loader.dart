part of '../l10n_service.dart';

class _L10nAssetLoader {
  const _L10nAssetLoader();

  static const List<String> supportedLocales = [
    'vi',
    'en',
    'zh',
    'zh-TW',
    'ja',
    'ko',
    'th',
    'id',
    'es',
    'pt',
    'fr',
    'de',
    'it',
    'ru',
    'hi',
    'tr',
    'ar',
  ];

  static const Map<String, Locale> supportedLocaleMap = {
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
  };

  Future<void> ensureLoaded(_L10nLocaleState state, String localeCode) async {
    // Tiếng Việt dùng cho tra ngược câu cũ; tiếng Anh là fallback chung.
    // Các gói còn lại vẫn có sẵn offline, chỉ giải mã khi người dùng chọn.
    final requiredLocales = {'vi', 'en', localeCode};
    await Future.wait(
      requiredLocales.map((code) => _ensureLocale(state, code)),
    );
  }

  Future<void> _ensureLocale(_L10nLocaleState state, String code) async {
    if (state.assetMaps.containsKey(code)) return;
    final existing = state.assetLoads[code];
    if (existing != null) return existing;

    final bundle = state.assetBundle;
    final generation = state.assetGeneration;
    final task = () async {
      final map = await _loadAssetMap(bundle, 'assets/i18n/$code.json');
      // Không nhận kết quả từ bundle cũ sau khi khởi tạo lại.
      if (map == null || generation != state.assetGeneration) return;
      state.assetMaps[code] = map;
      if (code == 'vi') {
        state.assetViValueToKey = _L10nValueToKeyHelper.buildFromSources([map]);
      }
    }();
    state.assetLoads[code] = task;
    try {
      await task;
    } finally {
      if (identical(state.assetLoads[code], task)) {
        state.assetLoads.remove(code);
      }
    }
  }

  Future<Map<String, String>?> _loadAssetMap(
    AssetBundle bundle,
    String path,
  ) async {
    try {
      final raw = await bundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Invalid locale asset');
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } catch (_) {
      // Không ghi nhớ lần tải lỗi; lần chọn/init tiếp theo có thể thử lại.
      bundle.evict(path);
      return null;
    }
  }
}
