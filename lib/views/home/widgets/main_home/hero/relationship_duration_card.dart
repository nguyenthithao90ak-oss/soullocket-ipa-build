import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../companion/home_companion_motion.dart';
import '../../companion/home_companion_scene.dart';
import 'balanced_countdown_style.dart';

/// Dải giấy nhỏ gọn cho bộ đếm Home, giữ ba điểm neo của Companion Scene.
class RelationshipDurationCard extends StatelessWidget {
  const RelationshipDurationCard({
    super.key,
    required String years,
    required String months,
    required String days,
  }) : _primaryValue = months,
       _firstValue = years,
       _secondValue = days,
       _clock = false;

  const RelationshipDurationCard.clock({
    super.key,
    required String hours,
    required String minutes,
    required String seconds,
  }) : _primaryValue = minutes,
       _firstValue = hours,
       _secondValue = seconds,
       _clock = true;

  final String _primaryValue;
  final String _firstValue;
  final String _secondValue;
  final bool _clock;

  Widget _anchor(String id, Widget child) => HomeCompanionAnchor(
    id: id,
    shape: HomeCompanionSurfaceShape.outline,
    border: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    final primaryLabel = context.tr(
      _clock ? 'home_pht_06b001' : 'comm_thng_59900',
    );
    final firstLabel = context.tr(_clock ? 'home_gi_770f40' : 'comm_nm_923e10');
    final secondLabel = context.tr(
      _clock ? 'home_giy_392758' : 'comm_ngy_41ec10',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(0.0, 390.0).toDouble()
            : 390.0;
        if (width <= 0) return const SizedBox.shrink();
        final compact = width < 340;
        final radius = compact ? 18.0 : 22.0;
        final horizontalPadding = compact ? 10.0 : 14.0;
        final verticalPadding = compact ? 9.0 : 11.0;

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: palette.rose.withValues(alpha: .12),
                      blurRadius: 14,
                      spreadRadius: -7,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: CustomPaint(
                    painter: _PaperStripPainter(palette: palette),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        horizontalPadding,
                        verticalPadding,
                        horizontalPadding,
                        verticalPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      context.tr('home_together_title'),
                                      maxLines: 1,
                                      style: SLTheme.quicksand(
                                        fontSize: compact ? 14 : 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: palette.ink,
                                        height: 1.15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ExcludeSemantics(
                                child: Container(
                                  width: compact ? 24 : 27,
                                  height: compact ? 24 : 27,
                                  decoration: BoxDecoration(
                                    color: palette.rose.withValues(alpha: .10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    size: compact ? 13 : 15,
                                    color: palette.rose,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 5 : 7),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _anchor(
                                  'home-time-middle',
                                  _EditorialMetric(
                                    value: _primaryValue,
                                    label: primaryLabel,
                                    palette: palette,
                                    compact: compact,
                                  ),
                                ),
                              ),
                              ExcludeSemantics(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Text(
                                    '·',
                                    style: SLTheme.quicksand(
                                      fontSize: compact ? 18 : 20,
                                      fontWeight: FontWeight.w800,
                                      color: palette.border,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _anchor(
                                  'home-time-right',
                                  _EditorialMetric(
                                    value: _secondValue,
                                    label: secondLabel,
                                    palette: palette,
                                    compact: compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 2 : 4),
                          Row(
                            children: [
                              _anchor(
                                'home-time-left',
                                _EditorialSecondaryMetric(
                                  value: _firstValue,
                                  label: firstLabel,
                                  palette: palette,
                                  compact: compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    context.tr('home_together_subtitle'),
                                    maxLines: 1,
                                    style: SLTheme.quicksand(
                                      fontSize: compact ? 10.5 : 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: palette.muted,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaperStripPainter extends CustomPainter {
  const _PaperStripPainter({required this.palette});

  final BalancedCountdownPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.height < 100 ? 18.0 : 22.0;
    final paper = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(paper, Paint()..color = palette.paper);
    canvas.drawRRect(
      paper,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: palette.dark ? .035 : .34),
            palette.blush.withValues(alpha: palette.dark ? .34 : .22),
          ],
        ).createShader(rect),
    );

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.border.withValues(alpha: .62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(.7),
        Radius.circular((radius - .7).clamp(0.0, radius)),
      ),
      border,
    );

    final paperLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = palette.border.withValues(alpha: .20);
    final line = Path()
      ..moveTo(14, size.height - 14)
      ..cubicTo(
        size.width * .27,
        size.height - 18,
        size.width * .48,
        size.height - 9,
        size.width * .69,
        size.height - 14,
      )
      ..cubicTo(
        size.width * .82,
        size.height - 17,
        size.width * .91,
        size.height - 11,
        size.width - 14,
        size.height - 15,
      );
    canvas.drawPath(line, paperLine);

    final fold = Path()
      ..moveTo(size.width - 34, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 34)
      ..close();
    canvas.drawPath(
      fold,
      Paint()..color = palette.blush.withValues(alpha: .52),
    );
    canvas.drawLine(
      Offset(size.width - 34, 0),
      Offset(size.width, 34),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.border.withValues(alpha: .48),
    );

    final tape = Paint()..color = palette.gold.withValues(alpha: .13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, -4, 42, 13),
        const Radius.circular(4),
      ),
      tape,
    );

    final heart = Path()
      ..moveTo(size.width - 45, size.height - 12)
      ..cubicTo(
        size.width - 57,
        size.height - 21,
        size.width - 53,
        size.height - 28,
        size.width - 45,
        size.height - 21,
      )
      ..cubicTo(
        size.width - 37,
        size.height - 28,
        size.width - 33,
        size.height - 21,
        size.width - 45,
        size.height - 12,
      )
      ..close();
    canvas.drawPath(
      heart,
      Paint()..color = palette.rose.withValues(alpha: .22),
    );
  }

  @override
  bool shouldRepaint(covariant _PaperStripPainter oldDelegate) =>
      oldDelegate.palette.dark != palette.dark;
}

class _EditorialMetric extends StatelessWidget {
  const _EditorialMetric({
    required this.value,
    required this.label,
    required this.palette,
    required this.compact,
  });

  final String value;
  final String label;
  final BalancedCountdownPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    child: ExcludeSemantics(
      child: SizedBox(
        height: compact ? 54 : 62,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style:
                      SLTheme.quicksand(
                        fontSize: compact ? 35 : 42,
                        height: .92,
                        fontWeight: FontWeight.w900,
                        color: palette.rose,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  style: SLTheme.quicksand(
                    fontSize: compact ? 14 : 16,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EditorialSecondaryMetric extends StatelessWidget {
  const _EditorialSecondaryMetric({
    required this.value,
    required this.label,
    required this.palette,
    required this.compact,
  });

  final String value;
  final String label;
  final BalancedCountdownPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, maxWidth: 92),
        child: SizedBox(
          height: compact ? 32 : 35,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style:
                        SLTheme.quicksand(
                          fontSize: compact ? 19 : 21,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: palette.ink,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    maxLines: 1,
                    style: SLTheme.quicksand(
                      fontSize: compact ? 10.5 : 11.5,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
