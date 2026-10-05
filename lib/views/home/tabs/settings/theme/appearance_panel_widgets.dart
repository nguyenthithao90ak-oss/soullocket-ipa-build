import 'package:flutter/material.dart';

import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/sl_settings_kit.dart';

abstract final class AppearancePanelStyle {
  static const canvas = SLSettingsColors.canvas;
  static const paper = SLSettingsColors.surface;
  static const ink = SLSettingsColors.ink;
  static const muted = SLSettingsColors.inkSecondary;
  static const rose = SLSettingsColors.accentStrong;
  static const blush = SLSettingsColors.accentSoft;
  static const line = SLSettingsColors.border;
}

class AppearancePanelHeader extends StatelessWidget {
  const AppearancePanelHeader({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: SLSettingsPageHeader(
      title: context.tr('appearance_page_title'),
      description: context.tr('theme_preview_desc'),
      icon: Icons.palette_outlined,
      iconColor: SLSettingsColors.violet,
      onBack: onBack,
      backLabel: context.tr('p7_back'),
    ),
  );
}

/// Dùng cùng một bề mặt cho sáu nhóm; giữ state con khi đóng/mở.
class AppearanceSectionCard extends StatefulWidget {
  const AppearanceSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  State<AppearanceSectionCard> createState() => _AppearanceSectionCardState();
}

class _AppearanceSectionCardState extends State<AppearanceSectionCard> {
  bool _expanded = false;
  bool _opened = false;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: AppearancePanelStyle.paper,
      borderRadius: BorderRadius.circular(SLSettingsRadius.card),
      border: Border.all(
        color: _expanded
            ? SLSettingsColors.accent.withValues(alpha: 0.4)
            : AppearancePanelStyle.line,
      ),
      boxShadow: SLSettingsPalette.light.shadow,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(SLSettingsRadius.card),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          maintainState: true,
          onExpansionChanged: (value) => setState(() {
            _expanded = value;
            _opened = _opened || value;
          }),
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          shape: const Border(),
          collapsedShape: const Border(),
          minTileHeight: 72,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (MediaQuery.textScalerOf(context).scale(14) < 22) ...[
                SLSettingsIconTile(
                  icon: widget.icon,
                  color: _expanded
                      ? SLSettingsColors.accent
                      : SLSettingsColors.violet,
                  filled: _expanded,
                  size: 40,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: SLSettingsText.title(AppearancePanelStyle.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.description,
                      style: SLSettingsText.caption(AppearancePanelStyle.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: const Icon(
              Icons.expand_more_rounded,
              size: 22,
              color: SLSettingsColors.inkTertiary,
            ),
          ),
          children: [
            const Divider(height: 20, color: SLSettingsColors.divider),
            if (_opened) widget.child,
          ],
        ),
      ),
    ),
  );
}
