// ignore_for_file: invalid_use_of_protected_member
part of '../soul_block_game.dart';

extension _SoulBlockFeedbackPart on _SoulBlockGameState {
  Future<void> _initAudio() async {
    final errorFallback = context.tr('util_khngthkhit_0ee520');
    try {
      _tapSfxBytes = _buildWaveBytes(<_SoulSfxTone>[
        _tone(57, 18, 0.90, noiseMix: 0.32),
        _tone(64, 28, 0.46, noiseMix: 0.14),
      ], masterGain: 0.54);
      _liftSfxBytes =
          await _loadAudioAssetBytes('assets/audio/soul_block/drag_lift.mp3') ??
          _buildWaveBytes(<_SoulSfxTone>[
            _tone(60, 24, 0.84, noiseMix: 0.22),
            _tone(67, 38, 0.56, noiseMix: 0.08),
            _tone(72, 42, 0.32, noiseMix: 0.04),
          ], masterGain: 0.62);
      _placeSfxBytes =
          await _loadAudioAssetBytes(
            'assets/audio/soul_block/big_win_place_first_half.mp3',
          ) ??
          _buildWaveBytes(<_SoulSfxTone>[
            _tone(50, 26, 0.92, noiseMix: 0.34),
            _tone(57, 46, 0.66, noiseMix: 0.14),
            _tone(62, 32, 0.36, noiseMix: 0.06),
          ], masterGain: 0.68);
      _clearSfxBytes =
          await _loadAudioAssetBytes(
            'assets/audio/soul_block/clear_burst.mp3',
          ) ??
          _buildWaveBytes(<_SoulSfxTone>[
            _tone(62, 24, 0.88, noiseMix: 0.16),
            _tone(69, 30, 0.78, noiseMix: 0.12),
            _tone(76, 54, 0.76, noiseMix: 0.06),
            _tone(83, 84, 0.56, noiseMix: 0.03),
          ], masterGain: 0.70);
      _bombSfxBytes =
          await _loadAudioAssetBytes(
            'assets/audio/soul_block/bomb_explosion.mp3',
          ) ??
          _buildWaveBytes(<_SoulSfxTone>[
            _tone(36, 120, 1.0, noiseMix: 0.94),
            _tone(43, 90, 0.88, noiseMix: 0.86),
            _tone(48, 70, 0.64, noiseMix: 0.72),
          ], masterGain: 0.90);
      _comboSfxLevels = <Uint8List>[
        _buildWaveBytes(<_SoulSfxTone>[
          _tone(64, 24, 0.88, noiseMix: 0.14),
          _tone(71, 28, 0.78, noiseMix: 0.11),
          _tone(78, 44, 0.66, noiseMix: 0.05),
        ], masterGain: 0.70),
        _buildWaveBytes(<_SoulSfxTone>[
          _tone(67, 20, 0.90, noiseMix: 0.12),
          _tone(74, 28, 0.84, noiseMix: 0.10),
          _tone(79, 40, 0.80, noiseMix: 0.06),
          _tone(84, 62, 0.58, noiseMix: 0.03),
        ], masterGain: 0.74),
        _buildWaveBytes(<_SoulSfxTone>[
          _tone(69, 20, 0.90, noiseMix: 0.11),
          _tone(76, 26, 0.86, noiseMix: 0.08),
          _tone(81, 36, 0.82, noiseMix: 0.06),
          _tone(86, 48, 0.72, noiseMix: 0.04),
          _tone(91, 76, 0.60, noiseMix: 0.02),
        ], masterGain: 0.78),
        _buildWaveBytes(<_SoulSfxTone>[
          _tone(71, 18, 0.92, noiseMix: 0.10),
          _tone(78, 24, 0.90, noiseMix: 0.08),
          _tone(83, 32, 0.86, noiseMix: 0.06),
          _tone(88, 44, 0.82, noiseMix: 0.05),
          _tone(91, 54, 0.74, noiseMix: 0.03),
          _tone(95, 90, 0.64, noiseMix: 0.02),
        ], masterGain: 0.82),
      ];
      _streakSfxBytes = _buildWaveBytes(<_SoulSfxTone>[
        _tone(64, 24, 0.84, noiseMix: 0.12),
        _tone(71, 30, 0.78, noiseMix: 0.10),
        _tone(78, 42, 0.70, noiseMix: 0.05),
        _tone(83, 66, 0.58, noiseMix: 0.02),
      ], masterGain: 0.70);
      _bestScoreSfxBytes =
          await _loadAudioAssetBytes('assets/audio/soul_block/big_win.mp3') ??
          _buildWaveBytes(<_SoulSfxTone>[
            _tone(67, 24, 0.86, noiseMix: 0.12),
            _tone(74, 30, 0.84, noiseMix: 0.10),
            _tone(81, 42, 0.80, noiseMix: 0.06),
            _tone(86, 64, 0.76, noiseMix: 0.03),
            _tone(91, 96, 0.64, noiseMix: 0.02),
          ], masterGain: 0.76);
      if (!mounted) return;
      _audioReady = true;
      unawaited(_syncBgmWithSound());
    } catch (error) {
      debugPrint(
        'Soul Block audio init failed: ${AppErrorMapper.resolve(error, fallbackMessage: errorFallback).message}',
      );
      _audioReady = false;
    }
  }

