part of '../../../tabs/main_home_tab.dart';

class AnimatedWaveBackground extends StatefulWidget {
  final String styleKey;
  final bool enableMotion;
  final bool transparentMode;

  const AnimatedWaveBackground({
    super.key,
    required this.styleKey,
    required this.enableMotion,
    this.transparentMode = false,
  });

  static bool hasMotion(String styleKey) {
    return styleKey != 'plain';
  }

  @override
  State<AnimatedWaveBackground> createState() =>
      _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // Shake detection and ripple states
  double _lastX = 0.0;
  double _lastY = 0.0;
  double _lastZ = 0.0;
  bool _isFirstEvent = true;
  double _shakeIntensity = 0.0;
  final List<_TapInteractionEffect> _tapEffects = [];
  // Throttle sensor: chỉ xử lý 1 event mỗi 16ms (~60fps)
  int _lastSensorProcessedMs = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    UiPrefs.notifier.addListener(_onUiPrefsChanged);
  }

  void _initSensor() {
    if (kIsWeb) return;
    try {
      _sensorSubscription?.cancel();
      _isFirstEvent = true;

      double? lastRawX;
      double? lastRawY;
      int staticCount = 0;
      bool isSensorActive = true;

      _sensorSubscription = SensorHelper.accelerometerEvents.listen(
        (event) {
          if (!mounted) return;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastSensorProcessedMs < 16) return;
          _lastSensorProcessedMs = nowMs;

          // Check if sensor is sending changing values (to detect static/emulated sensors)
          if (lastRawX != null && lastRawY != null) {
            if ((event.x - lastRawX!).abs() < 0.0001 && (event.y - lastRawY!).abs() < 0.0001) {
              staticCount++;
              if (staticCount > 10) {
                isSensorActive = false;
              }
            } else {
              staticCount = 0;
              isSensorActive = true;
            }
          }
          lastRawX = event.x;
          lastRawY = event.y;

          if (!isSensorActive) return;

          // Smooth the tilt using low-pass filter (lerp)
          final targetX = -event.x.clamp(-6.0, 6.0) * 3.5;
          final targetY = event.y.clamp(-6.0, 6.0) * 3.5;
          _tiltX = _tiltX * 0.92 + targetX * 0.08;
          _tiltY = _tiltY * 0.92 + targetY * 0.08;

          // Detect shake using acceleration changes
          if (_isFirstEvent) {
            _lastX = event.x;
            _lastY = event.y;
            _lastZ = event.z;
            _isFirstEvent = false;
            return;
          }

          final deltaX = event.x - _lastX;
          final deltaY = event.y - _lastY;
          final deltaZ = event.z - _lastZ;

          _lastX = event.x;
          _lastY = event.y;
          _lastZ = event.z;

          final force = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);
          // Threshold of 3.5 m/s^2 represents a sudden shake
          if (force > 3.5) {
            _shakeIntensity = (_shakeIntensity + 0.45).clamp(0.0, 1.5);

            final now = DateTime.now();
            if (_tapEffects.isEmpty ||
                now.difference(_tapEffects.last.startTime).inMilliseconds > 250) {
              if (_tapEffects.length >= 3) {
                _tapEffects.removeAt(0);
              }
              final random = Random();
              _tapEffects.add(
                _TapInteractionEffect(
                  centerOffset: Offset(
                    (random.nextDouble() - 0.5) * 80.0,
                    (random.nextDouble() - 0.5) * 80.0,
                  ),
                  startTime: now,
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState(_shouldAnimateFor());
  }

  @override
  void didUpdateWidget(AnimatedWaveBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.styleKey != widget.styleKey ||
        oldWidget.enableMotion != widget.enableMotion) {
      _syncAnimationState(_shouldAnimateFor());
    }
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_onUiPrefsChanged);
    _sensorSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onUiPrefsChanged() {
    if (!mounted) return;
    _syncAnimationState(_shouldAnimateFor());
  }

  bool _shouldAnimateFor() {
    if (!AnimatedWaveBackground.hasMotion(widget.styleKey)) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    return widget.enableMotion;
  }

  void _syncAnimationState(bool shouldAnimate) {
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      if (_sensorSubscription == null) {
        _initSensor();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _sensorSubscription?.cancel();
      _sensorSubscription = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AnimatedWaveBackground.hasMotion(widget.styleKey)) {
      return const SizedBox.expand();
    }
    final isBasicStyle = widget.styleKey == 'default' || widget.styleKey == 'plain' || widget.styleKey.isEmpty;
    if (widget.transparentMode && isBasicStyle) {
      return const SizedBox.expand();
    }
    final uiState = UiPrefs.notifier.value;
    final effectProfile = UiPrefs.resolveEffectProfile(
      state: uiState,
      isWeb: kIsWeb,
    );
    final quality = effectProfile.graphicsQualityKey;

    final result = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shouldAnimate = _shouldAnimateFor();

        // Decay shake intensity on every frame
        if (shouldAnimate) {
          if (_shakeIntensity > 0.001) {
            _shakeIntensity *= 0.94;
          } else {
            _shakeIntensity = 0.0;
          }

          // Filter out expired ripples
          final now = DateTime.now();
          _tapEffects.removeWhere((r) => r.getProgress(now) >= 1.0);
        }

        return CustomPaint(
          painter: _WavePainter(
            shouldAnimate ? _controller.value : 0.0,
            widget.styleKey,
            quality: quality,
            tiltX: _tiltX,
            tiltY: _tiltY,
            shakeIntensity: _shakeIntensity,
            tapEffects: List.from(_tapEffects),
          ),
        );
      },
    );

    return RepaintBoundary(
      child: MouseRegion(
        onHover: (event) {
          final localPos = event.localPosition;
          final renderBox = context.findRenderObject();
          if (renderBox is RenderBox && renderBox.hasSize) {
            final size = renderBox.size;
            final centerX = size.width / 2;
            final centerY = size.height / 2;
            if (centerX > 0.0 && centerY > 0.0) {
              _tiltX = (localPos.dx - centerX) / centerX * 12.0;
              _tiltY = (localPos.dy - centerY) / centerY * 12.0;
            }
          }
        },
        onExit: (_) {
          _tiltX = 0.0;
          _tiltY = 0.0;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            final renderBox = context.findRenderObject();
            if (renderBox is RenderBox && renderBox.hasSize) {
              final localPos = event.localPosition;
              final size = renderBox.size;
              final centerX = size.width / 2;
              final centerY = size.height / 2;
              if (centerX > 0.0 && centerY > 0.0) {
                final offset = Offset(localPos.dx - centerX, localPos.dy - centerY);
                _shakeIntensity = (_shakeIntensity + 0.45).clamp(0.0, 1.5);
                if (_tapEffects.length >= 4) {
                  _tapEffects.removeAt(0);
                }
                _tapEffects.add(
                  _TapInteractionEffect(
                    centerOffset: offset,
                    startTime: DateTime.now(),
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              }
            }
          },
          child: result,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final String styleKey;
  final String quality;
  final double tiltX;
  final double tiltY;
  final double shakeIntensity;
  final List<_TapInteractionEffect> tapEffects;

  _WavePainter(
    this.animationValue,
    this.styleKey, {
    required this.quality,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.shakeIntensity = 0.0,
    this.tapEffects = const [],
  });

  
  MaskFilter? _getBlur(double sigma) {
    if (quality != 'high') return null;
    return MaskFilter.blur(BlurStyle.normal, sigma);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final radius = min(width, height) / 2;
    final center = Offset(width / 2, height / 2);

    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    if (styleKey == 'plain') {
      return;
    } else if (styleKey == 'glow') {
      _drawGlowHearts(canvas, width, height);
    } else if (styleKey == 'glass') {
      _drawGlassBubbles(canvas, width, height);
    } else if (styleKey == 'galaxy') {
      _drawGalaxy(canvas, width, height, center, radius);
    } else if (styleKey == 'neon') {
      _drawNeonParty(canvas, width, height, center, radius);
    } else if (styleKey == 'aurora') {
      _drawAurora(canvas, width, height, center, radius);
    } else if (styleKey == 'crystal') {
      _drawCrystal(canvas, width, height, center, radius);
    } else if (styleKey == 'candy') {
      _drawCandyPop(canvas, width, height, center, radius);
    } else if (styleKey == 'hyper') {
      _drawHyperColor(canvas, width, height, center, radius);
    } else if (styleKey == 'fireworks') {
      _drawFireworks(canvas, width, height, center, radius);
    } else if (styleKey == 'lava') {
      _drawLava(canvas, width, height, center, radius);
    } else if (styleKey == 'cherry_blossom') {
      _drawCherryBlossom(canvas, width, height, center, radius);
    } else if (styleKey == 'meteor_shower') {
      _drawMeteorShower(canvas, width, height, center, radius);
    } else if (styleKey == 'deep_ocean') {
      _drawDeepOcean(canvas, width, height, center, radius);
    } else if (styleKey == 'golden_sunset') {
      _drawGoldenSunset(canvas, width, height, center, radius);
    } else if (styleKey == 'neon_pulse') {
      _drawNeonPulse(canvas, width, height, center, radius);
    } else {
      _drawDefaultWaves(canvas, width, height, center, radius);
    }

    // Draw tap effects specific to style at the end of paint so they overlay on any background style
    _drawTapEffects(canvas, center, radius);
  }

  void _drawHeartPath(
    Canvas canvas,
    double x,
    double y,
    double size,
    double opacity,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFFF4F93).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    if (quality == 'high') {
      paint.maskFilter = _getBlur(size * 0.25);
    } else if (quality == 'balanced') {
      paint.maskFilter = _getBlur(size * 0.15);
    }

    final path = Path();
    path.moveTo(x, y + size / 4);
    path.cubicTo(
      x - size,
      y - size * 0.7,
      x - size * 0.5,
      y - size,
      x,
      y - size / 4,
    );
    path.cubicTo(
      x + size * 0.5,
      y - size,
      x + size,
      y - size * 0.7,
      x,
      y + size / 4,
    );

    if (quality == 'high') {
      canvas.drawShadow(
        path,
        const Color(0xFFFF4F93).withValues(alpha: opacity * 0.3),
        4,
        false,
      );
    }
    canvas.drawPath(path, paint);
  }

  void _drawGlowHearts(Canvas canvas, double width, double height) {
    final heartCount = quality == 'low' ? 3 : (quality == 'balanced' ? 6 : 8);
    for (var i = 0; i < heartCount; i++) {
      final startX = width * ((i * 0.37 + 0.1) % 1.0);
      final speed = 0.5 + (i * 0.2 % 0.5);
      final size = 12.0 + (i * 5 % 12);

      final progress = (animationValue * speed + (i * 0.17)) % 1.0;
      final y = height + size - progress * (height + size * 2) + tiltY * (0.6 + i * 0.1);
      final x = startX + sin((animationValue * pi * 4) + i) * 15 + tiltX * (0.6 + i * 0.1);
      final opacity = sin(progress * pi);

      _drawHeartPath(canvas, x, y, size, opacity * 0.8);
    }
  }

  void _drawGlassBubbles(Canvas canvas, double width, double height) {
    final bubblePaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final count = quality == 'low' ? 4 : (quality == 'balanced' ? 7 : 10);
    for (var i = 0; i < count; i++) {
      final startX = width * ((i * 0.43 + 0.05) % 1.0);
      final speed = 0.4 + (i * 0.15 % 0.6);
      final size = 6.0 + (i * 7 % 14);

      final progress = (animationValue * speed + (i * 0.23)) % 1.0;
      final y = height + size - progress * (height + size * 2) + tiltY * (0.5 + i * 0.1);
      final x = startX + cos((animationValue * pi * 3) + i * 2) * 12 + tiltX * (0.5 + i * 0.1);
      final opacity = sin(progress * pi);

      bubblePaint.color = Colors.white.withValues(alpha: 0.15 * opacity);
      if (quality == 'high') {
        bubblePaint.maskFilter = _getBlur(2);
      } else if (quality == 'balanced') {
        bubblePaint.maskFilter = _getBlur(1);
      } else {
        bubblePaint.maskFilter = null;
      }
      canvas.drawCircle(Offset(x, y), size, bubblePaint);

      if (quality != 'low') {
        borderPaint.color = Colors.white.withValues(alpha: 0.4 * opacity);
        canvas.drawCircle(Offset(x, y), size, borderPaint);
      }
    }
  }

  void _drawDefaultWaves(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    if (quality != 'low') {
      // Pulsing ring - nhẹ, chỉ drawCircle, có lệch nhẹ theo nghiêng
      // Giảm alpha cho balanced để sóng không quá sáng
      final ringAlphaFactor = quality == 'balanced' ? 0.72 : 1.0;
      final ringPaint1 = Paint()
        ..color = const Color(0xFFFFC6DA).withValues(alpha: 0.13 * (1 - animationValue) * ringAlphaFactor)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(center.dx + tiltX * 0.3, center.dy + tiltY * 0.3),
        radius * (0.8 + 0.2 * animationValue),
        ringPaint1,
      );

      final phase2 = (animationValue + 0.5) % 1.0;
      final ringPaint2 = Paint()
        ..color = const Color(0xFFFF9EBB).withValues(alpha: 0.08 * (1 - phase2) * ringAlphaFactor)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(center.dx + tiltX * 0.3, center.dy + tiltY * 0.3),
        radius * (0.8 + 0.2 * phase2),
        ringPaint2,
      );
    }

    void drawWave(
      Color color,
      double amplitude,
      double frequency,
      double phaseShift,
      double verticalOffset,
    ) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final yBase = height * verticalOffset + (tiltY * 0.75);
      final tiltAmount = tiltX * 3.5;

      final step = quality == 'high' ? 8.0 : 16.0;
      final path = Path()..moveTo(0, height);
      for (double i = 0; i <= width; i += step) {
        final relX = i / width;
        final wave = sin(
                  (relX * frequency * pi * 2) +
                      (animationValue * pi * 2) +
                      phaseShift,
                ) *
                amplitude;
        final tilt = (relX - 0.5) * tiltAmount * 2.0;
        final y = yBase + wave + tilt;
        if (i == 0) {
          path.lineTo(0, y);
        } else {
          path.lineTo(i, y);
        }
      }
      path
        ..lineTo(width, height)
        ..close();

      canvas.drawPath(path, paint);
    }

    void drawWaveBezier(
      Color color,
      double amplitude,
      double phaseShift,
      double verticalOffset,
    ) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final yBase = height * verticalOffset + (tiltY * 0.75);
      final t = animationValue * pi * 2 + phaseShift;

      final tiltAmount = tiltX * 3.5;
      final y0 = yBase + sin(t) * amplitude - tiltAmount;
      final y1 = yBase + sin(t + pi * 0.5) * amplitude - tiltAmount * 0.5;
      final y2 = yBase + sin(t + pi) * amplitude;
      final y3 = yBase + sin(t + pi * 1.5) * amplitude + tiltAmount * 0.5;
      final yLast = yBase + sin(t + pi * 2) * amplitude + tiltAmount;

      final path = Path()
        ..moveTo(0, height)
        ..lineTo(0, y0)
        ..cubicTo(width * 0.25, y1, width * 0.5, y2, width * 0.75, y3)
        ..cubicTo(width * 0.88, yBase + sin(t + pi * 1.75) * amplitude + tiltAmount * 0.8, width, yLast, width, yLast)
        ..lineTo(width, height)
        ..close();

      canvas.drawPath(path, paint);
    }

    final double shakeAmpMultiplier = 1.0 + shakeIntensity * 1.5;
    if (quality == 'low') {
      drawWaveBezier(const Color(0xFFFFC6DA).withValues(alpha: 0.32), 18 * shakeAmpMultiplier, 0, 0.55);
      drawWaveBezier(const Color(0xFFFFB1CA).withValues(alpha: 0.40), 10 * shakeAmpMultiplier, pi, 0.65);
    } else if (quality == 'balanced') {
      // Balanced: giảm alpha ~25% để sóng không quá chói
      drawWave(const Color(0xFFFFC6DA).withValues(alpha: 0.24), 18 * shakeAmpMultiplier, 1.0, 0, 0.55);
      drawWave(const Color(0xFFFF9EBB).withValues(alpha: 0.19), 14 * shakeAmpMultiplier, 1.2, pi / 2, 0.60);
      drawWave(const Color(0xFFFFB1CA).withValues(alpha: 0.30), 10 * shakeAmpMultiplier, 1.5, pi, 0.65);
    } else {
      drawWave(const Color(0xFFFFC6DA).withValues(alpha: 0.32), 18 * shakeAmpMultiplier, 1.0, 0, 0.55);
      drawWave(const Color(0xFFFF9EBB).withValues(alpha: 0.26), 14 * shakeAmpMultiplier, 1.2, pi / 2, 0.60);
      drawWave(const Color(0xFFFFB1CA).withValues(alpha: 0.40), 10 * shakeAmpMultiplier, 1.5, pi, 0.65);
    }
  }

  void _drawGalaxy(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          const Color(0xFF1A0533).withValues(alpha: 0.9),
          const Color(0xFF0D0221).withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    final angle = animationValue * pi * 2;

    if (quality != 'low') {
      final swirl1 = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: const [
            Color(0xFF8B2FC9),
            Color(0xFF4A6CF7),
            Color(0xFFFF4EBB),
            Color(0xFF00D4FF),
            Color(0xFF8B2FC9),
          ],
          startAngle: angle,
          endAngle: angle + pi * 2,
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));
      
      if (quality == 'high') {
        swirl1.maskFilter = _getBlur(12);
      } else {
        swirl1.maskFilter = _getBlur(5);
      }
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle) * radius * 0.2,
          center.dy + sin(angle) * radius * 0.2,
        ),
        radius * 0.45,
        swirl1,
      );
    }

    if (quality == 'high') {
      final swirl2 = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: const [
            Color(0xFF00D4FF),
            Color(0xFFFF4EBB),
            Color(0xFF8B2FC9),
            Color(0xFF00D4FF),
          ],
          startAngle: angle + pi,
          endAngle: angle + pi * 3,
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.5))
        ..maskFilter = _getBlur(8);
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle + pi) * radius * 0.15,
          center.dy + sin(angle + pi) * radius * 0.15,
        ),
        radius * 0.3,
        swirl2,
      );
    }
  }

  void _drawNeonParty(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF0A001A).withValues(alpha: 0.92),
    );

    final barColors = [
      const Color(0xFFFF0080),
      const Color(0xFF00FFEA),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF44),
      const Color(0xFFFF6600),
      const Color(0xFF9900FF),
    ];
    final barCount = quality == 'low' ? 3 : (quality == 'balanced' ? 4 : 6);
    for (var i = 0; i < barCount; i++) {
      final barAngle = animationValue * pi * 2 + (i * pi / 3);
      final pulse = (sin(animationValue * pi * 6 + i) + 1) / 2;
      final len = radius * (0.55 + pulse * 0.2);
      final paint = Paint()
        ..color = barColors[i].withValues(alpha: 0.4 + pulse * 0.35)
        ..strokeWidth = 3.5 + pulse * 2.0
        ..strokeCap = StrokeCap.round;
      if (quality == 'high') {
        paint.maskFilter = _getBlur(6 + pulse * 4);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(3 + pulse * 2);
      }
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(barAngle) * len,
          center.dy + sin(barAngle) * len,
        ),
        paint,
      );
    }

    final ringCount = quality == 'low' ? 1 : (quality == 'balanced' ? 2 : 3);
    for (var r = 0; r < ringCount; r++) {
      final phase = (animationValue + r * 0.33) % 1.0;
      final ringR = radius * 0.3 + radius * 0.65 * phase;
      final paint = Paint()
        ..color = barColors[r * 2 % barColors.length]
            .withValues(alpha: (1 - phase) * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      if (quality == 'high') {
        paint.maskFilter = _getBlur(5);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(3);
      }
      canvas.drawCircle(center, ringR, paint);
    }
  }

  void _drawAurora(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF011329).withValues(alpha: 0.95),
            const Color(0xFF001A12).withValues(alpha: 0.95),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height)),
    );

    final auroraConfig = quality == 'low'
        ? [
            [0.35, 0.12, 1.0, 0.0, 1.0, 0.6, 0.55],
            [0.50, 0.14, 1.2, 0.5, 0.3, 1.0, 0.35],
          ]
        : (quality == 'balanced'
            ? [
                [0.35, 0.12, 1.0, 0.0, 1.0, 0.6, 0.55],
                [0.50, 0.14, 1.2, 0.5, 0.3, 1.0, 0.35],
                [0.65, 0.11, 1.5, 0.8, 0.2, 1.0, 0.25],
              ]
            : [
                [0.35, 0.12, 1.0, 0.0, 1.0, 0.6, 0.55],
                [0.42, 0.10, 0.8, 0.2, 0.9, 1.0, 0.45],
                [0.50, 0.14, 1.2, 0.5, 0.3, 1.0, 0.35],
                [0.58, 0.08, 0.7, 0.0, 0.8, 0.5, 0.30],
                [0.65, 0.11, 1.5, 0.8, 0.2, 1.0, 0.25],
              ]);

    final step = quality == 'low' ? 16.0 : (quality == 'balanced' ? 12.0 : 8.0);

    for (final cfg in auroraConfig) {
      final yBase = height * cfg[0];
      final amp = height * cfg[1];
      final speed = cfg[2];
      final bandColor = Color.fromRGBO(
        (cfg[3] * 255).round(),
        (cfg[4] * 255).round(),
        (cfg[5] * 255).round(),
        cfg[6],
      );
      final path = Path()..moveTo(0, height);
      for (double x = 0; x <= width; x += step) {
        final wave1 =
            sin((x / width * 2 * pi) + animationValue * speed * pi * 2) * amp;
        final wave2 = sin(
              (x / width * 3 * pi) + animationValue * speed * pi * 1.3 + pi / 3,
            ) *
            amp *
            0.5;
        path.lineTo(x, yBase + wave1 + wave2);
      }
      path
        ..lineTo(width, height)
        ..close();
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bandColor,
            bandColor.withValues(alpha: bandColor.a * 0.3),
          ],
        ).createShader(Rect.fromLTWH(0, yBase - amp * 2, width, amp * 4));
      
      if (quality == 'high') {
        paint.maskFilter = _getBlur(8);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(3);
      }
      
      canvas.drawPath(path, paint);
    }

  }

  void _drawCrystal(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            const Color(0xFFE8F4FF).withValues(alpha: 0.8),
            const Color(0xFFF0E8FF).withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final crystalAngle = animationValue * pi * 0.3;
    final facetColors = [
      const Color(0xFFFF9ECC),
      const Color(0xFFA8E6FF),
      const Color(0xFFCCA8FF),
      const Color(0xFFA8FFD4),
      const Color(0xFFFFE8A8),
      const Color(0xFFFF9ECC),
    ];
    final facetOpacities = [0.5, 0.45, 0.4, 0.4, 0.45, 0.35];

    final facetCount = quality == 'low' ? 3 : (quality == 'balanced' ? 4 : 6);
    for (var i = 0; i < facetCount; i++) {
      final facetAngle = crystalAngle + (i * pi / 3);
      final facetAngle2 = crystalAngle + ((i + 1) * pi / 3);
      final pulse = (sin(animationValue * pi * 4 + i) + 1) / 2;
      final path = Path()
        ..moveTo(
          center.dx + cos(facetAngle) * radius * (0.25 + pulse * 0.08),
          center.dy + sin(facetAngle) * radius * (0.25 + pulse * 0.08),
        )
        ..lineTo(
          center.dx + cos(facetAngle) * radius * (0.72 + pulse * 0.06),
          center.dy + sin(facetAngle) * radius * (0.72 + pulse * 0.06),
        )
        ..lineTo(
          center.dx + cos(facetAngle2) * radius * (0.72 + pulse * 0.06),
          center.dy + sin(facetAngle2) * radius * (0.72 + pulse * 0.06),
        )
        ..lineTo(
          center.dx + cos(facetAngle2) * radius * (0.25 + pulse * 0.08),
          center.dy + sin(facetAngle2) * radius * (0.25 + pulse * 0.08),
        )
        ..close();
      
      final paint = Paint()
        ..color = facetColors[i]
            .withValues(alpha: facetOpacities[i] * (0.6 + pulse * 0.4));
      if (quality == 'high') {
        paint.maskFilter = _getBlur(4);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(2);
      }
      canvas.drawPath(path, paint);
    }

    final lineCount = quality == 'low' ? 3 : (quality == 'balanced' ? 4 : 6);
    for (var i = 0; i < lineCount; i++) {
      final lineAngle = crystalAngle * 2 + (i * pi / 3);
      final pulse = (sin(animationValue * pi * 6 + i * 0.7) + 1) / 2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.4)
        ..strokeWidth = 1.5 + pulse * 1.5;
      if (quality == 'high') {
        paint.maskFilter = _getBlur(2 + pulse * 3);
      }
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(lineAngle) * radius * (0.5 + pulse * 0.2),
          center.dy + sin(lineAngle) * radius * (0.5 + pulse * 0.2),
        ),
        paint,
      );
    }

    final fleckCount = quality == 'low' ? 4 : (quality == 'balanced' ? 8 : 12);
    for (var i = 0; i < fleckCount; i++) {
      final fleckAngle =
          animationValue * pi * 2 * (i.isEven ? 1 : -0.7) + i * pi / 6;
      final fleckR = radius * ((i * 0.07 + 0.2) % 0.7);
      final pulse = (sin(animationValue * pi * 5 + i) + 1) / 2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.45);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(2 + pulse * 2);
      }
      canvas.drawCircle(
        Offset(
          center.dx + cos(fleckAngle) * fleckR,
          center.dy + sin(fleckAngle) * fleckR,
        ),
        1.5 + pulse * 2.0,
        paint,
      );
    }

    final centerPaint = Paint();
    if (quality != 'low') {
      centerPaint.shader = SweepGradient(
        colors: const [
          Color(0xFFFF9ECC),
          Color(0xFFA8E6FF),
          Color(0xFFCCA8FF),
          Color(0xFFA8FFD4),
          Color(0xFFFFE8A8),
          Color(0xFFFF9ECC),
        ],
        startAngle: crystalAngle,
        endAngle: crystalAngle + pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.22));
      if (quality == 'high') {
        centerPaint.maskFilter = _getBlur(6);
      } else {
        centerPaint.maskFilter = _getBlur(3);
      }
      canvas.drawCircle(center, radius * 0.22, centerPaint);
    }
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _drawCandyPop(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD8F0), Color(0xFFDDF8FF), Color(0xFFFFF3C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round;
    if (quality == 'high') {
      stripePaint.maskFilter = _getBlur(2);
    } else if (quality == 'balanced') {
      stripePaint.maskFilter = _getBlur(1);
    }
    
    final stripeColors = [
      const Color(0xFFFF6FB7),
      const Color(0xFF53D8FF),
      const Color(0xFFFFD54F),
      const Color(0xFFB388FF),
    ];
    final stripeCount = quality == 'low' ? 3 : (quality == 'balanced' ? 5 : 7);
    for (var i = 0; i < stripeCount; i++) {
      final offset = ((animationValue + i * 0.18) % 1.0) * width * 1.6;
      stripePaint.color =
          stripeColors[i % stripeColors.length].withValues(alpha: 0.20);
      canvas.drawLine(
        Offset(offset - width * 0.9, -height * 0.1),
        Offset(offset, height * 1.1),
        stripePaint,
      );
    }

    final bubbleCount = quality == 'low' ? 5 : (quality == 'balanced' ? 9 : 14);
    for (var i = 0; i < bubbleCount; i++) {
      final progress = (animationValue * (0.45 + i * 0.02) + i * 0.11) % 1.0;
      final x = width * ((i * 0.23 + 0.08) % 1.0) +
          sin(animationValue * pi * 4 + i) * 10;
      final y = height + 16 - progress * (height + 36);
      final size = 4.0 + (i % 4) * 2.0;
      final paint = Paint()
        ..color = stripeColors[(i + 1) % stripeColors.length]
            .withValues(alpha: 0.34 + sin(progress * pi) * 0.22);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(1.5);
      }
      canvas.drawCircle(Offset(x, y), size, paint);
    }
  }

  void _drawHyperColor(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final angle = animationValue * pi * 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFF005D),
            Color(0xFFFFD600),
            Color(0xFF00F5FF),
            Color(0xFF00FF66),
            Color(0xFF7C4DFF),
            Color(0xFFFF00C8),
            Color(0xFFFF005D),
          ],
          startAngle: angle,
          endAngle: angle + pi * 2,
        ).createShader(rect),
    );

    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.34),
            Colors.black.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..blendMode = BlendMode.screen,
    );

    final colors = [
      const Color(0xFFFFF176),
      const Color(0xFFFF00A8),
      const Color(0xFF00E5FF),
      const Color(0xFF69F0AE),
      const Color(0xFFFF6D00),
      Colors.white,
    ];
    final orbitCount = quality == 'low' ? 5 : (quality == 'balanced' ? 10 : 18);
    for (var i = 0; i < orbitCount; i++) {
      final orbit = radius * (0.28 + (i % 5) * 0.11);
      final a = angle * (i.isEven ? 1.0 : -1.25) + i * pi / 9;
      final pulse = (sin(animationValue * pi * 8 + i) + 1) / 2;
      final p = Offset(center.dx + cos(a) * orbit, center.dy + sin(a) * orbit);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.72);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(3 + pulse * 3);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(1.5 + pulse * 1.5);
      }
      canvas.drawCircle(p, 2.8 + pulse * 3.2, paint);
      
      if (quality == 'high' && i % 3 == 0) {
        canvas.drawLine(
          center,
          p,
          Paint()
            ..color = colors[i % colors.length].withValues(alpha: 0.18)
            ..strokeWidth = 1.4
            ..maskFilter = _getBlur(5),
        );
      }
    }

    final burstCount = quality == 'low' ? 3 : (quality == 'balanced' ? 6 : 12);
    for (var i = 0; i < burstCount; i++) {
      final burst = (animationValue + i * 0.083) % 1.0;
      final burstRadius = radius * (0.16 + burst * 0.72);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 + (1 - burst) * 2.8
        ..color = colors[i % colors.length].withValues(alpha: (1 - burst) * 0.42);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(4);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(2);
      }
      canvas.drawCircle(center, burstRadius, paint);
    }
  }

  void _drawFireworks(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF140026), Color(0xFF06000F)],
          radius: 0.8,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final colors = [
      const Color(0xFFFFD54F),
      const Color(0xFFFF4FB3),
      const Color(0xFF40C4FF),
      const Color(0xFF69F0AE),
      const Color(0xFFFF8A65),
      const Color(0xFFE040FB),
      Colors.white,
    ];
    final anchors = quality == 'low'
        ? [
            Offset(width * 0.32, height * 0.35),
            Offset(width * 0.68, height * 0.42),
          ]
        : (quality == 'balanced'
            ? [
                Offset(width * 0.32, height * 0.35),
                Offset(width * 0.68, height * 0.42),
                Offset(width * 0.48, height * 0.65),
              ]
            : [
                Offset(width * 0.32, height * 0.35),
                Offset(width * 0.68, height * 0.42),
                Offset(width * 0.48, height * 0.65),
                Offset(width * 0.20, height * 0.58),
                Offset(width * 0.78, height * 0.28),
              ]);

    for (var b = 0; b < anchors.length; b++) {
      final progress = (animationValue + b * 0.29) % 1.0;
      if (progress < 0.2) {
        final t = progress / 0.2;
        final sy = height - (height - anchors[b].dy) * t;
        final paint = Paint()
          ..color = colors[b % colors.length].withValues(alpha: 1 - t)
          ..strokeWidth = 2.0;
        if (quality == 'high') {
          paint.maskFilter = _getBlur(2);
        } else if (quality == 'balanced') {
          paint.maskFilter = _getBlur(1);
        }
        canvas.drawLine(
          Offset(anchors[b].dx, sy + 25),
          Offset(anchors[b].dx, sy),
          paint,
        );
      }
    }

    final particleCount = quality == 'low' ? 8 : (quality == 'balanced' ? 14 : 24);
    for (var b = 0; b < anchors.length; b++) {
      final progress = (animationValue + b * 0.29) % 1.0;
      if (progress >= 0.2) {
        final burstProgress = (progress - 0.2) / 0.8;
        final burstRadius = radius * (0.05 + burstProgress * 0.65);

        for (var i = 0; i < particleCount; i++) {
          final a = i * (pi * 2 / particleCount) + (burstProgress * pi * 0.1);
          final isLong = i % 2 == 0;
          final currentRadius = isLong ? burstRadius : burstRadius * 0.6;

          final start = Offset(
            anchors[b].dx + cos(a) * (currentRadius * 0.4),
            anchors[b].dy +
                sin(a) * (currentRadius * 0.4) +
                (burstProgress * 20),
          );
          final end = Offset(
            anchors[b].dx + cos(a) * currentRadius,
            anchors[b].dy + sin(a) * currentRadius + (burstProgress * 30),
          );

          final twinkle = (sin(animationValue * pi * 10 + i) + 1) / 2;
          final paint = Paint()
            ..color = colors[(i + b) % colors.length]
                .withValues(alpha: (1 - burstProgress) * (0.6 + twinkle * 0.4))
            ..strokeWidth = 1.5 + (1 - burstProgress) * 2.0
            ..strokeCap = StrokeCap.round;
          if (quality == 'high') {
            paint.maskFilter = _getBlur(3);
          } else if (quality == 'balanced') {
            paint.maskFilter = _getBlur(1.5);
          }
          canvas.drawLine(start, end, paint);

          if (quality != 'low' && isLong && burstProgress > 0.4 && burstProgress < 0.9) {
            final paintDot = Paint()
              ..color = Colors.white.withValues(alpha: 1 - burstProgress);
            if (quality == 'high') {
              paintDot.maskFilter = _getBlur(2);
            } else if (quality == 'balanced') {
              paintDot.maskFilter = _getBlur(1);
            }
            canvas.drawCircle(
              end,
              2.0 * (1 - burstProgress),
              paintDot,
            );
          }
        }

        if (quality != 'low' && burstProgress < 0.4) {
          final paintFlash = Paint()
            ..color = Colors.white.withValues(alpha: 1 - burstProgress / 0.4);
          if (quality == 'high') {
            paintFlash.maskFilter = _getBlur(5);
          } else if (quality == 'balanced') {
            paintFlash.maskFilter = _getBlur(2.5);
          }
          canvas.drawCircle(
            anchors[b],
            6 * (1 - burstProgress / 0.4),
            paintFlash,
          );
        }
      }
    }
  }

  void _drawLava(
    Canvas canvas,
    double width,
    double height,
    Offset center,
    double radius,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF5A0000), Color(0xFF280000), Color(0xFF0A0000)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final lavaColors = [
      const Color(0xFFFFEA00),
      const Color(0xFFFF9100),
      const Color(0xFFFF1744),
      const Color(0xFFFF3D00),
      const Color(0xFFFFC400),
    ];

    final blobCount = quality == 'low' ? 4 : (quality == 'balanced' ? 7 : 14);
    for (var i = 0; i < blobCount; i++) {
      final speed = 0.25 + i * 0.025;
      final progress = (animationValue * speed + i * 0.17) % 1.0;
      final blobRadius = radius * (0.12 + (i % 5) * 0.04);
      final x = width * ((i * 0.27 + 0.08) % 1.0) +
          sin(animationValue * pi * 4 + i) * radius * 0.15;
      final y = height + blobRadius * 2 - progress * (height + blobRadius * 3);
      final blobColor = lavaColors[i % lavaColors.length];

      if (quality == 'low') {
        canvas.drawCircle(
          Offset(x, y),
          blobRadius,
          Paint()..color = blobColor.withValues(alpha: 0.24),
        );
      } else if (quality == 'balanced') {
        canvas.drawCircle(
          Offset(x, y),
          blobRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                blobColor.withValues(alpha: 0.40),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(x, y), radius: blobRadius * 1.3),
            ),
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          blobRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                blobColor.withValues(alpha: 0.95),
                blobColor.withValues(alpha: 0.5),
                Colors.transparent,
              ],
              stops: const [0.3, 0.7, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset(x, y), radius: blobRadius * 1.5),
            )
            ..maskFilter = _getBlur(8),
        );

        canvas.drawCircle(
          Offset(x - blobRadius * 0.2, y - blobRadius * 0.2),
          blobRadius * 0.3,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..maskFilter = _getBlur(4),
        );
      }
    }

    final waveCount = quality == 'low' ? 2 : (quality == 'balanced' ? 3 : 5);
    final waveStep = quality == 'low' ? 16.0 : (quality == 'balanced' ? 12.0 : 8.0);
    for (var i = 0; i < waveCount; i++) {
      final phase = (animationValue * (1.2 + i * 0.1) + i * 0.2) % 1.0;
      final y = height * (0.50 + i * 0.1);
      final path = Path()..moveTo(0, height);
      for (double x = 0; x <= width; x += waveStep) {
        path.lineTo(
          x,
          y +
              sin((x / width * pi * 2) + phase * pi * 2) *
                  radius *
                  (0.06 + i * 0.02) +
              cos((x / width * pi * 4) - phase * pi) * radius * 0.03,
        );
      }
      path
        ..lineTo(width, height)
        ..close();

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lavaColors[i % lavaColors.length].withValues(alpha: 0.4 + i * 0.1),
            const Color(0xFF3E0000).withValues(alpha: 0.8),
          ],
        ).createShader(Rect.fromLTWH(0, y - 50, width, height - y + 50));
      
      if (quality == 'high') {
        paint.maskFilter = _getBlur(3);
      } else if (quality == 'balanced') {
        paint.maskFilter = _getBlur(1.5);
      }

      canvas.drawPath(path, paint);
    }

    final sparkCount = quality == 'low' ? 8 : (quality == 'balanced' ? 12 : 25);
    for (var i = 0; i < sparkCount; i++) {
      final p = (animationValue * 1.5 + i * 0.04) % 1.0;
      final sx = width * ((i * 0.37) % 1.0) + sin(p * pi * 6 + i) * 20;
      final sy = height - p * height;
      final paint = Paint()
        ..color = lavaColors[i % lavaColors.length].withValues(alpha: (1 - p) * 0.8);
      if (quality == 'high') {
        paint.maskFilter = _getBlur(2);
      }
      canvas.drawCircle(Offset(sx, sy), 1.5 + (i % 3), paint);
    }
  }

  void _drawCherryBlossom(Canvas canvas, double width, double height, Offset center, double radius) {
    // Nền gradient hồng pastel mềm mại
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        colors: [
          const Color(0xFFFFF0F5).withValues(alpha: 0.95),
          const Color(0xFFFFE4EC).withValues(alpha: 0.9),
          const Color(0xFFFFC1D4).withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Lớp glow hồng nhẹ ở tâm
    if (quality != 'low') {
      final glowPaint = Paint()
        ..color = const Color(0xFFFF69B4).withValues(alpha: 0.12)
        ..maskFilter = _getBlur(40);
      canvas.drawCircle(
        Offset(center.dx, center.dy + sin(animationValue * pi * 2) * 10),
        radius * 0.5,
        glowPaint,
      );
    }

    final count = quality == 'low' ? 8 : (quality == 'balanced' ? 16 : 28);
    final petalColors = [
      const Color(0xFFFFB7C5),
      const Color(0xFFF8A4B8),
      const Color(0xFFFFCDD2),
      const Color(0xFFFF8FAB),
      const Color(0xFFFFE0E6),
    ];
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final startX = width * ((i * 0.19 + 0.05) % 1.0);
      final speed = 0.15 + (i * 0.07 % 0.35);
      final size = 5.0 + (i * 3.7 % 10);

      final progress = (animationValue * speed + (i * 0.11)) % 1.0;
      final swayAmount = 25.0 + (i % 4) * 8;
      final y = -size * 2 + progress * (height + size * 4) + tiltY * (0.3 + i * 0.08);
      final x = startX + sin((animationValue * pi * 2.5) + i * 1.3) * swayAmount
          + cos((animationValue * pi * 1.7) + i * 0.7) * swayAmount * 0.4
          + tiltX * (0.3 + i * 0.08);
      final opacity = sin(progress * pi) * (0.6 + (i % 3) * 0.15);

      final colorIdx = i % petalColors.length;
      paint.color = petalColors[colorIdx].withValues(alpha: opacity.clamp(0.0, 1.0));

      if (quality == 'high' && size > 7) {
        paint.maskFilter = _getBlur(size * 0.12);
      }

      canvas.save();
      canvas.translate(x, y);
      final rotSpeed = (i % 2 == 0 ? 1.0 : -1.0) * (0.6 + (i % 5) * 0.15);
      canvas.rotate(animationValue * pi * rotSpeed + i * 0.5);

      // 5 cánh hoa anh đào
      final petalCount = 5;
      for (var p = 0; p < petalCount; p++) {
        canvas.save();
        canvas.rotate(p * 2 * pi / petalCount);
        final petal = Path();
        petal.moveTo(0, 0);
        petal.quadraticBezierTo(size * 0.5, -size * 0.6, 0, -size);
        petal.quadraticBezierTo(-size * 0.5, -size * 0.6, 0, 0);
        canvas.drawPath(petal, paint);
        canvas.restore();
      }
      // Nhụy hoa nhỏ ở giữa
      canvas.drawCircle(Offset.zero, size * 0.15,
        Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: opacity * 0.9));
      canvas.restore();
    }
  }

  void _drawMeteorShower(Canvas canvas, double width, double height, Offset center, double radius) {
    // Nền trời đêm gradient sâu
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, -0.5),
        colors: [
          const Color(0xFF1A1A3E).withValues(alpha: 0.98),
          const Color(0xFF0D0D2B).withValues(alpha: 0.98),
          const Color(0xFF050510).withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Dải ngân hà mờ
    if (quality != 'low') {
      final milkyPaint = Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.06)
        ..maskFilter = _getBlur(50);
      final milkyPath = Path();
      milkyPath.moveTo(0, height * 0.2);
      milkyPath.quadraticBezierTo(width * 0.3, height * 0.4, width * 0.6, height * 0.15);
      milkyPath.quadraticBezierTo(width * 0.8, height * 0.05, width, height * 0.3);
      milkyPath.lineTo(width, height * 0.4);
      milkyPath.quadraticBezierTo(width * 0.7, height * 0.15, width * 0.4, height * 0.35);
      milkyPath.quadraticBezierTo(width * 0.15, height * 0.5, 0, height * 0.35);
      milkyPath.close();
      canvas.drawPath(milkyPath, milkyPaint);
    }

    // Sao nhấp nháy nhiều lớp
    final starCount = quality == 'low' ? 15 : (quality == 'balanced' ? 30 : 55);
    final starPaint = Paint();
    for (var i = 0; i < starCount; i++) {
      final x = width * ((i * 0.137 + 0.03) % 1.0);
      final y = height * ((i * 0.193 + 0.02) % 1.0);
      final twinkleSpeed = 3.0 + (i % 5) * 1.5;
      final twinkle = (sin(animationValue * pi * twinkleSpeed + i * 1.7) + 1) * 0.5;
      final starSize = 0.5 + (i % 4) * 0.5;
      final starColor = i % 7 == 0
          ? const Color(0xFFBBDEFB)
          : (i % 5 == 0 ? const Color(0xFFFFCDD2) : Colors.white);
      starPaint.color = starColor.withValues(alpha: (0.2 + 0.8 * twinkle).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), starSize, starPaint);

      // Tia sáng cho sao lớn
      if (quality != 'low' && starSize > 1.2 && twinkle > 0.7) {
        starPaint.color = starColor.withValues(alpha: twinkle * 0.3);
        canvas.drawLine(Offset(x - starSize * 2, y), Offset(x + starSize * 2, y), starPaint..strokeWidth = 0.5);
        canvas.drawLine(Offset(x, y - starSize * 2), Offset(x, y + starSize * 2), starPaint);
        starPaint.strokeWidth = 0.0;
      }
    }

    // Sao băng với đuôi dài gradient và glow
    final meteorCount = quality == 'low' ? 2 : (quality == 'balanced' ? 3 : 5);
    for (var i = 0; i < meteorCount; i++) {
      final speed = 0.8 + (i * 0.35);
      final progress = (animationValue * speed + (i * 0.25)) % 1.0;
      if (progress > 0.7) continue;

      final tailLength = 50.0 + (i * 15);
      final angle = -pi / 4 - (i * 0.15);
      final originX = width * (0.2 + (i * 0.18) % 0.7);
      final originY = -20.0;

      final headX = originX + progress * width * 0.8 * cos(angle + pi / 2);
      final headY = originY + progress * height * 1.3;
      final tailX = headX - tailLength * cos(angle + pi / 4);
      final tailY = headY - tailLength * sin(angle + pi / 4).abs();

      // Glow quanh đầu sao băng
      if (quality != 'low') {
        canvas.drawCircle(
          Offset(headX, headY),
          4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..maskFilter = _getBlur(6),
        );
      }

      // Đuôi gradient
      final meteorPaint = Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFFBBDEFB).withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 1.0],
        ).createShader(Rect.fromPoints(Offset(headX, headY), Offset(tailX, tailY)));
      canvas.drawLine(Offset(headX, headY), Offset(tailX, tailY), meteorPaint);

      // Đầu sao băng sáng
      canvas.drawCircle(Offset(headX, headY), 2.0, Paint()..color = Colors.white);
    }
  }

  void _drawDeepOcean(Canvas canvas, double width, double height, Offset center, double radius) {
    // Nền gradient đại dương xanh sâu
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.5),
        colors: [
          const Color(0xFF0077B6).withValues(alpha: 0.8),
          const Color(0xFF023E8A).withValues(alpha: 0.85),
          const Color(0xFF03045E).withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Ánh sáng caustic từ trên mặt nước chiếu xuống
    if (quality != 'low') {
      for (var i = 0; i < 4; i++) {
        final cx = center.dx + sin(animationValue * pi * 2 + i * 1.5) * radius * 0.3;
        final cy = center.dy - radius * 0.4 + cos(animationValue * pi * 1.5 + i) * 15;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: radius * 0.5, height: radius * 0.15),
          Paint()
            ..color = const Color(0xFF90E0EF).withValues(alpha: 0.08 + sin(animationValue * pi * 3 + i) * 0.04)
            ..maskFilter = _getBlur(25),
        );
      }
    }

    // Bọt khí nổi lên với ánh sáng phản chiếu
    final count = quality == 'low' ? 10 : (quality == 'balanced' ? 18 : 30);
    for (var i = 0; i < count; i++) {
      final startX = width * ((i * 0.23 + 0.05) % 1.0);
      final speed = 0.12 + (i * 0.08 % 0.3);
      final size = 2.0 + (i * 4.3 % 12);

      final progress = (animationValue * speed + (i * 0.17)) % 1.0;
      final wobble = sin((animationValue * pi * 4) + i * 2.3) * (8 + size * 0.5);
      final y = height + size - progress * (height + size * 3) + tiltY * (0.2 + i * 0.06);
      final x = startX + wobble + tiltX * (0.2 + i * 0.06);
      final opacity = sin(progress * pi);

      // Bọt khí chính — viền tròn bán trong suốt
      canvas.drawCircle(
        Offset(x, y),
        size,
        Paint()
          ..color = const Color(0xFFCAF0F8).withValues(alpha: 0.25 * opacity)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, y),
        size,
        Paint()
          ..color = const Color(0xFF90E0EF).withValues(alpha: 0.4 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Ánh sáng phản chiếu trên bọt khí
      if (size > 4) {
        canvas.drawCircle(
          Offset(x - size * 0.25, y - size * 0.3),
          size * 0.2,
          Paint()..color = Colors.white.withValues(alpha: 0.5 * opacity),
        );
      }
    }

    // Rong biển nhẹ lay ở dưới
    if (quality != 'low') {
      final seaweedPaint = Paint()
        ..color = const Color(0xFF2D6A4F).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final baseX = width * (0.1 + i * 0.2);
        final baseY = height * 0.95;
        final sway = sin(animationValue * pi * 2 + i * 1.2) * 12;
        final path = Path();
        path.moveTo(baseX, baseY);
        path.quadraticBezierTo(
          baseX + sway, baseY - height * 0.12,
          baseX + sway * 0.6, baseY - height * 0.22,
        );
        canvas.drawPath(path, seaweedPaint);
      }
    }
  }

  void _drawGoldenSunset(Canvas canvas, double width, double height, Offset center, double radius) {
    // Nền gradient hoàng hôn nhiều lớp
    final sunBob = sin(animationValue * pi * 1.5);
    final sunCenter = Offset(center.dx, center.dy + sunBob * 8);

    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, -0.2 + sunBob * 0.05),
        colors: [
          const Color(0xFFFFF8E1).withValues(alpha: 0.95),
          const Color(0xFFFFCC80).withValues(alpha: 0.85),
          const Color(0xFFFF8A65).withValues(alpha: 0.7),
          const Color(0xFFE65100).withValues(alpha: 0.5),
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Mặt trời rực rỡ với nhiều lớp glow
    final sunRadius = radius * 0.18;
    if (quality != 'low') {
      // Outer glow
      canvas.drawCircle(
        sunCenter,
        sunRadius * 3,
        Paint()
          ..color = const Color(0xFFFFB74D).withValues(alpha: 0.12)
          ..maskFilter = _getBlur(30),
      );
      // Mid glow
      canvas.drawCircle(
        sunCenter,
        sunRadius * 1.8,
        Paint()
          ..color = const Color(0xFFFFCC02).withValues(alpha: 0.2)
          ..maskFilter = _getBlur(15),
      );
    }
    // Sun core
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF9C4),
            const Color(0xFFFFD54F),
            const Color(0xFFFF9800),
          ],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius)),
    );

    // Tia nắng mặt trời xoay chậm
    if (quality != 'low') {
      final rayCount = quality == 'balanced' ? 8 : 14;
      final rayPaint = Paint()..strokeCap = StrokeCap.round;
      for (var i = 0; i < rayCount; i++) {
        final angle = (i * 2 * pi / rayCount) + animationValue * pi * 0.3;
        final rayLen = sunRadius * 1.5 + sin(animationValue * pi * 4 + i * 2) * sunRadius * 0.5;
        final startR = sunRadius * 1.1;
        final sx = sunCenter.dx + cos(angle) * startR;
        final sy = sunCenter.dy + sin(angle) * startR;
        final ex = sunCenter.dx + cos(angle) * (startR + rayLen);
        final ey = sunCenter.dy + sin(angle) * (startR + rayLen);
        rayPaint
          ..strokeWidth = 1.5
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFFFD54F).withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ).createShader(Rect.fromPoints(Offset(sx, sy), Offset(ex, ey)));
        canvas.drawLine(Offset(sx, sy), Offset(ex, ey), rayPaint);
      }
    }

    // Hạt bụi vàng lấp lánh bay
    final dustCount = quality == 'low' ? 12 : (quality == 'balanced' ? 25 : 40);
    final dustColors = [
      const Color(0xFFFFCC80),
      const Color(0xFFFFE082),
      const Color(0xFFFFD54F),
      const Color(0xFFFFF9C4),
    ];
    final dustPaint = Paint();
    for (var i = 0; i < dustCount; i++) {
      final x = width * ((i * 0.31 + 0.02) % 1.0);
      final y = height * ((i * 0.43 + 0.05) % 1.0);
      final progress = (animationValue * 0.3 + i * 0.07) % 1.0;
      final moveX = x + sin(progress * pi * 3 + i * 0.7) * 25;
      final moveY = y + cos(progress * pi * 2 + i * 1.1) * 18;
      final opacity = sin(progress * pi) * (0.4 + (i % 3) * 0.15);
      final dotSize = 1.0 + (i % 4) * 0.8;
      dustPaint.color = dustColors[i % dustColors.length].withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(moveX, moveY), dotSize, dustPaint);
    }
  }

  void _drawNeonPulse(Canvas canvas, double width, double height, Offset center, double radius) {
    // Nền đen sâu
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF030308).withValues(alpha: 0.92));

    final pulse = sin(animationValue * pi * 6);
    final pulse2 = sin(animationValue * pi * 4 + pi / 3);

    // Multi-color neon rings
    final neonColors = [
      const Color(0xFFFF003C), // Đỏ neon
      const Color(0xFF00F0FF), // Cyan neon
      const Color(0xFFBF00FF), // Tím neon
      const Color(0xFF39FF14), // Xanh lá neon
    ];

    // Vòng neon nhịp đập
    for (int c = 0; c < neonColors.length; c++) {
      final ringPulse = sin(animationValue * pi * 6 + c * pi / 2);
      final ringRadius = radius * (0.25 + c * 0.12) + ringPulse * radius * 0.06;
      final ringPaint = Paint()
        ..color = neonColors[c].withValues(alpha: 0.35 + ringPulse * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + ringPulse;
      if (quality != 'low') {
        ringPaint.maskFilter = _getBlur(8 + ringPulse * 4);
      }
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // Tia sáng xoay xung quanh tâm
    final rayCount = quality == 'low' ? 8 : (quality == 'balanced' ? 16 : 24);
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * pi / rayCount) + animationValue * pi * 1.5;
      final colorIdx = i % neonColors.length;
      final rayPulse = sin(animationValue * pi * 8 + i * 0.5);
      final innerR = radius * 0.15;
      final outerR = innerR + (12 + rayPulse * 15).clamp(0.0, 30.0);
      final rayPaint = Paint()
        ..strokeWidth = 1.5 + rayPulse * 0.5
        ..strokeCap = StrokeCap.round
        ..color = neonColors[colorIdx].withValues(alpha: (0.3 + rayPulse * 0.3).clamp(0.0, 1.0));
      if (quality == 'high') {
        rayPaint.maskFilter = _getBlur(3 + rayPulse * 2);
      }
      canvas.drawLine(
        Offset(center.dx + cos(angle) * innerR, center.dy + sin(angle) * innerR),
        Offset(center.dx + cos(angle) * outerR, center.dy + sin(angle) * outerR),
        rayPaint,
      );
    }

    // Hạt neon bay lơ lửng
    final particleCount = quality == 'low' ? 6 : (quality == 'balanced' ? 12 : 20);
    for (var i = 0; i < particleCount; i++) {
      final angle = animationValue * pi * (0.5 + i * 0.15) + i * 2 * pi / particleCount;
      final dist = radius * (0.3 + (i % 4) * 0.1) + sin(animationValue * pi * 3 + i) * 10;
      final px = center.dx + cos(angle) * dist;
      final py = center.dy + sin(angle) * dist;
      final pSize = 1.5 + (i % 3);
      final pColor = neonColors[i % neonColors.length];
      final pOpacity = (0.4 + sin(animationValue * pi * 5 + i * 1.3) * 0.4).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(px, py),
        pSize,
        Paint()..color = pColor.withValues(alpha: pOpacity),
      );
      if (quality != 'low' && pSize > 2) {
        canvas.drawCircle(
          Offset(px, py),
          pSize * 2,
          Paint()
            ..color = pColor.withValues(alpha: pOpacity * 0.2)
            ..maskFilter = _getBlur(5),
        );
      }
    }

    // Pulse glow ở giữa
    if (quality != 'low') {
      canvas.drawCircle(
        center,
        radius * 0.12 + pulse2 * 5,
        Paint()
          ..color = const Color(0xFFFF003C).withValues(alpha: 0.15 + pulse * 0.1)
          ..maskFilter = _getBlur(15 + pulse * 8),
      );
    }
  }

  void _drawTapEffects(Canvas canvas, Offset center, double radius) {
    if (tapEffects.isEmpty) return;
    final now = DateTime.now();

    for (final effect in tapEffects) {
      final rawProgress = effect.getProgress(now);
      if (rawProgress >= 1.0) continue;

      // Easing curve (easeOutCubic) to make explosion pop fast then slow down
      final progress = 1.0 - pow(1.0 - rawProgress, 3);
      final origin = Offset(center.dx + effect.centerOffset.dx, center.dy + effect.centerOffset.dy);
      final rng = Random(effect.seed);
      final fadeOpacity = (1.0 - rawProgress);

      if (styleKey == 'fireworks' || styleKey == 'meteor_shower' || styleKey == 'galaxy') {
        // --- Starburst / Fireworks ---
        final particleCount = quality == 'low' ? 8 : (quality == 'balanced' ? 14 : 20);
        final paint = Paint()
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus;
          
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 40.0 + rng.nextDouble() * 100.0;
          final pDist = progress * speed;
          
          final px = origin.dx + cos(angle) * pDist;
          final py = origin.dy + sin(angle) * pDist + (progress * progress * 20.0); // Slight gravity
          
          final trailLength = (speed * 0.15 * fadeOpacity).clamp(2.0, 15.0);
          final size = 1.5 + rng.nextDouble() * 2.5;
          
          paint.color = (rng.nextBool() ? const Color(0xFFFFD54F) : const Color(0xFF00F5FF))
              .withValues(alpha: fadeOpacity * (0.6 + rng.nextDouble() * 0.4));
          paint.strokeWidth = size * fadeOpacity;
          
          canvas.drawLine(
            Offset(px - cos(angle) * trailLength, py - sin(angle) * trailLength),
            Offset(px, py),
            paint,
          );
        }
      } else if (styleKey == 'candy' || styleKey == 'hyper') {
        // --- Confetti ---
        final colors = [const Color(0xFFFF6FB7), const Color(0xFF53D8FF), const Color(0xFFFFD54F), const Color(0xFFB388FF), const Color(0xFF69F0AE)];
        final particleCount = quality == 'low' ? 6 : (quality == 'balanced' ? 10 : 15);
        final paint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 30.0 + rng.nextDouble() * 60.0;
          final pDist = progress * speed;
          final gravity = progress * progress * 50.0; 
          
          final px = origin.dx + cos(angle) * pDist;
          final py = origin.dy + sin(angle) * pDist + gravity;
          
          final size = 3.0 + rng.nextDouble() * 5.0;
          paint.color = colors[rng.nextInt(colors.length)].withValues(alpha: fadeOpacity);
          canvas.drawCircle(Offset(px, py), size * fadeOpacity, paint);
        }
      } else if (styleKey == 'cherry_blossom') {
        // --- Petal Burst ---
        final colors = [const Color(0xFFFFB7C5), const Color(0xFFF8A4B8), const Color(0xFFFFCDD2), const Color(0xFFFFF0F5)];
        final particleCount = quality == 'low' ? 4 : (quality == 'balanced' ? 6 : 9);
        final paint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 30.0 + rng.nextDouble() * 50.0;
          final pDist = progress * speed;
          
          final drift = sin(progress * pi * 3 + i) * 15.0; // Swaying motion
          final px = origin.dx + cos(angle) * pDist + drift;
          final py = origin.dy + sin(angle) * pDist + progress * 25.0;
          
          final size = 4.0 + rng.nextDouble() * 4.0;
          paint.color = colors[rng.nextInt(colors.length)].withValues(alpha: fadeOpacity);
          
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(progress * pi * 5 * (rng.nextBool() ? 1 : -1) + angle);
          final petal = Path();
          petal.moveTo(0, 0);
          petal.quadraticBezierTo(size * 0.5, -size * 0.6, 0, -size);
          petal.quadraticBezierTo(-size * 0.5, -size * 0.6, 0, 0);
          canvas.drawPath(petal, paint);
          canvas.restore();
        }
      } else if (styleKey == 'floating_hearts' || styleKey == 'glow') {
        // --- Heart / Glow Burst ---
        final particleCount = quality == 'low' ? 4 : (quality == 'balanced' ? 6 : 10);
        final paint = Paint()..style = PaintingStyle.fill;
        if (styleKey == 'glow') {
          paint.blendMode = BlendMode.plus;
        }
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 20.0 + rng.nextDouble() * 40.0;
          final pDist = progress * speed;
          
          final px = origin.dx + cos(angle) * pDist;
          final py = origin.dy + sin(angle) * pDist - progress * 30.0; // Float up
          
          final size = 3.0 + rng.nextDouble() * 6.0;
          paint.color = const Color(0xFFFF4F93).withValues(alpha: fadeOpacity * 0.85);
          
          final path = Path();
          path.moveTo(px, py + size / 4);
          path.cubicTo(px - size, py - size * 0.7, px - size * 0.5, py - size, px, py - size / 4);
          path.cubicTo(px + size * 0.5, py - size, px + size, py - size * 0.7, px, py + size / 4);
          canvas.drawPath(path, paint);
        }
      } else if (styleKey == 'lava') {
        // --- Lava Bubbles ---
        final colors = [const Color(0xFFFF1744), const Color(0xFFFF9100), const Color(0xFFFFEA00)];
        final particleCount = quality == 'low' ? 4 : (quality == 'balanced' ? 6 : 10);
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.screen;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 15.0 + rng.nextDouble() * 35.0;
          final pDist = progress * speed;
          
          final px = origin.dx + cos(angle) * pDist;
          final py = origin.dy + sin(angle) * pDist - progress * 15.0;
          
          final size = 4.0 + rng.nextDouble() * 7.0;
          paint.color = colors[rng.nextInt(colors.length)].withValues(alpha: fadeOpacity);
          canvas.drawCircle(Offset(px, py), size * fadeOpacity, paint);
        }
      } else if (styleKey == 'neon' || styleKey == 'neon_pulse' || styleKey == 'aurora') {
        // --- Neon Pulse ---
        final ringColor = styleKey == 'aurora' ? const Color(0xFF00FFEA) : const Color(0xFFFF003C);
        final paint = Paint()
          ..color = ringColor.withValues(alpha: fadeOpacity * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * fadeOpacity
          ..blendMode = BlendMode.plus;
          
        canvas.drawCircle(origin, progress * 55.0, paint);
        
        final particleCount = quality == 'low' ? 4 : 8;
        for (int i = 0; i < particleCount; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final px = origin.dx + cos(angle) * progress * 65.0;
          final py = origin.dy + sin(angle) * progress * 65.0;
          canvas.drawCircle(
            Offset(px, py), 
            2.5 * fadeOpacity, 
            Paint()..color = Colors.white.withValues(alpha: fadeOpacity)..blendMode = BlendMode.plus
          );
        }
      } else {
        // --- Default Ripple (Plain/Glass/Deep Ocean/Golden Sunset) ---
        final maxR = radius * 0.6;
        final currentRadius = maxR * progress;
        final baseColor = (styleKey == 'deep_ocean') ? const Color(0xFF90E0EF) :
                          (styleKey == 'golden_sunset') ? const Color(0xFFFFD54F) : const Color(0xFFFFEBF2);

        final ripplePaint = Paint()
          ..color = baseColor.withValues(alpha: fadeOpacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + fadeOpacity * 3.0;

        canvas.drawCircle(origin, currentRadius, ripplePaint);

        if (progress > 0.2) {
          final progress2 = (progress - 0.2) / 0.8;
          final opacity2 = (1.0 - rawProgress) * 0.4;
          final ripplePaint2 = Paint()
            ..color = baseColor.withValues(alpha: opacity2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0 + fadeOpacity * 2.0;

          canvas.drawCircle(origin, maxR * 0.75 * progress2, ripplePaint2);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.styleKey != styleKey ||
        oldDelegate.quality != quality ||
        oldDelegate.shakeIntensity != shakeIntensity ||
        oldDelegate.tapEffects.length != tapEffects.length;
  }
}

class _TapInteractionEffect {
  final Offset centerOffset;
  final DateTime startTime;
  final Duration duration;
  final int seed;

  _TapInteractionEffect({
    required this.centerOffset,
    required this.startTime,
    required this.duration,
  }) : seed = startTime.microsecondsSinceEpoch;

  double getProgress(DateTime now) {
    final elapsed = now.difference(startTime).inMilliseconds;
    return (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}
