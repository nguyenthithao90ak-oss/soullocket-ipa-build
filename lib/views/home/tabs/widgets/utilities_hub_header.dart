import 'package:flutter/material.dart';

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
        MediaQuery.of(context).padding.top + 8,
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
                        colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                      ).createShader(bounds),
                      child: Text(
                        'UTILITIES HUB',
                        style: SLTheme.quicksand(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    SLSpacing.h4,
                    Container(
                      width: 100,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: SLRadius.pillAll,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                        ),
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
                      tooltip: 'Đặt lại',
                      onTap: onResetTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: SLSpacing.all4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: SLRadius.mdAll,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _UtilitiesHubSegmentButton(
                      label: 'Tiện ích chung',
                      active: currentSegment == 0,
                      onTap: () => onSegmentChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _UtilitiesHubSegmentButton(
                      label: 'Công cụ thiết yếu',
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
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: SLShadow.subtle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: SLRadius.smAll,
          boxShadow: active ? SLShadow.subtle : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: active ? SLColors.primary : SLColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
