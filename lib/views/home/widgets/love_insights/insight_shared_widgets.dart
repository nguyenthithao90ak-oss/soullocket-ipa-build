part of '../../love_insights_screen.dart';

extension _InsightSharedWidgetsExt on _LoveInsightsScreenState {
  // ── Palette chung ──
  static const _textDark = Color(0xFF332C35);
  static const _textGrey = Color(0xFF8D8490);

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
              color: _textGrey,
            ),
          ),
        ),
        Text(
          trailing,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: _textGrey,
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
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
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
    Color accent = const Color(0xFFFF4F87),
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: accent),
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
                  color: _textDark,
                ),
              ),
              SLSpacing.h4,
              Text(
                subtitle,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: _textGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
