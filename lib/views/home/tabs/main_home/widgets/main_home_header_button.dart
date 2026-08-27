import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Image.asset(
          imageAsset ?? 'assets/icons/cute_3d/btn_settings_3d_candy.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
