import 'package:flutter/material.dart';

class SLFeedbackStyle {
  static const surface = Color(0xFF2D2930);
  static const foreground = Color(0xFFFAF6F8);
  static const secondary = Color(0xFFC9BEC5);
  static const border = Color(0xFF514650);
  static const success = Color(0xFF91D5B6);
  static const warning = Color(0xFFEBC88B);
  static const danger = Color(0xFFF1A5B3);
  static const info = Color(0xFFA6CBF0);
  static const primary = Color(0xFFE8B4CB);
  static const maxWidth = 480.0;
  static const radius = BorderRadius.all(Radius.circular(16));
  static const textStyle = TextStyle(
    color: foreground,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static const shape = RoundedRectangleBorder(
    borderRadius: radius,
    side: BorderSide(color: border, width: 0.5),
  );

  static Color accentFor(Color? color) {
    if (color == null || color.a == 0) return info;
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.15) return info;
    if (hsl.hue >= 15 && hsl.hue < 70) return warning;
    if (hsl.hue >= 70 && hsl.hue < 180) return success;
    if (hsl.hue >= 180 && hsl.hue < 270) return info;
    if (hsl.hue >= 270 && hsl.hue < 335) return primary;
    return danger;
  }

  static IconData iconFor(Color accent) {
    if (accent == success) return Icons.check_circle_outline_rounded;
    if (accent == warning) return Icons.warning_amber_rounded;
    if (accent == danger) return Icons.error_outline_rounded;
    if (accent == primary) return Icons.favorite_border_rounded;
    return Icons.info_outline_rounded;
  }

  static SnackBarThemeData snackBarTheme({double? availableWidth}) {
    final horizontal = availableWidth != null && availableWidth > maxWidth + 32
        ? (availableWidth - maxWidth) / 2
        : 16.0;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surface,
      contentTextStyle: textStyle,
      shape: shape,
      elevation: 6,
      insetPadding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 16),
      actionTextColor: primary,
      closeIconColor: secondary,
      showCloseIcon: true,
      actionOverflowThreshold: 0.3,
      dismissDirection: DismissDirection.horizontal,
    );
  }
}

class SLFeedbackTheme extends StatelessWidget {
  const SLFeedbackTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Theme(
      data: Theme.of(context).copyWith(
        snackBarTheme: SLFeedbackStyle.snackBarTheme(
          availableWidth: constraints.maxWidth,
        ),
      ),
      child: child,
    ),
  );
}

class SLFeedbackContent extends StatelessWidget {
  const SLFeedbackContent({
    super.key,
    required this.child,
    this.accent = SLFeedbackStyle.info,
    this.icon,
  });

  final Widget child;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon ?? SLFeedbackStyle.iconFor(accent),
          size: 19,
          color: accent,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: DefaultTextStyle.merge(
            style: SLFeedbackStyle.textStyle.copyWith(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            child: child,
          ),
        ),
      ),
    ],
  );
}

class SLSnackBar extends SnackBar {
  SLSnackBar({
    super.key,
    required Widget content,
    Color? backgroundColor,
    IconData? icon,
    SnackBarAction? action,
    super.duration,
    super.width,
    super.margin,
    super.behavior = SnackBarBehavior.floating,
    super.onVisible,
    super.dismissDirection = DismissDirection.horizontal,
  }) : super(
         content: SLFeedbackContent(
           accent: SLFeedbackStyle.accentFor(backgroundColor),
           icon: icon,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               content,
               if (action != null)
                 Align(
                   alignment: AlignmentDirectional.centerEnd,
                   child: action,
                 ),
             ],
           ),
         ),
         backgroundColor: SLFeedbackStyle.surface,
         elevation: 6,
         shape: SLFeedbackStyle.shape,
         padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
         showCloseIcon: true,
         closeIconColor: SLFeedbackStyle.secondary,
         persist: action != null,
       );
}
