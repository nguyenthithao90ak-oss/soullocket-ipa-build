import 'soul_rhythm/soul_rhythm_models.dart';
import 'soul_rhythm/soul_rhythm_painters.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/admob_service.dart';
import '../ui_prefs.dart';
import '../../core/sl_theme.dart';
import 'soul_rhythm_music_config.dart';
import '../../utils/services/game_download_service.dart';
import '../../utils/app_error_mapper.dart';

part 'soul_rhythm/ui/soul_rhythm_hud.dart';
part 'soul_rhythm/ui/soul_rhythm_playfield.dart';
part 'soul_rhythm/ui/soul_rhythm_menu_screen.dart';
part 'soul_rhythm/ui/soul_rhythm_game_over_screen.dart';

class _GameChartEvent {
  final SoulRhythmToneSpec tone;
  final int startMs;
  final int lane4;

  const _GameChartEvent({
    required this.tone,
    required this.startMs,
    required this.lane4,
  });
}

class _SoulRhythmReviveSnapshot {
  const _SoulRhythmReviveSnapshot({
    required this.score,
    required this.combo,
    required this.maxCombo,
    required this.perfects,
    required this.misses,
    required this.hits,
    required this.speedMultiplier,
    required this.chartElapsedMs,
    required this.chartEventIndex,
    required this.chartLoopIndex,
    required this.nextChartEventMs,
    required this.gameTrackStarted,
    required this.tiles,
  });

  final int score;
  final int combo;
  final int maxCombo;
  final int perfects;
  final int misses;
  final int hits;
  final double speedMultiplier;
  final double chartElapsedMs;
  final int chartEventIndex;
  final int chartLoopIndex;
  final double nextChartEventMs;
  final bool gameTrackStarted;
  final List<Tile> tiles;
}

class SoulRhythmGame extends StatefulWidget {
  const SoulRhythmGame({super.key});

  @override
  State<SoulRhythmGame> createState() => _SoulRhythmGameState();
}

