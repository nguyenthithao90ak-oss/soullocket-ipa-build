import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../companion/home_companion_motion.dart';
import '../../companion/home_companion_scene.dart';
import 'balanced_countdown_style.dart';

/// Dải giấy nhỏ gọn cho bộ đếm thời gian yêu nhau trên Home.
///
/// Phần tính ngày nằm ở [RelationshipDuration]. Widget này chỉ quyết định
/// cách trình bày: trước mốc một năm là tháng + ngày; từ mốc một năm trở đi
/// là năm + tháng + ngày.
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

  int get _firstNumber {
    final digits = _firstValue.replaceAll(RegExp(r'[^0-9-]'), '');
    return int.tryParse(digits) ?? 0;
  }

  List<_DurationMetric> _metrics(BuildContext context) {
    if (_clock) {
      return [
        _DurationMetric(
          id: 'home-time-left',
          value: _firstValue,
          label: context.tr('home_gi_770f40'),
        ),
        _DurationMetric(
          id: 'home-time-middle',
          value: _primaryValue,
          label: context.tr('home_pht_06b001'),
        ),
        _DurationMetric(
          id: 'home-time-right',
          value: _secondValue,
          label: context.tr('home_giy_392758'),
        ),
      ];
    }

    final month = _DurationMetric(
      // Khi chưa đủ năm, tháng giữ vị trí trái của dải hai ô. Khi đã đủ năm,
      // vị trí giữa được giữ để Companion Scene không đổi nhịp đột ngột.
      id: _firstNumber > 0 ? 'home-time-middle' : 'home-time-left',
      value: _primaryValue,
      label: context.tr('comm_thng_59900e'),
    );
    final day = _DurationMetric(
      id: 'home-time-right',
      value: _secondValue,
      label: context.tr('comm_ngy_41ec10'),
    );
    if (_firstNumber <= 0) return [month, day];

    return [
      _DurationMetric(
        id: 'home-time-left',
        value: _firstValue,
        label: context.tr('comm_nm_923e10'),
      ),
      month,
      day,
    ];
  }

  Widget _anchor(
    _DurationMetric metric,
    Widget child,
    Path Function(Rect) path,
  ) {
    return HomeCompanionAnchor(
      id: metric.id,
      shape: HomeCompanionSurfaceShape.outline,
      border: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      pathBuilder: path,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(
      dark: Theme.of(context).brightness == Brightness.dark,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        if (availableWidth <= 0) return const SizedBox.shrink();

        // Mảnh giấy thứ ba là dải ngang, không chiếm hết chiều rộng Home trên
        // máy lớn. Trên máy 320dp vẫn dùng toàn bộ cột trừ lề an toàn.
        final width = math.min(availableWidth, 360.0);
        final compact = width < 340;
        final metrics = _metrics(context);
        final metricFontSize = metrics.length == 3
            ? (compact ? 24.0 : 27.0)
            : (compact ? 28.0 : 31.0);
        final metricLabelSize = metrics.length == 3
            ? (compact ? 9.5 : 10.5)
            : (compact ? 11.0 : 12.0);
        const path = _TornPaperClipper.pathFor;

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: AlignmentDirectional.center,
              child: SizedBox(
                width: width,
                child: CustomPaint(
                  painter: _TornPaperPainter(
                    palette: palette,
                    doodleSeed: metrics.length,
                  ),
                  child: ClipPath(
                    clipper: const _TornPaperClipper(),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        compact ? 15 : 19,
                        compact ? 11 : 12,
                        compact ? 15 : 19,
                        compact ? 10 : 11,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    context.tr('home_together_title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: SLTheme.quicksand(
                                      fontSize: compact ? 13 : 14,
                                      fontWeight: FontWeight.w800,
                                      color: palette.ink,
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ExcludeSemantics(
                                child: CustomPaint(
                                  size: Size.square(compact ? 18 : 20),
                                  painter: _TinyHeartPainter(
                                    color: palette.rose,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 3 : 4),
                          SizedBox(
                            height: 48,
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (
                                  var index = 0;
                                  index < metrics.length;
                                  index++
                                ) ...[
                                  if (index > 0)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: compact ? 2 : 4,
                                      ),
                                      child: ExcludeSemantics(
                                        child: _MetricDivider(
                                          color: palette.border,
                                          compact: compact,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: _anchor(
                                      metrics[index],
                                      _DurationMetricView(
                                        value: metrics[index].value,
                                        label: metrics[index].label,
                                        palette: palette,
                                        valueFontSize: metricFontSize,
                                        labelFontSize: metricLabelSize,
                                      ),
                                      path,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

class _DurationMetric {
  const _DurationMetric({
    required this.id,
    required this.value,
    required this.label,
  });

  final String id;
  final String value;
  final String label;
}

class _DurationMetricView extends StatelessWidget {
  const _DurationMetricView({
    required this.value,
    required this.label,
    required this.palette,
    required this.valueFontSize,
    required this.labelFontSize,
  });

  final String value;
  final String label;
  final BalancedCountdownPalette palette;
  final double valueFontSize;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style:
                        SLTheme.quicksand(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w900,
                          height: .9,
                          color: palette.rose,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    maxLines: 1,
                    style: SLTheme.quicksand(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w700,
                      height: 1,
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
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.color, required this.compact});

  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 6 : 8,
      height: 42,
      child: Center(
        child: Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .74),
          ),
        ),
      ),
    );
  }
}

class _TornPaperClipper extends CustomClipper<Path> {
  const _TornPaperClipper();

  static Path pathFor(Rect rect) {
    final safe = rect.deflate(1.0);
    final path = Path();
    final width = safe.width;
    final height = safe.height;
    final left = safe.left;
    final top = safe.top;
    final right = safe.right;
    final bottom = safe.bottom;

    double topEdge(double x) =>
        top + 3.0 + math.sin(x * .23) * 1.35 + math.sin(x * .57) * .65;
    double bottomEdge(double x) =>
        bottom - 3.0 + math.sin(x * .19 + 1.2) * 1.2 + math.sin(x * .49) * .7;

    path.moveTo(left + 6, topEdge(6));
    for (var x = 14.0; x < width - 8; x += 12) {
      path.lineTo(left + x, topEdge(x));
    }
    path.lineTo(right - 5, topEdge(width - 5));
    path.quadraticBezierTo(
      right - 2,
      top + height * .28,
      right - 4,
      top + height * .52,
    );
    path.quadraticBezierTo(
      right - 2,
      top + height * .76,
      right - 7,
      bottomEdge(width - 7),
    );
    for (var x = width - 18.0; x > 8; x -= 12) {
      path.lineTo(left + x, bottomEdge(x));
    }
    path.lineTo(left + 6, bottomEdge(6));
    path.quadraticBezierTo(
      left + 2,
      top + height * .75,
      left + 5,
      top + height * .48,
    );
    path.quadraticBezierTo(left + 2, top + height * .22, left + 6, topEdge(6));
    path.close();
    return path;
  }

  @override
  Path getClip(Size size) => pathFor(Offset.zero & size);

  @override
  bool shouldReclip(covariant _TornPaperClipper oldClipper) => false;
}

class _TornPaperPainter extends CustomPainter {
  const _TornPaperPainter({required this.palette, required this.doodleSeed});

  final BalancedCountdownPalette palette;
  final int doodleSeed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paperPath = _TornPaperClipper.pathFor(rect);

    canvas.drawShadow(
      paperPath,
      Colors.black.withValues(alpha: palette.dark ? .22 : .14),
      5,
      true,
    );
    canvas.drawPath(
      paperPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.paper,
            palette.paper,
            palette.blush.withValues(alpha: palette.dark ? .72 : .52),
          ],
        ).createShader(rect),
    );

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = palette.border.withValues(alpha: palette.dark ? .72 : .6);
    canvas.drawPath(paperPath, edgePaint);

    // Một nét chì mảnh và vài chấm nhỏ tạo cảm giác giấy thủ công mà không
    // làm rối phần số. Tất cả đều là vector nên không thêm asset bitmap.
    final stitch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..strokeCap = StrokeCap.round
      ..color = palette.border.withValues(alpha: .28);
    final stitchPath = Path()
      ..moveTo(size.width * .16, size.height - 12)
      ..cubicTo(
        size.width * .31,
        size.height - 15,
        size.width * .44,
        size.height - 9,
        size.width * .58,
        size.height - 12,
      )
      ..cubicTo(
        size.width * .68,
        size.height - 14,
        size.width * .76,
        size.height - 10,
        size.width * .84,
        size.height - 12,
      );
    canvas.drawPath(stitchPath, stitch);

    _drawTinyHeart(
      canvas,
      Offset(size.width - 25, size.height - 17),
      .55,
      palette.rose.withValues(alpha: .35),
    );
    _drawTinyHeart(
      canvas,
      Offset(size.width * .12, size.height * .30),
      .36,
      palette.rose.withValues(alpha: .28),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * .86, size.height * .26),
      4.5,
      palette.gold.withValues(alpha: .7),
    );
    _drawDaisy(
      canvas,
      Offset(size.width * .08, size.height - 17),
      4.3,
      palette.gold.withValues(alpha: .64),
      palette.rose.withValues(alpha: .38),
    );
    if (doodleSeed == 3) {
      _drawSparkle(
        canvas,
        Offset(size.width * .22, size.height * .24),
        3.2,
        palette.gold.withValues(alpha: .52),
      );
    }
  }

  static void _drawTinyHeart(
    Canvas canvas,
    Offset center,
    double scale,
    Color color,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy + 5 * scale)
      ..cubicTo(
        center.dx - 11 * scale,
        center.dy - 2 * scale,
        center.dx - 7 * scale,
        center.dy - 10 * scale,
        center.dx,
        center.dy - 4 * scale,
      )
      ..cubicTo(
        center.dx + 7 * scale,
        center.dy - 10 * scale,
        center.dx + 11 * scale,
        center.dy - 2 * scale,
        center.dx,
        center.dy + 5 * scale,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  static void _drawSparkle(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(
        center.dx + size * .28,
        center.dy - size * .28,
        center.dx + size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + size * .28,
        center.dy + size * .28,
        center.dx,
        center.dy + size,
      )
      ..quadraticBezierTo(
        center.dx - size * .28,
        center.dy + size * .28,
        center.dx - size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - size * .28,
        center.dy - size * .28,
        center.dx,
        center.dy - size,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  static void _drawDaisy(
    Canvas canvas,
    Offset center,
    double size,
    Color petal,
    Color centerColor,
  ) {
    final petalPaint = Paint()..color = petal;
    for (var i = 0; i < 5; i++) {
      final angle = math.pi * 2 * i / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * size * .72,
        size * .38,
        petalPaint,
      );
    }
    canvas.drawCircle(center, size * .30, Paint()..color = centerColor);
  }

  @override
  bool shouldRepaint(covariant _TornPaperPainter oldDelegate) =>
      oldDelegate.palette.dark != palette.dark ||
      oldDelegate.palette.transparent != palette.transparent ||
      oldDelegate.doodleSeed != doodleSeed;
}

class _TinyHeartPainter extends CustomPainter {
  const _TinyHeartPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _TornPaperPainter._drawTinyHeart(
      canvas,
      Offset(size.width / 2, size.height / 2),
      size.shortestSide / 22,
      color.withValues(alpha: .78),
    );
  }

  @override
  bool shouldRepaint(covariant _TinyHeartPainter oldDelegate) =>
      oldDelegate.color != color;
}
