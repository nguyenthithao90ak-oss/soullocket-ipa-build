// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code, non_constant_identifier_names
part of '../../settings_tab.dart';

extension _CountdownModeIndependentScreenViewPart
    on _CountdownModeIndependentScreenState {
  String _resolveThemeKey(String rawKey) {
    final key = rawKey.trim();
    if (key.isNotEmpty && key != 'theme-auto') return key;
    final now = DateTime.now();
    if (now.hour >= 19 || now.hour < 5) return 'theme-night';
    switch (now.month) {
      case 6:
      case 7:
      case 8:
        return 'theme-ocean';
      case 9:
      case 10:
      case 11:
        return 'theme-sunset';
      default:
        return 'theme-pink-glow';
    }
  }

  Color _titleColor(_CountdownModeThemeData themeData) {
    return themeData.isDark ? Colors.white : const Color(0xFF3D2B40);
  }

  Color _subtitleColor(_CountdownModeThemeData themeData) {
    return themeData.isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF8A6B88);
  }

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

  Widget _CountdownSurfaceContainer({
    required _CountdownModeThemeData themeData,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceFillColor(themeData),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _surfaceBorderColor(themeData),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: _surfaceShadowColor(themeData),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  }