import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import 'profile_section_models.dart';

class VisitorProfileTabBarSection extends StatelessWidget {
  final String activeTab;
  final List<VisitorProfileTabItem> items;
  final ValueChanged<String> onSelected;

  const VisitorProfileTabBarSection({
    super.key,
    required this.activeTab,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: SLColors.borderLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: _VisitorProfileTabButton(
                  item: item,
                  isActive: activeTab == item.id,
                  onTap: () => onSelected(item.id),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VisitorProfileTabButton extends StatelessWidget {
  final VisitorProfileTabItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _VisitorProfileTabButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? SLColors.bgCard : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isActive ? SLShadow.sm : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isActive ? SLColors.primary : SLColors.textTertiary,
            ),
            if (isActive) ...[
              SLSpacing.w4,
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: SLColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
