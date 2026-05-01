import 'package:flutter/material.dart';

const double _kUtilityStickerLogicalSize = 64;
const Set<String> _kUtilityStickerIds = <String>{
  'age_zodiac',
  'bucket',
  'calculator',
  'calendar',
  'capsule',
  'cinema',
  'collage',
  'creative_diary',
  'diary_export',
  'drawing',
  'finance',
  'friendly_chat',
  'gift',
  'giftcode',
  'habit',
  'health',
  'history',
  'love_card',
  'note',
  'photo',
  'store',
  'surprise',
  'tarot',
  'vault',
  'voice',
  'wheel',
  'wish',
};

String? utilityStickerAssetForId(String utilityId) {
  final normalizedId = utilityId.trim().toLowerCase();
  if (!_kUtilityStickerIds.contains(normalizedId)) {
    return null;
  }
  return 'assets/images/utility_stickers/$normalizedId.png';
}

bool hasUtilityStickerAsset(String utilityId) {
  return utilityStickerAssetForId(utilityId) != null;
}

int _utilityStickerCacheSize({
  required double logicalSize,
  required double devicePixelRatio,
}) {
  final cacheSize = (logicalSize * devicePixelRatio).round();
  return cacheSize > 0 ? cacheSize : 1;
}

ImageProvider<Object>? utilityStickerImageProviderForId(
  String utilityId, {
  double logicalSize = _kUtilityStickerLogicalSize,
  double devicePixelRatio = 1,
}) {
  final assetPath = utilityStickerAssetForId(utilityId);
  if (assetPath == null) {
    return null;
  }

  final cacheSize = _utilityStickerCacheSize(
    logicalSize: logicalSize,
    devicePixelRatio: devicePixelRatio,
  );
  return ResizeImage.resizeIfNeeded(
    cacheSize,
    cacheSize,
    AssetImage(assetPath),
  );
}

List<ImageProvider<Object>> utilityStickerImageProviders({
  Iterable<String>? utilityIds,
  double logicalSize = _kUtilityStickerLogicalSize,
  double devicePixelRatio = 1,
}) {
  final sourceIds = utilityIds ?? _kUtilityStickerIds;
  return sourceIds
      .map(
        (utilityId) => utilityStickerImageProviderForId(
          utilityId,
          logicalSize: logicalSize,
          devicePixelRatio: devicePixelRatio,
        ),
      )
      .whereType<ImageProvider<Object>>()
      .toList(growable: false);
}

Future<void> precacheUtilityStickerList(
  BuildContext context, {
  Iterable<String>? utilityIds,
  double logicalSize = _kUtilityStickerLogicalSize,
}) async {
  final mediaQuery = MediaQuery.maybeOf(context);
  final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1;
  final providers = utilityStickerImageProviders(
    utilityIds: utilityIds,
    logicalSize: logicalSize,
    devicePixelRatio: devicePixelRatio,
  );
  if (providers.isEmpty) return;

  await Future.wait<void>(
    providers.map(
      (provider) async {
        try {
          await precacheImage(provider, context);
        } catch (_) {}
      },
    ),
    eagerError: false,
  );
}

Widget buildUtilityStickerIcon({
  required String utilityId,
  required IconData fallbackIcon,
  required Color fallbackColor,
  double fallbackSize = 24,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  BoxFit fit = BoxFit.contain,
}) {
  final fallback = Center(
    child: Icon(
      fallbackIcon,
      size: fallbackSize,
      color: fallbackColor,
    ),
  );

  final assetPath = utilityStickerAssetForId(utilityId);
  if (assetPath == null) {
    return fallback;
  }

  return Builder(
    builder: (context) {
      final provider = utilityStickerImageProviderForId(
        utilityId,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      if (provider == null) {
        return fallback;
      }

      return SizedBox.expand(
        child: Padding(
          padding: padding,
          child: Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              Image(
                image: provider,
                fit: fit,
                alignment: Alignment.center,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return const SizedBox.shrink();
                },
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
