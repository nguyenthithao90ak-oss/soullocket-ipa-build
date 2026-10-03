import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../../core/sl_theme.dart';
import '../../../../../../utils/services/l10n_service.dart';
import '../../../../../../utils/sleep_tracking_math.dart';
import 'widget_sleep_event_preview.dart';
import 'widget_utility_surface.dart';

/// Mẫu được gắn nhãn rõ ràng, không ghi dữ liệu minh họa vào widget/House.
class WidgetUtilityGallery extends StatefulWidget {
  const WidgetUtilityGallery({
    super.key,
    required this.sizeKey,
    required this.themeKey,
    required this.animated,
  });
  final String sizeKey, themeKey;
  final bool animated;
  @override
  State<WidgetUtilityGallery> createState() => _WidgetUtilityGalleryState();
}

class _WidgetUtilityGalleryState extends State<WidgetUtilityGallery> {
  WidgetUtilityKind _kind = WidgetUtilityKind.sleep;
  bool _empty = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in WidgetUtilityKind.values)
                SizedBox(
                  width: itemWidth,
                  child: _UtilityKindChoice(
                    kind: kind,
                    selected: _kind == kind,
                    onTap: () => setState(() => _kind = kind),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Center(
        child:
            _kind == WidgetUtilityKind.sleep || _kind == WidgetUtilityKind.event
            ? WidgetSleepEventPreview(
                sizeKey: widget.sizeKey,
                heading: context.tr(_kind.titleKey),
                sleep: _kind == WidgetUtilityKind.sleep,
                themeKey: widget.themeKey,
                animated: widget.animated,
                people: _empty
                    ? const []
                    : const [
                        SleepPersonSnapshot(
                          state: 'recorded',
                          source: 'healthkit',
                          duration: 27300000,
                        ),
                        SleepPersonSnapshot(
                          state: 'unknown',
                          source: 'unknown',
                        ),
                      ],
                title: context.tr('home_knim_4f6aeb'),
                days: '12',
                label: context.tr('p8_events_days_remaining_label'),
                date: MaterialLocalizations.of(
                  context,
                ).formatMediumDate(DateTime(2026, 10, 15)),
                hasEvent: !_empty,
              )
            : WidgetPlanPreview(
                kind: _kind,
                sizeKey: widget.sizeKey,
                themeKey: widget.themeKey,
                animated: widget.animated,
                enabled: !_empty,
                headline: context.tr(
                  _kind == WidgetUtilityKind.cycle
                      ? 'p3_health_phase_period'
                      : 'milestone_tomorrow',
                ),
                detail: context.tr(
                  _kind == WidgetUtilityKind.cycle
                      ? 'p3_health_next_period'
                      : 'p8_events_title',
                ),
                date: MaterialLocalizations.of(
                  context,
                ).formatMediumDate(DateTime(2026, 10, 15)),
                progress: .65,
              ),
      ),
      const SizedBox(height: 8),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.tr('widget_preview_empty'),
          style: SLTheme.quicksand(fontSize: 12),
        ),
        value: _empty,
        onChanged: (value) => setState(() => _empty = value),
      ),
    ],
  );
}

