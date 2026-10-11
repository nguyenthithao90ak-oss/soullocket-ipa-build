import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../widgets/sl_settings_kit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../../core/sl_theme.dart';
import '../../../../../../utils/services/l10n_service.dart';
import '../../../../../../utils/sleep_tracking_math.dart';
import '../../../../../../widgets/cycle_flower.dart';
import 'widget_sleep_event_preview.dart';
import 'widget_theme_surface.dart';
import 'widget_utility_surface.dart';

/// Loại đang xem tách khỏi style của widget đôi đã lưu trên màn hình chính.
enum WidgetStudioTemplate {
  classic('classic', 'home_mcnh_a57a8e', Icons.widgets_rounded),
  countdown('countdown', 'home_mngy_5500cb', Icons.timer_outlined),
  event('soulevent', 'p8_events_title', Icons.card_giftcard_rounded),
  cycle('cycle', 'widget_type_cycle', Icons.local_florist_outlined),
  sleep('sleep', 'widget_title_sleep', Icons.nightlight_round),
  calendar('calendar', 'home_lchchung_ac8882', Icons.calendar_month_outlined);

  const WidgetStudioTemplate(this.id, this.titleKey, this.icon);
  final String id, titleKey;
  final IconData icon;

  bool get usesCoupleStyle => this == classic || this == countdown;
  WidgetUtilityKind? get sampleKind => switch (this) {
    sleep => WidgetUtilityKind.sleep,
    cycle => WidgetUtilityKind.cycle,
    calendar => WidgetUtilityKind.calendar,
    _ => null,
  };

  static WidgetStudioTemplate fromId(String id) =>
      values.firstWhere((item) => item.id == id, orElse: () => classic);
}

/// Một bộ chọn và một preview; mẫu minh họa không được ghi vào widget/House.
class WidgetUtilityGallery extends StatefulWidget {
  const WidgetUtilityGallery({
    super.key,
    required this.sizeKey,
    required this.themeKey,
    required this.animated,
    required this.selectedId,
    required this.onChanged,
    required this.previewBuilder,
  });
  final String sizeKey, themeKey;
  final bool animated;
  final String selectedId;
  final ValueChanged<String> onChanged;
  final WidgetBuilder previewBuilder;
  @override
  State<WidgetUtilityGallery> createState() => _WidgetUtilityGalleryState();
}

class _WidgetUtilityGalleryState extends State<WidgetUtilityGallery> {
  bool _empty = false;

  @override
  void didUpdateWidget(WidgetUtilityGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) _empty = false;
  }

  @override
  Widget build(BuildContext context) {
    final selected = WidgetStudioTemplate.fromId(widget.selectedId);
    final kind = selected.sampleKind;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 250 ||
                    MediaQuery.textScalerOf(context).scale(12) > 18
                ? 1
                : 2;
            final itemWidth =
                (constraints.maxWidth - 8 * (columns - 1)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in WidgetStudioTemplate.values)
                  SizedBox(
                    width: itemWidth,
                    child: _UtilityKindChoice(
                      template: template,
                      selected: selected == template,
                      onTap: () => widget.onChanged(template.id),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (kind != null) ...[
          Text(
            context.tr('widget_utility_examples_hint'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              color: SLSettingsColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Center(
          child: KeyedSubtree(
            key: ValueKey('widget-preview-${selected.id}'),
            child: kind == null
                ? widget.previewBuilder(context)
                : kind == WidgetUtilityKind.sleep
                ? WidgetSleepEventPreview(
                    sizeKey: widget.sizeKey,
                    heading: context.tr(kind.titleKey),
                    sleep: true,
                    themeKey: widget.themeKey,
                    animated: widget.animated,
                    accent: WidgetThemeDesign.accent(widget.themeKey),
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
                    kind: kind,
                    sizeKey: widget.sizeKey,
                    themeKey: widget.themeKey,
                    animated: widget.animated,
                    enabled: !_empty,
                    headline: context.tr(
                      kind == WidgetUtilityKind.cycle
                          ? 'cycle_ui_phase_luteal'
                          : 'milestone_tomorrow',
                    ),
                    detail: context.tr(
                      kind == WidgetUtilityKind.cycle
                          ? 'cycle_ui_until_next_period'
                          : 'p8_events_title',
                    ),
                    date: MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(DateTime(2026, 10, 15)),
                    progress: .57,
                  ),
          ),
        ),
        if (kind != null) ...[
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.tr('widget_preview_empty'),
                style: SLTheme.quicksand(fontSize: 12),
              ),
              value: _empty,
              onChanged: (value) => setState(() => _empty = value),
            ),
          ),
        ],
      ],
    );
  }
}

