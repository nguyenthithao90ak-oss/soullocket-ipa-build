import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/utility_service.dart';
import '../../../utilities/utilities_config.dart';
import '../../../utilities/utility_sticker_icon.dart';

class UtilitiesHubItem extends StatelessWidget {
  const UtilitiesHubItem({
    super.key,
    required this.app,
    required this.isEditMode,
    required this.onTap,
    required this.onReorder,
    required this.onEditModeChanged,
  });

  final UtilityApp app;
  final bool isEditMode;
  final VoidCallback onTap;
  final void Function(String fromId, String toId) onReorder;
  final ValueChanged<bool> onEditModeChanged;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != app.id,
      onAcceptWithDetails: (details) => onReorder(details.data, app.id),
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return LongPressDraggable<String>(
          data: app.id,
          delay: const Duration(milliseconds: 220),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: () {
            HapticFeedback.selectionClick();
            onEditModeChanged(true);
          },
          onDragCompleted: HapticFeedback.lightImpact,
          onDraggableCanceled: (_, __) => onEditModeChanged(false),
          onDragEnd: (_) => onEditModeChanged(false),
          feedback: _UtilitiesHubDragFeedback(app: app),
          childWhenDragging: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            opacity: 0.24,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              scale: 0.92,
              child: _UtilitiesHubTileContent(app: app, isTarget: false),
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<String>(app.id),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              scale: isTarget ? 1.07 : 1,
              child: _UtilitiesHubTileContent(
                app: app,
                isTarget: isTarget,
                onTap: onTap,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UtilitiesHubDragFeedback extends StatelessWidget {
  const _UtilitiesHubDragFeedback({required this.app});

  final UtilityApp app;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Transform.translate(
          offset: const Offset(-36, -42),
          child: Transform.scale(
            scale: 1.08,
            child: Opacity(
              opacity: 0.94,
              child: SizedBox(
                width: 86,
                height: 112,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: SLColors.textPrimary.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _UtilitiesHubTileContent(app: app, isTarget: false),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Palette — all colors derived once from the two seed colors and cached.
// ---------------------------------------------------------------------------

class _TilePalette {
  const _TilePalette({
    required this.shellStart,
    required this.shellEnd,
    required this.shellBorder,
    required this.innerBorder,
    required this.shellGlow,
    required this.shellOverlayStart,
    required this.innerOverlayStart,
    required this.labelColor,
  });

  final Color shellStart;
  final Color shellEnd;
  final Color shellBorder;
  final Color innerBorder;
  final Color shellGlow;
  final Color shellOverlayStart;
  final Color innerOverlayStart;
  final Color labelColor;
}

/// FIX #2: Use an unambiguous String key to avoid XOR hash collisions.
/// Format: firstArgb_lastArgb — unique for every color pair.
final Map<String, _TilePalette> _paletteCache = {};

_TilePalette _getTilePalette(List<Color> colors) {
  // Stable key: two ARGB ints joined — no collision risk.
  final key = '${colors.first.toARGB32()}_${colors.last.toARGB32()}';
  return _paletteCache.putIfAbsent(key, () {
    final shellStart =
        Color.lerp(colors.first, colors.last, 0.16) ?? colors.first;
    final shellEnd =
        Color.lerp(colors.last, colors.first, 0.10) ?? colors.last;
    final shellBorder =
        Color.lerp(colors.last, SLColors.textPrimary, 0.10) ?? colors.last;
    final innerBorder =
        Color.lerp(colors.first, colors.last, 0.32) ?? colors.first;
    final shellGlow =
        Color.lerp(colors.first, Colors.transparent, 0.46) ?? colors.first;
    final shellOverlayStart =
        Color.lerp(colors.first, colors.last, 0.14) ?? colors.first;
    final innerOverlayStart =
        Color.lerp(colors.first, colors.last, 0.22) ?? colors.first;
    final labelColor =
        Color.lerp(colors.last, SLColors.textPrimary, 0.72) ??
            SLColors.textPrimary;
    return _TilePalette(
      shellStart: shellStart,
      shellEnd: shellEnd,
      shellBorder: shellBorder,
      innerBorder: innerBorder,
      shellGlow: shellGlow,
      shellOverlayStart: shellOverlayStart,
      innerOverlayStart: innerOverlayStart,
      labelColor: labelColor,
    );
  });
}

// ---------------------------------------------------------------------------
// CustomPainter — draws the entire icon shell in ONE GPU pass.
// ---------------------------------------------------------------------------

class _TileIconPainter extends CustomPainter {
  _TileIconPainter({
    required this.palette,
    required this.innerColors,
    required this.isTarget,
  });

  final _TilePalette palette;
  final List<Color> innerColors;
  final bool isTarget;

  static const double _shellRadius = 26.0;
  static const double _innerSize = 52.0;
  static const double _innerRadius = 20.0;
  static const double _glossHeight = 18.0;
  static const double _glossMarginH = 10.0;
  static const double _glossTop = 9.0;
  static const double _shadowHeight = 9.0;
  static const double _shadowMarginH = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shellA1 = isTarget ? 0.98 : 0.94;
    final shellA2 = isTarget ? 0.98 : 0.88;
    final borderA = isTarget ? 0.96 : 0.88;
    final borderW = isTarget ? 1.5 : 1.15;
    final glowA = isTarget ? 0.34 : 0.22;

    final fullRect = Offset.zero & size;
    final shellRRect = RRect.fromRectAndRadius(
      fullRect,
      const Radius.circular(_shellRadius),
    );

    // 1. Shell background.
    canvas.drawRRect(
      shellRRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette.shellStart.withValues(alpha: shellA1),
            palette.shellEnd.withValues(alpha: shellA2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(fullRect),
    );

    // 2. Shell outer glow.
    canvas.drawRRect(
      shellRRect.inflate(6),
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.shellGlow.withValues(alpha: glowA * 0.28),
            Colors.transparent,
          ],
          radius: 0.85,
        ).createShader(fullRect)
        ..blendMode = BlendMode.srcOver,
    );

    // 3. Shell border.
    canvas.drawRRect(
      shellRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = palette.shellBorder.withValues(alpha: borderA)
        ..strokeWidth = borderW,
    );

    // 4. Top gloss highlight.
    final glossRect = Rect.fromLTWH(
      _glossMarginH,
      _glossTop,
      size.width - _glossMarginH * 2,
      _glossHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glossRect, const Radius.circular(18)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette.shellOverlayStart.withValues(alpha: 0.34),
            palette.shellOverlayStart.withValues(alpha: 0.08),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(glossRect),
    );

    // 5. Inner rounded rect (icon background).
    final innerDx = (size.width - _innerSize) / 2;
    final innerDy = (size.height - _innerSize) / 2;
    final innerRect = Rect.fromLTWH(innerDx, innerDy, _innerSize, _innerSize);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(_innerRadius),
    );

    canvas.drawRRect(
      innerRRect,
      Paint()
        ..shader = LinearGradient(
          colors: innerColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(innerRect),
    );

    // 6. Inner border.
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = palette.innerBorder.withValues(alpha: 0.58)
        ..strokeWidth = 1.0,
    );

    // 7. Inner overlay shimmer.
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            palette.innerOverlayStart.withValues(alpha: 0.22),
            palette.innerOverlayStart.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(innerRect),
    );

    // 8. Bottom inner shadow.
    final shadowRect = Rect.fromLTWH(
      innerDx + _shadowMarginH,
      innerDy + _innerSize - _shadowHeight * 2,
      _innerSize - _shadowMarginH * 2,
      _shadowHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(12)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF000000).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(shadowRect),
    );
  }

  /// FIX #1: appConfig['colors'] is a non-const List — reference equality
  /// always returns false for different instances with the same values.
  /// Use `listEquals()` for correct value-based comparison.
  @override
  bool shouldRepaint(_TileIconPainter old) {
    if (old.isTarget != isTarget) return true;
    if (old.palette != palette) return true;
    // listEquals does O(n) element comparison — n=2 here, effectively O(1).
    if (!listEquals(old.innerColors, innerColors)) return true;
    return false;
  }
}

// ---------------------------------------------------------------------------
// Tile content widget.
// ---------------------------------------------------------------------------

class _UtilitiesHubTileContent extends StatelessWidget {
  const _UtilitiesHubTileContent({
    required this.app,
    required this.isTarget,
    this.onTap,
  });

  final UtilityApp app;
  final bool isTarget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final config = appConfig[app.id] ??
        {
          'icon': app.icon,
          'colors': app.colors,
          'title': app.title,
        };
    final List<Color> colors = List<Color>.from(config['colors'] as List);
    final IconData iconData = config['icon'] as IconData;
    final Color iconColor =
        (config['iconColor'] as Color?) ?? SLColors.textInverse;

    final palette = _getTilePalette(colors);

    /// FIX #3: Read devicePixelRatio once in the parent build() and pass it
    /// directly to buildUtilityStickerIcon, eliminating the Builder widget
    /// that was created for each of the 19 tiles solely to access MediaQuery.
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSlide(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                offset: isTarget ? const Offset(0, -0.04) : Offset.zero,
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // All background drawing in a single GPU paint call.
                      CustomPaint(
                        painter: _TileIconPainter(
                          palette: palette,
                          innerColors: colors,
                          isTarget: isTarget,
                        ),
                      ),
                      // Icon on top — Builder removed.
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: buildUtilityStickerIcon(
                            utilityId: app.id,
                            fallbackIcon: iconData,
                            fallbackColor: iconColor,
                            fallbackSize: 27,
                            padding: const EdgeInsets.all(2),
                            devicePixelRatio: dpr,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 28,
                child: Center(
                  child: Text(
                    app.localizedTitle.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: palette.labelColor,
                      letterSpacing: 0.35,
                      height: 1.08,
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
