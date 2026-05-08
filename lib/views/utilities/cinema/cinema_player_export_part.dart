part of '../cinema_screen.dart';

extension _CinemaReelPlayerExportPart on _CinemaReelPlayerScreenState {
  Future<void> _createVideo() async {
    if (_isExportingVideo) {
      return;
    }
    if (!_videoExportService.isSupported) {
      _commitState(() {
        _videoStatus =
            'Tính năng xuất video đang tạm bảo trì. Bạn vẫn có thể xem reel ảnh bình thường.';
        _videoProgress = null;
        _isExportingVideo = false;
      });
      _showPlayerSnack(
        'Tính năng xuất video đang tạm bảo trì.',
        backgroundColor: const Color(0xFF8E6E1F),
      );
      return;
    }
    if (_hasFreshExport) {
      _showPlayerSnack('Video hiện tại đã sẵn sàng để tải xuống.');
      return;
    }

    _commitState(() {
      _isExportingVideo = true;
      _videoProgress = 0.02;
      _videoStatus = 'Đang chuẩn bị video kỷ niệm...';
    });

    try {
      final result = await _videoExportService.exportReel(
        exportId: '${widget.reel.dateKey}_${widget.reel.title}',
        frames: widget.reel.items
            .map(
              (item) => CinemaVideoFrame(
                id: item.id,
                imageUrl: item.imageUrl,
              ),
            )
            .toList(growable: false),
        frameDuration: _kCinemaFrameDuration,
        overlay: CinemaVideoOverlayConfig(
          title: _exportTitle,
          subtitle: _exportSubtitle,
          brandLabel: 'SoulLocket Cinema',
          tagLabel: _exportTagLabel,
          accentColor: Color(widget.reel.accentValue),
          anchor: _titleAnchor,
          qualityPreset: _qualityPreset,
          useHevc: _useHevc,
        ),
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          _commitState(() {
            _videoProgress = progress.value;
            _videoStatus = progress.label;
          });
        },
      );

      if (!mounted) {
        return;
      }
      _commitState(() {
        _isExportingVideo = false;
        _videoProgress = 1;
        _videoStatus =
            'Video MP4 đã sẵn sàng. Bạn có thể tải xuống hoặc chia sẻ ngay.';
        _exportedVideoPath = result.outputPath;
        _exportedVideoSignature = _currentExportSignature;
      });
      _showPlayerSnack('Đã tạo video kỷ niệm thành công.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _normalizeError(error);
      _commitState(() {
        _isExportingVideo = false;
        _videoProgress = null;
        _videoStatus = message;
      });
      _showPlayerSnack(
        message,
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> _saveVideoToDevice() async {
    final exportPath = _exportedVideoPath;
    if (!_hasFreshExport || exportPath == null) {
      _showPlayerSnack(
        'Hãy tạo video trước khi tải xuống.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    if (_isSavingVideo) {
      return;
    }

    final granted = await _ensureGalleryPermission();
    if (!granted) {
      _showPlayerSnack(
        'Chưa có quyền lưu video vào thiết bị.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    _commitState(() => _isSavingVideo = true);
    try {
      final result = await VisionGallerySaver.saveFile(
        exportPath,
        name: _buildVideoFileName(),
      );
      final isSuccess = result['isSuccess'] == true ||
          (result['filePath']?.toString().isNotEmpty ?? false);
      if (!isSuccess) {
        final message = result['errorMessage']?.toString().trim();
        throw Exception(
          message != null && message.isNotEmpty
              ? message
              : 'Không thể lưu video vào thiết bị.',
        );
      }

      if (!mounted) {
        return;
      }
      _commitState(() {
        _videoStatus = 'Video đã được lưu vào máy.';
      });
      _showPlayerSnack('Đã tải video kỷ niệm về máy.');
    } catch (error) {
      _showPlayerSnack(
        _normalizeError(error),
        backgroundColor: const Color(0xFFE53935),
      );
    } finally {
      if (mounted) {
        _commitState(() => _isSavingVideo = false);
      }
    }
  }

  Future<void> _shareVideo() async {
    final exportPath = _exportedVideoPath;
    if (!_hasFreshExport || exportPath == null) {
      _showPlayerSnack(
        'Hãy tạo video trước khi chia sẻ.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(exportPath)],
          text: _exportTitle,
        ),
      );
    } catch (error) {
      _showPlayerSnack(
        _normalizeError(error),
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await app_permission.Permission.photosAddOnly.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }
      final requested = await AppLifecyclePresenceGuard.guard(
        app_permission.Permission.photosAddOnly.request,
      );
      return requested.isGranted || requested.isLimited;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdkInt >= 29) {
        return true;
      }
      final status = await app_permission.Permission.storage.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }
      final requested = await AppLifecyclePresenceGuard.guard(
        app_permission.Permission.storage.request,
      );
      return requested.isGranted || requested.isLimited;
    }

    return true;
  }

  String _buildVideoFileName() {
    final baseName = _exportTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final safeBaseName = baseName.isEmpty ? 'soullocket_cinema' : baseName;
    return 'soullocket_${safeBaseName}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _normalizeError(Object error) {
    var text = error.toString().trim();
    if (text.startsWith('Bad state: ')) {
      text = text.substring('Bad state: '.length);
    }
    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }
    if (text.startsWith('Unsupported operation: ')) {
      text = text.substring('Unsupported operation: '.length);
    }
    return text;
  }
}
