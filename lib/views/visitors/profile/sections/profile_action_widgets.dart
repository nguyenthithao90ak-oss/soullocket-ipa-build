import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/l10n_service.dart';
import 'profile_section_models.dart';

class VisitorProfileAppBarActions extends StatelessWidget {
  final bool isMe;
  final bool isUpdatingProfileAppearance;
  final List<VisitorProfileMenuAction> menuActions;
  final VoidCallback onOpenAppearance;
  final ValueChanged<String> onSelected;

  const VisitorProfileAppBarActions({
    super.key,
    required this.isMe,
    required this.isUpdatingProfileAppearance,
    required this.menuActions,
    required this.onOpenAppearance,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isMe) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          tooltip: context.tr('p5_profile_customize_tooltip'),
          onPressed: isUpdatingProfileAppearance ? null : onOpenAppearance,
          icon: _ActionCircle(
            child: Icon(
              Icons.settings_rounded,
              color: isUpdatingProfileAppearance
                  ? Colors.white54
                  : Colors.white,
              size: 18,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        tooltip: context.tr('p5_profile_more_actions'),
        icon: const _ActionCircle(
          child: Icon(Icons.more_vert, color: Colors.white, size: 18),
        ),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
        onSelected: onSelected,
        itemBuilder: (_) => menuActions
            .map(
              (action) => PopupMenuItem<String>(
                value: action.value,
                enabled: action.enabled,
                child: Row(
                  children: [
                    Icon(action.icon, size: 16, color: action.iconColor),
                    SLSpacing.w8,
                    Text(
                      action.label,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        color: action.textColor ?? action.iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class VisitorProfileHeartButton extends StatelessWidget {
  final bool isDropping;
  final bool isHeartDroppedToday;
  final int heartCount;
  final Animation<double> heartScale;
  final VoidCallback onTap;

  const VisitorProfileHeartButton({
    super.key,
    required this.isDropping,
    required this.isHeartDroppedToday,
    required this.heartCount,
    required this.heartScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr('p5_profile_heart_action'),
      value: '$heartCount',
      enabled: !isDropping,
      child: GestureDetector(
        onTap: isDropping ? null : onTap,
        child: ScaleTransition(
          scale: heartScale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isHeartDroppedToday
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(SLRadius.pill),
              border: Border.all(
                color: isHeartDroppedToday
                    ? Colors.white24
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHeartDroppedToday
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isHeartDroppedToday
                      ? const Color(0xFFFF8FAF)
                      : Colors.white,
                  size: 18,
                ),
                SLSpacing.w8,
                Text(
                  '$heartCount',
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _ActionCircle extends StatelessWidget {
  final Widget child;

  const _ActionCircle({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: SLSpacing.all8,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}
