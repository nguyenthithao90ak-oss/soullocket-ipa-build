import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sl_theme.dart';
import '../../services/admob_service.dart';
import '../../services/house_service.dart';
import '../premium/premium_store_screen.dart';
import '../../utils/services/game_download_service.dart';

part 'soul_block/soul_block_panels.dart';
part 'soul_block/soul_block_refined_panels.dart';
part 'soul_block/soul_block_bootstrap.dart';
part 'soul_block/soul_block_board.dart';
part 'soul_block/soul_block_feedback_section.dart';
part 'soul_block/soul_block_models.dart';
part 'soul_block/soul_block_menu_widgets.dart';
part 'soul_block/soul_block_panel_section.dart';
part 'soul_block/soul_block_strategy_logic.dart';

enum _SoulGameView {
  splash,
  menu,
  gameplay,
}

class SoulBlockGame extends StatefulWidget {
  const SoulBlockGame({
    super.key,
    this.storageKeyPrefix = 'soul_block',
    this.gameTitle = 'SOUL BLOCK',
    this.loadErrorMessage = 'Không thể khởi động Soul Block lúc này.',
  });

  final String storageKeyPrefix;
  final String gameTitle;
  final String loadErrorMessage;

  @override
  State<SoulBlockGame> createState() => _SoulBlockGameState();
}

class _SoulBlockGameState extends State<SoulBlockGame>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        _SoulBlockStrategyLogic {
  static const int _boardSize = 8;
  static const double _boardGap = 1.8;
  static const double _boardPanelPadding = 10;
  static const double _boardLayoutSafetyInset = 12.0;
  static const double _bannerDockBaseHeight = 54.0;
  static const double _memoryBurstCardAspectRatio = 0.9;
  static const double _dragLiftOffset = 12;
  static const int _trayPreviewGridSize = 5;
  static const double _dragUpdateEpsilon = 0.5;
  static const double _dragOverlayUpdateEpsilon = 1.6;
  static const Duration _autoTrayShuffleInterval = Duration(seconds: 30);
  static const Duration _autoTrayShuffleRetryDelay = Duration(seconds: 3);

  String get _bestScoreKey => '${widget.storageKeyPrefix}_best_score';
  String get _soundEnabledKey => '${widget.storageKeyPrefix}_sound_enabled';
  String get _vibrationEnabledKey =>
      '${widget.storageKeyPrefix}_vibration_enabled';
  String get _leaderboardKey =>
      '${widget.storageKeyPrefix}_local_leaderboard_v2';
  String get _autoTrayShuffleEnabledKey =>
      '${widget.storageKeyPrefix}_auto_tray_shuffle_enabled';
  String get _savedRunKey => '${widget.storageKeyPrefix}_saved_run_v1';
  @override
  int get _strategyBoardSize => _boardSize;

  final HouseService _houseService = HouseService();
  final AdMobService _adMob = AdMobService();
  @override
  final Random _random = Random();
  final GlobalKey _boardKey = GlobalKey();
  final ValueNotifier<int> _dragVisualTick = ValueNotifier<int>(0);
  final ValueNotifier<int> _trayVisualTick = ValueNotifier<int>(0);
  final ValueNotifier<int> _dragOverlayTick = ValueNotifier<int>(0);

  late final Future<SharedPreferences> _prefsFuture;

  late final List<AudioPlayer> _sfxPlayers;
  late final AudioPlayer _bgmPlayer;
  late final AnimationController _playPulseController;
  late final AnimationController _shakeController;
  late final AnimationController _flashController;
  late final AnimationController _floatingController;
  late final AnimationController _explosionController;
  late final AnimationController _memoryBurstController;

  late List<List<_SoulTile?>> _board;
  List<_SoulPieceOption> _tray = <_SoulPieceOption>[];
  List<_LeaderboardEntry> _leaderboard = <_LeaderboardEntry>[];

  _SoulGameView _view = _SoulGameView.splash;
  _RecommendedMove? _recommendedMove;
  _PreparedSoulRun? _preparedMenuRun;
  _SoulPieceOption? _draggingPiece;
  _SoulBlockPerformanceProfile _performanceProfile =
      _SoulBlockPerformanceProfile.mid;
  BannerAd? _bannerAd;

  String? _houseId;
  String? _loadError;
  String? _floatingText;

  Set<int> _clearingRows = <int>{};
  Set<int> _clearingCols = <int>{};

  Offset _dragPosition = Offset.zero;
  Offset _boardOrigin = Offset.zero;
  List<List<bool>>? _dragBoardMask;
  ({Color tone, Set<int> templateCells})? _dragPieceRenderCache;
  Set<int>? _dragPreviewFootprintKeys;
  Widget? _draggedPieceOverlay;
  double _dragOverlayWidth = 0;
  double _dragOverlayHeight = 0;
  Color _floatingTextColor = const Color(0xFFFFCC00);

  List<_ExplosionParticle> _explosionParticles = <_ExplosionParticle>[];
  List<String> _memoryBurstGallery = <String>[];
  final Set<String> _memoryBurstWarmUrls = <String>{};
  final Map<String, double> _memoryBurstAspectRatios = <String, double>{};
  Offset _explosionCenter = Offset.zero;
  Color _explosionAccent = const Color(0xFFFFCC00);
  _MemoryBurstSnapshot? _memoryBurstSnapshot;
  int? _snapBackPieceId;

  @override
  int _pieceSequence = 0;
  int _score = 0;
  int _bestScore = 0;
  @override
  int _combo = 0;
  int _streak = 0;
  @override
  int _turn = 0;
  @override
  int _clearedLines = 0;
  int _scorePulseTick = 0;
  int _previewRow = -1;
  int _previewCol = -1;
  int _currentSessionId = 0;
  int _sfxPlayerIndex = 0;
  int? _pausedAtMs;
  DateTime? _autoTrayShuffleNextAt;

  double _boardCellExtent = 0;
  double _boardContentInset = 0;

  Uint8List? _tapSfxBytes;
  Uint8List? _liftSfxBytes;
  Uint8List? _placeSfxBytes;
  Uint8List? _clearSfxBytes;
  Uint8List? _streakSfxBytes;
  Uint8List? _bestScoreSfxBytes;
  Uint8List? _memoryBurstSfxBytes;
  List<Uint8List> _comboSfxLevels = <Uint8List>[];

  bool _audioReady = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isBusy = false;
  bool _isGameOver = false;
  bool _continueUsedThisRun = false;
  bool _isReviving = false;
  bool _isRestarting = false;
  bool _isShowingFullscreenAd = false;
  bool _isRefreshingMemoryBurstGallery = false;
  bool _isOpeningGameplay = false;
  bool _autoTrayShuffleEnabled = false;
  bool _isPremiumUser = false;

  Timer? _autoTrayShuffleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefsFuture = SharedPreferences.getInstance();
    _board = _createEmptyBoard();
    _sfxPlayers = List<AudioPlayer>.generate(
      4,
      (int index) => AudioPlayer(playerId: 'soul_block_sfx_$index'),
    );
    _bgmPlayer = AudioPlayer(playerId: 'soul_block_bgm');

