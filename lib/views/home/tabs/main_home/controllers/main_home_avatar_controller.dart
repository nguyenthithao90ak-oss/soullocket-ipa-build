part of '../../main_home_tab.dart';

extension MainHomeAvatarController on _MainHomeTabState {
  Future<XFile?> _cropAvatarImage(
    XFile file, {
    required bool isUser1,
  }) async {
    if (kIsWeb || file.path.isEmpty) {
      return file;
    }

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
        uiSettings: [
          
          AndroidUiSettings(
            toolbarTitle: isUser1 ? 'Cắt avatar bạn nam' : 'Cắt avatar người ấy',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFFFF6D97),
            dimmedLayerColor: Colors.black.withValues(alpha: 0.8),
            cropFrameColor: Colors.transparent,
            cropGridColor: Colors.transparent,
            showCropGrid: false,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: isUser1 ? 'Cắt avatar bạn nam' : 'Cắt avatar người ấy',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile == null) {
        return null;
      }
      return XFile(croppedFile.path);
    } catch (_) {
      return file;
    }
  }

  String _pendingAvatarUploadKeyForHouse(String houseId) =>
      '${_MainHomeTabState._pendingAvatarUploadKeyPrefix}$houseId';

  Future<void> _promptPendingAvatarRetryIfNeeded() async {
    if (_didPromptPendingAvatarRetry || !mounted) {
      return;
    }
    final houseId =
        (_houseId ?? await _houseService.getCurrentHouseId())?.trim();
    if (houseId == null || houseId.isEmpty) {
      return;
    }
    final pending = await PendingUploadService.instance.load(
      _pendingAvatarUploadKeyForHouse(houseId),
    );
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingAvatarRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Lần đổi avatar trang chủ trước đã bị gián đoạn.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(_retryPendingAvatarUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingAvatarUpload() async {
    final houseId =
        (_houseId ?? await _houseService.getCurrentHouseId())?.trim();
    if (houseId == null || houseId.isEmpty) {
      return;
    }
    final pendingKey = _pendingAvatarUploadKeyForHouse(houseId);
    final pending = await PendingUploadService.instance.load(pendingKey);
    if (pending == null || !mounted) {
      return;
    }
    final role = pending['role']?.toString().trim() ?? '';
    final filePath = pending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(pendingKey);
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(pendingKey);
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(pendingKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Không tìm thấy ảnh avatar cũ để thử lại.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await _changeAvatar(
      isUser1: role != 'user2',
      presetFile: file,
    );
  }

  Future<void> _changeAvatar({
    required bool isUser1,
    XFile? presetFile,
  }) async {
    final houseId = _houseId ?? await _houseService.getCurrentHouseId();
    if (!mounted || houseId == null) return;
    if (_uploadingAvatarRole != null) return;

    XFile? file;
    try {
      file = presetFile ?? await _storageService.pickImage();
    } catch (e) {
      if (mounted) SLNotice.showInfo(context, 'Lỗi chọn ảnh: $e');
    }
    if (file == null) return;
    if (!mounted) return;

    final role = isUser1 ? 'user1' : 'user2';
    final field = isUser1 ? 'avtUser1' : 'avtUser2';
    final pendingKey = _pendingAvatarUploadKeyForHouse(houseId);
    setState(() {
      _uploadingAvatarRole = role;
    });
    _avatarUploadProgressNotifier.value = 0.0;

    try {
      if (presetFile == null) {
        file = await _cropAvatarImage(file, isUser1: isUser1);
      }
      if (file == null) {
        return;
      }
      await PendingUploadService.instance.save(pendingKey, <String, dynamic>{
        'role': role,
        'filePath': file.path,
      });

      final upload = await _storageService.uploadPublicImage(
        houseId,
        'home_avatar',
        file,
        quality: 84,
        minWidth: 512,
        minHeight: 512,
        onProgress: (p) {
          if (mounted) {
            _avatarUploadProgressNotifier.value = p;
          }
        },
      );
      final url = upload?.downloadUrl.trim() ?? '';
      if (url.isEmpty) {
        throw 'Không lấy được ảnh mới.';
      }

      final oldAvatarUrl = (_houseSettings?[field] ?? '').toString().trim();
      await PendingUploadService.instance.clear(pendingKey);

      try {
        final hid = (_houseId ?? '').trim();
        if (hid.isNotEmpty) {
          await _dbRef.child('houses/$hid/settings').update({
            field: url,
          }).catchError((_) {});
        }
      } catch (_) {}

      if (oldAvatarUrl.isNotEmpty && oldAvatarUrl.startsWith('http')) {
        try {
          _storageService.deleteImageByUrl(oldAvatarUrl);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _houseSettings ??= {};
          _houseSettings![field] = url;
        });
        _avatarUploadProgressNotifier.value = 1.0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUser1
                  ? 'Đã cập nhật avatar cho bạn nam.'
                  : 'Đã cập nhật avatar cho bạn nữ.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.tr('Chưa thể đổi ảnh đại diện lúc này. Vui lòng thử lại.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatarRole = null;
        });
        _avatarUploadProgressNotifier.value = -1.0;
      }
    }
  }
}
