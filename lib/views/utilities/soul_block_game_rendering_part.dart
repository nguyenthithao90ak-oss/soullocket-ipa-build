// ignore_for_file: invalid_use_of_protected_member, unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of 'soul_block_game.dart';

extension _SoulBlockGameRenderingPart on _SoulBlockGameState {
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

  _SoulBlockPerformanceProfile _resolvePerformanceProfile() {
    if (_smoothGraphics) {
      return _SoulBlockPerformanceProfile.low;
    }
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
    final double logicalHeight =
        logicalWidth / _SoulBlockGameState._memoryBurstCardAspectRatio;
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
      onError: (Object _, StackTrace? _) {
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

    final double diff =
        (aspectRatio - _SoulBlockGameState._memoryBurstCardAspectRatio).abs();
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
    final double innerExtent =
        boardExtent - (_SoulBlockGameState._boardPanelPadding * 2) - 6.0;
    final double contentExtent = (_boardCellExtent * _boardSize) +
        (_SoulBlockGameState._boardGap * (_boardSize - 1));
    _boardContentInset = max(0, innerExtent - contentExtent) / 2;
  }

  double _resolveBoardCellExtent(
    double boardExtent, {
    required double devicePixelRatio,
  }) {
    final double usableBoardExtent = boardExtent -
        (_SoulBlockGameState._boardPanelPadding * 2) -
        (_SoulBlockGameState._boardGap * (_boardSize - 1)) -
        _SoulBlockGameState._boardLayoutSafetyInset;
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
    final cellFullSize = _boardCellExtent + _SoulBlockGameState._boardGap;
    return piece.template.width * cellFullSize - _SoulBlockGameState._boardGap;
  }

  double _dragPieceHeightPixels(_SoulPieceOption piece) {
    final cellFullSize = _boardCellExtent + _SoulBlockGameState._boardGap;
    return piece.template.height * cellFullSize - _SoulBlockGameState._boardGap;
  }

  double _dragPieceTop(double pointerDy, double pieceHeight) {
    return pointerDy -
        (pieceHeight * 0.5) -
        _SoulBlockGameState._dragLiftOffset;
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

  Offset _boardCellCenter(double row, double col) {
    final cellFullSize = _boardCellExtent + _SoulBlockGameState._boardGap;
    return Offset(
      _boardOrigin.dx +
          _SoulBlockGameState._boardPanelPadding +
          _boardContentInset +
          (col * cellFullSize) +
          (_boardCellExtent / 2),
      _boardOrigin.dy +
          _SoulBlockGameState._boardPanelPadding +
          _boardContentInset +
          (row * cellFullSize) +
          (_boardCellExtent / 2),
    );
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
}
