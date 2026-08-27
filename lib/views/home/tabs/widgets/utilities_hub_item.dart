import 'dart:ui';

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
          onDraggableCanceled: (_, _) => onEditModeChanged(false),
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

    final Color startColor = colors.first;
    final Color endColor = colors.last;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                offset: isTarget ? const Offset(0, -0.06) : Offset.zero,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  scale: isTarget ? 1.08 : 1.0,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      // Lớp nền ngọc trai sứ mềm mại, trong suốt cao cấp nổi bật trên mọi hình nền
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.94),
                          startColor.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.86),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: startColor.withValues(alpha: 0.22),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: buildUtilityStickerIcon(
                        utilityId: app.id,
                        fallbackIcon: iconData,
                        fallbackColor: startColor,
                        fallbackSize: 34,
                        padding: const EdgeInsets.all(7),
                        devicePixelRatio: dpr,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Khung nền viên nang mờ (Capsule Pill) bảo vệ chữ sắc nét, không bị chìm vào ảnh nền
              Container(
                constraints: const BoxConstraints(minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    app.localizedTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2E2427),
                      letterSpacing: 0.1,
                      height: 1.15,
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
