part of '../../main_home_tab.dart';

extension _MainHomeTabStatusCards on _MainHomeTabState {
  Widget _buildHomeCardFirstTapWrapper({
    required Widget child,
    required bool showHint,
    required Future<void> Function() onTap,
    double radius = 24,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(onTap()),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (showHint)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        context.tr('home_nvo_b99c83'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatInsightUpdatedAtText(int updatedAt) {
    if (updatedAt <= 0) {
      return context.tr('home_cpnhtgnnht_af26d6');
    }

    final now = DateTime.now();
    final updated = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    final diff = now.difference(updated);

    if (diff.inMinutes < 1) {
      return context.tr('home_cpnhtgnnht_d75b69');
    }
    if (diff.inHours < 1) {
      return 'Cập nhật gần nhất ${diff.inMinutes} phút trước';
    }
    if (diff.inDays < 1) {
      return 'Cập nhật gần nhất ${diff.inHours} giờ trước';
    }
    return 'Cập nhật gần nhất ${diff.inDays} ngày trước';
  }

  Widget _buildModernHighlightCard(
      {required String? startDate, required bool isSingle}) {
    final title = _buildCountdownText(isSingle: isSingle, startDate: startDate);
    final photoCount = _highlightItems.length;
    return SLTheme.glassCard(
      margin: EdgeInsets.zero,
      padding: SLSpacing.all20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD7E6), Color(0xFFFFEEF5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: SLColors.primary,
                  size: 20,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_khonhkhcni_903ef3'),
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF263242),
                      ),
                    ),
                    Text(
                      context.tr('home_nhngiungtn_061ab5'),
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: SLColors.primary,
              height: 1.4,
            ),
          ),
          if (photoCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Tháng này đã lưu $photoCount khoảnh khắc bằng ảnh',
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SLColors.textSecondary,
              ),
            ),
          ],
          SLSpacing.h16,
          if (_highlightItems.isEmpty)
            _buildHighlightEmptyState()
          else
            RepaintBoundary(
              child: _buildHighlightPhotoScatter(),
            ),
        ],
      ),
    );
  }

  Widget _buildModernMapCard({required String nameU1, required String nameU2}) {
    final isSingle = _isSingleRelationship;
    return _buildHomeCardFirstTapWrapper(
      showHint: _showMapCardFirstTapHint,
      onTap: _handleMapCardTap,
      child: SLTheme.glassCard(
        margin: EdgeInsets.zero,
        padding: SLSpacing.all16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDDF5FF), Color(0xFFF0FAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.map_rounded,
                    color: SLColors.secondary,
                    size: 22,
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSingle ? context.tr('home_vtrhinti_f5956d') : context.tr('home_bncahaia_12dcb1'),
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: SLColors.secondary,
                        ),
                      ),
                      Text(
                        isSingle
                            ? context.tr('home_xemvtrhint_58d61b')
                            : context.tr('home_xemkhongcc_53f9b9'),
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: SLColors.secondary.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _homeDistanceText,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4B5B6E),
                        height: 1.4,
                      ),
                    ),
                  ),
                  SLSpacing.w12,
                  Text(
                    context.tr('home_mngay_02e4c1'),
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: SLColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInsightCard({
    required bool isSingle,
    required String nameU1,
    required String nameU2,
  }) {
    final insight = _insightData;
    final metrics = insight == null
        ? const <_InsightBubbleSpec>[]
        : [
            if (!isSingle)
              _InsightBubbleSpec(
                label: nameU1.trim(),
                value: insight.loveU1,
                color: SLColors.secondary,
                phase: 0.2,
              ),
            _InsightBubbleSpec(
              label: isSingle ? 'LEVEL' : 'LOVE',
              value: insight.loveScore,
              color: SLColors.primary,
              phase: 1.4,
              emphasize: true,
            ),
            if (!isSingle)
              _InsightBubbleSpec(
                label: nameU2.trim(),
                value: insight.loveU2,
                color: const Color(0xFF7B7FF6),
                phase: 2.5,
              ),
          ];

    return _buildHomeCardFirstTapWrapper(
      showHint: _showInsightCardFirstTapHint,
      onTap: _handleInsightCardTap,
      child: SLTheme.glassCard(
        margin: EdgeInsets.zero,
        padding: SLSpacing.all20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: SLColors.accent,
                  size: 18,
                ),
                SLSpacing.w8,
                Flexible(
                  child: Text(
                    isSingle ? context.tr('home_tngquanhmn_0e1b6b') : context.tr('home_hnhtrnhiqu_cbcf59'),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1,
                      color: SLColors.accent,
                    ),
                  ),
                ),
                SLSpacing.w8,
                Icon(
                  Icons.insights_rounded,
                  size: 16,
                  color: SLColors.accent.withValues(alpha: 0.5),
                ),
              ],
            ),
            SLSpacing.h20,
            if (insight == null)
              Text(
                context.tr('home_anggomthmc_0715ce'),
                style: SLTheme.quicksand(
                  fontSize: 12,
                  color: SLColors.textTertiary,
                ),
              )
            else ...[
              _buildInsightBubbleWrap(metrics, compact: false),
              SLSpacing.h20,
              Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.86),
                      const Color(0xFFFFF4F8).withValues(alpha: 0.92),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: SLRadius.lgAll,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9BBC).withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_linhndudng_83e5d9'),
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: SLColors.accent.withValues(alpha: 0.76),
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      _formatInsightUpdatedAtText(insight.updatedAt),
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textTertiary,
                      ),
                    ),
                    SLSpacing.h8,
                    Text(
                      insight.suggestion,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        color: SLColors.textSecondary,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightBubbleWrap(
    List<_InsightBubbleSpec> metrics, {
    required bool compact,
  }) {
    final bubbleSize = compact ? 58.0 : 60.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(
            child: Center(
              child: _FloatingInsightBubble(
                label: metrics[index].label,
                value: metrics[index].value,
                color: metrics[index].color,
                phase: metrics[index].phase,
                size: bubbleSize,
                emphasize: metrics[index].emphasize,
                compact: compact,
              ),
            ),
          ),
          if (index < metrics.length - 1) SizedBox(width: compact ? 12 : 18),
        ],
      ],
    );
  }
}

