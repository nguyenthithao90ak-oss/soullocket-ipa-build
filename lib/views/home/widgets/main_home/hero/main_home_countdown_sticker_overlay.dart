part of '../../../tabs/main_home_tab.dart';

/// Cụm charm bám viền thay cho bộ sticker rải rời rạc trước đây.
class _CountdownThemeStickerOverlay extends StatelessWidget {
  const _CountdownThemeStickerOverlay({
    required this.styleKey,
    required this.enableMotion,
  });

  final String styleKey;
  final bool enableMotion;

  @override
  Widget build(BuildContext context) => KeepsakeOrnaments(
    styleKey: styleKey,
    animate: enableMotion && !UiPrefs.notifier.value.liteMode,
  );
}
