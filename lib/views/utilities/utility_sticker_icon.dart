import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_cache_manager.dart';

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

  final String filename = assetPath.substring('assets/images/'.length);
  final String r2Url = '${AppConfig.r2PublicDomain}/stickers/$filename';

  final cacheSize = _utilityStickerCacheSize(
    logicalSize: logicalSize,
    devicePixelRatio: devicePixelRatio,
  );
  return ResizeImage.resizeIfNeeded(
    cacheSize,
    cacheSize,
    CachedNetworkImageProvider(
      r2Url,
      cacheManager: AppCacheManager.instance,
    ),
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

/// Builds the sticker icon for a utility tile.
///
/// [devicePixelRatio] — when provided by the caller (who already has a
/// BuildContext), the image provider is created directly without wrapping
/// in a [Builder] widget. This eliminates one extra widget per tile and
/// avoids redundant MediaQuery lookups.
Widget buildUtilityStickerIcon({
  required String utilityId,
  required IconData fallbackIcon,
  required Color fallbackColor,
  double fallbackSize = 24,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  BoxFit fit = BoxFit.contain,
  double? devicePixelRatio, // FIX #3: caller passes DPR → no Builder needed.
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

  // Fast path: DPR known at call site → build image directly, no extra widget.
  if (devicePixelRatio != null) {
    final provider = utilityStickerImageProviderForId(
      utilityId,
      devicePixelRatio: devicePixelRatio,
    );
    if (provider == null) return fallback;
    return SizedBox.expand(
      child: Padding(
        padding: padding,
        child: Image(
          image: provider,
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return fallback;
          },
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  // Fallback path: no DPR provided → use Builder (for other callers).
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
          child: Image(
            image: provider,
            fit: fit,
            alignment: Alignment.center,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              return fallback;
            },
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      );
    },
  );
}
