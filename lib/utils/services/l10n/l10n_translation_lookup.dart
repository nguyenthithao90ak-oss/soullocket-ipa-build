part of '../l10n_service.dart';

class _L10nTranslationLookup {
  const _L10nTranslationLookup();

  String translate(
    String key, {
    required Locale locale,
    required Map<String, String> assetVi,
    required Map<String, String> assetEn,
    required Map<String, String> assetViValueToKey,
    required Map<String, String> staticViValueToKey,
  }) {
    final rawKey = key.trim();
    if (rawKey.isEmpty) return key;

    final isVietnamese = locale.languageCode == 'vi';
    final map = isVietnamese ? _resolvedVi(assetVi) : _resolvedEn(assetEn);
    final webParity = isVietnamese
        ? _L10nStaticData._viWebParity
        : _L10nStaticData._enWebParity;
    final canonicalKey =
        assetViValueToKey[rawKey] ?? staticViValueToKey[rawKey] ?? rawKey;

    return webParity[canonicalKey] ??
        map[canonicalKey] ??
        webParity[rawKey] ??
        map[rawKey] ??
        rawKey;
  }

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
