import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';

class MainHomeHeaderButton extends StatelessWidget {
  final IconData? icon;
  final String? imageAsset;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MainHomeHeaderButton({
    super.key,
    this.icon,
    this.imageAsset,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.025,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SLColors.paper,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: SLColors.border, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: SLColors.ink.withValues(alpha: 0.11),
                  blurRadius: 14,
                  spreadRadius: -5,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (imageAsset != null)
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(imageAsset!, fit: BoxFit.contain),
                  )
                else
                  Icon(icon ?? Icons.favorite_rounded, color: color, size: 22),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 7,
                    color: color.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