class _InsightBubbleSpec {
  final String label;
  final int value;
  final Color color;
  final double phase;
  final bool emphasize;

  const _InsightBubbleSpec({
    required this.label,
    required this.value,
    required this.color,
    required this.phase,
    this.emphasize = false,
  });
}

class _FloatingInsightBubble extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final double phase;
  final double size;
  final bool emphasize;
  final bool compact;

  const _FloatingInsightBubble({
    required this.label,
    required this.value,
    required this.color,
    required this.phase,
    required this.size,
    required this.emphasize,
    required this.compact,
  });

  @override
  State<_FloatingInsightBubble> createState() => _FloatingInsightBubbleState();
}

class _FloatingInsightBubbleState extends State<_FloatingInsightBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4200 + (widget.phase * 240).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = widget.value.clamp(0, 100);
    final label = widget.label.isEmpty ? 'LOVE' : widget.label;
    final shouldUseLoveBlock =
        widget.emphasize && label.toUpperCase() == 'LOVE';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = (_controller.value * 2 * pi) + widget.phase;
        final verticalShift = sin(angle) * (widget.compact ? 1.2 : 1.8);
        final horizontalShift = cos(angle * 0.9) * 0.5;
        final scale = 1 + (sin(angle + 0.8) * 0.006);

        return Transform.translate(
          offset: Offset(horizontalShift, -verticalShift),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shouldUseLoveBlock)
            _buildLoveBlock(clampedValue, label)
          else ...[
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: clampedValue / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.98),
                                widget.color.withValues(alpha: 
                                  widget.emphasize ? 0.18 : 0.11,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: widget.color.withValues(alpha: 0.16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 
                                  widget.emphasize ? 0.16 : 0.1,
                                ),
                                blurRadius: widget.emphasize ? 16 : 12,
                                offset: const Offset(0, 7),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.82),
                                blurRadius: 8,
                                offset: const Offset(-2, -2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: widget.size * 0.12,
                        left: widget.size * 0.16,
                        child: Container(
                          width: widget.size * 0.28,
                          height: widget.size * 0.14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: widget.size * 0.78,
                        height: widget.size * 0.78,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: widget.compact ? 4.2 : 4.6,
                          backgroundColor: widget.color.withValues(alpha: 0.09),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(widget.color),
                        ),
                      ),
                      Container(
                        width: widget.size * 0.52,
                        height: widget.size * 0.52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white,
                              widget.color.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      Text(
                        '$clampedValue',
                        style: SLTheme.quicksand(
                          fontSize: widget.compact ? 13 : 14,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SLSpacing.h8,
            SizedBox(
              width: double.infinity,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: widget.compact ? 8.5 : 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF74707A),
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoveBlock(int clampedValue, String label) {
    final blockWidth = widget.compact ? widget.size + 18 : widget.size + 26;
    final blockHeight = widget.compact ? widget.size + 6 : widget.size + 10;
    final radius = BorderRadius.circular(widget.compact ? 24 : 28);

    return SizedBox(
      width: blockWidth,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clampedValue / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          final fill = progress.clamp(0.06, 1.0);
          return Container(
            height: blockHeight,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.98),
                  widget.color.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: widget.color.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.84),
                  blurRadius: 10,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: fill,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withValues(alpha: 0.14),
                              widget.color.withValues(alpha: 0.30),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: widget.compact ? 6 : 8,
                    right: widget.compact ? 7 : 8,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: widget.compact ? 13 : 15,
                      color: widget.color.withValues(alpha: 0.45),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.compact ? 8 : 10,
                        vertical: widget.compact ? 7 : 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: widget.compact ? 9 : 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: widget.color.withValues(alpha: 0.82),
                            ),
                          ),
                          SizedBox(height: widget.compact ? 2 : 3),
                          Text(
                            '$clampedValue%',
                            style: SLTheme.quicksand(
                              fontSize: widget.compact ? 15 : 16,
                              fontWeight: FontWeight.w900,
                              color: widget.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
