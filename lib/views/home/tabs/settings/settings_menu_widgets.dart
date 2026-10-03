import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';

class SettingsMenuStyle {
  static const surface = Color(0xFFFFFAF3);
  static const border = Color(0xFFE8DDD0);
  static const ink = Color(0xFF45382F);
  static const secondary = Color(0xFF7A695D);
  static const tea = Color(0xFF92745C);
  static const sage = Color(0xFF648575);
  static const rose = Color(0xFFAC6A79);
  static const blue = Color(0xFF6B8798);
  static const lavender = Color(0xFF8D7D99);
  static const danger = Color(0xFFAC4E54);
  static const darkSurface = Color(0xFF27221F);
}

class SettingsMenuCard extends StatelessWidget {
  const SettingsMenuCard({
    super.key,
    required this.children,
    this.isDark = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  final List<Widget> children;
  final bool isDark;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x084F3827),
                  blurRadius: 18,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: isDark
            ? SettingsMenuStyle.darkSurface
            : SettingsMenuStyle.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF40362F) : SettingsMenuStyle.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class SettingsMenuHeading extends StatelessWidget {
  const SettingsMenuHeading({
    super.key,
    required this.title,
    this.isDark = false,
    this.topPadding = 20,
  });

  final String title;
  final bool isDark;
  final double topPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.fromSTEB(22, topPadding, 22, 8),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: SettingsMenuStyle.tea.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? const Color(0xFFE5D4C4)
                  : SettingsMenuStyle.secondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class SettingsMenuDivider extends StatelessWidget {
  const SettingsMenuDivider({super.key, this.isDark = false});

  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 74, end: 18),
    child: Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF39312B) : const Color(0xFFF0E7DC),
    ),
  );
}

class SettingsMenuTile extends StatelessWidget {
  const SettingsMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.accent = SettingsMenuStyle.tea,
    this.subtitle,
    this.isDark = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color accent;
  final String? subtitle;
  final bool isDark;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = isDestructive ? SettingsMenuStyle.danger : accent;
    final iconColor = isDark
        ? Color.lerp(effectiveAccent, const Color(0xFFFFF3E5), 0.35)!
        : effectiveAccent;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        splashColor: effectiveAccent.withValues(alpha: 0.08),
        highlightColor: effectiveAccent.withValues(alpha: 0.04),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: effectiveAccent.withValues(
                      alpha: isDark ? 0.18 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SLTheme.quicksand(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDestructive
                              ? iconColor
                              : isDark
                              ? const Color(0xFFF6EBDF)
                              : SettingsMenuStyle.ink,
                          height: 1.35,
                        ),
                      ),
                      if (subtitle?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFFC1AEA0)
                                : SettingsMenuStyle.secondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!isDestructive)
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                      color: isDark
                          ? const Color(0xFFAC9482)
                          : const Color(0xFFB6A28F),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
