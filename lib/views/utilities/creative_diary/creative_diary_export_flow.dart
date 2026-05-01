part of '../creative_diary_screen.dart';
// ignore_for_file: invalid_use_of_protected_member

extension _CreativeDiaryExportFlowPart on _CreativeDiaryScreenState {
  void _showSnack(
    String message, {
    Color? backgroundColor,
  }) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: SLTheme.quicksand(fontWeight: FontWeight.w800),
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _errorText(
    Object error, {
    required String fallback,
  }) {
    final cleaned = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Unsupported operation: ', '')
        .trim();
    if (cleaned.isEmpty ||
        cleaned.contains('Ã') ||
        cleaned.contains('\uFFFD')) {
      return fallback;
    }
    return cleaned;
  }

  Future<bool> _hasRewardedSaveCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedUntilMs = prefs.getInt(
          _CreativeDiaryScreenState._rewardedSaveUnlockedUntilPrefsKey,
        ) ??
        0;
    return DateTime.now().millisecondsSinceEpoch < unlockedUntilMs;
  }

  Future<void> _storeRewardedSaveCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedUntil =
        DateTime.now().add(_CreativeDiaryScreenState._rewardedSaveCooldown);
    await prefs.setInt(
      _CreativeDiaryScreenState._rewardedSaveUnlockedUntilPrefsKey,
      unlockedUntil.millisecondsSinceEpoch,
    );
  }

  Future<bool> _confirmRewardedSave({
    required String title,
    required String message,
  }) async {
    final adMobService = AdMobService();
    if (await adMobService.isProUser()) {
      return true;
    }
    if (await _hasRewardedSaveCooldown()) {
      return true;
    }
    if (!mounted) {
      return false;
    }

    final shouldWatchAd = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
              title: Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                ),
              ),
              content: Text(
                message,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: SLColors.textSecondary,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Để sau',
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      color: SLColors.textSecondary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: Text(
                    'Xem quảng cáo',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: SLColors.primaryActive,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldWatchAd || !mounted) {
      return false;
    }

    await adMobService.initialize();
    if (!mounted) {
      return false;
    }

    final watched = await adMobService.showRewardedAd();
    if (watched) {
      await _storeRewardedSaveCooldown();
      return true;
    }
    if (!mounted) {
      return false;
    }

    _showSnack(
      'Bạn cần xem hết quảng cáo để lưu ảnh. Nếu quảng cáo chưa tải xong, hãy thử lại sau.',
      backgroundColor: const Color(0xFFE53935),
    );
    return false;
  }

  Future<RenderRepaintBoundary> _waitForExportBoundary() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _exportBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null && !boundary.debugNeedsPaint) {
        return boundary;
      }
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }

    throw StateError('Không thể dựng trang sổ để lưu.');
  }

  Future<Uint8List> _captureExportPage(
    _DiaryPageData page,
    int index,
  ) async {
    final pixelRatio = math.min(
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio *
          1.6,
      3.0,
    );

    setState(() {
      _exportPage = page;
      _exportPageIndex = index;
      _exportStatus = 'Đang chuẩn bị trang ${index + 1}/${_pages.length}...';
    });

    final boundary = await _waitForExportBoundary();
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Không thể xuất ảnh từ trang sổ.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _saveDiaryPageToGallery(
    Uint8List bytes, {
    required int index,
    required String batchStamp,
  }) async {
    final result = await VisionGallerySaver.saveImage(
      bytes,
      quality: 100,
      name:
          'soullocket_diary_${batchStamp}_${(index + 1).toString().padLeft(2, '0')}',
      androidRelativePath: 'Pictures/SoulLocket/SoTayKyNiem',
    );

    final isSuccess = result['isSuccess'] == true ||
        (result['filePath']?.toString().isNotEmpty ?? false);
    if (!isSuccess) {
      final message = result['errorMessage']?.toString().trim();
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Không thể lưu trang sổ vào máy.',
      );
    }
  }

  Future<void> _saveNotebookToDevice() async {
    if (_isLoading || _isExportingNotebook) {
      return;
    }
    if (_pages.isEmpty) {
      _showSnack(
        'Sổ tay chưa có trang nào để lưu.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final granted = await _guardController.ensureGalleryPermission(context);
    if (!granted) {
      _showSnack(
        'Chưa có quyền lưu ảnh vào thiết bị.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    final unlocked = await _confirmRewardedSave(
      title: 'Lưu sổ tay về máy',
      message:
          'Bạn cần xem 1 quảng cáo ngắn để lưu toàn bộ ảnh kỷ niệm trong sổ tay về thiết bị.',
    );
    if (!unlocked) {
      return;
    }

    final batchStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    var savedCount = 0;
    Object? lastError;

    setState(() {
      _isExportingNotebook = true;
      _exportStatus = 'Đang chuẩn bị lưu sổ tay...';
      _exportDetail = 'Mỗi trang sẽ được lưu thành một ảnh đầy đủ.';
    });

    try {
      for (var index = 0; index < _pages.length; index++) {
        if (!mounted) {
          return;
        }

        setState(() {
          _exportStatus =
              'Đang lưu trang ${index + 1}/${_pages.length} về máy...';
        });

        try {
          final bytes = await _captureExportPage(_pages[index], index);
          await _saveDiaryPageToGallery(
            bytes,
            index: index,
            batchStamp: batchStamp,
          );
          savedCount++;
        } catch (error) {
          lastError = error;
        }
      }

      if (!mounted) {
        return;
      }

      if (savedCount == _pages.length) {
        _showSnack('Đã lưu trọn bộ ${_pages.length} trang sổ về máy.');
        return;
      }

      if (savedCount > 0) {
        _showSnack(
          'Đã lưu $savedCount/${_pages.length} trang. Một vài trang chưa lưu, bạn có thể thử lại.',
          backgroundColor: const Color(0xFFB26A00),
        );
        return;
      }

      throw lastError ?? StateError('Không thể lưu sổ tay về máy.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Không thể lưu sổ tay: ${_errorText(error, fallback: 'Vui lòng thử lại sau.')}',
        backgroundColor: const Color(0xFFE53935),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingNotebook = false;
          _exportStatus = null;
          _exportDetail = null;
          _exportPage = null;
          _exportPageIndex = 0;
        });
      }
    }
  }

  Future<void> _saveCurrentPageToDevice() async {
    if (_isLoading || _isExportingNotebook) {
      return;
    }
    if (_pages.isEmpty) {
      _showSnack(
        'Sổ tay chưa có trang nào để lưu.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final index = _currentIndex.clamp(0, _pages.length - 1);
    final page = _pages[index];
    final granted = await _guardController.ensureGalleryPermission(context);
    if (!granted) {
      _showSnack(
        'Chưa có quyền lưu ảnh vào thiết bị.',
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    final unlocked = await _confirmRewardedSave(
      title: 'Lưu ảnh kỷ niệm',
      message:
          'Bạn cần xem 1 quảng cáo ngắn để lưu ảnh của trang kỷ niệm này về thiết bị.',
    );
    if (!unlocked) {
      return;
    }

    final batchStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    setState(() {
      _isExportingNotebook = true;
      _exportStatus =
          'Đang chuẩn bị lưu trang ${index + 1}/${_pages.length}...';
      _exportDetail = 'Chỉ trang đang xem sẽ được lưu thành một ảnh đầy đủ.';
    });

    try {
      final bytes = await _captureExportPage(page, index);
      if (!mounted) {
        return;
      }
      setState(() {
        _exportStatus =
            'Đang lưu trang ${index + 1}/${_pages.length} về máy...';
      });
      await _saveDiaryPageToGallery(
        bytes,
        index: index,
        batchStamp: batchStamp,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Đã lưu trang ${index + 1} về máy.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Không thể lưu trang này: ${_errorText(error, fallback: 'Vui lòng thử lại sau.')}',
        backgroundColor: const Color(0xFFE53935),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingNotebook = false;
          _exportStatus = null;
          _exportDetail = null;
          _exportPage = null;
          _exportPageIndex = 0;
        });
      }
    }
  }
}
