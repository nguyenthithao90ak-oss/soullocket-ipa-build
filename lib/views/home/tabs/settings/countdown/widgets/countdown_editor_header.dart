// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension HeaderEditorExt on _CountdownModeEditorScreenState {
  List<Widget> _buildEditorHeader(
    BuildContext context,
    _CountdownModeThemeData themeData,
  ) {
    return [
      Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(15),
              child: Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: themeData.isDark ? 0.14 : 0.82,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: themeData.isDark ? 0.22 : 0.94,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: themeData.foreground,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('home_citkhnggia_09f866'),
                  style: SLTheme.textStyleForKey(
                    'dancingScript',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: themeData.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('home_bccytngtmc_c1f7aa'),
                  style: SLTheme.quicksand(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    color: themeData.foreground.withValues(
                      alpha: themeData.isDark ? 0.78 : 0.72,
                    ),
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }
}
