import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../../../utils/services/l10n_service.dart';
import 'home_display_layout.dart';
import 'home_display_style.dart';

/// Chỉ trả lựa chọn đã xác nhận; đóng bảng không làm đổi Home hay cài đặt.
Future<HomeDisplayStyle?> showHomeDisplayStylePicker(
  BuildContext context, {
  required HomeDisplayStyle selected,
}) {
  // Chỉ mở các kiểu Home đang thử nghiệm trong bản debug.
  if (!kDebugMode) return Future<HomeDisplayStyle?>.value();
  final l10n = L10nScope.of(context);
  return showModalBottomSheet<HomeDisplayStyle>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => L10nScope(
      notifier: l10n,
      child: FractionallySizedBox(
        heightFactor: .94,
        child: _HomeDisplayStylePicker(selected: selected),
      ),
    ),
  );
}

class _HomeDisplayStylePicker extends StatefulWidget {
  const _HomeDisplayStylePicker({required this.selected});

  final HomeDisplayStyle selected;

  @override
  State<_HomeDisplayStylePicker> createState() =>
      _HomeDisplayStylePickerState();
}

class _HomeDisplayStylePickerState extends State<_HomeDisplayStylePicker> {
  late HomeDisplayStyle _preview = widget.selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final previewPalette = _StylePalette.fromRuntime(
      HomeDisplayPalette.of(context, _preview),
      dark: dark,
    );
    final accent = previewPalette.accent;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          key: const ValueKey('home-display-style-sheet'),
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 12),
                        child: Text(
                          context.tr('home_display_style_title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('home-display-style-close'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('home-display-style-content'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      context.tr('home_display_style_hint'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: largeText ? 302 : 226,
                      child: ListView.separated(
                        key: const ValueKey('home-display-style-choices'),
                        scrollDirection: Axis.horizontal,
                        itemCount: HomeDisplayStyle.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final style = HomeDisplayStyle.values[index];
                          return SizedBox(
                            width: largeText ? 172 : 126,
                            child: _StyleChoice(
                              style: style,
                              selected: style == _preview,
                              active: style == widget.selected,
                              dark: dark,
                              onTap: () => setState(() => _preview = style),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('home_display_style_preview'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      key: const ValueKey('home-display-style-preview'),
                      label:
                          '${context.tr('home_display_style_preview')}: '
                          '${context.tr(_preview.titleKey)}',
                      image: true,
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: previewPalette.back,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: SizedBox(
                            height: 278,
                            child: CustomPaint(
                              key: ValueKey(
                                'home-display-style-art-${_preview.storageKey}',
                              ),
                              painter: _HomeStylePreviewPainter(
                                style: _preview,
                                palette: previewPalette,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr(_preview.titleKey),
                      key: const ValueKey('home-display-style-preview-title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(_preview.descriptionKey),
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.phone_iphone_rounded,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('home_display_style_local'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('home-display-style-apply'),
                      onPressed: () => Navigator.of(context).pop(_preview),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(context.tr('home_display_style_apply')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        backgroundColor: dark ? null : accent,
                        foregroundColor: dark ? null : Colors.white,
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleChoice extends StatelessWidget {
  const _StyleChoice({
    required this.style,
    required this.selected,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  final HomeDisplayStyle style;
  final bool selected;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = _StylePalette.fromRuntime(
      HomeDisplayPalette.of(context, style),
      dark: dark,
    );
    final title = context.tr(style.titleKey);
    return Semantics(
      key: ValueKey('home-display-style-choice-${style.storageKey}'),
      label: title,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? palette.back : colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? palette.accent : colors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: palette.back,
                        child: CustomPaint(
                          painter: _HomeStylePreviewPainter(
                            style: style,
                            palette: palette,
                            thumbnail: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (style == HomeDisplayStyle.current || active)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (selected) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            key: active
                                ? ValueKey(
                                    'home-display-style-active-${style.storageKey}',
                                  )
                                : null,
                            context.tr(
                              style == HomeDisplayStyle.current
                                  ? 'home_display_style_default'
                                  : 'home_display_style_selected',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StylePalette {
  const _StylePalette({
    required this.back,
    required this.card,
    required this.accent,
    required this.secondary,
    required this.dark,
  });

  final Color back;
  final Color card;
  final Color accent;
  final Color secondary;
  final bool dark;

  factory _StylePalette.fromRuntime(
    HomeDisplayPalette palette, {
    required bool dark,
  }) {
    return _StylePalette(
      back: palette.background,
      card: palette.surface,
      accent: palette.accent,
      secondary: Color.alphaBlend(
        palette.accent.withValues(alpha: dark ? .24 : .2),
        palette.surface,
      ),
      dark: dark,
    );
  }
}

enum _PreviewBlock { profile, countdown, note, upcoming, bento, pet }

/// Sơ đồ bố cục, không tạo ngày yêu, ảnh, tâm trạng hay trạng thái online giả.
class _HomeStylePreviewPainter extends CustomPainter {
  const _HomeStylePreviewPainter({
    required this.style,
    required this.palette,
    this.thumbnail = false,
  });

  final HomeDisplayStyle style;
  final _StylePalette palette;
  final bool thumbnail;

  List<_PreviewBlock> get _blocks {
    const p = _PreviewBlock.profile;
    const c = _PreviewBlock.countdown;
    const n = _PreviewBlock.note;
    const u = _PreviewBlock.upcoming;
    const b = _PreviewBlock.bento;
    const t = _PreviewBlock.pet;
    return switch (style) {
      HomeDisplayStyle.current => [c, p, t, u, b],
      HomeDisplayStyle.nest => [p, c, n, u, b, t],
      HomeDisplayStyle.portrait => [p, n, c, t, u, b],
      // Giữ đúng thứ tự các surface của hero thật, thay vì dùng một sơ đồ
      // chung khiến thumbnail không còn giống kiểu đã chọn.
      HomeDisplayStyle.scrapbook => [p, c, n, u, t, b],
      HomeDisplayStyle.cloud => [p, c, t, n, u, b],
      HomeDisplayStyle.daily => [p, n, u, c, b, t],
      HomeDisplayStyle.minimal => [p, c, n, u, b, t],
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final available = Size(size.width - 16, size.height - 20);
    final height = math.min(available.height, available.width / .65);
    final width = height * .65;
    final phone = Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
    final r = width * .11;
    final frame = RRect.fromRectAndRadius(phone, Radius.circular(r));
    canvas.drawShadow(
      Path()..addRRect(frame),
      Colors.black.withValues(alpha: palette.dark ? .25 : .1),
      thumbnail ? 2 : 7,
      true,
    );
    canvas.drawRRect(frame, Paint()..color = palette.card);
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawRect(phone, Paint()..color = palette.back);
    final content = phone.deflate(width * .065);
    var y = content.top + width * .10;
    _line(
      canvas,
      Offset(content.left, content.top + width * .04),
      width * .21,
      width * .025,
      palette.accent,
    );
    canvas.drawCircle(
      Offset(content.right - width * .035, content.top + width * .04),
      width * .03,
      Paint()..color = palette.secondary,
    );
    final blocks = _blocks;
    final weights = blocks.map(_weight).toList();
    final gaps = width * .045;
    final usable = content.bottom - y - gaps * blocks.length - width * .07;
    final total = weights.reduce((a, b) => a + b);
    for (var i = 0; i < blocks.length; i++) {
      final h = usable * weights[i] / total;
      final rect = Rect.fromLTWH(content.left, y, content.width, h);
      _block(canvas, rect, blocks[i], palette);
      y += h + gaps;
    }
    final navY = phone.bottom - width * .09;
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(phone.left + width * (.16 + .17 * i), navY),
        width * .017,
        Paint()..color = i == 0 ? palette.accent : palette.secondary,
      );
    }
    canvas.restore();
  }

  double _weight(_PreviewBlock block) => switch (block) {
    _PreviewBlock.profile => style == HomeDisplayStyle.portrait ? 3.4 : 1.65,
    _PreviewBlock.countdown => style == HomeDisplayStyle.current ? 2.8 : 1.45,
    _PreviewBlock.note => style == HomeDisplayStyle.daily ? 1.45 : .8,
    _PreviewBlock.upcoming => 1,
    _PreviewBlock.bento => 1.35,
    _PreviewBlock.pet => style == HomeDisplayStyle.cloud ? 2.5 : 1,
  };

  void _block(Canvas canvas, Rect rect, _PreviewBlock block, _StylePalette p) {
    final radius =
        rect.width * (style == HomeDisplayStyle.minimal ? .035 : .08);
    if (block == _PreviewBlock.bento) {
      final half = (rect.width - rect.width * .04) / 2;
      final a = Rect.fromLTWH(rect.left, rect.top, half, rect.height);
      final b = Rect.fromLTWH(rect.right - half, rect.top, half, rect.height);
      for (final tile in [a, b]) {
        _card(canvas, tile, radius, p.card);
        _line(
          canvas,
          tile.topLeft + Offset(half * .12, rect.height * .24),
          half * .53,
          rect.height * .08,
          p.secondary,
        );
        _line(
          canvas,
          tile.topLeft + Offset(half * .12, rect.height * .48),
          half * .72,
          rect.height * .16,
          p.accent.withValues(alpha: .45),
        );
      }
      return;
    }
    _card(canvas, rect, radius, p.card);
    switch (block) {
      case _PreviewBlock.profile:
        switch (style) {
          case HomeDisplayStyle.portrait:
            _portraitHero(canvas, rect, p);
          case HomeDisplayStyle.scrapbook:
            _scrapbookHero(canvas, rect, p);
          case HomeDisplayStyle.cloud:
            _cloudHero(canvas, rect, p);
          case HomeDisplayStyle.daily:
            _dailyHero(canvas, rect, p);
          case HomeDisplayStyle.minimal:
            _minimalHero(canvas, rect, p);
          case HomeDisplayStyle.nest:
            _nestHero(canvas, rect, p);
          case HomeDisplayStyle.current:
            _duoCircles(canvas, rect, p);
        }
      case _PreviewBlock.countdown:
        if (style == HomeDisplayStyle.current) {
          final ring = math.min(rect.height * .37, rect.width * .25);
          canvas.drawCircle(
            rect.center,
            ring,
            Paint()
              ..color = p.secondary
              ..style = PaintingStyle.stroke
              ..strokeWidth = ring * .15,
          );
          _heart(canvas, rect.center, ring * .38, p.accent);
        } else {
          _heart(
            canvas,
            Offset(rect.left + rect.width * .18, rect.center.dy),
            rect.height * .2,
            p.accent,
          );
          _line(
            canvas,
            Offset(
              rect.left + rect.width * .35,
              rect.center.dy - rect.height * .12,
            ),
            rect.width * .43,
            rect.height * .14,
            p.accent.withValues(alpha: .7),
          );
          _line(
            canvas,
            Offset(
              rect.left + rect.width * .35,
              rect.center.dy + rect.height * .16,
            ),
            rect.width * .3,
            rect.height * .06,
            p.secondary,
          );
        }
      case _PreviewBlock.note:
        if (style == HomeDisplayStyle.scrapbook) {
          _tape(canvas, rect, p);
        }
        if (style == HomeDisplayStyle.daily) _timeline(canvas, rect, p);
        _line(
          canvas,
          rect.topLeft + Offset(rect.width * .1, rect.height * .34),
          rect.width * .7,
          rect.height * .08,
          p.accent.withValues(alpha: .6),
        );
        _line(
          canvas,
          rect.topLeft + Offset(rect.width * .1, rect.height * .62),
          rect.width * .46,
          rect.height * .07,
          p.secondary,
        );
      case _PreviewBlock.upcoming:
        if (style == HomeDisplayStyle.daily) {
          _timeline(canvas, rect, p, compact: true);
          return;
        }
        final side = rect.height * .55;
        _card(
          canvas,
          Rect.fromLTWH(
            rect.left + rect.width * .09,
            rect.center.dy - side / 2,
            side,
            side,
          ),
          side * .2,
          p.secondary,
        );
        _line(
          canvas,
          Offset(
            rect.left + rect.width * .32,
            rect.center.dy - rect.height * .1,
          ),
          rect.width * .51,
          rect.height * .08,
          p.accent.withValues(alpha: .55),
        );
        _line(
          canvas,
          Offset(
            rect.left + rect.width * .32,
            rect.center.dy + rect.height * .15,
          ),
          rect.width * .3,
          rect.height * .06,
          p.secondary,
        );
      case _PreviewBlock.pet:
        final unit = math.min(rect.height * .3, rect.width * .12);
        if (style == HomeDisplayStyle.cloud) {
          final cloudPaint = Paint()
            ..color = p.secondary.withValues(alpha: .42);
          canvas.drawOval(
            Rect.fromCenter(
              center: rect.center + Offset(0, unit),
              width: unit * 5.2,
              height: unit * 1.5,
            ),
            cloudPaint,
          );
        }
        for (var i = 0; i < 2; i++) {
          final center =
              rect.center + Offset((i == 0 ? -1.25 : 1.25) * unit, unit * .12);
          final color = i == 0 ? p.secondary : p.accent.withValues(alpha: .38);
          for (final direction in [-1.0, 1.0]) {
            final ear = center + Offset(direction * unit * .55, -unit * .73);
            canvas.drawOval(
              Rect.fromCenter(
                center: ear,
                width: unit * .54,
                height: i == 0 ? unit * 1.1 : unit * .56,
              ),
              Paint()..color = color,
            );
          }
          canvas.drawCircle(center, unit * .8, Paint()..color = color);
          for (final direction in [-1.0, 1.0]) {
            canvas.drawCircle(
              center + Offset(direction * unit * .25, 0),
              unit * .06,
              Paint()..color = p.accent,
            );
          }
        }
      case _PreviewBlock.bento:
        break;
    }
  }

  void _duoCircles(Canvas canvas, Rect rect, _StylePalette p) {
    final radius = math.min(rect.height * .28, rect.width * .13);
    final frame = rect.deflate(rect.width * .08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, Radius.circular(rect.width * .08)),
      Paint()
        ..color = p.accent.withValues(alpha: .08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(
      Offset(frame.left + frame.width * .18, frame.bottom - rect.height * .16),
      Offset(frame.right - frame.width * .18, frame.bottom - rect.height * .16),
      Paint()
        ..color = p.accent.withValues(alpha: .35)
        ..strokeWidth = math.max(1, rect.width * .012),
    );
    canvas.drawCircle(
      Offset(rect.center.dx - radius * 1.25, rect.center.dy),
      radius,
      Paint()..color = p.secondary,
    );
    canvas.drawCircle(
      Offset(rect.center.dx + radius * 1.25, rect.center.dy),
      radius,
      Paint()..color = p.accent.withValues(alpha: .3),
    );
    _heart(canvas, rect.center, radius * .53, p.accent);
    final roof = Path()
      ..moveTo(frame.left + frame.width * .68, frame.top + frame.height * .28)
      ..lineTo(frame.left + frame.width * .82, frame.top + frame.height * .14)
      ..lineTo(frame.left + frame.width * .96, frame.top + frame.height * .28);
    canvas.drawPath(
      roof,
      Paint()
        ..color = p.accent.withValues(alpha: .48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, rect.width * .014)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Vòm ảnh dọc + đôi silhouette, tương ứng hero Portrait.
  void _portraitHero(Canvas canvas, Rect rect, _StylePalette p) {
    final inner = rect.deflate(rect.width * .035);
    final arch = RRect.fromRectAndCorners(
      inner,
      topLeft: Radius.circular(inner.width * .22),
      topRight: Radius.circular(inner.width * .22),
    );
    canvas.drawRRect(arch, Paint()..color = p.secondary.withValues(alpha: .72));
    canvas.drawLine(
      Offset(inner.center.dx, inner.top),
      Offset(inner.center.dx, inner.bottom),
      Paint()
        ..color = p.card.withValues(alpha: .55)
        ..strokeWidth = math.max(1, inner.width * .018),
    );
    final lower = Rect.fromLTWH(
      inner.left,
      inner.top + inner.height * .58,
      inner.width,
      inner.height * .42,
    );
    canvas.drawRect(
      lower,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, p.accent.withValues(alpha: .55)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(lower),
    );
    _drawDuoSilhouette(canvas, inner.deflate(inner.width * .16), p);
  }

  /// Hai tấm polaroid nghiêng và dải tape, đúng tinh thần Scrapbook.
  void _scrapbookHero(Canvas canvas, Rect rect, _StylePalette p) {
    final cardWidth = rect.width * .43;
    final cardHeight = rect.height * .72;
    void card(Offset center, double angle, Color tint) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final cardRect = Rect.fromCenter(
        center: Offset.zero,
        width: cardWidth,
        height: cardHeight,
      );
      canvas.drawRect(cardRect, Paint()..color = p.card);
      final photo = Rect.fromLTWH(
        cardRect.left + cardWidth * .10,
        cardRect.top + cardHeight * .08,
        cardWidth * .80,
        cardHeight * .68,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(photo, Radius.circular(cardWidth * .08)),
        Paint()..color = tint,
      );
      _drawDuoSilhouette(
        canvas,
        photo.deflate(photo.width * .13),
        p,
        single: true,
      );
      canvas.restore();
    }

    card(
      Offset(rect.left + cardWidth * .70, rect.center.dy + rect.height * .02),
      -.11,
      p.secondary,
    );
    card(
      Offset(rect.right - cardWidth * .70, rect.center.dy + rect.height * .10),
      .08,
      p.accent.withValues(alpha: .23),
    );
    _tape(canvas, rect, p);
  }

  /// Đảo nhỏ, mây và ngôi nhà là dấu hiệu nhận biết hero Cloud.
  void _cloudHero(Canvas canvas, Rect rect, _StylePalette p) {
    final cloud = Paint()..color = p.card.withValues(alpha: .78);
    canvas.drawOval(
      Rect.fromLTWH(
        rect.left - rect.width * .08,
        rect.top + rect.height * .16,
        rect.width * .48,
        rect.height * .16,
      ),
      cloud,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        rect.right - rect.width * .38,
        rect.top + rect.height * .30,
        rect.width * .48,
        rect.height * .16,
      ),
      cloud,
    );
    final island = Rect.fromLTWH(
      rect.left + rect.width * .10,
      rect.bottom - rect.height * .28,
      rect.width * .80,
      rect.height * .28,
    );
    canvas.drawOval(island, Paint()..color = p.secondary.withValues(alpha: .9));
    final house = Rect.fromLTWH(
      rect.left + rect.width * .56,
      rect.bottom - rect.height * .47,
      rect.width * .22,
      rect.height * .20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(house, Radius.circular(rect.width * .025)),
      Paint()..color = p.card.withValues(alpha: .95),
    );
    final roof = Path()
      ..moveTo(house.left - rect.width * .035, house.top)
      ..lineTo(house.center.dx, house.top - rect.height * .13)
      ..lineTo(house.right + rect.width * .035, house.top)
      ..close();
    canvas.drawPath(roof, Paint()..color = p.accent.withValues(alpha: .55));
    canvas.drawRect(
      Rect.fromLTWH(
        house.left + house.width * .44,
        house.bottom - house.height * .44,
        house.width * .12,
        house.height * .44,
      ),
      Paint()..color = p.accent.withValues(alpha: .45),
    );
    _drawDuoSilhouette(
      canvas,
      island.deflate(island.width * .25),
      p,
      single: true,
    );
  }

  /// Dòng thời gian ngang của kiểu Daily, không gắn ngày hay con số giả.
  void _dailyHero(Canvas canvas, Rect rect, _StylePalette p) {
    final avatar = Rect.fromLTWH(
      rect.left + rect.width * .08,
      rect.top + rect.height * .20,
      rect.height * .44,
      rect.height * .44,
    );
    _drawDuoSilhouette(canvas, avatar, p);
    final lineX = rect.left + rect.width * .43;
    canvas.drawLine(
      Offset(lineX, rect.top + rect.height * .18),
      Offset(lineX, rect.bottom - rect.height * .18),
      Paint()
        ..color = p.accent.withValues(alpha: .34)
        ..strokeWidth = math.max(1, rect.width * .012),
    );
    for (var i = 0; i < 3; i++) {
      final y = rect.top + rect.height * (.28 + i * .22);
      canvas.drawCircle(
        Offset(lineX, y),
        math.max(2, rect.width * .025),
        Paint()..color = i == 1 ? p.accent : p.secondary,
      );
      _line(
        canvas,
        Offset(lineX + rect.width * .10, y - rect.height * .045),
        rect.width * (.30 - i * .035),
        rect.height * .07,
        i == 1 ? p.accent.withValues(alpha: .5) : p.secondary,
      );
    }
  }

  /// Khoảng thở tối giản, chỉ giữ đôi silhouette nhỏ và nét mảnh.
  void _minimalHero(Canvas canvas, Rect rect, _StylePalette p) {
    final center = Offset(rect.center.dx, rect.top + rect.height * .44);
    final radius = math.min(rect.width, rect.height) * .14;
    canvas.drawCircle(
      center.translate(-radius * 1.15, 0),
      radius,
      Paint()..color = p.secondary.withValues(alpha: .82),
    );
    canvas.drawCircle(
      center.translate(radius * 1.15, 0),
      radius,
      Paint()..color = p.accent.withValues(alpha: .28),
    );
    canvas.drawLine(
      Offset(rect.left + rect.width * .17, rect.bottom - rect.height * .20),
      Offset(rect.right - rect.width * .17, rect.bottom - rect.height * .20),
      Paint()
        ..color = p.accent.withValues(alpha: .22)
        ..strokeWidth = math.max(1, rect.width * .012),
    );
  }

  /// Vòm tổ ấm của kiểu Nest.
  void _nestHero(Canvas canvas, Rect rect, _StylePalette p) {
    final arch = Rect.fromLTWH(
      rect.left + rect.width * .19,
      rect.top + rect.height * .10,
      rect.width * .62,
      rect.height * .82,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        arch,
        topLeft: Radius.circular(arch.width * .45),
        topRight: Radius.circular(arch.width * .45),
      ),
      Paint()..color = p.secondary.withValues(alpha: .86),
    );
    canvas.drawCircle(
      Offset(rect.right - rect.width * .18, rect.top + rect.height * .24),
      rect.width * .10,
      Paint()..color = p.accent.withValues(alpha: .34),
    );
    _drawDuoSilhouette(canvas, arch.deflate(arch.width * .18), p);
  }

  void _drawDuoSilhouette(
    Canvas canvas,
    Rect area,
    _StylePalette p, {
    bool single = false,
  }) {
    final unit = math
        .min(area.width * .18, area.height * .26)
        .clamp(2.0, 36.0)
        .toDouble();
    final baseline = area.bottom - unit * .12;
    final centers = single
        ? <Offset>[Offset(area.center.dx, baseline - unit * .63)]
        : <Offset>[
            Offset(area.center.dx - unit * .95, baseline - unit * .63),
            Offset(area.center.dx + unit * .95, baseline - unit * .63),
          ];
    for (var i = 0; i < centers.length; i++) {
      final center = centers[i];
      final color = i == 0 ? p.secondary : p.accent.withValues(alpha: .42);
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, unit * .48),
          width: unit * 1.34,
          height: unit * 1.45,
        ),
        Paint()..color = color,
      );
      canvas.drawCircle(center, unit * .66, Paint()..color = color);
      if (i == 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(-unit * .30, -unit * .73),
            width: unit * .30,
            height: unit * .80,
          ),
          Paint()..color = color,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(unit * .30, -unit * .73),
            width: unit * .30,
            height: unit * .80,
          ),
          Paint()..color = color,
        );
      } else {
        canvas.drawCircle(
          center.translate(-unit * .47, -unit * .24),
          unit * .23,
          Paint()..color = color,
        );
        canvas.drawCircle(
          center.translate(unit * .47, -unit * .24),
          unit * .23,
          Paint()..color = color,
        );
      }
    }
    if (!single) {
      _heart(
        canvas,
        Offset(area.center.dx, area.top + unit * .55),
        unit * .22,
        p.accent,
      );
    }
  }

  void _tape(Canvas canvas, Rect rect, _StylePalette p) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.top + rect.height * .04);
    canvas.rotate(-.08);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: rect.width * .28,
        height: math.max(4, rect.height * .10).toDouble(),
      ),
      Paint()..color = p.accent.withValues(alpha: .25),
    );
    canvas.restore();
  }

  void _timeline(
    Canvas canvas,
    Rect rect,
    _StylePalette p, {
    bool compact = false,
  }) {
    final x = rect.left + rect.width * (compact ? .18 : .12);
    canvas.drawLine(
      Offset(x, rect.top + rect.height * .18),
      Offset(x, rect.bottom - rect.height * .18),
      Paint()
        ..color = p.accent.withValues(alpha: .28)
        ..strokeWidth = math.max(1, rect.width * .012).toDouble(),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(x, rect.top + rect.height * (.26 + i * .25)),
        math.max(2, rect.width * .022).toDouble(),
        Paint()..color = i == 1 ? p.accent : p.secondary,
      );
    }
  }

  void _card(Canvas canvas, Rect rect, double radius, Color color) =>
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = color,
      );

  void _line(
    Canvas canvas,
    Offset start,
    double width,
    double height,
    Color color,
  ) => _card(
    canvas,
    Rect.fromLTWH(start.dx, start.dy, width, height),
    height / 2,
    color,
  );

  void _heart(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + radius)
      ..cubicTo(
        center.dx - radius * 1.8,
        center.dy - radius * .1,
        center.dx - radius * .85,
        center.dy - radius * 1.4,
        center.dx,
        center.dy - radius * .55,
      )
      ..cubicTo(
        center.dx + radius * .85,
        center.dy - radius * 1.4,
        center.dx + radius * 1.8,
        center.dy - radius * .1,
        center.dx,
        center.dy + radius,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HomeStylePreviewPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.palette != palette ||
      oldDelegate.thumbnail != thumbnail;
}
