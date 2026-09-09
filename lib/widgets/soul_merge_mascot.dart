import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';

/// Dùng cùng một hình đôi ở Home, header và điểm chạm trong Soul Merge.
class SoulMergeMascot extends StatelessWidget {
  const SoulMergeMascot({
    super.key,
    required this.size,
    this.animate = true,
    this.framed = false,
  });

  static const assetPath =
      'assets/images/soullocket_stickers/soul_merge_mascot_v2.png';

  final double size;
  final bool animate;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.tr('p4_soul_title'),
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: framed
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFDF9), Color(0xFFFFE8EF)],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAE5673).withValues(alpha: 0.14),
                      blurRadius: size * 0.16,
                      offset: Offset(0, size * 0.05),
                    ),
                  ],
                )
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.all(framed ? size * 0.08 : 0),
            child: SoulLocketStickerMotionView(
              animate: animate,
              motion: SoulLocketStickerMotion.breathe,
              duration: const Duration(milliseconds: 3200),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                cacheWidth: 512,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFE75B82),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
