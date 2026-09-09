import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_countdown_shapes.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Cùng một bảng màu cho vòng đếm thật và hình thu nhỏ trong bộ chọn.
class BalancedCountdownPalette {
  const BalancedCountdownPalette({this.dark = false, this.transparent = false});

  final bool dark;
  final bool transparent;

  Color get rose => dark ? const Color(0xFFF0B1C4) : const Color(0xFFA83F60);
  Color get ink => dark ? const Color(0xFFF8EFF3) : const Color(0xFF3E3038);
  Color get muted => dark ? const Color(0xFFC6B7C0) : const Color(0xFF806B76);
  Color get paper => dark ? const Color(0xFF2D252D) : const Color(0xFFFFFCF9);
  Color get blush => dark ? const Color(0xFF45303C) : const Color(0xFFF9E9EF);
  Color get border => dark ? const Color(0xFF775260) : const Color(0xFFE6BCCB);
  Color get label => transparent ? Colors.white : muted;
  List<Color> get numberColors => transparent
      ? const [Colors.white, Color(0xFFFFE5EE)]
      : [rose, dark ? const Color(0xFFD894B6) : const Color(0xFFC57491)];

  LinearGradient get outerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: transparent
        ? [
            Colors.white.withValues(alpha: .28),
            Colors.white.withValues(alpha: .09),
          ]
        : [
            paper,
            blush,
            dark ? const Color(0xFF634453) : const Color(0xFFF0D2DD),
          ],
  );

  LinearGradient get innerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: transparent
        ? [
            Colors.white.withValues(alpha: .08),
            Colors.white.withValues(alpha: .03),
          ]
        : [paper, paper, blush],
  );
}

/// Nền tĩnh, không blur hay animation: nhẹ cả khi dùng Lite/giảm chuyển động.
/// Giữ hình dáng người dùng đã chọn; phần số và thao tác do màn chính quản lý.
class BalancedCountdownSurface extends StatelessWidget {
  const BalancedCountdownSurface({
    super.key,
    this.shapeKey = 'circle',
    this.transparent = false,
    this.child,
  });

  final String shapeKey;
  final bool transparent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(
      dark: Theme.of(context).brightness == Brightness.dark,
      transparent: transparent,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final inset = (size * .03).clamp(2.0, 9.0);
        ShapeBorder shapeFor(BorderSide side) => shapeKey == 'squircle'
            ? ContinuousRectangleBorder(
                side: side,
                borderRadius: BorderRadius.circular(size * .38),
              )
            : SlCountdownShapes.getShapeBorderForKey(shapeKey, side: side);
        return DecoratedBox(
          decoration: ShapeDecoration(
            shape: shapeFor(
              BorderSide(
                color: transparent
                    ? Colors.white.withValues(alpha: .45)
                    : palette.border,
                width: size < 80 ? 1 : 1.4,
              ),
            ),
            gradient: palette.outerGradient,
            shadows: transparent
                ? const []
                : [
                    BoxShadow(
                      color: palette.rose.withValues(alpha: .10),
                      blurRadius: size * .08,
                      spreadRadius: -size * .025,
                      offset: Offset(0, size * .035),
                    ),
                  ],
          ),
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                shape: shapeFor(
                  BorderSide(
                    color: palette.border.withValues(alpha: .45),
                    width: .8,
                  ),
                ),
                gradient: palette.innerGradient,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _BalancedKeepsakePainter(
                              palette: palette,
                              round: shapeKey == 'circle' || shapeKey.isEmpty,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ?child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalancedKeepsakePainter extends CustomPainter {
  const _BalancedKeepsakePainter({required this.palette, required this.round});
  final BalancedCountdownPalette palette;
  final bool round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 240);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = (palette.transparent ? Colors.white : palette.border)
          .withValues(alpha: .65);
    if (round) {
      const orbit = Rect.fromLTWH(12, 12, 216, 216);
      canvas.drawArc(orbit, -.48 * math.pi, .30 * math.pi, false, pen);
      canvas.drawArc(orbit, .52 * math.pi, .30 * math.pi, false, pen);
    }

    void heart(double x, double y, double scale, Color color) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      final path = Path()
        ..moveTo(0, 7)
        ..cubicTo(-18, -4, -10, -18, 0, -8)
        ..cubicTo(10, -18, 18, -4, 0, 7)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.restore();
    }

    final pink = palette.transparent
        ? Colors.white.withValues(alpha: .7)
        : palette.rose;
    heart(35, 148, .62, pink.withValues(alpha: .55));
    heart(204, 89, .73, pink.withValues(alpha: .72));
    final gold = Paint()..color = const Color(0xFFC8A16E).withValues(alpha: .8);
    for (final point in [const Offset(40, 136), const Offset(195, 100)]) {
      canvas.drawCircle(point, 1.8, gold);
    }
    final sparkle = Path()
      ..moveTo(190, 43)
      ..quadraticBezierTo(191, 49, 197, 50)
      ..quadraticBezierTo(191, 51, 190, 57)
      ..quadraticBezierTo(189, 51, 183, 50)
      ..quadraticBezierTo(189, 49, 190, 43)
      ..close();
    canvas.drawPath(sparkle, gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BalancedKeepsakePainter oldDelegate) =>
      oldDelegate.palette.dark != palette.dark ||
      oldDelegate.palette.transparent != palette.transparent ||
      oldDelegate.round != round;
}

class BalancedCountdownOption extends StatelessWidget {
  const BalancedCountdownOption({
    super.key,
    required this.selected,
    required this.onTap,
  });
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    final label = context.tr('countdown_default');
    final status = context.tr(
      selected ? 'balanced_countdown_selected' : 'balanced_countdown_available',
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $status',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? palette.blush : palette.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? palette.rose : palette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: BalancedCountdownSurface(
                    child: Center(
                      child: Icon(
                        Icons.favorite_rounded,
                        color: palette.rose,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr('balanced_countdown_subtitle'),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11.5,
                          height: 1.4,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? palette.rose : palette.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chỉ bọc phần trình bày, không nắm quyền mở khóa hoặc lưu lựa chọn.
class CountdownStylePickerSurface extends StatelessWidget {
  const CountdownStylePickerSurface({
    super.key,
    required this.title,
    required this.options,
    required this.onClose,
  });
  final String title;
  final List<Widget> options;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: Material(
            color: palette.paper,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: palette.border.withValues(alpha: .7)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              SizedBox.square(
                                dimension: 38,
                                child: BalancedCountdownSurface(
                                  child: Center(
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      color: palette.rose,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.tr('balanced_countdown_picker_hint'),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              height: 1.4,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...options,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('countdown_picker_close'),
                    onPressed: onClose,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.rose,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      context.tr('balanced_countdown_close'),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