  Future<Source> _getBgmSource() async {
    // Bản nhạc Soul Block gốc được khôi phục từ lịch sử Git và đóng gói để chơi offline.
    const bundledAsset = 'audio/soul_block/soul_block_bgm.mp3';
    debugPrint('Soul Block: Using bundled BGM: $bundledAsset');
    return AssetSource(bundledAsset);
  }

  bool get _canPlayAudio =>
      mounted && _soundEnabled && _appActive && !_isShowingFullscreenAd;

  Future<void> _syncBgmWithSound() {
    // Tuần tự hóa lệnh: trở lại app tiếp tục bản nhạc đang phát.
    _bgmSyncQueue = _bgmSyncQueue.then((_) async {
      if (!mounted || !_audioSettingsLoaded) return;
      try {
        if (!_canPlayAudio) {
          if (_bgmPlayer.state == PlayerState.playing) await _bgmPlayer.pause();
          return;
        }
        if (!_bgmSourceReady) {
          final source = await _getBgmSource();
          if (!mounted) return;
          await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
          if (!mounted) return;
          await _bgmPlayer.setVolume(0.36);
          if (!mounted) return;
          await _bgmPlayer.setSource(source);
          _bgmSourceReady = true;
        }
        if (!mounted) return;
        if (!_canPlayAudio) {
          await _bgmPlayer.pause();
        } else if (_bgmPlayer.state == PlayerState.stopped ||
            _bgmPlayer.state == PlayerState.completed) {
          await _bgmPlayer.play(await _getBgmSource(), volume: 0.36);
        } else if (_bgmPlayer.state != PlayerState.playing) {
          await _bgmPlayer.resume();
        }
      } catch (error) {
        // Web có thể chặn autoplay; thao tác chạm tiếp theo sẽ thử lại.
        debugPrint(AppErrorMapper.resolve(error).message);
      }
    });
    return _bgmSyncQueue;
  }

  _SoulSfxTone _tone(
    int midi,
    int durationMs,
    double volume, {
    double noiseMix = 0,
  }) {
    return _SoulSfxTone(
      frequency: 440.0 * pow(2, (midi - 69) / 12).toDouble(),
      durationMs: durationMs,
      volume: volume,
      noiseMix: noiseMix,
    );
  }

