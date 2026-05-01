part of '../../soul_rhythm_game.dart';

class _SoulPlayfieldGeometry {
  const _SoulPlayfieldGeometry({
    required this.laneCount,
    required this.playArea,
    required this.hitLineY,
    required this.laneWidth,
    required this.laneXs,
    required this.judgeLineRect,
    required this.hitWindowRect,
  });

  final int laneCount;
  final Rect playArea;
  final double hitLineY;
  final double laneWidth;
  final List<double> laneXs;
  final Rect judgeLineRect;
  final Rect hitWindowRect;
}

extension _SoulRhythmPlayfield on _SoulRhythmGameState {
  _SoulPlayfieldGeometry _buildPlayfieldGeometry(
      Rect playArea, double hitLineY) {
    final laneCount = _laneCountForWidth(playArea.width);
    final laneWidth =
        (playArea.width - (_SoulRhythmGameState._laneGap * (laneCount - 1))) /
            laneCount;
    final laneXs = List<double>.generate(
      laneCount,
      (index) => index * (laneWidth + _SoulRhythmGameState._laneGap),
      growable: false,
    );
    return _SoulPlayfieldGeometry(
      laneCount: laneCount,
      playArea: playArea,
      hitLineY: hitLineY,
      laneWidth: laneWidth,
      laneXs: laneXs,
      judgeLineRect: Rect.fromLTWH(8, hitLineY - 4, playArea.width - 16, 8),
      hitWindowRect: Rect.fromLTWH(0, hitLineY - 36, playArea.width, 72),
    );
  }

