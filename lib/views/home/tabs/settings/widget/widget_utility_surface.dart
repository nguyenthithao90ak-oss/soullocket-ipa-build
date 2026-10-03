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
  List<Color> get colors => switch (this) {
    WidgetUtilityKind.sleep => const [Color(0xFF292943), Color(0xFF44425F)],
    WidgetUtilityKind.event => const [Color(0xFFFFF9ED), Color(0xFFFBE4D7)],
    WidgetUtilityKind.cycle => const [
      Color(0xFFFFF7DB),
      Color(0xFFE4F2D5),
      Color(0xFFC9E7E0),
    ],
    WidgetUtilityKind.calendar => const [
      Color(0xFFF0F9FF),
      Color(0xFFDCEAFF),
      Color(0xFFD9DDFB),
    ],
  };
  Color get ink => switch (this) {
    WidgetUtilityKind.sleep => const Color(0xFFFFF8E8),
    WidgetUtilityKind.event => const Color(0xFF654339),
    WidgetUtilityKind.cycle => const Color(0xFF324D38),
    WidgetUtilityKind.calendar => const Color(0xFF294C74),
  };
}

/// Nền từng loại cố định để dễ nhận diện; theme chỉ đổi họa tiết, không thêm halo/viền.
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
    colors: kind.colors,
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
