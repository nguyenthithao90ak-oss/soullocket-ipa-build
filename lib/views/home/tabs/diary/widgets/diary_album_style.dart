import 'package:flutter/material.dart';

import '../../../../../widgets/sl_settings_kit.dart';

/// Bảng màu giấy ấm dùng chung cho album và thanh chuyển mục nhật ký.
abstract final class DiaryAlbumStyle {
  static const canvas = Color(0xFFF8F5F1);
  static const paper = Color(0xFFFFFDFC);
  static const ink = Color(0xFF3D3435);
  static const muted = Color(0xFF786B69);
  static const rose = Color(0xFF975C68);
  static const roseWash = Color(0xFFF1E5E6);
  static const line = Color(0xFFE6DCD6);
  static const sage = Color(0xFF587364);
}

/// Màu giao diện album theo lựa chọn Sáng/Tối của app.
@immutable
class DiaryAlbumPalette {
  const DiaryAlbumPalette({required this.isDark});

  factory DiaryAlbumPalette.of(BuildContext context) => DiaryAlbumPalette(
    isDark: Theme.of(context).brightness == Brightness.dark,
  );

  final bool isDark;

  Color get canvas =>
      isDark ? SLSettingsColors.darkCanvas : DiaryAlbumStyle.canvas;
  Color get paper =>
      isDark ? SLSettingsColors.darkSurface : DiaryAlbumStyle.paper;
  Color get inset =>
      isDark ? SLSettingsColors.darkSurfaceMuted : const Color(0xFFEEE8E3);
  Color get ink => isDark ? SLSettingsColors.darkInk : DiaryAlbumStyle.ink;
  Color get muted =>
      isDark ? SLSettingsColors.darkInkSecondary : DiaryAlbumStyle.muted;
  Color get rose => isDark ? const Color(0xFFE5A9B8) : DiaryAlbumStyle.rose;
  Color get roseWash =>
      isDark ? const Color(0xFF3B2932) : DiaryAlbumStyle.roseWash;
  Color get line => isDark ? SLSettingsColors.darkBorder : DiaryAlbumStyle.line;

  Color tint(Color color) =>
      isDark ? Color.lerp(color, const Color(0xFFFFF3F6), 0.55)! : color;
}
