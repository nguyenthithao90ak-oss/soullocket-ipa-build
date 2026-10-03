// ignore_for_file: invalid_use_of_protected_member
part of '../soul_block_game.dart';

extension _SoulBlockFeedbackPart on _SoulBlockGameState {
  Future<void> _initAudio() async {
    // Hàm chạy từ initState, chưa được đăng ký phụ thuộc vào L10nScope.
    final errorFallback = L10nService().translate('util_khngthkhit_0ee520');
    try {
      // Dùng audio focus riêng cho hiệu ứng để tiếng nổ không làm ngắt nhạc nền.
      try {
        final sfxContext = AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const <AVAudioSessionOptions>{
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        );
        await Future.wait(
          _sfxPlayers.map((player) async {
            if (_audioDisposed) return;
            await player.setAudioContext(sfxContext);
            if (_audioDisposed) return;
            await player.setReleaseMode(ReleaseMode.stop);
          }),
        );
      } catch (error) {
        // Một số nền tảng web/desktop không hỗ trợ audio context; vẫn phát
        // hiệu ứng bằng cấu hình mặc định của audioplayers.
        debugPrint('Soul Block SFX context unavailable: $error');
      }

      final assetBytes = await Future.wait<Uint8List?>(<Future<Uint8List?>>[
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/tap.wav'),
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/lift.wav'),
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/place.wav'),
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/rotate.wav'),
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/invalid.wav'),
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/clear.wav'),
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/bomb.wav'),
        _loadAudioAssetBytes(
          'assets/audio/soul_block/original_v1/combo_x2.wav',
        ),
        _loadAudioAssetBytes(
          'assets/audio/soul_block/original_v1/combo_x3.wav',
        ),
        _loadAudioAssetBytes(
          'assets/audio/soul_block/original_v1/combo_x4.wav',
        ),
        _loadAudioAssetBytes(
          'assets/audio/soul_block/original_v1/combo_x5.wav',
        ),
        _loadAudioAssetBytes(
          'assets/audio/soul_block/original_v1/streak_break.wav',
        ),
        _loadAudioAssetBytes('assets/audio/soul_block/original_v1/revive.wav'),
        _loadAudioAssetBytes(
          'assets/audio/soul_block/original_v1/game_over.wav',
        ),
        _loadAudioAssetBytes(
          'assets/audio/soul_block/original_v1/best_score.wav',
        ),
      ]);
      if (!mounted || _audioDisposed) return;
      Uint8List fallback(int index, List<_SoulSfxTone> tones) =>
          assetBytes[index] ?? _buildWaveBytes(tones);
      _tapSfxBytes = fallback(0, <_SoulSfxTone>[_tone(76, 85, .3)]);
      _liftSfxBytes = fallback(1, <_SoulSfxTone>[
        _tone(60, 24, .84, noiseMix: .22),
        _tone(67, 38, .56, noiseMix: .08),
      ]);
      _placeSfxBytes = fallback(2, <_SoulSfxTone>[
        _tone(50, 26, .92, noiseMix: .34),
        _tone(57, 46, .66, noiseMix: .14),
      ]);
      _rotateSfxBytes = fallback(3, <_SoulSfxTone>[
        _tone(72, 70, .36),
        _tone(79, 105, .28),
      ]);
      _invalidSfxBytes = fallback(4, <_SoulSfxTone>[
        _tone(50, 90, .22),
        _tone(49, 70, .14),
      ]);
      _clearSfxBytes = fallback(5, <_SoulSfxTone>[
        _tone(62, 24, .88, noiseMix: .16),
        _tone(69, 30, .78, noiseMix: .12),
        _tone(76, 54, .76, noiseMix: .06),
      ]);
      _bombSfxBytes = fallback(6, <_SoulSfxTone>[
        _tone(36, 120, 1, noiseMix: .94),
        _tone(43, 90, .88, noiseMix: .86),
      ]);
      _comboSfxLevels = <Uint8List>[
        for (int index = 7; index <= 10; index++)
          assetBytes[index] ??
              _buildWaveBytes(<_SoulSfxTone>[
                _tone(64 + (index - 7) * 2, 24, .88, noiseMix: .12),
                _tone(71 + (index - 7) * 2, 42, .76, noiseMix: .06),
              ]),
      ];
      _streakBreakSfxBytes = fallback(11, <_SoulSfxTone>[
        _tone(72, 120, .25),
        _tone(67, 150, .18),
      ]);
      _reviveSfxBytes = fallback(12, <_SoulSfxTone>[
        _tone(60, 120, .25),
        _tone(67, 150, .25),
        _tone(72, 180, .24),
      ]);
      _gameOverSfxBytes = fallback(13, <_SoulSfxTone>[
        _tone(57, 260, .16),
        _tone(60, 300, .12),
        _tone(64, 420, .10),
      ]);
      _bestScoreSfxBytes = fallback(14, <_SoulSfxTone>[
        _tone(72, 90, .25),
        _tone(79, 120, .25),
        _tone(84, 180, .24),
      ]);
      if (!mounted) return;
      _audioReady = true;
      debugPrint(
        'Soul Block audio ready: ${assetBytes.whereType<Uint8List>().length}/15 bundled effects',
      );
      unawaited(_syncBgmWithSound());
    } catch (error, stackTrace) {
      debugPrint(
        'Soul Block audio init failed: ${AppErrorMapper.resolve(error, fallbackMessage: errorFallback).message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _audioReady = false;
    }
  }

  Future<Source> _getBgmSource() async {
    // Nhạc nền được sáng tác và đóng gói nội bộ, phát offline không cần tải.
    const bundledAsset = 'audio/soul_block/original_v1/neon_memory.mp3';
    debugPrint('Soul Block: Using bundled BGM: $bundledAsset');
    return AssetSource(bundledAsset);
  }

  bool get _canPlayAudio =>
      mounted &&
      !_audioDisposed &&
      _audioSettingsLoaded &&
      _soundEnabled &&
      _appActive &&
      !_isShowingFullscreenAd;

  Future<void> _syncBgmWithSound() {
    // Tuần tự hóa lệnh: trở lại app tiếp tục bản nhạc đang phát.
    _bgmSyncQueue = _bgmSyncQueue.then((_) async {
      if (!mounted || _audioDisposed || !_audioSettingsLoaded || !_audioReady) {
        return;
      }
      try {
        if (!_canPlayAudio) {
          if (_bgmPlayer.state == PlayerState.playing) await _bgmPlayer.pause();
          return;
        }
        if (!_bgmSourceReady) {
          final source = await _getBgmSource();
          if (!mounted || _audioDisposed) return;
          await _bgmPlayer.setAudioContext(
            AudioContext(
              android: const AudioContextAndroid(
                usageType: AndroidUsageType.game,
              ),
              iOS: AudioContextIOS(
                category: AVAudioSessionCategory.playback,
                options: const <AVAudioSessionOptions>{
                  AVAudioSessionOptions.mixWithOthers,
                },
              ),
            ),
          );
          if (!mounted || _audioDisposed) return;
          await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
          if (!mounted || _audioDisposed) return;
          await _bgmPlayer.setVolume(0.28);
          if (!mounted || _audioDisposed) return;
          await _bgmPlayer.setSource(source);
          _bgmSourceReady = true;
        }
        if (!mounted || _audioDisposed) return;
        if (!_canPlayAudio) {
          await _bgmPlayer.pause();
        } else if (_bgmPlayer.state == PlayerState.stopped ||
            _bgmPlayer.state == PlayerState.completed) {
          await _bgmPlayer.play(await _getBgmSource(), volume: 0.28);
          if (!_canPlayAudio) await _bgmPlayer.pause();
        } else if (_bgmPlayer.state != PlayerState.playing) {
          await _bgmPlayer.resume();
          if (!_canPlayAudio) await _bgmPlayer.pause();
        }
      } catch (error) {
        // Web có thể chặn autoplay; thao tác chạm tiếp theo sẽ thử lại.
        debugPrint('Soul Block BGM failed: $error');
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
      // Luôn ưu tiên bộ âm thanh original_v1 đã đóng gói. Gói tải cũ có thể
      // chứa nhạc/hiệu ứng trước đây và làm trải nghiệm giữa các máy khác nhau.
      debugPrint('Soul Block: Loading SFX from ASSET: $assetPath');
      final ByteData data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
    bool isCurrent() => _canPlayAudio && request == _sfxRequests[index];
    // Mỗi player chỉ nhận một lệnh tại một thời điểm. Lệnh cũ bị hủy khi
    // tắt tiếng/vào quảng cáo, kể cả khi đang giải mã âm thanh.
    _sfxQueues[index] = _sfxQueues[index].then((_) async {
      if (!isCurrent()) return;
      try {
        await player.stop();
        if (!isCurrent()) return;
        await player.setSource(
          BytesSource(bytes, mimeType: isWave ? 'audio/wav' : 'audio/mpeg'),
        );
        if (!isCurrent()) return;
        await player.setVolume(volume.clamp(0.0, 1.0).toDouble());
        if (!isCurrent()) return;
        await player.resume();
        if (!isCurrent()) await player.stop();
      } catch (error) {
        debugPrint('Soul Block SFX playback failed: $error');
      }
    });
    await _sfxQueues[index];
  }

  Future<void> _stopSfx() async {
    for (var index = 0; index < _sfxPlayers.length; index++) {
      _sfxRequests[index]++;
      final player = _sfxPlayers[index];
      _sfxQueues[index] = _sfxQueues[index].then((_) async {
        try {
          await player.stop();
        } catch (error) {
          debugPrint('Soul Block SFX stop failed: $error');
        }
      });
    }
    await Future.wait(_sfxQueues);
  }

  Future<void> _disposeAudio() async {
    _audioDisposed = true;
    _audioReady = false;
    for (var index = 0; index < _sfxRequests.length; index++) {
      _sfxRequests[index]++;
    }
    // Đợi các lệnh đang chạy kết thúc trước khi giải phóng player native.
    await _audioInitFuture;
    await Future.wait([..._sfxQueues, _bgmSyncQueue]);
    await Future.wait(
      [..._sfxPlayers, _bgmPlayer].map((player) async {
        try {
          await player.dispose();
        } catch (error) {
          debugPrint('Soul Block audio dispose failed: $error');
        }
      }),
    );
  }

  void _emitClickFeedback() {
    if (_canPlayAudio && _bgmPlayer.state != PlayerState.playing) {
      unawaited(_syncBgmWithSound());
    }
    if (!_canPlayAudio) {
      return;
    }
    if (_audioReady) {
      unawaited(_playSfx(_tapSfxBytes, volume: 0.38));
    } else {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  void _emitRotateFeedback() {
    if (!_canPlayAudio) return;
    if (_bgmPlayer.state != PlayerState.playing) {
      unawaited(_syncBgmWithSound());
    }
    if (_audioReady) {
      unawaited(_playSfx(_rotateSfxBytes ?? _tapSfxBytes, volume: 0.42));
    } else {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  void _emitInvalidFeedback() {
    if (!_canPlayAudio) return;
    if (_audioReady) {
      unawaited(_playSfx(_invalidSfxBytes ?? _tapSfxBytes, volume: 0.44));
    } else {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  void _emitLiftFeedback() {
    if (_canPlayAudio && _bgmPlayer.state != PlayerState.playing) {
      unawaited(_syncBgmWithSound());
    }
    if (_canPlayAudio) {
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
    if (_canPlayAudio) {
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
    if (_canPlayAudio) {
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
    if (_canPlayAudio) {
      if (_audioReady) {
        Uint8List? selectedBytes = _clearSfxBytes;
        double volume = 0.54 + min(clearedCount - 1, 3) * 0.025;

        // Chuỗi lớn dùng giai điệu tổng hợp mới; bộ nhớ và âm lượng có trần,
        // còn số combo hiển thị và thưởng điểm vẫn tiếp tục tăng.
        final int comboLevel = max(2, streakCount);
        if (_comboSfxLevels.isNotEmpty &&
            (streakCount >= 2 || clearedCount >= 2)) {
          selectedBytes = comboLevel > 5
              ? _highComboSoundFor(comboLevel)
              : _comboSfxLevels[min(
                  comboLevel - 2,
                  _comboSfxLevels.length - 1,
                )];
          volume = 0.54 + min(comboLevel, 5) * 0.015;
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

  Uint8List _highComboSoundFor(int comboLevel) {
    // 12 biến thể tái sử dụng cho x6 trở lên, không tích lũy một WAV mỗi lần nổ.
    final variant = (comboLevel - 6) % 12;
    return _highComboSfxCache.putIfAbsent(variant, () {
      const scale = <int>[0, 2, 4, 7, 9, 12];
      final root = 69 + scale[variant % scale.length];
      final sparkle = variant >= 6 ? 3 : 0;
      return _buildWaveBytes(<_SoulSfxTone>[
        _tone(root - 12, 32, .66, noiseMix: .08),
        _tone(root, 44, .62),
        _tone(root + 7, 48, .48),
        _tone(root + 12 + sparkle, 84, .36),
      ], masterGain: .74);
    });
  }

  void _emitStreakBreakFeedback() {
    if (!_canPlayAudio) return;
    if (_audioReady) {
      unawaited(_playSfx(_streakBreakSfxBytes, volume: 0.42));
    } else {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  void _emitReviveFeedback() {
    if (!_canPlayAudio) return;
    if (_audioReady) {
      unawaited(_playSfx(_reviveSfxBytes ?? _clearSfxBytes, volume: 0.60));
    } else {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  void _emitGameOverFeedback() {
    if (!_canPlayAudio) return;
    if (_audioReady) {
      unawaited(_playSfx(_gameOverSfxBytes, volume: 0.56));
    } else {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  void _emitBestScoreFeedback() {
    if (!_canPlayAudio) {
      return;
    }
    if (_audioReady) {
      unawaited(_playSfx(_bestScoreSfxBytes, volume: 0.50));
      return;
    }
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  void _showComboBurst(
    int comboLevel, {
    int gainedScore = 0,
    bool allClear = false,
  }) {
    if (comboLevel < 1) {
      return;
    }
    final color = comboLevel < 5
        ? const Color(0xFF9DE7FF)
        : comboLevel < 10
        ? const Color(0xFFC3B6F6)
        : comboLevel < 25
        ? const Color(0xFFE9C9A2)
        : const Color(0xFFFFD783);
    _showFloatingMessage(
      allClear
          ? L10nService().translate('soul_block_all_clear')
          : L10nService().format('soul_block_combo', {'level': comboLevel}),
      color: color,
      detail: gainedScore > 0 ? '+${_formatNumber(gainedScore)}' : null,
    );
  }

  void _triggerScreenPulse() {
    if (MediaQuery.disableAnimationsOf(context) || _draggingPiece != null) {
      return;
    }
    _shakeController.forward(from: 0);
    _flashController.forward(from: 0);
  }

  void _showFloatingMessage(
    String message, {
    required Color color,
    String? detail,
  }) {
    setState(() {
      _floatingText = message;
      _floatingScoreText = detail;
      _floatingTextColor = color;
    });
    _floatingController.forward(from: 0);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(
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
        subtitle: L10nService().format('soul_block_combo', {
          'level': streakCount,
        }),
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