    _playPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 960),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _floatingText = null);
        }
      });

    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _explosionParticles = <_ExplosionParticle>[];
            _explosionCenter = Offset.zero;
          });
        }
      });

    _memoryBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1820),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _memoryBurstSnapshot = null);
        }
      });

    unawaited(_initAudio());
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTrayShuffleTimer?.cancel();
    _dragVisualTick.dispose();
    _trayVisualTick.dispose();
    _dragOverlayTick.dispose();
    _bannerAd?.dispose();
    _playPulseController.dispose();
    _shakeController.dispose();
    _flashController.dispose();
    _floatingController.dispose();
    _explosionController.dispose();
    _memoryBurstController.dispose();
    for (final AudioPlayer player in _sfxPlayers) {
      player.dispose();
    }
    _bgmPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pausedAtMs = DateTime.now().millisecondsSinceEpoch;
      _autoTrayShuffleTimer?.cancel();
      unawaited(_bgmPlayer.pause());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final pausedAtMs = _pausedAtMs;
      _pausedAtMs = null;
      unawaited(_syncBgmWithSound(restartIfStopped: true));
      unawaited(_refreshPremiumStatus());
      _syncAutoTrayShuffleTimer();
      if (pausedAtMs == null) {
        return;
      }
      unawaited(_maybeShowResumeInterstitial(pausedAtMs));
    }
  }

  Future<void> _maybeShowResumeInterstitial(int pausedAtMs) async {
    if (_view != _SoulGameView.gameplay ||
        _isGameOver ||
        _isShowingFullscreenAd ||
        _draggingPiece != null) {
      return;
    }

    final pausedFor = DateTime.now().millisecondsSinceEpoch - pausedAtMs;
    if (pausedFor < const Duration(minutes: 2).inMilliseconds) {
      return;
    }
    if (_random.nextDouble() > 0.33) {
      return;
    }

    _isShowingFullscreenAd = true;
    try {
      await _adMob.showInterstitialAd();
    } finally {
      _isShowingFullscreenAd = false;
    }
  }

  Future<void> _openPremiumStore() async {
    _emitClickFeedback();
    final houseId = _houseId ?? await _houseService.getCurrentHouseId() ?? '';
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumStoreScreen(
          houseId: houseId,
          myName: 'Bạn',
        ),
      ),
    );

    await _syncBannerAfterPremium();
  }

  Future<void> _persistSetting(String key, bool value) async {
    final prefs = await _prefsFuture;
    await prefs.setBool(key, value);
  }

  Future<void> _setSoundEnabled(bool value) async {
    setState(() {
      _soundEnabled = value;
    });
    await _persistSetting(_soundEnabledKey, value);
    await _syncBgmWithSound();
    if (value) {
      _emitClickFeedback();
    }
  }

  Future<void> _setVibrationEnabled(bool value) async {
    setState(() {
      _vibrationEnabled = value;
    });
    await _persistSetting(_vibrationEnabledKey, value);
    if (value) {
      HapticFeedback.selectionClick();
    }
  }

  bool get _canRunAutoTrayShuffle =>
      _autoTrayShuffleEnabled &&
      _isPremiumUser &&
      _view == _SoulGameView.gameplay &&
      !_isGameOver;

  void _syncAutoTrayShuffleTimer({bool resetWindow = false}) {
    _autoTrayShuffleTimer?.cancel();
    _autoTrayShuffleTimer = null;

    if (!_canRunAutoTrayShuffle) {
      _autoTrayShuffleNextAt = null;
      return;
    }

    final DateTime now = DateTime.now();
    if (resetWindow || _autoTrayShuffleNextAt == null) {
      _autoTrayShuffleNextAt = now.add(_autoTrayShuffleInterval);
    }

    final Duration delay = _autoTrayShuffleNextAt!.difference(now);
    _autoTrayShuffleTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_handleAutoTrayShuffleTick()),
    );
  }

  Future<void> _handleAutoTrayShuffleTick() async {
    _autoTrayShuffleTimer = null;

    if (!_canRunAutoTrayShuffle) {
      _autoTrayShuffleNextAt = null;
      return;
    }

    if (_isBusy ||
        _draggingPiece != null ||
        _isReviving ||
        _isRestarting ||
        _isShowingFullscreenAd) {
      _autoTrayShuffleNextAt = DateTime.now().add(_autoTrayShuffleRetryDelay);
      _syncAutoTrayShuffleTimer();
      return;
    }

    _rerollRandomTrayPieces(automatic: true);
    _autoTrayShuffleNextAt = DateTime.now().add(_autoTrayShuffleInterval);
    _syncAutoTrayShuffleTimer();
  }

  bool _rerollRandomTrayPieces({required bool automatic}) {
    if (_tray.isEmpty || _isGameOver || _isBusy || _draggingPiece != null) {
      return false;
    }

    final int trayLength = _tray.length;
    final int replacementCount =
        trayLength == 1 ? 1 : min(trayLength, 1 + _random.nextInt(2));
    final List<int> shuffledIndices =
        List<int>.generate(trayLength, (int index) => index)..shuffle(_random);
    final List<_SoulPieceOption> replacementPool = _buildSmartBatch(_board);
    if (replacementPool.isEmpty) {
      return false;
    }

    var nextTray = List<_SoulPieceOption>.from(_tray);
    for (var index = 0; index < replacementCount; index++) {
      nextTray[shuffledIndices[index]] =
          replacementPool[index % replacementPool.length];
    }

    var nextRecommended = _recommendMoveFor(_board, nextTray);
    if (nextRecommended == null) {
      nextTray =
          _buildSmartBatch(_board).take(trayLength).toList(growable: false);
      if (nextTray.length != trayLength) {
        return false;
      }
      nextRecommended = _recommendMoveFor(_board, nextTray);
      if (nextRecommended == null) {
        return false;
      }
    }

    setState(() {
      _tray = nextTray;
      _recommendedMove = nextRecommended;
    });

    _showFloatingMessage(
      automatic
          ? 'T\u1ef1 \u0111\u1ed9ng \u0111\u1ed5i $replacementCount kh\u1ed1i'
          : '\u0110\u00e3 \u0111\u1ed5i $replacementCount kh\u1ed1i',
      color: automatic ? const Color(0xFF7AE7FF) : const Color(0xFFFFD166),
    );
    return true;
  }

  void _markDragVisualDirty() {
    _dragVisualTick.value = _dragVisualTick.value + 1;
  }

  void _markTrayVisualDirty() {
    _trayVisualTick.value = _trayVisualTick.value + 1;
  }

  void _markDragOverlayDirty() {
    _dragOverlayTick.value = _dragOverlayTick.value + 1;
  }

  void _pauseMenuPulse() {
    if (_playPulseController.isAnimating) {
      _playPulseController.stop();
    }
  }

  void _resumeMenuPulse() {
    if (!_playPulseController.isAnimating) {
      _playPulseController.repeat(reverse: true);
    }
  }

  void _clearDragVisualState({bool notify = true}) {
    final bool hadDragVisualState = _draggingPiece != null ||
        _previewRow != -1 ||
        _previewCol != -1 ||
        _dragBoardMask != null;
    _draggingPiece = null;
    _previewRow = -1;
    _previewCol = -1;
    _dragBoardMask = null;
    _dragPieceRenderCache = null;
    _dragPreviewFootprintKeys = null;
    _draggedPieceOverlay = null;
    _dragOverlayWidth = 0;
    _dragOverlayHeight = 0;
    if (notify && hadDragVisualState) {
      _markDragVisualDirty();
      _markTrayVisualDirty();
      _markDragOverlayDirty();
    }
  }

  void _returnToMenuFromSettings() {
    _emitClickFeedback();
    setState(() {
      _clearDragVisualState(notify: false);
      _isBusy = false;
      _isGameOver = false;
      _isReviving = false;
      _isRestarting = false;
      _memoryBurstSnapshot = null;
      _explosionParticles = <_ExplosionParticle>[];
      _floatingText = null;
      _snapBackPieceId = null;
      _view = _SoulGameView.menu;
    });
    _resumeMenuPulse();
    _syncAutoTrayShuffleTimer();
    _markDragVisualDirty();
    _scheduleMenuRunWarmup();
  }

  void _restartCurrentRunFromSettings() {
    if (_isRestarting || _isOpeningGameplay) {
      return;
    }
    _emitClickFeedback();
    if (_view == _SoulGameView.menu) {
      _resumeMenuPulse();
      unawaited(_startSessionFromMenu());
      return;
    }
    setState(() {
      _isRestarting = true;
      _clearDragVisualState(notify: false);
    });
    _markDragVisualDirty();
    _startNewGame(openGameplay: true);
  }

  Future<void> _exitToHomeFromSettings() async {
    _emitClickFeedback();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).maybePop();
  }

  Future<void> _startSessionFromMenu() async {
    if (_isOpeningGameplay || _view != _SoulGameView.menu) {
      return;
    }
    _emitClickFeedback();
    setState(() {
      _isOpeningGameplay = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    final _PreparedSoulRun? preparedRun = _preparedMenuRun;
    _preparedMenuRun = null;
    _startNewGame(
      openGameplay: true,
      preparedRun: preparedRun,
    );
  }

  List<_SoulPieceOption> _buildOpeningTray(List<List<_SoulTile?>> board) {
    final List<_SoulPieceOption> tray = _buildSmartBatch(board);
    final List<_SoulPieceTemplate> curatedTemplates =
        <_SoulPieceTemplate>[
      _kSoulBlockTemplates.firstWhere((template) => template.id == 'duo_h'),
      _kSoulBlockTemplates.firstWhere((template) => template.id == 'duo_v'),
      _kSoulBlockTemplates.firstWhere((template) => template.id == 'square_2'),
    ];

    final List<_SoulPieceOption> curated = <_SoulPieceOption>[];
    for (final template in curatedTemplates) {
      final _SoulPieceOption? option = tray.firstWhere(
        (_SoulPieceOption item) => item.template.id == template.id,
        orElse: () => _spawnPieceFromTemplate(template),
      );
      curated.add(option);
    }

    if (curated.any((piece) =>
        _findPlacements(_boardMask(board), piece.template).isEmpty)) {
      return tray.take(3).toList(growable: false);
    }

    return curated;
  }

  _PreparedSoulRun _prepareFreshRun() {
    final nextBoard = _createOpeningBoard();
    final nextTray = _buildOpeningTray(nextBoard);
    return _PreparedSoulRun(
      board: nextBoard,
      tray: nextTray,
      recommendedMove: _recommendMoveFor(nextBoard, nextTray),
      sessionId: DateTime.now().microsecondsSinceEpoch,
    );
  }

  void _scheduleMenuRunWarmup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _view != _SoulGameView.menu ||
          _preparedMenuRun != null ||
          _loadError != null) {
        return;
      }
      final _PreparedSoulRun preparedMenuRun = _prepareFreshRun();
      if (!mounted || _view != _SoulGameView.menu) {
        return;
      }
      setState(() {
        _preparedMenuRun = preparedMenuRun;
      });
    });
  }

  void _startNewGame({
    required bool openGameplay,
    _PreparedSoulRun? preparedRun,
  }) {
    final _PreparedSoulRun nextRun = preparedRun ?? _prepareFreshRun();
    final bool restoringExistingRun = preparedRun != null;
    _memoryBurstController.stop();
    _explosionController.stop();

    final restoredBoard = _cloneBoard(nextRun.board);
    final restoredTray = List<_SoulPieceOption>.from(nextRun.tray);
    final restoredRecommendedMove =
        _recommendMoveFor(restoredBoard, restoredTray);
    final restoredGameOver = restoredTray.isEmpty ||
        !_hasAnyPlayableMove(restoredBoard, restoredTray);

    setState(() {
      _board = restoredBoard;
      _tray = restoredTray;
      _recommendedMove = restoredRecommendedMove;
      _score = restoringExistingRun ? _score : 0;
      _combo = restoringExistingRun ? _combo : 0;
      _streak = restoringExistingRun ? _streak : 0;
      _turn = restoringExistingRun ? _turn : 0;
      _clearedLines = restoringExistingRun ? _clearedLines : 0;
      _scorePulseTick = 0;
      _currentSessionId = nextRun.sessionId;
      _draggingPiece = null;
      _previewRow = -1;
      _previewCol = -1;
      _dragBoardMask = null;
      _clearingRows = <int>{};
      _clearingCols = <int>{};
      _floatingText = null;
      _memoryBurstSnapshot = null;
      _snapBackPieceId = null;
      _isBusy = false;
      _isGameOver = restoredGameOver;
      _continueUsedThisRun =
          restoringExistingRun ? _continueUsedThisRun : false;
      _isReviving = false;
      _isRestarting = false;
      _isOpeningGameplay = false;
      if (openGameplay) {
        _view = _SoulGameView.gameplay;
      }
    });
    if (openGameplay) {
      _pauseMenuPulse();
    } else {
      _resumeMenuPulse();
    }
    _syncAutoTrayShuffleTimer(resetWindow: openGameplay);
    if (openGameplay) {
      unawaited(_syncBgmWithSound(restartIfStopped: true));
    }

    if (_isGameOver) {
      unawaited(_handleGameOverTransition());
    }
  }

  String _memoryBurstGalleryKeyFor(String? houseId) {
    final normalizedHouseId = houseId?.trim() ?? '';
    return '${widget.storageKeyPrefix}_memory_burst_gallery_$normalizedHouseId';
  }

  _SoulBlockPerformanceProfile _resolvePerformanceProfile() {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final Size logicalSize = mediaQuery?.size ??
        (view == null
            ? const Size(392, 800)
            : view.physicalSize / view.devicePixelRatio);
    final double shortestSide = logicalSize.shortestSide;
    final double devicePixelRatio =
        mediaQuery?.devicePixelRatio ?? view?.devicePixelRatio ?? 1.0;

    if (shortestSide < 360 || devicePixelRatio <= 1.2) {
      return _SoulBlockPerformanceProfile.low;
    }
    if (shortestSide < 430 || devicePixelRatio <= 2.0) {
      return _SoulBlockPerformanceProfile.mid;
    }
    return _SoulBlockPerformanceProfile.high;
  }

  ({int width, int height}) _memoryBurstCacheSize() {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final double devicePixelRatio =
        mediaQuery?.devicePixelRatio ?? view?.devicePixelRatio ?? 1.0;
    final _SoulBlockPerformanceProfile profile = _performanceProfile;
    final double cappedDevicePixelRatio =
        devicePixelRatio.clamp(1.0, profile.maxImageDevicePixelRatio);
    final double logicalWidth =
        min((mediaQuery?.size.width ?? 392.0) * 0.72, 276.0);
    final double logicalHeight = logicalWidth / _memoryBurstCardAspectRatio;
    return (
      width: (logicalWidth * cappedDevicePixelRatio)
          .round()
          .clamp(220, profile.maxImageCacheWidth),
      height: (logicalHeight * cappedDevicePixelRatio)
          .round()
          .clamp(240, profile.maxImageCacheHeight),
    );
  }

  ImageProvider<Object> _memoryBurstImageProvider(String imageUrl) {
    final cacheSize = _memoryBurstCacheSize();
    return CachedNetworkImageProvider(
      imageUrl,
      maxWidth: cacheSize.width,
      maxHeight: cacheSize.height,
    );
  }

  Future<void> _rememberMemoryBurstAspectRatio(String imageUrl) async {
    final String normalizedUrl = imageUrl.trim();
    if (!mounted ||
        normalizedUrl.isEmpty ||
        _memoryBurstAspectRatios.containsKey(normalizedUrl)) {
      return;
    }

    final ImageStream stream = _memoryBurstImageProvider(normalizedUrl).resolve(
      createLocalImageConfiguration(context),
    );
    final Completer<double?> completer = Completer<double?>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo imageInfo, bool _) {
        if (completer.isCompleted) {
          return;
        }
        final double width = imageInfo.image.width.toDouble();
        final double height = imageInfo.image.height.toDouble();
        if (width <= 0 || height <= 0) {
          completer.complete(null);
          return;
        }
        completer.complete(width / height);
      },
      onError: (Object _, StackTrace? __) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    stream.addListener(listener);
    double? aspectRatio;
    try {
      aspectRatio = await completer.future.timeout(
        const Duration(milliseconds: 650),
        onTimeout: () => null,
      );
    } finally {
      stream.removeListener(listener);
    }

    if (!mounted ||
        aspectRatio == null ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0) {
      return;
    }
    _memoryBurstAspectRatios[normalizedUrl] = aspectRatio;
  }

  double _memoryBurstFitWeight(String imageUrl) {
    final double? aspectRatio = _memoryBurstAspectRatios[imageUrl.trim()];
    if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) {
      return 0.55;
    }

    final double diff = (aspectRatio - _memoryBurstCardAspectRatio).abs();
    double weight = 1.0 - (diff * 1.7);
    if (aspectRatio < 0.68) {
      weight -= (0.68 - aspectRatio) * 2.6;
    }
    if (aspectRatio > 1.28) {
      weight -= (aspectRatio - 1.28) * 1.1;
    }
    return weight.clamp(0.08, 1.0).toDouble();
  }

  String _pickMemoryBurstImage(List<String> selectionPool) {
    if (selectionPool.length <= 1) {
      return selectionPool.first;
    }

    final List<({String url, double weight})> weightedPool = selectionPool
        .map(
          (String url) => (url: url, weight: _memoryBurstFitWeight(url)),
        )
        .toList(growable: false);
    final double totalWeight = weightedPool.fold<double>(
      0,
      (double sum, ({String url, double weight}) item) => sum + item.weight,
    );
    if (totalWeight <= 0) {
      return selectionPool[_random.nextInt(selectionPool.length)];
    }

    double cursor = _random.nextDouble() * totalWeight;
    for (final ({String url, double weight}) item in weightedPool) {
      cursor -= item.weight;
      if (cursor <= 0) {
        return item.url;
      }
    }
    return weightedPool.last.url;
  }

  Future<void> _warmMemoryBurstImages(
    Iterable<String> urls, {
    int limit = 4,
  }) async {
    if (!mounted || limit <= 0) {
      return;
    }

    var warmedCount = 0;
    for (final String rawUrl in urls) {
      final String normalizedUrl = rawUrl.trim();
      if (normalizedUrl.isEmpty ||
          _memoryBurstWarmUrls.contains(normalizedUrl)) {
        continue;
      }

      try {
        await precacheImage(
          _memoryBurstImageProvider(normalizedUrl),
          context,
        );
      } catch (_) {
        continue;
      }

      if (!mounted) {
        return;
      }

      await _rememberMemoryBurstAspectRatio(normalizedUrl);
      if (!mounted) {
        return;
      }
      _memoryBurstWarmUrls.add(normalizedUrl);
      warmedCount += 1;
      if (warmedCount >= limit) {
        return;
      }
    }
  }

  List<String> _decodeMemoryBurstGallery(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>[];
      }
      final urls = <String>[];
      final seen = <String>{};
      for (final Object? item in decoded) {
        final String normalized = (item as String? ?? '').trim();
        if (normalized.isEmpty || !seen.add(normalized)) {
          continue;
        }
        urls.add(normalized);
      }
      return urls;
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _refreshMemoryBurstGallery(String houseId) async {
    final String normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty || _isRefreshingMemoryBurstGallery) {
      return;
    }

    _isRefreshingMemoryBurstGallery = true;
    try {
      final DatabaseReference baseRef =
          FirebaseDatabase.instance.ref('houses/$normalizedHouseId');
      final DataSnapshot memoriesSnapshot =
          await baseRef.child('memories').limitToLast(48).get();
      final List<String> nextGallery =
          _extractMediaUrls(memoriesSnapshot.value);
      final Set<String> seenUrls = nextGallery.toSet();

      if (nextGallery.length < 8) {
        final DataSnapshot albumSnapshot =
            await baseRef.child('album').limitToLast(48).get();
        for (final String url in _extractMediaUrls(albumSnapshot.value)) {
          if (seenUrls.add(url)) {
            nextGallery.add(url);
          }
          if (nextGallery.length >= 18) {
            break;
          }
        }
      }

      if (nextGallery.isEmpty) {
        return;
      }

      final SharedPreferences prefs = await _prefsFuture;
      await prefs.setString(
        _memoryBurstGalleryKeyFor(normalizedHouseId),
        jsonEncode(nextGallery),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _memoryBurstGallery = nextGallery;
        _memoryBurstAspectRatios
            .removeWhere((String url, _) => !seenUrls.contains(url));
      });
      unawaited(
        _warmMemoryBurstImages(
          nextGallery,
          limit: _performanceProfile.memoryBurstWarmLimit,
        ),
      );
    } catch (error) {
      debugPrint('Soul Block memory burst gallery load failed: $error');
    } finally {
      _isRefreshingMemoryBurstGallery = false;
    }
  }

  List<String> _extractMediaUrls(Object? rawSource) {
    if (rawSource is! Map) {
      return <String>[];
    }

    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(rawSource);
    data.forEach((dynamic key, dynamic value) {
      if (value is! Map) {
        return;
      }
      final Map<String, dynamic> item =
          Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
      item['id'] = key.toString();
      entries.add(item);
    });

    entries.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int tsA = (a['ts'] as num?)?.toInt() ?? 0;
      final int tsB = (b['ts'] as num?)?.toInt() ?? 0;
      return tsB.compareTo(tsA);
    });

    final List<String> urls = <String>[];
    final Set<String> seenUrls = <String>{};
    for (final Map<String, dynamic> item in entries) {
      for (final String key in <String>[
        'url',
        'imageUrl',
        'photoUrl',
        'mediaUrl'
      ]) {
        final String url = (item[key] as String? ?? '').trim();
        if (url.isEmpty || !url.startsWith('http') || !seenUrls.add(url)) {
          continue;
        }
        urls.add(url);
        break;
      }
      if (urls.length >= 18) {
        break;
      }
    }
    return urls;
  }

  List<List<_SoulTile?>> _createEmptyBoard() {
    return List<List<_SoulTile?>>.generate(
      _boardSize,
      (_) => List<_SoulTile?>.filled(_boardSize, null),
    );
  }

  List<List<_SoulTile?>> _createOpeningBoard() {
    final List<List<_SoulTile?>> board = _createEmptyBoard();

    void placeCells(
      List<Point<int>> cells,
      int toneIndex,
      int pieceId,
    ) {
      for (final Point<int> cell in cells) {
        board[cell.y][cell.x] = _SoulTile(
          toneIndex: toneIndex,
          pieceId: pieceId,
          placedTurn: 0,
        );
      }
    }

    final List<List<List<Point<int>>>> openingPatterns =
        <List<List<Point<int>>>>[
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(2, 2),
          const Point<int>(3, 2),
        ],
        <Point<int>>[
          const Point<int>(5, 2),
          const Point<int>(5, 3),
        ],
        <Point<int>>[
          const Point<int>(2, 5),
          const Point<int>(3, 5),
        ],
      ],
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(1, 1),
          const Point<int>(2, 1),
          const Point<int>(1, 2),
        ],
        <Point<int>>[
          const Point<int>(5, 1),
          const Point<int>(5, 2),
        ],
        <Point<int>>[
          const Point<int>(3, 5),
          const Point<int>(4, 5),
          const Point<int>(4, 6),
        ],
      ],
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(3, 1),
          const Point<int>(4, 1),
          const Point<int>(3, 2),
        ],
        <Point<int>>[
          const Point<int>(1, 4),
          const Point<int>(2, 4),
        ],
        <Point<int>>[
          const Point<int>(5, 4),
          const Point<int>(5, 5),
        ],
      ],
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(1, 2),
          const Point<int>(2, 2),
        ],
        <Point<int>>[
          const Point<int>(4, 4),
          const Point<int>(5, 4),
          const Point<int>(4, 5),
        ],
        <Point<int>>[
          const Point<int>(2, 6),
          const Point<int>(3, 6),
        ],
      ],
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(2, 1),
          const Point<int>(2, 2),
        ],
        <Point<int>>[
          const Point<int>(4, 2),
          const Point<int>(5, 2),
          const Point<int>(5, 3),
        ],
        <Point<int>>[
          const Point<int>(3, 5),
          const Point<int>(4, 5),
        ],
      ],
    ];

    final List<List<Point<int>>> selectedPattern =
        openingPatterns[_random.nextInt(openingPatterns.length)];
    for (int index = 0; index < selectedPattern.length; index++) {
      placeCells(
        selectedPattern[index],
        index % _kSoulTones.length,
        -(index + 1),
      );
    }

    return board;
  }

  List<List<_SoulTile?>> _cloneBoard(List<List<_SoulTile?>> board) {
    return List<List<_SoulTile?>>.generate(
      _boardSize,
      (int row) => List<_SoulTile?>.from(board[row]),
    );
  }

  void _updateBoardMetrics() {
    final BuildContext? boardContext = _boardKey.currentContext;
    final renderBox = boardContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    _boardOrigin = renderBox.localToGlobal(Offset.zero);
    final double boardExtent = min(renderBox.size.width, renderBox.size.height);
    final double devicePixelRatio =
        MediaQuery.maybeOf(boardContext!)?.devicePixelRatio ?? 1.0;
    _boardCellExtent = _resolveBoardCellExtent(
      boardExtent,
      devicePixelRatio: devicePixelRatio,
    );
    final double innerExtent = boardExtent - (_boardPanelPadding * 2);
    final double contentExtent =
        (_boardCellExtent * _boardSize) + (_boardGap * (_boardSize - 1));
    _boardContentInset = max(0, innerExtent - contentExtent) / 2;
  }

  double _resolveBoardCellExtent(
    double boardExtent, {
    required double devicePixelRatio,
  }) {
    final double usableBoardExtent = boardExtent -
        (_boardPanelPadding * 2) -
        (_boardGap * (_boardSize - 1)) -
        _boardLayoutSafetyInset;
    final double rawExtent = usableBoardExtent / _boardSize;
    if (!rawExtent.isFinite || rawExtent <= 0) {
      return 0;
    }
    final double safeDpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    return ((rawExtent * safeDpr).floorToDouble() / safeDpr)
        .clamp(0.0, rawExtent)
        .toDouble();
  }

  double _dragPieceWidthPixels(_SoulPieceOption piece) {
    final cellFullSize = _boardCellExtent + _boardGap;
    return piece.template.width * cellFullSize - _boardGap;
  }

  double _dragPieceHeightPixels(_SoulPieceOption piece) {
    final cellFullSize = _boardCellExtent + _boardGap;
    return piece.template.height * cellFullSize - _boardGap;
  }

  double _dragPieceTop(double pointerDy, double pieceHeight) {
    return pointerDy - (pieceHeight * 0.5) - _dragLiftOffset;
  }

  double _clampDragPieceLeft(double left, double pieceWidth) {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final double screenWidth = mediaQuery?.size.width ?? double.infinity;
    if (!screenWidth.isFinite || screenWidth <= pieceWidth) {
      return left;
    }
    return left.clamp(0.0, screenWidth - pieceWidth).toDouble();
  }

  double _clampDragPieceTop(double top, double pieceHeight) {
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final double screenHeight = mediaQuery?.size.height ?? double.infinity;
    final double topInset = mediaQuery?.padding.top ?? 0.0;
    final double bottomInset = mediaQuery?.padding.bottom ?? 0.0;
    if (!screenHeight.isFinite || screenHeight <= pieceHeight) {
      return top;
    }
    return top
        .clamp(
            topInset, max(topInset, screenHeight - bottomInset - pieceHeight))
        .toDouble();
  }

  ({double left, double top}) _dragPieceOverlayOffsetFromPosition(
    _SoulPieceOption piece,
    Offset referencePosition,
  ) {
    final double dragWidth = _dragPieceWidthPixels(piece);
    final double dragHeight = _dragPieceHeightPixels(piece);
    final double rawLeft = referencePosition.dx - (dragWidth / 2);
    final double rawTop = _dragPieceTop(referencePosition.dy, dragHeight);
    return (
      left: _clampDragPieceLeft(rawLeft, dragWidth),
      top: _clampDragPieceTop(rawTop, dragHeight),
    );
  }

  Offset _dragReferencePosition(_SoulPieceOption piece, Offset globalPosition) {
    final double dragPieceWidthPixels = _dragPieceWidthPixels(piece);
    final double dragPieceHeightPixels = _dragPieceHeightPixels(piece);
    return Offset(
      globalPosition.dx - (dragPieceWidthPixels / 2),
      _dragPieceTop(globalPosition.dy, dragPieceHeightPixels),
    );
  }

  int _nearestBoardIndex(double relativeOffset, double cellFullSize) {
    return ((relativeOffset + (cellFullSize / 2)) / cellFullSize).floor();
  }

  bool _isInsideBoardBounds(_SoulPieceOption piece, int row, int col) {
    return row >= 0 &&
        col >= 0 &&
        row + piece.template.height <= _boardSize &&
        col + piece.template.width <= _boardSize;
  }

  Offset _boardCellCenter(double row, double col) {
    final cellFullSize = _boardCellExtent + _boardGap;
    return Offset(
      _boardOrigin.dx +
          _boardPanelPadding +
          _boardContentInset +
          (col * cellFullSize) +
          (_boardCellExtent / 2),
      _boardOrigin.dy +
          _boardPanelPadding +
          _boardContentInset +
          (row * cellFullSize) +
          (_boardCellExtent / 2),
    );
  }

  void _startDrag(_SoulPieceOption piece, Offset globalPosition) {
    if (_isGameOver || _isBusy || _view != _SoulGameView.gameplay) {
      return;
    }

    _updateBoardMetrics();
    _dragBoardMask = _boardMask(_board);
    _dragPieceRenderCache = _pieceRenderCache(piece);
    _dragPreviewFootprintKeys = null;
    _dragOverlayWidth = _dragPieceWidthPixels(piece);
    _dragOverlayHeight = _dragPieceHeightPixels(piece);
    _draggedPieceOverlay = _buildDraggedPieceGrid(piece);
    final preview = _resolvePreviewCell(piece, globalPosition);
    _emitLiftFeedback();
    _draggingPiece = piece;
    _dragPosition = globalPosition;
    _previewRow = preview.row;
    _previewCol = preview.col;
    _dragPreviewFootprintKeys =
        _previewFootprintKeys(piece, preview.row, preview.col);
    _markDragVisualDirty();
    _markTrayVisualDirty();
    _markDragOverlayDirty();
  }

  void _updateDrag(Offset globalPosition) {
    final draggingPiece = _draggingPiece;
    if (draggingPiece == null || _isBusy) {
      return;
    }

    final preview = _resolvePreviewCell(draggingPiece, globalPosition);
    final Offset previousPosition = _dragPosition;
    final bool previewChanged =
        preview.row != _previewRow || preview.col != _previewCol;
    final bool movedEnoughForPreview =
        (globalPosition - previousPosition).distanceSquared >=
            (_dragUpdateEpsilon * _dragUpdateEpsilon);
    if (!movedEnoughForPreview && !previewChanged) {
      return;
    }

    _dragPosition = globalPosition;
    _previewRow = preview.row;
    _previewCol = preview.col;
    if (previewChanged) {
      _dragPreviewFootprintKeys =
          _previewFootprintKeys(draggingPiece, preview.row, preview.col);
      _markDragVisualDirty();
    }

    final bool movedEnoughForOverlay =
        (globalPosition - previousPosition).distanceSquared >=
            (_dragOverlayUpdateEpsilon * _dragOverlayUpdateEpsilon);
    if (previewChanged || movedEnoughForOverlay) {
      _markDragOverlayDirty();
    }
  }

  void _cancelDrag() {
    _clearDragVisualState();
  }

  Future<void> _endDrag() async {
    if (_draggingPiece != null && _previewRow >= 0 && _previewCol >= 0) {
      final piece = _draggingPiece!;
      final row = _previewRow;
      final col = _previewCol;
      _clearDragVisualState();
      await _placePieceAt(piece, row, col);
      return;
    }
    final _SoulPieceOption? piece = _draggingPiece;
    _cancelDrag();
    if (piece != null && mounted) {
      setState(() => _snapBackPieceId = piece.id);
      _markTrayVisualDirty();
      await Future<void>.delayed(const Duration(milliseconds: 170));
      if (!mounted || _snapBackPieceId != piece.id) {
        return;
      }
      setState(() => _snapBackPieceId = null);
      _markTrayVisualDirty();
    }
  }

  ({int row, int col}) _resolvePreviewCell(
    _SoulPieceOption piece,
    Offset globalPosition,
  ) {
    if (_boardCellExtent <= 0) {
      return (row: -1, col: -1);
    }

    final cellFullSize = _boardCellExtent + _boardGap;
    final Offset pieceOffset = _dragReferencePosition(piece, globalPosition);

    final relativeX = pieceOffset.dx -
        _boardOrigin.dx -
        _boardPanelPadding -
        _boardContentInset;
    final relativeY = pieceOffset.dy -
        _boardOrigin.dy -
        _boardPanelPadding -
        _boardContentInset;

    final baseCol = _nearestBoardIndex(relativeX, cellFullSize);
    final baseRow = _nearestBoardIndex(relativeY, cellFullSize);
    final boardMask = _dragBoardMask ?? _boardMask(_board);

    bool canPlaceAt(int row, int col) {
      return _isInsideBoardBounds(piece, row, col) &&
          _canPlace(boardMask, piece.template, row, col);
    }

    if (canPlaceAt(baseRow, baseCol)) {
      return (row: baseRow, col: baseCol);
    }

    const neighborOffsets = <({int rowOffset, int colOffset})>[
      (rowOffset: 0, colOffset: -1),
      (rowOffset: 0, colOffset: 1),
      (rowOffset: -1, colOffset: 0),
      (rowOffset: 1, colOffset: 0),
      (rowOffset: -1, colOffset: -1),
      (rowOffset: -1, colOffset: 1),
      (rowOffset: 1, colOffset: -1),
      (rowOffset: 1, colOffset: 1),
    ];

    ({int row, int col})? bestMatch;
    double bestDistance = double.infinity;

    for (final offset in neighborOffsets) {
      final row = baseRow + offset.rowOffset;
      final col = baseCol + offset.colOffset;
      if (!canPlaceAt(row, col)) {
        continue;
      }
      final center = _boardCellCenter(row.toDouble(), col.toDouble());
      final distance = (center - globalPosition).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = (row: row, col: col);
      }
    }

    return bestMatch ?? (row: -1, col: -1);
  }

  Set<int>? _previewFootprintKeys(
    _SoulPieceOption piece,
    int startRow,
    int startCol,
  ) {
    if (startRow < 0 || startCol < 0) {
      return null;
    }
    return piece.template.cells
        .map(
          (Point<int> cell) =>
              _boardCellKey(startRow + cell.y, startCol + cell.x),
        )
        .toSet();
  }

  int _boardCellKey(int row, int col) => (row << 16) ^ (col & 0xFFFF);

  bool _isCellInPreviewFootprint(int row, int col) {
    return _dragPreviewFootprintKeys?.contains(_boardCellKey(row, col)) ??
        false;
  }

  Future<void> _placePieceAt(
    _SoulPieceOption piece,
    int row,
    int col,
  ) async {
    if (_isGameOver || _isBusy) {
      return;
    }

    final boardMask = _boardMask(_board);
    if (!_canPlace(boardMask, piece.template, row, col)) {
      return;
    }

    _isBusy = true;

    final remainingTray = List<_SoulPieceOption>.from(_tray)
      ..removeWhere((item) => item.id == piece.id);
    final placement = _placeTemplate(_board, piece, row, col);
    final placedBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (boardRow) => List<_SoulTile?>.generate(
        _boardSize,
        (boardCol) {
          final _SoulTile? tile = placement.board[boardRow][boardCol];
          if (tile == null || tile.pieceId != piece.id) {
            return tile;
          }
          return _SoulTile(
            toneIndex: tile.toneIndex,
            pieceId: tile.pieceId,
            placedTurn: _turn + 1,
          );
        },
        growable: false,
      ),
      growable: false,
    );
    final clearResolution = _clearAffectedLines(
      placedBoard,
      placement.rowsToClear,
      placement.colsToClear,
    );
    final clearedRows = clearResolution.clearedRows.toList(growable: false);
    final clearedCols = clearResolution.clearedCols.toList(growable: false);
    final clearedNow = clearedRows.length + clearedCols.length;
    final gainedScore = _scoreGainFor(piece.template, clearedNow, _combo);
    final nextScore = _score + gainedScore;
    final nextCombo = clearedNow > 0 ? _combo + 1 : 0;
    final nextStreak = clearedNow > 0 ? _streak + 1 : 0;
    final bool beatBestThisMove =
        _score <= _bestScore && nextScore > _bestScore;

    _emitPlaceFeedback();
    if (clearedNow > 0) {
      _emitClearFeedback(
        clearedCount: clearedNow,
        streakCount: nextStreak,
      );
      _triggerScreenPulse();
      if (clearedNow >= 2) {
        _showComboBurst(clearedNow);
      }
      if (nextStreak >= 2) {
        _showStreakBurst(nextStreak);
      }
    }
    if (beatBestThisMove) {
      _emitBestScoreFeedback();
      _showFloatingMessage(
        'New Best!',
        color: const Color(0xFFFFD166),
      );
    }

    setState(() {
      _board = placedBoard;
      _tray = remainingTray;
      _turn += 1;
      _score = nextScore;
      _combo = nextCombo;
      _streak = nextStreak;
      _scorePulseTick += 1;
      _clearingRows = clearResolution.clearedRows;
      _clearingCols = clearResolution.clearedCols;
    });

    if (clearedNow > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) {
        return;
      }
    }

    final resolvedBoard = clearResolution.board;
    final replenishedTray =
        remainingTray.isEmpty ? _buildFastTray(resolvedBoard) : remainingTray;
    final nextRecommended = _recommendMoveFor(resolvedBoard, replenishedTray);
    final noMovesLeft = replenishedTray.isEmpty ||
        !_hasAnyPlayableMove(resolvedBoard, replenishedTray);

    setState(() {
      _board = resolvedBoard;
      _tray = replenishedTray;
      _recommendedMove = nextRecommended;
      _clearingRows = <int>{};
      _clearingCols = <int>{};
      _clearedLines += clearedNow;
      _isGameOver = noMovesLeft;
      _isBusy = false;
    });

    if (clearedNow > 0) {
      _triggerExplosionEffect(
        clearedCount: clearedNow,
        clearedRows: clearedRows,
        clearedCols: clearedCols,
        subtle: clearedNow == 1,
      );
    } else if (beatBestThisMove) {
      _triggerExplosionEffect(
        clearedCount: 2,
        clearedRows: <int>[row],
        clearedCols: <int>[col],
        subtle: true,
      );
    }
    if (clearedNow >= 2) {
      _triggerMemoryBurstReward(
        clearedCount: clearedNow,
        streakCount: nextStreak,
      );
    }

    if (nextScore > _bestScore) {
      unawaited(_persistBestScore(nextScore));
    }
    unawaited(_persistSavedRun());
    if (noMovesLeft) {
      await _handleGameOverTransition();
    }
  }

  Future<void> _handleGameOverTransition() async {
    _cancelDrag();
    _memoryBurstController.stop();
    _combo = 0;
    _streak = 0;
    await _clearSavedRun();
    await _persistCurrentRunScore();
    _adMob.preloadSoulGameRewardedAd();
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (mounted) {
      setState(() {});
    }
    _syncAutoTrayShuffleTimer();
  }

  void _returnToMenuFromGameOver() {
    _emitClickFeedback();
    unawaited(_clearSavedRun());
    setState(() {
      _draggingPiece = null;
      _previewRow = -1;
      _previewCol = -1;
      _dragBoardMask = null;
      _draggedPieceOverlay = null;
      _isBusy = false;
      _isGameOver = false;
      _isReviving = false;
      _isRestarting = false;
      _memoryBurstSnapshot = null;
      _view = _SoulGameView.menu;
    });
    _resumeMenuPulse();
    _syncAutoTrayShuffleTimer();
    _scheduleMenuRunWarmup();
  }

  Future<void> _restartAfterGameOver() async {
    if (_isRestarting) {
      return;
    }

    _emitClickFeedback();
    setState(() {
      _isRestarting = true;
    });

    _isShowingFullscreenAd = true;
    try {
      await _adMob.showInterstitialAd();
    } finally {
      _isShowingFullscreenAd = false;
    }

    if (!mounted) {
      return;
    }
    _startNewGame(openGameplay: true);
  }

  Future<void> _reviveFromRewardedAd() async {
    if (_isReviving || _continueUsedThisRun) {
      return;
    }

    _emitClickFeedback();
    setState(() {
      _isReviving = true;
    });

    final rewarded = await _adMob.showSoulGameRewardedAd();
    if (!mounted) {
      return;
    }

    if (!rewarded) {
      setState(() {
        _isReviving = false;
      });
      _showSnackBar('Quảng cáo chưa sẵn sàng. Hãy thử lại sau vài giây.');
      return;
    }

    final occupiedRows = <int>[];
    for (var row = 0; row < _boardSize; row++) {
      if (_board[row].any((tile) => tile != null)) {
        occupiedRows.add(row);
      }
    }
    occupiedRows.shuffle(_random);
    final revivedRows = occupiedRows.take(min(3, occupiedRows.length)).toSet();

    final nextBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (row) => List<_SoulTile?>.from(_board[row]),
    );
    for (final row in revivedRows) {
      for (var col = 0; col < _boardSize; col++) {
        nextBoard[row][col] = null;
      }
    }

    final nextTray = List<_SoulPieceOption>.from(_tray);
    final nextRecommended = _recommendMoveFor(nextBoard, nextTray);
    final nextIsGameOver =
        nextTray.isEmpty || !_hasAnyPlayableMove(nextBoard, nextTray);

    setState(() {
      _board = nextBoard;
      _tray = nextTray;
      _recommendedMove = nextRecommended;
      _clearingRows = revivedRows;
      _clearingCols = <int>{};
      _continueUsedThisRun = true;
      _isReviving = false;
      _isGameOver = nextIsGameOver;
      _isBusy = false;
    });

    _triggerScreenPulse();
    _showFloatingMessage(
      'Continue!',
      color: const Color(0xFF00FF66),
    );
    _emitClearFeedback(
      clearedCount: max(1, revivedRows.length),
      streakCount: max(1, revivedRows.length),
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) {
      return;
    }
    setState(() {
      _clearingRows = <int>{};
    });
    unawaited(_persistSavedRun());
  }

  Future<void> _persistBestScore(int score) async {
    _bestScore = score;
    final prefs = await _prefsFuture;
    await prefs.setInt(_bestScoreKey, score);
    if (mounted) {
      setState(() {});
    }
  }

  List<_LeaderboardEntry> _decodeLeaderboard(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <_LeaderboardEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_LeaderboardEntry>[];
      }
      final entries = decoded
          .whereType<Map>()
          .map(
            (item) => _LeaderboardEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
      entries.sort(_sortLeaderboard);
      return entries.take(10).toList(growable: false);
    } catch (_) {
      return <_LeaderboardEntry>[];
    }
  }

  int _sortLeaderboard(_LeaderboardEntry a, _LeaderboardEntry b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return b.timestampMs.compareTo(a.timestampMs);
  }

  Future<void> _persistCurrentRunScore() async {
    if (_turn <= 0) {
      return;
    }

    final entry = _LeaderboardEntry(
      sessionId: _currentSessionId,
      score: _score,
      lines: _clearedLines,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    final nextEntries = List<_LeaderboardEntry>.from(_leaderboard)
      ..removeWhere((item) => item.sessionId == _currentSessionId)
      ..add(entry)
      ..sort(_sortLeaderboard);
    final trimmed = nextEntries.take(10).toList(growable: false);

    final prefs = await _prefsFuture;
    await prefs.setString(
      _leaderboardKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );

    if (mounted) {
      setState(() {
        _leaderboard = trimmed;
      });
    }
  }

  Map<String, dynamic> _tileToJson(_SoulTile tile) {
    return <String, dynamic>{
      'toneIndex': tile.toneIndex,
      'pieceId': tile.pieceId,
      'placedTurn': tile.placedTurn,
    };
  }

  _SoulTile? _tileFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    return _SoulTile(
      toneIndex: (json['toneIndex'] as num?)?.toInt() ?? 0,
      pieceId: (json['pieceId'] as num?)?.toInt() ?? 0,
      placedTurn: (json['placedTurn'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _pieceToJson(_SoulPieceOption piece) {
    return <String, dynamic>{
      'id': piece.id,
      'templateId': piece.template.id,
      'toneIndex': piece.toneIndex,
    };
  }

  _SoulPieceOption? _pieceFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final String templateId = (json['templateId'] as String? ?? '').trim();
    final _SoulPieceTemplate? template =
        _kSoulBlockTemplates.cast<_SoulPieceTemplate?>().firstWhere(
              (_SoulPieceTemplate? item) => item?.id == templateId,
              orElse: () => null,
            );
    if (template == null) {
      return null;
    }
    return _SoulPieceOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      template: template,
      toneIndex: (json['toneIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _persistSavedRun() async {
    final SharedPreferences prefs = await _prefsFuture;
    if (_view != _SoulGameView.gameplay || _isGameOver) {
      await prefs.remove(_savedRunKey);
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'sessionId': _currentSessionId,
      'score': _score,
      'bestScore': _bestScore,
      'combo': _combo,
      'streak': _streak,
      'turn': _turn,
      'clearedLines': _clearedLines,
      'continueUsedThisRun': _continueUsedThisRun,
      'pieceSequence': _pieceSequence,
      'board': _board
          .map(
            (List<_SoulTile?> row) => row
                .map((tile) => tile == null ? null : _tileToJson(tile))
                .toList(growable: false),
          )
          .toList(growable: false),
      'tray': _tray.map(_pieceToJson).toList(growable: false),
    };
    await prefs.setString(_savedRunKey, jsonEncode(payload));
  }

  Future<void> _clearSavedRun() async {
    final SharedPreferences prefs = await _prefsFuture;
    await prefs.remove(_savedRunKey);
  }

  _PreparedSoulRun? _decodeSavedRun(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
      final List<dynamic> boardRows = (json['board'] as List?) ?? <dynamic>[];
      if (boardRows.length != _boardSize) {
        return null;
      }
      final List<List<_SoulTile?>> board = boardRows.map((Object? row) {
        final List<dynamic> cells = row is List ? row : <dynamic>[];
        if (cells.length != _boardSize) {
          throw const FormatException('invalid board row');
        }
        return cells.map(_tileFromJson).toList(growable: false);
      }).toList(growable: false);
      final List<_SoulPieceOption> tray =
          ((json['tray'] as List?) ?? <dynamic>[])
              .map(_pieceFromJson)
              .whereType<_SoulPieceOption>()
              .toList(growable: false);
      final _RecommendedMove? recommendedMove = _recommendMoveFor(board, tray);
      if (tray.isEmpty || !_hasAnyPlayableMove(board, tray)) {
        return null;
      }
      _pieceSequence = max(
        (json['pieceSequence'] as num?)?.toInt() ?? 0,
        tray.fold<int>(
            0, (int maxId, _SoulPieceOption piece) => max(maxId, piece.id)),
      );
      _score = (json['score'] as num?)?.toInt() ?? 0;
      _bestScore = max(_bestScore, (json['bestScore'] as num?)?.toInt() ?? 0);
      _combo = (json['combo'] as num?)?.toInt() ?? 0;
      _streak = (json['streak'] as num?)?.toInt() ?? 0;
      _turn = (json['turn'] as num?)?.toInt() ?? 0;
      _clearedLines = (json['clearedLines'] as num?)?.toInt() ?? 0;
      _continueUsedThisRun = json['continueUsedThisRun'] == true;
      return _PreparedSoulRun(
        board: board,
        tray: tray,
        recommendedMove: recommendedMove,
        sessionId: (json['sessionId'] as num?)?.toInt() ??
            DateTime.now().microsecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildCurrentView() {
    switch (_view) {
      case _SoulGameView.splash:
        return _buildSplashScreen();
      case _SoulGameView.menu:
        if (_loadError != null) {
          return _buildLoadErrorPanel();
        }
        return _buildRefinedMainMenu();
      case _SoulGameView.gameplay:
        return _buildRefinedGameplayScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    _performanceProfile = _resolvePerformanceProfile();
    final Widget currentView = KeyedSubtree(
      key: ValueKey<_SoulGameView>(_view),
      child: _buildCurrentView(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      bottomNavigationBar:
          _view == _SoulGameView.gameplay ? _buildBannerDock() : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              _kSoulStageTop,
              _kSoulStageMid,
              _kSoulStageBottom,
            ],
            stops: <double>[0, 0.54, 1],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned(
              top: -70,
              left: -24,
              child: _GlowOrb(
                color: Color(0x24FFB86B),
                size: 230,
              ),
            ),
            const Positioned(
              right: -46,
              top: 118,
              child: _GlowOrb(
                color: Color(0x2258C7FF),
                size: 210,
              ),
            ),
            const Positioned(
              left: -42,
              bottom: 74,
              child: _GlowOrb(
                color: Color(0x2057F0A0),
                size: 220,
              ),
            ),
            const Positioned(
              right: 18,
              bottom: -70,
              child: _GlowOrb(
                color: Color(0x1FFF5FA2),
                size: 210,
              ),
            ),
            AnimatedBuilder(
              animation: _flashController,
              builder: (BuildContext context, Widget? child) {
                if (_backgroundFlashOpacity <= 0.001) {
                  return const SizedBox.shrink();
                }
                return IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFFFFE398)
                        .withValues(alpha: _backgroundFlashOpacity),
                  ),
                );
              },
            ),
            SafeArea(
              bottom: _view != _SoulGameView.gameplay,
              child: _view == _SoulGameView.gameplay
                  ? currentView
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: currentView,
                    ),
            ),
            if (_view == _SoulGameView.gameplay && _floatingText != null)
              _buildFloatingToast(),
            if (_view == _SoulGameView.gameplay && _memoryBurstSnapshot != null)
              _buildMemoryBurstOverlay(),
            if (_view == _SoulGameView.gameplay &&
                _explosionParticles.isNotEmpty)
              _buildExplosionEffect(),
            if (_view == _SoulGameView.gameplay)
              ValueListenableBuilder<int>(
                valueListenable: _dragOverlayTick,
                builder: (BuildContext context, int _, Widget? __) {
                  final _SoulPieceOption? piece = _draggingPiece;
                  final Widget? overlay = _draggedPieceOverlay;
                  if (piece == null ||
                      overlay == null ||
                      _boardCellExtent <= 0 ||
                      _dragOverlayWidth <= 0 ||
                      _dragOverlayHeight <= 0) {
                    return const SizedBox.shrink();
                  }
                  final ({double left, double top}) overlayOffset =
                      _dragPieceOverlayOffsetFromPosition(
                    piece,
                    _dragPosition,
                  );
                  return Positioned(
                    left: _clampDragPieceLeft(
                      overlayOffset.left,
                      _dragOverlayWidth,
                    ),
                    top: _clampDragPieceTop(
                      overlayOffset.top,
                      _dragOverlayHeight,
                    ),
                    width: _dragOverlayWidth,
                    height: _dragOverlayHeight,
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale:
                            _previewRow >= 0 && _previewCol >= 0 ? 1.02 : 1.0,
                        child: Opacity(
                          opacity: _previewRow >= 0 && _previewCol >= 0
                              ? 0.98
                              : 0.94,
                          child: RepaintBoundary(child: overlay),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
