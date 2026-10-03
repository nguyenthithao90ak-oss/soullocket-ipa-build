part of '../../main_home_tab.dart';

extension MainHomeAvatarController on _MainHomeTabState {
  Future<XFile?> _cropAvatarImage(XFile file, {required bool isUser1}) async {
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
            toolbarTitle: isUser1
                ? 'Cắt avatar bạn nam'
                : 'Cắt avatar người ấy',
            toolbarColor: const Color(0xFFD81B60),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: isUser1 ? context.tr('home_ctavatarbn_f914c9') : context.tr('home_ctavatarng_30711f'),
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
    final houseId = (_houseId ?? await _houseService.getCurrentHouseId())
        ?.trim();
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
        SLSnackBar(
          content: Text(
            context.tr('home_lniavatart_37d3af'),
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: context.tr('Thử lại'),
            onPressed: () {
              unawaited(_retryPendingAvatarUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingAvatarUpload() async {
    final houseId = (_houseId ?? await _houseService.getCurrentHouseId())
        ?.trim();
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
          SLSnackBar(
            content: Text(context.tr('home_khngtmthyn_e7acea')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await _changeAvatar(isUser1: role != 'user2', presetFile: file);
  }

  Future<void> _changeAvatar({required bool isUser1, XFile? presetFile}) async {
    final uploadUid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = _houseId ?? await _houseService.getCurrentHouseId();
    if (!mounted || houseId == null || uploadUid == null) return;
    if (_uploadingAvatarRole != null) return;

    XFile? file;
    try {
      file = presetFile ?? await _storageService.pickImage();
    } catch (e) {
      if (mounted) SLNotice.showInfo(context, L10nScope.of(context).format('ui_home_error_selecting_photo_value1_f81600', {'value1': e}));
    }
    if (file == null) return;
    if (!mounted) return;

    final role = isUser1 ? 'user1' : 'user2';
    final field = isUser1 ? 'avtUser1' : 'avtUser2';
    final pendingKey = _pendingAvatarUploadKeyForHouse(houseId);
    _safeSetState(() {
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
        role: role,
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
      await StorageMediaCommit.commit(
        scopeIsCurrent: () =>
            mounted &&
            _houseId == houseId &&
            FirebaseAuth.instance.currentUser?.uid == uploadUid,
        persist: () =>
            _dbRef.child('houses/$houseId/settings').update({field: url}),
        clearPending: () => PendingUploadService.instance.clear(pendingKey),
      );

      if (oldAvatarUrl != url && oldAvatarUrl.startsWith('http')) {
        try {
          await _storageService.deleteImageByUrl(oldAvatarUrl);
        } catch (error) {
          debugPrint('[MainHome] Old avatar cleanup failed: $error');
        }
      }

      if (mounted) {
        _safeSetState(() {
          _houseSettings ??= {};
          _houseSettings![field] = url;
        });
        _avatarUploadProgressNotifier.value = 1.0;

        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(
              isUser1
                  ? context.tr('home_cpnhtavata_af1e5c')
                  : context.tr('home_cpnhtavata_182b34'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(
              context.tr('home_chathinhid_401e49'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        _safeSetState(() {
          _uploadingAvatarRole = null;
        });
        _avatarUploadProgressNotifier.value = -1.0;
      }
    }
  }
}
