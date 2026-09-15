part of '../l10n_service.dart';

class _L10nLocaleState {
  Locale currentLocale = const Locale('en');
  AssetBundle assetBundle = rootBundle;
  Map<String, Map<String, String>> assetMaps = {};
  Map<String, String> assetViValueToKey = const {};
  final Map<String, Future<void>> assetLoads = {};
  int assetGeneration = 0;

  void useAssetBundle(AssetBundle bundle) {
    if (identical(assetBundle, bundle)) return;
    assetBundle = bundle;
    assetGeneration++;
    assetMaps.clear();
    assetLoads.clear();
    assetViValueToKey = const {};
  }
}
