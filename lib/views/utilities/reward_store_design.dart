import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';

/// Màu trình bày của cửa hàng; không tham gia tính điểm hay quyền đổi thưởng.
@immutable
class RewardStorePalette {
  const RewardStorePalette._(this.dark);

  factory RewardStorePalette.of(BuildContext context) =>
      RewardStorePalette._(Theme.of(context).brightness == Brightness.dark);

  final bool dark;
  Color get canvas => dark ? SLColors.darkBgMain : SLColors.paperCanvas;
  Color get surface => dark ? SLColors.darkBgCard : SLColors.paper;
  Color get ink => dark ? SLColors.darkTextPrimary : SLColors.ink;
  Color get muted => dark ? SLColors.darkTextSecond : SLColors.textSecondary;
  Color get line => dark ? SLColors.darkBorder : SLColors.border;
  Color get rose => dark ? const Color(0xFFE7ADC1) : const Color(0xFF943F5B);
  Color get roseSoft => dark ? const Color(0xFF40303B) : SLColors.paperBlush;
  Color get success => dark ? const Color(0xFFA8D4B2) : const Color(0xFF3E7250);
  Color get successSoft =>
      dark ? const Color(0xFF28372F) : const Color(0xFFEDF5EE);
  Color get gold => dark ? const Color(0xFFE6BF87) : const Color(0xFF916032);
  Color get goldSoft => dark ? const Color(0xFF393029) : SLColors.paperPeach;
  Color get onAccent => dark ? SLColors.darkBgMain : SLColors.textInverse;
  Color get disabled => dark ? SLColors.darkBgElevated : SLColors.bgMuted;
  List<Color> get wallet => dark
      ? const [Color(0xFF513344), Color(0xFF693A50)]
      : const [Color(0xFF87394F), Color(0xFFAD4668)];

  TextStyle text(double size, {Color? color, bool bold = false}) =>
      SLTheme.quicksand(
        fontSize: size,
        color: color ?? ink,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.45,
      );

  BoxDecoration card({Color? color, double radius = 24}) => BoxDecoration(
    color: color ?? surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: line),
  );
}
