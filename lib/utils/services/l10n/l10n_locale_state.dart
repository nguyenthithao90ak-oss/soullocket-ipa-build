part of '../l10n_service.dart';

class _L10nLocaleState {
  Locale currentLocale = const Locale('en');
  AssetBundle assetBundle = rootBundle;
  Map<String, Map<String, String>> assetMaps = {};
  Map<String, String> assetViValueToKey = const {};
  bool assetsLoaded = false;
  bool loadingAssets = false;
}
