import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/utility_service.dart';
import '../../../utilities/utilities_config.dart';

/// Cache palette cho shortcut items — tránh lookup appConfig mỗi build.
final Map<String, _ShortcutPalette> _shortcutPaletteCache = {};

class _ShortcutPalette {
  final List<Color> colors;
  final IconData iconData;
  final Color iconColor;

  const _ShortcutPalette({
    required this.colors,
    required this.iconData,
    required this.iconColor,
  });
}

_ShortcutPalette _resolveShortcutPalette(UtilityApp app) {
  return _shortcutPaletteCache.putIfAbsent(app.id, () {
    final config = appConfig[app.id] ??
        {
          'icon': app.icon,
          'colors': app.colors,
        };
    return _ShortcutPalette(
      colors: List<Color>.from(config['colors'] as List),
      iconData: config['icon'] as IconData? ?? app.icon,
      iconColor: config['iconColor'] as Color? ?? SLColors.textInverse,
    );
  });
}

class UtilitiesHubShortcuts extends StatelessWidget {
  const UtilitiesHubShortcuts({
    super.key,
    required this.pinnedApps,
    required this.recentApps,
    required this.onShortcutTap,
  });

  final List<UtilityApp> pinnedApps;
  final List<UtilityApp> recentApps;
  final ValueChanged<String> onShortcutTap;

  @override
  Widget build(BuildContext context) {
    if (pinnedApps.isEmpty && recentApps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pinnedApps.isNotEmpty) ...[
          _ShortcutGroup(
            title: context.tr('home_ghim_4be667'),
            icon: Icons.push_pin_rounded,
            apps: pinnedApps,
            onTap: onShortcutTap,
            compact: false,
          ),
          const SizedBox(height: 10),
        ],
        if (recentApps.isNotEmpty)
          _ShortcutGroup(
            title: context.tr('home_gny_a3ae09'),
            icon: Icons.history_rounded,
            apps: recentApps,
            onTap: onShortcutTap,
            compact: true,
          ),
      ],
    );
  }
}

class _ShortcutGroup extends StatelessWidget {
  const _ShortcutGroup({
    required this.title,
    required this.icon,
    required this.apps,
    required this.onTap,
    required this.compact,
  });

  final String title;
  final IconData icon;
  final List<UtilityApp> apps;
  final ValueChanged<String> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: SLColors.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: SLColors.primary,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        compact
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: apps
                      .map(
                        (app) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ShortcutIconButton(
                            app: app,
                            onTap: () => onTap(app.id),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: apps
                    .map(
                      (app) => _ShortcutChip(
                        app: app,
                        onTap: () => onTap(app.id),
                      ),
                    )
                    .toList(growable: false),
              ),
      ],
    );
  }
}

class _ShortcutIconButton extends StatelessWidget {
  const _ShortcutIconButton({
    required this.app,
    required this.onTap,
  });

  final UtilityApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _resolveShortcutPalette(app);
    final colors = palette.colors;
    final iconData = palette.iconData;
    final iconColor = palette.iconColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Tooltip(
          message: app.localizedTitle,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(iconData, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.app,
    required this.onTap,
  });

  final UtilityApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _resolveShortcutPalette(app);
    final colors = palette.colors;
    final iconData = palette.iconData;
    final iconColor = palette.iconColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.first.withValues(alpha: 0.16),
                colors.last.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colors.last.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(iconData, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                app.localizedTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: SLColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
