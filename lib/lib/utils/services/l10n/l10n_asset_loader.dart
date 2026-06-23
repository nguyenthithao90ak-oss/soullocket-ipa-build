part of '../l10n_service.dart';

class _L10nAssetLoader {
  const _L10nAssetLoader();

  static const List<String> supportedLocales = [
    'vi', 'en', 'zh', 'zh-TW', 'ja', 'ko', 'th', 'id',
    'es', 'pt', 'fr', 'de', 'it', 'ru', 'hi', 'tr', 'ar'
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

  Future<void> ensureLoaded(_L10nLocaleState state) async {
    if (state.assetsLoaded || state.loadingAssets) return;
    state.loadingAssets = true;
    try {
      final futures = supportedLocales.map(
        (loc) => _loadAssetMap(state.assetBundle, 'assets/i18n/$loc.json'),
      );
      final results = await Future.wait(futures);

      for (int i = 0; i < supportedLocales.length; i++) {
        state.assetMaps[supportedLocales[i]] = results[i];
      }

      state.assetViValueToKey = _L10nValueToKeyHelper.buildFromSources([
        state.assetMaps['vi'] ?? const {},
      ]);
      state.assetsLoaded = true;
    } finally {
      state.loadingAssets = false;
    }
  }

  Future<Map<String, String>> _loadAssetMap(
    AssetBundle bundle,
    String path,
  ) async {
    try {
      final raw = await bundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value?.toString() ?? '',
        ),
      );
    } catch (_) {
      return const {};
    }
  }
}
