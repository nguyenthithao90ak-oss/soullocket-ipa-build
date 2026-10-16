import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/service_locator.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/home_drawing_model.dart';
import 'package:soullocket_app/utils/services/home_drawing_service.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';
import 'package:soullocket_app/widgets/sl_toast.dart';

class HomeDrawingHost extends StatefulWidget {
  const HomeDrawingHost({
    super.key,
    required this.child,
    required this.uid,
    required this.houseId,
    required this.isActiveListenable,
    this.service,
  });

  final Widget child;
  final String? uid;
  final String? houseId;
  final ValueListenable<bool> isActiveListenable;
  final HomeDrawingService? service;

  @override
  State<HomeDrawingHost> createState() => _HomeDrawingHostState();
}

enum _HomeDrawingMode { draw, scroll }

class _HomeDrawingHostState extends State<HomeDrawingHost> {
  late final HomeDrawingService _service =
      widget.service ??
      (locator.isRegistered<HomeDrawingService>()
          ? locator<HomeDrawingService>()
          : HomeDrawingService());
  final ValueNotifier<int> _paintRevision = ValueNotifier<int>(0);
  final ValueNotifier<_HomeDrawingViewport> _viewport =
      ValueNotifier<_HomeDrawingViewport>(
        const _HomeDrawingViewport(offset: 0, contentHeight: 0),
      );
  HomeDrawingLocalState _local = HomeDrawingLocalState.empty();
  HomeDrawingStatus _status = const HomeDrawingStatus.locked();
  StreamSubscription<HomeDrawingBoard>? _boardSubscription;
  Timer? _statusRefreshTimer;
  HomeDrawingStroke? _activeStroke;
  _HomeDrawingMode _mode = _HomeDrawingMode.scroll;
  bool _isHomeActive = false;
  bool _isOpen = false;
  bool _isLoading = false;
  bool _isSaving = false;
  int _scopeGeneration = 0;
  int _serverOffsetMs = 0;
  int _strokeSequence = 0;
  int _selectedColor = 0xffff6f91;
  int _selectedWidth = 8;

  String? get _uid =>
      widget.uid?.trim().isEmpty == true ? null : widget.uid?.trim();
  String? get _houseId =>
      widget.houseId?.trim().isEmpty == true ? null : widget.houseId?.trim();
  bool get _hasScope => _uid != null && _houseId != null;

  static const _colors = <int>[
    0xffff6f91,
    0xffffa726,
    0xffffd54f,
    0xff66bb6a,
    0xff42a5f5,
    0xffab7df6,
    0xff5c4654,
  ];

  @override
  void initState() {
    super.initState();
    _isHomeActive = widget.isActiveListenable.value;
    widget.isActiveListenable.addListener(_onActiveChanged);
    unawaited(_loadScope());
  }

