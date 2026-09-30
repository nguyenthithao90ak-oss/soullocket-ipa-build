// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/service_locator.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/admob_service.dart';
import 'package:soullocket_app/widgets/consent_ad_view.dart';
import '../../utils/services/house_service.dart';
import '../../utils/app_error_mapper.dart';
import '../premium/premium_store_screen.dart';
import '../../utils/services/games/game_download_service.dart';
import '../../utils/services/games/soul_block_memory_service.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

part 'soul_block/soul_block_panels.dart';
part 'soul_block/soul_block_refined_panels.dart';
part 'soul_block/soul_block_bootstrap.dart';
part 'soul_block/soul_block_board.dart';
part 'soul_block/soul_block_feedback_section.dart';
part 'soul_block/soul_block_models.dart';
part 'soul_block/soul_block_menu_widgets.dart';
part 'soul_block/soul_block_panel_section.dart';
part 'soul_block/soul_block_strategy_logic.dart';
part 'soul_block/soul_block_photo.dart';

enum _SoulGameView { splash, menu, gameplay }

class SoulBlockGame extends StatefulWidget {
  SoulBlockGame({
    super.key,
    this.storageKeyPrefix = 'soul_block',
    this.gameTitle = 'SOUL BLOCK',
    String? loadErrorMessage,
  }) : loadErrorMessage =
           loadErrorMessage ??
           L10nService().translate('util_khngthkhin_d28984');

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
  int _boardSize = 8;
  _SoulPieceOption? _holdPiece;
  bool _draggingFromHold = false;
  final GlobalKey _holdAreaKey = GlobalKey();
  final int _rotationsLeft = 3;

  static const double _boardGap = 1.8;
  static const double _boardPanelPadding = 10;
  static const double _boardLayoutSafetyInset = 12.0;
  static const double _bannerDockBaseHeight = 54.0;
  static const double _memoryBurstCardAspectRatio = 0.9;
  static const double _dragLiftOffset = 12;
  static const double _dragUpdateEpsilon = 1.2;
  static const double _dragOverlayUpdateEpsilon = 2.8;
  static const Duration _autoTrayShuffleInterval = Duration(seconds: 30);
  static const Duration _autoTrayShuffleRetryDelay = Duration(seconds: 3);
  static const int _maxReviveAdsPerRun = 5;
  static const Duration _gameOverRevealDelay = Duration(milliseconds: 760);

  String get _bestScoreKey => '${widget.storageKeyPrefix}_best_score';
  String get _soundEnabledKey => '${widget.storageKeyPrefix}_sound_enabled';
  String get _vibrationEnabledKey =>
      '${widget.storageKeyPrefix}_vibration_enabled';
  String get _smoothGraphicsKey => '${widget.storageKeyPrefix}_smooth_graphics';
  String get _leaderboardKey =>
      '${widget.storageKeyPrefix}_local_leaderboard_v2';
  String get _autoTrayShuffleEnabledKey =>
      '${widget.storageKeyPrefix}_auto_tray_shuffle_enabled';
  String get _savedRunKey => '${widget.storageKeyPrefix}_saved_run_v1';
  @override
  int get _strategyBoardSize => _boardSize;

  final HouseService _houseService = HouseService();
  final SoulBlockMemoryService _memoryService =
      locator<SoulBlockMemoryService>();
  final AdMobService _adMob = AdMobService();
  @override
  final Random _random = Random();
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _effectsKey = GlobalKey();
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
  bool _loadingBanner = false;

  String? _houseId;
  String? _loadError;
  String? _floatingText;

  Set<int> _clearingRows = <int>{};
  Set<int> _clearingCols = <int>{};
  Set<Point<int>> _clearingCells = <Point<int>>{};

  Offset _dragPosition = Offset.zero;
  Offset _boardOrigin = Offset.zero;
  List<List<bool>>? _dragBoardMask;
  Set<int>? _dragPreviewFootprintKeys;
  Widget? _draggedPieceOverlay;
  double _dragOverlayWidth = 0;
  double _dragOverlayHeight = 0;
  Color _floatingTextColor = const Color(0xFFFFCC00);

  List<_ExplosionParticle> _explosionParticles = <_ExplosionParticle>[];
  Offset _explosionCenter = Offset.zero;
  Color _explosionAccent = const Color(0xFFFFCC00);
  _MemoryBurstSnapshot? _memoryBurstSnapshot;
  ui.Image? _boardPhoto;
  String? _photoId;
  StreamSubscription<User?>? _photoAuthSubscription;
  int _photoRequest = 0;
  bool _photoLoading = false;
  bool _photoUnavailable = false;
  bool _photoNeedsNext = false;
  int _newGamesSincePhotoChange = 0;
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
  final List<int> _sfxRequests = List<int>.filled(4, 0);
  int? _pausedAtMs;
  DateTime? _autoTrayShuffleNextAt;

  double _boardCellExtent = 0;
  double _boardContentInset = 0;

  Uint8List? _tapSfxBytes;
  Uint8List? _liftSfxBytes;
  Uint8List? _placeSfxBytes;
  Uint8List? _clearSfxBytes;
  Uint8List? _bombSfxBytes;
  Uint8List? _streakSfxBytes;
  Uint8List? _bestScoreSfxBytes;
  List<Uint8List> _comboSfxLevels = <Uint8List>[];

