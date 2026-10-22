import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sl_date_picker.dart';
import 'sl_dialog.dart';
import 'sl_settings_kit.dart';

/// Giữ thiết kế sáng hiện hữu; thay các màu Material khi người dùng chọn tối.
abstract final class SLAppTheme {
  static ThemeData apply(ThemeData light, {required bool isDark}) {
    if (!isDark) return light;
    const palette = SLSettingsPalette.dark;
    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: palette.accent,
      primary: palette.accent,
      onPrimary: const Color(0xFF39101E),
      primaryContainer: const Color(0xFF532536),
      onPrimaryContainer: const Color(0xFFFFD9E2),
      surface: palette.surface,
      surfaceDim: palette.canvas,
      surfaceBright: palette.surfaceMuted,
      surfaceContainerLowest: palette.canvas,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surfaceMuted,
      surfaceContainerHighest: palette.surfaceMuted,
      onSurface: palette.ink,
      onSurfaceVariant: palette.inkSecondary,
      outline: const Color(0xFF9B8992),
      outlineVariant: palette.border,
    );
    final textTheme = light.textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );
    return light.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      canvasColor: palette.canvas,
      scaffoldBackgroundColor: palette.canvas,
      cardColor: palette.surface,
      dividerColor: palette.divider,
      disabledColor: palette.inkTertiary,
      unselectedWidgetColor: palette.inkSecondary,
      textTheme: textTheme,
      primaryTextTheme: light.primaryTextTheme.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      iconTheme: light.iconTheme.copyWith(color: palette.ink),
      primaryIconTheme: light.primaryIconTheme.copyWith(
        color: scheme.onPrimary,
      ),
      splashColor: scheme.primary.withValues(alpha: 0.12),
      highlightColor: scheme.primary.withValues(alpha: 0.08),
      hoverColor: scheme.primary.withValues(alpha: 0.08),
      focusColor: scheme.primary.withValues(alpha: 0.12),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: scheme.primary,
      ),
      appBarTheme: light.appBarTheme.copyWith(
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        titleTextStyle: light.appBarTheme.titleTextStyle?.copyWith(
          color: palette.ink,
        ),
        iconTheme: IconThemeData(color: palette.ink),
        actionsIconTheme: IconThemeData(color: palette.ink),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: light.cardTheme.copyWith(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: light.dividerTheme.copyWith(color: palette.divider),
      dialogTheme: SLDialogStyle.theme(textTheme, isDark: true),
      datePickerTheme: SLPickerStyle.dateTheme(textTheme, isDark: true),
      timePickerTheme: SLPickerStyle.timeTheme(textTheme, isDark: true),
      bottomSheetTheme: light.bottomSheetTheme.copyWith(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(
        fillColor: palette.surfaceMuted,
        hintStyle: light.inputDecorationTheme.hintStyle?.copyWith(
          color: palette.inkTertiary,
        ),
        labelStyle: light.inputDecorationTheme.labelStyle?.copyWith(
          color: palette.inkSecondary,
        ),
        prefixIconColor: palette.inkSecondary,
        suffixIconColor: palette.inkSecondary,
        border: _inputBorder(palette.border),
        enabledBorder: _inputBorder(palette.border),
        disabledBorder: _inputBorder(palette.border),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
      ),
      checkboxTheme: light.checkboxTheme.copyWith(
        side: BorderSide(color: palette.inkSecondary),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.surfaceMuted;
          }
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
      dropdownMenuTheme: light.dropdownMenuTheme.copyWith(
        textStyle: light.dropdownMenuTheme.textStyle?.copyWith(
          color: palette.ink,
        ),
        menuStyle: light.dropdownMenuTheme.menuStyle?.copyWith(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
        ),
      ),
      popupMenuTheme: light.popupMenuTheme.copyWith(
        color: palette.surface,
        textStyle: textTheme.bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: light.elevatedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? palette.inkTertiary
                : scheme.onPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? palette.surfaceMuted
                : scheme.primary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: light.outlinedButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: light.textButtonTheme.style?.copyWith(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
        ),
      ),
      navigationBarTheme: light.navigationBarTheme.copyWith(
        backgroundColor: palette.surface,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : palette.inkSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = light.navigationBarTheme.labelTextStyle?.resolve(states);
          return (base ?? textTheme.labelMedium!).copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.ink
                : palette.inkSecondary,
          );
        }),
      ),
      progressIndicatorTheme: light.progressIndicatorTheme.copyWith(
        color: scheme.primary,
        circularTrackColor: scheme.primaryContainer,
        linearTrackColor: scheme.primaryContainer,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
}
