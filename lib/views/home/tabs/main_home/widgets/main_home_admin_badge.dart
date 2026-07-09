import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';

class MainHomeAdminBadge extends StatelessWidget {
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const MainHomeAdminBadge({
    super.key,
    this.iconSize = 14,
    this.padding = const EdgeInsets.only(left: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        padding: SLSpacing.all4,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: SLRadius.pillAll,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB300).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.admin_panel_settings_rounded,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
