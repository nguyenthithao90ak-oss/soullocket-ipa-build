import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/love_insight_service.dart';
import '../../services/offline_cache_service.dart';
import '../../core/sl_theme.dart';

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
          _errorText = 'Chưa tải được phần phân tích yêu thương lúc này.';
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
          _isSingle ? 'Phân tích hoạt động' : 'Phân tích yêu thương',
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF23192C),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFF7FB),
                    const Color(0xFFFFEEF5).withValues(alpha: 0.95),
                    const Color(0xFFF9F1FF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: -30,
            child: _buildBackdropOrb(
              size: 170,
              colors: const [Color(0xFFFFB4D2), Color(0xFFE9C8FF)],
            ),
          ),
          Positioned(
            left: -34,
            top: 130,
            child: _buildBackdropOrb(
              size: 120,
              colors: const [Color(0xFFFFE0EA), Color(0xFFFFC4D8)],
              delayItem: 1500,
            ),
          ),
          SafeArea(
            top: false,
            child: _buildContent(),
          ),
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
                _errorText ?? 'Không có dữ liệu để hiển thị.',
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
                  'Tải lại',
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

  BoxDecoration _glassCardDecoration({
    required Color borderColor,
    required Color shadowColor,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.96),
          const Color(0xFFFFF2F7).withValues(alpha: 0.96),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  BoxDecoration _softCardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: SLRadius.xlAll,
      border: Border.all(color: borderColor ?? const Color(0xFFF2E7EE)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFCEBCD0).withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 10),
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
      if (score >= 90) return 'Rất rực rỡ';
      if (score >= 75) return 'Đang rất ổn';
      if (score >= 60) return 'Giữ nhịp tốt';
      if (score >= 45) return 'Cần ấm lên';
      return 'Nên chăm mình hơn';
    }

    if (score >= 90) return 'Soulmate rực rỡ';
    if (score >= 75) return 'Yêu sâu đậm';
    if (score >= 60) return 'Đang rất ổn';
    if (score >= 45) return 'Cần hâm nóng';
    return 'Nên chăm nhau hơn';
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
    if (value <= 0) return '0 ngày';
    if (value < 1) return '< 1 ngày';
    return '${value.floor()} ngày';
  }

  String _favoriteActivityLabel(LoveInsightData insight) {
    if (insight.diaryTotal > insight.albumTotal) return 'Viết nhật ký';
    if (insight.diaryTotal < insight.albumTotal) return 'Đăng ảnh/video';
    return 'Cân bằng cả hai';
  }

  String _positivityStatus(int value) {
    if (value >= 85) return 'Đang rất êm';
    if (value >= 70) return 'Khá tích cực';
    if (value >= 50) return 'Ổn định';
    return 'Nên hâm ấm lại';
  }

  String _dailyTip(LoveInsightData insight) {
    if (_isSingle) {
      if (insight.memoryThisMonth >= 8) {
        return 'Nhịp lưu giữ của bạn đang rất tốt. Cứ giữ đều nhật ký và album như hiện tại, bản đồ cảm xúc của bạn sẽ ngày càng rõ hơn.';
      }
      if (insight.positivity >= 70) {
        return 'Tinh thần của bạn đang khá sáng. Chỉ cần thêm vài kỷ niệm nhỏ mỗi tuần là chỉ số này sẽ lên rất nhanh.';
      }
      return 'Hôm nay chỉ cần viết một dòng ngắn hoặc lưu lại một ảnh bạn thích là đủ để nhịp hoạt động ấm lên rồi.';
    }

    if (insight.loveScore >= 85) {
      return 'Mối quan hệ của hai bạn đang phát triển rất đẹp. Một cử chỉ bất ngờ nhỏ hôm nay sẽ làm cảm xúc lên thêm một nấc.';
    }
    if (insight.positivity >= 70) {
      return 'Nhịp yêu đang ổn định. Hỏi han nhau thêm một lần thật lòng trong ngày sẽ giúp chỉ số này sáng lên rõ rệt.';
    }
    return 'Hai bạn đang cần thêm một chút chất lượng hơn số lượng. Một cuộc trò chuyện ngắn nhưng thật lòng sẽ hiệu quả hơn rất nhiều.';
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
          offset: Offset(0, -15.0 * _animation.value), // Lên xuống 15px
          child: child,
        );
      },
      child: IgnorePointer(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: widget.colors
                  .map((color) => color.withValues(alpha: 0.38))
                  .toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
