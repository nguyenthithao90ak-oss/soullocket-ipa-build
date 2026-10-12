import 'dart:math' as math;

import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/love_insight_service.dart';
import 'widgets/insight_profile_avatar.dart';
import '../../widgets/utility_vip_badge.dart';

part 'widgets/love_insights/insight_header_cards.dart';
part 'widgets/love_insights/insight_stats_grid.dart';
part 'widgets/love_insights/insight_offline_contribution_cards.dart';
part 'widgets/love_insights/insight_mood_habit_cards.dart';
part 'widgets/love_insights/insight_timeline_section.dart';
part 'widgets/love_insights/insight_shared_widgets.dart';
part 'widgets/love_insights/insight_companion_art.dart';

/// Giữ màu pastel ở light, dùng token chung cho độ tương phản ở dark.
abstract final class _InsightStyle {
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color canvas(BuildContext context) =>
      dark(context) ? SLColors.darkBgMain : const Color(0xFFFFFAF7);
  static Color surface(BuildContext context) =>
      dark(context) ? SLColors.darkBgCard : Colors.white;
  static Color ink(BuildContext context) =>
      dark(context) ? SLColors.darkTextPrimary : const Color(0xFF492E3A);
  static Color muted(BuildContext context) =>
      dark(context) ? SLColors.darkTextSecond : const Color(0xFF806C73);
  static Color line(BuildContext context) =>
      dark(context) ? SLColors.darkBorder : const Color(0xFFF0E5DF);
  static Color accent(BuildContext context, Color light) => dark(context)
      ? Color.lerp(light, SLColors.darkTextPrimary, 0.55)!
      : light;
  static Color wash(BuildContext context, Color light) =>
      dark(context) ? Color.lerp(SLColors.darkBgCard, light, 0.08)! : light;
}

class LoveInsightsView extends StatelessWidget {
  final LoveInsightData? data;
  final bool isLoading;
  final String? errorText;
  final Future<void> Function() onRefresh;
  final String nameU1;
  final String nameU2;
  final String avatarU1;
  final String avatarU2;
  final int loveDays;
  final String relationshipMode;
  // Báo cáo nâng cao (lời khuyên, dòng thời gian) dành cho PRO.
  final bool isPro;
  final VoidCallback? onUpgrade;

  const LoveInsightsView({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.nameU1,
    required this.nameU2,
    required this.avatarU1,
    required this.avatarU2,
    required this.loveDays,
    required this.relationshipMode,
    this.isLoading = false,
    this.errorText,
    this.isPro = true,
    this.onUpgrade,
  });

  bool get _isSingle => relationshipMode == 'single';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _InsightStyle.canvas(context),
      appBar: AppBar(
        backgroundColor: _InsightStyle.canvas(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 28
            ? 96
            : 72,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16),
          child: Center(
            child: IconButton.filledTonal(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              style: IconButton.styleFrom(
                backgroundColor: _InsightStyle.surface(context),
                foregroundColor: _InsightStyle.ink(context),
                minimumSize: const Size(48, 48),
              ),
              icon: const BackButtonIcon(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        titleSpacing: 12,
        title: Text(
          context.tr(
            _isSingle ? 'insight_title_single' : 'insight_title_couple',
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _InsightStyle.ink(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading && data == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('loading'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(color: _InsightStyle.muted(context)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (data == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 42,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.8),
              ),
              SLSpacing.h12,
              Text(
                errorText ?? L10nService().translate('insight_no_data'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _InsightStyle.ink(context),
                ),
              ),
              SLSpacing.h16,
              FilledButton(
                onPressed: onRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                ),
                child: Text(
                  L10nService().translate('insight_reload'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final insight = data!;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildHeaderCard(context, insight),
          SLSpacing.h16,
          _buildDailyTipCard(context, insight),
          SLSpacing.h16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              context.tr('insight_overview_title'),
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _InsightStyle.ink(context),
              ),
            ),
          ),
          SLSpacing.h12,
          _buildStatsGrid(context, insight),
          SLSpacing.h16,
          if (!_isSingle) ...[
            _buildContributionCard(context, insight),
            SLSpacing.h20,
          ],
          _buildHabitCard(context, insight),
          SLSpacing.h20,
          if (isPro) ...[
            _buildAdvisorCard(context, insight),
            SLSpacing.h20,
            _buildTimelineSection(context, insight),
          ] else
            _buildProReportCard(context),
        ],
      ),
    );
  }

  Widget _buildProReportCard(BuildContext context) {
    return Container(
      key: const ValueKey('insight-pro-report'),
      padding: const EdgeInsets.all(20),
      decoration: _softCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('pro_insights_title'),
                  style: SLTheme.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _InsightStyle.ink(context),
                  ),
                ),
              ),
              const UtilityVipBadge(compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('pro_insights_desc'),
            style: SLTheme.quicksand(
              fontSize: 13.5,
              height: 1.45,
              color: _InsightStyle.ink(context).withValues(alpha: 0.72),
            ),
          ),
          if (onUpgrade != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('insight-pro-upgrade'),
              onPressed: onUpgrade,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(context.tr('p6_upgrade_vip')),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _softCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: _InsightStyle.surface(context),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _InsightStyle.line(context)),
      boxShadow: [
        BoxShadow(
          color: _InsightStyle.ink(context).withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _levelLabel(int score) {
    if (_isSingle) {
      if (score >= 90) return L10nService().translate('insight_single_90');
      if (score >= 75) return L10nService().translate('insight_single_75');
      if (score >= 60) return L10nService().translate('insight_single_60');
      if (score >= 45) return L10nService().translate('insight_single_45');
      return L10nService().translate('insight_single_low');
    }

    if (score >= 90) return L10nService().translate('insight_couple_90');
    if (score >= 75) return L10nService().translate('insight_couple_75');
    if (score >= 60) return L10nService().translate('insight_couple_60');
    if (score >= 45) return L10nService().translate('insight_couple_45');
    return L10nService().translate('insight_couple_low');
  }

  double _progressToNextLevel(int score) {
    final nextLevel = score >= 90
        ? 100
        : score >= 75
        ? 90
        : score >= 60
        ? 75
        : score >= 45
        ? 60
        : 45;
    final base = nextLevel - 15;
    final progress = ((score - base) / 15) * 100;
    return progress.clamp(5, 100).toDouble();
  }

  String _favoriteActivityLabel(LoveInsightData insight) {
    if (insight.diaryTotal > insight.albumTotal) {
      return L10nService().translate('insight_habit_diary');
    }
    if (insight.diaryTotal < insight.albumTotal) {
      return L10nService().translate('insight_habit_album');
    }
    return L10nService().translate('insight_habit_balance');
  }

  String _positivityStatus(int value) {
    if (value >= 85) return L10nService().translate('insight_habit_status_85');
    if (value >= 70) return L10nService().translate('insight_habit_status_70');
    if (value >= 50) return L10nService().translate('insight_habit_status_50');
    return L10nService().translate('insight_habit_status_low');
  }

  String _dailyTip(LoveInsightData insight) {
    if (_isSingle) {
      if (insight.memoryThisMonth >= 8) {
        return L10nService().translate('insight_advice_single_high');
      }
      if (insight.positivity >= 70) {
        return L10nService().translate('insight_advice_single_mid');
      }
      return L10nService().translate('insight_advice_single_low');
    }

    if (insight.loveScore >= 85) {
      return L10nService().translate('insight_advice_couple_high');
    }
    if (insight.positivity >= 70) {
      return L10nService().translate('insight_advice_couple_mid');
    }
    return L10nService().translate('insight_advice_couple_low');
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });
}
