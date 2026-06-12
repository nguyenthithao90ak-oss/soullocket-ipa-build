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

class _TilePalette {
  final Color shellStart;
  final Color shellEnd;
  final Color shellBorder;
  final Color innerBorder;
  final Color shellGlow;
  final Color shellOverlayStart;
  final Color shellOverlayEnd;
  final Color innerOverlayStart;
  final Color innerOverlayEnd;
  final Color labelColor;

  const _TilePalette({
    required this.shellStart,
    required this.shellEnd,
    required this.shellBorder,
    required this.innerBorder,
    required this.shellGlow,
    required this.shellOverlayStart,
    required this.shellOverlayEnd,
    required this.innerOverlayStart,
    required this.innerOverlayEnd,
    required this.labelColor,
  });
}

final Map<String, _TilePalette> _paletteCache = {};

_TilePalette _getTilePalette(List<Color> colors, bool isTarget) {
  final cacheKey = '${colors.first.value}_${colors.last.value}_$isTarget';
  if (_paletteCache.containsKey(cacheKey)) {
    return _paletteCache[cacheKey]!;
  }

  final shellStart =
      Color.lerp(colors.first, colors.last, isTarget ? 0.10 : 0.16) ??
          colors.first;
  final shellEnd =
      Color.lerp(colors.last, colors.first, isTarget ? 0.04 : 0.10) ??
          colors.last;
  final shellBorder =
      Color.lerp(colors.last, SLColors.textPrimary, isTarget ? 0.04 : 0.10) ??
          colors.last;
  final innerBorder =
      Color.lerp(colors.first, colors.last, 0.32) ?? colors.first;
  final shellGlow =
      Color.lerp(colors.first, Colors.transparent, 0.46) ?? colors.first;
  final shellOverlayStart =
      Color.lerp(colors.first, colors.last, 0.14) ?? colors.first;
  final shellOverlayEnd =
      Color.lerp(colors.last, colors.first, 0.06) ?? colors.last;
  final innerOverlayStart =
      Color.lerp(colors.first, colors.last, 0.22) ?? colors.first;
  final innerOverlayEnd =
      Color.lerp(colors.last, colors.first, 0.08) ?? colors.last;
  final labelColor =
      Color.lerp(colors.last, SLColors.textPrimary, 0.72) ??
          SLColors.textPrimary;

  final palette = _TilePalette(
    shellStart: shellStart,
    shellEnd: shellEnd,
    shellBorder: shellBorder,
    innerBorder: innerBorder,
    shellGlow: shellGlow,
    shellOverlayStart: shellOverlayStart,
    shellOverlayEnd: shellOverlayEnd,
    innerOverlayStart: innerOverlayStart,
    innerOverlayEnd: innerOverlayEnd,
    labelColor: labelColor,
  );

  _paletteCache[cacheKey] = palette;
  return palette;
}

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
    final List<Color> colors = config['colors'];
    final IconData iconData = config['icon'];
    final Color iconColor = config['iconColor'] ?? SLColors.textInverse;

    final palette = _getTilePalette(colors, isTarget);
    final Color shellStart = palette.shellStart;
    final Color shellEnd = palette.shellEnd;
    final Color shellBorder = palette.shellBorder;
    final Color innerBorder = palette.innerBorder;
    final Color shellGlow = palette.shellGlow;
    final Color shellOverlayStart = palette.shellOverlayStart;
    final Color shellOverlayEnd = palette.shellOverlayEnd;
    final Color innerOverlayStart = palette.innerOverlayStart;
    final Color innerOverlayEnd = palette.innerOverlayEnd;
    final Color labelColor = palette.labelColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              AnimatedSlide(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                offset: isTarget ? const Offset(0, -0.04) : Offset.zero,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: [
                        shellStart.withValues(alpha: isTarget ? 0.98 : 0.94),
                        shellEnd.withValues(alpha: isTarget ? 0.98 : 0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: shellBorder.withValues(alpha: isTarget ? 0.96 : 0.88),
                      width: isTarget ? 1.5 : 1.15,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shellGlow.withValues(alpha: isTarget ? 0.34 : 0.22),
                        blurRadius: isTarget ? 18 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 9,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [
                                shellOverlayStart.withValues(alpha: 0.34),
                                shellOverlayEnd.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: innerBorder.withValues(alpha: 0.58),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      innerOverlayStart.withValues(alpha: 0.22),
                                      innerOverlayEnd.withValues(alpha: 0.06),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.28, 1.0],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 9,
                              right: 9,
                              bottom: 9,
                              child: Container(
                                height: 9,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [
                                      SLColors.textPrimary.withValues(alpha: 0.14),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),
                            buildUtilityStickerIcon(
                              utilityId: app.id,
                              fallbackIcon: iconData,
                              fallbackColor: iconColor,
                              fallbackSize: 27,
                              padding: const EdgeInsets.all(2),
                            ),
                          ],
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
                      color: labelColor,
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
