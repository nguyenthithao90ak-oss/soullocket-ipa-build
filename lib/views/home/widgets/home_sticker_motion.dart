import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../widgets/soullocket_animated_sticker.dart';
import '../../ui_prefs.dart';

/// Chỉ hình sticker chuyển động; khung thẻ, chữ và vùng chạm giữ nguyên.
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
    // Lệch pha ổn định để nhiều sticker không cùng nhún một nhịp.
    final seed = motionSeed.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      child: child,
      builder: (context, prefs, visual) {
        final effects = UiPrefs.resolveEffectProfile(
          state: prefs,
          isWeb: kIsWeb,
        );
        return SoulLocketStickerMotionView(
          animate: effects.animationEnabled,
          motion: motion,
          phaseOffset: (seed % 19) / 19,
          duration: Duration(milliseconds: 2800 + (seed % 7) * 130),
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
    return HomeStickerMotion(
      motion: motion,
      motionSeed: assetPath,
      child: Image.asset(
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
