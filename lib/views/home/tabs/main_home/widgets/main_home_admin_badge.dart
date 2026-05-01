part of '../../main_home_tab.dart';
// ignore_for_file: unused_element

extension _MainHomeAdminBadgeExt on _MainHomeTabState {
  Widget _buildAdminBadge({
    double iconSize = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.only(left: 6),
  }) {
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
              color: const Color(0xFFFFB300).withOpacity(0.28),
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
