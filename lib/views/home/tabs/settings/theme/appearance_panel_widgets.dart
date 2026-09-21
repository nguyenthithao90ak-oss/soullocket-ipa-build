import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/services/l10n_service.dart';

abstract final class AppearancePanelStyle {
  static const canvas = Color(0xFFFAF6F4);
  static const paper = Color(0xFFFFFDFC);
  static const ink = Color(0xFF46363D);
  static const muted = Color(0xFF82727A);
  static const rose = Color(0xFFAA5E79);
  static const blush = Color(0xFFF7E9EE);
  static const line = Color(0xFFEDE2E5);
}

class AppearancePanelHeader extends StatelessWidget {
  const AppearancePanelHeader({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton.filledTonal(
            onPressed: onBack,
            tooltip: context.tr('p7_back'),
            style: IconButton.styleFrom(
              backgroundColor: AppearancePanelStyle.paper,
              foregroundColor: AppearancePanelStyle.ink,
              side: const BorderSide(color: AppearancePanelStyle.line),
              minimumSize: const Size(48, 48),
            ),
            icon: const BackButtonIcon(),
          ),
          const SizedBox(height: 18),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                context.tr('appearance_page_title'),
                style: SLTheme.quicksand(
                  fontSize: MediaQuery.sizeOf(context).width < 360 ? 24 : 29,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: AppearancePanelStyle.ink,
                ),
              ),
            ),
            if (MediaQuery.textScalerOf(context).scale(14) < 22) ...[
              const SizedBox(width: 16),
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppearancePanelStyle.blush,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    size: 29,
                    color: AppearancePanelStyle.rose,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('theme_preview_desc'),
          style: SLTheme.quicksand(
            fontSize: 13,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: AppearancePanelStyle.muted,
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: _expanded
            ? AppearancePanelStyle.rose.withValues(alpha: 0.45)
            : AppearancePanelStyle.line,
      ),
      boxShadow: [
        BoxShadow(
          color: AppearancePanelStyle.ink.withValues(alpha: 0.025),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          maintainState: true,
          onExpansionChanged: (value) => setState(() {
            _expanded = value;
            _opened = _opened || value;
          }),
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: const Border(),
          collapsedShape: const Border(),
          minTileHeight: 76,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.textScalerOf(context).scale(14) < 22) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppearancePanelStyle.blush,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 21,
                    color: AppearancePanelStyle.rose,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: AppearancePanelStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.description,
                      style: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: AppearancePanelStyle.muted,
                      ),
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
              size: 20,
              color: AppearancePanelStyle.muted,
            ),
          ),
          children: [
            const Divider(height: 24, color: AppearancePanelStyle.line),
            if (_opened) widget.child,
          ],
        ),
      ),
    ),
  );
}
