import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import 'anniversary_panel.dart';
import 'theme_background_actions.dart';
import 'theme_preview_builder.dart';

class ThemePanel extends StatelessWidget {
  const ThemePanel({
    super.key,
    required this.themeControls,
    required this.preview,
    this.anniversaryPanel,
    this.backgroundActions,
    this.footer,
    this.title = 'Giao diện & Widget',
    this.subtitle =
        'Panel shell-ready: owner có thể cắm controller/save logic mà không phải giữ hết UI trong settings shell.',
  });

  final Widget themeControls;
  final ThemePreviewBuilder preview;
  final AnniversaryPanel? anniversaryPanel;
  final ThemeBackgroundActions? backgroundActions;
  final Widget? footer;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      themeControls,
      if (anniversaryPanel != null) anniversaryPanel!,
      preview,
      if (backgroundActions != null) backgroundActions!,
      if (footer != null) footer!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFBFD), Color(0xFFFDF7FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF7D2E2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF231926).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF796A74),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: List<Widget>.generate(sections.length, (index) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index == sections.length - 1 ? 0 : 12),
                child: sections[index],
              );
            }),
          ),
        ],
      ),
    );
  }
}
