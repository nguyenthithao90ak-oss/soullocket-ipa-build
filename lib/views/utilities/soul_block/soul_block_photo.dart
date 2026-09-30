// ignore_for_file: invalid_use_of_protected_member
part of '../soul_block_game.dart';

extension _SoulBlockPhotoExperience on _SoulBlockGameState {
  Future<ui.Image> _decodeBoardPhoto(String url) async {
    // Một ảnh giải mã dùng chung cho bàn, khay và các mảnh vỡ.
    final provider = ResizeImage(
      NetworkImage(url),
      width: 1024,
      height: 1024,
      policy: ResizeImagePolicy.fit,
    );
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image.clone());
        info.dispose();
      },
      onError: (Object error, StackTrace? stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    try {
      return await completer.future.timeout(const Duration(seconds: 12));
    } finally {
      stream.removeListener(listener);
      await provider.evict();
    }
  }

  void _clearDiaryPhoto() {
    _photoRequest++;
    final old = _boardPhoto;
    _explosionController.stop();
    _memoryBurstController.stop();
    setState(() {
      _boardPhoto = null;
      _photoId = null;
      _photoLoading = false;
      _photoUnavailable = true;
      _photoNeedsNext = false;
      _newGamesSincePhotoChange = 0;
      _memoryBurstSnapshot = null;
      _explosionParticles = <_ExplosionParticle>[];
      _draggedPieceOverlay = null;
    });
    _cancelDrag();
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> _loadDiaryPhoto({bool next = false}) async {
    if (!mounted) return;
    final houseId = _houseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (houseId == null || uid == null) {
      _clearDiaryPhoto();
      return;
    }
    final request = ++_photoRequest;
    final bool advanceRequested = next || _photoNeedsNext;
    final String? previousPhotoId = _photoId;
    bool isCurrent() =>
        mounted &&
        request == _photoRequest &&
        FirebaseAuth.instance.currentUser?.uid == uid &&
        _houseId == houseId;
    setState(() {
      _photoLoading = true;
      _photoUnavailable = false;
      _photoNeedsNext = advanceRequested;
    });
    try {
      final ordered = await _memoryService.candidates(
        houseId,
        preferredId: _photoId,
        next: advanceRequested,
      );
      if (!isCurrent()) return;
      final loadingTime = Stopwatch()..start();
      for (final candidate in ordered.take(8)) {
        if (loadingTime.elapsed > const Duration(seconds: 24)) break;
        if (!isCurrent()) return;
        ui.Image? decoded;
        try {
          final memory = await _memoryService
              .resolve(houseId, candidate)
              .timeout(const Duration(seconds: 8));
          if (!isCurrent()) return;
          if (memory == null) continue;
          decoded = await _decodeBoardPhoto(memory.url);
          // Chờ thao tác và cả hai hiệu ứng kết thúc trước khi đổi ảnh.
          while (isCurrent() &&
              (_draggingPiece != null ||
                  _isBusy ||
                  _explosionController.isAnimating ||
                  _memoryBurstController.isAnimating)) {
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
          if (!isCurrent()) {
            decoded.dispose();
            return;
          }
          final old = _boardPhoto;
          setState(() {
            _boardPhoto = decoded;
            _photoId = memory.id;
            _photoLoading = false;
            _photoNeedsNext = false;
            _photoUnavailable = false;
            _draggedPieceOverlay = null;
            if (advanceRequested) {
              _newGamesSincePhotoChange = 0;
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
          if (advanceRequested && memory.id == previousPhotoId && mounted) {
            _showSnackBar(context.tr('soul_block_photo_no_other'));
          }
          if (_view == _SoulGameView.gameplay) {
            unawaited(_memoryService.remember(houseId, memory.id, uid: uid));
            unawaited(_persistSavedRun());
          }
          return;
        } catch (_) {
          decoded?.dispose();
          if (!isCurrent()) return;
        }
      }
      if (isCurrent()) {
        setState(() {
          _photoLoading = false;
          _photoUnavailable = true;
        });
        if (advanceRequested && mounted) {
          _showSnackBar(context.tr('soul_block_photo_no_other'));
        }
      }
    } catch (error) {
      if (!isCurrent()) return;
      debugPrint(AppErrorMapper.resolve(error).message);
      setState(() {
        _photoLoading = false;
        _photoUnavailable = true;
      });
    }
  }

  Future<void> _requestDiaryPhotoChange() async {
    if (_photoLoading ||
        _isBusy ||
        _draggingPiece != null ||
        _isShowingFullscreenAd ||
        _houseId?.trim().isEmpty != false) {
      return;
    }
    await _loadDiaryPhoto(next: true);
  }

  Point<int> _piecePhotoAnchor(_SoulPieceOption piece) {
    final move = _recommendMoveFor(_board, [piece]);
    if (move != null) return Point(move.col, move.row);
    // Mảnh chưa có chỗ đặt vẫn giữ cùng tỉ lệ ảnh của bàn.
    return Point(
      (_boardSize - piece.template.width) ~/ 2,
      (_boardSize - piece.template.height) ~/ 2,
    );
  }

  Rect _boardPhotoRect(int row, int col) {
    final side = _boardSize.toDouble();
    return Rect.fromLTWH(col / side, row / side, 1 / side, 1 / side);
  }

  Rect _piecePhotoRect(
    _SoulPieceOption piece,
    int x,
    int y, {
    int? boardRow,
    int? boardCol,
  }) {
    if (boardRow != null && boardCol != null) {
      return _boardPhotoRect(boardRow, boardCol);
    }
    final anchor = _piecePhotoAnchor(piece);
    return _boardPhotoRect(anchor.y + y, anchor.x + x);
  }

  Rect _tilePhotoRect(_SoulTile tile, int row, int col) =>
      _boardPhotoRect(row, col);

  Widget _buildPhotoTile({
    required double width,
    required double height,
    required Rect crop,
    bool preview = false,
    bool clearing = false,
    bool floating = false,
    bool gold = false,
    bool bomb = false,
  }) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: clearing ? 0.0 : 1.0),
      duration: Duration(milliseconds: reduced ? 0 : 150),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.scale(
        scale: clearing ? 0.82 + value * 0.18 : 1,
        child: CustomPaint(
          size: Size(width, height),
          painter: _SoulPhotoTilePainter(
            image: _boardPhoto,
            crop: crop,
            preview: preview,
            clearing: clearing ? 1 - value : 0,
            floating: floating,
            gold: gold,
            bomb: bomb,
          ),
          child: child,
        ),
      ),
      child: gold || bomb
          ? Center(
              child: Icon(
                gold ? Icons.star_rounded : Icons.local_fire_department_rounded,
                size: min(width, height) * 0.42,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            )
          : null,
    );
  }

  Widget _buildPhotoStatus({required bool compact}) {
    if (_boardPhoto == null && !_photoLoading && !_photoUnavailable) {
      return const SizedBox.shrink();
    }
    final key = _photoLoading
        ? 'soul_block_photo_loading'
        : _photoUnavailable
        ? (_boardPhoto == null
              ? 'soul_block_photo_empty'
              : 'soul_block_photo_retry')
        : 'soul_block_photo_cycle';
    final bool canChange =
        !_photoLoading &&
        !_isBusy &&
        _draggingPiece == null &&
        !_isShowingFullscreenAd &&
        _houseId?.trim().isNotEmpty == true;
    return Material(
      color: Colors.white.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _photoUnavailable ? () => unawaited(_loadDiaryPhoto()) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 30,
                    child: _boardPhoto == null
                        ? Icon(
                            _photoLoading
                                ? Icons.hourglass_top_rounded
                                : Icons.photo_library_outlined,
                            color: _kSoulChrome,
                            size: 18,
                          )
                        : RawImage(image: _boardPhoto, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(key),
                    style: SLTheme.quicksand(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: _kSoulMuted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('soul_block_photo_change'),
                  onPressed: canChange
                      ? () => unawaited(_requestDiaryPhotoChange())
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: Icon(
                    _photoUnavailable
                        ? Icons.refresh_rounded
                        : Icons.swap_horiz_rounded,
                    size: 18,
                    color: _kSoulChrome,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _burstPhotoCells(
    List<List<_SoulTile?>> source,
    Set<Point<int>> cells, {
    required int clearedCount,
  }) {
    if (cells.isEmpty || MediaQuery.disableAnimationsOf(context)) return;
    _updateBoardMetrics();
    if (_boardCellExtent <= 0) return;
    final renderBox = _effectsKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) return;
    final origin = renderBox.localToGlobal(Offset.zero);
    final points = cells.where((c) => source[c.y][c.x] != null).toList();
    if (points.isEmpty) return;
    final intensity = clearedCount.clamp(1, 4);
    final cap = switch (_performanceProfile.tier) {
      _SoulBlockPerformanceTier.low => 12,
      _SoulBlockPerformanceTier.mid => 24,
      _SoulBlockPerformanceTier.high => 36,
    };
    final step = max(1, (points.length * 2 / cap).ceil());
    final particles = <_ExplosionParticle>[];
    final center =
        points
            .map(
              (c) => _boardCellCenter(c.y.toDouble(), c.x.toDouble()) - origin,
            )
            .reduce((a, b) => a + b) /
        points.length.toDouble();
    for (var index = 0; index < points.length; index += step) {
      final cell = points[index];
      final tile = source[cell.y][cell.x]!;
      final position =
          _boardCellCenter(cell.y.toDouble(), cell.x.toDouble()) - origin;
      for (var half = 0; half < 2; half++) {
        final angle =
            atan2(position.dy - center.dy, position.dx - center.dx) +
            (half == 0 ? -.55 : .55);
        final distance =
            24 + intensity * 5 + _random.nextDouble() * (40 + intensity * 5);
        particles.add(
          _ExplosionParticle(
            startOffset: position,
            endOffset:
                position +
                Offset(cos(angle) * distance, sin(angle) * distance - 22),
            color: Colors.white,
            size: _boardCellExtent,
            rotation: 0,
            twist: (half == 0 ? -1 : 1) * (.18 + _random.nextDouble() * .3),
            opacity: .98,
            delayFraction: (index % _boardSize) * .009,
            isShard: true,
            simpleDraw: false,
            shapeType: 4 + half,
            photoRect: _tilePhotoRect(tile, cell.y, cell.x),
          ),
        );
      }
    }
    setState(() {
      _explosionParticles = particles;
      _explosionCenter = center;
      _explosionAccent = intensity >= 4
          ? _kSoulWarm
          : intensity == 3
          ? _kSoulChrome
          : const Color(0xFF9DE7FF);
    });
    _explosionController.duration = Duration(
      milliseconds: _performanceProfile.tier == _SoulBlockPerformanceTier.low
          ? 580
          : 720,
    );
    _explosionController.forward(from: 0);
  }
}

Rect _sourcePhotoRect(ui.Image image, Rect crop) {
  final side = min(image.width, image.height).toDouble();
  final left = (image.width - side) / 2;
  final top = (image.height - side) / 2;
  return Rect.fromLTWH(
    left + crop.left * side,
    top + crop.top * side,
    crop.width * side,
    crop.height * side,
  );
}

class _SoulPhotoTilePainter extends CustomPainter {
  const _SoulPhotoTilePainter({
    required this.image,
    required this.crop,
    this.preview = false,
    this.clearing = 0,
    this.floating = false,
    this.gold = false,
    this.bomb = false,
  });
  final ui.Image? image;
  final Rect crop;
  final bool preview, floating, gold, bomb;
  final double clearing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shell = RRect.fromRectAndRadius(
      rect.deflate(.65),
      Radius.circular(size.shortestSide * .16),
    );
    final frame = gold
        ? const Color(0xFFFFD787)
        : bomb
        ? const Color(0xFFFFA4AD)
        : const Color(0xFFE5EFFF);
    canvas.drawRRect(shell, Paint()..color = const Color(0xFF080F22));
    canvas.save();
    canvas.clipRRect(shell);
    if (image != null) {
      canvas.drawImageRect(
        image!,
        _sourcePhotoRect(image!, crop),
        rect,
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Colors.white.withValues(alpha: preview ? .55 : 1),
      );
    } else {
      // Khi chưa có ảnh: bề mặt khắc trung tính, vẫn phân biệt ô đã đặt.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF536078), Color(0xFF26334B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
      final p = Paint()
        ..color = Colors.white.withValues(alpha: .10)
        ..strokeWidth = 1;
      for (double i = -size.height; i < size.width; i += 9) {
        canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), p);
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .15),
            Colors.transparent,
            Colors.black.withValues(alpha: .22),
          ],
          stops: const [0, .35, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    if (clearing > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: clearing * .85),
      );
    }
    canvas.restore();
    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (gold || bomb || preview) ? 1.6 : 1
        ..color = frame.withValues(alpha: preview || floating ? .95 : .68),
    );
    canvas.drawLine(
      Offset(size.width * .2, 1.6),
      Offset(size.width * .8, 1.6),
      Paint()
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: .7),
    );
  }

  @override
  bool shouldRepaint(covariant _SoulPhotoTilePainter old) =>
      old.image != image ||
      old.crop != crop ||
      old.preview != preview ||
      old.floating != floating ||
      old.clearing != clearing ||
      old.gold != gold ||
      old.bomb != bomb;
}

class _SoulPhotoReferencePainter extends CustomPainter {
  const _SoulPhotoReferencePainter(this.image, this.crop);
  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        rect.deflate(.8),
        Radius.circular(size.shortestSide * .18),
      ),
    );
    canvas.drawImageRect(
      image,
      _sourcePhotoRect(image, crop),
      rect,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Colors.white.withValues(alpha: .14),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SoulPhotoReferencePainter old) =>
      old.image != image || old.crop != crop;
}
