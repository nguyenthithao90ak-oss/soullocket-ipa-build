import 'package:flutter/material.dart';

import '../core/sl_theme.dart';
import 'sl_settings_kit.dart';

/// Token cho các trang chi tiết mở từ Cài đặt; dùng chung bảng màu
/// [SLSettingsColors] để mọi trang con nhìn đồng bộ.
class SLDetailStyle {
  static const canvas = SLSettingsColors.canvas;
  static const surface = SLSettingsColors.surface;
  static const border = SLSettingsColors.border;
  static const ink = SLSettingsColors.ink;
  static const secondary = SLSettingsColors.inkSecondary;
  static const primary = SLSettingsColors.accentStrong;
  static const sage = SLSettingsColors.success;
  static const rose = SLSettingsColors.rose;
  static const blue = SLSettingsColors.info;
  static const warning = SLSettingsColors.warning;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? SLSettingsColors.darkCanvas : canvas;

  static Color card(BuildContext context) =>
      isDark(context) ? SLSettingsColors.darkSurface : surface;

  static Color outline(BuildContext context) =>
      isDark(context) ? SLSettingsColors.darkBorder : border;

  static Color text(BuildContext context) =>
      isDark(context) ? SLSettingsColors.darkInk : ink;

  static Color muted(BuildContext context) =>
      isDark(context) ? SLSettingsColors.darkInkSecondary : secondary;

  static Color accent(BuildContext context, Color color) =>
      isDark(context) ? Color.lerp(color, surface, 0.35)! : color;
}

class SLDetailPageHeader extends StatelessWidget {
  const SLDetailPageHeader({
    super.key,
    required this.title,
    required this.icon,
    this.description,
    this.onBack,
    this.backLabel,
  });

  final String title;
  final String? description;
  final IconData icon;
  final VoidCallback? onBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) => SLSettingsPageHeader(
    title: title,
    description: description,
    icon: icon,
    iconColor: _iconColorFor(icon),
    onBack: onBack,
    backLabel: backLabel,
    isDark: SLDetailStyle.isDark(context),
  );

  /// Mỗi trang giữ một sắc nhận diện riêng, cùng bộ màu với danh sách Cài đặt.
  static Color _iconColorFor(IconData icon) {
    if (icon == Icons.notifications_none_rounded ||
        icon == Icons.notifications_rounded) {
      return SLSettingsColors.amber;
    }
    if (icon == Icons.cloud_sync_outlined || icon == Icons.cloud_rounded) {
      return SLSettingsColors.sky;
    }
    if (icon == Icons.history_rounded) return SLSettingsColors.slate;
    if (icon == Icons.support_agent_rounded) return SLSettingsColors.teal;
    if (icon == Icons.location_on_outlined) return SLSettingsColors.indigo;
    return SLSettingsColors.rose;
  }
}

