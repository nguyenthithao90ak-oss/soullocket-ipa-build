import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../companion/home_companion_motion.dart';
import '../../companion/home_companion_scene.dart';
import 'balanced_countdown_style.dart';

/// Bề mặt Editorial gọn nhẹ cho bộ đếm thời gian yêu nhau trên Home.
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

        // Bề mặt phải thẳng hàng với các khối Home khác, kể cả điện thoại có
        // chiều rộng logical lớn do DPI nhỏ. Lề an toàn đã được caller quản lý.
        final width = availableWidth;
        final compact = width < 340;
        final metrics = _metrics(context);
        final metricFontSize = metrics.length == 3
            ? (compact ? 30.0 : 38.0)
            : (compact ? 38.0 : 50.0);
        final metricLabelSize = metrics.length == 3
            ? (compact ? 10.0 : 12.0)
            : (compact ? 12.0 : 15.0);
        const path = _EditorialSurfaceClipper.pathFor;

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: width,
              child: CustomPaint(
                painter: _EditorialSurfacePainter(
                  palette: palette,
                  doodleSeed: metrics.length,
                ),
                child: ClipPath(
                  clipper: const _EditorialSurfaceClipper(),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      compact ? 16 : 20,
                      compact ? 16 : 18,
                      compact ? 16 : 20,
                      compact ? 14 : 16,
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
                                    style: SLTheme.quicksand(
                                      fontSize: compact ? 12 : 13,
                                      fontWeight: FontWeight.w700,
                                      color: palette.muted,
                                      letterSpacing: 1.2,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                        SizedBox(height: compact ? 13 : 16),
                        SizedBox(
                          height: compact ? 52 : 62,
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
                                      horizontal: compact ? 2 : 5,
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
                        SizedBox(height: compact ? 11 : 14),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              context.tr('home_together_subtitle'),
                              style: SLTheme.quicksand(
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w600,
                                color: palette.muted,
                                height: 1.2,
                              ),
                            ),
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
      height: 18,
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

class _EditorialSurfaceClipper extends CustomClipper<Path> {
  const _EditorialSurfaceClipper();

  static Path pathFor(Rect rect) {
    final safe = rect.deflate(1);
    final radius = math.min(28.0, math.max(18.0, safe.shortestSide * .08));
    return Path()..addRRect(
      RRect.fromRectAndRadius(safe, Radius.circular(radius)),
    );
  }

  @override
  Path getClip(Size size) => pathFor(Offset.zero & size);

  @override
  bool shouldReclip(covariant _EditorialSurfaceClipper oldClipper) => false;
}

class _EditorialSurfacePainter extends CustomPainter {
  const _EditorialSurfacePainter({
    required this.palette,
    required this.doodleSeed,
  });

  final BalancedCountdownPalette palette;
  final int doodleSeed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final surfacePath = _EditorialSurfaceClipper.pathFor(rect);

    canvas.drawShadow(
      surfacePath,
      Colors.black.withValues(alpha: palette.dark ? .22 : .14),
      8,
      true,
    );
    canvas.drawPath(
      surfacePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.paper,
            palette.paper,
            palette.blush.withValues(alpha: palette.dark ? .82 : .68),
          ],
        ).createShader(rect),
    );

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = palette.border.withValues(alpha: palette.dark ? .72 : .6);
    canvas.drawPath(surfacePath, edgePaint);

    canvas.save();
    canvas.clipPath(surfacePath);
    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(.95, -.95),
        radius: 1.1,
        colors: [
          palette.rose.withValues(alpha: palette.dark ? .16 : .09),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, wash);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = palette.border.withValues(alpha: .42);
    final accentPath = Path()
      ..moveTo(size.width * .06, size.height * .82)
      ..cubicTo(
        size.width * .23,
        size.height * .76,
        size.width * .34,
        size.height * .86,
        size.width * .51,
        size.height * .81,
      )
      ..cubicTo(
        size.width * .64,
        size.height * .77,
        size.width * .76,
        size.height * .84,
        size.width * .94,
        size.height * .78,
      );
    canvas.drawPath(accentPath, line);

    _drawTinyHeart(
      canvas,
      Offset(size.width - 29, size.height - 24),
      .48,
      palette.rose.withValues(alpha: .35),
    );
    _drawTinyHeart(
      canvas,
      Offset(size.width * .10, size.height * .70),
      .30,
      palette.rose.withValues(alpha: .28),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * .90, size.height * .25),
      4.2,
      palette.gold.withValues(alpha: .7),
    );
    if (doodleSeed == 3) {
      _drawSparkle(
        canvas,
        Offset(size.width * .20, size.height * .24),
        3.2,
        palette.gold.withValues(alpha: .52),
      );
    }
    canvas.restore();
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

  @override
  bool shouldRepaint(covariant _EditorialSurfacePainter oldDelegate) =>
      oldDelegate.palette.dark != palette.dark ||
      oldDelegate.palette.transparent != palette.transparent ||
      oldDelegate.doodleSeed != doodleSeed;
}

class _TinyHeartPainter extends CustomPainter {
  const _TinyHeartPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _EditorialSurfacePainter._drawTinyHeart(
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
