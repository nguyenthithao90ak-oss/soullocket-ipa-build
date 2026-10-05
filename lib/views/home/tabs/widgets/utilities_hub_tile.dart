import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';
import 'package:soullocket_app/widgets/lossless_sticker_assets.dart';

/// Một số tiện ích dùng chung ảnh sticker với tiện ích khác.
const Map<String, String> _kHubStickerAliases = <String, String>{
  'local_album': 'photo',
  'soul_events': 'history',
  'surprise_maker': 'love_card',
  'sleep_tracker': 'age_zodiac',
  'couple_connect': 'wish',
};

String utilityHubStickerAsset(String utilityId) {
  final id = _kHubStickerAliases[utilityId] ?? utilityId;
  return LosslessStickerAssets.resolve(
    'assets/images/utility_stickers/$id.png',
  );
}

/// Ảnh sticker 3D theo ID tiện ích hoặc tên ảnh trong `utility_stickers`.
class UtilityStickerImage extends StatelessWidget {
  const UtilityStickerImage({
    super.key,
    required this.stickerId,
    required this.size,
    required this.fallbackIcon,
    this.fallbackColor = SLColors.primary,
  });

  final String stickerId;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final cacheSize = math.max(
      1,
      (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    return SizedBox.square(
      dimension: size,
      child: Image(
        image: ResizeImage.resizeIfNeeded(
          cacheSize,
          cacheSize,
          AssetImage(utilityHubStickerAsset(stickerId)),
        ),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => Center(
          child: Icon(fallbackIcon, size: size * 0.6, color: fallbackColor),
        ),
      ),
    );
  }
}

/// Sticker 3D của tiện ích, không khung nền.
class UtilityHubSticker extends StatelessWidget {
  const UtilityHubSticker({super.key, required this.app, required this.size});

  final UtilityApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    return UtilityStickerImage(
      stickerId: app.id,
      size: size,
      fallbackIcon: app.icon,
      fallbackColor: app.colors.isNotEmpty
          ? app.colors.first
          : SLColors.primary,
    );
  }
}

class UtilitiesPinBadge extends StatelessWidget {
  const UtilitiesPinBadge({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SLColors.primaryActive,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        Icons.push_pin_rounded,
        size: size * 0.55,
        color: Colors.white,
      ),
    );
  }
}

/// Sticker kèm dấu ghim ở góc khi tiện ích đã được ghim lên trang Nhà.
class UtilityHubStickerWithBadge extends StatelessWidget {
  const UtilityHubStickerWithBadge({
    super.key,
    required this.app,
    required this.size,
    required this.isPinned,
  });

  final UtilityApp app;
  final double size;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final sticker = UtilityHubSticker(app: app, size: size);
    if (!isPinned) return sticker;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        sticker,
        Positioned(
          top: -2,
          right: -4,
          child: UtilitiesPinBadge(size: size >= 48 ? 20 : 17),
        ),
      ],
    );
  }
}

String utilityHubSemanticLabel(
  BuildContext context,
  UtilityApp app,
  bool isPinned,
) {
  final title = app.localizedTitle;
  return isPinned ? '$title, ${context.tr('home_ghim_4be667')}' : title;
}

/// Ô tiện ích dạng sticker + tên, dùng trong các lưới.
class UtilitiesHubTile extends StatelessWidget {
  const UtilitiesHubTile({
    super.key,
    required this.app,
    required this.stickerSize,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
    this.labelFontSize = 12,
  });

  final UtilityApp app;
  final double stickerSize;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: utilityHubSemanticLabel(context, app, isPinned),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UtilityHubStickerWithBadge(
                app: app,
                size: stickerSize,
                isPinned: isPinned,
              ),
              const SizedBox(height: 6),
              Text(
                app.localizedTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w700,
                  color: SLColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
