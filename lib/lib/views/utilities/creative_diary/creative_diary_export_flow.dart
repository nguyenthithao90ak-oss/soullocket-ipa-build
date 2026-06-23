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
    return AppErrorMapper.resolve(
      error,
      fallbackMessage: fallback,
    ).message;
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
                    context.tr('util_sau_8a3721'),
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
                    context.tr('util_xemqungco_3eab07'),
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
      context.tr('util_bncnxemhtq_4cfa2f'),
      backgroundColor: const Color(0xFFE53935),
    );
    return false;
  }

  Future<RenderRepaintBoundary> _waitForExportBoundary() async {
    final errNoRepaint = context.tr('util_khngthdngt_7fda2c');
    for (var attempt = 0; attempt < 8; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _exportBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null && !boundary.debugNeedsPaint) {
        return boundary;
      }
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }

    throw StateError(errNoRepaint);
  }

  Future<Uint8List> _captureExportPage(
    _DiaryPageData page,
    int index,
  ) async {
    final errExportFailed = context.tr('util_khngthxutn_15afa3');
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
        throw StateError(errExportFailed);
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
    final errSaveFailed = context.tr('util_khngthlutr_e91f80');
    final result = await VisionGallerySaver.saveImage(
      bytes,
      quality: 100,
      name:
          'soullocket_diary_${batchStamp}_${(index + 1).toString().padLeft(2, '0')}',
    );

    final isSuccess = result['isSuccess'] == true ||
        (result['filePath']?.toString().isNotEmpty ?? false);
    if (!isSuccess) {
      final message = result['errorMessage']?.toString().trim();
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : errSaveFailed,
      );
    }
  }

  Future<void> _saveNotebookToDevice() async {
    if (_isLoading || _isExportingNotebook) {
      return;
    }
    final emptyNotebookErr = context.tr('util_staychactr_734626');
    final permissionDeniedErr = context.tr('util_chacquynlu_b6c143');
    final confirmAdTitle = context.tr('util_lustayvmy_2f6c33');
    final confirmAdMsg = context.tr('util_bncnxem1qu_9a56aa');
    final preparingLog = context.tr('util_angchunblu_4a896d');
    final detailLog = context.tr('util_mitrangscl_408b1f');
    final fallbackExportErr = context.tr('util_khngthlust_5bf617');

    if (_pages.isEmpty) {
      _showSnack(
        emptyNotebookErr,
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final granted = await _guardController.ensureGalleryPermission(context);
    if (!granted) {
      _showSnack(
        permissionDeniedErr,
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    final unlocked = await _confirmRewardedSave(
      title: confirmAdTitle,
      message:
          confirmAdMsg,
    );
    if (!unlocked) {
      return;
    }

    final batchStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    var savedCount = 0;
    Object? lastError;

    setState(() {
      _isExportingNotebook = true;
      _exportStatus = preparingLog;
      _exportDetail = detailLog;
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

      throw lastError ?? StateError(fallbackExportErr);
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
    final emptyNotebookErr = context.tr('util_staychactr_734626');
    final permissionDeniedErr = context.tr('util_chacquynlu_b6c143');
    final confirmAdTitle = context.tr('util_lunhknim_ebdd93');
    final confirmAdMsg = context.tr('util_bncnxem1qu_3efd64');
    final detailLog = context.tr('util_chtrangang_df85ea');

    if (_pages.isEmpty) {
      _showSnack(
        emptyNotebookErr,
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final index = _currentIndex.clamp(0, _pages.length - 1);
    final page = _pages[index];
    final granted = await _guardController.ensureGalleryPermission(context);
    if (!granted) {
      _showSnack(
        permissionDeniedErr,
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    final unlocked = await _confirmRewardedSave(
      title: confirmAdTitle,
      message:
          confirmAdMsg,
    );
    if (!unlocked) {
      return;
    }

    final batchStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    setState(() {
      _isExportingNotebook = true;
      _exportStatus =
          'Đang chuẩn bị lưu trang ${index + 1}/${_pages.length}...';
      _exportDetail = detailLog;
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
