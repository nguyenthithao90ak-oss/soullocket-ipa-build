import 'package:flutter/material.dart';

import '../core/soul_locket_brand.dart';

class SoulLocketBrandMark extends StatelessWidget {
  const SoulLocketBrandMark({
    super.key,
    this.styleKey,
    this.size = 88,
    this.showLabel = false,
    this.labelColor,
  });

  final String? styleKey;
  final double size;
  final bool showLabel;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final style = SoulLocketBrand.styleFor(styleKey);
    final radius = size * 0.28;
    final heartOuterSize = size * 0.42;
    final heartInnerSize = size * 0.31;
    final sparkSize = size * 0.12;

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.backgroundColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: style.frameColor.withOpacity(0.92),
          width: size * 0.018,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: style.glowColor.withOpacity(0.26),
            blurRadius: size * 0.24,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: size * 0.16,
            right: size * 0.16,
            top: size * 0.16,
            bottom: size * 0.16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: style.surfaceColor.withOpacity(0.92),
                borderRadius: BorderRadius.circular(size * 0.23),
              ),
            ),
          ),
          Positioned(
            top: size * 0.14,
            right: size * 0.14,
            child: Container(
              width: sparkSize,
              height: sparkSize,
              decoration: BoxDecoration(
                color: style.sparkleColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.85),
                  width: size * 0.01,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.favorite_rounded,
              size: heartOuterSize,
              color: style.heartOutlineColor,
            ),
          ),
          Center(
            child: Icon(
              Icons.favorite_rounded,
              size: heartInnerSize,
              color: style.heartColor,
            ),
          ),
        ],
      ),
    );

    if (!showLabel) {
      return badge;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        badge,
        const SizedBox(height: 8),
        Text(
          style.label,
          style: TextStyle(
            fontSize: 12.2,
            fontWeight: FontWeight.w800,
            color: labelColor ?? const Color(0xFF243041),
          ),
        ),
      ],
    );
  }
}
