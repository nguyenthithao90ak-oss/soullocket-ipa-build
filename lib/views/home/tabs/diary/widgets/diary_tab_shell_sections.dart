import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/getting_started_guide.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/sl_theme.dart';
import 'diary_album_style.dart';

class DiaryAccessLockedView extends StatelessWidget {
  final VoidCallback onUnlock;

  const DiaryAccessLockedView({super.key, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: colors.isDark
              ? ColoredBox(color: colors.canvas)
              : SLTheme.meshPattern(),
        ),
        Center(
          child: SLTheme.glassCard(
            padding: const EdgeInsets.all(32),
            color: colors.isDark ? colors.paper : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: SLColors.primary,
                ),
                SLSpacing.h24,
                Text(
                  context.tr('home_nhtkringt_e0cba8'),
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: colors.ink,
                  ),
                ),
                SLSpacing.h12,
                Text(
                  context.tr('home_mkhaxemnhn_77ff5c'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(fontSize: 14, color: colors.muted),
                ),
                SLSpacing.gapH(32),
                SLTheme.primaryButton(
                  text: context.tr('home_mkhangay_0a4b1a'),
                  onPressed: onUnlock,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DiaryHeaderSection extends StatelessWidget {
  final String currentTab;
  final ValueChanged<String> onTabChanged;
  final String? houseId;

  const DiaryHeaderSection({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.houseId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: DiaryTabSectionSwitcher(
              currentTab: currentTab,
              onTabChanged: onTabChanged,
            ),
          ),
          IconButton(
            tooltip: context.tr('starter_memory_title'),
            onPressed: () =>
                showGettingStartedArticle(context, GettingStartedTopic.memory),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class DiaryTabSectionSwitcher extends StatelessWidget {
  final String currentTab;
  final ValueChanged<String> onTabChanged;

  const DiaryTabSectionSwitcher({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.inset,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: _DiarySegmentBtn(
                label: context.tr('home_knim_262759'),
                icon: Icons.photo_library_rounded,
                active: currentTab == 'memory',
                onTap: () {
                  if (currentTab != 'memory') onTabChanged('memory');
                },
              ),
            ),
            Expanded(
              child: _DiarySegmentBtn(
                label: context.tr('home_tms_f029b6'),
                icon: Icons.auto_stories_rounded,
                active: currentTab == 'diary',
                onTap: () {
                  if (currentTab != 'diary') onTabChanged('diary');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiarySegmentBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _DiarySegmentBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    return Semantics(
      selected: active,
      child: Material(
        color: active ? colors.paper : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? colors.rose : colors.muted,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                        color: active ? colors.ink : colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiaryHouseSetupCard extends StatelessWidget {
  final String title;
  final String message;
  final Future<void> Function() onRetry;

  const DiaryHouseSetupCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  BoxDecoration _softDiaryCard({
    Color color = const Color(0xFFFDFDFE),
    Color borderColor = const Color(0x52FFFFFF),
    double radius = 24,
    bool strongShadow = false,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.4),
      boxShadow: [
        BoxShadow(
          color: const Color(
            0xFFFF73A6,
          ).withValues(alpha: strongShadow ? 0.18 : 0.11),
          blurRadius: strongShadow ? 28 : 18,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: const Color(
            0xFF6BC6FF,
          ).withValues(alpha: strongShadow ? 0.12 : 0.08),
          blurRadius: strongShadow ? 22 : 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: _softDiaryCard(
        color: colors.paper,
        borderColor: colors.line,
        strongShadow: true,
        radius: 20,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            size: 44,
            color: Color(0xFFD81B60),
          ),
          SLSpacing.h12,
          Text(
            title,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: colors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          SLSpacing.h8,
          Text(
            message,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: colors.muted,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          SLSpacing.h16,
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('home_thli_4dffdf')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD81B60),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
            ),
          ),
        ],
      ),
    );
  }
}

class DiaryPostsEmptyStateCard extends StatelessWidget {
  const DiaryPostsEmptyStateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF73A6).withValues(alpha: 0.11),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Lottie.asset(
            'assets/images/empty_diary_sticker.json',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
            options: LottieOptions(enableMergePaths: true),
          ),
          SLSpacing.h8,
          Text(
            context.tr('home_chactmsno_a4ad4d'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: colors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          SLSpacing.h4,
          Text(
            context.tr('home_vitdngcmxc_6ac761'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: colors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const GettingStartedHelpButton(topic: GettingStartedTopic.memory),
        ],
      ),
    );
  }
}

class DiaryMemoryEmptyStateCard extends StatelessWidget {
  const DiaryMemoryEmptyStateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DiaryAlbumPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🖼️', style: TextStyle(fontSize: 36)),
          SLSpacing.h16,
          Text(
            context.tr('home_chacknimno_c1df72'),
            style: SLTheme.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: colors.ink,
            ),
          ),
          SLSpacing.h4,
          Text(
            context.tr('home_btulugikho_acb3de'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              color: colors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const GettingStartedHelpButton(topic: GettingStartedTopic.memory),
        ],
      ),
    );
  }
}

class DiarySelectionBottomBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExit;
  final VoidCallback onSelectAll;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const DiarySelectionBottomBar({
    super.key,
    required this.selectedCount,
    required this.onExit,
    required this.onSelectAll,
    required this.onSave,
    required this.onShare,
    required this.onDelete,
  });

  /// Chừa đúng chiều cao thanh chọn khi nhãn dài hoặc người dùng tăng cỡ chữ.
  static double heightFor(BuildContext context, double width, int count) {
    final layout = _DiarySelectionLayout.forWidth(context, width, count);
    final rows = 4 ~/ layout.columns;
    return 26 +
        layout.headerHeight +
        12 +
        rows * layout.buttonHeight +
        (rows - 1) * 8;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF5ECE9) : DiaryAlbumStyle.ink;
    final rose = dark ? const Color(0xFFE5A9B8) : DiaryAlbumStyle.rose;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _DiarySelectionLayout.forWidth(
          context,
          constraints.maxWidth,
          selectedCount,
        );
        return Container(
          key: const ValueKey('diary-selection-surface'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF292326) : DiaryAlbumStyle.paper,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: dark ? const Color(0xFF4C3B41) : const Color(0xFFEADDE0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF633443,
                ).withValues(alpha: dark ? .2 : .14),
                blurRadius: 28,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: layout.headerHeight,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rose.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.check_rounded, color: rose, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        L10nService().format('diary_selected_photos_count', {
                          'count': selectedCount,
                        }),
                        style: _DiarySelectionLayout.headerStyle().copyWith(
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey('diary-selection-exit'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: onExit,
                      style: IconButton.styleFrom(
                        backgroundColor: ink.withValues(alpha: .04),
                        foregroundColor: ink.withValues(alpha: .72),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DiarySelectionAction(
                    actionKey: 'diary-selection-all',
                    icon: Icons.select_all_rounded,
                    label: context.tr(_diarySelectionLabelKeys[0]),
                    foreground: dark
                        ? const Color(0xFFB6CBBB)
                        : const Color(0xFF587364),
                    background: dark
                        ? const Color(0xFF344139)
                        : const Color(0xFFEEF3EE),
                    layout: layout,
                    onPressed: onSelectAll,
                  ),
                  _DiarySelectionAction(
                    actionKey: 'diary-selection-save',
                    icon: Icons.file_download_outlined,
                    label: context.tr(_diarySelectionLabelKeys[1]),
                    foreground: dark ? const Color(0xFF30232A) : Colors.white,
                    background: rose,
                    layout: layout,
                    onPressed: onSave,
                  ),
                  _DiarySelectionAction(
                    actionKey: 'diary-selection-share',
                    icon: Icons.link_rounded,
                    label: context.tr(_diarySelectionLabelKeys[2]),
                    foreground: dark
                        ? const Color(0xFFC6B9DF)
                        : const Color(0xFF79638B),
                    background: dark
                        ? const Color(0xFF3A3045)
                        : const Color(0xFFF2EDF7),
                    layout: layout,
                    onPressed: onShare,
                  ),
                  _DiarySelectionAction(
                    actionKey: 'diary-selection-delete',
                    icon: Icons.delete_outline_rounded,
                    label: context.tr(_diarySelectionLabelKeys[3]),
                    foreground: dark
                        ? const Color(0xFFF2B3AD)
                        : const Color(0xFFA74950),
                    background: dark
                        ? const Color(0xFF483035)
                        : const Color(0xFFFBEFEE),
                    layout: layout,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

const _diarySelectionLabelKeys = [
  'util_chnttc_2969f7',
  'ui_utilities_save_to_device_2562f6',
  'home_tolinkt_af40c0',
  'p3_delete',
];

class _DiarySelectionLayout {
  const _DiarySelectionLayout({
    required this.columns,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.headerHeight,
  });
  final int columns;
  final double buttonWidth, buttonHeight, headerHeight;

  static TextStyle labelStyle() => SLTheme.quicksand(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    height: 1.35,
    letterSpacing: 0,
  );

  static TextStyle headerStyle() => SLTheme.quicksand(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.35,
    letterSpacing: 0,
  );

  factory _DiarySelectionLayout.forWidth(
    BuildContext context,
    double width,
    int count,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final innerWidth = (width - 26).clamp(1.0, double.infinity);
    final fourColumnWidth = (innerWidth - 24) / 4;
    var columns = fourColumnWidth < 64 ? 2 : 4;
    final labels = _diarySelectionLabelKeys.map(context.tr).toList();
    if (columns == 4) {
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: labelStyle()),
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 2,
        )..layout(maxWidth: fourColumnWidth - 12);
        final tooLong = painter.didExceedMaxLines;
        painter.dispose();
        if (tooLong) {
          columns = 2;
          break;
        }
      }
    }
    final buttonWidth = (innerWidth - (columns - 1) * 8) / columns;
    var labelHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle()),
        textDirection: direction,
        textScaler: textScaler,
      )..layout(maxWidth: (buttonWidth - 12).clamp(1.0, double.infinity));
      if (painter.height > labelHeight) labelHeight = painter.height;
      painter.dispose();
    }
    final header = TextPainter(
      text: TextSpan(
        text: L10nService().format('diary_selected_photos_count', {
          'count': count,
        }),
        style: headerStyle(),
      ),
      textDirection: direction,
      textScaler: textScaler,
    )..layout(maxWidth: (innerWidth - 102).clamp(1.0, double.infinity));
    final headerHeight = header.height < 48 ? 48.0 : header.height;
    header.dispose();
    return _DiarySelectionLayout(
      columns: columns,
      buttonWidth: buttonWidth,
      buttonHeight: (labelHeight + 50).clamp(72.0, double.infinity),
      headerHeight: headerHeight,
    );
  }
}

class _DiarySelectionAction extends StatelessWidget {
  const _DiarySelectionAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.layout,
    required this.onPressed,
  });
  final String actionKey, label;
  final IconData icon;
  final Color foreground, background;
  final _DiarySelectionLayout layout;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: layout.buttonWidth,
    height: layout.buttonHeight,
    child: TextButton(
      key: ValueKey(actionKey),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        minimumSize: const Size(48, 48),
        foregroundColor: foreground,
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        visualDensity: VisualDensity.standard,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: _DiarySelectionLayout.labelStyle().copyWith(
              color: foreground,
            ),
          ),
        ],
      ),
    ),
  );
}
