import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';

import 'utilities_hub_tile.dart';

/// Hàng tiện ích vừa mở, cuộn ngang.
class UtilitiesRecentRow extends StatelessWidget {
  const UtilitiesRecentRow({
    super.key,
    required this.apps,
    required this.pinnedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final List<UtilityApp> apps;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.tr('home_gny_a3ae09'),
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SLColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final app in apps)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: SizedBox(
                    width: 76,
                    child: _RecentItem(
                      app: app,
                      isPinned: pinnedIds.contains(app.id),
                      onTap: () => onTap(app),
                      onLongPress: () => onLongPress(app),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentItem extends StatelessWidget {
  const _RecentItem({
    required this.app,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
  });

  final UtilityApp app;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: utilityHubSemanticLabel(context, app, isPinned),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: SLColors.paper,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF522C49).withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: UtilityHubStickerWithBadge(
                  app: app,
                  size: 44,
                  isPinned: isPinned,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                app.localizedTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SLColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
