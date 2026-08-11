import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/sl_theme.dart';

class DiaryAccessLockedView extends StatelessWidget {
  final VoidCallback onUnlock;

  const DiaryAccessLockedView({
    super.key,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: SLTheme.meshPattern()),
        Center(
          child: SLTheme.glassCard(
            padding: const EdgeInsets.all(32),
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
                    color: SLColors.textPrimary,
                  ),
                ),
                SLSpacing.h12,
                Text(
                  context.tr('home_mkhaxemnhn_77ff5c'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    color: SLColors.textSecondary,
                  ),
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: DiaryTabSectionSwitcher(
              currentTab: currentTab,
              onTabChanged: onTabChanged,
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _DiarySegmentBtn(
                label: context.tr('home_knim_262759'),
                active: currentTab == 'memory',
                activeColor: const Color(0xFF5C71D8),
                activeShadowColor: const Color(0xFF7C8BFF),
                onTap: () {
                  if (currentTab != 'memory') onTabChanged('memory');
                },
              ),
            ),
            Expanded(
              child: _DiarySegmentBtn(
                label: context.tr('home_tms_f029b6'),
                active: currentTab == 'diary',
                activeColor: const Color(0xFFD81B60),
                activeShadowColor: const Color(0xFFFF6A9F),
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
  final bool active;
  final Color activeColor;
  final Color activeShadowColor;
  final VoidCallback onTap;

  const _DiarySegmentBtn({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.activeShadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Colors.white, Color(0xFFF8FAFC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: activeShadowColor.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: SLTheme.quicksand(
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14.0,
            color: active
                ? activeColor
                : const Color(0xFF718096),
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
          color: const Color(0xFFFF73A6)
              .withValues(alpha: strongShadow ? 0.18 : 0.11),
          blurRadius: strongShadow ? 28 : 18,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: const Color(0xFF6BC6FF)
              .withValues(alpha: strongShadow ? 0.12 : 0.08),
          blurRadius: strongShadow ? 22 : 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: _softDiaryCard(
        color: Colors.white.withValues(alpha: 0.96),
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
              color: const Color(0xFF5F6F83),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          SLSpacing.h8,
          Text(
            message,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFF7C8AA0),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: SLRadius.mdAll,
              ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x52FFFFFF), width: 1.4),
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
              color: const Color(0xFF6F7B90),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          SLSpacing.h4,
          Text(
            context.tr('home_vitdngcmxc_6ac761'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFF8A97A9),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class DiaryMemoryEmptyStateCard extends StatelessWidget {
  const DiaryMemoryEmptyStateCard({super.key});

  @override
  Widget build(BuildContext context) {
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
              color: SLColors.textPrimary,
            ),
          ),
          SLSpacing.h4,
          Text(
            context.tr('home_btulugikho_acb3de'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 12,
              color: SLColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.92),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: SLColors.textPrimary,
                  ),
                  iconSize: 22,
                  onPressed: onExit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    L10nService().format(
                      'diary_selected_photos_count',
                      {'count': selectedCount},
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: SLColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.select_all_rounded,
                  color: Color(0xFF38A169),
                ),
                tooltip: context.tr('util_chnttc_2969f7'),
                iconSize: 22,
                onPressed: onSelectAll,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.download_rounded,
                  color: SLColors.primary,
                ),
                iconSize: 22,
                onPressed: onSave,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.link_rounded,
                  color: Color(0xFF5C71D8),
                ),
                tooltip: context.tr('home_tolinkt_af40c0'),
                iconSize: 22,
                onPressed: onShare,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
                iconSize: 22,
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