  bool _audioReady = false;
  bool _audioSettingsLoaded = false;
  bool _bgmSourceReady = false;
  Future<void> _bgmSyncQueue = Future<void>.value();
  bool _appActive = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _smoothGraphics = true;
  bool _isBusy = false;
  bool _isGameOver = false;
  bool _isResolvingGameOver = false;
  int _reviveAdsUsed = 0;
  bool _isReviving = false;
  bool _isRestarting = false;
  bool _isShowingFullscreenAd = false;
  bool _isOpeningGameplay = false;
  bool _autoTrayShuffleEnabled = false;
  bool _isPremiumUser = false;

  Timer? _autoTrayShuffleTimer;

  @override
  void initState() {
    super.initState();
    _adMob.suppressAutoInterstitial();
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

    _floatingController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 960),
        )..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _floatingText = null);
          }
        });

    _explosionController =
        AnimationController(
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

    _memoryBurstController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1100),
        )..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _memoryBurstSnapshot = null);
          }
        });

    unawaited(_initAudio());
    _adMob.adRevision.addListener(_onBannerPrivacyChanged);
    final photoUid = FirebaseAuth.instance.currentUser?.uid;
    _photoAuthSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (mounted && user?.uid != photoUid) _clearDiaryPhoto();
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _adMob.adRevision.removeListener(_onBannerPrivacyChanged);
    _adMob.resumeAutoInterstitial();
    WidgetsBinding.instance.removeObserver(this);
    _autoTrayShuffleTimer?.cancel();
    _dragVisualTick.dispose();
    _trayVisualTick.dispose();
    _dragOverlayTick.dispose();
    AdMobService().disposeBanner(_bannerAd);
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
    _photoRequest++;
    unawaited(_photoAuthSubscription?.cancel());
    _boardPhoto?.dispose();
    _memoryService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appActive = false;
      _pausedAtMs = DateTime.now().millisecondsSinceEpoch;
      _autoTrayShuffleTimer?.cancel();
      unawaited(_syncBgmWithSound());
      for (final player in _sfxPlayers) {
        unawaited(player.pause());
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _appActive = true;
      final pausedAtMs = _pausedAtMs;
      _pausedAtMs = null;
      unawaited(_syncBgmWithSound());
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
    await _syncBgmWithSound();
    try {
      await _adMob.showInterstitialAd();
    } finally {
      _isShowingFullscreenAd = false;
      unawaited(_syncBgmWithSound());
    }
  }

  Future<void> _openPremiumStore() async {
    _emitClickFeedback();
    if (!AppConfig.isPurchaseEnabled) {
      _showSnackBar(context.tr('util_mcnyangtmn_fdd99c'));
      return;
    }
    final houseId = _houseId ?? await _houseService.getCurrentHouseId() ?? '';
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumStoreScreen(
          houseId: houseId,
          myName: context.tr('util_bn_1fd75b'),
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
    final sync = _syncBgmWithSound();
    if (!value) {
      for (var i = 0; i < _sfxPlayers.length; i++) {
        _sfxRequests[i]++;
        unawaited(_sfxPlayers[i].stop());
      }
    }
    await _persistSetting(_soundEnabledKey, value);
    await sync;
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

  Future<void> _setSmoothGraphicsEnabled(bool value) async {
    setState(() {
      _smoothGraphics = value;
      _performanceProfile = _resolvePerformanceProfile();
    });
    await _persistSetting(_smoothGraphicsKey, value);
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
    final int replacementCount = trayLength == 1
        ? 1
        : min(trayLength, 1 + _random.nextInt(2));
    final List<int> shuffledIndices = List<int>.generate(
      trayLength,
      (int index) => index,
    )..shuffle(_random);
    final List<_SoulPieceOption> replacementPool = _buildSmartBatch(_board);
    if (replacementPool.isEmpty) {
      return false;
    }

    var nextTray = List<_SoulPieceOption>.from(_tray);
    for (var index = 0; index < replacementCount; index++) {
      nextTray[shuffledIndices[index]] =
          replacementPool[index % replacementPool.length];
    }

    var nextRecommended = _recommendMoveFor(_board, [...nextTray, ?_holdPiece]);
    if (nextRecommended == null) {
      nextTray = _buildSmartBatch(
        _board,
      ).take(trayLength).toList(growable: false);
      if (nextTray.length != trayLength) {
        return false;
      }
      nextRecommended = _recommendMoveFor(_board, [...nextTray, ?_holdPiece]);
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
    final bool hadDragVisualState =
        _draggingPiece != null ||
        _previewRow != -1 ||
        _previewCol != -1 ||
        _dragBoardMask != null;
    _draggingPiece = null;
    _draggingFromHold = false;
    _previewRow = -1;
    _previewCol = -1;
    _dragBoardMask = null;
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
      _isResolvingGameOver = false;
      _isReviving = false;
      _isRestarting = false;
      _memoryBurstSnapshot = null;
      _explosionParticles = <_ExplosionParticle>[];
      _floatingText = null;
      _snapBackPieceId = null;
      _view = _SoulGameView.menu;
      _currentSessionId = 0;
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
    _startNewGame(openGameplay: true, preparedRun: preparedRun);
  }

  _PreparedSoulRun _prepareFreshRun() {
    final oldTurn = _turn;
    final oldCombo = _combo;
    final oldLines = _clearedLines;
    try {
      _turn = 0;
      _combo = 0;
      _clearedLines = 0;
      final nextBoard = _createOpeningBoard();
      final nextTray = _buildSmartBatch(nextBoard);
      return _PreparedSoulRun(
        board: nextBoard,
        tray: nextTray,
        recommendedMove: _recommendMoveFor(nextBoard, nextTray),
        sessionId: DateTime.now().microsecondsSinceEpoch,
      );
    } finally {
      _turn = oldTurn;
      _combo = oldCombo;
      _clearedLines = oldLines;
    }
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
    final int nextGamesSincePhotoChange = min(2, _newGamesSincePhotoChange + 1);
    final bool shouldRotatePhoto = nextGamesSincePhotoChange >= 2;
    _memoryBurstController.stop();
    _explosionController.stop();
    _floatingController.stop();
    _shakeController.reset();
    _flashController.reset();

    setState(() {
      _explosionParticles = <_ExplosionParticle>[];
      _draggedPieceOverlay = null;
      _board = _cloneBoard(nextRun.board);
      _tray = List<_SoulPieceOption>.from(nextRun.tray);
      _recommendedMove = nextRun.recommendedMove;
      _score = 0;
      _combo = 0;
      _streak = 0;
      _turn = 0;
      _clearedLines = 0;
      _scorePulseTick = 0;
      _currentSessionId = nextRun.sessionId;
      _draggingPiece = null;
      _previewRow = -1;
      _previewCol = -1;
      _dragBoardMask = null;
      _clearingRows = <int>{};
      _clearingCols = <int>{};
      _clearingCells = <Point<int>>{};
      _floatingText = null;
      _memoryBurstSnapshot = null;
      _snapBackPieceId = null;
      _isBusy = false;
      _isGameOver = nextRun.tray.isEmpty || nextRun.recommendedMove == null;
      _isResolvingGameOver = false;
      _reviveAdsUsed = 0;
      _holdPiece = null;
      _draggingFromHold = false;
      _dragPreviewFootprintKeys = null;
      _photoNeedsNext = shouldRotatePhoto;
      _newGamesSincePhotoChange = nextGamesSincePhotoChange;
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
      unawaited(_syncBgmWithSound());
      unawaited(_persistSavedRun());
      if (_houseId != null && (_boardPhoto == null || shouldRotatePhoto)) {
        // Ảnh chỉ tự chuyển sau hai ván mới; thao tác đổi ảnh thủ công vẫn
        // dùng cùng bộ nhớ ảnh và không làm gián đoạn hiệu ứng đang chạy.
        unawaited(_loadDiaryPhoto(next: shouldRotatePhoto));
      }
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
    if (_smoothGraphics) {
      return _SoulBlockPerformanceProfile.low;
    }
    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final Size logicalSize =
        mediaQuery?.size ??
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

  List<List<_SoulTile?>> _createEmptyBoard() {
    return List<List<_SoulTile?>>.generate(
      _boardSize,
      (_) => List<_SoulTile?>.filled(_boardSize, null),
    );
  }

  List<List<_SoulTile?>> _createOpeningBoard() {
    final List<List<_SoulTile?>> board = _createEmptyBoard();

    void placeCells(List<Point<int>> cells, int toneIndex, int pieceId) {
      for (final Point<int> cell in cells) {
        if (cell.y >= 0 &&
            cell.y < _boardSize &&
            cell.x >= 0 &&
            cell.x < _boardSize) {
          board[cell.y][cell.x] = _SoulTile(
            toneIndex: toneIndex,
            pieceId: pieceId,
            placedTurn: 0,
          );
        }
      }
    }

    // Smart opening: Row/col gần đầy để người dùng nổ nhanh
    // Mỗi pattern có 4 nhóm khối, tổng ~20-24 ô được lấp
    final List<List<List<Point<int>>>>
    smartOpeningPatterns = <List<List<Point<int>>>>[
      // Pattern A: Row 7 (6/8) + Col 7 (6/8) + row 0 (6/8) → user đặt 3 ô là nổ
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 7),
          const Point<int>(1, 7),
          const Point<int>(2, 7),
          const Point<int>(3, 7),
          const Point<int>(4, 7),
          const Point<int>(5, 7),
        ],
        <Point<int>>[
          const Point<int>(7, 0),
          const Point<int>(7, 1),
          const Point<int>(7, 2),
          const Point<int>(7, 3),
          const Point<int>(7, 4),
          const Point<int>(7, 5),
        ],
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(1, 0),
          const Point<int>(2, 0),
          const Point<int>(3, 0),
          const Point<int>(4, 0),
          const Point<int>(5, 0),
        ],
        <Point<int>>[
          const Point<int>(2, 3),
          const Point<int>(3, 3),
          const Point<int>(2, 4),
          const Point<int>(3, 4),
        ],
      ],
      // Pattern B: 2 rows gần đầy + cluster trung tâm
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 6),
          const Point<int>(1, 6),
          const Point<int>(2, 6),
          const Point<int>(4, 6),
          const Point<int>(5, 6),
          const Point<int>(6, 6),
        ],
        <Point<int>>[
          const Point<int>(0, 7),
          const Point<int>(1, 7),
          const Point<int>(2, 7),
          const Point<int>(3, 7),
          const Point<int>(5, 7),
          const Point<int>(6, 7),
        ],
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(0, 1),
          const Point<int>(0, 2),
          const Point<int>(0, 3),
          const Point<int>(0, 5),
          const Point<int>(0, 6),
        ],
        <Point<int>>[
          const Point<int>(3, 3),
          const Point<int>(4, 3),
          const Point<int>(3, 4),
          const Point<int>(4, 4),
        ],
      ],
      // Pattern C: Col 0 (6/8) + Col 7 (5/8) + row 7 gần đầy
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(7, 0),
          const Point<int>(7, 1),
          const Point<int>(7, 2),
          const Point<int>(7, 5),
          const Point<int>(7, 6),
        ],
        <Point<int>>[
          const Point<int>(0, 7),
          const Point<int>(0, 6),
          const Point<int>(0, 5),
          const Point<int>(0, 2),
          const Point<int>(0, 1),
          const Point<int>(0, 0),
        ],
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(1, 0),
          const Point<int>(2, 0),
          const Point<int>(3, 0),
          const Point<int>(5, 0),
          const Point<int>(6, 0),
        ],
        <Point<int>>[
          const Point<int>(4, 3),
          const Point<int>(5, 3),
          const Point<int>(4, 4),
          const Point<int>(5, 4),
        ],
      ],
      // Pattern D: Diagonal clusters + 2 near-full rows
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(1, 0),
          const Point<int>(2, 0),
          const Point<int>(3, 0),
          const Point<int>(4, 0),
          const Point<int>(6, 0),
        ],
        <Point<int>>[
          const Point<int>(1, 7),
          const Point<int>(2, 7),
          const Point<int>(3, 7),
          const Point<int>(4, 7),
          const Point<int>(5, 7),
          const Point<int>(6, 7),
        ],
        <Point<int>>[
          const Point<int>(2, 2),
          const Point<int>(3, 2),
          const Point<int>(2, 3),
        ],
        <Point<int>>[
          const Point<int>(5, 5),
          const Point<int>(6, 5),
          const Point<int>(6, 4),
          const Point<int>(5, 4),
        ],
      ],
      // Pattern E: 3 near-full cols spread
      <List<Point<int>>>[
        <Point<int>>[
          const Point<int>(0, 0),
          const Point<int>(0, 1),
          const Point<int>(0, 2),
          const Point<int>(0, 4),
          const Point<int>(0, 5),
          const Point<int>(0, 6),
        ],
        <Point<int>>[
          const Point<int>(4, 0),
          const Point<int>(4, 1),
          const Point<int>(4, 2),
          const Point<int>(4, 4),
          const Point<int>(4, 5),
          const Point<int>(4, 6),
        ],
        <Point<int>>[
          const Point<int>(7, 0),
          const Point<int>(7, 1),
          const Point<int>(7, 2),
          const Point<int>(7, 4),
          const Point<int>(7, 5),
          const Point<int>(7, 6),
        ],
        <Point<int>>[
          const Point<int>(2, 3),
          const Point<int>(3, 3),
          const Point<int>(5, 3),
          const Point<int>(6, 3),
        ],
      ],
    ];

    final List<List<Point<int>>> selectedPattern =
        smartOpeningPatterns[_random.nextInt(smartOpeningPatterns.length)];
    for (int index = 0; index < selectedPattern.length; index++) {
      placeCells(
        selectedPattern[index],
        index % _kSoulTones.length,
        -(index + 1),
      );
    }

    final targetOpeningCells = 40 + _random.nextInt(5);
    var filledCells = 0;
    for (var row = 0; row < _boardSize; row++) {
      for (var col = 0; col < _boardSize; col++) {
        if (board[row][col] != null) filledCells++;
      }
    }

    var guard = 0;
    while (filledCells < targetOpeningCells && guard < 240) {
      guard++;
      final row = _random.nextInt(_boardSize);
      final col = _random.nextInt(_boardSize);
      if (board[row][col] != null) continue;

      var rowCount = 0;
      var colCount = 0;
      for (var i = 0; i < _boardSize; i++) {
        if (board[row][i] != null) rowCount++;
        if (board[i][col] != null) colCount++;
      }
      if (rowCount >= _boardSize - 1 || colCount >= _boardSize - 1) continue;

      board[row][col] = _SoulTile(
        toneIndex: (row + col) % _kSoulTones.length,
        pieceId: -100 - filledCells,
        placedTurn: 0,
      );
      filledCells++;
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
    final double innerExtent = boardExtent - (_boardPanelPadding * 2) - 6.0;
    final double contentExtent =
        (_boardCellExtent * _boardSize) + (_boardGap * (_boardSize - 1));
    _boardContentInset = max(0, innerExtent - contentExtent) / 2;
  }

  double _resolveBoardCellExtent(
    double boardExtent, {
    required double devicePixelRatio,
  }) {
    final double usableBoardExtent =
        boardExtent -
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
          topInset,
          max(topInset, screenHeight - bottomInset - pieceHeight),
        )
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

  void _startDrag(
    _SoulPieceOption piece,
    Offset globalPosition, {
    bool fromHold = false,
  }) {
    if (_isGameOver || _isBusy || _view != _SoulGameView.gameplay) {
      return;
    }

    _draggingFromHold = fromHold;
    _updateBoardMetrics();
    _dragBoardMask = _boardMask(_board);
    _dragPreviewFootprintKeys = null;
    _dragOverlayWidth = _dragPieceWidthPixels(piece);
    _dragOverlayHeight = _dragPieceHeightPixels(piece);
    final preview = _resolvePreviewCell(piece, globalPosition);
    _emitLiftFeedback();
    _draggingPiece = piece;
    _dragPosition = globalPosition;
    _previewRow = preview.row;
    _previewCol = preview.col;
    _draggedPieceOverlay = _buildDraggedPieceGrid(piece);
    _dragPreviewFootprintKeys = _previewFootprintKeys(
      piece,
      preview.row,
      preview.col,
    );
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
      _draggedPieceOverlay = _buildDraggedPieceGrid(draggingPiece);
      _dragPreviewFootprintKeys = _previewFootprintKeys(
        draggingPiece,
        preview.row,
        preview.col,
      );
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

  bool _isInsideHoldArea(Offset globalPosition) {
    final RenderBox? box =
        _holdAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    ).contains(globalPosition);
  }

  Future<void> _endDrag() async {
    if (_draggingPiece != null) {
      final piece = _draggingPiece!;
      if (_previewRow >= 0 && _previewCol >= 0) {
        final row = _previewRow;
        final col = _previewCol;
        _clearDragVisualState();
        await _placePieceAt(piece, row, col);
        return;
      }

      if (!_draggingFromHold && _isInsideHoldArea(_dragPosition)) {
        _clearDragVisualState();
        _emitPlaceFeedback();
        setState(() {
          final temp = _holdPiece;
          _holdPiece = piece;
          _tray = List<_SoulPieceOption>.from(_tray)
            ..removeWhere((item) => item.id == piece.id);
          if (temp != null) {
            _tray.add(temp);
          }
          if (_tray.isEmpty) _tray = _buildSmartBatch(_board);
          _recommendedMove = _recommendMoveFor(_board, [..._tray, ?_holdPiece]);
        });
        _markTrayVisualDirty();
        unawaited(_persistSavedRun());
        return;
      }
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

    final relativeX =
        pieceOffset.dx -
        _boardOrigin.dx -
        _boardPanelPadding -
        _boardContentInset;
    final relativeY =
        pieceOffset.dy -
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

  Future<void> _placePieceAt(_SoulPieceOption piece, int row, int col) async {
    if (_isGameOver || _isBusy) {
      return;
    }

    final boardMask = _boardMask(_board);
    if (!_canPlace(boardMask, piece.template, row, col)) {
      return;
    }

    _isBusy = true;
    final sessionId = _currentSessionId;
    final fromHold = _holdPiece?.id == piece.id;

    final placedBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (boardRow) => List<_SoulTile?>.from(_board[boardRow]),
    );
    for (final cell in piece.template.cells) {
      placedBoard[row + cell.y][col + cell.x] = _SoulTile(
        toneIndex: piece.toneIndex,
        pieceId: piece.id,
        placedTurn: _turn + 1,
        photoRect: _piecePhotoRect(
          piece,
          cell.x,
          cell.y,
          boardRow: row + cell.y,
          boardCol: col + cell.x,
        ),
      );
    }

    // Giữ ảnh ô trước khi bom xóa dữ liệu để mảnh vỡ khớp với bàn.
    final burstSource = _cloneBoard(placedBoard);
    final bombClearedCells = <Point<int>>[];
    if (piece.isBomb) {
      final int centerRow = row + piece.template.height ~/ 2;
      final int centerCol = col + piece.template.width ~/ 2;
      for (int r = centerRow - 1; r <= centerRow + 1; r++) {
        for (int c = centerCol - 1; c <= centerCol + 1; c++) {
          if (r >= 0 && r < _boardSize && c >= 0 && c < _boardSize) {
            if (placedBoard[r][c] != null) {
              placedBoard[r][c] = null;
              bombClearedCells.add(Point<int>(c, r));
            }
          }
        }
      }
    }

    final clearedRows = <int>[];
    final clearedCols = <int>[];
    for (var boardRow = 0; boardRow < _boardSize; boardRow++) {
      if (placedBoard[boardRow].every((cell) => cell != null)) {
        clearedRows.add(boardRow);
      }
    }
    for (var boardCol = 0; boardCol < _boardSize; boardCol++) {
      var full = true;
      for (var boardRow = 0; boardRow < _boardSize; boardRow++) {
        if (placedBoard[boardRow][boardCol] == null) {
          full = false;
          break;
        }
      }
      if (full) {
        clearedCols.add(boardCol);
      }
    }

    final clearedNow = clearedRows.length + clearedCols.length;
    int gainedScore = _scoreGainFor(piece.template, clearedNow, _combo);
    if (piece.isBomb) {
      gainedScore += bombClearedCells.length * 10;
    }
    if (piece.isGold) {
      gainedScore *= 2;
    }
    final nextScore = _score + gainedScore;
    final nextCombo = clearedNow > 0 ? _combo + 1 : 0;
    final nextStreak = clearedNow > 0 ? _streak + 1 : 0;
    final bool beatBestThisMove =
        _score <= _bestScore && nextScore > _bestScore;
    final List<_SoulPieceOption> remainingTray;
    if (fromHold) {
      remainingTray = _tray;
    } else {
      remainingTray = List<_SoulPieceOption>.from(_tray)
        ..removeWhere((item) => item.id == piece.id);
    }

    if (piece.isBomb) {
      _emitBombFeedback();
    } else {
      _emitPlaceFeedback();
    }
    if (piece.isBomb && bombClearedCells.isNotEmpty) {
      _showFloatingMessage(
        L10nService().format('soul_block_boom', {
          'points': bombClearedCells.length * 10,
        }),
        color: const Color(0xFFFF4500),
      );
      _triggerScreenPulse();
    }
    if (piece.isGold) {
      _showFloatingMessage(
        L10nService().translate('soul_block_gold'),
        color: const Color(0xFFFFD700),
      );
      _triggerScreenPulse();
    }

    if (clearedNow > 0) {
      _emitClearFeedback(clearedCount: clearedNow, streakCount: nextStreak);
      _triggerScreenPulse();
      if (clearedNow >= 2) {
        _showComboBurst(clearedNow);
      } else if (nextStreak >= 2) {
        _showFloatingMessage(
          L10nService().format('soul_block_chain', {'level': nextStreak}),
          color: const Color(0xFF00C3FF),
        );
      }
    }
    if (beatBestThisMove && clearedNow == 0 && !piece.isBomb) {
      _emitBestScoreFeedback();
      // Removed 'New Best!' floating message to reduce spam during gameplay.
    }

    setState(() {
      _board = placedBoard;
      _tray = remainingTray;
      if (fromHold) {
        _holdPiece = null;
      }
      _turn += 1;
      _score = nextScore;
      _combo = nextCombo;
      _streak = nextStreak;
      _scorePulseTick += 1;
      _clearingRows = clearedRows.toSet();
      _clearingCols = clearedCols.toSet();
      _clearingCells = bombClearedCells.toSet();
    });

    if (clearedNow > 0 || bombClearedCells.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted ||
          _currentSessionId != sessionId ||
          _view != _SoulGameView.gameplay) {
        return;
      }
    }

    final resolvedBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (boardRow) => List<_SoulTile?>.from(placedBoard[boardRow]),
    );
    for (final boardRow in clearedRows) {
      for (var boardCol = 0; boardCol < _boardSize; boardCol++) {
        resolvedBoard[boardRow][boardCol] = null;
      }
    }
    for (final boardCol in clearedCols) {
      for (var boardRow = 0; boardRow < _boardSize; boardRow++) {
        resolvedBoard[boardRow][boardCol] = null;
      }
    }

    final replenishedTray = remainingTray.isEmpty
        ? _buildSmartBatch(resolvedBoard)
        : remainingTray;
    final nextRecommended = _recommendMoveFor(resolvedBoard, [
      ...replenishedTray,
      ?_holdPiece,
    ]);
    final noMovesLeft = nextRecommended == null;

    setState(() {
      _board = resolvedBoard;
      _tray = replenishedTray;
      _recommendedMove = nextRecommended;
      _clearingRows = <int>{};
      _clearingCols = <int>{};
      _clearingCells = <Point<int>>{};
      _clearedLines += clearedNow;
      _isGameOver = noMovesLeft;
      _isResolvingGameOver = noMovesLeft;
      _isBusy = false;
    });

    if (_boardPhoto != null &&
        (clearedNow > 0 || bombClearedCells.isNotEmpty)) {
      final Set<Point<int>> photoBurstCells = <Point<int>>{};
      for (final int clearRow in clearedRows) {
        for (int clearCol = 0; clearCol < _boardSize; clearCol++) {
          photoBurstCells.add(Point<int>(clearCol, clearRow));
        }
      }
      for (final int clearCol in clearedCols) {
        for (int clearRow = 0; clearRow < _boardSize; clearRow++) {
          photoBurstCells.add(Point<int>(clearCol, clearRow));
        }
      }
      photoBurstCells.addAll(bombClearedCells);
      _burstPhotoCells(burstSource, photoBurstCells, clearedCount: clearedNow);
    } else if (clearedNow > 0) {
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
    } else if (bombClearedCells.isNotEmpty) {
      _triggerExplosionEffect(
        clearedCount: 2,
        clearedRows: <int>[row],
        clearedCols: <int>[col],
        subtle: false,
      );
    }
    final bool shouldTriggerBurst = clearedNow >= 4 && !_smoothGraphics;
    if (clearedNow > 0 && shouldTriggerBurst) {
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

  void _rotatePiece(_SoulPieceOption piece) {
    if (_isGameOver || _isBusy || _draggingPiece != null) return;
    final index = _tray.indexWhere((p) => p.id == piece.id);
    if (index < 0 && _holdPiece?.id != piece.id) return;
    _emitClickFeedback();
    final rotated = _SoulPieceOption(
      id: piece.id,
      template: piece.template.rotate(),
      toneIndex: piece.toneIndex,
      isGold: piece.isGold,
      isBomb: piece.isBomb,
    );
    setState(() {
      if (index >= 0) {
        _tray[index] = rotated;
      } else {
        _holdPiece = rotated;
      }
      _recommendedMove = _recommendMoveFor(_board, [..._tray, ?_holdPiece]);
    });
    _markTrayVisualDirty();
    unawaited(_persistSavedRun());
  }

  void _setBoardSize(int size) {
    if (_boardSize == size) return;
    setState(() {
      _boardSize = size;
      _preparedMenuRun = null;
    });
    _scheduleMenuRunWarmup();
  }

  Future<void> _handleGameOverTransition() async {
    _cancelDrag();
    _memoryBurstController.stop();
    _combo = 0;
    _streak = 0;
    // Giữ nguyên trạng thái bàn trong lúc hiệu ứng nổ kết thúc để người chơi
    // nhìn thấy nút hồi sinh thay vì bị chuyển Game Over quá sớm.
    if (mounted) {
      setState(() {
        _isResolvingGameOver = true;
      });
    }
    await Future<void>.delayed(_gameOverRevealDelay);
    await _persistCurrentRunScore();
    _adMob.preloadSoulGameRewardedAd();
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (mounted) {
      setState(() {
        _isResolvingGameOver = false;
      });
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
      _isResolvingGameOver = false;
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
    await _syncBgmWithSound();
    try {
      await _adMob.showInterstitialAd();
    } finally {
      _isShowingFullscreenAd = false;
      unawaited(_syncBgmWithSound());
    }

    if (!mounted) {
      return;
    }
    _startNewGame(openGameplay: true);
  }

  Future<void> _reviveFromRewardedAd() async {
    if (_isReviving ||
        _isRestarting ||
        _isResolvingGameOver ||
        _isShowingFullscreenAd ||
        _reviveAdsUsed >= _maxReviveAdsPerRun) {
      return;
    }

    _emitClickFeedback();
    setState(() {
      _isReviving = true;
      _isShowingFullscreenAd = true;
    });

    await _syncBgmWithSound();
    bool rewarded = false;
    try {
      rewarded = await _adMob.showSoulGameRewardedAd();
    } catch (error) {
      debugPrint(
        'Soul Block rewarded revive failed: '
        '${AppErrorMapper.resolve(error).message}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isShowingFullscreenAd = false;
        });
      } else {
        _isShowingFullscreenAd = false;
      }
      unawaited(_syncBgmWithSound());
    }
    if (!mounted) {
      return;
    }

    if (!rewarded) {
      setState(() {
        _isReviving = false;
      });
      _showSnackBar(context.tr('soul_block_revive_unavailable'));
      return;
    }

    final occupiedRows = List<int>.generate(_boardSize, (row) => row)
      ..sort((a, b) {
        final aCount = _board[a].whereType<_SoulTile>().length;
        final bCount = _board[b].whereType<_SoulTile>().length;
        return bCount.compareTo(aCount);
      });
    final revivedRows = occupiedRows
        .where((row) => _board[row].any((tile) => tile != null))
        .take(min(3, _boardSize))
        .toSet();

    final nextBoard = List<List<_SoulTile?>>.generate(
      _boardSize,
      (row) => List<_SoulTile?>.from(_board[row]),
    );
    for (final row in revivedRows) {
      for (var col = 0; col < _boardSize; col++) {
        nextBoard[row][col] = null;
      }
    }

    var nextTray = List<_SoulPieceOption>.from(_tray);
    var nextRecommended = _recommendMoveFor(nextBoard, [
      ...nextTray,
      ?_holdPiece,
    ]);
    if (nextRecommended == null) {
      final rescuePieces = _buildSmartBatch(nextBoard);
      if (rescuePieces.isNotEmpty) {
        nextTray = List<_SoulPieceOption>.from(nextTray)
          ..add(rescuePieces.first);
      }
      nextRecommended = _recommendMoveFor(nextBoard, nextTray);
    }
    if (nextRecommended == null) {
      final rescueTemplate = _kSoulBlockTemplates.firstWhere(
        (template) => template.id == 'single',
      );
      nextTray = List<_SoulPieceOption>.from(nextTray)
        ..add(_spawnPieceFromTemplate(rescueTemplate, forceBomb: true));
      nextRecommended = _recommendMoveFor(nextBoard, nextTray);
    }

    setState(() {
      _board = nextBoard;
      _tray = nextTray;
      _recommendedMove = nextRecommended;
      _clearingRows = revivedRows;
      _clearingCols = <int>{};
      _clearingCells = <Point<int>>{};
      _reviveAdsUsed += 1;
      _isReviving = false;
      _isGameOver = nextRecommended == null;
      _isResolvingGameOver = false;
      _isBusy = false;
    });
    // Ghi ngay sau khi quảng cáo được xác nhận để số lượt không bị lùi lại
    // nếu app bị thu nhỏ trong lúc hiệu ứng hồi sinh đang chạy.
    unawaited(_persistSavedRun());

    _triggerScreenPulse();
    _showFloatingMessage(
      L10nService().translate('soul_block_continue'),
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
      _clearingCells = <Point<int>>{};
    });
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
            (item) =>
                _LeaderboardEntry.fromJson(Map<String, dynamic>.from(item)),
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
      if (tile.photoRect != null)
        'photoRect': [
          tile.photoRect!.left,
          tile.photoRect!.top,
          tile.photoRect!.width,
          tile.photoRect!.height,
        ],
    };
  }

  _SoulTile? _tileFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final rawCrop = json['photoRect'];
    final crop = rawCrop is List && rawCrop.length == 4
        ? Rect.fromLTWH(
            (rawCrop[0] as num).toDouble(),
            (rawCrop[1] as num).toDouble(),
            (rawCrop[2] as num).toDouble(),
            (rawCrop[3] as num).toDouble(),
          )
        : null;
    return _SoulTile(
      toneIndex: (json['toneIndex'] as num?)?.toInt() ?? 0,
      pieceId: (json['pieceId'] as num?)?.toInt() ?? 0,
      placedTurn: (json['placedTurn'] as num?)?.toInt() ?? 0,
      photoRect: crop,
    );
  }

  Map<String, dynamic> _pieceToJson(_SoulPieceOption piece) {
    return <String, dynamic>{
      'id': piece.id,
      'templateId': piece.template.id,
      'quarterTurns': piece.template.quarterTurns,
      'toneIndex': piece.toneIndex,
      'isGold': piece.isGold,
      'isBomb': piece.isBomb,
    };
  }

  _SoulPieceOption? _pieceFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final String templateId = (json['templateId'] as String? ?? '').trim();
    _SoulPieceTemplate? template = _kSoulBlockTemplates
        .cast<_SoulPieceTemplate?>()
        .firstWhere(
          (_SoulPieceTemplate? item) => item?.id == templateId,
          orElse: () => null,
        );
    if (template == null) {
      return null;
    }
    final turns = ((json['quarterTurns'] as num?)?.toInt() ?? 0) % 4;
    for (var turn = 0; turn < turns; turn++) {
      template = template!.rotate();
    }
    return _SoulPieceOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      template: template!,
      toneIndex: (json['toneIndex'] as num?)?.toInt() ?? 0,
      isGold: json['isGold'] == true,
      isBomb: json['isBomb'] == true,
    );
  }

  Future<void> _persistSavedRun() async {
    final SharedPreferences prefs = await _prefsFuture;
    // Giữ snapshot cả khi Game Over đang hiện để người chơi có thể hồi sinh
    // sau khi app bị thu nhỏ hoặc bị gián đoạn giữa quảng cáo.
    if (_view != _SoulGameView.gameplay) {
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
      'reviveAdsUsed': _reviveAdsUsed,
      'newGamesSincePhotoChange': _newGamesSincePhotoChange,
      'pieceSequence': _pieceSequence,
      'board': _board
          .map(
            (List<_SoulTile?> row) => row
                .map((tile) => tile == null ? null : _tileToJson(tile))
                .toList(growable: false),
          )
          .toList(growable: false),
      'tray': _tray.map(_pieceToJson).toList(growable: false),
      'holdPiece': _holdPiece == null ? null : _pieceToJson(_holdPiece!),
      'boardSize': _boardSize,
      if (_photoId != null) 'photoId': _photoId,
      'photoHouseId': _houseId,
      'photoNeedsNext': _photoNeedsNext,
    };
    await prefs.setString(_savedRunKey, jsonEncode(payload));
  }

  Future<void> _clearSavedRun() async {
    final SharedPreferences prefs = await _prefsFuture;
    await prefs.remove(_savedRunKey);
  }

  _PreparedSoulRun? _decodeSavedRun(String? raw, {String? houseId}) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
      final int savedBoardSize = (json['boardSize'] as num?)?.toInt() ?? 8;
      final List<dynamic> boardRows = (json['board'] as List?) ?? <dynamic>[];
      if (!const [8, 9, 10].contains(savedBoardSize) ||
          boardRows.length != savedBoardSize) {
        return null;
      }
      final List<List<_SoulTile?>> board = boardRows
          .map((Object? row) {
            final List<dynamic> cells = row is List ? row : <dynamic>[];
            if (cells.length != savedBoardSize) {
              throw const FormatException('invalid board row');
            }
            return cells.map(_tileFromJson).toList(growable: false);
          })
          .toList(growable: false);
      final List<_SoulPieceOption> tray =
          ((json['tray'] as List?) ?? <dynamic>[])
              .map(_pieceFromJson)
              .whereType<_SoulPieceOption>()
              .toList(growable: false);
      final holdPiece = _pieceFromJson(json['holdPiece']);
      final previousSize = _boardSize;
      final _RecommendedMove? recommendedMove;
      try {
        _boardSize = savedBoardSize;
        recommendedMove = _recommendMoveFor(board, [...tray, ?holdPiece]);
      } finally {
        _boardSize = previousSize;
      }
      _pieceSequence = max(
        (json['pieceSequence'] as num?)?.toInt() ?? 0,
        [...tray, ?holdPiece].fold<int>(
          0,
          (int maxId, _SoulPieceOption piece) => max(maxId, piece.id),
        ),
      );
      _score = (json['score'] as num?)?.toInt() ?? 0;
      _bestScore = max(_bestScore, (json['bestScore'] as num?)?.toInt() ?? 0);
      _combo = (json['combo'] as num?)?.toInt() ?? 0;
      _streak = (json['streak'] as num?)?.toInt() ?? 0;
      _turn = (json['turn'] as num?)?.toInt() ?? 0;
      _clearedLines = (json['clearedLines'] as num?)?.toInt() ?? 0;
      _reviveAdsUsed = min(
        _maxReviveAdsPerRun,
        max(
          0,
          (json['reviveAdsUsed'] as num?)?.toInt() ??
              (json['continueUsedThisRun'] == true ? 1 : 0),
        ),
      );
      _newGamesSincePhotoChange = min(
        2,
        max(
          0,
          (json['newGamesSincePhotoChange'] as num?)?.toInt() ??
              (json['photoNeedsNext'] == true ? 1 : 0),
        ),
      );
      // Ván đang lưu không được tự đổi ảnh khi người chơi mở lại. Chỉ tiếp
      // tục bộ đếm hai ván cho lần bắt đầu ván mới tiếp theo.
      _photoNeedsNext = false;
      _photoId = json['photoHouseId'] == houseId
          ? (json['photoId'] as String?)?.trim()
          : null;
      return _PreparedSoulRun(
        board: board,
        tray: tray,
        recommendedMove: recommendedMove,
        sessionId:
            (json['sessionId'] as num?)?.toInt() ??
            DateTime.now().microsecondsSinceEpoch,
        holdPiece: holdPiece,
        boardSize: savedBoardSize,
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
      backgroundColor: _kSoulStageBottom,
      bottomNavigationBar: _view == _SoulGameView.gameplay
          ? _buildBannerDock()
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[_kSoulStageTop, _kSoulStageMid, _kSoulStageBottom],
            stops: <double>[0, 0.54, 1],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          key: _effectsKey,
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned(
              top: -100,
              right: -80,
              child: _GlowOrb(color: Color(0x1AC3B6F6), size: 380),
            ),
            const Positioned(
              bottom: -80,
              left: -60,
              child: _GlowOrb(color: Color(0x0FE9C9A2), size: 320),
            ),
            AnimatedBuilder(
              animation: _flashController,
              builder: (BuildContext context, Widget? child) {
                if (_backgroundFlashOpacity <= 0.001) {
                  return const SizedBox.shrink();
                }
                return IgnorePointer(
                  child: ColoredBox(
                    color: const Color(
                      0xFFFFE398,
                    ).withValues(alpha: _backgroundFlashOpacity),
                  ),
                );
              },
            ),
            SafeArea(
              bottom: true,
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
                builder: (BuildContext context, int _, Widget? _) {
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
                      _dragPieceOverlayOffsetFromPosition(piece, _dragPosition);
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
                        scale: _previewRow >= 0 && _previewCol >= 0
                            ? 1.02
                            : 1.0,
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
