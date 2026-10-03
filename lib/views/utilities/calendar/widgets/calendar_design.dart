import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';

/// Màu chữ được ghép với nền của lịch, không phụ thuộc theme của Home.
abstract final class CalendarDesign {
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      dark(context) ? const Color(0xFF211D22) : const Color(0xFFF8F4EE);
  static Color surface(BuildContext context) =>
      dark(context) ? const Color(0xFF2D272F) : const Color(0xFFFFFDF9);
  static Color soft(BuildContext context) =>
      dark(context) ? const Color(0xFF383039) : const Color(0xFFF1EAE3);
  static Color ink(BuildContext context) =>
      dark(context) ? const Color(0xFFF9F1F4) : const Color(0xFF362B32);
  static Color muted(BuildContext context) =>
      dark(context) ? const Color(0xFFC5B7C0) : const Color(0xFF75646C);
  static Color border(BuildContext context) =>
      dark(context) ? const Color(0xFF483C47) : const Color(0xFFE5DAD2);
  static Color primary(BuildContext context) =>
      dark(context) ? const Color(0xFFF1A9BB) : const Color(0xFFA8455D);
  static Color onPrimary(BuildContext context) =>
      dark(context) ? const Color(0xFF34202A) : const Color(0xFFFFFFFF);
  static Color holidayAccent(BuildContext context) =>
      dark(context) ? const Color(0xFFDDD39A) : const Color(0xFF6A6440);

  static TextStyle text(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.4,
  }) {
    final style = SLTheme.quicksand(
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink(context),
      height: height,
    );
    // Font người dùng chọn có thể thiếu glyph Arabic/CJK. Giữ các fallback
    // của theme để renderer dùng font phù hợp thay vì mất ký tự.
    return style.copyWith(
      fontFamilyFallback: <String>{
        ...?style.fontFamilyFallback,
        ...?Theme.of(context).textTheme.bodyMedium?.fontFamilyFallback,
      }.toList(),
    );
  }
}
