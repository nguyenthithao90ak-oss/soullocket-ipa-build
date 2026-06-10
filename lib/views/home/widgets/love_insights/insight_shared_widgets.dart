part of '../../love_insights_screen.dart';

extension _InsightSharedWidgetsExt on _LoveInsightsScreenState {
  Widget _buildSectionLabel({
    required String title,
    required String trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF595260),
            ),
          ),
        ),
        Text(
          trailing,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF66606C),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    Color accent = const Color(0xFFD81B60),
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: SLRadius.mdAll,
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        SLSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF202538),
                ),
              ),
              SLSpacing.h4,
              Text(
                subtitle,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: const Color(0xFF867E89),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallHeader(String title) {
    return Text(
      title,
      style: SLTheme.quicksand(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF6F6772),
      ),
    );
  }
}
