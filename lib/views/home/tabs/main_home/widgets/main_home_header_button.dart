part of '../../main_home_tab.dart';

extension _MainHomeHeaderButtonExt on _MainHomeTabState {
  Widget _buildHeaderButton({
    Key? key,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: SLRadius.xlAll,
          border: Border.all(color: const Color(0xCCE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
