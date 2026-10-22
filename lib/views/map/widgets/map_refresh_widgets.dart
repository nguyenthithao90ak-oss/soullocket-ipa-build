import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../map_location_access.dart';

// Bảng màu của phương án B: nền than trung tính, mint làm màu hành động.
// Các màu phụ vẫn đủ khác nhau để phân biệt vị trí của hai người và trạng thái.
const mapRose = Color(0xFFE77B98);
const mapBlue = Color(0xFF8EAFB8);
const mapSage = Color(0xFF73E2C1);
const mapLavender = Color(0xFF9ACFC5);
const mapInk = Color(0xFF0E171A);
const mapPeach = Color(0xFFD9B59F);
const mapButter = Color(0xFFCBE6DC);

/// Nét vẽ canvas nhẹ để màn bản đồ có cảm giác như một trang scrapbook.
/// Các hình chỉ là lớp trang trí, không che marker hoặc bắt tương tác.
class MapCuteCanvasPainter extends CustomPainter {
  const MapCuteCanvasPainter({
    this.dark = false,
    this.dense = false,
    this.intensity = 1,
  });

  final bool dark;
  final bool dense;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final opacity = (dark ? .22 : .44) * intensity;
    final softOpacity = (dark ? .14 : .24) * intensity;
    final paint = Paint()..style = PaintingStyle.fill;

    void bubble(Offset center, double radius, Color color) {
      paint.color = color.withValues(alpha: softOpacity);
      canvas.drawCircle(center, radius, paint);
    }

    void line(Offset start, Offset end, Color color, double width) {
      final stroke = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width;
      canvas.drawLine(start, end, stroke);
    }

    void heart(Offset center, double scale, Color color) {
      final path = Path()
        ..moveTo(center.dx, center.dy + scale * .9)
        ..cubicTo(
          center.dx - scale * 1.35,
          center.dy + scale * .05,
          center.dx - scale * .78,
          center.dy - scale * .92,
          center.dx,
          center.dy - scale * .2,
        )
        ..cubicTo(
          center.dx + scale * .78,
          center.dy - scale * .92,
          center.dx + scale * 1.35,
          center.dy + scale * .05,
          center.dx,
          center.dy + scale * .9,
        )
        ..close();
      paint.color = color.withValues(alpha: opacity);
      canvas.drawPath(path, paint);
    }

    void sparkle(Offset center, double radius, Color color) {
      final stroke = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = dense ? 1.4 : 1.8;
      canvas.drawLine(
        Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy),
        stroke,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        stroke,
      );
      canvas.drawCircle(
        center,
        radius * .22,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }

