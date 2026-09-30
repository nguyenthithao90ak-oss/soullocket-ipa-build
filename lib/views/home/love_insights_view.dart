import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/love_insight_service.dart';
import 'widgets/insight_profile_avatar.dart';

part 'widgets/love_insights/insight_header_cards.dart';
part 'widgets/love_insights/insight_stats_grid.dart';
part 'widgets/love_insights/insight_offline_contribution_cards.dart';
part 'widgets/love_insights/insight_mood_habit_cards.dart';
part 'widgets/love_insights/insight_timeline_section.dart';
part 'widgets/love_insights/insight_shared_widgets.dart';

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
  });

  bool get _isSingle => relationshipMode == 'single';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF6F2),
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
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF492E3A),
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
            color: const Color(0xFF492E3A),
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4F87)),
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
                color: const Color(0xFFFF4F87).withValues(alpha: 0.8),
              ),
              SLSpacing.h12,
              Text(
                errorText ?? L10nService().translate('insight_no_data'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5A4656),
                ),
              ),
              SLSpacing.h16,
              FilledButton(
                onPressed: onRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4F87),
                  foregroundColor: Colors.white,
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
      color: const Color(0xFFFF4F87),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildHeaderCard(context, insight),
          SLSpacing.h16,
          _buildDailyTipCard(insight),
          SLSpacing.h16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              context.tr('insight_overview_title'),
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF492E3A),
              ),
            ),
          ),
          SLSpacing.h12,
          _buildStatsGrid(insight),
          SLSpacing.h16,
          if (!_isSingle) ...[_buildContributionCard(insight), SLSpacing.h20],
          _buildHabitCard(insight),
          SLSpacing.h20,
          _buildAdvisorCard(insight),
          SLSpacing.h20,
          _buildTimelineSection(insight),
        ],
      ),
    );
  }

  BoxDecoration _softCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFF0E5DF)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF492E3A).withValues(alpha: 0.035),
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
