import 'package:flutter/material.dart';

import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/sl_settings_kit.dart';
import '../../../widgets/main_home/hero/countdown_artwork_surface.dart';
import 'theme_canvas_painter.dart';

abstract final class AppearancePanelStyle {
  static const canvas = SLSettingsColors.canvas;
  static const paper = SLSettingsColors.surface;
  static const ink = SLSettingsColors.ink;
  static const muted = SLSettingsColors.inkSecondary;
  static const rose = SLSettingsColors.accentStrong;
  static const blush = SLSettingsColors.accentSoft;
  static const line = SLSettingsColors.border;
}

class AppearancePanelHeader extends StatelessWidget {
  const AppearancePanelHeader({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: SLSettingsPageHeader(
      title: context.tr('appearance_page_title'),
      description: context.tr('theme_preview_desc'),
      icon: Icons.palette_outlined,
      iconColor: SLSettingsColors.violet,
      isDark: SLSettingsPalette.isNightTheme,
      onBack: onBack,
      backLabel: context.tr('p7_back'),
    ),
  );
}

/// Mỗi nhóm có artwork riêng, giữ bản nháp con khi đóng/mở.
class AppearanceSectionCard extends StatefulWidget {
  const AppearanceSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    this.accentColor,
    this.artKind = AppearanceArtKind.palette,
    this.initiallyExpanded = false,
    this.isDark,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final Color? accentColor;
  final AppearanceArtKind artKind;
  final bool initiallyExpanded;
  final bool? isDark;

  @override
  State<AppearanceSectionCard> createState() => _AppearanceSectionCardState();
}

class _AppearanceSectionCardState extends State<AppearanceSectionCard> {
  late bool _expanded;
  late bool _opened;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _opened = _expanded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark ?? SLSettingsPalette.isNightTheme;
    final palette = SLSettingsPalette.resolve(isDark);
    final accent = palette.tint(widget.accentColor ?? palette.accent);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: isDark ? .24 : .17)),
        boxShadow: palette.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            maintainState: true,
            initiallyExpanded: widget.initiallyExpanded,
            onExpansionChanged: (value) => setState(() {
              _expanded = value;
              _opened = _opened || value;
            }),
            tilePadding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            shape: const Border(),
            collapsedShape: const Border(),
            minTileHeight: 92,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (MediaQuery.textScalerOf(context).scale(14) < 22) ...[
                  ExcludeSemantics(
                    child: Container(
                      width: 68,
                      height: 70,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? .09 : .07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CustomPaint(
                        painter: AppearanceArtworkPainter(
                          kind: widget.artKind,
                          accent: accent,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: SLSettingsText.title(palette.ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.description,
                        style: SLSettingsText.caption(palette.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.expand_more_rounded, size: 19, color: accent),
              ),
            ),
            children: [
              Divider(height: 18, color: palette.divider),
              if (_opened) widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Vùng xem trước chỉ là minh họa; chữ hướng dẫn bên ngoài vẫn theo cỡ chữ máy.
class AppearancePreviewCard extends StatelessWidget {
  const AppearancePreviewCard({
    super.key,
    required this.title,
    required this.sampleLabel,
    required this.description,
    required this.colors,
    required this.accent,
    required this.themeKey,
    required this.effectKey,
    required this.child,
    this.isDark = false,
    this.reduced = false,
    this.background,
  });

  final String title;
  final String sampleLabel;
  final String description;
  final List<Color> colors;
  final Color accent;
  final String themeKey;
  final String effectKey;
  final Widget child;
  final bool isDark;
  final bool reduced;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? const Color(0xFFFFF3F6) : SLSettingsColors.ink;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            if (background != null) Positioned.fill(child: background!),
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ThemeCanvasAmbientPainter(
                      themeKey: themeKey,
                      effectKey: effectKey,
                      accent: accent,
                      isDark: isDark,
                      reduced: reduced,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: SLSettingsText.title(ink)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          sampleLabel,
                          style: SLSettingsText.caption(ink),
                        ),
                      ),
                    ],
                  ),
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: EdgeInsets.zero,
                          viewPadding: EdgeInsets.zero,
                          textScaler: TextScaler.noScaling,
                          disableAnimations:
                              reduced ||
                              MediaQuery.disableAnimationsOf(context),
                        ),
                        child: SizedBox(
                          height: 176,
                          width: double.infinity,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    description,
                    style: SLSettingsText.caption(ink.withValues(alpha: .76)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceCountdownPreview extends StatelessWidget {
  const AppearanceCountdownPreview({
    super.key,
    required this.styleKey,
    required this.valueText,
    required this.topLabel,
    required this.bottomLabel,
    required this.textStyle,
    this.transparent = false,
    this.isDark = false,
  });
  final String styleKey;
  final String valueText;
  final String topLabel;
  final String bottomLabel;
  final TextStyle textStyle;
  final bool transparent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final design = CountdownArtworkDesign.of(styleKey);
    final ink = isDark
        ? Colors.white
        : (design.night ? design.paper : design.ink);
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(brightness: isDark ? Brightness.dark : Brightness.light),
      child: CountdownArtworkSurface(
        styleKey: styleKey,
        enableMotion: false,
        transparent: transparent,
        minimumContentExtent: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                topLabel,
                style: textStyle.copyWith(fontSize: 8, color: ink),
              ),
            ),
            FittedBox(
              child: Text(
                valueText,
                style: textStyle.copyWith(
                  fontSize: 31,
                  height: 1.15,
                  color: ink,
                ),
              ),
            ),
            FittedBox(
              child: Text(
                bottomLabel,
                style: textStyle.copyWith(fontSize: 8, color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceEffectGrid extends StatelessWidget {
  const AppearanceEffectGrid({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.isDark,
  });
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(
      isDark ?? SLSettingsPalette.isNightTheme,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;
        final columns = largeText || constraints.maxWidth < 245 ? 2 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final selected = option.$2 == value;
            return SizedBox(
              width: width,
              child: Semantics(
                button: true,
                selected: selected,
                label: option.$1,
                child: ExcludeSemantics(
                  child: Material(
                    color: selected ? palette.accentSoft : palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onChanged(option.$2),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 82),
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? palette.accent : palette.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 32,
                              height: 30,
                              child: CustomPaint(
                                painter: AppearanceEffectPainter(
                                  effectKey: option.$2,
                                  color: selected
                                      ? palette.accent
                                      : palette.inkSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              option.$1,
                              textAlign: TextAlign.center,
                              style: SLSettingsText.caption(
                                selected ? palette.accent : palette.ink,
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
          }).toList(),
        );
      },
    );
  }
}

/// Hàng điều khiển nhẹ, không thêm một khung nữa bên trong mỗi nhóm.
class AppearanceToggleRow extends StatelessWidget {
  const AppearanceToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.accentColor,
    this.isDark,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? accentColor;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? SLSettingsPalette.isNightTheme;
    final palette = SLSettingsPalette.resolve(dark);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.textScalerOf(context).scale(14) < 22) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  icon,
                  color: palette.tint(accentColor ?? palette.accent),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: SLSettingsText.body(palette.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: SLSettingsText.caption(palette.inkSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              height: 48,
              child: SLSettingsSwitch(
                value: value,
                onChanged: onChanged,
                isDark: dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