    void dashedPath(
      Path path,
      Color color, {
      double width = 1.8,
      double dash = 9,
      double gap = 7,
    }) {
      final stroke = Paint()
        ..color = color.withValues(alpha: opacity * .9)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width;
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = (distance + dash).clamp(0.0, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), stroke);
          distance += dash + gap;
        }
      }
    }

    // Phương án B dùng chrome tối giản. Trên nền than chỉ giữ vài đường
    // contour rất mảnh để tạo chiều sâu, không vẽ tim/sparkle pastel.
    if (dark) {
      final contour = Paint()
        ..color = const Color(0xFF8FE8CB).withValues(alpha: opacity * .35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = dense ? 1 : 1.2;
      for (var y = -size.height * .1; y < size.height * 1.1; y += 34) {
        canvas.drawLine(
          Offset(-size.width * .1, y),
          Offset(size.width * 1.1, y + size.height * .08),
          contour,
        );
      }
      final route = Path()
        ..moveTo(-size.width * .08, size.height * .72)
        ..cubicTo(
          size.width * .24,
          size.height * .58,
          size.width * .58,
          size.height * .84,
          size.width * 1.08,
          size.height * .34,
        );
      dashedPath(route, const Color(0xFF73E2C1), width: 1.2, dash: 10, gap: 10);
      return;
    }

    bubble(
      Offset(size.width * .06, size.height * .12),
      size.width * .14,
      mapRose,
    );
    bubble(
      Offset(size.width * .94, size.height * .18),
      size.width * .17,
      mapLavender,
    );
    bubble(
      Offset(size.width * .88, size.height * .92),
      size.width * .13,
      mapBlue,
    );
    bubble(
      Offset(size.width * .12, size.height * .9),
      size.width * .11,
      mapPeach,
    );

    heart(Offset(size.width * .12, size.height * .18), dense ? 7 : 11, mapRose);
    heart(Offset(size.width * .88, size.height * .12), dense ? 6 : 9, mapRose);
    heart(
      Offset(size.width * .82, size.height * .86),
      dense ? 7 : 10,
      mapLavender,
    );
    sparkle(
      Offset(size.width * .22, size.height * .68),
      dense ? 6 : 9,
      mapButter,
    );
    sparkle(
      Offset(size.width * .78, size.height * .42),
      dense ? 5 : 8,
      mapBlue,
    );

    // Hai nét cong nhỏ gợi đường nối giữa hai người.
    line(
      Offset(size.width * .05, size.height * .76),
      Offset(size.width * .18, size.height * .72),
      mapSage,
      dense ? 1.2 : 1.7,
    );
    line(
      Offset(size.width * .82, size.height * .64),
      Offset(size.width * .95, size.height * .60),
      mapRose,
      dense ? 1.2 : 1.7,
    );

    // Route đứt nét và các waypoint tạo cảm giác bản đồ được vẽ tay trên giấy.
    // Chỉ dùng ở canvas lớn; trên card nhỏ, các nét này sẽ làm rối nội dung.
    if (!dense) {
      final route = Path()
        ..moveTo(size.width * -.06, size.height * .74)
        ..cubicTo(
          size.width * .20,
          size.height * .58,
          size.width * .28,
          size.height * .88,
          size.width * .50,
          size.height * .63,
        )
        ..cubicTo(
          size.width * .68,
          size.height * .42,
          size.width * .76,
          size.height * .58,
          size.width * 1.06,
          size.height * .31,
        );
      dashedPath(route, mapSage, width: 2.2, dash: 11, gap: 8);

      final secondRoute = Path()
        ..moveTo(size.width * .08, size.height * .12)
        ..cubicTo(
          size.width * .28,
          size.height * .22,
          size.width * .45,
          size.height * .08,
          size.width * .72,
          size.height * .22,
        );
      dashedPath(secondRoute, mapLavender, width: 1.4, dash: 7, gap: 9);

      for (final point in const <Offset>[
        Offset(.22, .62),
        Offset(.51, .63),
        Offset(.78, .48),
      ]) {
        final center = Offset(size.width * point.dx, size.height * point.dy);
        final ring = Paint()
          ..color = paletteColor(mapRose).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, 5.5, ring);
        canvas.drawCircle(
          center,
          2.1,
          Paint()..color = mapRose.withValues(alpha: opacity),
        );
      }
    }
  }

  Color paletteColor(Color color) =>
      dark ? Color.lerp(color, Colors.white, .24)! : color;

  @override
  bool shouldRepaint(covariant MapCuteCanvasPainter oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.dense != dense ||
      oldDelegate.intensity != intensity;
}

