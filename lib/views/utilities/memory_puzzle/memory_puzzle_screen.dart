import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';
import '../../../utils/screen_activity_mixin.dart';
import 'memory_puzzle_audio.dart';
import 'memory_puzzle_brand_mark.dart';
import 'memory_puzzle_drag_feedback.dart';
import 'memory_puzzle_engine.dart';
import 'memory_puzzle_photo.dart';
import 'memory_puzzle_piece_painter.dart';

/// Màn chơi ghép ảnh nhật ký. Nguồn ảnh và tiến độ được tiêm vào để màn
/// không tự tạo request Firebase trong lúc người chơi kéo mảnh.
class MemoryPuzzleScreen extends StatefulWidget {
  const MemoryPuzzleScreen({
    super.key,
    required this.loadPhoto,
    required this.progressScope,
    this.audio,
    this.loadProgress,
    this.saveProgress,
  });

  final MemoryPuzzlePhotoLoader loadPhoto;
  final String progressScope;
  final MemoryPuzzleAudio? audio;
  final Future<Map<String, dynamic>?> Function()? loadProgress;
  final Future<void> Function(Map<String, dynamic>)? saveProgress;

  @override
  State<MemoryPuzzleScreen> createState() => _MemoryPuzzleScreenState();
}

class _MemoryPuzzleScreenState extends State<MemoryPuzzleScreen>
    with ScreenActivityMixin {
  MemoryPuzzleEngine? _engine;
  MemoryPuzzlePhoto? _photo;
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _level = 1;
  int _seed = 0;
  bool _loading = true;
  bool _busy = false;
  bool _showReference = false;
  bool _musicEnabled = true;
  bool _effectsEnabled = true;
  bool _completed = false;
  bool get _foreground => isScreenActive;
  bool _saveErrorShown = false;
  final GlobalKey _boardKey = GlobalKey();

  Future<MemoryPuzzlePhoto?> _loadPhotoWithTimeout({
    String? excludePhotoId,
    String? preferredPhotoId,
  }) {
    final source = widget.loadPhoto(
      excludePhotoId: excludePhotoId,
      preferredPhotoId: preferredPhotoId,
    );
    var timedOut = false;
    unawaited(
      source.then<void>((photo) {
        if (timedOut) photo?.image.dispose();
      }, onError: (Object error, StackTrace stackTrace) {}),
    );
    return source.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        timedOut = true;
        throw TimeoutException('memory_puzzle_photo_timeout');
      },
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_restoreOrStart());
  }

  Future<void> _restoreOrStart() async {
    Map<String, dynamic>? saved;
    try {
      final loadProgress = widget.loadProgress;
      saved = loadProgress == null
          ? null
          : await loadProgress().timeout(const Duration(seconds: 12));
    } catch (_) {
      saved = null;
    }
    if (!mounted) return;
    MemoryPuzzleEngine? restored;
    String? photoId;
    if (saved != null && saved['scope'] == widget.progressScope) {
      try {
        final rawEngine = saved['engine'];
        if (rawEngine is Map &&
            saved['photoId'] is String &&
            (saved['photoId'] as String).isNotEmpty) {
          restored = MemoryPuzzleEngine.fromJson(
            Map<String, dynamic>.from(rawEngine),
          );
          _level = restored.difficulty.level;
          _seed = restored.seed;
          _elapsedSeconds = ((saved['elapsedSeconds'] as num?)?.toInt() ?? 0)
              .clamp(0, 1000000000);
          photoId = saved['photoId'] as String?;
          _musicEnabled = saved['musicEnabled'] != false;
          _effectsEnabled = saved['effectsEnabled'] != false;
        }
      } catch (_) {
        restored = null;
      }
    }
    final engine = restored ?? _newEngine(1);
    MemoryPuzzlePhoto? photo;
    try {
      photo = await _loadPhotoWithTimeout(preferredPhotoId: photoId);
    } catch (_) {
      _showMessage('memory_puzzle_photo_failed');
    }
    if (!mounted) {
      photo?.image.dispose();
      return;
    }
    if (photo == null) {
      setState(() {
        // Không trộn snapshot cũ với ảnh khác khi ảnh khôi phục không còn.
        _engine = engine;
        _loading = false;
      });
      return;
    }
    _engine = engine;
    _photo = photo;
    _completed = engine.isComplete;
    _loading = false;
    setState(() {});
    unawaited(_sound((audio) => audio.setEffectsEnabled(_effectsEnabled)));
    if (!_completed && _foreground) {
      unawaited(_sound((audio) => audio.setMusicEnabled(_musicEnabled)));
    }
    if (!_completed) {
      _startTimer();
    }
    await _persist();
  }

  MemoryPuzzleEngine _newEngine(int level) {
    _level = level;
    _seed = DateTime.now().microsecondsSinceEpoch ^ (level * 7919);
    _elapsedSeconds = 0;
    return MemoryPuzzleEngine(level: level, seed: _seed);
  }

  void _startTimer() {
    if (!_foreground || _completed || _photo == null) return;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_foreground || _busy || _completed || _photo == null) {
        return;
      }
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds % 5 == 0) unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    final engine = _engine;
    final photo = _photo;
    if (engine == null || photo == null || widget.saveProgress == null) return;
    try {
      await widget
          .saveProgress!({
            'scope': widget.progressScope,
            'photoId': photo.id,
            'level': engine.difficulty.level,
            'elapsedSeconds': _elapsedSeconds,
            'engine': engine.toJson(),
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'musicEnabled': _musicEnabled,
            'effectsEnabled': _effectsEnabled,
          })
          .timeout(const Duration(seconds: 10));
      _saveErrorShown = false;
    } catch (_) {
      if (!_saveErrorShown) _showMessage('memory_puzzle_save_failed');
      _saveErrorShown = true;
    }
  }

  Future<void> _sound(Future<void> Function(MemoryPuzzleAudio) action) async {
    final audio = widget.audio;
    if (audio == null) return;
    try {
      await action(audio);
    } catch (_) {
      /* Audio không chặn gameplay. */
    }
  }

  Future<void> _loadNewPhoto({bool advanceLevel = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final old = _photo;
    try {
      var photo = await _loadPhotoWithTimeout(excludePhotoId: old?.id);
      // Khi offline chỉ còn một ảnh đã cache, vẫn cho người chơi lên màn
      // tiếp theo bằng ảnh đó thay vì khóa tiến trình; nếu có ảnh khác thì
      // luôn ưu tiên ảnh khác ở lần gọi đầu.
      if (photo == null && advanceLevel && old != null) {
        photo = await _loadPhotoWithTimeout();
      }
      if (!mounted) {
        photo?.image.dispose();
        return;
      }
      if (photo == null) {
        _showMessage('memory_puzzle_no_other_photo');
        return;
      }
      _timer?.cancel();
      _timer = null;
      setState(() {
        _photo = photo;
        _engine = _newEngine(advanceLevel ? _level + 1 : _level);
        _completed = false;
        _showReference = false;
      });
      old?.image.dispose();
      _startTimer();
      if (_foreground) {
        unawaited(_sound((audio) => audio.setMusicEnabled(_musicEnabled)));
      }
      await _persist();
    } catch (_) {
      _showMessage('memory_puzzle_photo_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restart() async {
    final old = _engine;
    if (old == null || _busy) return;
    setState(() {
      _engine = _newEngine(old.difficulty.level);
      _completed = false;
    });
    _startTimer();
    if (_foreground) {
      unawaited(_sound((audio) => audio.setMusicEnabled(_musicEnabled)));
    }
    await _persist();
  }

  Future<void> _dropPiece(int id, Offset globalOffset) async {
    final engine = _engine;
    final board = _boardKey.currentContext?.findRenderObject();
    if (engine == null || board is! RenderBox || _busy || _completed) return;
    final local = board.globalToLocal(globalOffset);
    // `DragTargetDetails.offset` là góc trên trái của feedback; đưa tâm mảnh
    // về vị trí ngón tay để vùng hút dễ dùng trên màn hình nhỏ.
    final centered =
        local + const Offset(puzzleDragSize / 2, puzzleDragSize / 2);
    final size = board.size;
    final placed = engine.tryPlace(
      id,
      centerX:
          (centered.dx - puzzleBoardInset) /
          (size.width - puzzleBoardInset * 2),
      centerY:
          (centered.dy - puzzleBoardInset) /
          (size.height - puzzleBoardInset * 2),
    );
    if (!placed) {
      unawaited(_sound((audio) => audio.playPickup()));
      if (mounted) _showMessage('memory_puzzle_try_again');
      return;
    }
    await _afterPlacement();
  }

  Future<void> _afterPlacement() async {
    if (!mounted) return;
    setState(() => _completed = _engine!.isComplete);
    if (_completed) {
      _timer?.cancel();
      _timer = null;
      unawaited(
        _sound((audio) async {
          await audio.pause();
          await audio.playComplete();
        }),
      );
    } else {
      unawaited(_sound((audio) => audio.playSnap()));
    }
    await _persist();
  }

  Future<void> _rotate(int id) async {
    if (_busy || _completed || _engine?.rotatePiece(id) != true) return;
    unawaited(_sound((audio) => audio.playPickup()));
    setState(() {});
    await _persist();
  }

  Future<void> _useHint() async {
    if (_busy || _completed) return;
    final id = _engine?.useHint();
    if (id == null) {
      _showMessage('memory_puzzle_no_hints');
      return;
    }
    await _afterPlacement();
  }

  void _showMessage(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  @override
  void onScreenActivityChanged(bool active) {
    if (!active) {
      _timer?.cancel();
      _timer = null;
      unawaited(_sound((audio) => audio.pause()));
      unawaited(_persist());
    } else if (!_completed && _photo != null) {
      _startTimer();
      unawaited(_sound((audio) => audio.setMusicEnabled(_musicEnabled)));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _photo?.image.dispose();
    unawaited(_sound((audio) => audio.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final engine = _engine;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF111827) : const Color(0xFFF7F4EE),
      appBar: AppBar(
        title: Row(
          children: [
            const MemoryPuzzleBrandMark(size: 30),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                context.tr('memory_puzzle_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: context.tr('memory_puzzle_reference'),
            onPressed: _photo == null
                ? null
                : () => setState(() => _showReference = !_showReference),
            icon: Icon(
              _showReference
                  ? Icons.visibility_rounded
                  : Icons.visibility_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: Text(context.tr('memory_puzzle_loading')))
            : _photo == null || engine == null
            ? _buildEmpty(dark)
            : _buildGame(dark, engine),
      ),
    );
  }

  Widget _buildEmpty(bool dark) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 54,
            color: dark ? Colors.white70 : Colors.brown,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('memory_puzzle_no_photo'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _loadNewPhoto,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('memory_puzzle_retry')),
          ),
        ],
      ),
    ),
  );

  Widget _buildGame(bool dark, MemoryPuzzleEngine engine) {
    final photo = _photo!;
    final text = dark ? Colors.white : const Color(0xFF342B2B);
    final muted = dark ? Colors.white70 : const Color(0xFF766B6B);
    final progress = (engine.progress * 100).round();
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSide = math.min(
          math.min(constraints.maxWidth - 32, 420.0),
          constraints.maxHeight * .58,
        );
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Text(
                      context.tr('memory_puzzle_subtitle'),
                      style: TextStyle(color: muted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          key: const ValueKey('puzzle-music'),
                          selected: _musicEnabled,
                          avatar: Icon(
                            _musicEnabled
                                ? Icons.music_note_rounded
                                : Icons.music_off_rounded,
                            size: 18,
                          ),
                          label: Text(context.tr('memory_puzzle_music')),
                          onSelected: (enabled) {
                            setState(() => _musicEnabled = enabled);
                            unawaited(
                              _sound(
                                (audio) => audio.setMusicEnabled(
                                  enabled && _foreground && !_completed,
                                ),
                              ),
                            );
                            unawaited(_persist());
                          },
                        ),
                        FilterChip(
                          key: const ValueKey('puzzle-effects'),
                          selected: _effectsEnabled,
                          avatar: Icon(
                            _effectsEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            size: 18,
                          ),
                          label: Text(context.tr('memory_puzzle_effects')),
                          onSelected: (enabled) {
                            setState(() => _effectsEnabled = enabled);
                            unawaited(
                              _sound(
                                (audio) => audio.setEffectsEnabled(enabled),
                              ),
                            );
                            unawaited(_persist());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _stat(
                          context.tr('memory_puzzle_level'),
                          '${engine.difficulty.level}',
                          text,
                        ),
                        _stat(
                          context.tr('memory_puzzle_progress'),
                          '$progress%',
                          text,
                        ),
                        _stat(
                          context.tr('memory_puzzle_timer'),
                          _formatTime(_elapsedSeconds),
                          text,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: engine.progress,
                        minHeight: 5,
                        color: const Color(0xFF9F765A),
                        backgroundColor: muted.withValues(alpha: .12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (photo.offline || photo.fromCache)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              photo.offline
                                  ? Icons.cloud_off_rounded
                                  : Icons.offline_bolt_rounded,
                              size: 16,
                              color: muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                context.tr(
                                  photo.offline
                                      ? 'memory_puzzle_offline'
                                      : 'memory_puzzle_cached',
                                ),
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PuzzleBoardHeader(
                height: boardSide + 14,
                background: dark
                    ? const Color(0xFF111827)
                    : const Color(0xFFF7F4EE),
                child: Center(
                  child: SizedBox.square(
                    dimension: boardSide,
                    child: _buildBoard(engine, photo.image),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('puzzle-hint'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed:
                                _busy ||
                                    _completed ||
                                    engine.hintsUsed >=
                                        engine.difficulty.hintBudget
                                ? null
                                : _useHint,
                            icon: const Icon(Icons.lightbulb_outline_rounded),
                            label: Text(
                              '${context.tr('memory_puzzle_hint')} · ${engine.difficulty.hintBudget - engine.hintsUsed}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          key: const ValueKey('puzzle-restart'),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: _busy ? null : _restart,
                          tooltip: context.tr('memory_puzzle_restart'),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          key: const ValueKey('puzzle-change-photo'),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: _busy ? null : _loadNewPhoto,
                          tooltip: context.tr('memory_puzzle_next_photo'),
                          icon: const Icon(Icons.photo_library_outlined),
                        ),
                      ],
                    ),
                    if (_showReference) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: RawImage(
                            image: photo.image,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_completed) _buildComplete(engine, text),
                    Text(
                      context.tr('memory_puzzle_pieces'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('memory_puzzle_gesture_guide'),
                      style: TextStyle(color: muted, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    _buildTray(engine, photo.image),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: .7)),
        ),
      ],
    ),
  );

  Widget _buildBoard(MemoryPuzzleEngine engine, ui.Image image) {
    return DecoratedBox(
      key: _boardKey,
      decoration: BoxDecoration(
        color: const Color(0xFF202A3D),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: DragTarget<int>(
        onAcceptWithDetails: (details) =>
            _dropPiece(details.data, details.offset),
        builder: (context, candidates, rejected) => Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: CustomPaint(
                key: const ValueKey('puzzle-board'),
                painter: MemoryPuzzleBoardPainter(image: image, engine: engine),
              ),
            ),
            if (candidates.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFEAC98B),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTray(MemoryPuzzleEngine engine, ui.Image image) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final id in engine.trayOrder)
        if (!engine.pieces[id].placed)
          LongPressDraggable<int>(
            key: ValueKey('puzzle-piece-$id'),
            data: id,
            delay: const Duration(milliseconds: 150),
            dragAnchorStrategy: (_, _, _) =>
                const Offset(puzzleDragSize / 2, puzzleDragSize / 2),
            maxSimultaneousDrags: 1,
            onDragStarted: () =>
                unawaited(_sound((audio) => audio.playPickup())),
            feedback: MemoryPuzzleDragFeedback(
              image: image,
              piece: engine.pieces[id],
              rows: engine.difficulty.rows,
              cols: engine.difficulty.cols,
              reduceMotion:
                  MediaQuery.maybeOf(context)?.disableAnimations ?? false,
            ),
            childWhenDragging: Opacity(
              opacity: .25,
              child: _trayPiece(engine.pieces[id], image),
            ),
            child: _trayPiece(engine.pieces[id], image),
          ),
    ],
  );

  Widget _trayPiece(MemoryPuzzlePiece piece, ui.Image image) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: 72,
        child: CustomPaint(
          painter: MemoryPuzzlePiecePainter(
            image: image,
            piece: piece,
            rows: _engine!.difficulty.rows,
            cols: _engine!.difficulty.cols,
          ),
        ),
      ),
      if (piece.quarterTurns != 0 || _engine!.difficulty.rotationEnabled)
        SizedBox(
          height: 48,
          width: 64,
          child: IconButton(
            key: ValueKey('puzzle-rotate-${piece.id}'),
            onPressed: () => _rotate(piece.id),
            padding: EdgeInsets.zero,
            tooltip: context.tr('memory_puzzle_rotate'),
            icon: const Icon(Icons.rotate_right_rounded, size: 18),
          ),
        ),
    ],
  );

  Widget _buildComplete(MemoryPuzzleEngine engine, Color color) => Card(
    key: const ValueKey('puzzle-complete'),
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            context.tr('memory_puzzle_complete'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Icon(
                  i < engine.stars(_elapsedSeconds)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFD2A95F),
                  size: 32,
                ),
            ],
          ),
          Text(
            L10nScope.of(context).format('memory_puzzle_stars', {
              'stars': engine.stars(_elapsedSeconds),
            }),
            style: TextStyle(color: color.withValues(alpha: .75)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('puzzle-next-level'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _busy ? null : () => _loadNewPhoto(advanceLevel: true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(context.tr('memory_puzzle_next_level')),
          ),
        ],
      ),
    ),
  );

  String _formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Bàn ghép luôn còn trên màn hình khi người chơi cuộn khay nhiều mảnh.
class _PuzzleBoardHeader extends SliverPersistentHeaderDelegate {
  const _PuzzleBoardHeader({
    required this.height,
    required this.background,
    required this.child,
  });
  final double height;
  final Color background;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: background, child: child);
  @override
  bool shouldRebuild(covariant _PuzzleBoardHeader oldDelegate) => true;
}