class SLDetailIcon extends StatelessWidget {
  const SLDetailIcon({
    super.key,
    required this.icon,
    this.color = SLDetailStyle.primary,
    this.size = 36,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SLSettingsIconTile(
    icon: icon,
    color: color,
    size: size,
    filled: false,
    isDark: SLDetailStyle.isDark(context),
  );
}

class SLDetailCard extends StatelessWidget {
  const SLDetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(SLDetailStyle.isDark(context));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SLSettingsRadius.card),
        boxShadow: palette.shadow,
      ),
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SLSettingsRadius.card),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SLDetailHeading extends StatelessWidget {
  const SLDetailHeading({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.color = SLDetailStyle.primary,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color color;

  @override
  Widget build(BuildContext context) => SLSettingsBlockHeading(
    icon: icon,
    title: title,
    subtitle: description,
    iconColor: color,
    isDark: SLDetailStyle.isDark(context),
  );
}

class SLDetailButton extends StatelessWidget {
  const SLDetailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => SLSettingsButton(
    icon: icon,
    label: label,
    onPressed: onPressed,
    isDark: SLDetailStyle.isDark(context),
    variant: primary
        ? SLSettingsButtonVariant.primary
        : SLSettingsButtonVariant.secondary,
  );
}

class SLDetailToggle extends StatelessWidget {
  const SLDetailToggle({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.onTap,
    this.ignoreDirectSwitchTap = false,
    this.color = SLDetailStyle.primary,
  });

  final IconData icon;
  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;
  final bool ignoreDirectSwitchTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = SLDetailStyle.isDark(context);
    final palette = SLSettingsPalette.resolve(isDark);
    final toggle = SLSettingsSwitch(
      value: value,
      onChanged: onChanged,
      isDark: isDark,
    );
    return Semantics(
      label: ignoreDirectSwitchTap ? title : null,
      toggled: ignoreDirectSwitchTap ? value : null,
      button: ignoreDirectSwitchTap ? true : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: description == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              SLSettingsIconTile(
                icon: icon,
                color: color,
                size: 34,
                filled: false,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SLSettingsText.title(palette.ink)),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        style: SLSettingsText.caption(palette.inkSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (ignoreDirectSwitchTap)
                ExcludeSemantics(child: IgnorePointer(child: toggle))
              else
                Semantics(label: title, child: toggle),
            ],
          ),
        ),
      ),
    );
  }
}

class SLDetailStatusRow extends StatelessWidget {
  const SLDetailStatusRow({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    this.ready = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool ready;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = SLDetailStyle.isDark(context);
    final palette = SLSettingsPalette.resolve(isDark);
    final badge = SLSettingsPill(
      label: status,
      tone: ready ? SLSettingsTone.success : SLSettingsTone.warning,
      isDark: isDark,
      dense: true,
    );
    final label = Text(title, style: SLSettingsText.body(palette.ink));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inline =
                  constraints.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(13) < 18;
              return Row(
                children: [
                  Icon(icon, color: palette.inkSecondary, size: 19),
                  const SizedBox(width: 10),
                  if (inline) ...[
                    Expanded(flex: 3, child: label),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: badge,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [label, const SizedBox(height: 5), badge],
                      ),
                    ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.inkTertiary,
                      size: 20,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class SLDetailDisclosure extends StatelessWidget {
  const SLDetailDisclosure({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.description,
    this.color = SLDetailStyle.primary,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(SLDetailStyle.isDark(context));
    return SLDetailCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: palette.inkSecondary,
        collapsedIconColor: palette.inkTertiary,
        leading: SLDetailIcon(icon: icon, color: color, size: 34),
        title: Text(title, style: SLSettingsText.title(palette.ink)),
        subtitle: description == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  description!,
                  style: SLSettingsText.caption(palette.inkSecondary),
                ),
              ),
        children: [child],
      ),
    );
  }
}

class SLDetailChoice extends StatelessWidget {
  const SLDetailChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.badge,
    this.warning,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final String? warning;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    button: true,
    child: Material(
      color: selected ? SLSettingsColors.accentSoft : SLSettingsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SLSettingsRadius.card),
        side: BorderSide(
          color: selected
              ? SLSettingsColors.accent.withValues(alpha: 0.6)
              : SLSettingsColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SLSettingsIconTile(
                    icon: icon,
                    color: selected
                        ? SLSettingsColors.accent
                        : SLSettingsColors.slate,
                    filled: selected,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: SLSettingsText.title(SLSettingsColors.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? SLSettingsColors.accent
                        : SLSettingsColors.inkTertiary,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    if (badge != null)
                      TextSpan(
                        text: '$badge · ',
                        style: const TextStyle(
                          color: SLSettingsColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    TextSpan(text: description),
                  ],
                ),
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  color: SLSettingsColors.inkSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (warning != null) ...[
                const SizedBox(height: 12),
                SLSettingsNotice(
                  tone: SLSettingsTone.warning,
                  icon: Icons.battery_alert_outlined,
                  message: warning!,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
