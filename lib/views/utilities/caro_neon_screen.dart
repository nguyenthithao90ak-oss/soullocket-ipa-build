import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sl_theme.dart';
import '../../models/house_settings.dart';
import '../../services/caro_game_service.dart';
import '../../services/house_service.dart';
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
  String _myRole = 'user1';
  String _user1Name = 'Bạn nam';
  String _user2Name = 'Bạn nữ';
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
      _myRole = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      _user1Name =
          settings.nameU1.trim().isEmpty ? 'Bạn nam' : settings.nameU1.trim();
      _user2Name =
          settings.nameU2.trim().isEmpty ? 'Bạn nữ' : settings.nameU2.trim();
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
    return winLength == 5 ? '5 ô thắng' : '3 ô thắng';
  }

  String _botStyleLabel(_BotStyle style) {
    switch (style) {
      case _BotStyle.gentle:
        return 'Hiền';
      case _BotStyle.balanced:
        return 'Cân bằng';
      case _BotStyle.tricky:
        return 'Tinh quái';
    }
  }

  String _botStyleDescription(_BotStyle style) {
    switch (style) {
      case _BotStyle.gentle:
        return 'Nhường nhẹ hơn, dễ thở hơn và hay chọn nước an toàn.';
      case _BotStyle.balanced:
        return 'Đánh gọn, đều tay và bàn 3 ô cố tình lệch nhịp nhẹ.';
      case _BotStyle.tricky:
        return 'Ưu tiên gài thế nhanh, chặn gắt hơn và ít mắc lỗi hơn.';
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
      if (_botThinking) return 'BOT ĐANG NGHĨ';
      final room = _botRoom;
      if (room == null) return 'BOT SẴN SÀNG';
      return room.isDone ? 'BOT XONG' : 'BOT ĐANG CHƠI';
    }
    if (houseRoom == null) return 'SẴN SÀNG';
    if (houseRoom.isWaiting) return 'ĐANG CHỜ';
    if (houseRoom.isActive) return 'ĐANG CHƠI';
    if (houseRoom.isDraw) return 'HÒA';
    if (houseRoom.isDone) return 'KẾT THÚC';
    return 'SẴN SÀNG';
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
        'Đã mở bàn ${winLength == 5 ? '5 ô thắng' : '3 ô thắng'} và gửi lời mời cho $_partnerName.',
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
      _showSnack(joined ? 'Đã vào bàn cờ.' : 'Không thể tham gia bàn này.');
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
      _showSnack('Đã dọn bàn cờ.');
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
      _showSnack('Đã mở ván mới ${_modeLabel(winLength).toLowerCase()}.');
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
      _showSnack('Chưa tới lượt bạn.');
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
      _showSnack('Bot đang tính nước đi.');
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
      return 'Bắt đầu trong không gian riêng bằng cách tạo bàn mới rồi mời $_partnerName vào chơi.';
    }
    if (room.isWaiting) {
      if (room.createdByRole == _myRole) {
        return 'Đang chờ $_partnerName vào bàn ${_modeLabel(room.winLength)}.';
      }
      return '${_displayNameForRole(room.createdByRole)} đang mời bạn vào bàn ${_modeLabel(room.winLength)}.';
    }
    if (room.isActive) {
      if (room.turnRole == _myRole) {
        return 'Tới lượt bạn. Đặt ${room.symbolForRole(_myRole)} vào ô muốn đánh.';
      }
      return 'Đang chờ ${_displayNameForRole(room.turnRole)} đi tiếp.';
    }
    if (room.isDraw) {
      return 'Ván này hòa. Bạn có thể tạo ván mới ngay.';
    }
    if (room.winnerRole == _myRole) {
      return 'Bạn vừa thắng. Tạo bàn mới để chơi tiếp.';
    }
    return '${_displayNameForRole(room.winnerRole)} đã thắng ván này.';
  }

  String _botStatusText(CaroRoom? room) {
    if (room == null) {
      return 'Bạn có thể chơi trong không gian riêng với người ấy hoặc mở Bot Neon để luyện tay.';
    }
    if (_botThinking) {
      return 'Bot Neon đang tính nước. Bot ưu tiên thắng ngay, chặn thua ngay và giữ thế trung tâm.';
    }
    if (room.isActive && room.turnRole == _myRole) {
      return 'Tới lượt bạn. Bạn đánh X, bot đánh O.';
    }
    if (room.isActive) {
      return 'Bot Neon đang ra nước đi.';
    }
    if (room.isDraw) {
      return 'Ván này hòa. Bạn có thể bắt đầu ván mới ngay.';
    }
    if (room.winnerRole == _myRole) {
      return 'Bạn đã thắng Bot Neon.';
    }
    return 'Bot Neon vừa thắng ván này.';
  }

  String _sceneStatusText(CaroRoom? room) {
    if (_playMode == _CaroPlayMode.bot) {
      if (room == null) {
        return 'Chọn luật chơi rồi bấm Bắt đầu để vào bàn với Bot Neon.';
      }
      if (_botThinking) {
        return 'Bot Neon đang tính nước.';
      }
      if (room.isActive && room.turnRole == _myRole) {
        return 'Tới lượt bạn. Bạn đánh X, bot đánh O.';
      }
      if (room.isActive) {
        return 'Bot Neon đang ra nước.';
      }
      if (room.isDraw) {
        return 'Ván này hòa. Có thể mở ván mới ngay.';
      }
      if (room.winnerRole == _myRole) {
        return 'Bạn đã thắng Bot Neon.';
      }
      return 'Bot Neon thắng ván này.';
    }

    if (room == null) {
      return 'Chọn luật chơi rồi bấm Bắt đầu để mở bàn riêng.';
    }
    if (room.isWaiting) {
      if (room.createdByRole == _myRole) {
        return 'Đã mở bàn ${_modeLabel(room.winLength)}. Chờ $_partnerName vào trận.';
      }
      return '${_displayNameForRole(room.createdByRole)} đã mở bàn ${_modeLabel(room.winLength)} cho bạn.';
    }
    if (room.isActive) {
      if (room.turnRole == _myRole) {
        return 'Tới lượt bạn. Chạm ô trống để đặt ${room.symbolForRole(_myRole)}.';
      }
      return 'Đang chờ ${_displayNameForRole(room.turnRole)} ra nước.';
    }
    if (room.isDraw) {
      return 'Ván này hòa. Có thể mở bàn mới ngay.';
    }
    if (room.winnerRole == _myRole) {
      return 'Bạn vừa thắng ván này.';
    }
    return '${_displayNameForRole(room.winnerRole)} vừa thắng ván này.';
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
          ? 'Bắt đầu nhanh với Bot Neon'
          : 'Bắt đầu trong không gian riêng';
    }
    if (room.isWaiting) {
      return room.createdByRole == _myRole
          ? 'Bàn đã sẵn sàng'
          : 'Có lời mời đang chờ';
    }
    if (room.isDone) {
      return isBotMode ? 'Mở ván mới với Bot' : 'Bắt đầu ván mới';
    }
    return 'Tiếp tục bàn đấu';
  }

  String _launchCardDescription(
    CaroRoom? room,
    bool isBotMode,
    int winLength,
  ) {
    final modeText = _modeLabel(winLength);
    if (room == null) {
      return isBotMode
          ? 'Bấm Bắt đầu rồi chọn 3 ô hoặc 5 ô. Nếu muốn, bạn đổi luôn kiểu bot trước khi vào bàn.'
          : 'Bấm Bắt đầu rồi chọn 3 ô hoặc 5 ô. Sau đó app mở bàn riêng và mời $_partnerName.';
    }
    if (room.isWaiting) {
      return room.createdByRole == _myRole
          ? 'Lời mời đã gửi. Khi $_partnerName vào, tab Bàn đấu sẽ là nơi chơi chính.'
          : 'Người ấy đã mở bàn $modeText. Bạn có thể vào trận ngay từ đây.';
    }
    if (room.isDone) {
      return isBotMode
          ? 'Bấm Bắt đầu để chọn lại luật chơi hoặc kiểu bot rồi mở ván mới.'
          : 'Bấm Bắt đầu để chọn lại 3 ô hoặc 5 ô rồi mở bàn mới.';
    }
    return 'Ván đang diễn ra. Chạm Bàn đấu để quay lại đúng khu chơi chính.';
  }

  String _primaryLaunchLabel(CaroRoom? room, bool isBotMode) {
    if (isBotMode) {
      if (room == null) return 'Bắt đầu với Bot';
      if (room.isDone) return 'Ván mới với Bot';
      return 'Vào bàn đấu';
    }

    if (room == null) return 'Bắt đầu';
    if (room.isWaiting && room.createdByRole != _myRole) {
      return 'Tham gia ngay';
    }
    if (room.isDone) return 'Mở bàn mới';
    return 'Vào bàn đấu';
  }

  String _primaryLaunchCaption(CaroRoom? room, bool isBotMode) {
    if (room == null || room.isDone) {
      return isBotMode
          ? 'Bấm xong sẽ chọn 3 ô, 5 ô và kiểu bot'
          : 'Bấm xong sẽ chọn 3 ô hoặc 5 ô';
    }
    if (!isBotMode && room.isWaiting && room.createdByRole != _myRole) {
      return 'Vào ngay bàn người ấy đã mở';
    }
    return 'Mở lại khu đánh riêng gọn hơn';
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
          ? 'Chưa có ván với Bot. Quay lại Sảnh để bắt đầu nhanh.'
          : 'Chưa có bàn riêng. Quay lại Sảnh để mở bàn.';
    }
    if (room.isWaiting) {
      return room.createdByRole == _myRole
          ? 'Bàn đã mở, đang chờ $_partnerName vào.'
          : 'Lời mời đã sẵn sàng, bạn có thể vào trận ngay.';
    }
    if (room.isActive) {
      return room.turnRole == _myRole
          ? 'Tới lượt bạn. Chạm ô trống để đánh.'
          : 'Đang chờ ${_displayNameForRole(room.turnRole)} ra nước.';
    }
    if (room.isDraw) {
      return 'Ván này hòa. Có thể chơi lại ngay.';
    }
    return room.winnerRole == _myRole
        ? 'Bạn vừa thắng ván này.'
        : '${_displayNameForRole(room.winnerRole)} vừa thắng.';
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
      stream: _caroService.streamRoom(_houseId!),
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
    final roomLabel = isBotMode ? 'BOT NEON' : 'KHÔNG GIAN RIÊNG';

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
                                  ? 'Chơi rõ ràng hơn với khu bắt đầu ở giữa và tab bàn đấu riêng.'
                                  : 'Mở bàn từ Sảnh, sau đó đánh trong tab riêng cho gọn và dễ nhìn.',
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
                                      ? 'BẮT ĐẦU Ở GIỮA'
                                      : 'SẢNH RIÊNG TƯ',
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
                                      ? 'Bàn đấu với Bot Neon'
                                      : 'Bàn đấu riêng',
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
                          ? 'Bắt đầu nhanh với Bot Neon để luyện phản xạ và thử chiến thuật.'
                          : 'Bắt đầu trong không gian riêng để chơi theo thời gian thực cùng người ấy.',
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
                ? 'Bắt đầu cùng Bot Neon'
                : 'Bắt đầu trong không gian riêng',
            description: isBotMode
                ? 'Chạm để vào nhanh ván mới, luyện 3 ô hoặc 5 ô với nhịp chơi gọn và rõ.'
                : 'Tạo bàn riêng, mời người ấy và giữ mọi thao tác ngay trong một màn hình gọn gàng.',
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
