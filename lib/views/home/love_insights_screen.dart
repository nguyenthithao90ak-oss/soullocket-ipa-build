import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/services/love_insight_service.dart';
import '../../utils/services/offline_cache_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../core/sl_theme.dart';
import 'package:soullocket_app/views/home/widgets/love_insights/walking_sticker_overlay.dart';

part 'widgets/love_insights/insight_header_cards.dart';
part 'widgets/love_insights/insight_stats_grid.dart';
part 'widgets/love_insights/insight_interaction_card.dart';
part 'widgets/love_insights/insight_offline_contribution_cards.dart';
part 'widgets/love_insights/insight_mood_habit_cards.dart';
part 'widgets/love_insights/insight_timeline_section.dart';
part 'widgets/love_insights/insight_shared_widgets.dart';

class LoveInsightsScreen extends StatefulWidget {
  final String houseId;
  final String nameU1;
  final String nameU2;
  final int loveDays;
  final String relationshipMode;

  const LoveInsightsScreen({
    super.key,
    required this.houseId,
    required this.nameU1,
    required this.nameU2,
    required this.loveDays,
    required this.relationshipMode,
  });

  @override
  State<LoveInsightsScreen> createState() => _LoveInsightsScreenState();
}

class _LoveInsightsScreenState extends State<LoveInsightsScreen> {
  final LoveInsightService _insightService = LoveInsightService();

  LoveInsightData? _insight;
  bool _isLoading = true;
  String? _errorText;

  bool get _isSingle => widget.relationshipMode == 'single';
  double get _contentHorizontalPadding => 14;

  @override
  void initState() {
    super.initState();
    _loadInsight();
  }

  Future<void> _loadInsight() async {
    final cacheKey = 'love_insight_${widget.houseId}';
    final cachedData = OfflineCacheService.loadCacheSync(cacheKey);
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _insight =
              LoveInsightData.fromMap(Map<String, dynamic>.from(cachedData));
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final insight = await _insightService.computeInsights(
        widget.houseId,
        widget.relationshipMode,
      );

      OfflineCacheService.saveCache(cacheKey, insight.toMap());

      if (!mounted) return;
      setState(() {
        _insight = insight;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_insight == null) {
          _isLoading = false;
          _errorText = L10nService().translate('insight_error_load');
        } else {
          _isLoading =
              false; // keep showing cache if error occurs but cache exists
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF23192C),
        titleSpacing: 0,
        title: Text(
          _isSingle
              ? L10nService().translate('insight_title_single')
              : L10nService().translate('insight_title_couple'),
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF23192C),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFF0F5),
                    Color(0xFFFFE8F0),
                    Color(0xFFF3E5FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.1, 0.5, 0.9],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -50,
            child: _buildBackdropOrb(
              size: 220,
              colors: const [Color(0xFFFF94C2), Color(0xFFDCA3FF)],
            ),
          ),
          Positioned(
            left: -60,
            top: 150,
            child: _buildBackdropOrb(
              size: 180,
              colors: const [Color(0xFFFFB3CA), Color(0xFFFF9EB7)],
              delayItem: 1500,
            ),
          ),
          Positioned(
            right: -20,
            top: 400,
            child: _buildBackdropOrb(
              size: 140,
              colors: const [Color(0xFFE8B2FF), Color(0xFFFFD1E3)],
              delayItem: 800,
            ),
          ),
          SafeArea(
            top: false,
            child: _buildContent(),
          ),
          const WalkingStickerOverlay(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _insight == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD81B60)),
      );
    }

    if (_insight == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 42,
                color: const Color(0xFFD81B60).withValues(alpha: 0.8),
              ),
              SLSpacing.h12,
              Text(
                _errorText ?? L10nService().translate('insight_no_data'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF5A4656),
                ),
              ),
              SLSpacing.h16,
              FilledButton(
                onPressed: _loadInsight,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: SLRadius.lgAll,
                  ),
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

    final insight = _insight!;
    return RefreshIndicator(
      color: const Color(0xFFD81B60),
      onRefresh: _loadInsight,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          _contentHorizontalPadding,
          12,
          _contentHorizontalPadding,
          30,
        ),
        children: [
          _buildHeaderCard(insight),
          SLSpacing.h16,
          _buildDailyTipCard(insight),
          SLSpacing.h16,
          _buildStatsGrid(insight),
          SLSpacing.h16,
          _buildInteractionCard(insight),
          SLSpacing.h16,
          _buildOfflineCard(insight),
          SLSpacing.h16,
          if (_isSingle)
            _buildSingleFocusCard(insight)
          else
            _buildContributionCard(insight),
          SLSpacing.h16,
          _buildMoodHabitRow(insight),
          SLSpacing.h16,
          _buildAdvisorCard(insight),
          SLSpacing.h16,
          _buildTimelineSection(insight),
        ],
      ),
    );
  }

  Widget _buildBackdropOrb({
    required double size,
    required List<Color> colors,
    int delayItem = 0,
  }) {
    return _FloatingOrb(
      size: size,
      colors: colors,
      delayMilliseconds: delayItem,
    );
  }

  BoxDecoration _softCardDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(28),
      border:
          Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFCEBCD0).withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFFD81B60);
    if (score >= 70) return const Color(0xFFF57C00);
    if (score >= 55) return const Color(0xFF7B1FA2);
    return const Color(0xFF5C6BC0);
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

  String _offlineText(double value) {
    if (value <= 0) return L10nService().translate('insight_0_days');
    if (value < 1) return L10nService().translate('insight_less_than_1_day');
    return '${value.floor()} ${L10nService().translate('insight_days')}';
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

class _FloatingOrb extends StatefulWidget {
  final double size;
  final List<Color> colors;
  final int delayMilliseconds;

  const _FloatingOrb({
    required this.size,
    required this.colors,
    this.delayMilliseconds = 0,
  });

  @override
  State<_FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<_FloatingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Khởi tạo animation, thời gian bồng bềnh là 3-4s tuỳ random
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (widget.delayMilliseconds > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMilliseconds), () {
        if (mounted) _controller.repeat(reverse: true);
      });
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -20.0 * _animation.value),
          child: child,
        );
      },
      child: IgnorePointer(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.colors.first.withValues(alpha: 0.8),
                widget.colors.last.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
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
