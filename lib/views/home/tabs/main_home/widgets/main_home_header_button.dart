import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';

class MainHomeHeaderButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MainHomeHeaderButton({
    super.key,
    required this.icon,
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
        child: Center(
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