  @override
  void didUpdateWidget(covariant HomeDrawingHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveListenable != widget.isActiveListenable) {
      oldWidget.isActiveListenable.removeListener(_onActiveChanged);
      widget.isActiveListenable.addListener(_onActiveChanged);
      _isHomeActive = widget.isActiveListenable.value;
    }
    if (oldWidget.uid != widget.uid || oldWidget.houseId != widget.houseId) {
      unawaited(_loadScope());
    }
  }

  @override
  void dispose() {
    widget.isActiveListenable.removeListener(_onActiveChanged);
    _boardSubscription?.cancel();
    _statusRefreshTimer?.cancel();
    _paintRevision.dispose();
    _viewport.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    final next = widget.isActiveListenable.value;
    if (_isHomeActive == next) return;
    _isHomeActive = next;
    if (next) {
      _startBoardWatch();
      unawaited(_refreshStatus(force: true));
    } else {
      _boardSubscription?.cancel();
      _boardSubscription = null;
      _statusRefreshTimer?.cancel();
      _statusRefreshTimer = null;
      if (mounted) {
        setState(() {
          _isOpen = false;
          _activeStroke = null;
          _mode = _HomeDrawingMode.scroll;
        });
      }
    }
  }

  Future<void> _loadScope() async {
    final generation = ++_scopeGeneration;
    await _boardSubscription?.cancel();
    _boardSubscription = null;
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;
    _viewport.value = const _HomeDrawingViewport(offset: 0, contentHeight: 0);
    final uid = _uid;
    final houseId = _houseId;
    if (uid == null || houseId == null) {
      if (mounted && generation == _scopeGeneration) {
        setState(() {
          _local = HomeDrawingLocalState.empty();
          _status = const HomeDrawingStatus.locked();
          _isOpen = false;
        });
      }
      return;
    }
    final local = await _service.loadLocal(uid: uid, houseId: houseId);
    if (!mounted || generation != _scopeGeneration) return;
    setState(() {
      _local = local;
      _status = const HomeDrawingStatus.locked();
      _isOpen = false;
    });
    _startBoardWatch();
    unawaited(_refreshStatus(force: true, generation: generation));
  }

  Future<void> _refreshStatus({
    bool force = false,
    int? generation,
  }) async {
    final uid = _uid;
    final houseId = _houseId;
    final expectedGeneration = generation ?? _scopeGeneration;
    if (!_isHomeActive || uid == null || houseId == null) return;
    try {
      final status = await _service.status(
        uid: uid,
        houseId: houseId,
        force: force,
      );
      if (!mounted || expectedGeneration != _scopeGeneration ||
          !_isHomeActive || _uid != uid || _houseId != houseId) {
        return;
      }
      _updateServerOffset(status.serverNow);
      if (status.snapshot != null) _mergeRemoteBoard(status.snapshot!);
      final expiredOpen = _isOpen &&
          !status.available &&
          status.expiresAt > 0 &&
          status.expiresAt <= _serverNow;
      setState(() {
        _status = status;
        if (expiredOpen) {
          _isOpen = false;
          _activeStroke = null;
          _mode = _HomeDrawingMode.scroll;
        }
      });
      _scheduleStatusRefresh(status);
    } catch (_) {
      if (!mounted || expectedGeneration != _scopeGeneration ||
          !_isHomeActive) {
        return;
      }
      _statusRefreshTimer?.cancel();
      _statusRefreshTimer = Timer(
        const Duration(seconds: 30),
        () => unawaited(_refreshStatus(force: true)),
      );
    }
  }

  void _scheduleStatusRefresh(HomeDrawingStatus status) {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = null;
    final target = status.available ? status.expiresAt : status.nextCheckAt;
    if (target <= 0 || !_isHomeActive) return;
    final delayMs = math.max(1000, target - _serverNow);
    _statusRefreshTimer = Timer(
      Duration(milliseconds: delayMs),
      () => unawaited(_refreshStatus(force: true)),
    );
  }

  void _startBoardWatch() {
    final uid = _uid;
    final houseId = _houseId;
    if (!_isHomeActive || uid == null || houseId == null) return;
    _boardSubscription?.cancel();
    final generation = _scopeGeneration;
    _boardSubscription = _service
        .watch(
          uid: uid,
          houseId: houseId,
          isCurrent: () =>
              mounted &&
              generation == _scopeGeneration &&
              _isHomeActive &&
              _uid == uid &&
              _houseId == houseId,
        )
        .listen((board) {
          if (!mounted || generation != _scopeGeneration) return;
          final next = _local.hasDraft
              ? _local.copyWith(confirmed: board, baseRevision: board.revision)
              : HomeDrawingLocalState(confirmed: board);
          setState(() => _local = next);
          unawaited(_service.persist(uid: uid, houseId: houseId, state: next));
        });
  }

  Future<void> _openDrawing() async {
    if (!_hasScope || _isLoading || !_isHomeActive) return;
    final uid = _uid!;
    final houseId = _houseId!;
    unawaited(SoundService().playClick());
    setState(() => _isLoading = true);
    try {
      var status = await _service.status(uid: uid, houseId: houseId);
      _updateServerOffset(status.serverNow);
      if (status.available) {
        status = await _service.open(uid: uid, houseId: houseId);
        _updateServerOffset(status.serverNow);
      }
      if (!mounted) return;
      if (status.snapshot != null) _mergeRemoteBoard(status.snapshot!);
      setState(() {
        _status = status;
        _isOpen = status.available;
        _mode = status.available
            ? _HomeDrawingMode.draw
            : _HomeDrawingMode.scroll;
      });
      if (status.available) {
        unawaited(SoundService().playReward());
        _showMessage(
          L10nService().format('home_drawing_remaining', {
            'minutes':
                '${((_status.expiresAt - _serverNow) / 60000).ceil().clamp(1, 60)}',
          }),
          variant: SLToastVariant.success,
          icon: Icons.auto_awesome_rounded,
        );
      } else {
        _showMessage(
          _lockedMessage(status.reason),
          variant: SLToastVariant.warning,
          icon: Icons.lock_outline_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        final info = AppErrorMapper.resolve(error);
        _showMessage(
          info.message,
          variant: info.isNetworkError
              ? SLToastVariant.warning
              : SLToastVariant.danger,
          icon: info.isNetworkError
              ? Icons.cloud_off_rounded
              : Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mergeRemoteBoard(HomeDrawingBoard board) {
    if (board.revision < _local.confirmed.revision) return;
    final next = _local.hasDraft
        ? _local.copyWith(confirmed: board, baseRevision: board.revision)
        : HomeDrawingLocalState(confirmed: board);
    setState(() => _local = next);
    final uid = _uid;
    final houseId = _houseId;
    if (uid != null && houseId != null) {
      unawaited(_service.persist(uid: uid, houseId: houseId, state: next));
    }
  }

  void _updateServerOffset(int serverNow) {
    if (serverNow <= 0) return;
    _serverOffsetMs = serverNow - DateTime.now().millisecondsSinceEpoch;
  }

  int get _serverNow => DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;

  String _lockedMessage(String reason) {
    if (reason == 'pro') return _tr('home_drawing_remaining');
    return _tr('home_drawing_rules');
  }

  String _tr(String key) => L10nService().translate(key);

  void _showMessage(
    String message, {
    SLToastVariant variant = SLToastVariant.info,
    IconData? icon,
  }) {
    if (!mounted) return;
    SLToast.show(
      context,
      message,
      title: _tr('home_drawing_title'),
      variant: variant,
      icon: icon,
    );
  }

  bool get _expired =>
      _isOpen && _status.expiresAt > 0 && _status.expiresAt <= _serverNow;

  void _startStroke(
    Offset localPosition,
    Size viewportSize,
    double scrollOffset,
    double contentHeight,
  ) {
    if (_isSaving || _expired || _mode != _HomeDrawingMode.draw) return;
    if (_isEraserSelected) {
      _eraseAt(
        localPosition,
        viewportSize,
        scrollOffset,
        contentHeight,
      );
      return;
    }
    if (_local.visibleStrokes.length >= homeDrawingMaxStrokes) {
      _showMessage(_tr('home_drawing_limit'));
      return;
    }
    _activeStroke = HomeDrawingStroke(
      id: _newStrokeId(),
      color: _selectedColor,
      width: _selectedWidth,
      points: [
        _point(
          localPosition,
          viewportSize,
          scrollOffset,
          contentHeight,
        ),
      ],
    );
    unawaited(SoundService().playClick());
    _paintRevision.value++;
  }

  void _updateStroke(
    Offset localPosition,
    Size viewportSize,
    double scrollOffset,
    double contentHeight,
  ) {
    if (_isEraserSelected) {
      _eraseAt(
        localPosition,
        viewportSize,
        scrollOffset,
        contentHeight,
      );
      return;
    }
    final active = _activeStroke;
    if (active == null || _expired || _mode != _HomeDrawingMode.draw) return;
    final point = _point(
      localPosition,
      viewportSize,
      scrollOffset,
      contentHeight,
    );
    final last = active.points.last;
    final distance = math.sqrt(
      math.pow(point.x - last.x, 2) + math.pow(point.y - last.y, 2),
    );
    if (distance < 8) return;
    var points = [...active.points, point];
    if (points.length > homeDrawingMaxPoints) {
      points = [
        for (var index = 0; index < points.length - 1; index += 2)
          points[index],
        points.last,
      ];
    }
    _activeStroke = active.copyWith(points: List.unmodifiable(points));
    _paintRevision.value++;
  }

  void _finishStroke() {
    final active = _activeStroke;
    _activeStroke = null;
    if (active == null || active.points.isEmpty || _expired) {
      _paintRevision.value++;
      return;
    }
    _setDraft([..._local.visibleStrokes, active]);
  }

  HomeDrawingPoint _point(
    Offset position,
    Size viewportSize,
    double scrollOffset,
    double contentHeight,
  ) {
    final width = viewportSize.width <= 0 ? 1 : viewportSize.width;
    final height = contentHeight <= 0 ? viewportSize.height : contentHeight;
    return HomeDrawingPoint(
      (position.dx / width * homeDrawingCoordinateMax).round().clamp(
        0,
        homeDrawingCoordinateMax,
      ),
      ((position.dy + scrollOffset) / height * homeDrawingCoordinateMax)
          .round()
          .clamp(
        0,
        homeDrawingCoordinateMax,
      ),
    );
  }

  String _newStrokeId() {
    _strokeSequence++;
    return 's${DateTime.now().microsecondsSinceEpoch}_$_strokeSequence';
  }

  void _setDraft(List<HomeDrawingStroke> strokes) {
    final uid = _uid;
    final houseId = _houseId;
    final next = _local.copyWith(
      draftStrokes: List.unmodifiable(strokes),
      baseRevision: _local.hasDraft
          ? _local.baseRevision
          : _local.confirmed.revision,
    );
    setState(() => _local = next);
    if (uid != null && houseId != null) {
      unawaited(_service.persist(uid: uid, houseId: houseId, state: next));
    }
    _paintRevision.value++;
  }

  void _undo() {
    if (_local.visibleStrokes.isEmpty) return;
    _setDraft([..._local.visibleStrokes]..removeLast());
  }

  void _clear() {
    if (_local.visibleStrokes.isEmpty) return;
    _setDraft(const []);
  }

  void _eraseAt(
    Offset localPosition,
    Size viewportSize,
    double scrollOffset,
    double contentHeight,
  ) {
    if (_local.visibleStrokes.isEmpty) return;
    final target = _point(
      localPosition,
      viewportSize,
      scrollOffset,
      contentHeight,
    );
    final reversed = _local.visibleStrokes.reversed.toList();
    final index = reversed.indexWhere((stroke) => _hitStroke(stroke, target));
    if (index < 0) return;
    final originalIndex = _local.visibleStrokes.length - 1 - index;
    final strokes = [..._local.visibleStrokes]..removeAt(originalIndex);
    _setDraft(strokes);
  }

  bool _hitStroke(HomeDrawingStroke stroke, HomeDrawingPoint target) {
    final threshold = math.max(32, stroke.width * 3);
    for (final point in stroke.points) {
      if (math.sqrt(
            math.pow(point.x - target.x, 2) + math.pow(point.y - target.y, 2),
          ) <=
          threshold) {
        return true;
      }
    }
    for (var index = 1; index < stroke.points.length; index++) {
      final start = stroke.points[index - 1];
      final end = stroke.points[index];
      final dx = end.x - start.x;
      final dy = end.y - start.y;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : ((target.x - start.x) * dx + (target.y - start.y) * dy) /
                lengthSquared;
      final clamped = t.clamp(0.0, 1.0);
      final closestX = start.x + dx * clamped;
      final closestY = start.y + dy * clamped;
      if (math.sqrt(
            math.pow(target.x - closestX, 2) + math.pow(target.y - closestY, 2),
          ) <=
          threshold) {
        return true;
      }
    }
    return false;
  }

  Future<void> _save() async {
    final uid = _uid;
    final houseId = _houseId;
    if (uid == null || houseId == null || _isSaving) return;
    if (_expired) {
      _showMessage(_tr('home_drawing_expired'));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final result = await _service.save(
        uid: uid,
        houseId: houseId,
        state: _local,
      );
      if (!mounted) return;
      setState(() => _local = result.state);
      if (result.succeeded) {
        unawaited(SoundService().playSaved());
        _showMessage(
          _tr('home_drawing_saved'),
          variant: SLToastVariant.success,
          icon: Icons.check_circle_outline_rounded,
        );
        setState(() {
          _isOpen = false;
          _mode = _HomeDrawingMode.scroll;
          _activeStroke = null;
        });
      } else if (result.status == HomeDrawingSaveStatus.conflict) {
        _showConflict(result.state);
      } else if (result.status == HomeDrawingSaveStatus.rateLimited) {
        _showMessage(
          _tr('home_drawing_failed'),
          variant: SLToastVariant.warning,
          icon: Icons.schedule_rounded,
        );
      } else if (result.status == HomeDrawingSaveStatus.expired) {
        _showMessage(
          _tr('home_drawing_expired'),
          variant: SLToastVariant.warning,
          icon: Icons.timer_off_rounded,
        );
      } else {
        _showMessage(
          _tr('home_drawing_failed'),
          variant: SLToastVariant.danger,
          icon: Icons.cloud_off_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showConflict(HomeDrawingLocalState state) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('home_drawing_conflict')),
        content: Text(_tr('home_drawing_use_latest')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tr('home_drawing_close')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tr('home_drawing_use_latest')),
          ),
        ],
      ),
    );
    if (!mounted || choice != true) return;
    final latest = state.confirmed;
    final next = HomeDrawingLocalState(confirmed: latest);
    setState(() => _local = next);
    final uid = _uid;
    final houseId = _houseId;
    if (uid != null && houseId != null) {
      await _service.persist(uid: uid, houseId: houseId, state: next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasScope = _hasScope;
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: widget.child,
        ),
        if (hasScope &&
            _isHomeActive &&
            (_isOpen || _local.visibleStrokes.isNotEmpty))
          _buildDrawingLayer(context),
        if (hasScope &&
            _isHomeActive &&
            (_status.available || _isOpen))
          _buildPencilButton(context),
        if (hasScope && _isHomeActive && _isOpen) _buildToolbar(context),
        if (hasScope && _isHomeActive && _isOpen)
          _buildDrawingStatusBanner(context),
      ],
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final metrics = notification.metrics;
    final contentHeight = math.max(
      metrics.viewportDimension,
      metrics.viewportDimension + metrics.maxScrollExtent,
    ).toDouble();
    _viewport.value = _HomeDrawingViewport(
      offset: metrics.pixels.clamp(0.0, metrics.maxScrollExtent).toDouble(),
      contentHeight: contentHeight,
    );
    return false;
  }

  Widget _buildPencilButton(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 100;
    final active = _isOpen;
    return Positioned(
      right: 12,
      bottom: bottom,
      child: Semantics(
        button: true,
        label: active ? _tr('home_drawing_title') : _tr('home_drawing_open'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: active ? 60 : 56,
          height: active ? 60 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? const [Color(0xffff8fab), Color(0xffc55b86)]
                  : const [Color(0xffffc3d0), Color(0xffff8fab)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffb54f78).withValues(alpha: 0.28),
                blurRadius: active ? 22 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isLoading ? null : _openDrawing,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        active
                            ? Icons.edit_note_rounded
                            : Icons.auto_fix_high_rounded,
                        key: ValueKey<bool>(active),
                        color: Colors.white,
                        size: active ? 29 : 25,
                      ),
                    ),
                  if (active)
                    const Positioned(
                      right: 8,
                      top: 9,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingStatusBanner(BuildContext context) {
    final remaining = ((_status.expiresAt - _serverNow) / 60000)
        .ceil()
        .clamp(1, 60);
    return Positioned(
      left: 24,
      right: 24,
      top: MediaQuery.paddingOf(context).top + 12,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Material(
            key: ValueKey<int>(_status.expiresAt),
            color: const Color(0xfdfcf7fb),
            elevation: 8,
            shadowColor: const Color(0xffb54f78).withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xffb54f78),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _tr('home_drawing_remaining').replaceAll(
                        '{minutes}',
                        '$remaining',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xff74415d),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingLayer(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top + 68;
    final bottom = media.padding.bottom + 104;
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      bottom: bottom,
      child: ClipRect(
        child: ValueListenableBuilder<_HomeDrawingViewport>(
          valueListenable: _viewport,
          builder: (context, viewport, _) => LayoutBuilder(
            builder: (context, constraints) {
              final viewportSize = constraints.biggest;
              final contentHeight = math.max(
                viewportSize.height,
                viewport.contentHeight,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -viewport.offset,
                    height: contentHeight,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _paintRevision,
                      child: const SizedBox.expand(),
                      builder: (context, revision, child) => CustomPaint(
                        painter: _HomeDrawingPainter(
                          strokes: _local.visibleStrokes,
                          activeStroke: _activeStroke,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _mode == _HomeDrawingMode.scroll,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: (details) => _startStroke(
                          details.localPosition,
                          viewportSize,
                          viewport.offset,
                          contentHeight,
                        ),
                        onPanUpdate: (details) => _updateStroke(
                          details.localPosition,
                          viewportSize,
                          viewport.offset,
                          contentHeight,
                        ),
                        onPanEnd: (_) => _finishStroke(),
                        onTapUp: (details) {
                          if (_mode == _HomeDrawingMode.draw &&
                              _isEraserSelected) {
                            _eraseAt(
                              details.localPosition,
                              viewportSize,
                              viewport.offset,
                              contentHeight,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool get _isEraserSelected => _selectedColor == -1;

  Widget _buildToolbar(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 12;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom,
      child: Material(
        color: dark ? const Color(0xee2d2630) : const Color(0xfdfcf8fa),
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toolbarButton(
                  icon: Icons.edit_rounded,
                  label: _tr('home_drawing_pen'),
                  selected:
                      _mode == _HomeDrawingMode.draw && !_isEraserSelected,
                  onPressed: () => setState(() {
                    _mode = _HomeDrawingMode.draw;
                    if (_isEraserSelected) _selectedColor = _colors.first;
                  }),
                ),
                _toolbarButton(
                  icon: Icons.auto_fix_high_rounded,
                  label: _tr('home_drawing_eraser'),
                  selected: _isEraserSelected,
                  onPressed: () => setState(() {
                    _mode = _HomeDrawingMode.draw;
                    _selectedColor = -1;
                  }),
                ),
                _toolbarButton(
                  icon: Icons.pan_tool_alt_rounded,
                  label: _tr('home_drawing_scroll'),
                  selected: _mode == _HomeDrawingMode.scroll,
                  onPressed: () =>
                      setState(() => _mode = _HomeDrawingMode.scroll),
                ),
                const SizedBox(width: 4),
                for (final color in _colors) _colorButton(color),
                SizedBox(
                  width: 100,
                  child: Slider(
                    min: homeDrawingMinWidth.toDouble(),
                    max: homeDrawingMaxWidth.toDouble(),
                    divisions: homeDrawingMaxWidth - homeDrawingMinWidth,
                    value: _selectedWidth.toDouble(),
                    label: '$_selectedWidth',
                    onChanged: _isEraserSelected
                        ? null
                        : (value) =>
                              setState(() => _selectedWidth = value.round()),
                  ),
                ),
                _toolbarButton(
                  icon: Icons.undo_rounded,
                  label: _tr('home_drawing_undo'),
                  onPressed: _undo,
                ),
                _toolbarButton(
                  icon: Icons.delete_sweep_rounded,
                  label: _tr('home_drawing_clear'),
                  onPressed: _clear,
                ),
                _toolbarButton(
                  icon: Icons.save_rounded,
                  label: _tr('home_drawing_save'),
                  onPressed: _isSaving ? null : _save,
                  filled: true,
                ),
                _toolbarButton(
                  icon: Icons.close_rounded,
                  label: _tr('home_drawing_close'),
                  onPressed: () => setState(() {
                    _isOpen = false;
                    _mode = _HomeDrawingMode.scroll;
                    _activeStroke = null;
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool selected = false,
    bool filled = false,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: selected || filled
            ? Theme.of(context).colorScheme.primary
            : null,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : filled
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
      ),
    );
  }

  Widget _colorButton(int color) {
    final selected = _selectedColor == color;
    return Semantics(
      button: true,
      label: L10nService().format('home_drawing_color', {
        'number': '${_colors.indexOf(color) + 1}',
      }),
      child: IconButton(
        onPressed: () => setState(() {
          _selectedColor = color;
          _mode = _HomeDrawingMode.draw;
        }),
        icon: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(color),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: selected ? 3 : 1,
            ),
          ),
          child: const SizedBox(width: 24, height: 24),
        ),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }
}

class _HomeDrawingPainter extends CustomPainter {
  const _HomeDrawingPainter({required this.strokes, this.activeStroke});

  final List<HomeDrawingStroke> strokes;
  final HomeDrawingStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, size, stroke);
    }
    final active = activeStroke;
    if (active != null) _paintStroke(canvas, size, active);
  }

  void _paintStroke(Canvas canvas, Size size, HomeDrawingStroke stroke) {
    final paint = Paint()
      ..color = Color(stroke.color)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.5, stroke.width / 512 * size.shortestSide);
    final points = stroke.points;
    if (points.length == 1) {
      canvas.drawCircle(
        Offset(
          points.first.normalizedX * size.width,
          points.first.normalizedY * size.height,
        ),
        paint.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    final path = Path()
      ..moveTo(
        points.first.normalizedX * size.width,
        points.first.normalizedY * size.height,
      );
    for (final point in points.skip(1)) {
      path.lineTo(
        point.normalizedX * size.width,
        point.normalizedY * size.height,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeDrawingPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes) ||
      !identical(oldDelegate.activeStroke, activeStroke);
}

class _HomeDrawingViewport {
  const _HomeDrawingViewport({required this.offset, required this.contentHeight});

  final double offset;
  final double contentHeight;

  @override
  bool operator ==(Object other) =>
      other is _HomeDrawingViewport &&
      other.offset == offset &&
      other.contentHeight == contentHeight;

  @override
  int get hashCode => Object.hash(offset, contentHeight);
}
