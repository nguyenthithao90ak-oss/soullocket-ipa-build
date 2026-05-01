part of '../l10n_service.dart';

class _L10nAssetLoader {
  const _L10nAssetLoader();

  static const String _viAssetPath = 'assets/i18n/vi.json';
  static const String _enAssetPath = 'assets/i18n/en.json';

  Future<void> ensureLoaded(_L10nLocaleState state) async {
    if (state.assetsLoaded || state.loadingAssets) return;
    state.loadingAssets = true;
    try {
      final results = await Future.wait([
        _loadAssetMap(state.assetBundle, _viAssetPath),
        _loadAssetMap(state.assetBundle, _enAssetPath),
      ]);
      state.assetVi = results[0];
      state.assetEn = results[1];
      state.assetViValueToKey = _L10nValueToKeyHelper.buildFromSources([
        state.assetVi,
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
