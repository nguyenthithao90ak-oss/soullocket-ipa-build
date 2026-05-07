import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/services/export_service.dart';
import '../diary_tab_btn.dart';

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
                  'NHẬT KÝ RIÊNG TƯ',
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
                SLSpacing.h12,
                Text(
                  'Mở khóa để xem những tâm sự và kỷ niệm chỉ thuộc về hai bạn.',
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    color: SLColors.textSecondary,
                  ),
                ),
                SLSpacing.gapH(32),
                SLTheme.primaryButton(
                  text: 'MỞ KHÓA NGAY',
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
      padding: EdgeInsets.fromLTRB(
        10,
        MediaQuery.of(context).padding.top + 20,
        10,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [SLColors.primary, SLColors.secondary],
                ).createShader(bounds),
                child: Text(
                  'DIARY & MEMORIES',
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
                    colors: [SLColors.primary, SLColors.secondary],
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h20,
          DiaryTabSectionSwitcher(
            currentTab: currentTab,
            onTabChanged: onTabChanged,
          ),
        ],
      ),
    );
  }
}

class DiaryExportMenuButton extends StatelessWidget {
  final String? houseId;

  const DiaryExportMenuButton({
    super.key,
    required this.houseId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF7AA8),
            Color(0xFFFF5E92),
            Color(0xFF8ED08D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A9F).withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 1.2),
      ),
      child: IconButton(
        tooltip: 'Xuất HTML',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.ios_share_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () async {
          final resolvedHouseId = (houseId ?? '').trim();
          if (resolvedHouseId.isEmpty) {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chưa có mã nhà để xuất dữ liệu.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          try {
            await ExportService().exportDiary(
              houseId: resolvedHouseId,
              format: DiaryExportFormat.html,
            );
          } catch (error) {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Chưa thể xuất dữ liệu lúc này. Vui lòng thử lại.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
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

  List<Color> _paletteForSection(String id) {
    switch (id) {
      case 'memory':
        return const [Color(0xFF7C8BFF), Color(0xFF62C7B5)];
      case 'diary':
      default:
        return const [Color(0xFFFF6A9F), Color(0xFFD81B60)];
    }
  }

  Color _sectionAccent(String id) {
    switch (id) {
      case 'memory':
        return const Color(0xFF5C71D8);
      case 'diary':
      default:
        return const Color(0xFFD81B60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SLTheme.glassCard(
      margin: EdgeInsets.zero,
      padding: SLSpacing.all4,
      radius: 20,
      child: Row(
        children: [
          Expanded(
            child: DiaryTabBtn(
              id: 'memory',
              label: 'KỶ NIỆM',
              icon: Icons.photo_library_rounded,
              active: currentTab == 'memory',
              palette: _paletteForSection('memory'),
              accent: _sectionAccent('memory'),
              onTap: () {
                if (currentTab != 'memory') {
                  onTabChanged('memory');
                }
              },
            ),
          ),
          Expanded(
            child: DiaryTabBtn(
              id: 'diary',
              label: 'TÂM SỰ',
              icon: Icons.auto_awesome_rounded,
              active: currentTab == 'diary',
              palette: _paletteForSection('diary'),
              accent: _sectionAccent('diary'),
              onTap: () {
                if (currentTab != 'diary') {
                  onTabChanged('diary');
                }
              },
            ),
          ),
        ],
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
          color:
              const Color(0xFFFF73A6).withValues(alpha: strongShadow ? 0.18 : 0.11),
          blurRadius: strongShadow ? 28 : 18,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color:
              const Color(0xFF6BC6FF).withValues(alpha: strongShadow ? 0.12 : 0.08),
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
            label: const Text('Thử lại'),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: _softDiaryCard(
        color: Colors.white.withValues(alpha: 0.92),
        strongShadow: true,
        radius: 20,
      ),
      child: Column(
        children: [
          const Text('💌', style: TextStyle(fontSize: 42)),
          SLSpacing.h12,
          Text(
            'Chưa có tâm sự nào...',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFF6F7B90),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          SLSpacing.h8,
          Text(
            'Viết dòng cảm xúc đầu tiên của bạn ở khung phía trên nhé.',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: const Color(0xFF8A97A9),
              fontWeight: FontWeight.w700,
              height: 1.45,
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
    return Center(
      child: SLTheme.glassCard(
        margin: EdgeInsets.zero,
        radius: 0,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: SLColors.textTertiary.withValues(alpha: 0.3),
            ),
            SLSpacing.h24,
            Text(
              'Chưa có kỷ niệm nào',
              style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: SLColors.textPrimary,
              ),
            ),
            SLSpacing.h8,
            Text(
              'Bắt đầu lưu giữ khoảnh khắc đầu tiên của hai bạn.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12,
                color: SLColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiarySelectionBottomBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExit;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const DiarySelectionBottomBar({
    super.key,
    required this.selectedCount,
    required this.onExit,
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
          Row(
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
              const SizedBox(width: 8),
              Text(
                'Đã chọn $selectedCount ảnh',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: SLColors.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
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
                tooltip: 'Tạo liên kết',
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
