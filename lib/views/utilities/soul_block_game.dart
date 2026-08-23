// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/admob_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/app_error_mapper.dart';
import '../premium/premium_store_screen.dart';
import '../../utils/services/games/game_download_service.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';

part 'soul_block_game_rendering_part.dart';
part 'soul_block_game_logic_part.dart';
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
  SoulBlockGame({
    super.key,
    this.storageKeyPrefix = 'soul_block',
    this.gameTitle = 'SOUL BLOCK',
    String? loadErrorMessage,
  }) : loadErrorMessage = loadErrorMessage ??
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
  static const int _trayPreviewGridSize = 5;
  static const double _dragUpdateEpsilon = 1.2;
  static const double _dragOverlayUpdateEpsilon = 2.8;
  static const Duration _autoTrayShuffleInterval = Duration(seconds: 30);
  static const Duration _autoTrayShuffleRetryDelay = Duration(seconds: 3);

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
  Set<Point<int>> _clearingCells = <Point<int>>{};

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
  Uint8List? _bombSfxBytes;
  Uint8List? _streakSfxBytes;
  Uint8List? _bestScoreSfxBytes;
  Uint8List? _memoryBurstSfxBytes;
  List<Uint8List> _comboSfxLevels = <Uint8List>[];

  bool _audioReady = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _smoothGraphics = true;
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
    _adMob.resumeAutoInterstitial();
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
