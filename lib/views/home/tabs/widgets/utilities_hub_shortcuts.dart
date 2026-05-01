import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/utility_service.dart';
import '../../../utilities/utilities_config.dart';

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
            title: 'Đã ghim',
            icon: Icons.push_pin_rounded,
            apps: pinnedApps,
            onTap: onShortcutTap,
            compact: false,
          ),
          const SizedBox(height: 10),
        ],
        if (recentApps.isNotEmpty)
          _ShortcutGroup(
            title: 'Gần đây',
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
            Icon(icon, size: 15, color: const Color(0xFFD81B60)),
            const SizedBox(width: 6),
            Text(
              title,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD81B60),
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
    final config = appConfig[app.id] ??
        {
          'icon': app.icon,
          'colors': app.colors,
        };
    final colors = List<Color>.from(config['colors'] as List);
    final iconData = config['icon'] as IconData? ?? app.icon;
    final iconColor = config['iconColor'] as Color? ?? Colors.white;

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
                  color: colors.first.withOpacity(0.16),
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
    final config = appConfig[app.id] ??
        {
          'icon': app.icon,
          'colors': app.colors,
        };
    final colors = List<Color>.from(config['colors'] as List);
    final iconData = config['icon'] as IconData? ?? app.icon;
    final iconColor = config['iconColor'] as Color? ?? Colors.white;

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
                colors.first.withOpacity(0.16),
                colors.last.withOpacity(0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colors.last.withOpacity(0.18),
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
                      color: colors.first.withOpacity(0.18),
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
                  color: const Color(0xFF5A2A3F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