class _UtilityKindChoice extends StatelessWidget {
  const _UtilityKindChoice({
    required this.template,
    required this.selected,
    required this.onTap,
  });
  final WidgetStudioTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: context.tr(template.titleKey),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('widget-template-${template.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          constraints: const BoxConstraints(minHeight: 48),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? SLSettingsColors.accentSoft
                : SLSettingsColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? SLSettingsColors.accent
                  : SLSettingsColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                template.icon,
                size: 17,
                color: selected
                    ? SLSettingsColors.accent
                    : SLSettingsColors.inkTertiary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.tr(template.titleKey),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected
                        ? SLSettingsColors.accentStrong
                        : SLSettingsColors.inkSecondary,
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
    final ink = WidgetThemeDesign.ink(themeKey);
    final cardColor = WidgetThemeDesign.cardColor(themeKey);
    final accent = WidgetThemeDesign.accent(themeKey);
    final track = WidgetThemeDesign.progressTrack(themeKey);
    Widget line(String value, {double size = 12, int lines = 1}) =>
        WidgetPreviewLabel(value, lines: lines, size: size, color: ink);
    Widget art(double height) => kind == WidgetUtilityKind.cycle
        ? CycleFlower(width: height * 1.2, animated: animated)
        : SizedBox(
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
                              color: cardColor,
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
                                              diameter: 40,
                                              accent: accent,
                                              ink: ink,
                                              track: track,
                                            ),
                                            const SizedBox(height: 4),
                                            line(
                                              context.tr(
                                                'cycle_ui_until_next_period',
                                              ),
                                              size: 9,
                                            ),
                                            const SizedBox(height: 3),
                                            line(headline, size: 8),
                                            const SizedBox(height: 3),
                                            line(
                                              date.isEmpty
                                                  ? detail
                                                  : L10nService().format(
                                                      'cycle_ui_expected_on',
                                                      {'date': date},
                                                    ),
                                              size: 7,
                                              lines: 2,
                                            ),
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
                                            accent: accent,
                                            ink: ink,
                                            track: track,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                line(
                                                  context.tr(
                                                    'cycle_ui_until_next_period',
                                                  ),
                                                  size: large ? 12 : 10,
                                                ),
                                                const SizedBox(height: 5),
                                                line(
                                                  headline,
                                                  size: large ? 22 : 18,
                                                  lines: 2,
                                                ),
                                                const SizedBox(height: 5),
                                                line(
                                                  date.isEmpty
                                                      ? detail
                                                      : L10nService().format(
                                                          'cycle_ui_expected_on',
                                                          {'date': date},
                                                        ),
                                                  size: large ? 12 : 9,
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
                                  if (kind == WidgetUtilityKind.cycle &&
                                      large) ...[
                                    const SizedBox(height: 12),
                                    line(
                                      context.tr('cycle_ui_estimate'),
                                      size: 10,
                                      lines: 2,
                                    ),
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
    required this.accent,
    required this.ink,
    required this.track,
  });
  final String days;
  final double progress, diameter;
  final Color accent, ink, track;

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
                    color: track,
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
                    color: accent,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: stroke + 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WidgetPreviewLabel(
                      days,
                      size: diameter >= 90
                          ? 25
                          : diameter >= 70
                          ? 20
                          : 16,
                      color: ink,
                    ),
                    WidgetPreviewLabel(
                      context.tr('p3_health_days_remaining'),
                      size: diameter >= 90 ? 8 : 7,
                      color: accent,
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
