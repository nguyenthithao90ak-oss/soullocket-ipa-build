import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../../../core/sl_theme.dart';

class UtilitiesHubHeader extends StatelessWidget {
  const UtilitiesHubHeader({
    super.key,
    required this.currentSegment,
    required this.onSegmentChanged,
    required this.onResetTap,
  });

  final int currentSegment;
  final ValueChanged<int> onSegmentChanged;
  final VoidCallback onResetTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 12,
        20,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [SLColors.primary, SLColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: SLShadow.subtle,
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('utilities_hub_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('utilities_hub_subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _UtilitiesHubHeaderAction(
                      icon: Icons.restart_alt_rounded,
                      tooltip: context.tr('home_tli_ffd7c4'),
                      onTap: onResetTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: SLColors.paper.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(22),
                boxShadow: SLShadow.subtle,
                border: Border.all(color: SLColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _UtilitiesHubSegmentButton(
                      label: context.tr('home_tinchchung_3e7d5e'),
                      icon: Icons.favorite_rounded,
                      active: currentSegment == 0,
                      onTap: () => onSegmentChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _UtilitiesHubSegmentButton(
                      label: context.tr('home_cngcthityu_872418'),
                      icon: Icons.handyman_rounded,
                      active: currentSegment == 1,
                      onTap: () => onSegmentChanged(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilitiesHubHeaderAction extends StatelessWidget {
  const _UtilitiesHubHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SLColors.bgElevated.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: SLShadow.subtle,
            border: Border.all(
              color: SLColors.bgElevated.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(icon, color: SLColors.primary, size: 20),
        ),
      ),
    );
  }
}

class _UtilitiesHubSegmentButton extends StatelessWidget {
  const _UtilitiesHubSegmentButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [SLColors.primary, SLColors.secondary],
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: SLColors.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? Colors.white : SLColors.textMuted,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 13.5,
                  color: active ? Colors.white : SLColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
