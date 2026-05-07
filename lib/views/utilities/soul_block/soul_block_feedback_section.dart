part of '../soul_block_game.dart';
// ignore_for_file: invalid_use_of_protected_member

extension _SoulBlockFeedbackPart on _SoulBlockGameState {
  Future<void> _initAudio() async {
    try {
      _tapSfxBytes = _buildWaveBytes(
        <_SoulSfxTone>[
          _tone(57, 18, 0.90, noiseMix: 0.32),
          _tone(64, 28, 0.46, noiseMix: 0.14),
        ],
        masterGain: 0.54,
      );
      _liftSfxBytes = await _loadAudioAssetBytes(
            'assets/audio/soul_block/drag_lift.mp3',
          ) ??
          _buildWaveBytes(
            <_SoulSfxTone>[
              _tone(60, 24, 0.84, noiseMix: 0.22),
              _tone(67, 38, 0.56, noiseMix: 0.08),
              _tone(72, 42, 0.32, noiseMix: 0.04),
            ],
            masterGain: 0.62,
          );
      _placeSfxBytes = await _loadAudioAssetBytes(
            'assets/audio/soul_block/big_win_place_first_half.mp3',
          ) ??
          _buildWaveBytes(
            <_SoulSfxTone>[
              _tone(50, 26, 0.92, noiseMix: 0.34),
              _tone(57, 46, 0.66, noiseMix: 0.14),
              _tone(62, 32, 0.36, noiseMix: 0.06),
            ],
            masterGain: 0.68,
          );
      _clearSfxBytes = await _loadAudioAssetBytes(
            'assets/audio/soul_block/clear_burst.mp3',
          ) ??
          _buildWaveBytes(
            <_SoulSfxTone>[
              _tone(62, 24, 0.88, noiseMix: 0.16),
              _tone(69, 30, 0.78, noiseMix: 0.12),
              _tone(76, 54, 0.76, noiseMix: 0.06),
              _tone(83, 84, 0.56, noiseMix: 0.03),
            ],
            masterGain: 0.70,
          );
      _comboSfxLevels = <Uint8List>[
        _buildWaveBytes(
          <_SoulSfxTone>[
            _tone(64, 24, 0.88, noiseMix: 0.14),
            _tone(71, 28, 0.78, noiseMix: 0.11),
            _tone(78, 44, 0.66, noiseMix: 0.05),
          ],
          masterGain: 0.70,
        ),
        _buildWaveBytes(
          <_SoulSfxTone>[
            _tone(67, 20, 0.90, noiseMix: 0.12),
            _tone(74, 28, 0.84, noiseMix: 0.10),
            _tone(79, 40, 0.80, noiseMix: 0.06),
            _tone(84, 62, 0.58, noiseMix: 0.03),
          ],
          masterGain: 0.74,
        ),
        _buildWaveBytes(
          <_SoulSfxTone>[
            _tone(69, 20, 0.90, noiseMix: 0.11),
            _tone(76, 26, 0.86, noiseMix: 0.08),
            _tone(81, 36, 0.82, noiseMix: 0.06),
            _tone(86, 48, 0.72, noiseMix: 0.04),
            _tone(91, 76, 0.60, noiseMix: 0.02),
          ],
          masterGain: 0.78,
        ),
        _buildWaveBytes(
          <_SoulSfxTone>[
            _tone(71, 18, 0.92, noiseMix: 0.10),
            _tone(78, 24, 0.90, noiseMix: 0.08),
            _tone(83, 32, 0.86, noiseMix: 0.06),
            _tone(88, 44, 0.82, noiseMix: 0.05),
            _tone(91, 54, 0.74, noiseMix: 0.03),
            _tone(95, 90, 0.64, noiseMix: 0.02),
          ],
          masterGain: 0.82,
        ),
      ];
      _streakSfxBytes = _buildWaveBytes(
        <_SoulSfxTone>[
          _tone(64, 24, 0.84, noiseMix: 0.12),
          _tone(71, 30, 0.78, noiseMix: 0.10),
          _tone(78, 42, 0.70, noiseMix: 0.05),
          _tone(83, 66, 0.58, noiseMix: 0.02),
        ],
        masterGain: 0.70,
      );
      _bestScoreSfxBytes = await _loadAudioAssetBytes(
            'assets/audio/soul_block/big_win.mp3',
          ) ??
          _buildWaveBytes(
            <_SoulSfxTone>[
              _tone(67, 24, 0.86, noiseMix: 0.12),
              _tone(74, 30, 0.84, noiseMix: 0.10),
              _tone(81, 42, 0.80, noiseMix: 0.06),
              _tone(86, 64, 0.76, noiseMix: 0.03),
              _tone(91, 96, 0.64, noiseMix: 0.02),
            ],
            masterGain: 0.76,
          );
      _memoryBurstSfxBytes = await _loadAudioAssetBytes(
            'assets/audio/soul_block/big_win_memory_second_half.mp3',
          ) ??
          _bestScoreSfxBytes;
      _audioReady = true;
      unawaited(_initBgm());
    } catch (error) {
      debugPrint('Soul Block audio init failed: $error');
      _audioReady = false;
    }
  }

