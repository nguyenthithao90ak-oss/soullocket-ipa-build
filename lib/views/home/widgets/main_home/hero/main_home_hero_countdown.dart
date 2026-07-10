part of '../../../tabs/main_home_tab.dart';

class _MainHomeHeroCountdownSection extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String houseName;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final String? startDate;
  final double circleSize;
  final bool homeShowHouseName;
  final bool showDayCounter;
  final bool showLoveTimeDetail;
  final String countdownStyleKey;
  final bool enableMotion;
  final VoidCallback? onEditStartDate;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final GlobalKey? firstGuideHeroKey;

  const _MainHomeHeroCountdownSection({
    required this.state,
    required this.isSingle,
    required this.houseName,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    required this.startDate,
    required this.circleSize,
    required this.homeShowHouseName,
    required this.showDayCounter,
    required this.showLoveTimeDetail,
    required this.countdownStyleKey,
    required this.enableMotion,
    this.onEditStartDate,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.firstGuideHeroKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The large circle is permanently reserved for the relationship day
        // count. Only the compact time-detail row below may be toggled.
        if (showDayCounter) ...[
          _MainHomeHeroCountdownCircle(
            state: state,
            isSingle: isSingle,
            smartGreeting: smartGreeting,
            circleValue: circleValue,
            circleTopLabel: circleTopLabel,
            circleBottomLabel: circleBottomLabel,
            circleSize: circleSize,
            countdownStyleKey: countdownStyleKey,
            enableMotion: enableMotion,
            onEditStartDate: onEditStartDate,
            onEditTopLabel: onEditTopLabel,
            onEditBottomLabel: onEditBottomLabel,
            firstGuideHeroKey: firstGuideHeroKey,
          ),
          SLSpacing.h16,
        ],
        // `showLoveTimeDetail` means the 3-block hours/minutes/seconds strip.
        if (showLoveTimeDetail)
          _MainHomeHeroCounters(
            state: state,
            startDate: startDate,
          ),
        // Hiển thị tên nhà đã bị ẩn theo yêu cầu
        // if (homeShowHouseName)
        //   MainHomeHeroBadges(
        //     houseName: houseName,
        //   ),
      ],
    );
  }
}

class HomeExplodingPhoto {
  final String url;
  final Offset position;
  final double angle;
  final double scale;
  final Offset targetOffset;
  final UniqueKey id = UniqueKey();

  HomeExplodingPhoto({
    required this.url,
    required this.position,
    required this.angle,
    required this.scale,
    required this.targetOffset,
  });
}

class HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double width = size.width;
    final double height = size.height;

    path.moveTo(width / 2, height * 0.28);
    // Left half of the heart
    path.cubicTo(
      width * 0.2,
      -height * 0.08,
      -width * 0.08,
      height * 0.28,
      width / 2,
      height * 0.95,
    );
    // Right half of the heart
    path.cubicTo(
      width * 1.08,
      height * 0.28,
      width * 0.8,
      -height * 0.08,
      width / 2,
      height * 0.28,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HeartBorderPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;
  final double shadowBlur;

  HeartBorderPainter({
    required this.color,
    required this.shadowColor,
    required this.shadowBlur,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final path = Path();
    path.moveTo(width / 2, height * 0.28);
    // Left half
    path.cubicTo(
      width * 0.2,
      -height * 0.08,
      -width * 0.08,
      height * 0.28,
      width / 2,
      height * 0.95,
    );
    // Right half
    path.cubicTo(
      width * 1.08,
      height * 0.28,
      width * 0.8,
      -height * 0.08,
      width / 2,
      height * 0.28,
    );
    path.close();

    // Draw shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw fill
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HeartBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.shadowBlur != shadowBlur;
  }
}

class HomeExplodingPhotoWidget extends StatefulWidget {
  final HomeExplodingPhoto photo;
  const HomeExplodingPhotoWidget({super.key, required this.photo});

  @override
  State<HomeExplodingPhotoWidget> createState() =>
      _HomeExplodingPhotoWidgetState();
}

class _HomeExplodingPhotoWidgetState extends State<HomeExplodingPhotoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: widget.photo.scale)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(widget.photo.scale),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.photo.scale, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: widget.photo.targetOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _slideAnimation.value;
        return Positioned(
          left: widget.photo.position.dx + offset.dx - 30,
          top: widget.photo.position.dy + offset.dy - 30,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: widget.photo.angle,
                child: child,
              ),
            ),
          ),
        );
      },
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: HeartBorderPainter(
                  color: Colors.white,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  shadowBlur: 8.0,
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ClipPath(
                  clipper: HeartClipper(),
                  child: widget.photo.url.isEmpty
                      ? Container(
                          color: const Color(0xFFFFE3EC),
                          child: const Center(
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFFF5E92),
                              size: 24,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.photo.url,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFFFE3EC),
                            child: const Center(
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFFFF5E92),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainHomeHeroCountdownCircle extends StatefulWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final double circleSize;
  final String countdownStyleKey;
  final bool enableMotion;
  final VoidCallback? onEditStartDate;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final GlobalKey? firstGuideHeroKey;

  const _MainHomeHeroCountdownCircle({
    required this.state,
    required this.isSingle,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    required this.circleSize,
    required this.countdownStyleKey,
    required this.enableMotion,
    this.onEditStartDate,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.firstGuideHeroKey,
  });

  @override
  State<_MainHomeHeroCountdownCircle> createState() =>
      _MainHomeHeroCountdownCircleState();
}

class _MainHomeHeroCountdownCircleState
    extends State<_MainHomeHeroCountdownCircle>
    with SingleTickerProviderStateMixin {
  final List<HomeExplodingPhoto> _activeExplosions = [];
  List<String> _cachedPhotoUrls = [];
  bool _isFetchingPhotos = false;

  late AnimationController _countController;
  late Animation<double> _countAnimation;
  int _targetValue = 0;

  @override
  void initState() {
    super.initState();
    _targetValue = int.tryParse(widget.circleValue) ?? 0;
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _countAnimation = Tween<double>(
      begin: 0.0,
      end: _targetValue.toDouble(),
    ).animate(CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    ));
    _countController.forward();
  }

  @override
  void didUpdateWidget(covariant _MainHomeHeroCountdownCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.circleValue != oldWidget.circleValue) {
      final oldVal = int.tryParse(oldWidget.circleValue) ?? 0;
      final newVal = int.tryParse(widget.circleValue) ?? 0;
      if (oldVal != newVal) {
        _targetValue = newVal;
        final currentVal = _countAnimation.value;
        _countAnimation = Tween<double>(
          begin: currentVal,
          end: _targetValue.toDouble(),
        ).animate(CurvedAnimation(
          parent: _countController,
          curve: Curves.easeOutCubic,
        ));
        _countController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _ensurePhotosLoaded() async {
    if (_cachedPhotoUrls.isNotEmpty || _isFetchingPhotos) return;
    _isFetchingPhotos = true;
    try {
      final houseId = widget.state._houseId;
      if (houseId == null || houseId.isEmpty) return;

      final firestore = FirebaseFirestore.instance;
      final List<String> urls = [];
      final Set<String> seen = {};

      // 1. Fetch from diaries collection
      try {
        final diariesSnap = await firestore
            .collection('houses')
            .doc(houseId)
            .collection('diaries')
            .orderBy('ts', descending: true)
            .limit(20)
            .get();
        for (var doc in diariesSnap.docs) {
          final data = doc.data();
          final url = (data['imageUrl'] ?? data['url'] ?? '').toString().trim();
          if (url.isNotEmpty && url.startsWith('http') && seen.add(url)) {
            urls.add(url);
          }
        }
      } catch (e) {
        debugPrint('[HomeCountdownCircle] diaries fetch error: $e');
      }

      // 2. Fetch from album collection
      try {
        final albumSnap = await firestore
            .collection('houses')
            .doc(houseId)
            .collection('album')
            .orderBy('ts', descending: true)
            .limit(20)
            .get();
        for (var doc in albumSnap.docs) {
          final data = doc.data();
          for (final key in <String>[
            'url',
            'imageUrl',
            'photoUrl',
            'mediaUrl',
            'thumbUrl'
          ]) {
            final url = (data[key] as String? ?? '').trim();
            if (url.isNotEmpty && url.startsWith('http') && seen.add(url)) {
              urls.add(url);
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('[HomeCountdownCircle] album fetch error: $e');
      }

      // 3. Fetch from memories collection
      try {
        final memoriesSnap = await firestore
            .collection('houses')
            .doc(houseId)
            .collection('memories')
            .orderBy('ts', descending: true)
            .limit(20)
            .get();
        for (var doc in memoriesSnap.docs) {
          final data = doc.data();
          for (final key in <String>[
            'url',
            'imageUrl',
            'photoUrl',
            'mediaUrl'
          ]) {
            final url = (data[key] as String? ?? '').trim();
            if (url.isNotEmpty && url.startsWith('http') && seen.add(url)) {
              urls.add(url);
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('[HomeCountdownCircle] memories fetch error: $e');
      }

      if (mounted) {
        setState(() {
          _cachedPhotoUrls = urls;
        });
      }
    } catch (e) {
      debugPrint('[HomeCountdownCircle] error fetching photos: $e');
    } finally {
      _isFetchingPhotos = false;
    }
  }

  void _triggerExplosion(Offset localPos) {
    HapticFeedback.mediumImpact();
    unawaited(_ensurePhotosLoaded());

    final random = Random();
    final int count = 4 + random.nextInt(3); // Burst 4, 5, or 6 photos at once!
    final List<HomeExplodingPhoto> newPhotos = [];

    for (int i = 0; i < count; i++) {
      final String url = _cachedPhotoUrls.isEmpty
          ? ''
          : _cachedPhotoUrls[random.nextInt(_cachedPhotoUrls.length)];

      // Pointing upwards and rightwards (e.g. -70 to 20 degrees) to go towards the circle center
      final double baseAngle =
          (-70.0 + random.nextDouble() * 90.0) * pi / 180.0;

      final double distance =
          100.0 + random.nextDouble() * 120.0; // Burst distance 100 to 220 px
      final double targetX = cos(baseAngle) * distance;
      final double targetY = sin(baseAngle) * distance;

      final photo = HomeExplodingPhoto(
        url: url,
        position: localPos,
        angle: (random.nextDouble() - 0.5) * 0.5,
        scale: 0.6 + random.nextDouble() * 0.5,
        targetOffset: Offset(targetX, targetY),
      );
      newPhotos.add(photo);
    }

    setState(() {
      _activeExplosions.addAll(newPhotos);
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          final ids = newPhotos.map((p) => p.id).toSet();
          _activeExplosions.removeWhere((p) => ids.contains(p.id));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transparentMode = UiPrefs.notifier.value.transparentMode;
    final countdownVisual =
        _CountdownVisualSpec.resolve(widget.countdownStyleKey, transparentMode);

    final selectedFont = UiPrefs.notifier.value.fontKey;
    final labelFont = (selectedFont.isEmpty || selectedFont == 'default')
        ? 'comfortaa'
        : selectedFont;

    final countdownTextColorStr = UiPrefs.notifier.value.countdownTextColor;
    Color? customTextColor;
    final isMultiColor = countdownTextColorStr == '#MULTI';
    if (countdownTextColorStr.isNotEmpty && !isMultiColor) {
      try {
        customTextColor =
            Color(int.parse(countdownTextColorStr.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    final labelHeight = (widget.circleSize * 0.15).clamp(24.0, 72.0).toDouble();
    final numberHeight =
        (widget.circleSize * 0.38).clamp(60.0, 160.0).toDouble();
    final topLabelWidth = widget.circleSize * 0.82;
    final bottomLabelWidth = widget.circleSize * 0.80;
    final numberWidth = widget.circleSize * 0.72;
    final topGap = (widget.circleSize * 0.05).clamp(8.0, 24.0).toDouble();
    final bottomGap = (widget.circleSize * 0.035).clamp(6.0, 18.0).toDouble();

    return KeyedSubtree(
      key: widget.firstGuideHeroKey,
      child: SizedBox(
        width: widget.circleSize * 1.2,
        height: widget.circleSize * 1.2,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. The main interactive circle
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: null,
              onLongPress: widget.state._showCountdownQuickCustomizeSheet,
              child: Container(
                width: widget.circleSize,
                height: widget.circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: countdownVisual.outerColor,
                  gradient: countdownVisual.outerGradient,
                  border: countdownVisual.outerBorder,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: (countdownVisual.outerColor != null ||
                                countdownVisual.outerGradient != null ||
                                countdownVisual.outerBorder != null)
                            ? SLSpacing.all12
                            : EdgeInsets.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: countdownVisual.innerColor,
                            gradient: countdownVisual.innerGradient,
                            border: countdownVisual.innerBorder,
                          ),
                          child: RepaintBoundary(
                            child: AnimatedWaveBackground(
                              styleKey: (transparentMode ||
                                      UiPrefs.notifier.value.liteMode)
                                  ? 'plain'
                                  : widget.countdownStyleKey,
                              enableMotion: widget.enableMotion,
                              transparentMode: transparentMode,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.countdownStyleKey == 'floating_hearts')
                      FloatingHeartsRingOverlay(
                        size: widget.circleSize,
                        enableMotion: widget.enableMotion,
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: widget.circleSize * 0.16),
                          child: _MainHomeHeroCountdownTapTarget(
                            circleSize: widget.circleSize,
                            onTap:
                                widget.isSingle ? null : widget.onEditTopLabel,
                            onLongPress:
                                widget.state._showCountdownQuickCustomizeSheet,
                            constraints: BoxConstraints(
                              minWidth: topLabelWidth,
                              maxWidth: topLabelWidth,
                              minHeight: labelHeight,
                              maxHeight: labelHeight,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: isMultiColor 
                                ? ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: countdownVisual.numberGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    blendMode: BlendMode.srcIn,
                                    child: Text(
                                      widget.circleTopLabel,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: SLTheme.textStyleForKey(
                                        labelFont,
                                        fontSize: (widget.circleSize * 0.11)
                                            .clamp(18.0, 42.0),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    widget.circleTopLabel,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: SLTheme.textStyleForKey(
                                      labelFont,
                                      fontSize: (widget.circleSize * 0.11)
                                          .clamp(18.0, 42.0),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: customTextColor ??
                                          countdownVisual.topLabelColor,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: topGap),
                        _MainHomeHeroCountdownTapTarget(
                          circleSize: widget.circleSize,
                          onTap:
                              widget.isSingle ? null : widget.onEditStartDate,
                          onLongPress:
                              widget.state._showCountdownQuickCustomizeSheet,
                          constraints: BoxConstraints(
                            minWidth: numberWidth,
                            maxWidth: numberWidth,
                            minHeight: numberHeight,
                            maxHeight: numberHeight,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: customTextColor != null
                                    ? [customTextColor, customTextColor]
                                    : countdownVisual.numberGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: AnimatedBuilder(
                                animation: _countAnimation,
                                builder: (context, child) {
                                  final parsed = int.tryParse(widget.circleValue);
                                  final displayVal = parsed == null
                                      ? widget.circleValue
                                      : _countAnimation.value.round().toString();
                                  return Text(
                                    displayVal,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: widget.state
                                        ._uiTextStyle(
                                          fontSize: (widget.circleSize * 0.36)
                                              .clamp(52.0, 160.0),
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 0.96,
                                          letterSpacing: 4.0,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: bottomGap),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: widget.circleSize * 0.18),
                          child: _MainHomeHeroCountdownTapTarget(
                            circleSize: widget.circleSize,
                            onTap: widget.isSingle
                                ? null
                                : widget.onEditBottomLabel,
                            onLongPress:
                                widget.state._showCountdownQuickCustomizeSheet,
                            constraints: BoxConstraints(
                              minWidth: bottomLabelWidth,
                              maxWidth: bottomLabelWidth,
                              minHeight: labelHeight,
                              maxHeight: labelHeight,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: isMultiColor
                                ? ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: countdownVisual.numberGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    blendMode: BlendMode.srcIn,
                                    child: Text(
                                      widget.circleBottomLabel,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: SLTheme.textStyleForKey(
                                        labelFont,
                                        fontSize: (widget.circleSize * 0.12)
                                            .clamp(20.0, 46.0),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    widget.circleBottomLabel,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: SLTheme.textStyleForKey(
                                      labelFont,
                                      fontSize: (widget.circleSize * 0.12)
                                          .clamp(20.0, 46.0),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: customTextColor ??
                                          countdownVisual.bottomLabelColor,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Outer ring & clickable heart badge (positioned in the larger parent stack)
            if (widget.countdownStyleKey == 'floating_hearts') ...[
              // Outer decorative thin ring
              IgnorePointer(
                child: Container(
                  width: widget.circleSize * 1.16,
                  height: widget.circleSize * 1.16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Clickable floating heart badge on bottom-left
              Positioned(
                left: widget.circleSize * 0.02,
                bottom: widget.circleSize * 0.02,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _triggerExplosion(Offset(
                        widget.circleSize * 0.1, widget.circleSize * 1.1));
                  },
                  child: Icon(
                    Icons.favorite_rounded,
                    size: widget.circleSize * 0.16,
                    color: const Color(0xFFFF9FBC),
                  ),
                ),
              ),
            ],

            // 3. Active exploding photos (drawn on top, not clipped)
            for (final photo in _activeExplosions)
              HomeExplodingPhotoWidget(key: photo.id, photo: photo),
          ],
        ),
      ),
    );
  }
}

class _MainHomeHeroCountdownTapTarget extends StatelessWidget {
  final double circleSize;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BoxConstraints? constraints;

  const _MainHomeHeroCountdownTapTarget({
    required this.circleSize,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.constraints,
  });

  double _countdownTapWidth(double circleSize) =>
      (circleSize * 0.56).clamp(132.0, 240.0);

  double _countdownTapHeight(double circleSize) =>
      (circleSize * 0.16).clamp(46.0, 72.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: constraints ??
            BoxConstraints(
              minWidth: _countdownTapWidth(circleSize),
              minHeight: _countdownTapHeight(circleSize),
            ),
        child: Center(child: child),
      ),
    );
  }
}
