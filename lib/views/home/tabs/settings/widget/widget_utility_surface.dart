import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'widget_theme_surface.dart';

enum WidgetUtilityKind { sleep, event, cycle, calendar }

extension WidgetUtilityDesign on WidgetUtilityKind {
  String get titleKey => switch (this) {
    WidgetUtilityKind.sleep => 'widget_title_sleep',
    WidgetUtilityKind.event => 'p8_events_title',
    WidgetUtilityKind.cycle => 'p3_health_header_cycle',
    WidgetUtilityKind.calendar => 'home_lchchung_ac8882',
  };
  String get artwork => switch (this) {
    WidgetUtilityKind.sleep => 'moon',
    WidgetUtilityKind.event => 'gift',
    WidgetUtilityKind.cycle => 'cycle',
    WidgetUtilityKind.calendar => 'calendar',
  };
}

/// Nền dùng đúng palette theme của widget đôi; artwork vẫn giữ nét riêng từng loại.
class WidgetUtilitySurface extends StatelessWidget {
  const WidgetUtilitySurface({
    super.key,
    required this.kind,
    required this.child,
    this.themeKey = 'pink',
    this.animated = false,
  });
  final WidgetUtilityKind kind;
  final Widget child;
  final String themeKey;
  final bool animated;

  @override
  Widget build(BuildContext context) => WidgetThemeSurface(
    themeKey: themeKey,
    colors: WidgetThemeDesign.palette(themeKey),
    animated: animated,
    artworkOpacity: kind == WidgetUtilityKind.sleep ? .22 : .18,
    drawBorder: false,
    child: Stack(
      children: [
        Positioned(
          top: 12,
          right: 12,
          child: Opacity(
            opacity: kind == WidgetUtilityKind.sleep ? .08 : .14,
            child: SizedBox(
              width: 105,
              height: 105,
              child: SvgPicture.asset(
                'assets/images/widget_stickers/${kind.artwork}.svg',
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}
