import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';

import 'utilities_hub_tile.dart';

String utilityCategoryTitleKey(UtilityCategory category) {
  switch (category) {
    case UtilityCategory.memories:
      return 'utilities_category_memories';
    case UtilityCategory.together:
      return 'utilities_category_together';
    case UtilityCategory.care:
      return 'utilities_category_care';
    case UtilityCategory.fun:
      return 'utilities_category_fun';
    case UtilityCategory.other:
      return 'utilities_category_other';
  }
}

/// Mô tả ngắn cho các ô lớn, thẻ và hàng danh sách.
const Map<String, String> _kUtilityDescriptionKeys = <String, String>{
  'calendar': 'utilities_desc_calendar',
  'habit': 'utilities_desc_habit',
  'health': 'utilities_desc_health',
  'sleep_tracker': 'utilities_desc_sleep',
  'vault': 'utilities_desc_vault',
  'diary_export': 'utilities_desc_diary_export',
  'store': 'utilities_desc_store',
  'giftcode': 'utilities_desc_giftcode',
};

String? _descriptionFor(BuildContext context, UtilityApp app) {
  final key = _kUtilityDescriptionKeys[app.id];
  return key == null ? null : context.tr(key);
}

class _CategoryPalette {
  const _CategoryPalette({
    required this.surface,
    required this.pill,
    required this.pillText,
    required this.muted,
    this.innerSurface = SLColors.paper,
  });

  final Color surface;
  final Color pill;
  final Color pillText;
  final Color muted;
  final Color innerSurface;
}

_CategoryPalette _paletteFor(UtilityCategory category) {
  switch (category) {
    case UtilityCategory.memories:
      return const _CategoryPalette(
        surface: Color(0xFFFFEDEF),
        pill: Color(0xFFFFE4E9),
        pillText: Color(0xFFA82E48),
        muted: SLColors.textSecond,
      );
    case UtilityCategory.together:
      return const _CategoryPalette(
        surface: Color(0xFFFFE9D7),
        pill: Color(0xFFFFE2CC),
        pillText: Color(0xFF8A4B1F),
        muted: SLColors.textSecond,
        innerSurface: Color(0xFFFFF7F0),
      );
    case UtilityCategory.care:
      return const _CategoryPalette(
        surface: Color(0xFFE4F3EC),
        pill: Color(0xFFD5EDE2),
        pillText: Color(0xFF2F6B52),
        muted: Color(0xFF4F6B5E),
      );
    case UtilityCategory.fun:
      return const _CategoryPalette(
        surface: Color(0xFFEFE7FB),
        pill: Color(0xFFE3D6F8),
        pillText: Color(0xFF5B3E99),
        muted: Color(0xFF5A4A78),
      );
    case UtilityCategory.other:
      return const _CategoryPalette(
        surface: SLColors.paper,
        pill: Color(0xFFF3E9DF),
        pillText: SLColors.textMedium,
        muted: SLColors.textSecond,
      );
  }
}

/// Một nhóm tiện ích; mỗi nhóm có kiểu bố cục riêng để trang không đơn điệu.
class UtilitiesCategorySection extends StatelessWidget {
  const UtilitiesCategorySection({
    super.key,
    required this.category,
    required this.apps,
    required this.pinnedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final UtilityCategory category;
  final List<UtilityApp> apps;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: context.tr(utilityCategoryTitleKey(category)),
          count: apps.length,
          palette: palette,
        ),
        const SizedBox(height: 10),
        _buildBody(palette),
      ],
    );
  }

  Widget _buildBody(_CategoryPalette palette) {
    switch (category) {
      case UtilityCategory.memories:
        return _GridDrawer(
          apps: apps,
          palette: palette,
          baseColumns: 4,
          stickerSize: 56,
          pinnedIds: pinnedIds,
          onTap: onTap,
          onLongPress: onLongPress,
        );
      case UtilityCategory.together:
        if (apps.length < 3) {
          return _GridDrawer(
            apps: apps,
            palette: palette,
            baseColumns: 4,
            stickerSize: 56,
            pinnedIds: pinnedIds,
            onTap: onTap,
            onLongPress: onLongPress,
          );
        }
        return _BentoDrawer(
          apps: apps,
          palette: palette,
          pinnedIds: pinnedIds,
          onTap: onTap,
          onLongPress: onLongPress,
        );
      case UtilityCategory.care:
        return _CardGrid(
          apps: apps,
          palette: palette,
          pinnedIds: pinnedIds,
          onTap: onTap,
          onLongPress: onLongPress,
        );
      case UtilityCategory.fun:
        return _GridDrawer(
          apps: apps,
          palette: palette,
          baseColumns: 3,
          stickerSize: 64,
          labelFontSize: 13,
          pinnedIds: pinnedIds,
          onTap: onTap,
          onLongPress: onLongPress,
        );
      case UtilityCategory.other:
        return _ListCard(
          apps: apps,
          palette: palette,
          pinnedIds: pinnedIds,
          onTap: onTap,
          onLongPress: onLongPress,
        );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.palette,
  });

  final String title;
  final int count;
  final _CategoryPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SLColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: palette.pill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.pillText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lưới sticker trên nền màu của nhóm.
class _GridDrawer extends StatelessWidget {
  const _GridDrawer({
    required this.apps,
    required this.palette,
    required this.baseColumns,
    required this.stickerSize,
    required this.pinnedIds,
    required this.onTap,
    required this.onLongPress,
    this.labelFontSize = 12,
  });

