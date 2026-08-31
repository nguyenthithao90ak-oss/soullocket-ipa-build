part of '../../../settings_tab.dart';

Color _surfaceFillColor(_CountdownModeThemeData themeData) {
  if (themeData.isDark) {
    return Colors.white.withValues(alpha: 0.12);
  }
  switch (UiPrefs.notifier.value.homeBlockToneKey) {
    case 'mist':
      return const Color(0xFFEEF4FF).withValues(alpha: 0.88);
    case 'rose':
      return const Color(0xFFFFE8F0).withValues(alpha: 0.90);
    case 'glass':
      return Colors.white.withValues(alpha: 0.66);
    default:
      return const Color(0xFFFFF0F6).withValues(alpha: 0.88);
  }
}

Color _surfaceBorderColor(_CountdownModeThemeData themeData) {
  if (themeData.isDark) {
    return Colors.white.withValues(alpha: 0.18);
  }
  switch (UiPrefs.notifier.value.homeBlockToneKey) {
    case 'mist':
      return const Color(0xFFE3F2FD).withValues(alpha: 0.86);
    case 'rose':
      return const Color(0xFFF8D7E4).withValues(alpha: 0.86);
    case 'glass':
      return Colors.white.withValues(alpha: 0.72);
    default:
      return Colors.white.withValues(alpha: 0.72);
  }
}

Color _surfaceShadowColor(_CountdownModeThemeData themeData) {
  if (themeData.isDark) {
    return Colors.black.withValues(alpha: 0.22);
  }
  switch (UiPrefs.notifier.value.homeBlockToneKey) {
    case 'mist':
      return const Color(0xFF64B5F6).withValues(alpha: 0.08);
    case 'rose':
      return const Color(0xFFD94C86).withValues(alpha: 0.08);
    case 'glass':
      return Colors.white.withValues(alpha: 0.06);
    default:
      return const Color(0xFFD94C86).withValues(alpha: 0.08);
  }
}

class _CountdownSurfaceContainer extends StatelessWidget {
  final _CountdownModeThemeData themeData;
  final Widget child;
  final EdgeInsetsGeometry padding;

  // ignore: unused_element_parameter
  const _CountdownSurfaceContainer({
    required this.themeData,
    required this.child,
    // ignore: unused_element_parameter
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceFillColor(themeData),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _surfaceBorderColor(themeData), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: _surfaceShadowColor(themeData),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
