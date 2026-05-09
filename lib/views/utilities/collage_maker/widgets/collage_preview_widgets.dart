part of '../../collage_maker_screen.dart';

extension _CollagePreviewWidgets on _CollageMakerScreenState {
  Widget _buildSelectedImagesPreview() {
    final memoryItems = _isFromMemory ? _getFilteredMemoryItems() : null;
    final urls = _isFromMemory
        ? memoryItems!.map(_photoCollageUrl).toList(growable: false)
        : _getFilteredUrls();
    final photos = _syncEditablePhotos(urls);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final tileSize = compact ? 96.0 : 112.0;
        _previewTileSize = tileSize;
        final hasPhotos = photos.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: compact
              ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
              : const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: _paperPanelDecoration(
            color: const Color(0xFFFFF8F2),
            borderColor: const Color(0xFFD8C7B7),
            flipped: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _IntroChip(
                    label: 'Chỉnh ảnh',
                    fixedHeight: 32,
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: _paperLine.withValues(alpha: 0.72),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Container(
                    height: 34,
                    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EADF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _paperLine),
                    ),
                    child: Text(
                      hasPhotos ? '${photos.length} ảnh' : '0 ảnh',
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w800,
                        color: _paperRoseDeep,
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                  ),
                ],
              ),
              SLSpacing.h12,
              if (!hasPhotos)
                Container(
                  height: compact ? 104 : 116,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8EFE4),
                    borderRadius: _paperRadius(flipped: true),
                    border: Border.all(color: _paperLine),
                  ),
                  child: Text(
                    'Chưa có ảnh nào được chọn.',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: _paperMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 13.5 : null,
                    ),
                  ),
                )
              else ...[
                Text(
                  'Chạm để chọn ảnh, kéo để đổi vị trí và giữ để chỉnh từng khung ảnh.',
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: _paperMuted,
                    fontSize: compact ? 12.0 : 12.4,
                    height: 1.35,
                  ),
                ),
                SLSpacing.h12,
                SizedBox(
                  height: tileSize + 18,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    padding: EdgeInsets.zero,
                    separatorBuilder: (_, __) => SizedBox(width: compact ? 8 : 10),
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      final memoryItem = _isFromMemory && memoryItems != null
                          ? memoryItems.firstWhere(
                              (item) => _photoCollageUrl(item) == photo.source,
                              orElse: () => const <String, dynamic>{},
                            )
                          : null;
                      return SizedBox(
                        width: tileSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildEditablePhotoTile(
                              photo: photo,
                              index: index,
                              tileSize: tileSize,
                              compact: compact,
                            ),
                            if (_isFromMemory &&
                                memoryItem != null &&
                                memoryItem.isNotEmpty)
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _removeMemoryPhoto(memoryItem),
                                    customBorder: const CircleBorder(),
                                    child: Ink(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.96),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: _paperLine),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _paperCocoa.withValues(alpha: 0.10),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 15,
                                        color: _paperRoseDeep,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditablePhotoTile({
    required _EditableCollagePhoto photo,
    required int index,
    required double tileSize,
    required bool compact,
  }) {
    final selected = _activeEditorIndex == index;
    final hovered = _hoveredSwapTargetIndex == index;
    final tileRadius = BorderRadius.circular(compact ? 22 : 24);
    final image = _buildTransformedPhoto(photo, tileSize, compact);

    final tile = DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final fromIndex = details.data;
        final canAccept = fromIndex != index;
        _setHoveredSwapTargetIndex(canAccept ? index : null);
        return canAccept;
      },
      onLeave: (_) => _clearHoveredSwapTarget(),
      onAcceptWithDetails: (details) => _swapEditablePhotos(details.data, index),
      builder: (context, _, __) {
        return GestureDetector(
          onTap: () => _selectEditablePhoto(index),
          onDoubleTap: () => _resetEditablePhoto(index),
          onScaleStart: (details) => _startFramePinch(index, details),
          onScaleUpdate: (details) => _updateFramePinch(index, details),
          onScaleEnd: (_) => _endFramePinch(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: tileSize,
            height: tileSize,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:
                  hovered ? const Color(0xFFF4E6D9) : const Color(0xFFF6EBDD),
              borderRadius: tileRadius,
              border: Border.all(
                color: hovered || selected ? _paperRoseDeep : _paperLine,
                width: hovered || selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _paperCocoa.withValues(alpha: selected ? 0.18 : 0.10),
                  blurRadius: selected ? 20 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(borderRadius: tileRadius, child: image),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _paperCocoa.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '${photo.scale.toStringAsFixed(1)}x',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (hovered)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _paperRoseDeep.withValues(alpha: 0.16),
                        borderRadius: tileRadius,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    return LongPressDraggable<int>(
      data: index,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.86,
          child: SizedBox(
            width: tileSize,
            height: tileSize,
            child: ClipRRect(borderRadius: tileRadius, child: image),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.34, child: tile),
      onDragStarted: () => _selectEditablePhoto(index),
      onDraggableCanceled: (_, __) => _clearHoveredSwapTarget(),
      onDragEnd: (_) => _clearHoveredSwapTarget(),
      child: tile,
    );
  }

  Widget _buildTransformedPhoto(
    _EditableCollagePhoto photo,
    double tileSize,
    bool compact,
  ) {
    final cacheWidth = (tileSize * 4).round().clamp(480, 720);
    final image = photo.source.startsWith('http')
        ? CachedNetworkImage(
            memCacheWidth: cacheWidth,
            imageUrl: photo.source,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _paperRoseDeep,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    color: _paperRoseDeep,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lỗi ảnh',
                    style: SLTheme.quicksand(
                      color: _paperMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        : Image.file(
            File(photo.source),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.high,
          );

    return ClipRect(
      child: ColoredBox(
        color: const Color(0xFFF9F3EC),
        child: Center(
          child: Transform.translate(
            offset: Offset(
              photo.offset.dx * tileSize * 0.28,
              photo.offset.dy * tileSize * 0.28,
            ),
            child: Transform.scale(
              scale: photo.scale,
              child: SizedBox.expand(child: image),
            ),
          ),
        ),
      ),
    );
  }
}
