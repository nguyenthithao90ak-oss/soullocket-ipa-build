// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension CountdownActionButtonExt on _CountdownModeIndependentScreenState {
  Widget _buildActionButton({
    required IconData icon,
    required Color foreground,
    required bool isDark,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.82),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.94),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
    );
    return Semantics(button: true, label: tooltip, child: child);
  }
}
