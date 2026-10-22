import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';

/// Palette của hub dùng cùng token với các màn Cài đặt/Home.
class SingleMatchHubPalette {
  const SingleMatchHubPalette(this.dark);

  factory SingleMatchHubPalette.of(BuildContext context) =>
      SingleMatchHubPalette(Theme.of(context).brightness == Brightness.dark);

  final bool dark;

  Color get canvas => dark ? SLColors.darkBgMain : SLColors.paperCanvas;
  Color get surface => dark ? SLColors.darkBgCard : SLColors.paper;
  Color get soft => dark ? SLColors.darkBgElevated : SLColors.paperBlush;
  Color get border => dark ? SLColors.darkBorder : SLColors.border;
  Color get ink => dark ? SLColors.darkTextPrimary : SLColors.ink;
  Color get muted => dark ? SLColors.darkTextSecond : SLColors.textSecond;
  Color get accent => dark ? SLColors.accentPink : SLColors.primary;
  Color get action => dark ? SLColors.accentPink : SLColors.ink;
  Color get onAction => dark ? SLColors.darkBgMain : SLColors.textInverse;
}

/// TabBarView dùng duration của controller để chuyển trang, kể cả khi animateTo
/// được gọi với duration riêng. Cả thanh tab và trang dùng cùng cấu hình này.
TabController createSingleMatchHubTabController({
  required TickerProvider vsync,
  required bool reducedMotion,
  int initialIndex = 0,
}) => TabController(
  length: 3,
  initialIndex: initialIndex,
  animationDuration: reducedMotion
      ? Duration.zero
      : const Duration(milliseconds: 240),
  vsync: vsync,
);

/// Ba tab giữ cùng TabController, tự xuống dòng và có vùng chạm tối thiểu 48dp.
class SingleMatchHubTabs extends StatelessWidget {
  const SingleMatchHubTabs({
    super.key,
    required this.controller,
    required this.labels,
  }) : assert(labels.length == 3);

  final TabController controller;
  final List<String> labels;

  static const _icons = [
    Icons.explore_rounded,
    Icons.chat_bubble_rounded,
    Icons.call_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = SingleMatchHubPalette.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(labels.length, (index) {
                final selected = controller.index == index;
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    child: TextButton(
                      key: ValueKey('single-match-tab-$index'),
                      onPressed: () => controller.animateTo(index),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        foregroundColor: selected ? palette.ink : palette.muted,
                        backgroundColor: selected
                            ? palette.soft
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                        animationDuration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ExcludeSemantics(
                            child: Icon(_icons[index], size: 19),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            labels[index],
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
