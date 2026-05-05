part of '../cinema_screen.dart';

extension _CinemaReelPlayerWidgetsPart on _CinemaReelPlayerScreenState {
  Widget _buildContainedImage(
    String url, {
    int memCacheWidth = 1600,
    double errorIconSize = 42,
  }) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: CachedNetworkImage(
          memCacheWidth: memCacheWidth,
          imageUrl: url,
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          placeholder: (_, __) => const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFFFF6FA5),
            ),
          ),
          errorWidget: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            color: Colors.white70,
            size: errorIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayDecorations(Color accent) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          final titleWidth =
              (viewport.width * 0.72).clamp(250.0, viewport.width - 24.0);
          final left = (_titleAnchor.dx * viewport.width)
              .clamp(12.0, viewport.width - titleWidth - 12.0);
          final top = (_titleAnchor.dy * viewport.height)
              .clamp(92.0, viewport.height - 220.0);

          return Stack(
            children: <Widget>[
              Positioned(
                right: 16,
                top: 72,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.34),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SoulLocket Cinema',
                          style: SLTheme.quicksand(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _isAdjustingTitlePosition
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: left,
                top: top,
                width: titleWidth,
                child: IgnorePointer(
                  ignoring: !_isAdjustingTitlePosition,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: _isAdjustingTitlePosition
                        ? (details) => _updateTitleAnchor(
                            details.delta, viewport, titleWidth)
                        : null,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: _isAdjustingTitlePosition
                              ? accent.withOpacity(0.9)
                              : Colors.white.withOpacity(0.12),
                          width: _isAdjustingTitlePosition ? 1.8 : 1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 74,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _exportTagLabel,
                              maxLines: 2,
                              overflow: TextOverflow.fade,
                              style: SLTheme.quicksand(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withOpacity(0.78),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _exportTitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _exportSubtitle,
                              maxLines: 3,
                              overflow: TextOverflow.fade,
                              style: SLTheme.quicksand(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.72),
                              ),
                            ),
                            if (_isAdjustingTitlePosition) ...<Widget>[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.open_with_rounded,
                                    size: 15,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kéo để đặt lại vị trí tiêu đề',
                                    style: SLTheme.quicksand(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.82),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoControls(Color accent) {
    final exportAvailable = _videoExportService.isSupported;
    final statusText = _isAdjustingTitlePosition
        ? 'Kéo khối tiêu đề tới vị trí bạn muốn rồi bấm Xong vị trí.'
        : (_videoStatus ??
            (exportAvailable
                ? null
                : 'Tính năng xuất video đang tạm bảo trì. Bạn vẫn có thể xem reel ảnh bình thường.'));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _buildControlChip(
                icon: _isAdjustingTitlePosition
                    ? Icons.check_rounded
                    : Icons.open_with_rounded,
                label:
                    _isAdjustingTitlePosition ? 'Xong vị trí' : 'Kéo tiêu đề',
                onTap: _toggleTitleAdjustment,
                accent: accent,
              ),
              _buildControlChip(
                icon: Icons.edit_rounded,
                label: 'Sửa tiêu đề',
                onTap: _editTitle,
                accent: accent,
              ),
              _buildControlChip(
                icon: Icons.movie_creation_outlined,
                label: _hasFreshExport ? 'Tạo lại video' : 'Tạo video',
                onTap:
                    !exportAvailable || _isExportingVideo ? null : _createVideo,
                accent: accent,
                emphasized: true,
              ),
              _buildControlChip(
                icon: Icons.download_rounded,
                label: _isSavingVideo ? 'Đang lưu...' : 'Tải xuống',
                onTap: exportAvailable && _hasFreshExport && !_isSavingVideo
                    ? _saveVideoToDevice
                    : null,
                accent: accent,
              ),
              _buildControlChip(
                icon: Icons.share_rounded,
                label: 'Chia sẻ',
                onTap: exportAvailable && _hasFreshExport ? _shareVideo : null,
                accent: accent,
              ),
            ],
          ),
          if (statusText != null && statusText.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              statusText,
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
          if (_videoProgress != null && _isExportingVideo) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: _videoProgress!.clamp(0, 1),
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showVideoSettingsSheet(Color accent) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF151116),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 30,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.tune_rounded, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cài đặt video kỷ niệm',
                            style: SLTheme.quicksand(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildVideoControls(accent),
                    const SizedBox(height: 14),
                    _buildQualitySelector(accent),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualitySelector(Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chất lượng video',
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: CinemaVideoQualityPreset.values.map((preset) {
              final isSelected = _qualityPreset == preset;
              return GestureDetector(
                onTap: () => _commitState(() {
                  _qualityPreset = preset;
                  _videoStatus = null;
                  _exportedVideoPath = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withOpacity(0.28)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? accent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preset.label,
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '~${preset.estimatedMbPer30Sec.toStringAsFixed(1)}MB/30s • ${preset.fps}fps',
                        style: SLTheme.quicksand(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.48),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlChip({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color accent,
    bool emphasized = false,
  }) {
    final isEnabled = onTap != null;
    final backgroundColor = emphasized
        ? accent.withOpacity(isEnabled ? 0.94 : 0.32)
        : Colors.white.withOpacity(isEnabled ? 0.08 : 0.04);
    final foregroundColor = emphasized
        ? const Color(0xFF2B0711)
        : Colors.white.withOpacity(isEnabled ? 0.92 : 0.36);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: emphasized
                  ? accent.withOpacity(isEnabled ? 0.96 : 0.18)
                  : Colors.white.withOpacity(isEnabled ? 0.1 : 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerArrow({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.34),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