  Widget _buildPlayfieldLayers({
    required double bgPulse,
    required double hitLineBlur,
    required double tileGlowBlur,
    required double tileGlowSpread,
    required double tileShineBlur,
    required _SoulPlayfieldGeometry geometry,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          RepaintBoundary(
            child: _buildStaticPlayfieldLayer(
              bgPulse: bgPulse,
              laneCount: geometry.laneCount,
            ),
          ),
          RepaintBoundary(
            child: _buildTileLayer(
              glowBlur: tileGlowBlur,
              glowSpread: tileGlowSpread,
              shineBlur: tileShineBlur,
            ),
          ),
          RepaintBoundary(
            child: _buildBeatVisualizerLayer(
              bgPulse: bgPulse,
              geometry: geometry,
            ),
          ),
          RepaintBoundary(
            child: _buildJudgeAndEffectsLayer(
              bgPulse: bgPulse,
              hitLineBlur: hitLineBlur,
              geometry: geometry,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticPlayfieldLayer({
    required double bgPulse,
    required int laneCount,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF150A20).withOpacity(0.98),
                  const Color(0xFF231138).withOpacity(0.96),
                  const Color(0xFF081B31).withOpacity(0.94),
                  const Color(0xFF030813).withOpacity(0.98),
                ],
                stops: const [0.0, 0.26, 0.68, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.09),
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.012),
                    Colors.transparent,
                    Colors.black.withOpacity(0.12),
                  ],
                  stops: const [0.0, 0.38, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: -54,
          right: -54,
          top: -42,
          height: 168,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFC94D)
                        .withOpacity(_isLowGraphics ? 0.08 : 0.16),
                    const Color(0xFFFF6EC7)
                        .withOpacity(_isLowGraphics ? 0.05 : 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                  center: Alignment.topCenter,
                  radius: 0.95,
                ),
              ),
            ),
          ),
        ),
        if (!_isLowGraphics)
          Positioned(
            left: 24,
            right: 24,
            top: 24,
            height: 84,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05 + (bgPulse * 0.06)),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6FE8FF)
                          .withOpacity(0.05 + (bgPulse * 0.08)),
                      blurRadius: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SoulRhythmStagePainter(
                bgPulse: bgPulse,
                lowGraphics: _isLowGraphics,
                highGraphics: _isHighGraphics,
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          height: 128,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E5FF)
                        .withOpacity(0.05 + (bgPulse * 0.08)),
                    const Color(0xFFFF3D81)
                        .withOpacity(0.025 + (bgPulse * 0.04)),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: LanePainter(laneCount: laneCount),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeatVisualizerLayer({
    required double bgPulse,
    required _SoulPlayfieldGeometry geometry,
  }) {
    if (_gameState != 'PLAYING' || _gameChartEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    final loopDuration = max(1, _gameChartLoopDurationMs).toDouble();
    final currentLoopProgress = (_chartElapsedMs % loopDuration) / loopDuration;
    final nextEventDelta = max(0.0, _nextChartEventMs - _chartElapsedMs);
    final beatEnergy = (1.0 - (nextEventDelta / 340).clamp(0.0, 1.0)).toDouble();
    final strongBeat = _chartEventIndex % 4 == 0;
    final pulseOpacity = (0.16 + (beatEnergy * (strongBeat ? 0.34 : 0.24)) +
            (bgPulse * 0.08))
        .clamp(0.0, strongBeat ? 0.56 : 0.44)
        .toDouble();
    final markerCount = min(24, max(8, _gameChartEvents.length));

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: 14,
              right: 14,
              top: 14,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'RHYTHM DRIVE',
                          style: SLTheme.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white70,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(currentLoopProgress * 100).round()}%',
                          style: SLTheme.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF6FE8FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: currentLoopProgress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF6EC7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(markerCount, (index) {
                          final isMajor = index % 4 == 0;
                          final normalized = markerCount <= 1
                              ? 0.0
                              : index / (markerCount - 1);
                          final passed = normalized <= currentLoopProgress;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 90),
                                  height: passed
                                      ? (isMajor ? 16 : 11)
                                      : (isMajor ? 10 : 7),
                                  decoration: BoxDecoration(
                                    color: passed
                                        ? (isMajor
                                            ? const Color(0xFFFFC94D)
                                            : const Color(0xFF6FE8FF))
                                        : Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 98,
              height: 110,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      (strongBeat
                              ? const Color(0xFFFFC94D)
                              : const Color(0xFFFF6EC7))
                          .withOpacity(pulseOpacity),
                      const Color(0xFF6FE8FF).withOpacity(pulseOpacity * 0.76),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.48, 1.0],
                    center: const Alignment(0, 0.78),
                    radius: 1.1,
                  ),
                ),
              ),
            ),
            if (!_isLowGraphics)
              Positioned(
                left: geometry.playArea.width * 0.12,
                right: geometry.playArea.width * 0.12,
                top: 86,
                height: 140,
                child: Opacity(
                  opacity: 0.10 + (beatEnergy * (strongBeat ? 0.20 : 0.12)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: SweepGradient(
                        colors: [
                          const Color(0xFFFF6EC7).withOpacity(0.0),
                          const Color(0xFFFF6EC7).withOpacity(0.36),
                          const Color(0xFF6FE8FF).withOpacity(0.18),
                          const Color(0xFFFFC94D).withOpacity(0.34),
                          const Color(0xFFFF6EC7).withOpacity(0.0),
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

  Widget _buildTileLayer({
    required double glowBlur,
    required double glowSpread,
    required double shineBlur,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (final tile in _tiles)
              if (!tile.isHit)
                Positioned(
                  left: tile.x,
                  top: tile.y,
                  child: Builder(
                    builder: (context) {
                      final borderRadius = BorderRadius.circular(
                        min(24.0, max(16.0, tile.width * 0.24)),
                      );
                      final capHeight = min(22.0, max(14.0, tile.height * 0.16));
                      final coreColor = Color.lerp(
                        tile.color,
                        Colors.black,
                        0.14,
                      )!;
                      final shadowColor = Color.lerp(
                        tile.color,
                        Colors.black,
                        0.36,
                      )!;

                      return Container(
                        width: tile.width,
                        height: tile.height,
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(tile.color, Colors.white, 0.42)!,
                              coreColor,
                              shadowColor,
                            ],
                            stops: const [0.0, 0.22, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.86),
                            width: 1.25,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tile.color.withOpacity(
                                _isLowGraphics ? 0.54 : 0.78,
                              ),
                              blurRadius: glowBlur,
                              spreadRadius: glowSpread,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.30),
                              blurRadius: _isLowGraphics ? 7 : 12,
                              offset: const Offset(0, 10),
                            ),
                            if (!_isLowGraphics)
                              BoxShadow(
                                color: Colors.white.withOpacity(0.16),
                                blurRadius: shineBlur * 0.42,
                                offset: const Offset(-2, -3),
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: borderRadius,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: capHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.98),
                                        Color.lerp(tile.color, Colors.white, 0.40)!,
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.white.withOpacity(0.32),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: tile.width * 0.12,
                                top: capHeight + 7,
                                bottom: 14,
                                width: max(4.0, tile.width * 0.07),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.72),
                                        Colors.white.withOpacity(0.08),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                height: tile.height * 0.24,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.20),
                                        Colors.black.withOpacity(0.42),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                              if (!_isLowGraphics)
                                Positioned(
                                  top: capHeight + 12,
                                  right: 10,
                                  child: Container(
                                    width: min(18.0, max(10.0, tile.width * 0.18)),
                                    height: min(18.0, max(10.0, tile.width * 0.18)),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.28),
                                          blurRadius: shineBlur * 0.65,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.10),
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.10),
                                      ],
                                      stops: const [0.0, 0.42, 1.0],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildJudgeAndEffectsLayer({
    required double bgPulse,
    required double hitLineBlur,
    required _SoulPlayfieldGeometry geometry,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              isComplex: true,
              painter: _SoulEffectsPainter(
                touchBursts: _touchBursts,
                particles: _particles,
              ),
            ),
          ),
        ),
        for (final ft in _floatingTexts)
          Positioned(
            left: ft.x - 50,
            top: ft.y,
            width: 100,
            child: IgnorePointer(
              child: Opacity(
                opacity: max(0, ft.life / ft.maxLife),
                child: Text(
                  ft.text,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: ft.text == 'PERFECT!' ? 20 : 16,
                    fontWeight: FontWeight.w900,
                    color: ft.color,
                    shadows: [
                      Shadow(
                        color: ft.color.withOpacity(0.8),
                        blurRadius: 10,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: geometry.judgeLineRect.left,
          width: geometry.judgeLineRect.width,
          top: geometry.judgeLineRect.top,
          child: RepaintBoundary(
            child: _buildHitLine(bgPulse, hitLineBlur),
          ),
        ),
      ],
    );
  }

  Widget _buildHitLine(double bgPulse, double hitLineBlur) {
    return IgnorePointer(
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              _SoulRhythmGameState._unityCyan.withOpacity(0.16),
              Colors.white.withOpacity(0.92),
              _SoulRhythmGameState._unityCyan.withOpacity(0.82),
              _SoulRhythmGameState._unityPink.withOpacity(0.24),
              Colors.transparent,
            ],
            stops: const [0.0, 0.16, 0.46, 0.72, 0.88, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: _SoulRhythmGameState._unityCyan.withOpacity(
                0.34 + (bgPulse * 0.17),
              ),
              blurRadius: hitLineBlur,
            ),
          ],
          borderRadius: SLRadius.pillAll,
        ),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 34),
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: SLRadius.pillAll,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.55),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoulRhythmStagePainter extends CustomPainter {
  const _SoulRhythmStagePainter({
    required this.bgPulse,
    required this.lowGraphics,
    required this.highGraphics,
  });

  final double bgPulse;
  final bool lowGraphics;
  final bool highGraphics;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.34);
    final glowPaint = Paint()..style = PaintingStyle.fill;

    glowPaint.shader = RadialGradient(
      colors: [
        const Color(0xFFFFC94D).withOpacity(lowGraphics ? 0.06 : 0.16),
        const Color(0xFFFF3D81).withOpacity(lowGraphics ? 0.04 : 0.12),
        Colors.transparent,
      ],
      stops: const [0.0, 0.48, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.72));
    canvas.drawCircle(center, size.width * 0.72, glowPaint);

    if (!lowGraphics) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highGraphics ? 2.2 : 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      for (int i = 0; i < (highGraphics ? 5 : 3); i++) {
        final t = i / (highGraphics ? 5 : 3);
        ringPaint.color = Color.lerp(
          const Color(0xFFFF3D81),
          const Color(0xFF6FE8FF),
          t,
        )!
            .withOpacity(0.12 + (bgPulse * 0.08));
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * (0.30 + (t * 0.13))),
            width: size.width * (0.42 + (t * 0.48)),
            height: size.height * (0.08 + (t * 0.08)),
          ),
          ringPaint,
        );
      }
    }

    final floorTop = size.height * 0.58;
    final floor = Path()
      ..moveTo(size.width * 0.16, floorTop)
      ..lineTo(size.width * 0.84, floorTop)
      ..lineTo(size.width * 1.16, size.height)
      ..lineTo(size.width * -0.16, size.height)
      ..close();
    final floorPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF111C3F).withOpacity(0.70),
          const Color(0xFF06101F).withOpacity(0.94),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, floorTop, size.width, size.height - floorTop));
    canvas.drawPath(floor, floorPaint);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF6FE8FF).withOpacity(lowGraphics ? 0.08 : 0.16);
    for (int i = 0; i <= 8; i++) {
      final t = i / 8;
      final xTop = (size.width * 0.22) + ((size.width * 0.56) * t);
      final xBottom = (size.width * -0.08) + ((size.width * 1.16) * t);
      canvas.drawLine(Offset(xTop, floorTop), Offset(xBottom, size.height), gridPaint);
    }
    for (int i = 0; i < 8; i++) {
      final t = i / 8;
      final y = floorTop + pow(t, 1.9) * (size.height - floorTop);
      canvas.drawLine(
        Offset(size.width * (0.16 - (t * 0.32)), y),
        Offset(size.width * (0.84 + (t * 0.32)), y),
        gridPaint,
      );
    }

    final beamPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, highGraphics ? 12 : 8);
    for (final side in [-1.0, 1.0]) {
      final beam = Path()
        ..moveTo(size.width * (side < 0 ? 0.05 : 0.95), size.height * 0.08)
        ..lineTo(size.width * (0.50 + (side * 0.08)), floorTop)
        ..lineTo(size.width * (0.50 + (side * 0.23)), size.height)
        ..lineTo(size.width * (side < 0 ? -0.05 : 1.05), size.height)
        ..close();
      beamPaint.color = (side < 0 ? const Color(0xFFFF3D81) : const Color(0xFF6FE8FF))
          .withOpacity(lowGraphics ? 0.035 : 0.075 + (bgPulse * 0.05));
      canvas.drawPath(beam, beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoulRhythmStagePainter oldDelegate) {
    return oldDelegate.bgPulse != bgPulse ||
        oldDelegate.lowGraphics != lowGraphics ||
        oldDelegate.highGraphics != highGraphics;
  }
}

class _SoulEffectsPainter extends CustomPainter {
  _SoulEffectsPainter({
    required this.touchBursts,
    required this.particles,
  });

  final List<TouchBurst> touchBursts;
  final List<Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()..style = PaintingStyle.stroke;
    final fillPaint = Paint();

    for (final burst in touchBursts) {
      final opacity = max(0.0, burst.life / burst.maxLife);
      if (opacity <= 0) continue;

      strokePaint
        ..color = burst.color.withOpacity(
          (burst.strong ? 0.9 : 0.55) * opacity,
        )
        ..strokeWidth = burst.strong ? 3 : 2
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          burst.strong ? 10 : 6,
        );
      canvas.drawCircle(Offset(burst.x, burst.y), burst.radius, strokePaint);
    }

    for (final particle in particles) {
      final opacity = max(0.0, particle.life / particle.maxLife);
      if (opacity <= 0) continue;

      fillPaint
        ..color = particle.color.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(particle.x + 3, particle.y + 3), 3, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoulEffectsPainter oldDelegate) {
    return oldDelegate.touchBursts != touchBursts ||
        oldDelegate.particles != particles;
  }
}
