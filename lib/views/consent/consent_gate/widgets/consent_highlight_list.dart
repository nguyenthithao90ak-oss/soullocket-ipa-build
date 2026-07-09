part of '../../consent_gate.dart';

Widget _buildHighlightList(BuildContext context,
  List<_ConsentHighlight> items, {
  required Color accent,
}) {
  // Responsive scaling for highlight list icons
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final scaleNormalization = 1.6 / dpr;
  final containerSize = (32 * scaleNormalization).clamp(28.0, 36.0);
  final iconSize = (16 * scaleNormalization).clamp(14.0, 18.0);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _cardBackground,
      borderRadius: SLRadius.lgAll,
      border: Border.all(color: _panelBorder),
    ),
    child: Column(
      children: items.map((item) {
        final isLast = identical(item, items.last);
        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: SLRadius.mdAll,
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: containerSize,
                height: containerSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: SLRadius.smAll,
                  border: Border.all(color: accent.withValues(alpha: 0.14)),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, color: accent, size: iconSize),
              ),
              SLSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: SLTheme.quicksand(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    SLSpacing.gapH(2),
                    Text(
                      item.description,
                      style: SLTheme.quicksand(
                        fontSize: 11.7,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}
