import 'soul_rhythm/soul_rhythm_models.dart';
import 'soul_rhythm/soul_rhythm_painters.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/admob_service.dart';
import '../ui_prefs.dart';
import '../../core/sl_theme.dart';
import 'soul_rhythm_music_config.dart';
import '../../utils/services/game_download_service.dart';

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
        } catch (error, stackTrace) {
          debugPrint('Soul Rhythm icon precache failed: $error');
          debugPrintStack(stackTrace: stackTrace);
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
    } catch (error, stackTrace) {
      debugPrint('Soul Rhythm audio init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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
                top: MediaQuery.of(context).padding.top + 8,
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