class _SoulRhythmGameState extends State<SoulRhythmGame>
    with TickerProviderStateMixin {
  static const String _highScoreKey = 'soul_rhythm_best_score';
  static const String _gameIconPath = 'assets/games/rhythm-tiles/icon.png';
  static const String _customTrackAssetPath =
      'audio/soul_rhythm_reference/tutorial_songs/AxelF_CrazyFrog_Tutorial.mp3';
  static const String _customTrackLabel = 'AXEL F';
  static const Duration _gameOverRevealDelay = Duration(seconds: 3);
  static const double _laneGap = 12.0;
  static const Color _unityCyan = Color(0xFF67E8FF);
  static const Color _unityPink = Color(0xFFFF4D9B);
  static const Color _unityGold = Color(0xFFFFD86B);
  static const String _customTrackMixTitle =
      'Crazy Frog · Tutorial reference loop';
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  late AnimationController _pulseController;
  bool _didPrecacheGameIcon = false;
  final ValueNotifier<int> _playfieldFrame = ValueNotifier<int>(0);
  final ValueNotifier<int> _hudFrame = ValueNotifier<int>(0);

  final AdMobService _adMob = AdMobService();
  final Random _random = Random();
  final List<Tile> _tiles = [];
  final List<Particle> _particles = [];
  final List<FloatingText> _floatingTexts = [];
  final List<TouchBurst> _touchBursts = [];
  final AudioPlayer _bgPlayer = AudioPlayer(playerId: 'soul_rhythm_bg');
  late final List<AudioPlayer> _sfxPlayers;

  String _gameState = 'MENU'; // MENU, PLAYING, ENDING, OVER
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _perfects = 0;
  int _misses = 0;
  int _hits = 0;
  int _lives = 3;
  int _highScore = 0;
  double _speedMultiplier = 1.0;
  double _chartElapsedMs = 0;
  int _chartEventIndex = 0;
  int _chartLoopIndex = 0;
  String _difficulty = 'normal';
  bool _isPaused = false;
  bool _newBestAchieved = false;
  bool _reviveUsed = false;
  bool _showReviveOffer = false;
  bool _isWatchingReviveAd = false;
  _SoulRhythmReviveSnapshot? _reviveSnapshot;
  Timer? _reviveTimer;
  Timer? _gameOverRevealTimer;
  int _sfxPlayerIndex = 0;
  bool _touchSoundEnabled = UiPrefsState.defaults.touchSound;
  bool _musicAutoplayEnabled = UiPrefsState.defaults.musicAutoplay;
  bool _audioReady = false;
  SharedPreferences? _cachedPrefs;
  String _activeTrack = '';
  SoulRhythmTrackConfig get _trackConfig => kSoulRhythmTrackConfig;
  String get _displayTrackLabel =>
      (_useCustomTrackAsset || _customTrackBytes != null)
          ? _customTrackLabel
          : _trackConfig.label;
  String get _displayMixTitle =>
      (_useCustomTrackAsset || _customTrackBytes != null)
          ? _customTrackMixTitle
          : _trackConfig.mixTitle;
  Uint8List? _menuLoopBytes;
  Uint8List? _gameLoopBytes;
  bool _useCustomTrackAsset = false;
  Uint8List? _customTrackBytes;
  Uint8List? _tapBytes;
  Uint8List? _perfectTapBytes;
  Uint8List? _missBytes;
  Uint8List? _selectBytes;
  late final List<_GameChartEvent> _baseGameChartEvents;
  List<_GameChartEvent> _gameChartEvents = <_GameChartEvent>[];
  int _gameChartLoopDurationMs = 1;
  bool _gameTrackStarted = false;
  double _nextChartEventMs = 0;
  int _stateGeneration = 0;
  int _lastTapSfxUs = 0;
  int _lastPerfectSfxUs = 0;
  int _lastMissSfxUs = 0;
  int _lastSelectSfxUs = 0;

  final List<Color> _colors = [
    const Color(0xFFFF0055),
    const Color(0xFF00E5FF),
    const Color(0xFFFFEB3B),
    const Color(0xFF76FF03),
    const Color(0xFFE040FB),
  ];

  String get _graphicsProfile {
    final ui = UiPrefs.notifier.value;
    if (ui.liteMode) return 'low';
    final key = ui.graphicsQualityKey.trim().toLowerCase();
    if (key == 'high') return 'high';
    if (key == 'low') return 'low';
    return 'balanced';
  }

  bool get _isLowGraphics => _graphicsProfile == 'low';
  bool get _isHighGraphics => _graphicsProfile == 'high';
  bool get _useReleaseSafePlayfield => !kDebugMode && Platform.isAndroid;

  Color get _graphicsChipColor {
    switch (_graphicsProfile) {
      case 'high':
        return const Color(0xFF76FF03);
      case 'low':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF29B6F6);
    }
  }

  String get _graphicsChipValue {
    switch (_graphicsProfile) {
      case 'high':
        return 'BOOST';
      case 'low':
        return 'LIGHT';
      default:
        return 'SMART';
    }
  }

  int _laneCountForWidth(double width) => width > 360 ? 4 : 3;

  int get _maxLivesForDifficulty => switch (_difficulty) {
        'easy' => 5,
        'hard' => 2,
        _ => 3,
      };

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return const Color(0xFF8DFF7A);
      case 'hard':
        return const Color(0xFFFF8A65);
      default:
        return _unityGold;
    }
  }

  int get _chartMinGapMs => switch (_difficulty) {
        'easy' => 340,
        'hard' => 260,
        _ => 300,
      };

  @override
  void initState() {
    super.initState();
    _adMob.suppressAutoInterstitial();
    _sfxPlayers = List.generate(
      4,
      (index) => AudioPlayer(playerId: 'soul_rhythm_sfx_$index'),
    );
    _adMob.preloadSoulGameRewardedAd();
    _ticker = createTicker(_onTick);
    unawaited(_primePrefs());
    _loadHighScore();
    _initGameChart();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    UiPrefs.notifier.addListener(_handleUiPrefsChanged);
    unawaited(_ensurePreferredDefaults());
    _initAudio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheGameIcon) {
      return;
    }

    _didPrecacheGameIcon = true;
    unawaited(
      () async {
        try {
          await precacheImage(
            _gameIconProvider(
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
            context,
          );
        } catch (error) {
          debugPrint(
            'Soul Rhythm icon precache failed: ${AppErrorMapper.resolve(error).message}',
          );
        }
      }(),
    );
  }

  ImageProvider<Object> _gameIconProvider({
    double logicalSize = 42,
    required double devicePixelRatio,
  }) {
    final cacheSize = (logicalSize * devicePixelRatio).round();
    return ResizeImage.resizeIfNeeded(
      cacheSize > 0 ? cacheSize : 1,
      cacheSize > 0 ? cacheSize : 1,
      const AssetImage(_gameIconPath),
    );
  }

  Future<void> _primePrefs() async {
    _cachedPrefs = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _prefs() async {
    final cached = _cachedPrefs;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    return prefs;
  }

  @override
  void dispose() {
    _adMob.resumeAutoInterstitial();
    _stateGeneration++;
    _cancelReviveCountdown();
    _cancelGameOverReveal();
    UiPrefs.notifier.removeListener(_handleUiPrefsChanged);
    _bgPlayer.dispose();
    for (final player in _sfxPlayers) {
      player.dispose();
    }
    _ticker.dispose();
    _pulseController.dispose();
    _playfieldFrame.dispose();
    _hudFrame.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await _prefs();
    if (!mounted) {
      return;
    }
    setState(() {
      _highScore = prefs.getInt(_highScoreKey) ?? 0;
    });
  }

  void _initGameChart() {
    final events = <_GameChartEvent>[];
    final steps = _trackConfig.gameSteps;
    final lanes = _trackConfig.gameLanePattern4;
    var startMs = 0;

    for (int i = 0; i < steps.length; i++) {
      final tone = steps[i];
      final lane4 = i < lanes.length ? lanes[i] : -1;
      final isPlayable = _midiFromNoteName(tone.note) > 0 && lane4 >= 0;
      if (isPlayable) {
        events.add(_GameChartEvent(
          tone: tone,
          startMs: startMs,
          lane4: lane4,
        ));
      }
      startMs += tone.durationMs;
    }

    _baseGameChartEvents = events;
    _gameChartLoopDurationMs = max(1, startMs);
    _rebuildGameChartForDifficulty();
  }

  void _rebuildGameChartForDifficulty() {
    if (_baseGameChartEvents.isEmpty) {
      _gameChartEvents = <_GameChartEvent>[];
      return;
    }

    final int windowMs = _chartMinGapMs;
    final List<_GameChartEvent> grouped = <_GameChartEvent>[];
    _GameChartEvent bestEvent = _baseGameChartEvents.first;
    var windowStartMs = bestEvent.startMs;
    int? previousAcceptedLane;

    for (final _GameChartEvent event in _baseGameChartEvents.skip(1)) {
      if (event.startMs - windowStartMs < windowMs) {
        final bool shouldReplace = _chartEventPriority(
              event,
              previousLane4: previousAcceptedLane,
            ) >=
            _chartEventPriority(
              bestEvent,
              previousLane4: previousAcceptedLane,
            );
        if (shouldReplace) {
          bestEvent = event;
        }
        continue;
      }

      grouped.add(bestEvent);
      previousAcceptedLane = bestEvent.lane4;
      bestEvent = event;
      windowStartMs = event.startMs;
    }
    grouped.add(bestEvent);

    final List<_GameChartEvent> filtered = <_GameChartEvent>[];
    for (final _GameChartEvent event in grouped) {
      if (filtered.isEmpty) {
        filtered.add(event);
        continue;
      }

      final _GameChartEvent previous = filtered.last;
      final int sameLaneGapTarget =
          event.lane4 == previous.lane4 ? windowMs + 80 : windowMs - 50;
      final bool tooClose =
          (event.startMs - previous.startMs) < max(160, sameLaneGapTarget);

      if (!tooClose) {
        filtered.add(event);
        continue;
      }

      final int? olderLane =
          filtered.length > 1 ? filtered[filtered.length - 2].lane4 : null;
      final bool replacePrevious = _chartEventPriority(
            event,
            previousLane4: olderLane,
          ) >
          _chartEventPriority(
            previous,
            previousLane4: olderLane,
          );
      if (replacePrevious) {
        filtered[filtered.length - 1] = event;
      }
    }

    _gameChartEvents = filtered;
  }

  double _chartEventPriority(
    _GameChartEvent event, {
    int? previousLane4,
  }) {
    final int midi = _midiFromNoteName(event.tone.note);
    final bool isAccent = event.tone.durationMs >= 220;
    final bool isLong = event.tone.durationMs >= 180;
    final bool isLead = midi >= _midiFromNoteName('B5');
    double score = event.tone.durationMs * 0.52;
    score += event.tone.volume * 100;
    if (isLong) score += 18;
    if (isAccent) score += 22;
    if (isLead) score += 26;
    if (previousLane4 != null && previousLane4 != event.lane4) {
      score += 8;
    }
    return score;
  }

  double _chartScrollSpeed() => 6.0 * _speedMultiplier;

  double _chartLeadInMs(Rect playArea) =>
      (_hitLineY(playArea) / _chartScrollSpeed()) * (1000 / 60);

  int _resolveLaneForWidth(int lane4, int laneCount) {
    if (laneCount <= 1) return 0;
    if (laneCount >= 4) return lane4.clamp(0, laneCount - 1);
    return ((lane4 * (laneCount - 1)) / 3).round().clamp(0, laneCount - 1);
  }

  Color _chartColorForEvent(_GameChartEvent event) {
    final peakMidi = _midiFromNoteName(event.tone.note);
    if (peakMidi >= _midiFromNoteName('B5')) {
      return _unityCyan;
    }
    if (event.tone.durationMs >= 220) {
      return _unityGold;
    }
    return _colors[event.lane4 % _colors.length];
  }

  void _spawnChartTiles(Rect playArea) {
    if (_gameChartEvents.isEmpty) return;
    final hitLineY = _hitLineY(playArea);
    final playfieldGeometry = _buildPlayfieldGeometry(playArea, hitLineY);
    final laneCount = playfieldGeometry.laneCount;

    while (_chartElapsedMs + 0.5 >= _nextChartEventMs) {
      final event = _gameChartEvents[_chartEventIndex];

      _spawnChartTile(event, playArea, laneCount);
      _spawnBeatAccentEffects(event, playArea, laneCount);
      _advanceChartSchedule();
    }
  }

  void _resetChartSchedule() {
    _chartEventIndex = 0;
    _chartLoopIndex = 0;
    _nextChartEventMs = _gameChartEvents.isEmpty
        ? double.infinity
        : _gameChartEvents.first.startMs.toDouble();
  }

  void _advanceChartSchedule() {
    _chartEventIndex++;
    if (_chartEventIndex >= _gameChartEvents.length) {
      _chartEventIndex = 0;
      _chartLoopIndex++;
    }
    _nextChartEventMs = ((_chartLoopIndex * _gameChartLoopDurationMs) +
            _gameChartEvents[_chartEventIndex].startMs)
        .toDouble();
  }

  void _spawnBeatAccentEffects(
    _GameChartEvent event,
    Rect playArea,
    int laneCount,
  ) {
    if (_isLowGraphics || event.lane4 < 0) {
      return;
    }
    final isPhraseBeat = _chartEventIndex % 4 == 0;
    final isStrongNote = event.tone.durationMs >= 200 ||
        _midiFromNoteName(event.tone.note) >= _midiFromNoteName('D5');
    if (!isPhraseBeat && !isStrongNote) {
      return;
    }

    final laneWidth =
        (playArea.width - (_laneGap * (laneCount - 1))) / laneCount;
    final lane = _resolveLaneForWidth(event.lane4, laneCount);
    final x = lane * (laneWidth + _laneGap) + (laneWidth * 0.5);
    final y = _hitLineY(playArea) - (_isHighGraphics ? 42 : 32);
    final color = isPhraseBeat ? _unityGold : _chartColorForEvent(event);
    final count = _isHighGraphics ? 10 : 6;

    _trimParticles(_isHighGraphics ? 190 : 125);
    for (int i = 0; i < count; i++) {
      final angle = ((i / count) * 2 * pi) + (_random.nextDouble() * 0.25);
      final speed = (_isHighGraphics ? 7.0 : 5.2) + _random.nextDouble() * 4.0;
      _particles.add(
        Particle(
          x: x,
          y: y,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: i.isEven ? color : _unityCyan,
          life: (_isHighGraphics ? 22.0 : 17.0) + _random.nextDouble() * 10.0,
        ),
      );
    }

    _spawnTouchBurst(
      x,
      y,
      color.withValues(alpha: _isHighGraphics ? 0.62 : 0.46),
      strong: isPhraseBeat,
    );
  }

  void _spawnChartTile(_GameChartEvent event, Rect playArea, int laneCount) {
    final laneWidth =
        (playArea.width - (_laneGap * (laneCount - 1))) / laneCount;
    final lane = _resolveLaneForWidth(event.lane4, laneCount);
    final width = laneWidth * 0.90;
    final shortHeight = min(132.0, max(92.0, laneWidth * 1.12));
    final longHeight = min(208.0, max(150.0, laneWidth * 1.78));
    final durationT =
        ((event.tone.durationMs - 120) / 120).clamp(0.0, 1.0).toDouble();
    final height = shortHeight + ((longHeight - shortHeight) * durationT);
    final laneStart = lane * (laneWidth + _laneGap);
    final x = laneStart + ((laneWidth - width) / 2);

    _tiles.add(Tile(
      x: x,
      y: -height,
      width: width,
      height: height,
      color: _chartColorForEvent(event),
    ));
  }

  Future<void> _ensurePreferredDefaults() async {
    await UiPrefs.ensureLoaded();
    final prefs = await _prefs();
    final current = UiPrefs.notifier.value;

    final hasTouchSound = prefs.containsKey('il_touch_sound');
    final hasMusicAutoplay = prefs.containsKey('il_music_autoplay');
    final hasLiteMode = prefs.containsKey('il_lite_mode');
    final hasGraphics = prefs.containsKey('il_graphics_quality');

    if (hasTouchSound && hasMusicAutoplay && hasLiteMode && hasGraphics) {
      return;
    }

    await UiPrefs.saveState(
      current.copyWith(
        touchSound: hasTouchSound ? current.touchSound : true,
        musicAutoplay: hasMusicAutoplay ? current.musicAutoplay : true,
        liteMode: hasLiteMode ? current.liteMode : false,
        graphicsQualityKey:
            hasGraphics ? current.graphicsQualityKey : 'balanced',
      ),
    );
  }

  Future<void> _saveHighScore(int score) async {
    final prefs = await _prefs();
    await prefs.setInt(_highScoreKey, score);
  }

  Future<void> _initAudio() async {
    try {
      await UiPrefs.ensureLoaded();
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(0.34);
      _menuLoopBytes = _buildWaveBytes(
        _trackConfig.menuSteps.map(_toneFromSpec).toList(),
        masterGain: _trackConfig.menuGain,
      );
      _gameLoopBytes = _buildWaveBytes(
        _trackConfig.gameSteps.map(_toneFromSpec).toList(),
        masterGain: _trackConfig.gameGain,
      );
      _customTrackBytes = null;
      _useCustomTrackAsset = false;
      _tapBytes = _buildWaveBytes(
        [
          _tone(88, 24, 0.92),
          _tone(83, 34, 0.74),
        ],
        masterGain: 0.90,
      );
      _perfectTapBytes = _buildWaveBytes(
        [
          _tone(88, 24, 1.00),
          _tone(95, 34, 0.94),
          _tone(100, 54, 0.82),
        ],
        masterGain: 0.98,
      );
      _missBytes = _buildWaveBytes(
        [
          _tone(65, 70, 0.72),
          _tone(53, 92, 0.56),
        ],
        masterGain: 0.82,
      );
      _selectBytes = _buildWaveBytes(
        [
          _tone(79, 54, 0.78),
          _tone(84, 74, 0.72),
        ],
        masterGain: 0.86,
      );
      _audioReady = true;
      for (final player in _sfxPlayers) {
        unawaited(player.setReleaseMode(ReleaseMode.stop));
      }
      _handleUiPrefsChanged();
      await _syncBackgroundTrack(force: true);
    } catch (error) {
      debugPrint(
        'Soul Rhythm audio init failed: ${AppErrorMapper.resolve(error).message}',
      );
      _audioReady = false;
      _customTrackBytes = null;
      _useCustomTrackAsset = false;
      _menuLoopBytes = _menuLoopBytes ?? Uint8List(0);
      _gameLoopBytes = _gameLoopBytes ?? Uint8List(0);
      _tapBytes = _tapBytes ?? Uint8List(0);
      _perfectTapBytes = _perfectTapBytes ?? Uint8List(0);
      _missBytes = _missBytes ?? Uint8List(0);
      _selectBytes = _selectBytes ?? Uint8List(0);
    }
  }

  void _handleUiPrefsChanged() {
    final prefs = UiPrefs.notifier.value;
    final touchSoundEnabled = prefs.touchSound;
    final musicAutoplayEnabled = prefs.musicAutoplay;
    final changed = touchSoundEnabled != _touchSoundEnabled ||
        musicAutoplayEnabled != _musicAutoplayEnabled;
    _touchSoundEnabled = touchSoundEnabled;
    _musicAutoplayEnabled = musicAutoplayEnabled;
    unawaited(_syncBackgroundTrack(force: true));
    if (changed && mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMusicAutoplay() async {
    HapticFeedback.selectionClick();
    if (_allowSfx(_lastSelectSfxUs, 90000)) {
      _lastSelectSfxUs = _nowUs();
      unawaited(_playSfx(_selectBytes, volume: 0.68));
    }
    await UiPrefs.saveState(
      UiPrefs.notifier.value.copyWith(
        musicAutoplay: !_musicAutoplayEnabled,
      ),
    );
  }

  Future<void> _toggleTouchSound() async {
    final nextValue = !_touchSoundEnabled;
    HapticFeedback.selectionClick();
    await UiPrefs.saveState(
      UiPrefs.notifier.value.copyWith(
        touchSound: nextValue,
      ),
    );
    if (nextValue) {
      if (_allowSfx(_lastSelectSfxUs, 90000)) {
        _lastSelectSfxUs = _nowUs();
        unawaited(_playSfx(_selectBytes, volume: 0.68));
      }
    }
  }

  Future<void> _toggleLowGraphics() async {
    final current = _graphicsProfile;
    final next = current == 'low' ? 'balanced' : 'low';
    HapticFeedback.selectionClick();
    if (_allowSfx(_lastSelectSfxUs, 90000)) {
      _lastSelectSfxUs = _nowUs();
      unawaited(_playSfx(_selectBytes, volume: 0.68));
    }
    await UiPrefs.saveState(
      UiPrefs.notifier.value.copyWith(
        graphicsQualityKey: next,
      ),
    );
  }

  void _backToMenu() {
    _stateGeneration++;
    _cancelReviveCountdown();
    _cancelGameOverReveal();
    HapticFeedback.mediumImpact();
    if (_allowSfx(_lastSelectSfxUs, 90000)) {
      _lastSelectSfxUs = _nowUs();
      unawaited(_playSfx(_selectBytes, volume: 0.72));
    }
    setState(() {
      _gameState = 'MENU';
      _gameTrackStarted = false;
      _isPaused = false;
      _showReviveOffer = false;
      _isWatchingReviveAd = false;
    });
    unawaited(_syncBackgroundTrack(force: true));
  }

  ToneStep _tone(int midi, int durationMs, double volume) {
    if (midi <= 0) {
      return ToneStep(0, durationMs, volume);
    }
    return ToneStep(
      440.0 * pow(2, (midi - 69) / 12).toDouble(),
      durationMs,
      volume,
    );
  }

  ToneStep _toneFromSpec(SoulRhythmToneSpec spec) {
    return _tone(_midiFromNoteName(spec.note), spec.durationMs, spec.volume);
  }

  int _midiFromNoteName(String noteName) {
    final normalized = noteName.trim().toUpperCase();
    if (normalized.isEmpty || normalized == 'REST' || normalized == 'R') {
      return 0;
    }
    final match = RegExp(r'^([A-G])([#B]?)(-?\d+)$').firstMatch(normalized);
    if (match == null) {
      return 0;
    }
    final base = switch (match.group(1)) {
      'C' => 0,
      'D' => 2,
      'E' => 4,
      'F' => 5,
      'G' => 7,
      'A' => 9,
      'B' => 11,
      _ => 0,
    };
    final accidental = match.group(2) ?? '';
    final octave = int.tryParse(match.group(3) ?? '') ?? 4;
    final semitone = accidental == '#'
        ? base + 1
        : accidental == 'B'
            ? base - 1
            : base;
    return ((octave + 1) * 12) + semitone;
  }

  Uint8List _buildWaveBytes(
    List<ToneStep> steps, {
    int sampleRate = 22050,
    double masterGain = 0.75,
  }) {
    final totalSamples = steps.fold<int>(
      0,
      (sum, step) => sum + max(1, (sampleRate * step.durationMs) ~/ 1000),
    );
    final byteData = ByteData(44 + (totalSamples * 2));

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
    for (final step in steps) {
      final stepSamples = max(1, (sampleRate * step.durationMs) ~/ 1000);
      final attackSamples = max(12, stepSamples ~/ 10);
      final releaseSamples = max(22, stepSamples ~/ 4);
      for (int i = 0; i < stepSamples; i++) {
        double envelope = 1.0;
        if (i < attackSamples) {
          envelope = i / attackSamples;
        } else if (i > stepSamples - releaseSamples) {
          envelope = (stepSamples - i) / releaseSamples;
        }
        envelope = envelope.clamp(0.0, 1.0);

        double sampleValue = 0;
        if (step.frequency > 0) {
          final time = i / sampleRate;

          // Nâng cấp âm thanh Synthwave / Cyberpunk (Dày, sắc và mạnh hơn)
          // 1. Sóng vuông (Square wave) kết hợp sóng răng cưa (Sawtooth) để tạo chất điện tử chói tai
          final phase = 2 * pi * step.frequency * time;
          final square = (sin(phase) > 0 ? 1.0 : -1.0) * 0.38;
          final sawtooth =
              (2.0 * (time * step.frequency - (time * step.frequency).floor()) -
                      1.0) *
                  0.28;

          // 2. Sub-bass nhẹ hơn để đỡ đục trên loa điện thoại
          final subPhase = 2 * pi * (step.frequency * 0.5) * time;
          final subBass = sin(subPhase) * 0.34;

          // 3. Shimmer sáng hơn để hit nổi rõ hơn
          final shimmerPhase = 2 * pi * (step.frequency * 2.0) * time;
          final shimmer = sin(shimmerPhase) * 0.22;

          // Trộn các dải âm lại
          sampleValue = square + sawtooth + subBass + shimmer;

          // Overdrive nhẹ hơn để âm sạch hơn nhưng vẫn có lực
          sampleValue = (sampleValue * 1.18).clamp(-1.0, 1.0);
        }
        final pcm = (sampleValue * envelope * step.volume * masterGain * 32767)
            .round()
            .clamp(-32767, 32767);
        byteData.setInt16(44 + (sampleIndex * 2), pcm, Endian.little);
        sampleIndex++;
      }
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _playSfx(Uint8List? bytes, {double volume = 1}) async {
    if (!_audioReady || !_touchSoundEnabled || bytes == null || bytes.isEmpty) {
      return;
    }
    final player = _sfxPlayers[_sfxPlayerIndex % _sfxPlayers.length];
    _sfxPlayerIndex++;
    unawaited(player.setVolume(volume));
    unawaited(player.play(BytesSource(bytes, mimeType: 'audio/wav')));
  }

  int _nowUs() => DateTime.now().microsecondsSinceEpoch;

  bool _allowSfx(int lastUs, int minGapUs) => (_nowUs() - lastUs) >= minGapUs;

  void _trimParticles(int maxCount) {
    if (_particles.length <= maxCount) return;
    _particles.removeRange(0, _particles.length - maxCount);
  }

  void _trimFloatingTexts(int maxCount) {
    if (_floatingTexts.length <= maxCount) return;
    _floatingTexts.removeRange(0, _floatingTexts.length - maxCount);
  }

  void _trimTouchBursts(int maxCount) {
    if (_touchBursts.length <= maxCount) return;
    _touchBursts.removeRange(0, _touchBursts.length - maxCount);
  }

  Future<void> _syncBackgroundTrack({bool force = false}) async {
    if (!_audioReady) {
      return;
    }
    final forceGameplayMusic = _gameState == 'PLAYING';
    if (!_musicAutoplayEnabled && !forceGameplayMusic) {
      if (_activeTrack.isNotEmpty || force) {
        _activeTrack = '';
        await _bgPlayer.stop();
      }
      return;
    }

    final desiredTrack = _useCustomTrackAsset || _customTrackBytes != null
        ? 'custom'
        : _gameState == 'PLAYING'
            ? (_gameTrackStarted ? 'game' : 'menu')
            : 'menu';
    if (desiredTrack.isEmpty) {
      if (_activeTrack.isNotEmpty || force) {
        _activeTrack = '';
        await _bgPlayer.stop();
      }
      return;
    }
    if (!force && desiredTrack == _activeTrack) {
      return;
    }

    final bytes = desiredTrack == 'game' ? _gameLoopBytes : _menuLoopBytes;
    if (desiredTrack != 'custom' && (bytes == null || bytes.isEmpty)) {
      return;
    }

    _activeTrack = desiredTrack;
    await _bgPlayer.setVolume(
      desiredTrack == 'custom'
          ? 0.44
          : desiredTrack == 'game'
              ? 0.48
              : 0.36,
    );
    await _bgPlayer.stop();
    if (desiredTrack == 'custom') {
      final fileName = p.basename(_customTrackAssetPath);
      final localPath = await GameDownloadService().getLocalPath('soul_rhythm', fileName);
      if (await File(localPath).exists()) {
        debugPrint('Soul Rhythm: Using LOCAL track: $localPath');
        await _bgPlayer.play(DeviceFileSource(localPath));
        return;
      }
      final fallbackBytes = _gameState == 'PLAYING' ? _gameLoopBytes : _menuLoopBytes;
      if (fallbackBytes != null && fallbackBytes.isNotEmpty) {
        debugPrint('Soul Rhythm: Local track missing, using generated fallback.');
        await _bgPlayer.play(
          BytesSource(
            fallbackBytes,
            mimeType: 'audio/wav',
          ),
        );
      }
      return;
    }
    await _bgPlayer.play(
      BytesSource(
        bytes!,
        mimeType: 'audio/wav',
      ),
    );
  }

  void _cancelReviveCountdown() {
    _reviveTimer?.cancel();
    _reviveTimer = null;
  }

  void _cancelGameOverReveal() {
    _gameOverRevealTimer?.cancel();
    _gameOverRevealTimer = null;
  }

  void _playHitFeedback(bool isPerfect) {
    if (isPerfect) {
      if (_allowSfx(_lastPerfectSfxUs, 45000)) {
        _lastPerfectSfxUs = _nowUs();
        unawaited(_playSfx(_perfectTapBytes, volume: 0.48));
      }
    } else if (_allowSfx(_lastTapSfxUs, 30000)) {
      _lastTapSfxUs = _nowUs();
      unawaited(_playSfx(_tapBytes, volume: 0.39));
    }
    if (!_touchSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    if (isPerfect) {
      HapticFeedback.heavyImpact();
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.lightImpact();
  }

  void _playMissFeedback() {
    if (_allowSfx(_lastMissSfxUs, 70000)) {
      _lastMissSfxUs = _nowUs();
      unawaited(_playSfx(_missBytes, volume: 0.84));
    }
    if (!_touchSoundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
    HapticFeedback.vibrate();
  }

  Rect _playAreaRect() {
    final media = MediaQuery.of(context);
    final isCompactWidth = media.size.width < 390;
    final sideInset = isCompactWidth ? 6.0 : 8.0;
    final top = media.padding.top + (isCompactWidth ? 62.0 : 68.0);
    final bottom = media.size.height - media.padding.bottom - 14;
    return Rect.fromLTWH(
      sideInset,
      top,
      media.size.width - (sideInset * 2),
      max(260.0, bottom - top),
    );
  }

  double _hitLineY(Rect playArea) => playArea.height * 0.8;

  void _onTick(Duration elapsed) {
    if (_gameState != 'PLAYING' || _isPaused) {
      _lastElapsed = elapsed;
      return;
    }

    double dt = (elapsed - _lastElapsed).inMicroseconds / 16666.66;
    if (dt > 3.0) dt = 3.0;
    _lastElapsed = elapsed;

    _gameLoop(dt);
  }

  void _startGame() {
    _stateGeneration++;
    if (_allowSfx(_lastSelectSfxUs, 90000)) {
      _lastSelectSfxUs = _nowUs();
      unawaited(_playSfx(_selectBytes, volume: 0.82));
    }
    HapticFeedback.mediumImpact();
    _cancelReviveCountdown();
    _cancelGameOverReveal();
    _rebuildGameChartForDifficulty();
    setState(() {
      _gameState = 'PLAYING';
      _isPaused = false;
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _perfects = 0;
      _misses = 0;
      _hits = 0;
      _newBestAchieved = false;
      _reviveUsed = false;
      _showReviveOffer = false;
      _isWatchingReviveAd = false;
      _reviveSnapshot = null;
      _gameTrackStarted = false;
      _chartElapsedMs = 0;
      _resetChartSchedule();
      _lives = _maxLivesForDifficulty;
      if (_difficulty == 'easy') {
        _speedMultiplier = 0.8;
      } else if (_difficulty == 'hard') {
        _speedMultiplier = 1.4;
      } else {
        _speedMultiplier = 1.1;
      }

      _tiles.clear();
      _particles.clear();
      _floatingTexts.clear();
      _touchBursts.clear();
      _lastElapsed = Duration.zero;
    });
    unawaited(_syncBackgroundTrack(force: true));

    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _gameLoop(double dt) {
    final playArea = _playAreaRect();

    // Tính toán tốc độ chung 1 lần duy nhất bên ngoài vòng lặp
    // Giảm tốc độ tăng (0.00015 thay vì 0.0004) và giới hạn tốc độ tối đa (clamp) để không quá nhanh
    final currentSpeed = _chartScrollSpeed();
    final dtMs = dt * (1000 / 60);

    _chartElapsedMs += dtMs;
    _spawnChartTiles(playArea);
    if (_updateTransientObjects(dt, currentSpeed, playArea)) {
      _playfieldFrame.value++;
      _hudFrame.value++;
    }
    if (!_gameTrackStarted && _chartElapsedMs >= _chartLeadInMs(playArea)) {
      _gameTrackStarted = true;
      unawaited(_syncBackgroundTrack(force: true));
    }
  }

  bool _updateTransientObjects(double dt, double currentSpeed, Rect playArea) {
    var changed = _tiles.isNotEmpty ||
        _particles.isNotEmpty ||
        _floatingTexts.isNotEmpty ||
        _touchBursts.isNotEmpty;

    for (int i = _tiles.length - 1; i >= 0; i--) {
      final tile = _tiles[i];
      if (tile.isHit) {
        continue;
      }
      tile.y += currentSpeed * dt;
      if (tile.y > playArea.height) {
        _tiles.removeAt(i);
        _registerMiss(playArea: playArea, notify: false);
      }
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 0.2 * dt;
      p.life -= dt;
      if (p.life <= 0) {
        _particles.removeAt(i);
      }
    }

    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final ft = _floatingTexts[i];
      ft.y -= 1.5 * dt;
      ft.life -= dt;
      if (ft.life <= 0) {
        _floatingTexts.removeAt(i);
      }
    }

    for (int i = _touchBursts.length - 1; i >= 0; i--) {
      final burst = _touchBursts[i];
      burst.radius += (burst.strong ? 5.0 : 3.0) * dt;
      burst.life -= dt;
      if (burst.life <= 0) {
        _touchBursts.removeAt(i);
      }
    }

    return changed;
  }

  void _spawnTouchBurst(
    double x,
    double y,
    Color color, {
    bool strong = false,
  }) {
    final maxBursts = _isHighGraphics ? 18 : (_isLowGraphics ? 8 : 12);
    _trimTouchBursts(maxBursts);
    _touchBursts.add(
      TouchBurst(
        x: x,
        y: y,
        radius:
            strong ? (_isLowGraphics ? 27 : 34) : (_isLowGraphics ? 14 : 18),
        life: strong ? (_isLowGraphics ? 18 : 25) : (_isLowGraphics ? 12 : 16),
        color: color,
        strong: strong,
      ),
    );
    if (strong && !_isLowGraphics) {
      _touchBursts.add(
        TouchBurst(
          x: x,
          y: y,
          radius: _isHighGraphics ? 18 : 16,
          life: _isHighGraphics ? 22 : 19,
          color: Colors.white.withValues(alpha: _isHighGraphics ? 0.55 : 0.42),
          strong: false,
        ),
      );
      if (_isHighGraphics) {
        _touchBursts.add(
          TouchBurst(
            x: x,
            y: y,
            radius: 11,
            life: 14,
            color: const Color(0xFF00E5FF).withValues(alpha: 0.42),
            strong: false,
          ),
        );
      }
    }
  }

  void _spawnHitEffects(double x, double y, Color color, bool isPerfect) {
    final accuracyAccent = isPerfect && (_combo + 1) % 8 == 0;
    final count = switch (_graphicsProfile) {
      'high' => accuracyAccent ? 42 : (isPerfect ? 34 : 20),
      'low' => isPerfect ? 14 : 9,
      _ => accuracyAccent ? 30 : (isPerfect ? 24 : 15),
    };
    final maxParticles = _isHighGraphics ? 180 : (_isLowGraphics ? 80 : 120);
    _trimParticles(maxParticles);
    for (int i = 0; i < count; i++) {
      final ringParticle = isPerfect && !_isLowGraphics && i < 8;
      final double angle =
          ringParticle ? (i / 8) * 2 * pi : _random.nextDouble() * 2 * pi;
      final double speed = ringParticle
          ? (_isHighGraphics ? 13.0 : 10.5)
          : _random.nextDouble() *
              (isPerfect
                  ? (_isLowGraphics ? 11.0 : 16.0)
                  : (_isLowGraphics ? 6.0 : 9.0));
      _particles.add(Particle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: ringParticle ? Colors.white : color,
        life: ringParticle
            ? (_isHighGraphics ? 30.0 : 24.0)
            : (_isLowGraphics ? 16.0 : 25.0) +
                _random.nextDouble() * (_isLowGraphics ? 14.0 : 25.0),
      ));
    }

    _trimFloatingTexts(14);
    _floatingTexts.add(FloatingText(
      x: x,
      y: y - 20,
      text: isPerfect ? 'PERFECT!' : 'GOOD',
      color: isPerfect ? const Color(0xFF00E5FF) : Colors.white,
      life: isPerfect ? 42.0 : 34.0,
    ));
    _spawnTouchBurst(
      x,
      y,
      isPerfect ? Colors.white : color,
      strong: isPerfect,
    );
  }

  void _handleTapDown(TapDownDetails details) {
    if (_gameState != 'PLAYING' || _isPaused) return;

    final playArea = _playAreaRect();
    final hitLineY = _hitLineY(playArea);
    final x = details.localPosition.dx;
    final y = details.localPosition.dy;

    Tile? targetTile;
    double bestScore = double.infinity;

    for (int i = 0; i < _tiles.length; i++) {
      final tile = _tiles[i];
      if (!tile.isHit) {
        final withinX = x >= tile.x - 30 && x <= tile.x + tile.width + 30;
        if (!withinX) {
          continue;
        }

        final withinY = y >= tile.y - 32 && y <= tile.y + tile.height + 32;
        final distanceToHitLine = ((tile.y + tile.height) - hitLineY).abs();
        final inHitWindow = distanceToHitLine <= max(62.0, tile.height * 0.28);
        if (withinY || inHitWindow) {
          final centerPenalty = ((tile.x + (tile.width / 2)) - x).abs() * 0.35;
          final verticalPenalty =
              withinY ? (y - (tile.y + tile.height * 0.78)).abs() * 0.12 : 16.0;
          final candidateScore =
              distanceToHitLine + centerPenalty + verticalPenalty;
          if (candidateScore < bestScore) {
            bestScore = candidateScore;
            targetTile = tile;
          }
        }
      }
    }

    if (targetTile != null) {
      final targetBottom = targetTile.y + targetTile.height;
      final isPerfect = (targetBottom - hitLineY).abs() <= 28;
      final hitY = y.clamp(
        targetTile.y + 18,
        min(targetTile.y + targetTile.height - 18, hitLineY + 14),
      );
      _hitTile(targetTile, isPerfect, x, hitY.toDouble());
    } else {
      setState(() {
        _spawnTouchBurst(x, y, Colors.white24);
      });
      _registerMiss();
    }
  }

  void _hitTile(Tile tile, bool isPerfect, double hitX, double hitY) {
    _playHitFeedback(isPerfect);

    setState(() {
      tile.isHit = true;
      _hits++;

      int baseScore = isPerfect ? 120 : 70;
      double mult = 1.0 + min(4.0, _combo * 0.1);
      _score += (baseScore * mult).floor();

      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      if (isPerfect) _perfects++;

      _spawnHitEffects(hitX, hitY, tile.color, isPerfect);
      _tiles.remove(tile);
    });
  }

  void _registerMiss({Rect? playArea, bool notify = true}) {
    final resolvedPlayArea = playArea ?? _playAreaRect();
    _playMissFeedback();
    void applyMiss() {
      _combo = 0;
      _misses++;
      _lives--;

      _trimFloatingTexts(14);
      _floatingTexts.add(FloatingText(
        x: resolvedPlayArea.width / 2,
        y: resolvedPlayArea.height * 0.5,
        text: 'MISS!',
        color: const Color(0xFFFF0055),
        life: 28.0,
      ));
      _spawnTouchBurst(
        resolvedPlayArea.width / 2,
        resolvedPlayArea.height * 0.54,
        const Color(0xFFFF0055)
            .withValues(alpha: _isLowGraphics ? 0.34 : 0.46),
      );

      if (_lives <= 0) {
        _gameOver();
      }
    }

    if (notify) {
      setState(applyMiss);
      return;
    }
    applyMiss();
  }

  List<Tile> _cloneActiveTiles(Iterable<Tile> tiles) {
    return tiles
        .where((tile) => !tile.isHit)
        .map(
          (tile) => Tile(
            x: tile.x,
            y: tile.y,
            width: tile.width,
            height: tile.height,
            color: tile.color,
          ),
        )
        .toList(growable: false);
  }

  void _captureReviveSnapshot() {
    _reviveSnapshot = _SoulRhythmReviveSnapshot(
      score: _score,
      combo: _combo,
      maxCombo: _maxCombo,
      perfects: _perfects,
      misses: _misses,
      hits: _hits,
      speedMultiplier: _speedMultiplier,
      chartElapsedMs: _chartElapsedMs,
      chartEventIndex: _chartEventIndex,
      chartLoopIndex: _chartLoopIndex,
      nextChartEventMs: _nextChartEventMs,
      gameTrackStarted: _gameTrackStarted,
      tiles: _cloneActiveTiles(_tiles),
    );
  }

  void _gameOver() {
    if (_gameState != 'PLAYING') {
      return;
    }
    _captureReviveSnapshot();
    _stateGeneration++;
    _cancelReviveCountdown();
    _cancelGameOverReveal();
    _gameState = 'ENDING';
    _gameTrackStarted = false;
    _isPaused = false;
    _newBestAchieved = _score > _highScore;
    if (_newBestAchieved) {
      _saveHighScore(_score);
      _highScore = _score;
    }
    _showReviveOffer = false;
    _isWatchingReviveAd = false;

    if (_ticker.isActive) {
      _ticker.stop();
    }
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    final generation = _stateGeneration;
    _gameOverRevealTimer = Timer(_gameOverRevealDelay, () {
      if (!mounted ||
          generation != _stateGeneration ||
          _gameState != 'ENDING') {
        return;
      }
      setState(() {
        _gameState = 'OVER';
        _showReviveOffer = !_reviveUsed;
      });
    });
    unawaited(_syncBackgroundTrack(force: true));
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      unawaited(_bgPlayer.pause());
      return;
    }
    if (_gameState == 'PLAYING' && _musicAutoplayEnabled) {
      unawaited(_syncBackgroundTrack(force: true));
    }
  }

  Future<void> _watchReviveAd() async {
    if (_isWatchingReviveAd || !_showReviveOffer || _reviveUsed) {
      return;
    }
    setState(() {
      _isWatchingReviveAd = true;
    });

    final isPro = await _adMob.isProUser();
    if (isPro) {
      if (!mounted) return;
      _revivePlayer();
      setState(() {
        _isWatchingReviveAd = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.tr('util_cquynprohi_0db3f1')),
          backgroundColor: const Color(0xFFE040FB),
        ),
      );
      return;
    }

    final worked = await _adMob.showSoulGameRewardedAd();
    if (!mounted) {
      return;
    }
    if (!worked) {
      setState(() {
        _isWatchingReviveAd = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.tr('util_chaticqung_d632bb')),
        ),
      );
      return;
    }
    _revivePlayer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('util_hisinhthnh_a10f6b')),
      ),
    );
  }

  void _revivePlayer() {
    final playArea = _playAreaRect();
    final hitLineY = _hitLineY(playArea);
    final snapshot = _reviveSnapshot;
    _stateGeneration++;
    _cancelReviveCountdown();
    _cancelGameOverReveal();
    HapticFeedback.mediumImpact();
    unawaited(_playSfx(_perfectTapBytes, volume: 0.86));
    if (!_touchSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    setState(() {
      _reviveUsed = true;
      _showReviveOffer = false;
      _isWatchingReviveAd = false;
      _newBestAchieved = false;
      _gameState = 'PLAYING';
      _isPaused = false;

      if (snapshot != null) {
        _score = snapshot.score;
        _combo = snapshot.combo;
        _maxCombo = snapshot.maxCombo;
        _perfects = snapshot.perfects;
        _misses = snapshot.misses;
        _hits = snapshot.hits;
        _speedMultiplier = snapshot.speedMultiplier;
        _chartElapsedMs = snapshot.chartElapsedMs;
        _chartEventIndex = snapshot.chartEventIndex;
        _chartLoopIndex = snapshot.chartLoopIndex;
        _nextChartEventMs = snapshot.nextChartEventMs;
        _gameTrackStarted = snapshot.gameTrackStarted;
        _tiles
          ..clear()
          ..addAll(_cloneActiveTiles(snapshot.tiles));
      }

      _lives = _maxLivesForDifficulty;
      _tiles.removeWhere((tile) => tile.y + tile.height >= hitLineY - 34);
      _floatingTexts.clear();
      _floatingTexts.add(
        FloatingText(
          x: playArea.width / 2,
          y: hitLineY - 88,
          text: 'REVIVE!',
          color: const Color(0xFFFFEB3B),
          life: 48.0,
        ),
      );
      _spawnTouchBurst(
        playArea.width / 2,
        hitLineY - 26,
        const Color(0xFFFFEB3B),
        strong: true,
      );
      _lastElapsed = Duration.zero;
      _reviveSnapshot = null;
    });
    unawaited(_syncBackgroundTrack(force: true));
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loopDuration = max(1, _gameChartLoopDurationMs).toDouble();
    final nextBeatDelta = max(0.0, _nextChartEventMs - _chartElapsedMs);
    final beatPulse = _gameState == 'PLAYING'
        ? (1.0 - (nextBeatDelta / 360).clamp(0.0, 1.0)).toDouble()
        : _pulseController.value * 0.35;
    double bgPulse = max(min(1.0, _combo / 50.0), beatPulse * 0.58);
    final loopPhase = (_chartElapsedMs % loopDuration) / loopDuration;
    final screenSize = MediaQuery.sizeOf(context);
    final shortestSide = min(screenSize.width, screenSize.height);
    final topOrbSize = shortestSide.clamp(220.0, 300.0).toDouble();
    final bottomOrbSize = (shortestSide * 0.9).clamp(240.0, 350.0).toDouble();
    final playArea = _playAreaRect();
    final playfieldGeometry =
        _buildPlayfieldGeometry(playArea, _hitLineY(playArea));
    final tileGlowBlur =
        _isHighGraphics ? 25.0 : (_isLowGraphics ? 14.0 : 18.0);
    final tileGlowSpread = _isHighGraphics ? 4.0 : (_isLowGraphics ? 1.6 : 2.8);
    final tileShineBlur = _isHighGraphics ? 10.0 : (_isLowGraphics ? 4.0 : 7.0);
    final hitLineBlur = _isHighGraphics ? 20.0 : (_isLowGraphics ? 10.0 : 14.0);

    return PopScope(
      canPop: _gameState == 'MENU',
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_gameState == 'PLAYING' ||
            _gameState == 'ENDING' ||
            _gameState == 'OVER') {
          setState(() {
            _gameState = 'MENU';
            _gameTrackStarted = false;
            if (_ticker.isActive) {
              _ticker.stop();
            }
            _isPaused = false;
          });
          _cancelGameOverReveal();
          unawaited(_syncBackgroundTrack(force: true));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0C29),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(
                        const Color(0xFF0F0C29),
                        Color.lerp(
                          const Color(0xFF240B36),
                          const Color(0xFF1A2A6C),
                          loopPhase,
                        )!,
                        bgPulse,
                      )!,
                      Color.lerp(
                        const Color(0xFF302B63),
                        Color.lerp(
                          const Color(0xFFC31432),
                          const Color(0xFFFFC94D),
                          loopPhase,
                        )!,
                        bgPulse,
                      )!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -(topOrbSize * 0.33),
              left: -(topOrbSize * 0.17),
              child: IgnorePointer(
                child: Container(
                  width: topOrbSize,
                  height: topOrbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF0055)
                            .withValues(alpha: 0.4 + (bgPulse * 0.3)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -(bottomOrbSize * 0.14),
              right: -(bottomOrbSize * 0.29),
              child: IgnorePointer(
                child: Container(
                  width: bottomOrbSize,
                  height: bottomOrbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00E5FF)
                            .withValues(alpha: 0.3 + (bgPulse * 0.3)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.4,
              right: -50,
              child: IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE040FB)
                            .withValues(alpha: 0.3 + (bgPulse * 0.2)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.7,
              left: -50,
              child: IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFEB3B)
                            .withValues(alpha: 0.15 + (bgPulse * 0.2)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GridPainter(opacity: 0.15 + (bgPulse * 0.2)),
                ),
              ),
            ),
            if (_gameState == 'PLAYING' ||
                _gameState == 'ENDING' ||
                _gameState == 'OVER')
              Positioned(
                left: playArea.left,
                top: playArea.top,
                width: playArea.width,
                height: playArea.height,
                child: ValueListenableBuilder<int>(
                  valueListenable: _playfieldFrame,
                  builder: (context, _, __) => GestureDetector(
                    onTapDown: _handleTapDown,
                    behavior: HitTestBehavior.opaque,
                    child: _buildPlayfieldLayers(
                      bgPulse: bgPulse,
                      hitLineBlur: hitLineBlur,
                      tileGlowBlur: tileGlowBlur,
                      tileGlowSpread: tileGlowSpread,
                      tileShineBlur: tileShineBlur,
                      geometry: playfieldGeometry,
                    ),
                  ),
                ),
              ),
            if (_gameState == 'PLAYING') ...[
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 8,
                right: 8,
                child: ValueListenableBuilder<int>(
                  valueListenable: _hudFrame,
                  builder: (context, _, __) => LayoutBuilder(
                    builder: (context, constraints) {
                      final compactHud = constraints.maxWidth < 370;
                      if (compactHud) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: _buildGameplayScorePanel(compact: true),
                              ),
                            ),
                            SLSpacing.w8,
                            _buildMiniBtn(
                              icon: _isPaused ? Icons.play_arrow : Icons.pause,
                              onTap: _togglePause,
                            ),
                            SLSpacing.w8,
                            _buildMiniBtn(
                              icon: Icons.close,
                              onTap: _backToMenu,
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: _buildGameplayScorePanel(),
                          ),
                          const Spacer(),
                          _buildLivesPanel(),
                          SLSpacing.w8,
                          _buildMiniBtn(
                            icon: _isPaused ? Icons.play_arrow : Icons.pause,
                            onTap: _togglePause,
                          ),
                          SLSpacing.w8,
                          _buildMiniBtn(
                            icon: Icons.close,
                            onTap: _backToMenu,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (_combo > 3)
                Positioned(
                  top: playArea.top + 28,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildComboBanner()),
                ),
            ],
            if (_gameState == 'PLAYING')
              Positioned(
                left: playArea.left + 12,
                right: playArea.left + 12,
                top: playArea.top + playArea.height - 48,
                child: Center(child: _buildStageHint()),
              ),
            if (_gameState == 'MENU') _buildMenuScreen(),
            if (_gameState == 'OVER') _buildGameOverScreen(),
          ],
        ),
      ),
    );
  }
}
