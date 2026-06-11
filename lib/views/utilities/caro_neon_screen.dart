import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sl_theme.dart';
import '../../models/house_settings.dart';
import '../../utils/services/caro_game_service.dart';
import '../../utils/services/house_service.dart';
import '../ui_prefs.dart';

part 'caro_neon/caro_neon_common_widgets.dart';
part 'caro_neon/caro_neon_lounge_widgets.dart';
part 'caro_neon/caro_neon_dialogs.dart';
part 'caro_neon/caro_neon_arena_widgets.dart';
part 'caro_neon/caro_neon_bot_logic.dart';
part 'caro_neon/caro_neon_board.dart';
part 'caro_neon/caro_neon_painters.dart';

enum _CaroPlayMode { house, bot }

enum _CaroSceneTab { lounge, arena }

enum _BotStyle { gentle, balanced, tricky }

class CaroNeonScreen extends StatefulWidget {
  const CaroNeonScreen({super.key});

  @override
  State<CaroNeonScreen> createState() => _CaroNeonScreenState();
}

class _CaroNeonScreenState extends State<CaroNeonScreen>
    with _CaroNeonBotLogic {
  final HouseService _houseService = HouseService();
  final CaroGameService _caroService = CaroGameService.instance;
  @override
  final math.Random _random = math.Random();
  final ScrollController _stageScrollController = ScrollController();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _houseId;
  Stream<CaroRoom?>? _roomStream;
  String _myRole = 'user1';
  String _user1Name = 'Bạn Nam';
  String _user2Name = 'Bạn Nữ';
  int _selectedWinLength = 3;
  bool _soundEnabled = true;
  _CaroPlayMode _playMode = _CaroPlayMode.house;
  _CaroSceneTab _sceneTab = _CaroSceneTab.lounge;
  @override
  _BotStyle _selectedBotStyle = _BotStyle.balanced;
  Map<String, String> _botBoard = <String, String>{};
  String _botStatus = 'idle';
  String _botTurnRole = 'user1';
  String _botWinnerRole = '';
  bool _botIsDraw = false;
  bool _botThinking = false;
  int _botVersion = 0;
  List<String> _botWinningCells = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _stageScrollController.dispose();
    super.dispose();
  }

  void _focusArenaViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_stageScrollController.hasClients) return;
      if (_stageScrollController.offset <= 12) return;
      unawaited(
        _stageScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Future<void> _loadContext() async {
    await UiPrefs.ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    final houseId = await _houseService.getCurrentHouseId();
    final settingsMap = houseId == null
        ? null
        : await _houseService.getHouseSettings(houseId.trim());
    final settings = settingsMap == null
        ? const HouseSettings()
        : HouseSettings.fromMap(settingsMap);

    if (!mounted) return;
    setState(() {
      _houseId = houseId?.trim().isNotEmpty == true ? houseId!.trim() : null;
      if (_houseId != null) {
        _roomStream = _caroService.streamRoom(_houseId!);
      }
      _myRole = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      _user1Name =
          settings.nameU1.trim().isEmpty ? context.tr('util_bnnam_694d9e') : settings.nameU1.trim();
      _user2Name =
          settings.nameU2.trim().isEmpty ? context.tr('util_bnn_14cea6') : settings.nameU2.trim();
      _soundEnabled = UiPrefs.notifier.value.touchSound;
      _isLoading = false;
    });
  }

  String get _myName => _displayNameForRole(_myRole);
  String get _partnerRole => _myRole == 'user2' ? 'user1' : 'user2';
  String get _partnerName => _displayNameForRole(_partnerRole);
  String get _botName => 'Bot Neon';

  String _displayNameForRole(String role) {
    if (role == 'bot') return _botName;
    return role == 'user2' ? _user2Name : _user1Name;
  }

  int _boardSizeFor(int winLength) => winLength == 5 ? 10 : 3;

  String _modeLabel(int winLength) {
    return winLength == 5 ? context.tr('util_5thng_5e66bf') : context.tr('util_3thng_080f34');
  }

  String _botStyleLabel(_BotStyle style) {
    switch (style) {
      case _BotStyle.gentle:
        return context.tr('util_hin_00f6d7');
      case _BotStyle.balanced:
        return context.tr('util_cnbng_25c728');
      case _BotStyle.tricky:
        return context.tr('util_tinhqui_51118a');
    }
  }

  String _botStyleDescription(_BotStyle style) {
    switch (style) {
      case _BotStyle.gentle:
        return context.tr('util_nhngnhhndt_ff8a31');
      case _BotStyle.balanced:
        return context.tr('util_nhgnutayvb_ae1c67');
      case _BotStyle.tricky:
        return context.tr('util_utingithnh_fafbad');
    }
  }

  @override
  double _botMistakeChance({
    required _BotStyle style,
    required int boardSize,
  }) {
    if (boardSize == 3) {
      switch (style) {
        case _BotStyle.gentle:
          return 0.22;
        case _BotStyle.balanced:
          return 0.10;
        case _BotStyle.tricky:
          return 0.04;
      }
    }

    switch (style) {
      case _BotStyle.gentle:
        return 0.14;
      case _BotStyle.balanced:
        return 0.07;
      case _BotStyle.tricky:
        return 0.03;
    }
  }

  @override
  double _botAttackWeight(_BotStyle style) {
    switch (style) {
      case _BotStyle.gentle:
        return 0.95;
      case _BotStyle.balanced:
        return 1.08;
      case _BotStyle.tricky:
        return 1.22;
    }
  }

  @override
  double _botDefenseWeight(_BotStyle style) {
    switch (style) {
      case _BotStyle.gentle:
        return 1.45;
      case _BotStyle.balanced:
        return 1.75;
      case _BotStyle.tricky:
        return 1.55;
    }
  }

  @override
  double _botCenterWeight(_BotStyle style) {
    switch (style) {
      case _BotStyle.gentle:
        return 1.18;
      case _BotStyle.balanced:
        return 1.0;
      case _BotStyle.tricky:
        return 0.9;
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  CaroRoom? get _botRoom {
    if (_botStatus == 'idle') return null;
    return CaroRoom(
      status: _botStatus,
      boardSize: _boardSizeFor(_selectedWinLength),
      winLength: _selectedWinLength,
      turnRole: _botTurnRole,
      playerXRole: _myRole,
      playerORole: 'bot',
      createdByRole: _myRole,
      creatorName: _myName,
      guestName: _botName,
      winnerRole: _botWinnerRole,
      winnerSymbol:
          _botWinnerRole.isEmpty ? '' : (_botWinnerRole == _myRole ? 'X' : 'O'),
      isDraw: _botIsDraw,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      board: Map<String, String>.from(_botBoard),
      winningCells: List<String>.from(_botWinningCells),
    );
  }

  bool _isModeLocked(CaroRoom? houseRoom) {
    final room = _playMode == _CaroPlayMode.bot ? _botRoom : houseRoom;
    return room != null && !room.isDone;
  }

  String _badgeLabel(CaroRoom? houseRoom) {
    if (_playMode == _CaroPlayMode.bot) {
      if (_botThinking) return context.tr('util_botangngh_e997cd');
      final room = _botRoom;
      if (room == null) return context.tr('util_botsnsng_f356f9');
      return room.isDone ? 'BOT XONG' : context.tr('util_botangchi_d26c0a');
    }
    if (houseRoom == null) return context.tr('util_snsng_baaa25');
    if (houseRoom.isWaiting) return context.tr('util_angch_7a6550');
    if (houseRoom.isActive) return context.tr('util_angchi_c83f37');
    if (houseRoom.isDraw) return context.tr('util_ha_7ed50f');
    if (houseRoom.isDone) return context.tr('util_ktthc_1856c2');
    return context.tr('util_snsng_baaa25');
  }

  Future<void> _playTapFx() async {
    HapticFeedback.selectionClick();
    if (!_soundEnabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> _playAlertFx() async {
    HapticFeedback.mediumImpact();
    if (!_soundEnabled) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  Future<void> _saveTouchSoundPreference(bool enabled) async {
    await UiPrefs.saveState(
      UiPrefs.notifier.value.copyWith(touchSound: enabled),
    );
  }

  void _toggleSound() {
    final next = !_soundEnabled;
    setState(() => _soundEnabled = next);
    unawaited(_saveTouchSoundPreference(next));
    if (next) {
      unawaited(_playTapFx());
    }
  }

  void _setPlayMode(_CaroPlayMode mode) {
    if (_playMode == mode) return;
    setState(() {
      _playMode = mode;
      _sceneTab = _CaroSceneTab.lounge;
    });
    unawaited(_playTapFx());
  }

  void _setSceneTab(_CaroSceneTab tab) {
    if (_sceneTab == tab) return;
    setState(() => _sceneTab = tab);
    if (tab == _CaroSceneTab.arena) {
      _focusArenaViewport();
    }
    unawaited(_playTapFx());
  }

  void _openArenaTab() {
    if (_sceneTab == _CaroSceneTab.arena) return;
    setState(() => _sceneTab = _CaroSceneTab.arena);
    _focusArenaViewport();
    unawaited(_playAlertFx());
  }

  void _startBotMatch(int winLength) {
    setState(() {
      _selectedWinLength = winLength;
      _sceneTab = _CaroSceneTab.arena;
      _botBoard = <String, String>{};
      _botStatus = 'active';
      _botTurnRole = _myRole;
      _botWinnerRole = '';
      _botIsDraw = false;
      _botThinking = false;
      _botWinningCells = const <String>[];
      _botVersion++;
    });
    _focusArenaViewport();
    unawaited(_playAlertFx());
  }

  void _clearBotMatch() {
    setState(() {
      _sceneTab = _CaroSceneTab.lounge;
      _botBoard = <String, String>{};
      _botStatus = 'idle';
      _botTurnRole = _myRole;
      _botWinnerRole = '';
      _botIsDraw = false;
      _botThinking = false;
      _botWinningCells = const <String>[];
      _botVersion++;
    });
    unawaited(_playTapFx());
  }

  Future<void> _inviteMatch(int winLength) async {
    final houseId = _houseId;
    if (houseId == null) return;
    await _runBusy(() async {
      await _caroService.inviteMatch(
        houseId: houseId,
        myRole: _myRole,
        myName: _myName,
        partnerName: _partnerName,
        boardSize: _boardSizeFor(winLength),
        winLength: winLength,
      );
      if (!mounted) return;
      setState(() => _sceneTab = _CaroSceneTab.arena);
      _focusArenaViewport();
      unawaited(_playAlertFx());
      _showSnack(
        L10nService().format('util_caro_table_opened_invite', {'mode': winLength == 5 ? context.tr('util_5thng_5e66bf') : context.tr('util_3thng_080f34'), 'name': _partnerName}),
      );
    });
  }

  Future<void> _joinMatch() async {
    final houseId = _houseId;
    if (houseId == null) return;
    await _runBusy(() async {
      final joined = await _caroService.joinMatch(
        houseId: houseId,
        myRole: _myRole,
      );
      if (!mounted) return;
      if (joined) {
        setState(() => _sceneTab = _CaroSceneTab.arena);
        _focusArenaViewport();
      }
      unawaited(_playAlertFx());
      _showSnack(joined ? context.tr('util_vobnc_cb57cb') : context.tr('util_khngththam_254fbc'));
    });
  }

  Future<void> _clearRoom() async {
    final houseId = _houseId;
    if (houseId == null) return;
    await _runBusy(() async {
      await _caroService.clearRoom(houseId);
      if (!mounted) return;
      setState(() => _sceneTab = _CaroSceneTab.lounge);
      unawaited(_playTapFx());
      _showSnack(context.tr('util_dnbnc_221281'));
    });
  }

  Future<void> _replayMatch({
    required bool isBotMode,
    required int winLength,
  }) async {
    if (isBotMode) {
      _startBotMatch(winLength);
      return;
    }

    final houseId = _houseId;
    if (houseId == null) return;

    await _runBusy(() async {
      await _caroService.inviteMatch(
        houseId: houseId,
        myRole: _myRole,
        myName: _myName,
        partnerName: _partnerName,
        boardSize: _boardSizeFor(winLength),
        winLength: winLength,
      );
      if (!mounted) return;
      _showSnack(L10nService().format('util_caro_new_match_opened', {'mode': _modeLabel(winLength).toLowerCase()}));
      unawaited(_playAlertFx());
    });
  }

  Future<void> _exitMatch({
    required bool isBotMode,
  }) async {
    if (isBotMode) {
      _clearBotMatch();
      if (!mounted) return;
      Navigator.of(context).maybePop();
      return;
    }

    final houseId = _houseId;
    if (houseId == null) {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    await _runBusy(() async {
      await _caroService.clearRoom(houseId);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  Future<void> _playMove(CaroRoom room, int row, int col) async {
    final houseId = _houseId;
    if (houseId == null || !room.isActive) return;
    if (room.turnRole != _myRole) {
      unawaited(_playTapFx());
      _showSnack(context.tr('util_chatiltbn_4021b5'));
      return;
    }
    if (room.cellAt(row, col) != null) return;
    unawaited(_playTapFx());

    final result = await _caroService.playMove(
      houseId: houseId,
      myRole: _myRole,
      row: row,
      col: col,
    );
    if (!mounted) return;
    if (result.committed) {
      unawaited(_playAlertFx());
      return;
    }
    if (result.message.isEmpty) return;
    _showSnack(result.message);
  }

  Future<void> _playBotMove(int row, int col) async {
    final room = _botRoom;
    if (room == null || !room.isActive || _botThinking) return;
    if (room.turnRole != _myRole) {
      unawaited(_playTapFx());
      _showSnack(context.tr('util_botangtnhn_9d9a3d'));
      return;
    }

    final key = '$row:$col';
    if (_botBoard.containsKey(key)) return;

    unawaited(_playTapFx());
    final board = Map<String, String>.from(_botBoard)..[key] = 'X';
    final boardSize = _boardSizeFor(_selectedWinLength);
    final winningCells = _findWinningCellsLocal(
      board: board,
      row: row,
      col: col,
      symbol: 'X',
      boardSize: boardSize,
      winLength: _selectedWinLength,
    );

    if (winningCells.isNotEmpty) {
      setState(() {
        _botBoard = board;
        _botStatus = 'done';
        _botTurnRole = _myRole;
        _botWinnerRole = _myRole;
        _botIsDraw = false;
        _botThinking = false;
        _botWinningCells = winningCells;
        _botVersion++;
      });
      unawaited(_playAlertFx());
      return;
    }

    if (board.length >= boardSize * boardSize) {
      setState(() {
        _botBoard = board;
        _botStatus = 'done';
        _botTurnRole = _myRole;
        _botWinnerRole = '';
        _botIsDraw = true;
        _botThinking = false;
        _botWinningCells = const <String>[];
        _botVersion++;
      });
      unawaited(_playAlertFx());
      return;
    }

    final version = _botVersion + 1;
    setState(() {
      _botBoard = board;
      _botStatus = 'active';
      _botTurnRole = 'bot';
      _botWinnerRole = '';
      _botIsDraw = false;
      _botThinking = true;
      _botWinningCells = const <String>[];
      _botVersion = version;
    });

    await Future.delayed(
      Duration(milliseconds: _selectedWinLength == 5 ? 320 : 220),
    );
    if (!mounted || _botVersion != version) return;
    _performBotTurn(version);
  }

  void _performBotTurn(int version) {
    if (!mounted ||
        _botVersion != version ||
        _botStatus != 'active' ||
        !_botThinking ||
        _botTurnRole != 'bot') {
      return;
    }

    final boardSize = _boardSizeFor(_selectedWinLength);
    final move = _chooseBotMove(
      board: _botBoard,
      boardSize: boardSize,
      winLength: _selectedWinLength,
    );
    final key = '${move.x}:${move.y}';
    final board = Map<String, String>.from(_botBoard)..[key] = 'O';
    final winningCells = _findWinningCellsLocal(
      board: board,
      row: move.x,
      col: move.y,
      symbol: 'O',
      boardSize: boardSize,
      winLength: _selectedWinLength,
    );

    if (winningCells.isNotEmpty) {
      setState(() {
        _botBoard = board;
        _botStatus = 'done';
        _botTurnRole = 'bot';
        _botWinnerRole = 'bot';
        _botIsDraw = false;
        _botThinking = false;
        _botWinningCells = winningCells;
        _botVersion++;
      });
      unawaited(_playAlertFx());
      return;
    }

    if (board.length >= boardSize * boardSize) {
      setState(() {
        _botBoard = board;
        _botStatus = 'done';
        _botTurnRole = _myRole;
        _botWinnerRole = '';
        _botIsDraw = true;
        _botThinking = false;
        _botWinningCells = const <String>[];
        _botVersion++;
      });
      unawaited(_playAlertFx());
      return;
    }

    setState(() {
      _botBoard = board;
      _botStatus = 'active';
      _botTurnRole = _myRole;
      _botWinnerRole = '';
      _botIsDraw = false;
      _botThinking = false;
      _botWinningCells = const <String>[];
      _botVersion++;
    });
    unawaited(_playAlertFx());
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusText(CaroRoom? room) {
    if (room == null) {
      return L10nService().format('util_caro_start_private_hint', {'name': _partnerName});
    }
    if (room.isWaiting) {
      if (room.createdByRole == _myRole) {
        return L10nService().format('util_caro_waiting_partner', {'name': _partnerName, 'mode': _modeLabel(room.winLength)});
      }
      return L10nService().format('util_caro_inviting_you', {'name': _displayNameForRole(room.createdByRole), 'mode': _modeLabel(room.winLength)});
    }
    if (room.isActive) {
      if (room.turnRole == _myRole) {
        return L10nService().format('util_caro_your_turn_place', {'symbol': room.symbolForRole(_myRole)});
      }
      return L10nService().format('util_caro_waiting_turn', {'name': _displayNameForRole(room.turnRole)});
    }
    if (room.isDraw) {
      return context.tr('util_vnnyhabnct_77070f');
    }
    if (room.winnerRole == _myRole) {
      return context.tr('util_bnvathngto_d13e30');
    }
    return L10nService().format('util_caro_winner_round', {'name': _displayNameForRole(room.winnerRole)});
  }

  String _botStatusText(CaroRoom? room) {
    if (room == null) {
      return context.tr('util_bncthchitr_6d2bdf');
    }
    if (_botThinking) {
      return context.tr('util_botneonang_45582d');
    }
    if (room.isActive && room.turnRole == _myRole) {
      return context.tr('util_tiltbnbnnh_064c70');
    }
    if (room.isActive) {
      return context.tr('util_botneonang_c4d96c');
    }
    if (room.isDraw) {
      return context.tr('util_vnnyhabnct_8b6042');
    }
    if (room.winnerRole == _myRole) {
      return context.tr('util_bnthngbotn_b2d517');
    }
    return context.tr('util_botneonvat_179a25');
  }

  String _sceneStatusText(CaroRoom? room) {
    if (_playMode == _CaroPlayMode.bot) {
      if (room == null) {
        return context.tr('util_chnlutchir_faf13a');
      }
      if (_botThinking) {
        return context.tr('util_botneonang_76c9e9');
      }
      if (room.isActive && room.turnRole == _myRole) {
        return context.tr('util_tiltbnbnnh_064c70');
      }
      if (room.isActive) {
        return context.tr('util_botneonang_aaa9c1');
      }
      if (room.isDraw) {
        return context.tr('util_vnnyhacthm_c25b46');
      }
      if (room.winnerRole == _myRole) {
        return context.tr('util_bnthngbotn_b2d517');
      }
      return context.tr('util_botneonthn_9d4917');
    }

    if (room == null) {
      return context.tr('util_chnlutchir_1b4278');
    }
    if (room.isWaiting) {
      if (room.createdByRole == _myRole) {
        return L10nService().format('util_caro_opened_waiting', {'mode': _modeLabel(room.winLength), 'name': _partnerName});
      }
      return L10nService().format('util_caro_opened_for_you', {'name': _displayNameForRole(room.createdByRole), 'mode': _modeLabel(room.winLength)});
    }
    if (room.isActive) {
      if (room.turnRole == _myRole) {
        return L10nService().format('util_caro_your_turn_tap', {'symbol': room.symbolForRole(_myRole)});
      }
      return L10nService().format('util_caro_waiting_move', {'name': _displayNameForRole(room.turnRole)});
    }
    if (room.isDraw) {
      return context.tr('util_vnnyhacthm_5b064f');
    }
    if (room.winnerRole == _myRole) {
      return context.tr('util_bnvathngvn_5a2b5b');
    }
    return L10nService().format('util_caro_winner_just_won', {'name': _displayNameForRole(room.winnerRole)});
  }

  Future<void> _openStartChooser({
    required bool isBotMode,
  }) async {
    final result = await showGeneralDialog<_StartSetupResult>(
      context: context,
      barrierLabel: 'start_setup',
      barrierDismissible: true,
      barrierColor: const Color(0xC9060411),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _StartSetupDialog(
          isBotMode: isBotMode,
          selectedWinLength: _selectedWinLength,
          selectedBotStyle: _selectedBotStyle,
          botStyleLabelBuilder: _botStyleLabel,
          botStyleDescriptionBuilder: _botStyleDescription,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedWinLength = result.winLength;
      if (result.botStyle != null) {
        _selectedBotStyle = result.botStyle!;
      }
    });

    if (isBotMode) {
      _startBotMatch(result.winLength);
      return;
    }

    await _inviteMatch(result.winLength);
  }

  Future<void> _handleLoungePrimaryAction({
    required CaroRoom? room,
    required bool isBotMode,
  }) async {
    if (isBotMode) {
      if (room == null || room.isDone) {
        await _openStartChooser(isBotMode: true);
        return;
      }
      _openArenaTab();
      return;
    }

    if (room == null || room.isDone) {
      await _openStartChooser(isBotMode: false);
      return;
    }

    if (room.isWaiting && room.createdByRole != _myRole) {
      await _joinMatch();
      return;
    }

    _openArenaTab();
  }

  String _launchCardTitle(CaroRoom? room, bool isBotMode) {
    if (room == null) {
      return isBotMode
          ? context.tr('util_btunhanhvi_cda8c5')
          : context.tr('util_btutrongkh_329e97');
    }
    if (room.isWaiting) {
      return room.createdByRole == _myRole
          ? context.tr('util_bnsnsng_193b32')
          : context.tr('util_climiangch_b68066');
    }
    if (room.isDone) {
      return isBotMode ? context.tr('util_mvnmivibot_a7f0ea') : context.tr('util_btuvnmi_084494');
    }
    return context.tr('util_tiptcbnu_546b49');
  }

  String _launchCardDescription(
    CaroRoom? room,
    bool isBotMode,
    int winLength,
  ) {
    final modeText = _modeLabel(winLength);
    if (room == null) {
      return isBotMode
          ? context.tr('util_bmbturichn_459e3f')
          : L10nService().format('util_caro_start_invite_desc', {'name': _partnerName});
    }
    if (room.isWaiting) {
      return room.createdByRole == _myRole
          ? L10nService().format('util_caro_invite_sent_desc', {'name': _partnerName})
          : L10nService().format('util_caro_partner_opened_desc', {'mode': modeText});
    }
    if (room.isDone) {
      return isBotMode
          ? context.tr('util_bmbtuchnli_e54a69')
          : context.tr('util_bmbtuchnli_180415');
    }
    return context.tr('util_vnangdinra_6707dd');
  }

  String _primaryLaunchLabel(CaroRoom? room, bool isBotMode) {
    if (isBotMode) {
      if (room == null) return context.tr('util_btuvibot_9e8cf3');
      if (room.isDone) return context.tr('util_vnmivibot_092422');
      return context.tr('util_vobnu_961476');
    }

    if (room == null) return context.tr('util_btu_3cb0f0');
    if (room.isWaiting && room.createdByRole != _myRole) {
      return 'Tham gia ngay';
    }
    if (room.isDone) return context.tr('util_mbnmi_4e809b');
    return context.tr('util_vobnu_961476');
  }

  String _primaryLaunchCaption(CaroRoom? room, bool isBotMode) {
    if (room == null || room.isDone) {
      return isBotMode
          ? context.tr('util_bmxongschn_286a19')
          : context.tr('util_bmxongschn_0bc7a6');
    }
    if (!isBotMode && room.isWaiting && room.createdByRole != _myRole) {
      return context.tr('util_vongaybnng_b2a600');
    }
    return context.tr('util_mlikhunhri_5f3ae7');
  }

  IconData _primaryLaunchIcon(CaroRoom? room, bool isBotMode) {
    if (isBotMode) {
      return room == null || room.isDone
          ? Icons.smart_toy_rounded
          : Icons.grid_view_rounded;
    }
    if (room == null || room.isDone) return Icons.rocket_launch_rounded;
    if (room.isWaiting && room.createdByRole != _myRole) {
      return Icons.login_rounded;
    }
    return Icons.grid_view_rounded;
  }

  String _arenaBannerText(CaroRoom? room, bool isBotMode) {
    if (room == null) {
      return isBotMode
          ? context.tr('util_chacvnvibo_478f79')
          : context.tr('util_chacbnring_e8897c');
    }
    if (room.isWaiting) {
      return room.createdByRole == _myRole
          ? L10nService().format('util_caro_table_waiting_short', {'name': _partnerName})
          : context.tr('util_limisnsngb_b65f70');
    }
    if (room.isActive) {
      return room.turnRole == _myRole
          ? context.tr('util_tiltbnchmt_8fabaf')
          : L10nService().format('util_caro_waiting_move', {'name': _displayNameForRole(room.turnRole)});
    }
    if (room.isDraw) {
      return context.tr('util_vnnyhacthc_71bb39');
    }
    return room.winnerRole == _myRole
        ? context.tr('util_bnvathngvn_5a2b5b')
        : L10nService().format('util_caro_winner_short', {'name': _displayNameForRole(room.winnerRole)});
  }

  Widget _buildScreenBody() {
    if (_isLoading && _houseId == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4EDBFF)),
      );
    }

    if (_playMode == _CaroPlayMode.bot) {
      return _buildStageShell(room: _botRoom, isBotMode: true);
    }

    if (_houseId == null) {
      return _UnavailableState(onRetry: _loadContext);
    }

    return StreamBuilder<CaroRoom?>(
      stream: _roomStream,
      builder: (context, snapshot) {
        return _buildStageShell(room: snapshot.data, isBotMode: false);
      },
    );
  }

  Widget _buildFocusedMatchShell({
    required CaroRoom room,
    required bool isBotMode,
  }) {
    final accent =
        isBotMode ? const Color(0xFFFF5E9E) : const Color(0xFF4EDBFF);
    final roomLabel = isBotMode ? 'BOT NEON' : context.tr('util_khnggianri_165062');

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth.toDouble(), 720.0);
        return SingleChildScrollView(
          controller: _stageScrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      _BackButton(
                        onTap: () {
                          unawaited(_playTapFx());
                          Navigator.of(context).maybePop();
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARO LINK',
                              style: SLTheme.quicksand(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              roomLabel,
                              style: SLTheme.quicksand(
                                fontSize: 12.4,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TinyPill(
                        text: _modeLabel(room.winLength),
                        color: accent,
                        darkText: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ArenaBoardPanel(
                    room: room,
                    winLength: room.winLength,
                    boardSize: room.boardSize,
                    myRole: _myRole,
                    myName: _myName,
                    opponentName: isBotMode ? _botName : _partnerName,
                    isBotMode: isBotMode,
                    compactMode: true,
                    onTapCell: (row, col) {
                      if (isBotMode) {
                        _playBotMove(row, col);
                        return;
                      }
                      _playMove(room, row, col);
                    },
                    onJoin: isBotMode ? null : _joinMatch,
                    onExit: () => _exitMatch(isBotMode: isBotMode),
                    onReplay: () => _replayMatch(
                      isBotMode: isBotMode,
                      winLength: room.winLength,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStageShell({
    required CaroRoom? room,
    required bool isBotMode,
  }) {
    if (room != null) {
      return _buildFocusedMatchShell(room: room, isBotMode: isBotMode);
    }

    final effectiveWinLength = room?.winLength ?? _selectedWinLength;
    final accent =
        isBotMode ? const Color(0xFFFF5E9E) : const Color(0xFF4EDBFF);
    final statusText = _sceneStatusText(room);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth.toDouble(), 980.0);
        return SingleChildScrollView(
          controller: _stageScrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BackButton(
                        onTap: () {
                          unawaited(_playTapFx());
                          Navigator.of(context).maybePop();
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARO LINK',
                              style: SLTheme.quicksand(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isBotMode
                                  ? context.tr('util_chirrnghnv_a3f8f4')
                                  : context.tr('util_mbntsnhsau_bd583a'),
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC7C0E0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _BadgeChip(label: _badgeLabel(room)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PlayTargetTabs(
                          playMode: _playMode,
                          onSelected: _setPlayMode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SoundToggleButton(
                        enabled: _soundEnabled,
                        onTap: _toggleSound,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SceneTabs(
                    sceneTab: _sceneTab,
                    onSelected: _setSceneTab,
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _sceneTab == _CaroSceneTab.lounge
                        ? KeyedSubtree(
                            key: const ValueKey<String>('caro-lounge'),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 620),
                                child: _LaunchStageCard(
                                  badgeText: isBotMode
                                      ? context.tr('util_btugia_789e76')
                                      : context.tr('util_snhringt_111a2d'),
                                  title: _launchCardTitle(room, isBotMode),
                                  description: _launchCardDescription(
                                    room,
                                    isBotMode,
                                    effectiveWinLength,
                                  ),
                                  primaryLabel: _primaryLaunchLabel(
                                    room,
                                    isBotMode,
                                  ),
                                  primaryCaption: _primaryLaunchCaption(
                                    room,
                                    isBotMode,
                                  ),
                                  primaryIcon: _primaryLaunchIcon(
                                    room,
                                    isBotMode,
                                  ),
                                  accent: accent,
                                  onPrimaryTap: () =>
                                      _handleLoungePrimaryAction(
                                    room: room,
                                    isBotMode: isBotMode,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey<String>('caro-arena'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ArenaStageBanner(
                                  title: isBotMode
                                      ? context.tr('util_bnuvibotne_e10d51')
                                      : context.tr('util_bnuring_e5f9ef'),
                                  caption: _arenaBannerText(room, isBotMode),
                                  badgeText: _badgeLabel(room),
                                  accent: accent,
                                ),
                                const SizedBox(height: 16),
                                _ArenaBoardPanel(
                                  room: room,
                                  winLength: effectiveWinLength,
                                  boardSize: room?.boardSize ??
                                      _boardSizeFor(effectiveWinLength),
                                  myRole: _myRole,
                                  isBotMode: isBotMode,
                                  onTapCell: (row, col) {
                                    if (isBotMode) {
                                      _playBotMove(row, col);
                                      return;
                                    }
                                    final activeRoom = room;
                                    if (activeRoom == null) return;
                                    _playMove(activeRoom, row, col);
                                  },
                                ),
                                const SizedBox(height: 16),
                                _HeroPanel(
                                  myName: _myName,
                                  partnerName:
                                      isBotMode ? _botName : _partnerName,
                                  myRole: _myRole,
                                  room: room,
                                  statusText: statusText,
                                ),
                                const SizedBox(height: 16),
                                if (isBotMode)
                                  _ArenaBotActionPanel(
                                    room: room,
                                    selectedWinLength: effectiveWinLength,
                                    isBusy: _botThinking,
                                    styleLabel:
                                        _botStyleLabel(_selectedBotStyle),
                                    styleDescription:
                                        _botStyleDescription(_selectedBotStyle),
                                    onStart: () =>
                                        _openStartChooser(isBotMode: true),
                                    onClear: _clearBotMatch,
                                  )
                                else
                                  _ArenaActionPanel(
                                    room: room,
                                    selectedWinLength: effectiveWinLength,
                                    myRole: _myRole,
                                    isBusy: _isBusy,
                                    onInvite: () =>
                                        _openStartChooser(isBotMode: false),
                                    onJoin: _joinMatch,
                                    onClear: _clearRoom,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildGameShell({
    required CaroRoom? room,
    required bool isBotMode,
  }) {
    final effectiveWinLength = room?.winLength ?? _selectedWinLength;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BackButton(
                onTap: () {
                  unawaited(_playTapFx());
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARO LINK',
                      style: SLTheme.quicksand(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isBotMode
                          ? context.tr('util_btunhanhvi_0c82ac')
                          : context.tr('util_btutrongkh_ecdcca'),
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC7C0E0),
                      ),
                    ),
                  ],
                ),
              ),
              _BadgeChip(label: _badgeLabel(room)),
            ],
          ),
          const SizedBox(height: 16),
          _StartBanner(
            icon: isBotMode ? Icons.smart_toy_rounded : Icons.home_rounded,
            title: isBotMode
                ? context.tr('util_btucngbotn_807130')
                : context.tr('util_btutrongkh_329e97'),
            description: isBotMode
                ? context.tr('util_chmvonhanh_093c90')
                : context.tr('util_tobnringmi_27f48f'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PlayTargetTabs(
                  playMode: _playMode,
                  onSelected: _setPlayMode,
                ),
              ),
              const SizedBox(width: 10),
              _SoundToggleButton(
                enabled: _soundEnabled,
                onTap: _toggleSound,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ModeTabs(
            selectedWinLength: effectiveWinLength,
            roomLocked: _isModeLocked(room),
            onSelected: (value) {
              if (_isModeLocked(room)) return;
              setState(() => _selectedWinLength = value);
              unawaited(_playTapFx());
            },
          ),
          const SizedBox(height: 18),
          _HeroPanel(
            myName: _myName,
            partnerName: isBotMode ? _botName : _partnerName,
            myRole: _myRole,
            room: room,
            statusText: isBotMode ? _botStatusText(room) : _statusText(room),
          ),
          const SizedBox(height: 18),
          if (isBotMode)
            _ArenaBotActionPanel(
              room: room,
              selectedWinLength: effectiveWinLength,
              isBusy: _botThinking,
              styleLabel: _botStyleLabel(_selectedBotStyle),
              styleDescription: _botStyleDescription(_selectedBotStyle),
              onStart: () => _openStartChooser(isBotMode: true),
              onClear: _clearBotMatch,
            )
          else
            _ArenaActionPanel(
              room: room,
              selectedWinLength: effectiveWinLength,
              myRole: _myRole,
              isBusy: _isBusy,
              onInvite: () => _openStartChooser(isBotMode: false),
              onJoin: _joinMatch,
              onClear: _clearRoom,
            ),
          const SizedBox(height: 18),
          _ArenaBoardPanel(
            room: room,
            winLength: effectiveWinLength,
            boardSize: room?.boardSize ?? _boardSizeFor(effectiveWinLength),
            myRole: _myRole,
            isBotMode: isBotMode,
            onTapCell: (row, col) {
              if (isBotMode) {
                _playBotMove(row, col);
                return;
              }
              final activeRoom = room;
              if (activeRoom == null) return;
              _playMove(activeRoom, row, col);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090014),
      body: Stack(
        children: [
          const Positioned.fill(
              child: CustomPaint(painter: _CaroBackdropPainter())),
          SafeArea(child: _buildScreenBody()),
        ],
      ),
    );
  }
}
