import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:soullocket_app/views/utilities/widgets/sleep_status_card.dart';
import '../../../../../../utils/sleep_tracking_math.dart';
import '../../../../../../utils/services/l10n_service.dart';
import '../../../../../../core/sl_theme.dart';
import 'widget_utility_surface.dart';

/// Cùng tỷ lệ/màu/artwork với native; caller quyết định dữ liệu thật hay mẫu.
class WidgetSleepEventPreview extends StatelessWidget {
  const WidgetSleepEventPreview({
    super.key,
    required this.sizeKey,
    required this.heading,
    this.sleep = false,
    this.people = const [],
    this.names = const [],
    this.now,
    this.title = '',
    this.days = '—',
    this.label = '',
    this.date = '',
    this.hasEvent = true,
    this.themeKey = 'pink',
    this.animated = false,
    this.accent = const Color(0xFF984C36),
  });
  final String sizeKey, heading, title, days, label, date, themeKey;
  final bool sleep, hasEvent, animated;
  final Color accent;
  final List<SleepPersonSnapshot> people;
  final List<String> names;
  final DateTime? now;

  Color get _ink =>
      sleep ? WidgetUtilityKind.sleep.ink : WidgetUtilityKind.event.ink;
  Widget _line(String value, {double size = 12, int lines = 1, Color? color}) =>
      Text(
        value,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: SLTheme.quicksand(
          fontSize: size,
          height: 1.12,
          fontWeight: FontWeight.w700,
          color: color ?? _ink,
        ),
      );
  Widget _art(String asset, double width, double height) => SizedBox(
    width: width,
    height: height,
    child: SvgPicture.asset('assets/images/widget_stickers/$asset.svg'),
  );
  SleepPersonSnapshot _personData(int i) => people.length > i
      ? people[i]
      : const SleepPersonSnapshot(state: 'unknown', source: 'unknown');
  String _name(BuildContext context, int i) =>
      names.length > i && names[i].trim().isNotEmpty
      ? names[i]
      : context.tr(i == 0 ? 'p3_sleep_default_me' : 'p3_sleep_default_partner');
  Widget _avatar(int i, double width, double height) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF6EFDF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: _art(i == 0 ? 'avatar_warm' : 'avatar_cream', width, height),
  );
  Widget _smallPerson(BuildContext context, int i) {
    final p = _personData(i);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            _avatar(i, 22, 26),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(_name(context, i), size: 10),
                  const SizedBox(height: 3),
                  _line(context.tr(sleepStateKey(p.state)), size: 8),
                  if (p.state == 'recorded')
                    _line(sleepDurationText(p.duration), size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _person(BuildContext context, int i, bool large) {
    final p = _personData(i);
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(large ? 12 : 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(i, large ? 32 : 27, large ? 32 : 27),
                const SizedBox(width: 6),
                Expanded(
                  child: _line(_name(context, i), size: large ? 15 : 11),
                ),
              ],
            ),
            SizedBox(height: large ? 6 : 4),
            _line(
              context.tr(sleepStateKey(p.state)),
              size: large ? 14 : 10,
              lines: 2,
            ),
            if (p.state == 'recorded') ...[
              const SizedBox(height: 4),
              _line(
                sleepDurationText(p.duration),
                size: large ? 24 : 18,
                lines: 2,
              ),
            ],
            const SizedBox(height: 6),
            _line(sleepSourceLabel(p.source), size: 9, lines: large ? 2 : 1),
          ],
        ),
      ),
    );
  }

  Color get _eventAccent {
    final rgb = accent.toARGB32();
    final red = (rgb >> 16) & 255, green = (rgb >> 8) & 255, blue = rgb & 255;
    final peak = math.max(1, math.max(red, math.max(green, blue)));
    final factor = math.min(1.0, 112 / peak);
    return Color.fromARGB(
      255,
      (red * factor).toInt(),
      (green * factor).toInt(),
      (blue * factor).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final small = sizeKey == 'small', large = sizeKey == 'large';
    final w = small ? 155.0 : 329.0, h = large ? 345.0 : 155.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final display = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : w,
          small
              ? 180.0
              : large
              ? 420.0
              : 340.0,
        );
        return SizedBox(
          width: display,
          height: display * h / w,
          child: FittedBox(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1,
              child: SizedBox(
                width: w,
                height: h,
                child: WidgetUtilitySurface(
                  kind: sleep
                      ? WidgetUtilityKind.sleep
                      : WidgetUtilityKind.event,
                  themeKey: themeKey,
                  animated: animated,
                  child: Padding(
                    padding: EdgeInsets.all(large ? 16 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _art(sleep ? 'moon' : 'gift', 24, 20),
                            const SizedBox(width: 6),
                            Expanded(child: _line(heading)),
                          ],
                        ),
                        SizedBox(height: large ? 12 : 6),
                        if (sleep) ...[
                          if (large) ...[
                            Center(child: _art('moon', 100, 44)),
                            const SizedBox(height: 12),
                          ],
                          Expanded(
                            child: small
                                ? Column(
                                    children: [
                                      _smallPerson(context, 0),
                                      const SizedBox(height: 5),
                                      _smallPerson(context, 1),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _person(context, 0, large),
                                      const SizedBox(width: 8),
                                      _person(context, 1, large),
                                    ],
                                  ),
                          ),
                          if (large) ...[
                            const SizedBox(height: 12),
                            _line(
                              context.tr(
                                Theme.of(context).platform == TargetPlatform.iOS
                                    ? 'sleep_tracking_info_ios'
                                    : 'sleep_tracking_info_android',
                              ),
                              size: 10,
                              lines: 3,
                            ),
                          ],
                        ] else if (hasEvent) ...[
                          if (large) ...[
                            Center(child: _art('gift', 105, 74)),
                            const SizedBox(height: 12),
                          ],
                          _line(
                            title,
                            size: large ? 20 : 14,
                            lines: large ? 2 : 1,
                          ),
                          SizedBox(height: large ? 12 : 6),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _line(
                                        days,
                                        size: large
                                            ? 50
                                            : small
                                            ? 28
                                            : 33,
                                        color: _eventAccent,
                                      ),
                                      const SizedBox(height: 3),
                                      _line(label, size: 10, lines: 2),
                                    ],
                                  ),
                                ),
                                if (!small) _art('gift', 54, 54),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          _line(date, size: 11),
                        ] else ...[
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Center(
                                  child: _art('gift', 60, small ? 34 : 48),
                                ),
                                const SizedBox(height: 8),
                                _line(
                                  context.tr('p8_events_empty_title'),
                                  lines: 2,
                                ),
                                const SizedBox(height: 4),
                                _line(
                                  context.tr('widget_sync_empty'),
                                  size: 10,
                                  lines: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