  Future<Source> _getBgmSource() async {
    const fileName = 'soul_block_bgm.mp3';
    final localPath =
        await GameDownloadService().getLocalPath('soul_block', fileName);
    if (await File(localPath).exists()) {
      debugPrint('Soul Block: Using LOCAL BGM: $localPath');
      return DeviceFileSource(localPath);
    }
    debugPrint('Soul Block: Using ASSET BGM');
    return AssetSource('audio/soul_block/$fileName');
  }

  Future<void> _initBgm() async {
    try {
      final source = await _getBgmSource();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.52);
      await _bgmPlayer.setSource(source);
      await _syncBgmWithSound(restartIfStopped: true);
    } catch (error) {
      debugPrint('Soul Block bgm init failed: $error');
    }
  }

  Future<void> _resumeBgm({bool restartIfStopped = false}) async {
    try {
      if (!_soundEnabled) {
        await _bgmPlayer.pause();
        return;
      }
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.52);
      if (restartIfStopped) {
        final source = await _getBgmSource();
        await _bgmPlayer.play(source, volume: 0.52);
        return;
      }
      await _bgmPlayer.resume();
    } catch (_) {
      if (restartIfStopped) {
        try {
          final source = await _getBgmSource();
          await _bgmPlayer.play(source, volume: 0.52);
        } catch (_) {}
      }
    }
  }

  Future<void> _syncBgmWithSound({bool restartIfStopped = false}) async {
    try {
      if (_soundEnabled) {
        await _resumeBgm(restartIfStopped: true);
      } else {
        await _bgmPlayer.pause();
      }
    } catch (_) {}
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
        final double harmonic =
            (sine + square + triangle + shimmer + sub).clamp(-1.0, 1.0);
        final double transient =
            pow(1 - (i / stepSamples), 1.8).toDouble().clamp(0.0, 1.0);
        final double noise = (sin(
                  ((sampleIndex + 1) * 12.9898) + (step.frequency * 0.014),
                ) *
                cos(((sampleIndex + 1) * 78.233) + (step.frequency * 0.021)))
            .clamp(-1.0, 1.0);
        final double knock =
            ((noise * 0.58) + (sin(phase * 4.2) * 0.12) + (square * 0.14))
                .clamp(-1.0, 1.0);
        final double sampleValue = ((harmonic * (1 - step.noiseMix)) +
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
    try {
      final fileName = p.basename(assetPath);
      final localPath =
          await GameDownloadService().getLocalPath('soul_block', fileName);
      final localFile = File(localPath);

      if (await localFile.exists()) {
        debugPrint('Soul Block: Loading SFX from LOCAL: $localPath');
        return await localFile.readAsBytes();
      }

      debugPrint('Soul Block: Loading SFX from ASSET: $assetPath');
      final ByteData data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      debugPrint('Soul Block: Error loading SFX ($assetPath): $e');
      return null;
    }
  }

  Future<void> _playSfx(Uint8List? bytes, {double volume = 1}) async {
    if (!_soundEnabled || !_audioReady || bytes == null || bytes.isEmpty) {
      return;
    }
    final AudioPlayer player =
        _sfxPlayers[_sfxPlayerIndex % _sfxPlayers.length];
    _sfxPlayerIndex += 1;
    try {
      await player.setVolume(volume.clamp(0.0, 1.0).toDouble());
      await player.stop();
      await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  void _emitClickFeedback() {
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
          _playSfx(
            selectedBytes,
            volume: volume.clamp(0.0, 1.0).toDouble(),
          ),
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

  void _emitMemoryBurstFeedback() {
    if (!_soundEnabled) {
      return;
    }
    if (_audioReady) {
      unawaited(_playSfx(_memoryBurstSfxBytes, volume: 0.58));
      return;
    }
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  void _showComboBurst(int clearedCount) {
    if (clearedCount <= 0) {
      return;
    }
    if (clearedCount == 2) {
      _showFloatingMessage(
        'COMBO x2',
        color: const Color(0xFF67E8FF),
      );
      return;
    }
    if (clearedCount == 3) {
      _showFloatingMessage(
        'COMBO x3',
        color: const Color(0xFFFFB347),
      );
      return;
    }
    _showFloatingMessage(
      'COMBO x$clearedCount',
      color: const Color(0xFFFFD166),
    );
  }

  void _triggerScreenPulse() {
    _shakeController.forward(from: 0);
    _flashController.forward(from: 0);
  }

  void _showStreakBurst(int streakCount) {
    if (streakCount < 2) {
      return;
    }
    _showFloatingMessage(
      'Streak $streakCount',
      color:
          streakCount >= 4 ? const Color(0xFFFF8A65) : const Color(0xFF67E8FF),
    );
  }

  void _showFloatingMessage(
    String message, {
    required Color color,
  }) {
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

  void _triggerExplosionEffect({
    required int clearedCount,
    required List<int> clearedRows,
    required List<int> clearedCols,
    bool subtle = false,
  }) {
    if (clearedCount < 1) {
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
        _boardCellCenter(
          row.toDouble(),
          (_SoulBlockGameState._boardSize - 1) / 2,
        ),
      for (final int col in clearedCols)
        _boardCellCenter(
          (_SoulBlockGameState._boardSize - 1) / 2,
          col.toDouble(),
        ),
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
    final Offset epicenter = Offset(
      sumDx / anchors.length,
      sumDy / anchors.length,
    );

    final Color accent =
        _kSoulBurstPalette[_random.nextInt(_kSoulBurstPalette.length)];
    final _SoulBlockPerformanceProfile profile = _performanceProfile;
    final bool simpleParticles = profile.tier ==
            _SoulBlockPerformanceTier.low ||
        (profile.tier == _SoulBlockPerformanceTier.mid && clearedCount >= 3);
    final int particleCount = subtle
        ? min((4 + (clearedCount * 2)).clamp(6, 10), profile.subtleParticleCap)
        : min(
            (6 + (clearedCount * 3)).clamp(10, 18), profile.strongParticleCap);
    final double maxDistance = subtle
        ? ((34 + (clearedCount * 7)).clamp(36, 72).toDouble() *
            profile.subtleDistanceScale)
        : ((48 + (clearedCount * 9)).clamp(52, 112).toDouble() *
            profile.strongDistanceScale);
    final List<_ExplosionParticle> particles = <_ExplosionParticle>[];

    for (int index = 0; index < particleCount; index++) {
      final double angle =
          ((index / particleCount) * pi * 2) + (_random.nextDouble() * 0.35);
      final double distance =
          (18 + (_random.nextDouble() * maxDistance)).clamp(18, 112);
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
                  ? 7 + (_random.nextDouble() * 5)
                  : 4 + (_random.nextDouble() * 3))
              : isShard
                  ? 10 + (_random.nextDouble() * 10)
                  : 5 + (_random.nextDouble() * 7),
          rotation: _random.nextDouble() * pi * 2,
          twist: (subtle ? 1.8 : 3.6) *
              _random.nextDouble() *
              (_random.nextBool() ? 1 : -1),
          opacity: ((subtle
                      ? 0.48 + (_random.nextDouble() * 0.18)
                      : 0.64 + (_random.nextDouble() * 0.30)) *
                  profile.opacityScale)
              .clamp(0.24, 0.92),
          delayFraction: (_random.nextDouble() * (subtle ? 0.14 : 0.22)) *
              profile.delayScale,
          isShard: isShard,
          simpleDraw: simpleParticles,
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
    if (_memoryBurstGallery.isEmpty) {
      final String? houseId = _houseId?.trim();
      if (houseId != null && houseId.isNotEmpty) {
        unawaited(_refreshMemoryBurstGallery(houseId));
      }
      return;
    }

    final List<String> warmedGallery = _memoryBurstGallery
        .where(_memoryBurstWarmUrls.contains)
        .toList(growable: false);
    final List<String> selectionPool =
        warmedGallery.isNotEmpty ? warmedGallery : _memoryBurstGallery;
    final String imageUrl = _pickMemoryBurstImage(selectionPool);
    final Color accent =
        _kSoulBurstPalette[_random.nextInt(_kSoulBurstPalette.length)];
    final bool megaBurst = clearedCount >= 4 || streakCount >= 5;
    final List<String> labels = megaBurst
        ? const <String>[
            'Soul Sync Bloom',
            'Locket Love Burst',
            'Heartbeat Memory',
            'Soullight Moment',
            'Our Little Spark',
            'Together in Bloom',
            'Love Note Glow',
            'Memory Kiss Pop',
            'Soulmate Flash',
            'Golden Heartbeat',
            'Sweet Story Shine',
            'Our Day in Lights',
          ]
        : clearedCount >= 4
            ? const <String>[
                'Soul Bloom',
                'Locket Spark',
                'Memory Glow',
                'Little Love Pop',
                'Our Soft Flash',
                'Heartbeat Shine',
                'Sweet Memory Beat',
                'Soul Note Light',
                'Photo Glow Up',
                'Love Story Pop',
                'Tiny Star Moment',
                'Dreamy Heart Sync',
              ]
            : const <String>[
                'Soft Memory',
                'Soul Wink',
                'Locket Glow',
                'Love Flicker',
                'Our Little Frame',
                'Heartnote Spark',
                'Sweet Tiny Burst',
                'Memory Blink',
                'Photo Kiss',
                'Soul Thread',
                'Quiet Heart Glow',
                'Mini Love Flash',
              ];
    final List<String> subtitles = megaBurst
        ? <String>[
            'Combo x$streakCount • tim rung lên một nhịp đẹp',
            'Chuỗi $streakCount • khoảnh khắc của hai đứa vừa sáng lên',
            'Combo x$streakCount • một mảnh ký ức đang nở hoa',
            'Chuỗi $streakCount • Soul Locket đang phát sáng',
            'Combo x$streakCount • ảnh hiện ra như một lời thương',
            'Chuỗi $streakCount • khung hình này thật sự rất dịu',
            'Combo x$streakCount • lại thêm một đoạn yêu được mở ra',
            'Chuỗi $streakCount • hôm nay của mình đẹp ghê',
          ]
        : clearedCount >= 4
            ? <String>[
                'Clear $clearedCount dòng • ký ức bật lên thật xinh',
                'Clear $clearedCount dòng • một khung ảnh vừa sáng dịu',
                'Chuỗi $streakCount • ảnh hiện ra ở đúng khoảnh khắc đẹp',
                'Clear $clearedCount dòng • Soul Locket vừa nở sáng',
                'Chuỗi $streakCount • một chút đáng yêu vừa chạm tới',
                'Clear $clearedCount dòng • tấm này lên hình rất tình',
                'Chuỗi $streakCount • nhìn như một chiếc locket đang mở',
              ]
            : <String>[
                'Chuỗi $streakCount • một mẩu ký ức vừa lóe lên',
                'Clear $clearedCount dòng • ảnh nhỏ mà vẫn rất xinh',
                'Chuỗi $streakCount • một góc thương vừa hiện ra',
                'Clear $clearedCount dòng • cảm giác như mở locket nhỏ',
                'Chuỗi $streakCount • nhẹ thôi nhưng rất dễ thương',
                'Clear $clearedCount dòng • giữ lại khoảnh khắc này nhé',
                'Chuỗi $streakCount • một tấm ảnh, một nhịp tim',
              ];
    final String label = labels[_random.nextInt(labels.length)];
    final String subtitle = subtitles[_random.nextInt(subtitles.length)];

    setState(() {
      _memoryBurstSnapshot = _MemoryBurstSnapshot(
        imageUrl: imageUrl,
        label: label,
        subtitle: subtitle,
        accent: accent,
      );
    });

    unawaited(
      _warmMemoryBurstImages(
        _memoryBurstGallery.where(
          (String url) => !_memoryBurstWarmUrls.contains(url),
        ),
        limit: 1,
      ),
    );
    _emitMemoryBurstFeedback();
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
    return sin(progress * pi * 7) * 12 * (1 - progress);
  }

  double get _boardShakeY {
    final progress = _shakeController.value;
    return cos(progress * pi * 10) * 3 * (1 - progress);
  }

  double get _backgroundFlashOpacity => (1 - _flashController.value) * 0.07;
}
