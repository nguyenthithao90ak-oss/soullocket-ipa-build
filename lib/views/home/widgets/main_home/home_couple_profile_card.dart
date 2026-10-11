import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:soullocket_app/utils/zodiac_utils.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'home_couple_decor_model.dart';
import 'home_couple_decor_art.dart';

/// Dùng chung cho Home và màn trang trí để nền, khung, sticker khớp nhau.
class HomeCoupleProfileCard extends StatelessWidget {
  final Widget left;
  final Widget center;
  final Widget right;
  final HomeCoupleCardDecor decor;
  final VoidCallback? onCustomize;
  final int? selectedStickerIndex;
  final ValueChanged<int>? onSelectSticker;
  final void Function(int index, Offset delta, Size canvas)? onMoveSticker;
  final bool drawingEnabled;
  final ValueListenable<HomeCoupleDrawingStroke?>? activeDrawingListenable;
  final void Function(Offset point, Size canvas)? onDrawStart;
  final void Function(Offset point, Size canvas)? onDrawUpdate;
  final VoidCallback? onDrawEnd;
  final VoidCallback? onDrawCancel;

  const HomeCoupleProfileCard({
    super.key,
    required this.left,
    required this.center,
    required this.right,
    this.decor = const HomeCoupleCardDecor(
      backgroundKey: 'blush',
      frameKey: 'doodle',
      stickers: <HomeCoupleStickerPlacement>[],
    ),
    this.onCustomize,
    this.selectedStickerIndex,
    this.onSelectSticker,
    this.onMoveSticker,
    this.drawingEnabled = false,
    this.activeDrawingListenable,
    this.onDrawStart,
    this.onDrawUpdate,
    this.onDrawEnd,
    this.onDrawCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = HomeCoupleDecorCatalog.backgroundColors(
      decor.backgroundKey,
      dark: dark,
    );
    final ink = dark ? const Color(0xFFF5DFE7) : const Color(0xFF715665);
    final canLongPressCustomize =
        onCustomize != null && onSelectSticker == null && !drawingEnabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: canLongPressCustomize ? onCustomize : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: dark ? const Color(0xFF97738C) : const Color(0xFFF0C4D4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFFC889A6,
              ).withValues(alpha: dark ? .08 : .14),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            children: [
              CustomPaint(
                painter: _HomeCoupleProfilePainter(
                  isDark: dark,
                  frameKey: decor.frameKey,
                ),
                child: IgnorePointer(
                  ignoring: onSelectSticker != null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          46,
                          4,
                          4,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (onCustomize != null)
                              IconButton(
                                key: const ValueKey('home-couple-decorate'),
                                onPressed: onCustomize,
                                tooltip: context.tr('home_decorate_card'),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  foregroundColor: ink,
                                ),
                                icon: const Icon(
                                  Icons.palette_outlined,
                                  size: 21,
                                ),
                              )
                            else
                              const SizedBox(width: 48, height: 48),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
                        child: LayoutBuilder(
                          builder: (context, constraints) => Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: left),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: constraints.maxWidth < 310 ? 56 : 72,
                                child: center,
                              ),
                              const SizedBox(width: 4),
                              Expanded(child: right),
                            ],
                          ),
                        ),
                      ),
                      if (decor.message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(30, 0, 30, 16),
                          child: Text(
                            decor.message,
                            key: const ValueKey('home-couple-decor-message'),
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _HomeCoupleDrawingLayer(
                    drawings: decor.drawings,
                    activeDrawingListenable: activeDrawingListenable,
                  ),
                ),
              ),
              if (decor.frameKey == 'rainbow_vip') ...[
                const PositionedDirectional(
                  top: 8,
                  start: 12,
                  child: IgnorePointer(
                    child: HomeCoupleDecorArt(id: 'rainbow', size: 38),
                  ),
                ),
                const PositionedDirectional(
                  top: 12,
                  end: 16,
                  child: IgnorePointer(
                    child: HomeCoupleDecorArt(id: 'bow', size: 30),
                  ),
                ),
              ],
              if (decor.frameKey == 'doodle')
                const PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: Size(36, 42),
                      painter: _HomeRibbonPainter(color: Color(0xFFE5A1BB)),
                    ),
                  ),
                ),
              if (decor.frameKey == 'sparkle')
                const PositionedDirectional(
                  top: 10,
                  start: 4,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: Size(54, 27),
                      painter: _HomeConstellationPainter(
                        color: Color(0xFFC9A567),
                      ),
                    ),
                  ),
                ),
              if (decor.frameKey == 'doodle')
                const PositionedDirectional(
                  bottom: 3,
                  end: 4,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: Size(24, 24),
                      painter: _HomeHeartPainter(color: Color(0xFFEBAAC0)),
                    ),
                  ),
                ),
              for (var i = 0; i < decor.stickers.length; i++)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final sticker = decor.stickers[i];
                      final rect = HomeCoupleDecorGeometry.stickerRect(
                        constraints.biggest,
                        sticker,
                      );
                      final interactive =
                          onSelectSticker != null && !drawingEnabled;
                      final selected = selectedStickerIndex == i;
                      final hitSize = interactive
                          ? rect.width.clamp(48.0, 80.0)
                          : rect.width;
                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: Rect.fromCenter(
                              center: rect.center,
                              width: hitSize,
                              height: hitSize,
                            ),
                            child: IgnorePointer(
                              ignoring: !interactive,
                              child: Semantics(
                                button: interactive,
                                selected: selected,
                                label: interactive
                                    ? context.tr(
                                        HomeCoupleDecorCatalog.sticker(
                                              sticker.id,
                                            )?.labelKey ??
                                            'home_decor_sticker_title',
                                      )
                                    : null,
                                excludeSemantics: !interactive,
                                child: GestureDetector(
                                  key: ValueKey('home-couple-sticker-$i'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: interactive
                                      ? () => onSelectSticker!(i)
                                      : null,
                                  onLongPress: interactive
                                      ? () => onSelectSticker!(i)
                                      : null,
                                  onPanStart: interactive
                                      ? (_) => onSelectSticker!(i)
                                      : null,
                                  child: Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerMove: interactive
                                        ? (event) {
                                            onMoveSticker?.call(
                                              i,
                                              event.delta,
                                              constraints.biggest,
                                            );
                                          }
                                        : null,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? Colors.white.withValues(
                                                alpha: .35,
                                              )
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        border: selected
                                            ? Border.all(
                                                color: const Color(0xFFD57C9D),
                                                width: 1.8,
                                              )
                                            : null,
                                      ),
                                      child: Center(
                                        child: Transform.rotate(
                                          angle: sticker.rotation,
                                          child: HomeCoupleDecorArt(
                                            id: sticker.id,
                                            size: rect.width,
                                            animate:
                                                HomeCoupleDecorCatalog.sticker(
                                                  sticker.id,
                                                )?.isAnimated ??
                                                false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              if (drawingEnabled)
                Positioned.fill(
                  child: _HomeCoupleDrawingInput(
                    onStart: onDrawStart,
                    onUpdate: onDrawUpdate,
                    onEnd: onDrawEnd,
                    onCancel: onDrawCancel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCoupleDrawingLayer extends StatelessWidget {
  final List<HomeCoupleDrawingStroke> drawings;
  final ValueListenable<HomeCoupleDrawingStroke?>? activeDrawingListenable;

  const _HomeCoupleDrawingLayer({
    required this.drawings,
    this.activeDrawingListenable,
  });

  Widget _paint(HomeCoupleDrawingStroke? activeDrawing) => RepaintBoundary(
    child: CustomPaint(
      key: const ValueKey('home-couple-drawing-layer'),
      painter: _HomeCoupleDrawingPainter(
        drawings: drawings,
        activeDrawing: activeDrawing,
      ),
      child: const SizedBox.expand(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final listenable = activeDrawingListenable;
    if (listenable == null) return _paint(null);
    return ValueListenableBuilder<HomeCoupleDrawingStroke?>(
      valueListenable: listenable,
      builder: (context, drawing, child) => _paint(drawing),
    );
  }
}

class _HomeCoupleDrawingInput extends StatefulWidget {
  final void Function(Offset point, Size canvas)? onStart;
  final void Function(Offset point, Size canvas)? onUpdate;
  final VoidCallback? onEnd;
  final VoidCallback? onCancel;

  const _HomeCoupleDrawingInput({
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
  });

  @override
  State<_HomeCoupleDrawingInput> createState() =>
      _HomeCoupleDrawingInputState();
}

class _HomeCoupleDrawingInputState extends State<_HomeCoupleDrawingInput> {
  int? _pointer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Semantics(
      label: context.tr('home_decor_draw_hint'),
      child: RawGestureDetector(
        gestures: {
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (recognizer) {},
              ),
        },
        behavior: HitTestBehavior.opaque,
        child: Listener(
          key: const ValueKey('home-couple-drawing-input'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_pointer != null || event.buttons & kPrimaryButton == 0) return;
            _pointer = event.pointer;
            widget.onStart?.call(event.localPosition, constraints.biggest);
          },
          onPointerMove: (event) {
            if (_pointer == event.pointer) {
              widget.onUpdate?.call(event.localPosition, constraints.biggest);
            }
          },
          onPointerUp: (event) {
            if (_pointer != event.pointer) return;
            widget.onUpdate?.call(event.localPosition, constraints.biggest);
            _pointer = null;
            widget.onEnd?.call();
          },
          onPointerCancel: (event) {
            if (_pointer != event.pointer) return;
            _pointer = null;
            widget.onCancel?.call();
          },
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _HomeCoupleDrawingPainter extends CustomPainter {
  final List<HomeCoupleDrawingStroke> drawings;
  final HomeCoupleDrawingStroke? activeDrawing;

  const _HomeCoupleDrawingPainter({required this.drawings, this.activeDrawing});

  @override
  void paint(Canvas canvas, Size size) {
    final allDrawings = activeDrawing == null
        ? drawings
        : [...drawings, activeDrawing!];
    for (final drawing in allDrawings) {
      final points = drawing.points;
      if (points.isEmpty) continue;
      final color = Color(
        drawing.colorValue & 0xFFFFFFFF,
      ).withValues(alpha: .9);
      final paint = Paint()
        ..isAntiAlias = true
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (size.shortestSide * drawing.width).clamp(1.5, 18.0);
      final first = _point(points.first, size);
      if (points.length == 1) {
        final dotPaint = Paint()
          ..isAntiAlias = true
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(first, paint.strokeWidth / 2, dotPaint);
        continue;
      }
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in points.skip(1)) {
        final next = _point(point, size);
        path.lineTo(next.dx, next.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  Offset _point(Offset normalized, Size size) => Offset(
    normalized.dx.clamp(0.0, 1.0) * size.width,
    normalized.dy.clamp(0.0, 1.0) * size.height,
  );

  @override
  bool shouldRepaint(covariant _HomeCoupleDrawingPainter oldDelegate) =>
      oldDelegate.drawings != drawings ||
      oldDelegate.activeDrawing != activeDrawing;
}

/// Capsule cung hoàng đạo dùng cùng một nét vẽ trên mọi locale, không dùng
/// emoji màu nên không bị lệch phong cách giữa Android/iOS/Web.
class HomeZodiacCapsule extends StatelessWidget {
  final String zodiacName;
  final String age;
  final bool isUser1;

  const HomeZodiacCapsule({
    super.key,
    required this.zodiacName,
    required this.age,
    required this.isUser1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isUser1 ? const Color(0xFF8751C8) : const Color(0xFF1B8E97);
    final fill = isUser1 ? const Color(0xFFF7EDFF) : const Color(0xFFEAFBF8);
    final localizedName = ZodiacUtils.localizedName(zodiacName);
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? accent.withValues(alpha: 0.15) : fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(29, 23),
            painter: _HomeZodiacGlyphPainter(sign: zodiacName, color: accent),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              localizedName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF473044),
                height: 1.05,
              ),
            ),
          ),
          if (age.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 18,
              color: accent.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 6),
            Text(
              age,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: accent,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeCoupleProfilePainter extends CustomPainter {
  final bool isDark;
  final String frameKey;

  const _HomeCoupleProfilePainter({
    required this.isDark,
    required this.frameKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 100 || size.height < 70) return;
    final rose = (isDark ? const Color(0xFFE7ABC0) : const Color(0xFFFF9FBA))
        .withValues(alpha: 0.52);
    if (frameKey == 'clean') return;
    final line = Paint()
      ..color = rose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(0, 30);
    final path = Path()
      ..moveTo(size.width * 0.08, 73)
      ..cubicTo(
        size.width * 0.22,
        48,
        size.width * 0.33,
        93,
        size.width * 0.50,
        72,
      )
      ..cubicTo(
        size.width * 0.67,
        51,
        size.width * 0.78,
        94,
        size.width * 0.92,
        70,
      );
    canvas.drawPath(path, line);

    final center = Offset(size.width * 0.5, 69);
    final heart = Path()
      ..moveTo(center.dx, center.dy + 6)
      ..cubicTo(
        center.dx - 10,
        center.dy - 1,
        center.dx - 6,
        center.dy - 8,
        center.dx,
        center.dy - 3,
      )
      ..cubicTo(
        center.dx + 6,
        center.dy - 8,
        center.dx + 10,
        center.dy - 1,
        center.dx,
        center.dy + 6,
      );
    canvas.drawPath(
      heart,
      Paint()
        ..color = rose.withValues(alpha: 0.33)
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
    if (frameKey == 'scallop') {
      final waves = Path();
      for (var x = 22.0; x < size.width - 32; x += 14) {
        waves
          ..moveTo(x, 9)
          ..quadraticBezierTo(x + 7, 3, x + 14, 9)
          ..moveTo(x, size.height - 9)
          ..quadraticBezierTo(x + 7, size.height - 3, x + 14, size.height - 9);
      }
      canvas.drawPath(waves, line);
    }

    final starPaint = Paint()
      ..color = rose.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    if (frameKey == 'sparkle') {
      _drawStar(
        canvas,
        Offset(size.width - 24, size.height - 18),
        6,
        starPaint,
      );
    }
    if (frameKey == 'rainbow_vip') {
      final frameRect = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
      final framePaint = Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF79A8),
            Color(0xFFFFC76E),
            Color(0xFF9DD69B),
            Color(0xFF83C9E8),
            Color(0xFFB99BEA),
            Color(0xFFFF79A8),
          ],
        ).createShader(frameRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(24)),
        framePaint,
      );
      _drawStar(canvas, Offset(size.width * .17, 18), 5, framePaint);
      _drawStar(canvas, Offset(size.width * .83, 18), 5, framePaint);
      canvas.drawCircle(
        Offset(size.width * .15, size.height - 18),
        3,
        Paint()..color = const Color(0xFFFF9FC2),
      );
      canvas.drawCircle(
        Offset(size.width * .86, size.height - 19),
        3,
        Paint()..color = const Color(0xFF9ECFEA),
      );
    }
    _drawStar(canvas, const Offset(28, 32), 5, starPaint);
    _drawStar(canvas, Offset(size.width - 30, 43), 4, starPaint);
    _drawStar(
      canvas,
      Offset(size.width * 0.5, size.height - 12),
      3.5,
      starPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height - 15),
      2.2,
      Paint()..color = rose.withValues(alpha: 0.58),
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.28, center.dy - radius * 0.28)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.28, center.dy - radius * 0.28)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeCoupleProfilePainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.frameKey != frameKey;
}

class _HomeZodiacGlyphPainter extends CustomPainter {
  final String sign;
  final Color color;

  const _HomeZodiacGlyphPainter({required this.sign, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final name = sign.trim();
    if (name == 'Bảo Bình') {
      path
        ..moveTo(1, 7)
        ..cubicTo(5, 1, 8, 13, 12, 7)
        ..cubicTo(16, 1, 19, 13, 23, 7)
        ..moveTo(1, 15)
        ..cubicTo(5, 9, 8, 21, 12, 15)
        ..cubicTo(16, 9, 19, 21, 23, 15);
    } else if (name == 'Thiên Yết' || name == 'Bọ Cạp') {
      path
        ..moveTo(2, 3)
        ..lineTo(2, 16)
        ..moveTo(2, 8)
        ..cubicTo(2, 2, 7, 2, 7, 8)
        ..lineTo(7, 16)
        ..moveTo(7, 8)
        ..cubicTo(7, 2, 12, 2, 12, 8)
        ..lineTo(12, 16)
        ..cubicTo(12, 21, 19, 20, 23, 16)
        ..moveTo(19, 12)
        ..lineTo(23, 16)
        ..lineTo(18, 17);
    } else {
      const glyphs = <String, String>{
        'Ma Kết': '♑',
        'Song Ngư': '♓',
        'Bạch Dương': '♈',
        'Kim Ngưu': '♉',
        'Song Tử': '♊',
        'Cự Giải': '♋',
        'Sư Tử': '♌',
        'Xử Nữ': '♍',
        'Thiên Bình': '♎',
        'Nhân Mã': '♐',
      };
      final glyph = glyphs[name] ?? '✦';
      _drawFallbackGlyph(canvas, size, paint, glyph);
      return;
    }
    canvas.drawPath(path, paint);
  }

  void _drawFallbackGlyph(Canvas canvas, Size size, Paint paint, String glyph) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeZodiacGlyphPainter oldDelegate) =>
      oldDelegate.sign != sign || oldDelegate.color != color;
}

class _HomeRibbonPainter extends CustomPainter {
  final Color color;

  const _HomeRibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.30);
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.47, size.height * 0.30);
    final left = Path()
      ..moveTo(center.dx - 2, center.dy)
      ..cubicTo(4, 2, -2, 11, 8, 23)
      ..cubicTo(16, 31, 25, 24, center.dx + 2, center.dy + 2)
      ..close();
    final right = Path()
      ..moveTo(center.dx + 1, center.dy)
      ..cubicTo(38, -2, size.width + 1, 1, size.width - 9, 17)
      ..cubicTo(size.width - 16, 27, 39, 25, center.dx, center.dy + 2)
      ..close();
    canvas.drawPath(left, fill);
    canvas.drawPath(right, fill);
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
    canvas.drawCircle(center, 5, fill);
    canvas.drawCircle(center, 5, stroke);
    final tail = Path()
      ..moveTo(center.dx - 1, center.dy + 4)
      ..cubicTo(20, 35, 19, 44, 9, size.height - 2)
      ..moveTo(center.dx + 3, center.dy + 4)
      ..cubicTo(38, 36, 45, 39, size.width - 5, size.height - 12);
    canvas.drawPath(tail, stroke);
  }

  @override
  bool shouldRepaint(covariant _HomeRibbonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HomeConstellationPainter extends CustomPainter {
  final Color color;

  const _HomeConstellationPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(2, 21)
      ..lineTo(16, 7)
      ..lineTo(28, 17)
      ..lineTo(42, 3)
      ..lineTo(53, 13);
    canvas.drawPath(path, paint);
    for (final point in const [
      Offset(2, 21),
      Offset(16, 7),
      Offset(28, 17),
      Offset(42, 3),
      Offset(53, 13),
    ]) {
      canvas.drawCircle(
        point,
        1.8,
        Paint()..color = color.withValues(alpha: 0.85),
      );
    }
    final moon = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(const Rect.fromLTWH(37, 2, 15, 19), -1.15, 3.9, false, moon);
  }

  @override
  bool shouldRepaint(covariant _HomeConstellationPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HomeHeartPainter extends CustomPainter {
  final Color color;

  const _HomeHeartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final path = Path()
      ..moveTo(center.dx, center.dy + 9)
      ..cubicTo(
        center.dx - 16,
        center.dy - 2,
        center.dx - 9,
        center.dy - 12,
        center.dx,
        center.dy - 5,
      )
      ..cubicTo(
        center.dx + 9,
        center.dy - 12,
        center.dx + 16,
        center.dy - 2,
        center.dx,
        center.dy + 9,
      );
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.65));
    final spark = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(2, 7), const Offset(9, 7), spark);
    canvas.drawLine(const Offset(5.5, 3.5), const Offset(5.5, 10.5), spark);
  }

  @override
  bool shouldRepaint(covariant _HomeHeartPainter oldDelegate) =>
      oldDelegate.color != color;
}