  final List<UtilityApp> apps;
  final _CategoryPalette palette;
  final int baseColumns;
  final double stickerSize;
  final double labelFontSize;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: _TileWrap(
          apps: apps,
          baseColumns: baseColumns,
          stickerSize: stickerSize,
          labelFontSize: labelFontSize,
          pinnedIds: pinnedIds,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}

class _TileWrap extends StatelessWidget {
  const _TileWrap({
    required this.apps,
    required this.baseColumns,
    required this.stickerSize,
    required this.labelFontSize,
    required this.pinnedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final List<UtilityApp> apps;
  final int baseColumns;
  final double stickerSize;
  final double labelFontSize;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560
            ? baseColumns + 2
            : baseColumns;
        final itemWidth = constraints.maxWidth / columns;
        return Wrap(
          runSpacing: 12,
          children: [
            for (final app in apps)
              SizedBox(
                width: itemWidth,
                child: UtilitiesHubTile(
                  app: app,
                  stickerSize: stickerSize,
                  labelFontSize: labelFontSize,
                  isPinned: pinnedIds.contains(app.id),
                  onTap: () => onTap(app),
                  onLongPress: () => onLongPress(app),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Một ô lớn bên trái và tối đa bốn ô nhỏ bên phải.
class _BentoDrawer extends StatelessWidget {
  const _BentoDrawer({
    required this.apps,
    required this.palette,
    required this.pinnedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final List<UtilityApp> apps;
  final _CategoryPalette palette;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  Widget _smallTile(UtilityApp? app) {
    if (app == null) return const SizedBox.shrink();
    return UtilitiesHubTile(
      app: app,
      stickerSize: 52,
      isPinned: pinnedIds.contains(app.id),
      onTap: () => onTap(app),
      onLongPress: () => onLongPress(app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feature = apps.first;
    final small = apps.skip(1).take(4).toList(growable: false);
    final extras = apps.skip(5).toList(growable: false);
    UtilityApp? smallAt(int index) =>
        index < small.length ? small[index] : null;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _FeatureTile(
                      app: feature,
                      palette: palette,
                      isPinned: pinnedIds.contains(feature.id),
                      onTap: () => onTap(feature),
                      onLongPress: () => onLongPress(feature),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _smallTile(smallAt(0))),
                            const SizedBox(width: 4),
                            Expanded(child: _smallTile(smallAt(1))),
                          ],
                        ),
                        if (small.length > 2) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _smallTile(smallAt(2))),
                              const SizedBox(width: 4),
                              Expanded(child: _smallTile(smallAt(3))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (extras.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TileWrap(
                apps: extras,
                baseColumns: 4,
                stickerSize: 52,
                labelFontSize: 12,
                pinnedIds: pinnedIds,
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.app,
    required this.palette,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
  });

  final UtilityApp app;
  final _CategoryPalette palette;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final description = _descriptionFor(context, app);
    return Semantics(
      button: true,
      label: utilityHubSemanticLabel(context, app, isPinned),
      excludeSemantics: true,
      child: Material(
        color: palette.innerSurface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                UtilityHubStickerWithBadge(
                  app: app,
                  size: 76,
                  isPinned: isPinned,
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.localizedTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ đứng có mô tả, ba thẻ mỗi hàng và cao bằng nhau.
class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.apps,
    required this.palette,
    required this.pinnedIds,
    required this.onTap,
    required this.onLongPress,
  });

  static const int _columns = 3;

  final List<UtilityApp> apps;
  final _CategoryPalette palette;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    final rows = <List<UtilityApp>>[
      for (var start = 0; start < apps.length; start += _columns)
        apps.sublist(
          start,
          start + _columns > apps.length ? apps.length : start + _columns,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          if (rowIndex > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < _columns; column++) ...[
                  if (column > 0) const SizedBox(width: 10),
                  Expanded(
                    child: column < rows[rowIndex].length
                        ? _InfoCard(
                            app: rows[rowIndex][column],
                            palette: palette,
                            isPinned: pinnedIds.contains(
                              rows[rowIndex][column].id,
                            ),
                            onTap: onTap,
                            onLongPress: onLongPress,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.app,
    required this.palette,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
  });

  final UtilityApp app;
  final _CategoryPalette palette;
  final bool isPinned;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    final description = _descriptionFor(context, app);
    return Semantics(
      button: true,
      label: utilityHubSemanticLabel(context, app, isPinned),
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(app),
          onLongPress: () => onLongPress(app),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            // Chữ dồn xuống đáy để các thẻ cao bằng nhau vẫn gọn.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                UtilityHubStickerWithBadge(
                  app: app,
                  size: 52,
                  isPinned: isPinned,
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.localizedTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Danh sách hàng ngang cho các công cụ ít dùng.
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.apps,
    required this.palette,
    required this.pinnedIds,
    required this.onTap,
    required this.onLongPress,
  });

  final List<UtilityApp> apps;
  final _CategoryPalette palette;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < apps.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.only(left: 68),
                child: Container(height: 1, color: SLColors.borderLight),
              ),
            _ListRow(
              app: apps[index],
              palette: palette,
              isPinned: pinnedIds.contains(apps[index].id),
              onTap: onTap,
              onLongPress: onLongPress,
            ),
          ],
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.app,
    required this.palette,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
  });

  final UtilityApp app;
  final _CategoryPalette palette;
  final bool isPinned;
  final ValueChanged<UtilityApp> onTap;
  final ValueChanged<UtilityApp> onLongPress;

  @override
  Widget build(BuildContext context) {
    final description = _descriptionFor(context, app);
    return Semantics(
      button: true,
      label: utilityHubSemanticLabel(context, app, isPinned),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(app),
        onLongPress: () => onLongPress(app),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                UtilityHubStickerWithBadge(
                  app: app,
                  size: 42,
                  isPinned: isPinned,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        app.localizedTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textPrimary,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.muted,
                  textDirection: Directionality.of(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
