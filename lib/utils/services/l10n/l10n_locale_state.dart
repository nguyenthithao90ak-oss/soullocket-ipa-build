part of '../l10n_service.dart';

class _L10nLocaleState {
  Locale currentLocale = const Locale('vi');
  AssetBundle assetBundle = rootBundle;
  Map<String, String> assetVi = const {};
  Map<String, String> assetEn = const {};
  Map<String, String> assetViValueToKey = const {};
  bool assetsLoaded = false;
  bool loadingAssets = false;
}
