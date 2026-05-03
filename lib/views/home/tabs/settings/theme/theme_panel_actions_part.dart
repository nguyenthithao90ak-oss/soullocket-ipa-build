part of '../../settings_tab.dart';

extension _SettingsTabThemePanelActionsPart on _SettingsTabState {
  Future<void> _promptPendingThemeBackgroundRetryIfNeeded() async {
    if (_didPromptPendingThemeBackgroundRetry || !mounted) {
      return;
    }
    final pending = await PendingUploadService.instance.load('pending_theme_bg');
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingThemeBackgroundRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tải ảnh nền giao diện trước đó bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () => unawaited(_retryPendingThemeBackgroundUpload()),
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingThemeBackgroundUpload() async {
    final pending = await PendingUploadService.instance.load('pending_theme_bg');
    if (pending == null) return;
    final filePath = pending['filePath']?.toString() ?? '';
    if (filePath.isEmpty) return;
    await _uploadThemeBackgroundFile(XFile(filePath));
  }

  Future<void> _pickAndUploadThemeBackground() async {
    if (_isUploadingThemeBackground) return;
    final file = await _storageService.pickImage();
    if (file == null) return;
    final cropped = await _cropThemeBackgroundFile(file);
    if (cropped == null) return;
    await _uploadThemeBackgroundFile(cropped);
  }

  Future<XFile?> _cropThemeBackgroundFile(XFile file) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: _themeBackgroundAspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cắt ảnh nền',
          toolbarColor: const Color(0xFFD81B60),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Cắt ảnh nền',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (croppedFile == null) return null;
    return XFile(croppedFile.path);
  }

  Future<void> _uploadThemeBackgroundFile(XFile file) async {
    if (_houseId == null) return;
    setState(() => _isUploadingThemeBackground = true);
    try {
      await PendingUploadService.instance.save('pending_theme_bg', {'filePath': file.path});
      final url = await _storageService.uploadImage(_houseId!, 'theme_bg', file);
      if (url != null) {
        _updateThemeDraft(() => _draftCustomBackgroundUrl = url);
        await PendingUploadService.instance.clear('pending_theme_bg');
        _showToast('Đã tải ảnh nền mới!', success: true);
      }
    } catch (e) {
      _showToast('Lỗi tải ảnh: $e', success: false);
    } finally {
      if (mounted) setState(() => _isUploadingThemeBackground = false);
    }
  }

  Future<void> _clearThemeBackground() async {
    _updateThemeDraft(() => _draftCustomBackgroundUrl = '');
    _showToast('Đã xóa ảnh nền tùy chỉnh', success: true);
  }
}