  Uint8List _buildWaveBytes(
    List<_SoulSfxTone> steps, {
    int sampleRate = 22050,
    double masterGain = 0.82,
  }) {
    final int totalSamples = steps.fold<int>(
      0,
      (int sum, _SoulSfxTone step) =>
          sum + max(1, (sampleRate * step.durationMs) ~/ 1000),
    );
    final ByteData byteData = ByteData(44 + (totalSamples * 2));

    void writeAscii(int offset, String value) {
      for (int i = 0; i < value.length; i++) {
        byteData.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    byteData.setUint32(4, 36 + (totalSamples * 2), Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    byteData.setUint32(40, totalSamples * 2, Endian.little);

    int sampleIndex = 0;
    for (final _SoulSfxTone step in steps) {
      final int stepSamples = max(1, (sampleRate * step.durationMs) ~/ 1000);
      final int attackSamples = max(10, stepSamples ~/ 10);
      final int releaseSamples = max(24, stepSamples ~/ 3);
      for (int i = 0; i < stepSamples; i++) {
        double envelope = 1;
        if (i < attackSamples) {
          envelope = i / attackSamples;
        } else if (i > stepSamples - releaseSamples) {
          envelope = (stepSamples - i) / releaseSamples;
        }
        envelope = envelope.clamp(0.0, 1.0);

        final double time = i / sampleRate;
        final double phase = 2 * pi * step.frequency * time;
        final double sine = sin(phase) * 0.22;
        final double square = (sin(phase) > 0 ? 1.0 : -1.0) * 0.13;
        final double triangle =
            (2 / pi) * asin(sin((phase * 0.5) + (pi / 7))) * 0.24;
        final double shimmer = sin((phase * 2.02) + 0.4) * 0.07;
        final double sub = sin(phase * 0.5) * 0.18;
        final double harmonic = (sine + square + triangle + shimmer + sub)
            .clamp(-1.0, 1.0);
        final double transient = pow(
          1 - (i / stepSamples),
          1.8,
        ).toDouble().clamp(0.0, 1.0);
        final double noise =
            (sin(((sampleIndex + 1) * 12.9898) + (step.frequency * 0.014)) *
                    cos(
                      ((sampleIndex + 1) * 78.233) + (step.frequency * 0.021),
                    ))
                .clamp(-1.0, 1.0);
        final double knock =
            ((noise * 0.58) + (sin(phase * 4.2) * 0.12) + (square * 0.14))
                .clamp(-1.0, 1.0);
        final double sampleValue =
            ((harmonic * (1 - step.noiseMix)) +
                    (knock * step.noiseMix * transient) +
                    (harmonic * step.noiseMix * 0.22))
                .clamp(-1.0, 1.0);
        final int pcm =
            (sampleValue * envelope * step.volume * masterGain * 32767)
                .round()
                .clamp(-32767, 32767);
        byteData.setInt16(44 + (sampleIndex * 2), pcm, Endian.little);
        sampleIndex += 1;
      }
    }

    return byteData.buffer.asUint8List();
  }

  Future<Uint8List?> _loadAudioAssetBytes(String assetPath) async {
    if (!mounted) return null;
    final loadSfxErrorFallback = L10nService().translate(
      'util_khngthtihi_635113',
    );
    try {
      if (!kIsWeb) {
        try {
          final localPath = await GameDownloadService().getLocalPath(
            'soul_block',
            p.basename(assetPath),
          );
          final localFile = File(localPath);
          if (await localFile.exists()) return await localFile.readAsBytes();
        } catch (_) {
          // Nếu gói tải về không có, tiếp tục thử asset và âm thanh tạo sẵn.
        }
      }

      debugPrint('Soul Block: Loading SFX from ASSET: $assetPath');
      final ByteData data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      debugPrint(
        'Soul Block: Error loading SFX ($assetPath): ${AppErrorMapper.resolve(e, fallbackMessage: loadSfxErrorFallback).message}',
      );
      return null;
    }
  }

  Future<void> _playSfx(Uint8List? bytes, {double volume = 1}) async {
    if (!_canPlayAudio || !_audioReady || bytes == null || bytes.isEmpty) {
      return;
    }
    final index = _sfxPlayerIndex++ % _sfxPlayers.length;
    final player = _sfxPlayers[index];
    final request = ++_sfxRequests[index];
    final isWave =
        bytes.length >= 12 &&
        bytes[0] == 82 &&
        bytes[1] == 73 &&
        bytes[2] == 70 &&
        bytes[3] == 70 &&
        bytes[8] == 87 &&
        bytes[9] == 65;
    try {
      await player.stop();
      if (!_canPlayAudio || request != _sfxRequests[index]) return;
      await player.play(
        BytesSource(bytes, mimeType: isWave ? 'audio/wav' : 'audio/mpeg'),
        volume: volume.clamp(0.0, 1.0).toDouble(),
      );
    } catch (_) {
      if (_canPlayAudio) unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  void _emitClickFeedback() {
    if (_canPlayAudio && _bgmPlayer.state != PlayerState.playing) {
      unawaited(_syncBgmWithSound());
    }
    if (!_soundEnabled) {
      return;
    }
    if (_audioReady) {
      unawaited(_playSfx(_tapSfxBytes, volume: 0.38));
    } else {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  void _emitLiftFeedback() {
    if (_canPlayAudio && _bgmPlayer.state != PlayerState.playing) {
      unawaited(_syncBgmWithSound());
    }
    if (_soundEnabled) {
      if (_audioReady) {
        unawaited(_playSfx(_liftSfxBytes, volume: 0.52));
      } else {
        unawaited(SystemSound.play(SystemSoundType.click));
      }
    }
    if (_vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _emitPlaceFeedback() {
    if (_soundEnabled) {
      if (_audioReady) {
        unawaited(_playSfx(_placeSfxBytes, volume: 0.50));
      } else {
        unawaited(SystemSound.play(SystemSoundType.click));
      }
    }
    if (_vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  void _emitBombFeedback() {
    if (_soundEnabled) {
      if (_audioReady && _bombSfxBytes != null) {
        unawaited(_playSfx(_bombSfxBytes, volume: 0.90));
      } else {
        unawaited(SystemSound.play(SystemSoundType.alert));
      }
    }
    if (_vibrationEnabled) {
      HapticFeedback.vibrate();
    }
  }

  void _emitClearFeedback({
    required int clearedCount,
    required int streakCount,
  }) {
    if (_soundEnabled) {
      if (_audioReady) {
        Uint8List? selectedBytes = _clearSfxBytes;
        double volume = 0.54;

        if (clearedCount >= 2) {
          final int comboIndex = min(
            max(clearedCount + streakCount - 3, 0),
            _comboSfxLevels.length - 1,
          );
          if (_comboSfxLevels.isNotEmpty) {
            selectedBytes = _comboSfxLevels[comboIndex];
            volume = 0.58 + min(streakCount, 4) * 0.01;
          }
        } else if (streakCount >= 2) {
          selectedBytes = _streakSfxBytes ?? _clearSfxBytes;
          volume = 0.50;
        }

        unawaited(
          _playSfx(selectedBytes, volume: volume.clamp(0.0, 1.0).toDouble()),
        );
      } else {
        unawaited(SystemSound.play(SystemSoundType.alert));
      }
    }
    if (_vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _emitBestScoreFeedback() {
    if (!_soundEnabled) {
      return;
    }
    if (_audioReady) {
      unawaited(_playSfx(_bestScoreSfxBytes, volume: 0.60));
      return;
    }
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  void _showComboBurst(int clearedCount) {
    if (clearedCount <= 0) {
      return;
    }
    final level = min(4, max(2, clearedCount));
    const colors = <Color>[
      Color(0xFF9DE7FF),
      Color(0xFFC3B6F6),
      Color(0xFFE9C9A2),
    ];
    _showFloatingMessage(
      L10nService().format('soul_block_combo', {'level': level}),
      color: colors[min(level - 2, colors.length - 1)],
    );
  }

  void _triggerScreenPulse() {
    if (MediaQuery.disableAnimationsOf(context) || _draggingPiece != null) {
      return;
    }
    _shakeController.forward(from: 0);
    _flashController.forward(from: 0);
  }

  void _showFloatingMessage(String message, {required Color color}) {
    setState(() {
      _floatingText = message;
      _floatingTextColor = color;
    });
    _floatingController.forward(from: 0);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F2937),
      ),
    );
  }

  // ignore: unused_element
  void _triggerExplosionEffect({
    required int clearedCount,
    required List<int> clearedRows,
    required List<int> clearedCols,
    bool subtle = false,
  }) {
    if (clearedCount < 1 || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    if (_boardCellExtent <= 0) {
      _updateBoardMetrics();
    }
    if (_boardCellExtent <= 0) {
      return;
    }

    final List<Offset> anchors = <Offset>[
      for (final int row in clearedRows)
        _boardCellCenter(row.toDouble(), (_boardSize - 1) / 2),
      for (final int col in clearedCols)
        _boardCellCenter((_boardSize - 1) / 2, col.toDouble()),
    ];
    if (anchors.isEmpty) {
      return;
    }

    double sumDx = 0;
    double sumDy = 0;
    for (final Offset anchor in anchors) {
      sumDx += anchor.dx;
      sumDy += anchor.dy;
    }
    final renderBox = _effectsKey.currentContext?.findRenderObject();
    final effectsOrigin = renderBox is RenderBox
        ? renderBox.localToGlobal(Offset.zero)
        : Offset.zero;
    final Offset epicenter =
        Offset(sumDx / anchors.length, sumDy / anchors.length) - effectsOrigin;

    final Color accent =
        _kSoulBurstPalette[_random.nextInt(_kSoulBurstPalette.length)];
    final _SoulBlockPerformanceProfile profile = _performanceProfile;
    const bool simpleParticles = true;
    final int particleCount = subtle
        ? min((4 + clearedCount).clamp(4, 8), profile.subtleParticleCap)
        : min((7 + (clearedCount * 2)).clamp(8, 14), profile.strongParticleCap);
    final double maxDistance = subtle
        ? ((60 + (clearedCount * 12)).clamp(70, 140).toDouble() *
              profile.subtleDistanceScale)
        : ((90 + (clearedCount * 15)).clamp(100, 180).toDouble() *
              profile.strongDistanceScale);
    final List<_ExplosionParticle> particles = <_ExplosionParticle>[];

    for (int index = 0; index < particleCount; index++) {
      // 360 degree explosion
      final double angle = _random.nextDouble() * pi * 2.0;
      // Further distance for more spectacular bursts
      final double distance =
          (15.0 + (_random.nextDouble() * maxDistance * 0.85)).clamp(
            15.0,
            140.0,
          );
      final bool isShard = index.isEven;
      particles.add(
        _ExplosionParticle(
          startOffset: epicenter,
          endOffset: Offset(
            epicenter.dx + (cos(angle) * distance),
            epicenter.dy + (sin(angle) * distance),
          ),
          color: _kSoulBurstPalette[_random.nextInt(_kSoulBurstPalette.length)],
          size: subtle
              ? (isShard
                    ? 3.0 + (_random.nextDouble() * 2.0)
                    : 1.5 + (_random.nextDouble() * 1.5))
              : isShard
              ? 5.0 + (_random.nextDouble() * 3.0)
              : 2.5 + (_random.nextDouble() * 2.0),
          rotation: _random.nextDouble() * pi * 2,
          twist:
              (subtle ? 0.6 : 1.2) *
              _random.nextDouble() *
              (_random.nextBool() ? 1 : -1),
          opacity:
              ((subtle
                          ? 0.35 + (_random.nextDouble() * 0.15)
                          : 0.50 + (_random.nextDouble() * 0.20)) *
                      profile.opacityScale)
                  .clamp(0.18, 0.76),
          delayFraction:
              (_random.nextDouble() * (subtle ? 0.10 : 0.16)) *
              profile.delayScale,
          isShard: isShard,
          simpleDraw: simpleParticles,
          shapeType: _random.nextInt(4),
        ),
      );
    }

    setState(() {
      _explosionCenter = epicenter;
      _explosionAccent = accent;
      _explosionParticles = particles;
    });

    _explosionController.forward(from: 0);
  }

  void _triggerMemoryBurstReward({
    required int clearedCount,
    required int streakCount,
  }) {
    final image = _boardPhoto;
    if (image == null || MediaQuery.disableAnimationsOf(context)) return;
    setState(() {
      _memoryBurstSnapshot = _MemoryBurstSnapshot(
        image: image,
        label: context.tr('soul_block_photo_ready'),
        subtitle: '×${max(clearedCount, streakCount)}',
        accent: const Color(0xFFCCDCF5),
      );
    });
    _memoryBurstController.forward(from: 0);
  }

  String _formatNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      final reverseIndex = raw.length - index;
      buffer.write(raw[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  double get _playPulseScale =>
      1 + (Curves.easeInOut.transform(_playPulseController.value) * 0.045);

  double get _boardShakeX {
    final progress = _shakeController.value;
    if (MediaQuery.disableAnimationsOf(context)) return 0;
    final amplitude = _smoothGraphics ? 2.2 : 4.8;
    return sin(progress * pi * 6) * amplitude * (1 - progress);
  }

  double get _boardShakeY {
    final progress = _shakeController.value;
    if (MediaQuery.disableAnimationsOf(context)) return 0;
    final amplitude = _smoothGraphics ? .8 : 1.8;
    return sin(progress * pi * 8) * amplitude * (1 - progress);
  }

  double get _backgroundFlashOpacity =>
      _flashController.isAnimating && !MediaQuery.disableAnimationsOf(context)
      ? sin(_flashController.value * pi) * (_smoothGraphics ? .018 : .035)
      : 0;
}
