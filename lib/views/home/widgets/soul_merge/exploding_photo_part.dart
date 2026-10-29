import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../utils/services/soul_merge_memories.dart';
import '../../../ui_prefs.dart';
import '../../tabs/diary/widgets/private_diary_image.dart';
import 'particle_explosion_part.dart';
import 'soul_merge_design.dart';

class SoulMergeMemoryLayout {
  static Size cardSize(Size available) {
    final height = math.min(278.0, math.max(0.0, available.height - 44));
    final width = math.min(
      (available.width * .54).clamp(166.0, 222.0),
      height / 1.26,
    );
    return Size(width, width * 1.26);
  }

  static Offset position(
    Size available,
    Size card,
    int slot, {
    Offset? anchor,
  }) {
    const padding = 18.0;
    final x = [
      available.width / 2 - card.width / 2,
      padding,
      available.width - card.width - padding,
    ][slot % 3];
    final y = [18.0, 30.0, 42.0][slot % 3];
    return Offset(
      (anchor == null ? x : anchor.dx - card.width / 2).clamp(
        padding,
        math.max(padding, available.width - card.width - padding),
      ),
      (anchor == null ? y : anchor.dy - card.height / 2).clamp(
        18.0,
        math.max(18.0, available.height - card.height - 22),
      ),
    );
  }
}

class ExplodingPhoto {
  ExplodingPhoto({
    required this.memory,
    required this.position,
    required this.size,
    this.angle = 0,
  });
  final SoulMergeMemory memory;
  final Offset position;
  final Size size;
  final double angle;
  final UniqueKey id = UniqueKey();
}

class ExplodingPhotoWidget extends StatefulWidget {
  const ExplodingPhotoWidget({
    super.key,
    required this.photo,
    this.imageProvider,
  });
  static const duration = Duration(milliseconds: 3500);
  final ExplodingPhoto photo;
  final ImageProvider? imageProvider;

  @override
  State<ExplodingPhotoWidget> createState() => _ExplodingPhotoWidgetState();
}

class _ExplodingPhotoWidgetState extends State<ExplodingPhotoWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _foreground = true;
  bool _animate = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(
      vsync: this,
      duration: ExplodingPhotoWidget.duration,
    );
    WidgetsBinding.instance.addObserver(this);
    UiPrefs.notifier.addListener(_onMotionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _onMotionChanged() {
    if (mounted) setState(_syncMotion);
  }

  void _syncMotion() {
    _visible = _foreground && TickerMode.valuesOf(context).enabled;
    _animate = UiPrefs.resolveEffectProfile(
      state: UiPrefs.notifier.value,
      isWeb: kIsWeb,
      pauseAnimations: !_visible || MediaQuery.disableAnimationsOf(context),
    ).animationEnabled;
    if (_animate) {
      if (!_controller.isAnimating && !_controller.isCompleted) {
        _controller.forward();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) setState(_syncMotion);
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_onMotionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final photo = widget.photo;
    return Positioned(
      left: photo.position.dx,
      top: photo.position.dy,
      width: photo.size.width,
      height: photo.size.height,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            child: SoulMergeMemoryCard(
              memory: photo.memory,
              imageProvider: widget.imageProvider,
            ),
            builder: (context, child) {
              final t = _animate ? _controller.value : .4;
              final enter = Curves.easeOutBack.transform(
                (t / .18).clamp(0.0, 1.0),
              );
              final exit = Curves.easeInCubic.transform(
                ((t - .82) / .18).clamp(0.0, 1.0),
              );
              return Opacity(
                opacity: ((t / .10).clamp(0.0, 1.0) * (1 - exit)).clamp(
                  0.0,
                  1.0,
                ),
                child: CustomPaint(
                  painter: _animate
                      ? SoulMergeMemoryBurstPainter(
                          progress: (t / .30).clamp(0.0, 1.0),
                          dark: Theme.of(context).brightness == Brightness.dark,
                        )
                      : null,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _animate ? 16 * (1 - enter) - 12 * exit : 0,
                    ),
                    child: Transform.rotate(
                      angle: _animate ? photo.angle * enter : 0,
                      child: Transform.scale(
                        scale: _animate ? .72 + enter * .28 - exit * .06 : 1,
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Thẻ lớn dùng toàn bộ kích thước layout; không còn thu nhỏ xuống 45%.
class SoulMergeMemoryCard extends StatelessWidget {
  const SoulMergeMemoryCard({
    super.key,
    required this.memory,
    this.imageProvider,
  });
  final SoulMergeMemory memory;
  final ImageProvider? imageProvider;

  Widget _placeholder(SoulMergeColors colors) => ColoredBox(
    color: colors.blush,
    child: Center(
      child: Icon(
        Icons.favorite_rounded,
        size: 38,
        color: colors.rose.withValues(alpha: .55),
      ),
    ),
  );

  Widget _image(SoulMergeColors colors) {
    if (imageProvider != null) {
      return Image(image: imageProvider!, fit: BoxFit.cover);
    }
    if (memory.privateMedia) {
      return PrivateDiaryImage(
        key: ValueKey('soul-memory-image:${memory.memoryId}'),
        houseId: memory.houseId,
        memoryId: memory.memoryId,
        cacheWidth: 640,
        retainCacheWidth: 1600,
        reuseAnyCachedSize: true,
        loadingBackgroundColor: colors.blush,
      );
    }
    return CachedNetworkImage(
      imageUrl: memory.imageUrl,
      memCacheWidth: 640,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (_, _) => _placeholder(colors),
      errorWidget: (_, _, _) => _placeholder(colors),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          key: const ValueKey('soul-merge-memory-card'),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: colors.line),
            boxShadow: [
              BoxShadow(
                color: colors.rose.withValues(alpha: .20),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .07),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(memory.hasPhoto ? 9 : 17),
            child: memory.hasPhoto
                ? Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.expand(child: _image(colors)),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 15,
                            color: colors.rose,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              memory.text.isEmpty
                                  ? memory.dateStr
                                  : memory.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            memory.mood,
                            style: const TextStyle(fontSize: 23),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              memory.dateStr,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final lineHeight =
                                MediaQuery.textScalerOf(context).scale(16) *
                                1.4;
                            final lines = math.max(
                              1,
                              (constraints.maxHeight / lineHeight).floor(),
                            );
                            return Text(
                              memory.text,
                              maxLines: lines,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Positioned(
          top: -4,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: -.06,
              child: Container(
                width: 46,
                height: 12,
                decoration: BoxDecoration(
                  color: colors.rose.withValues(alpha: .20),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: colors.rose.withValues(alpha: .08)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
