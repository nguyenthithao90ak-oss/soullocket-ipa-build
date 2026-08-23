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
  final String countdownShapeKey;
  final String countdownStyleKey;
  final bool enableMotionBase;
  final ValueListenable<bool>? isScrollingNotifier;
  final bool isMilestone;
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
    required this.countdownShapeKey,
    required this.countdownStyleKey,
    required this.enableMotionBase,
    this.isScrollingNotifier,
    this.isMilestone = false,
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
            countdownShapeKey: countdownShapeKey,
            countdownStyleKey: countdownStyleKey,
            enableMotionBase: enableMotionBase,
            isScrollingNotifier: isScrollingNotifier,
            isMilestone: isMilestone,
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
        // Hiá»ƒn thá»‹ tÃªn nhÃ  Ä‘Ã£ bá»‹ áº©n theo yÃªu cáº§u
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
            : widget.photo.url.startsWith('assets/')
                ? Image.asset(
                    widget.photo.url,
                    fit: BoxFit.contain,
                  )
                : CachedNetworkImage(
                    imageUrl: widget.photo.url,
                    fit: BoxFit.contain,
                    memCacheWidth: 300,
                    useOldImageOnUrlChange: true,
                    fadeInDuration: Duration.zero,
                    errorWidget: (_, _, _) => Container(
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
  final String countdownShapeKey;
  final String countdownStyleKey;
  final bool enableMotionBase;
  final ValueListenable<bool>? isScrollingNotifier;
  final bool isMilestone;
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
    required this.countdownShapeKey,
    required this.countdownStyleKey,
    required this.enableMotionBase,
    this.isScrollingNotifier,
    this.isMilestone = false,
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

  bool _isProUser = false;
  int _dailyExplosionCount = 0;
  bool _showFirstTimeHint = false;
  Timer? _hintDismissTimer;

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

    unawaited(_ensurePhotosLoaded());

    PurchaseService().isVip().then((isVip) {
      if (mounted) setState(() => _isProUser = isVip);
    });
    _loadExplosionLimit();

    SharedPreferences.getInstance().then((prefs) {
      if (prefs.getBool('seen_countdown_long_press_hint') != true) {
        if (mounted) {
          setState(() => _showFirstTimeHint = true);
          // Tá»± Ä‘á»™ng áº©n sau 1 phÃºt
          _hintDismissTimer = Timer(const Duration(minutes: 1), () {
            if (mounted && _showFirstTimeHint) {
              setState(() => _showFirstTimeHint = false);
            }
          });
        }
      }
    });
  }

  void _handleLongPressHint() {
    if (_showFirstTimeHint) {
      setState(() => _showFirstTimeHint = false);
      _hintDismissTimer?.cancel();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('seen_countdown_long_press_hint', true);
      });
    }
    widget.state._showCountdownQuickCustomizeSheet();
  }

  Future<void> _loadExplosionLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('explosion_date') ?? '';
    if (savedDate == today) {
      _dailyExplosionCount = prefs.getInt('explosion_count') ?? 0;
    } else {
      _dailyExplosionCount = 0;
      await prefs.setString('explosion_date', today);
      await prefs.setInt('explosion_count', 0);
    }
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
    _hintDismissTimer?.cancel();
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
      void extractUrls(dynamic data) {
        if (data == null) return;
        if (data is String) {
          final s = data.trim();
          // Lấy tất cả mọi link http không phải âm thanh/video và không chứa khoảng trắng
          if (s.startsWith('http') &&
              !s.contains(' ') &&
              !s.contains('.m4a') &&
              !s.contains('.mp4') &&
              !s.contains('.mp3') &&
              !s.contains('.wav') &&
              seen.add(s)) {
            urls.add(s);
          }
        } else if (data is Iterable) {
          for (final item in data) {
            extractUrls(item);
          }
        } else if (data is Map) {
          data.values.forEach(extractUrls);
        }
      }

      // 1. Fetch from diaries collection (Firestore)
      try {
        final diariesSnap = await firestore
            .collection('houses')
            .doc(houseId)
            .collection('diaries')
            .limit(20)
            .get();
        for (var doc in diariesSnap.docs) {
          extractUrls(doc.data());
        }
      } catch (e) {
        debugPrint('[HomeCountdownCircle] diaries fetch error: $e');
      }

      // 2. Fetch from album collection (Firestore)
      try {
        final albumSnap = await firestore
            .collection('houses')
            .doc(houseId)
            .collection('album')
            .limit(20)
            .get();
        for (var doc in albumSnap.docs) {
          extractUrls(doc.data());
        }
      } catch (e) {
        debugPrint('[HomeCountdownCircle] album fetch error: $e');
      }

      // 3. Fetch from memories collection (Firestore)
      try {
        final memoriesSnap = await firestore
            .collection('houses')
            .doc(houseId)
            .collection('memories')
            .limit(20)
            .get();
        for (var doc in memoriesSnap.docs) {
          extractUrls(doc.data());
        }
      } catch (e) {
        debugPrint('[HomeCountdownCircle] memories fetch error: $e');
      }

      // 4. RTDB Fallback (diary & creative_diary & album & memory)
      try {
        final rtdbRefs = [
          'diary',
          'creative_diary',
          'album',
          'memory',
          'memories'
        ];
        for (final refName in rtdbRefs) {
          final snap = await FirebaseDatabase.instance
              .ref('houses/$houseId/$refName')
              .get();
          if (snap.exists && snap.value != null) {
            extractUrls(snap.value);
          }
        }
      } catch (e) {
        debugPrint('[HomeCountdownCircle] rtdb fetch error: $e');
      }

      if (mounted) {
        urls.shuffle();
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

  void _triggerExplosion(Offset localPos) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString('explosion_date') != today) {
      _dailyExplosionCount = 0;
      await prefs.setString('explosion_date', today);
    }

    if (_dailyExplosionCount >= 50) return;

    _dailyExplosionCount++;
    await prefs.setInt('explosion_count', _dailyExplosionCount);

    HapticFeedback.mediumImpact();
    unawaited(_ensurePhotosLoaded());

    if (_cachedPhotoUrls.length > 3) {
      final first = _cachedPhotoUrls.removeAt(0);
      _cachedPhotoUrls.add(first);
    }

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
    final labelFont = (selectedFont.isEmpty || selectedFont == 'default' || selectedFont == 'comfortaa')
        ? 'quicksand'
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
    const multiColorGradient = [
      Color(0xFF00C6FF),
      Color(0xFF9D50BB),
      Color(0xFFF44336),
      Color(0xFF00C6FF),
    ];

    final topClean = widget.circleTopLabel.trim();
    final topLen = topClean.length;
    final int topMaxLines =
        (topLen > 12 || (topLen > 8 && topClean.contains(' '))) ? 2 : 1;
    final double topFontSize = topLen <= 8
        ? (widget.circleSize * 0.135).clamp(20.0, 48.0)
        : topLen <= 14
            ? (widget.circleSize * 0.105).clamp(16.0, 36.0)
            : (widget.circleSize * 0.085).clamp(13.0, 26.0);

    final bottomClean = widget.circleBottomLabel.trim();
    final bottomLen = bottomClean.length;
    final int bottomMaxLines =
        (bottomLen > 12 || (bottomLen > 8 && bottomClean.contains(' '))) ? 2 : 1;
    final double bottomFontSize = bottomLen <= 8
        ? (widget.circleSize * 0.14).clamp(22.0, 50.0)
        : bottomLen <= 14
            ? (widget.circleSize * 0.11).clamp(17.0, 38.0)
            : (widget.circleSize * 0.09).clamp(14.0, 28.0);

    final labelHeight = (widget.circleSize * (topMaxLines > 1 ? 0.22 : 0.18))
        .clamp(28.0, 84.0)
        .toDouble();
    final bottomLabelHeight = (widget.circleSize * (bottomMaxLines > 1 ? 0.22 : 0.18))
        .clamp(28.0, 84.0)
        .toDouble();
    final numberHeight =
        (widget.circleSize * 0.44).clamp(70.0, 180.0).toDouble();
    final topLabelWidth = widget.circleSize * 0.64;
    final bottomLabelWidth = widget.circleSize * 0.64;
    final numberWidth = widget.circleSize * 0.82;
    final topGap = (widget.circleSize * 0.04).clamp(6.0, 20.0).toDouble();
    final bottomGap = (widget.circleSize * 0.03).clamp(4.0, 16.0).toDouble();

    // Milestone glow border colour
    final BorderSide milestoneBorderSide = widget.isMilestone
        ? const BorderSide(color: Color(0xFFFFD700), width: 3.5)
        : BorderSide.none;

    return KeyedSubtree(
      key: widget.firstGuideHeroKey,
      child: SizedBox(
        width: widget.circleSize * 1.2,
        height: widget.circleSize * 1.2,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 0. Sparkle ring for milestone days
            if (widget.isMilestone)
              AnniversarySparkleRing(
                size: widget.circleSize * 1.2,
                ringRadius: widget.circleSize * 0.56,
                enabled: true,
                primaryColor: const Color(0xFFFFD700),
                accentColor: const Color(0xFFFF80AB),
              ),

            // 1. The main interactive circle
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: null,
              onLongPress: _handleLongPressHint,
              child: Container(
                width: widget.circleSize,
                height: widget.circleSize,
                decoration: ShapeDecoration(
                  shape: SlCountdownShapes.getShapeBorderForKey(
                    widget.countdownShapeKey,
                    side: widget.isMilestone ? milestoneBorderSide : BorderSide.none,
                  ),
                  color: (widget.isMilestone || countdownVisual.outerGradient != null) ? null : countdownVisual.outerColor,
                  gradient: widget.isMilestone
                      ? const RadialGradient(
                          center: Alignment.topLeft,
                          radius: 1.2,
                          colors: [
                            Color(0xFFFFE082),
                            Color(0xFFFF6FA3),
                            Color(0xFFAD1457),
                          ],
                        )
                      : countdownVisual.outerGradient,
                  shadows: widget.isMilestone
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFFFFD700).withValues(alpha: 0.55),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ]
                      : SLShadows.glowingPrimary,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Builder(
                        builder: (context) {
                          Widget buildBackground(bool enableMotion) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: Padding(
                                    padding: (countdownVisual.outerColor !=
                                                null ||
                                            countdownVisual.outerGradient !=
                                                null ||
                                            countdownVisual.outerBorder != null)
                                        ? SLSpacing.all12
                                        : EdgeInsets.zero,
                                    child: Container(
                                      clipBehavior: Clip.antiAlias,
                                      decoration: ShapeDecoration(
                                        shape: SlCountdownShapes.getShapeBorderForKey(
                                          widget.countdownShapeKey,
                                          side: (countdownVisual.innerBorder is Border)
                                              ? (countdownVisual.innerBorder as Border).top
                                              : BorderSide.none,
                                        ),
                                        color: countdownVisual.innerGradient != null ? null : countdownVisual.innerColor,
                                        gradient: countdownVisual.innerGradient,
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          RepaintBoundary(
                                            child: AnimatedWaveBackground(
                                              styleKey: (transparentMode || UiPrefs.notifier.value.liteMode)
                                                  ? 'plain'
                                                  : widget.countdownStyleKey,
                                              enableMotion: enableMotion,
                                              transparentMode: transparentMode,
                                            ),
                                          ),
                                          if (_cachedPhotoUrls.isNotEmpty &&
                                              widget.countdownStyleKey == 'floating_hearts')
                                            RepaintBoundary(
                                              child: SnowGlobePhotoLayer(
                                                photoUrls: _cachedPhotoUrls.take(3).toList(),
                                                circleSize: widget.circleSize,
                                                enableMotion: enableMotion,
                                              ),
                                            ),
                                          if (widget.countdownStyleKey == 'floating_hearts')
                                            RepaintBoundary(
                                              child: FloatingHeartsRingOverlay(
                                                size: widget.circleSize,
                                                enableMotion: enableMotion,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          if (widget.isScrollingNotifier == null) {
                            return buildBackground(widget.enableMotionBase);
                          }

                          return ValueListenableBuilder<bool>(
                            valueListenable: widget.isScrollingNotifier!,
                            builder: (context, isScrolling, _) =>
                                buildBackground(widget.enableMotionBase),
                          );
                        },
                      ),
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
                            onLongPress: _handleLongPressHint,
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
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: multiColorGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        widget.circleTopLabel,
                                        maxLines: topMaxLines,
                                        softWrap: true,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.textStyleForKey(
                                          labelFont,
                                          fontSize: topFontSize,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: topLen > 10 ? 0.4 : 1.0,
                                          color: Colors.white,
                                        ).copyWith(
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              offset: const Offset(0, 1.5),
                                              blurRadius: 3.0,
                                            ),
                                            if (widget.isMilestone)
                                              Shadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 12),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Text(
                                      widget.circleTopLabel,
                                      maxLines: topMaxLines,
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: SLTheme.textStyleForKey(
                                        labelFont,
                                        fontSize: topFontSize,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: topLen > 10 ? 0.4 : 1.0,
                                        color: customTextColor ??
                                            countdownVisual.topLabelColor,
                                      ).copyWith(
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            offset: const Offset(0, 1.5),
                                            blurRadius: 3.0,
                                          ),
                                          if (widget.isMilestone)
                                            Shadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 12),
                                        ],
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
                          onLongPress: _handleLongPressHint,
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
                                colors: isMultiColor
                                    ? multiColorGradient
                                    : customTextColor != null
                                        ? [customTextColor, customTextColor]
                                        : countdownVisual.numberGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: AnimatedBuilder(
                                animation: _countAnimation,
                                builder: (context, child) {
                                  final parsed =
                                      int.tryParse(widget.circleValue);
                                  final displayVal = parsed == null
                                      ? widget.circleValue
                                      : _countAnimation.value
                                          .round()
                                          .toString();
                                  return Text(
                                    displayVal,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: widget.state
                                        ._uiTextStyle(
                                          fontSize: (widget.circleSize * 0.44)
                                              .clamp(64.0, 180.0),
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 0.96,
                                          letterSpacing: 2.0,
                                        )
                                        .copyWith(
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.20),
                                              offset: const Offset(0, 2),
                                              blurRadius: 5.0,
                                            ),
                                            if (widget.isMilestone)
                                              Shadow(
                                                  color: Colors.white
                                                      .withValues(
                                                          alpha: 0.7),
                                                  blurRadius: 16),
                                          ],
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
                            onLongPress: _handleLongPressHint,
                            constraints: BoxConstraints(
                              minWidth: bottomLabelWidth,
                              maxWidth: bottomLabelWidth,
                              minHeight: bottomLabelHeight,
                              maxHeight: bottomLabelHeight,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: isMultiColor
                                  ? ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: multiColorGradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        widget.circleBottomLabel,
                                        maxLines: bottomMaxLines,
                                        softWrap: true,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.textStyleForKey(
                                          labelFont,
                                          fontSize: bottomFontSize,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: bottomLen > 10 ? 0.4 : 0.8,
                                          color: Colors.white,
                                        ).copyWith(
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              offset: const Offset(0, 1.5),
                                              blurRadius: 3.0,
                                            ),
                                            if (widget.isMilestone)
                                              Shadow(
                                                  color: Colors.white
                                                      .withValues(
                                                          alpha: 0.6),
                                                  blurRadius: 12),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Text(
                                      widget.circleBottomLabel,
                                      maxLines: bottomMaxLines,
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: SLTheme.textStyleForKey(
                                        labelFont,
                                        fontSize: bottomFontSize,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: bottomLen > 10 ? 0.4 : 0.8,
                                        color: customTextColor ??
                                            countdownVisual.bottomLabelColor,
                                      ).copyWith(
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            offset: const Offset(0, 1.5),
                                            blurRadius: 3.0,
                                          ),
                                          if (widget.isMilestone)
                                            Shadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 12),
                                        ],
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
              // Clickable floating heart badge on bottom-left, using Align for better dynamic positioning
              Positioned(
                left: widget.circleSize * 0.1,
                bottom: widget.circleSize * 0.05,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!_isProUser) {
                      SLNotice.showInfo(context,
                          'Hiệu ứng bắn tim chỉ dành cho tài khoản Pro!');
                      return;
                    }
                    if (_dailyExplosionCount >= 50) {
                      SLNotice.showInfo(
                          context, 'Hôm nay bạn đã hết lượt thả tim rồi nhé!');
                      return;
                    }
                    _triggerExplosion(Offset(
                        widget.circleSize * 0.1, widget.circleSize * 1.1));
                  },
                  child: Icon(
                    Icons.favorite_rounded,
                    size: widget.circleSize * 0.18,
                    color: const Color(0xFFFF9FBC),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 3. Active exploding photos (drawn on top, not clipped)
            for (final photo in _activeExplosions)
              HomeExplodingPhotoWidget(key: photo.id, photo: photo),

            // 4. First time hint
            if (_showFirstTimeHint)
              Center(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Nhấn giữ để chỉnh sửa',
                            style: widget.state._uiTextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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