class _UtilityKindChoice extends StatelessWidget {
  const _UtilityKindChoice({
    required this.kind,
    required this.selected,
    required this.onTap,
  });
  final WidgetUtilityKind kind;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (kind) {
    WidgetUtilityKind.sleep => Icons.nightlight_round,
    WidgetUtilityKind.event => Icons.card_giftcard_rounded,
    WidgetUtilityKind.cycle => Icons.local_florist_outlined,
    WidgetUtilityKind.calendar => Icons.calendar_month_outlined,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: context.tr(kind.titleKey),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          constraints: const BoxConstraints(minHeight: 48),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFFF8F4F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE9567D)
                  : const Color(0xFFF0E4E8),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 17,
                color: selected
                    ? const Color(0xFFE9567D)
                    : const Color(0xFF8B7B82),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.tr(kind.titleKey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected
                        ? const Color(0xFFB83D60)
                        : const Color(0xFF746A70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Cùng hoa/lịch, nền, thẻ và thứ tự nội dung với WidgetUtilityView iOS.
class WidgetPlanPreview extends StatelessWidget {
  const WidgetPlanPreview({
    super.key,
    required this.kind,
    required this.sizeKey,
    this.themeKey = 'pink',
    this.animated = false,
    this.enabled = false,
    this.headline = '',
    this.detail = '',
    this.date = '',
    this.progress = 0,
    this.cycleDays = '12',
  });
  final WidgetUtilityKind kind;
  final String sizeKey, themeKey, headline, detail, date, cycleDays;
  final bool animated, enabled;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final small = sizeKey == 'small', large = sizeKey == 'large';
    final w = small ? 155.0 : 329.0, h = large ? 345.0 : 155.0;
    Widget line(String value, {double size = 12, int lines = 1}) => Text(
      value,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      style: SLTheme.quicksand(
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: kind.ink,
      ),
    );
    Widget art(double height) => SizedBox(
      width: height * 1.2,
      height: height,
      child: SvgPicture.asset(
        'assets/images/widget_stickers/${kind.artwork}.svg',
      ),
    );
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
                  kind: kind,
                  themeKey: themeKey,
                  animated: animated,
                  child: Padding(
                    padding: EdgeInsets.all(
                      large
                          ? 16
                          : small
                          ? 9
                          : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            art(22),
                            const SizedBox(width: 6),
                            Expanded(child: line(context.tr(kind.titleKey))),
                          ],
                        ),
                        if (large) ...[
                          const SizedBox(height: 12),
                          Center(child: art(74)),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(small ? 8 : 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .48),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (enabled) ...[
                                  if (kind == WidgetUtilityKind.cycle) ...[
                                    if (small)
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _CycleDayRing(
                                              days: cycleDays,
                                              progress: progress,
                                              diameter: 64,
                                            ),
                                            const SizedBox(height: 4),
                                            line(headline, size: 12),
                                          ],
                                        ),
                                      )
                                    else
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          _CycleDayRing(
                                            days: cycleDays,
                                            progress: progress,
                                            diameter: large ? 94 : 72,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                line(
                                                  headline,
                                                  size: large ? 22 : 18,
                                                  lines: 2,
                                                ),
                                                const SizedBox(height: 5),
                                                line(
                                                  detail,
                                                  size: large ? 13 : 9,
                                                  lines: large ? 3 : 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ] else ...[
                                    line(
                                      headline,
                                      size: large
                                          ? 26
                                          : small
                                          ? 15
                                          : 20,
                                      lines: 2,
                                    ),
                                    const SizedBox(height: 6),
                                    line(date, size: 11),
                                    const SizedBox(height: 6),
                                  ],
                                  if (kind != WidgetUtilityKind.cycle)
                                    line(
                                      detail,
                                      size: large ? 14 : 10,
                                      lines: large ? 3 : 2,
                                    ),
                                ] else ...[
                                  Center(child: art(large ? 58 : 28)),
                                  const SizedBox(height: 6),
                                  line(
                                    context.tr(
                                      kind == WidgetUtilityKind.cycle
                                          ? 'util_health_enable_cycle_tracking'
                                          : 'widget_sync_empty',
                                    ),
                                    size: 11,
                                    lines: 3,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
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

class _CycleDayRing extends StatelessWidget {
  const _CycleDayRing({
    required this.days,
    required this.progress,
    required this.diameter,
  });
  final String days;
  final double progress, diameter;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final stroke = diameter >= 90 ? 8.0 : 6.0;
    return Semantics(
      label: '$days ${context.tr('p3_health_days_remaining')}',
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('cycle-day-ring'),
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(stroke / 2),
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: stroke,
                    color: const Color(0xFFD7E2CA),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(stroke / 2),
                  child: CircularProgressIndicator(
                    value: safeProgress,
                    strokeWidth: stroke,
                    strokeCap: StrokeCap.round,
                    color: const Color(0xFF648269),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: stroke + 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      days,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: diameter >= 90
                            ? 25
                            : diameter >= 70
                            ? 20
                            : 16,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF324D38),
                      ),
                    ),
                    Text(
                      context.tr('p3_health_days_remaining'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: diameter >= 90 ? 8 : 7,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF648269),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
