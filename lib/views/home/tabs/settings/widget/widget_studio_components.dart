import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../widgets/sl_settings_kit.dart';
import 'widget_theme_surface.dart';

/// Khung giao diện dùng riêng cho trang tuỳ chỉnh widget.
///
/// Các thành phần ở đây chỉ lo phần trình bày để màn cài đặt vẫn giữ nguyên
/// luồng lưu dữ liệu và đồng bộ widget ở lớp cha.
class WidgetStudioPanel extends StatelessWidget {
  const WidgetStudioPanel({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.onBack,
    this.onClose,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLSettingsPageHeader(
            title: title,
            icon: Icons.widgets_outlined,
            iconColor: SLSettingsColors.teal,
            leading: leading,
            onBack: onBack,
            trailing: onClose == null
                ? null
                : IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    color: SLSettingsColors.inkSecondary,
                  ),
          ),
          child,
        ],
      ),
    );
  }
}

class WidgetStudioPreviewStage extends StatelessWidget {
  const WidgetStudioPreviewStage({
    super.key,
    required this.title,
    required this.themeName,
    required this.child,
  });

  final String title;
  final String themeName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SLSettingsCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLSettingsBlockHeading(
            title: title,
            icon: Icons.phone_android_rounded,
            iconColor: SLSettingsColors.teal,
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: SLSettingsPill(
                label: themeName,
                tone: SLSettingsTone.accent,
                dense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class WidgetStudioSection extends StatelessWidget {
  const WidgetStudioSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.leading,
    this.accent = SLSettingsColors.rose,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SLSettingsCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SLSettingsBlockHeading(
            title: title,
            subtitle: subtitle,
            icon: icon ?? Icons.tune_rounded,
            leading: leading,
            iconColor: accent,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class WidgetStudioTab {
  const WidgetStudioTab({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class WidgetStudioSegmentedControl extends StatelessWidget {
  const WidgetStudioSegmentedControl({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onChanged,
  });

  final List<WidgetStudioTab> items;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SLSettingsColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SLSettingsColors.border),
        ),
        child: Row(
          children: items
              .map((item) {
                final selected = item.id == selectedId;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(item.id),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? SLSettingsColors.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: SLSettingsColors.ink.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: selected
                                    ? SLSettingsColors.accent
                                    : SLSettingsColors.inkTertiary,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: selected
                                      ? SLSettingsColors.accentStrong
                                      : SLSettingsColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class WidgetStudioThemeOption {
  const WidgetStudioThemeOption({
    required this.id,
    required this.label,
    required this.colors,
    required this.icon,
  });

  final String id;
  final String label;
  final List<Color> colors;
  final IconData icon;
}

class WidgetStudioThemePicker extends StatelessWidget {
  const WidgetStudioThemePicker({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final List<WidgetStudioThemeOption> options;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 410 ? 5 : 4;
        const gap = 9.0;
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: options
              .map((option) {
                final selected = option.id == selectedId;
                return SizedBox(
                  width: itemWidth,
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: option.label,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(option.id),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: selected
                                ? option.colors.first.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? SLSettingsColors.accent
                                  : SLSettingsColors.border,
                              width: selected ? 1.7 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AspectRatio(
                                aspectRatio: 1.28,
                                child: WidgetThemeSurface(
                                  themeKey: option.id,
                                  colors: option.colors,
                                  radius: 11,
                                  child: Stack(
                                    children: [
                                      if (selected)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                            margin: const EdgeInsets.all(5),
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: SLSettingsColors.accent,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 27,
                                child: Center(
                                  child: Text(
                                    option.label,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SLTheme.quicksand(
                                      fontSize: 10.1,
                                      fontWeight: selected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: selected
                                          ? SLSettingsColors.accentStrong
                                          : SLSettingsColors.inkSecondary,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}
