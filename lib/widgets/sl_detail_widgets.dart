import 'package:flutter/material.dart';

import '../core/sl_theme.dart';

class SLDetailStyle {
  static const canvas = Color(0xFFF5EFE6);
  static const surface = Color(0xFFFFFAF3);
  static const border = Color(0xFFE8DDD0);
  static const ink = Color(0xFF45382F);
  static const secondary = Color(0xFF7A695D);
  static const primary = Color(0xFF72543F);
  static const sage = Color(0xFF587564);
  static const rose = Color(0xFF9D6372);
  static const blue = Color(0xFF587589);
  static const warning = Color(0xFF906536);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF1F1B18) : canvas;

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF29231F) : surface;

  static Color outline(BuildContext context) =>
      isDark(context) ? const Color(0xFF483D33) : border;

  static Color text(BuildContext context) =>
      isDark(context) ? const Color(0xFFF6EADC) : ink;

  static Color muted(BuildContext context) =>
      isDark(context) ? const Color(0xFFC3B3A3) : secondary;

  static Color accent(BuildContext context, Color color) =>
      isDark(context) ? Color.lerp(color, surface, 0.45)! : color;
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                onPressed: onBack,
                tooltip: backLabel,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: SLDetailStyle.text(context),
                  backgroundColor: SLDetailStyle.card(context),
                  side: BorderSide(color: SLDetailStyle.outline(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const BackButtonIcon(),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: SLDetailStyle.text(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SLDetailIcon(icon: icon),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 12),
          Text(
            description!,
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: SLDetailStyle.muted(context),
            ),
          ),
        ],
      ],
    ),
  );
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
  Widget build(BuildContext context) {
    final accent = SLDetailStyle.accent(context, color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: accent, size: size * 0.5),
    );
  }
}

class SLDetailCard extends StatelessWidget {
  const SLDetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: SLDetailStyle.card(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: SLDetailStyle.outline(context)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SLDetailIcon(icon: icon, color: color),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: SLTheme.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: SLDetailStyle.text(context),
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: SLDetailStyle.muted(context),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
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
  Widget build(BuildContext context) {
    final color = primary ? Colors.white : SLDetailStyle.text(context);
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          backgroundColor: primary
              ? SLDetailStyle.primary
              : SLDetailStyle.card(context),
          foregroundColor: color,
          disabledBackgroundColor: SLDetailStyle.outline(context),
          disabledForegroundColor: SLDetailStyle.muted(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final toggle = Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: SLDetailStyle.primary,
      activeThumbColor: Colors.white,
      inactiveTrackColor: SLDetailStyle.outline(context),
      inactiveThumbColor: SLDetailStyle.muted(context),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    return Semantics(
      label: ignoreDirectSwitchTap ? title : null,
      toggled: ignoreDirectSwitchTap ? value : null,
      button: ignoreDirectSwitchTap ? true : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SLDetailIcon(icon: icon, color: color, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: SLDetailStyle.text(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (ignoreDirectSwitchTap)
                    ExcludeSemantics(child: IgnorePointer(child: toggle))
                  else
                    Semantics(label: title, child: toggle),
                ],
              ),
              if (description != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 42,
                    bottom: 4,
                  ),
                  child: Text(
                    description!,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: SLDetailStyle.muted(context),
                    ),
                  ),
                ),
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
    final accent = SLDetailStyle.accent(
      context,
      ready ? SLDetailStyle.sage : SLDetailStyle.warning,
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: SLTheme.quicksand(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: accent,
          height: 1.35,
        ),
      ),
    );
    final label = Text(
      title,
      style: SLTheme.quicksand(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: SLDetailStyle.text(context),
        height: 1.4,
      ),
    );
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
                  Icon(icon, color: SLDetailStyle.muted(context), size: 19),
                  const SizedBox(width: 10),
                  if (inline) ...[
                    Expanded(flex: 3, child: label),
                    const SizedBox(width: 8),
                    Flexible(flex: 2, child: badge),
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
                      color: SLDetailStyle.muted(context),
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
  Widget build(BuildContext context) => SLDetailCard(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: SLDetailStyle.muted(context),
      collapsedIconColor: SLDetailStyle.muted(context),
      leading: SLDetailIcon(icon: icon, color: color, size: 32),
      title: Text(
        title,
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: SLDetailStyle.text(context),
          height: 1.4,
        ),
      ),
      subtitle: description == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description!,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: SLDetailStyle.muted(context),
                  height: 1.45,
                ),
              ),
            ),
      children: [child],
    ),
  );
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
      color: selected ? const Color(0xFFF2E8DA) : SLDetailStyle.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? SLDetailStyle.primary : SLDetailStyle.border,
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
                  SLDetailIcon(icon: icon, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: SLTheme.quicksand(
                        color: SLDetailStyle.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? SLDetailStyle.primary
                        : SLDetailStyle.secondary,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    if (badge != null)
                      TextSpan(
                        text: '$badge · ',
                        style: const TextStyle(
                          color: SLDetailStyle.sage,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    TextSpan(text: description),
                  ],
                ),
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  color: SLDetailStyle.secondary,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (warning != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.battery_alert_outlined,
                      color: SLDetailStyle.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning!,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          color: SLDetailStyle.warning,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
