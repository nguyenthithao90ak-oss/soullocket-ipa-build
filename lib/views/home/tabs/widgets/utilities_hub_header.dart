import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';

import '../../../../core/sl_theme.dart';
import '../../../../widgets/app_help_center.dart';
import 'utilities_category_section.dart';

/// Đầu trang thu gọn: tiêu đề trượt đi khi cuộn, hàng chủ đề luôn ghim lại.
class UtilitiesHubHeaderDelegate extends SliverPersistentHeaderDelegate {
  const UtilitiesHubHeaderDelegate({
    required this.topInset,
    required this.titleExtent,
    required this.chipsExtent,
    required this.title,
    required this.chips,
  });

  final double topInset;
  final double titleExtent;
  final double chipsExtent;
  final Widget title;
  final Widget chips;

  @override
  double get minExtent => topInset + chipsExtent;

  @override
  double get maxExtent => topInset + titleExtent + chipsExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / titleExtent).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SLColors.paperCanvas.withValues(alpha: progress),
        border: Border(
          bottom: BorderSide(
            color: SLColors.border.withValues(alpha: progress),
          ),
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: topInset - shrinkOffset,
              height: titleExtent,
              child: Opacity(opacity: 1 - progress, child: title),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: chipsExtent,
              child: chips,
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant UtilitiesHubHeaderDelegate oldDelegate) {
    return oldDelegate.topInset != topInset ||
        oldDelegate.titleExtent != titleExtent ||
        oldDelegate.chipsExtent != chipsExtent ||
        oldDelegate.title != title ||
        oldDelegate.chips != chips;
  }
}

class UtilitiesHubTitle extends StatelessWidget {
  const UtilitiesHubTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.tr('utilities_hub_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('utilities_hub_subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SLColors.textSecond,
                  ),
                ),
              ],
            ),
          ),
          const AppHelpButton(articleId: 'utilities', iconOnly: true),
        ],
      ),
    );
  }
}

/// Hàng nút chủ đề; `null` là "Tất cả".
class UtilitiesCategoryChips extends StatelessWidget {
  const UtilitiesCategoryChips({
    super.key,
    required this.categories,
    required this.active,
    required this.onSelected,
    required this.controller,
    required this.chipKeys,
  });

  final List<UtilityCategory> categories;
  final UtilityCategory? active;
  final ValueChanged<UtilityCategory?> onSelected;
  final ScrollController controller;
  final Map<UtilityCategory?, GlobalKey> chipKeys;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        _CategoryChip(
          key: chipKeys[null],
          label: context.tr('utilities_filter_all'),
          selected: active == null,
          onTap: () => onSelected(null),
        ),
        for (final category in categories)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: _CategoryChip(
              key: chipKeys[category],
              label: context.tr(utilityCategoryTitleKey(category)),
              selected: active == category,
              onTap: () => onSelected(category),
            ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: selected
          ? BorderSide.none
          : const BorderSide(color: SLColors.border),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? SLColors.textPrimary : SLColors.paper,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? SLColors.paper : SLColors.textMedium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
