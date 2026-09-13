import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../widgets/soullocket_animated_sticker.dart';
import '../../../widgets/living_sticker.dart';
import '../../../widgets/living_sticker_scene.dart';
import '../../ui_prefs.dart';

/// Chỉ truyền chế độ tiết kiệm hiệu ứng; không lắc cả ảnh sticker.
class HomeStickerMotion extends StatelessWidget {
  final Widget child;
  final SoulLocketStickerMotion motion;
  final String motionSeed;

  const HomeStickerMotion({
    super.key,
    required this.child,
    this.motion = SoulLocketStickerMotion.gentleFloat,
    this.motionSeed = '',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      child: child,
      builder: (context, prefs, visual) {
        final effects = UiPrefs.resolveEffectProfile(
          state: prefs,
          isWeb: kIsWeb,
        );
        return StickerAnimationScope(
          enabled:
              effects.animationEnabled &&
              StickerAnimationScope.enabledOf(context),
          child: visual!,
        );
      },
    );
  }
}

class HomeStickerAsset extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final SoulLocketStickerMotion motion;
  final ImageErrorWidgetBuilder? errorBuilder;

  const HomeStickerAsset(
    this.assetPath, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.motion = SoulLocketStickerMotion.gentleFloat,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final scene = LivingStickerCatalog.asset(assetPath);
    return HomeStickerMotion(
      motion: motion,
      motionSeed: assetPath,
      child: scene != null
          ? LivingSticker(scene: scene, width: width, height: height)
          : Image.asset(
              assetPath,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: errorBuilder,
            ),
    );
  }
}
