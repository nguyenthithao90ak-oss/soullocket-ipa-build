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
        MediaQuery.paddingOf(context).top + 8,
        20,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF5E7E), Color(0xFFFF9E7A)],
                      ).createShader(bounds),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'UTILITIES HUB',
                          maxLines: 1,
                          softWrap: false,
                          style: SLTheme.quicksand(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5E7E), Color(0xFFFF9E7A)],
                        ),
                        borderRadius: BorderRadius.circular(999),
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
          SLSpacing.h20,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _UtilitiesHubSegmentButton(
                      label: context.tr('home_tinchchung_3e7d5e'),
                      active: currentSegment == 0,
                      onTap: () => onSegmentChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _UtilitiesHubSegmentButton(
                      label: context.tr('home_cngcthityu_872418'),
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
          child: Icon(
            icon,
            color: SLColors.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _UtilitiesHubSegmentButton extends StatelessWidget {
  const _UtilitiesHubSegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5E7E).withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: SLTheme.quicksand(
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            fontSize: 14.5,
            color: active
                ? SLColors.primary
                : SLColors.textPrimary.withValues(alpha: 0.55),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