/// Minh hoạ giấy scrapbook dùng khi bản đồ chưa tải được tile hoặc ở preview.
/// Đây là lớp trình bày độc lập, không thay thế dữ liệu vị trí thật.
class MapIllustratedPreview extends StatelessWidget {
  const MapIllustratedPreview({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 168,
        width: double.infinity,
        child: CustomPaint(
          painter: _MapIllustratedPreviewPainter(dark: dark),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MapIllustratedPreviewPainter extends CustomPainter {
  const _MapIllustratedPreviewPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final background = dark ? const Color(0xFF332B45) : const Color(0xFFFFFBFD);
    final road = dark ? const Color(0xFF6D617D) : const Color(0xFFEBCDD9);
    final route = dark ? const Color(0xFF9BD6C9) : mapSage;
    final rose = dark ? const Color(0xFFFFA7BF) : mapRose;
    final blue = dark ? const Color(0xFFB4D9FF) : mapBlue;
    final ink = dark ? const Color(0xFFF6EAF4) : mapInk;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            background,
            dark ? const Color(0xFF29243A) : const Color(0xFFF2F8FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    final paper = Paint()
      ..color = (dark ? Colors.white : mapRose).withValues(
        alpha: dark ? .035 : .045,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 22.0; y < size.height; y += 27) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 4), paper);
    }

    final roadPaint = Paint()
      ..color = road.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    final roads = <Path>[
      Path()
        ..moveTo(-12, size.height * .24)
        ..cubicTo(
          size.width * .24,
          size.height * .04,
          size.width * .35,
          size.height * .45,
          size.width + 12,
          size.height * .22,
        ),
      Path()
        ..moveTo(size.width * .14, size.height + 10)
        ..cubicTo(
          size.width * .30,
          size.height * .57,
          size.width * .72,
          size.height * .78,
          size.width * .86,
          -10,
        ),
      Path()
        ..moveTo(-10, size.height * .73)
        ..cubicTo(
          size.width * .34,
          size.height * .55,
          size.width * .55,
          size.height * .98,
          size.width + 10,
          size.height * .64,
        ),
    ];
    for (final path in roads) {
      canvas.drawPath(path, roadPaint);
    }

    final routePath = Path()
      ..moveTo(size.width * .20, size.height * .66)
      ..cubicTo(
        size.width * .33,
        size.height * .39,
        size.width * .55,
        size.height * .83,
        size.width * .79,
        size.height * .36,
      );
    final routePaint = Paint()
      ..color = route
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;
    for (final metric in routePath.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 16) {
        final end = (distance + 9).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), routePaint);
      }
    }

    _drawPin(canvas, Offset(size.width * .20, size.height * .66), rose, ink);
    _drawPin(canvas, Offset(size.width * .79, size.height * .36), blue, ink);
    _drawHeart(canvas, Offset(size.width * .51, size.height * .47), rose);
    for (final point in <Offset>[
      Offset(size.width * .09, size.height * .24),
      Offset(size.width * .70, size.height * .78),
      Offset(size.width * .89, size.height * .18),
    ]) {
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = rose.withValues(alpha: .72),
      );
    }
  }

  void _drawPin(Canvas canvas, Offset center, Color color, Color ink) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: dark ? .18 : .10);
    canvas.drawCircle(center.translate(0, 5), 13, shadow);
    final fill = Paint()..color = color;
    canvas.drawCircle(center, 12, fill);
    final outline = Paint()
      ..color = ink.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 12, outline);
    canvas.drawCircle(
      center,
      4,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
  }

  void _drawHeart(Canvas canvas, Offset center, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + 11)
      ..cubicTo(
        center.dx - 17,
        center.dy - 1,
        center.dx - 10,
        center.dy - 13,
        center.dx,
        center.dy - 4,
      )
      ..cubicTo(
        center.dx + 10,
        center.dy - 13,
        center.dx + 17,
        center.dy - 1,
        center.dx,
        center.dy + 11,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .78));
  }

  @override
  bool shouldRepaint(covariant _MapIllustratedPreviewPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

/// Thanh điều hướng chung: không tạo một khối nền riêng cho từng nút.
class MapNavigationBar extends StatelessWidget {
  const MapNavigationBar({
    super.key,
    required this.onBack,
    required this.onSearch,
    this.helpButton,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final Widget? helpButton;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Material(
      color: Colors.transparent,
      elevation: 7,
      shadowColor: mapInk.withValues(alpha: palette.dark ? .24 : .14),
      shape: const StadiumBorder(),
      // `Ink` thêm phần đệm bằng độ dày border vào kích thước render của
      // decoration. Dùng `DecoratedBox` giữ nguyên viền nhưng không làm
      // thanh điều hướng cao hơn 56dp trên Android/iOS.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.surface, palette.tint(mapSage)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: palette.accent(mapSage).withValues(alpha: .30),
          ),
        ),
        child: SizedBox(
          height: 56,
          child: CustomPaint(
            painter: MapCuteCanvasPainter(dark: palette.dark, dense: true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: palette.ink,
                    backgroundColor: Colors.transparent,
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    shape: const CircleBorder(),
                  ),
                ),
                child: Row(
                  children: [
                    MapToolbarButton(
                      key: const ValueKey('map_back_button'),
                      icon: Icons.arrow_back_rounded,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: onBack,
                      flat: true,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          context.tr('map_refresh_nav_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: palette.ink,
                          ),
                        ),
                      ),
                    ),
                    if (helpButton != null)
                      SizedBox(width: 48, height: 48, child: helpButton!),
                    MapToolbarButton(
                      key: const ValueKey('map_search_button'),
                      icon: Icons.search_rounded,
                      tooltip: context.tr('map_search_place_tooltip'),
                      onPressed: onSearch,
                      flat: true,
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
}

class MapToolbarButton extends StatelessWidget {
  const MapToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = mapSage,
    this.primary = false,
    this.flat = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color accent;
  final bool primary;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final shape = flat
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: BorderSide(
              color: primary ? palette.accent(accent) : palette.border,
              width: primary ? 0 : 1,
            ),
          );
    return Material(
      color: Colors.transparent,
      elevation: flat ? 0 : 5,
      shadowColor: (primary ? accent : mapInk).withValues(alpha: .18),
      shape: shape,
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: flat
                ? Colors.transparent
                : primary
                ? palette.accent(accent)
                : palette.surface,
            foregroundColor: primary && !flat
                ? Colors.white
                : palette.accent(accent),
            disabledBackgroundColor: flat
                ? Colors.transparent
                : palette.surface,
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            shape: shape,
          ),
          icon: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

/// Thẻ trạng thái nhỏ, nền đặc: không cần blur toàn bộ lớp bản đồ phía sau.
class MapStatusPill extends StatelessWidget {
  const MapStatusPill({
    super.key,
    required this.icon,
    required this.label,
    this.accent = mapSage,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.surface, palette.tint(accent)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border.withValues(alpha: .9)),
        boxShadow: [
          BoxShadow(
            color: mapInk.withValues(alpha: palette.dark ? .18 : .08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.tint(accent),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: palette.accent(accent)),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapInlineEmptyState extends StatelessWidget {
  const MapInlineEmptyState({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.tint(accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: palette.accent(accent), size: 26),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.5, color: palette.muted),
          ),
          if (onTap != null && actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.accent(accent),
                minimumSize: const Size(48, 48),
                side: BorderSide(color: accent.withValues(alpha: .3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text(actionLabel!, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}

class MapDistanceCard extends StatelessWidget {
  const MapDistanceCard({
    super.key,
    required this.distance,
    required this.live,
    required this.routeDistance,
    required this.eta,
  });

  final String distance;
  final bool live;
  final String routeDistance;
  final String eta;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .96, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.surface, palette.tint(mapSage)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: palette.accent(mapSage).withValues(alpha: .25),
          ),
          boxShadow: [
            BoxShadow(
              color: mapSage.withValues(alpha: palette.dark ? .18 : .10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.tint(mapSage),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.near_me_rounded,
                    size: 17,
                    color: palette.accent(mapSage),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('map_refresh_apart'),
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .12),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                distance,
                key: ValueKey(distance),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                  color: palette.ink,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                live
                    ? 'map_refresh_straight_distance'
                    : 'map_refresh_stale_distance',
              ),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: palette.muted,
              ),
            ),
            if (eta != '--') ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.border),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _metric(
                      context,
                      Icons.route_outlined,
                      'map_refresh_route',
                      routeDistance,
                      mapBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metric(
                      context,
                      Icons.schedule_rounded,
                      'map_refresh_eta',
                      eta,
                      mapLavender,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accent,
  ) {
    final palette = MapPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: palette.accent(accent)),
        const SizedBox(height: 5),
        Text(
          context.tr(label),
          style: TextStyle(fontSize: 10.5, color: palette.muted),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
      ],
    );
  }
}

/// Bảng màu riêng của bản đồ; không phụ thuộc nền kem của các màn tiện ích.
class MapPalette {
  const MapPalette(this.dark);

  factory MapPalette.of(BuildContext context) {
    // Map B là thiết kế riêng của màn bản đồ, độc lập với theme của màn khác.
    Theme.of(context);
    return const MapPalette(true);
  }

  final bool dark;

  Color get canvas => dark ? const Color(0xFF11191B) : const Color(0xFFFFF7FB);
  Color get surface => dark ? const Color(0xFF202A2D) : const Color(0xFFFFFFFF);
  Color get ink => dark ? const Color(0xFFF1FAF7) : mapInk;
  Color get muted => dark ? const Color(0xFFA9BCB7) : const Color(0xFF806A7C);
  Color get border => dark ? const Color(0xFF3D4D4F) : const Color(0xFFF0DCE8);

  Color accent(Color color) {
    if (!dark) return color;
    if (color == mapSage) return const Color(0xFF7CE8C7);
    if (color == mapRose) return const Color(0xFFF08DA8);
    if (color == mapBlue) return const Color(0xFFA6C4C9);
    if (color == mapLavender) return const Color(0xFFA7DED1);
    return Color.lerp(color, Colors.white, .28)!;
  }

  Color tint(Color color) =>
      Color.alphaBlend(color.withValues(alpha: dark ? .10 : .08), surface);
}

class MapSlidingPanel extends StatelessWidget {
  const MapSlidingPanel({
    super.key,
    required this.controller,
    required this.extent,
    required this.single,
    required this.onToggle,
    required this.children,
  });

  final DraggableScrollableController controller;
  final ValueNotifier<double> extent;
  final bool single;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    // Trạng thái mặc định phải giống mẫu B: chỉ lộ phần tóm tắt thấp ở đáy
    // màn hình. Người dùng vẫn có thể kéo lên để xem các thẻ chi tiết.
    final headingHeight =
        (104 + (MediaQuery.textScalerOf(context).scale(18) - 18) * 4)
            .clamp(104.0, 164.0)
            .toDouble();
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        extent.value = notification.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        controller: controller,
        initialChildSize: .28,
        minChildSize: .20,
        maxChildSize: .84,
        snap: true,
        snapSizes: const [.20, .28, .84],
        builder: (context, scrollController) => Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette.surface, palette.canvas],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: mapInk.withValues(alpha: palette.dark ? .24 : .14),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: MapCuteCanvasPainter(dark: palette.dark),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                bottom: 8,
                              ),
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        palette.border,
                                        palette.accent(mapSage),
                                        palette.border,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Tiêu đề và nút thu bảng vẫn nhìn thấy khi cuộn nội dung.
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _MapPanelHeadingDelegate(
                              height: headingHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [palette.surface, palette.canvas],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  child: ValueListenableBuilder<double>(
                                    valueListenable: extent,
                                    builder: (context, value, _) =>
                                        MapPanelHeading(
                                          single: single,
                                          expanded: value > .55,
                                          onToggle: onToggle,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              MediaQuery.paddingOf(context).bottom + 24,
                            ),
                            sliver: SliverList.list(children: children),
                          ),
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
    );
  }
}

class _MapPanelHeadingDelegate extends SliverPersistentHeaderDelegate {
  const _MapPanelHeadingDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_MapPanelHeadingDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

class MapPanelHeading extends StatelessWidget {
  const MapPanelHeading({
    super.key,
    required this.single,
    required this.expanded,
    required this.onToggle,
  });

  final bool single;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    // Ở cỡ chữ lớn hoặc màn hình hẹp, giữ nút chỉ đường ở dạng biểu tượng
    // để hàng tiêu đề không bị tràn ngang. Tooltip vẫn giữ tên đầy đủ.
    final compactActions = MediaQuery.textScalerOf(context).scale(14) > 18;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  single
                      ? 'map_refresh_compact_title_single'
                      : 'map_refresh_compact_title',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: palette.tint(mapSage),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 14,
                      color: palette.accent(mapSage),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      context.tr('map_refresh_location_subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: context.tr('map_refresh_directions'),
          child: SizedBox(
            width: compactActions ? 40 : null,
            child: FilledButton(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent(mapSage),
                foregroundColor: mapInk,
                elevation: 0,
                minimumSize: const Size(0, 40),
                padding: EdgeInsets.symmetric(
                  horizontal: compactActions ? 0 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: mapInk,
                ),
              ),
              child: compactActions
                  ? const Icon(Icons.near_me_rounded, size: 17)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_rounded, size: 16),
                        const SizedBox(width: 5),
                        Text(context.tr('map_refresh_directions')),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const ValueKey('map_panel_toggle'),
          tooltip: context.tr(
            expanded ? 'map_refresh_collapse' : 'map_refresh_expand',
          ),
          onPressed: onToggle,
          style: IconButton.styleFrom(
            foregroundColor: palette.muted,
            backgroundColor: palette.tint(mapSage),
            minimumSize: const Size(40, 40),
            fixedSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            side: BorderSide(color: palette.border),
          ),
          icon: Icon(
            expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
            size: 21,
          ),
        ),
      ],
    );
  }
}

class MapAccessNotice extends StatelessWidget {
  const MapAccessNotice({
    super.key,
    required this.access,
    required this.busy,
    required this.hasLivePosition,
    required this.onAction,
    this.web = false,
    this.syncError = false,
    this.onSettings,
  });

  final MapLocationAccess access;
  final bool busy;
  final bool hasLivePosition;
  final bool web;
  final bool syncError;
  final VoidCallback onAction;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final status = access.status;
    final connected = access.canTrack && hasLivePosition && !syncError;
    final String titleKey;
    final String bodyKey;
    final String actionKey;
    final IconData icon;
    if (busy || status == MapLocationAccessStatus.checking) {
      titleKey = 'map_refresh_checking';
      bodyKey = 'map_refresh_checking_body';
      actionKey = 'map_refresh_retry';
      icon = Icons.gps_not_fixed_rounded;
    } else if (status == MapLocationAccessStatus.serviceDisabled) {
      titleKey = 'map_refresh_service_off';
      bodyKey = 'map_refresh_service_off_body';
      actionKey = 'map_refresh_open_gps';
      icon = Icons.location_disabled_outlined;
    } else if (status == MapLocationAccessStatus.deniedForever) {
      titleKey = 'map_refresh_permission_blocked';
      bodyKey = web
          ? 'map_refresh_browser_body'
          : 'map_refresh_permission_blocked_body';
      actionKey = web ? 'map_refresh_retry' : 'map_refresh_open_settings';
      icon = Icons.lock_outline_rounded;
    } else if (status == MapLocationAccessStatus.permissionRequired) {
      titleKey = 'map_refresh_permission_title';
      bodyKey = web
          ? 'map_refresh_browser_body'
          : 'map_refresh_permission_body';
      actionKey = 'map_refresh_allow_location';
      icon = Icons.location_on_outlined;
    } else if (status == MapLocationAccessStatus.unavailable || syncError) {
      titleKey = 'map_refresh_unavailable';
      bodyKey = 'map_refresh_unavailable_body';
      actionKey = 'map_refresh_retry';
      icon = Icons.cloud_off_outlined;
    } else if (access.approximate) {
      titleKey = 'map_refresh_approximate';
      bodyKey = 'map_refresh_approximate_body';
      actionKey = web ? 'map_refresh_retry' : 'map_refresh_open_settings';
      icon = Icons.location_searching_rounded;
    } else if (connected) {
      titleKey = 'map_refresh_sharing';
      bodyKey = 'map_refresh_sharing_body';
      actionKey = 'map_refresh_open_settings';
      icon = Icons.verified_user_outlined;
    } else {
      titleKey = 'map_refresh_waiting';
      bodyKey = 'map_refresh_waiting_body';
      actionKey = 'map_refresh_retry';
      icon = Icons.gps_not_fixed_rounded;
    }
    final pending = busy || status == MapLocationAccessStatus.checking;
    final waiting = status == MapLocationAccessStatus.ready && !syncError;
    final needsPermission =
        status == MapLocationAccessStatus.permissionRequired ||
        status == MapLocationAccessStatus.deniedForever;
    final baseAccent = connected
        ? mapSage
        : pending || waiting
        ? mapBlue
        : needsPermission
        ? const Color(0xFF956C35)
        : mapRose;
    final accent = palette.accent(baseAccent);
    return Container(
      key: const ValueKey('map_access_notice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.tint(baseAccent), palette.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .20)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: palette.dark ? .12 : .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(titleKey),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(bodyKey),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
              ],
            ],
          ),
          if (!connected &&
              !busy &&
              status != MapLocationAccessStatus.checking) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('map_access_action'),
                style: FilledButton.styleFrom(
                  backgroundColor: baseAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed:
                    actionKey == 'map_refresh_open_settings' &&
                        !web &&
                        onSettings != null
                    ? onSettings
                    : onAction,
                icon: Icon(icon, size: 18),
                label: Text(context.tr(actionKey), textAlign: TextAlign.center),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MapPersonTile extends StatelessWidget {
  const MapPersonTile({
    super.key,
    required this.name,
    required this.isMe,
    required this.role,
    required this.avatarUrl,
    required this.isLive,
    required this.hasPosition,
    required this.address,
    required this.updated,
    this.onFocus,
    this.accuracy,
  });

  final String name;
  final bool isMe;
  final String role;
  final String avatarUrl;
  final bool isLive;
  final bool hasPosition;
  final String address;
  final String updated;
  final VoidCallback? onFocus;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final baseAccent = isMe ? mapBlue : mapRose;
    final accent = palette.accent(baseAccent);
    final active = isLive && hasPosition;
    final status = context.tr(
      active
          ? 'map_refresh_live'
          : hasPosition
          ? 'map_refresh_last_position'
          : 'map_refresh_not_shared',
    );
    final sticker = Image.asset(
      'assets/images/soullocket_stickers/auth_gender_${role == 'user1' ? 'male' : 'female'}_v1.webp',
      fit: BoxFit.contain,
      cacheWidth: 120,
      errorBuilder: (_, _, _) => Icon(Icons.person_outline, color: accent),
    );
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasPosition ? onFocus : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: MapCuteCanvasPainter(
                    dark: palette.dark,
                    dense: true,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: palette.tint(baseAccent),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accent.withValues(alpha: .18),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: avatarUrl.trim().isEmpty
                                    ? sticker
                                    : CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 120,
                                        maxWidthDiskCache: 240,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        placeholder: (_, _) => sticker,
                                        errorWidget: (_, _, _) => sticker,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active ? mapSage : palette.muted,
                                  border: Border.all(
                                    color: palette.surface,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe
                                  ? L10nService().format(
                                      'map_refresh_me_name',
                                      {'name': name},
                                    )
                                  : name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? palette.accent(mapSage)
                                    : palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasPosition && onFocus != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: Icon(
                            Icons.near_me_outlined,
                            size: 20,
                            color: accent,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasPosition)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.tint(baseAccent), palette.surface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: accent.withValues(alpha: .10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              updated,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: palette.muted,
                              ),
                            ),
                            if (accuracy != null && accuracy!.isFinite)
                              Text(
                                L10nService().format('map_refresh_accuracy', {
                                  'meters': accuracy!.round().toString(),
                                }),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: palette.muted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MapDetailsSection extends StatelessWidget {
  const MapDetailsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accent = mapSage,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: palette.border),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: PageStorageKey(title),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: shape,
        collapsedShape: shape,
        backgroundColor: palette.surface,
        collapsedBackgroundColor: palette.surface,
        iconColor: palette.muted,
        collapsedIconColor: palette.muted,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [palette.tint(accent), palette.tint(mapSage)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: palette.accent(accent), size: 19),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        children: [child],
      ),
    );
  }
}
