// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import
part of '../../main_home_tab.dart';

extension _MainHomeInsightCardExt on _MainHomeTabState {
  Widget _buildLegacyInsightCard({
    required bool isSingle,
    required String nameU1,
    required String nameU2,
  }) {
    final insight = _insightData;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: _buildHomeCardFirstTapWrapper(
        showHint: _showInsightCardFirstTapHintNotifier.value,
        onTap: _handleInsightCardTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFDCE8).withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              Row(
                children: [
                  const Text('💕 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      'Hành trình yêu thương',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: const Color(0xFF332C35),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFFFF6FA5),
                  ),
                ],
              ),
              SLSpacing.h20,
              if (insight == null)
                _buildInsightLoadingShimmer()
              else ...[
                // Rings & LOVE Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isSingle)
                      _buildProgressRing(
                        value: insight.loveU1,
                        label: nameU1.trim(),
                        color: const Color(0xFF42A5F5), // Hoặc đổi sang pastel pink/purple tuỳ thích
                      ),
                    
                    // LOVE Center Card
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF85A2), Color(0xFFFF4F87)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4F87).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'LOVE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: Colors.white70,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${insight.loveScore}%',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!isSingle)
                      _buildProgressRing(
                        value: insight.loveU2,
                        label: nameU2.trim(),
                        color: const Color(0xFF9B7AE8), // Pastel purple
                      ),
                  ],
                ),
                SLSpacing.h20,
                // AI Nhận xét
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: FastBackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF332C35).withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('✨ ', style: TextStyle(fontSize: 14)),
                          Text(
                            'AI phân tích',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: const Color(0xFFFF4F87),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        insight.suggestion,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF4A3060),
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRing({
    required int value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 6,
                color: color.withValues(alpha: 0.15),
              ),
              CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 6,
                color: color,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '$value',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: const Color(0xFF8D8490),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightLoadingShimmer() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () => setState(() {}),
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD6E7).withValues(alpha: value),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD6E7).withValues(alpha: value * 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        );
      },
    );
  }
}
