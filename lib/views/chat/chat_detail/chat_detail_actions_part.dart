// ignore_for_file: invalid_use_of_protected_member

import 'package:shared_preferences/shared_preferences.dart';
import '../../services/connectivity_service.dart';
import 'chat_friendly_helper.dart';

part of '../chat_detail_screen.dart';

extension _ChatDetailActionsPart on _ChatDetailScreenState {
  Future<void> _checkChatLock() async {
    try {
      final authSuccess = mounted
          ? await _militaryLockService.requestUnlock(
              context: context,
              scope: LockScope.chat,
              houseId: widget.myHouseId,
              title: MilitaryLockService.getScopeTitle(LockScope.chat),
              reason:
                  'Mở khóa để xem lại cuộc trò chuyện với ${_nickname.trim().isEmpty ? widget.targetName : _nickname.trim()}.',
            )
          : false;
      if (mounted) {
        setState(() {
          _isAuthenticated = authSuccess;
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _sendMsg() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) {
      return;
    }

    if (!await SecurityService().guardAction(context, 'chat_send_message')) {
      return;
    }

    try {
      if (!ConnectivityService().isOnline) {
        final offlineResponse = ChatFriendlyHelper.getFriendlyResponse(isOffline: true);
        _showNotice(offlineResponse);
        return;
      }
      await _sendChatMessage(text);
      _msgController.clear();
    } catch (e) {

      if (!mounted) return;
      _showChatError(e);
    }
  }

  void _handleComposerTextChanged() {
    final nextValue = _msgController.text.trim().isNotEmpty;
    if (_hasComposerText == nextValue || !mounted) {
      return;
    }
    setState(() => _hasComposerText = nextValue);
  }

  Future<void> _sendChatMessage(String text, {String type = 'text'}) {
    if (_isInternal) {
      return _chatService.sendInternalMessage(
        widget.myHouseId,
        ChatMessage(
          id: '',
          senderId: _currentRole,
          text: text,
          type: type,
          timestamp: DateTime.now(),
        ),
      );
    }
    return _chatService.sendMessage(
      widget.myHouseId,
      widget.targetHouseId,
      text,
      type: type,
    );
  }

  Future<void> _sendQuickLike() async {
    if (_hasComposerText) {
      await _sendMsg();
      return;
    }
    await _sendSticker(_quickReactionEmoji);
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    if (!await SecurityService().guardAction(
      context,
      'chat_add_reaction',
      content: '$messageId:$emoji',
    )) {
      return;
    }

    if (_isInternal) {
      await _chatService.addInternalReaction(
        widget.myHouseId,
        messageId,
        _currentRole,
        emoji,
      );
      return;
    }
    await _chatService.addReaction(
      widget.myHouseId,
      widget.targetHouseId,
      messageId,
      emoji,
    );
  }

  Future<void> _promptPendingChatUploadRetryIfNeeded() async {
    if (_didPromptPendingChatRetry || !mounted) {
      return;
    }
    final pendingImage = await PendingUploadService.instance.load(
      _pendingChatImageUploadKey,
    );
    final pendingBackground = await PendingUploadService.instance.load(
      _pendingChatBackgroundUploadKey,
    );
    if (pendingImage == null && pendingBackground == null) {
      return;
    }
    _didPromptPendingChatRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lần upload chat trước đã bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(_retryPendingChatUploads());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingChatUploads() async {
    final pendingImage = await PendingUploadService.instance.load(
      _pendingChatImageUploadKey,
    );
    if (pendingImage != null) {
      final imagePath = pendingImage['imagePath']?.toString().trim() ?? '';
      if (imagePath.isEmpty) {
        await PendingUploadService.instance.clear(_pendingChatImageUploadKey);
      } else {
        final file = XFile(imagePath);
        try {
          if (await file.length() > 0) {
            await _pickImage(presetImage: file);
            return;
          }
        } catch (_) {}
        await PendingUploadService.instance.clear(_pendingChatImageUploadKey);
      }
    }

    final pendingBackground = await PendingUploadService.instance.load(
      _pendingChatBackgroundUploadKey,
    );
    if (pendingBackground == null) {
      return;
    }
    final filePath = pendingBackground['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance
          .clear(_pendingChatBackgroundUploadKey);
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(
          _pendingChatBackgroundUploadKey,
        );
        return;
      }
    } catch (_) {
      await PendingUploadService.instance
          .clear(_pendingChatBackgroundUploadKey);
      return;
    }
    await _pickAndSaveChatBackground(
      currentBackgroundUrl:
          pendingBackground['currentBackgroundUrl']?.toString() ?? '',
      currentBackgroundStoragePath:
          pendingBackground['currentBackgroundStoragePath']?.toString() ?? '',
      presetFile: file,
    );
  }

  Future<void> _pickImage({XFile? presetImage}) async {
    if (!await SecurityService().guardAction(context, 'chat_send_image')) {
      return;
    }

    final XFile? image = presetImage ??
        await AppLifecyclePresenceGuard.guard(
          () => ImagePickerRecoveryService.instance.pickImage(
            picker: _picker,
            source: ImageSource.gallery,
            imageQuality: 70,
            maxWidth: 1080,
          ),
        );
    if (image == null) return;

    if (mounted) setState(() => _isUploading = true);
    try {
      await PendingUploadService.instance.save(
        _pendingChatImageUploadKey,
        <String, dynamic>{'imagePath': image.path},
      );
      final upload = await _storageService.uploadChatImage(
        widget.myHouseId,
        image,
        isInternal: _isInternal,
        targetHouseId: _isInternal ? null : widget.targetHouseId,
      );

      if (upload != null) {
        await _chatService.sendImageMessage(
          widget.myHouseId,
          upload: upload,
          isInternal: _isInternal,
          targetHouseId: _isInternal ? null : widget.targetHouseId,
          senderRole: _currentRole,
        );
        await PendingUploadService.instance.clear(_pendingChatImageUploadKey);
      }
    } catch (e) {
      if (!mounted) return;
      _showNotice('Chưa thể gửi ảnh lúc này. Vui lòng thử lại.', error: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _startCall(bool isVideo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          houseId: widget.myHouseId,
          targetHouseId: widget.targetHouseId,
          targetName: widget.targetName,
          isVideo: isVideo,
          onRoomCreated: (roomId) => _chatService.sendCallInvite(
            widget.myHouseId,
            widget.targetHouseId,
            roomId: roomId,
            isVideo: isVideo,
          ),
        ),
      ),
    );
  }

  Future<void> _joinCall(ChatMessage msg) async {
    final roomId = msg.callRoomId;
    if (roomId == null || roomId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy phòng gọi')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          houseId: widget.myHouseId,
          targetHouseId: widget.targetHouseId,
          targetName: widget.targetName,
          isVideo: msg.callMode != 'audio',
          roomId: roomId,
        ),
      ),
    );
  }

  Future<void> _openWatchTogether({String? initialUrl}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WatchTogetherScreen(
          myHouseId: widget.myHouseId,
          targetHouseId: widget.targetHouseId,
          targetName: widget.targetName,
          initialUrl: initialUrl,
        ),
      ),
    );
  }

  Future<bool> _sendSticker(String sticker) async {
    if (!await SecurityService().guardAction(context, 'chat_send_sticker')) {
      return false;
    }

    try {
      if (!ConnectivityService().isOnline) {
        final offlineResponse = ChatFriendlyHelper.getFriendlyResponse(isOffline: true);
        _showNotice(offlineResponse);
        return false;
      }
      await _sendChatMessage(sticker, type: 'sticker');
      return true;
    } catch (e) {

      _showChatError(e);
      return false;
    }
  }

  void _showChatError(Object error) {
    if (!mounted) return;
    if (isSilentRapidActionBlock(error)) {
      return;
    }
    final raw = error.toString();
    final normalizedRaw = raw.toLowerCase();
    final message = normalizedRaw.contains('permission-denied') ||
            normalizedRaw.contains("client doesn't have permission")
        ? 'Không thể gửi tin nhắn lúc này. Vui lòng thử lại sau.'
        : raw
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', '')
            .trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.isEmpty ? 'Không thể gửi tin nhắn' : message),
      ),
    );
  }

  void _showNotice(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFD81B60) : null,
      ),
    );
  }

  Future<void> _toggleChatMute() async {
    final nextValue = !_isChatMuted;
    if (mounted) {
      setState(() => _isChatMuted = nextValue);
    }
    try {
      await _saveChatMute(nextValue);
      _showNotice(
        nextValue
            ? 'Đã tắt thông báo cho cuộc chat này.'
            : 'Đã bật lại thông báo cho cuộc chat này.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChatMuted = !nextValue);
      _showNotice('Chưa thể cập nhật thông báo lúc này. Vui lòng thử lại.',
          error: true);
    }
  }

  String get _chatBackgroundFolderName => _isInternal
      ? 'chat_backgrounds/internal'
      : 'chat_backgrounds/direct/$_roomId';

  Future<XFile?> _cropChatBackgroundImage(XFile file) async {
    if (kIsWeb || file.path.isEmpty) {
      return file;
    }

    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final cropHeight = (size.height - padding.top - padding.bottom - 76 - 88)
        .clamp(size.width * 1.2, size.height)
        .toDouble();
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: CropAspectRatio(
        ratioX: size.width,
        ratioY: cropHeight,
      ),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 86,
      maxWidth: 1440,
      maxHeight: 2560,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cắt nền chat',
          toolbarColor: const Color(0xFFD81B60),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
          showCropGrid: true,
          cropGridRowCount: 4,
          cropGridColumnCount: 3,
        ),
        IOSUiSettings(
          title: 'Cắt nền chat',
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (croppedFile == null) {
      return null;
    }
    return XFile(croppedFile.path);
  }

  Future<void> _pickAndSaveChatBackground({
    required String currentBackgroundUrl,
    required String currentBackgroundStoragePath,
    XFile? presetFile,
  }) async {
    if (_isUpdatingChatBackground) {
      return;
    }

    XFile? file = presetFile ?? await _storageService.pickImage();
    if (file == null) {
      return;
    }

    if (presetFile == null) {
      file = await _cropChatBackgroundImage(file);
    }
    if (file == null) {
      return;
    }

    if (mounted) {
      setState(() => _isUpdatingChatBackground = true);
    }

    StorageUploadResult? uploadResult;
    var didPersistNewBackground = false;
    Object? cleanupError;
    try {
      await PendingUploadService.instance.save(
        _pendingChatBackgroundUploadKey,
        <String, dynamic>{
          'filePath': file.path,
          'currentBackgroundUrl': currentBackgroundUrl,
          'currentBackgroundStoragePath': currentBackgroundStoragePath,
        },
      );
      uploadResult = await _storageService.uploadManagedImage(
        widget.myHouseId,
        _chatBackgroundFolderName,
        file,
        quality: 82,
        minWidth: 1080,
        minHeight: 1600,
      );
      final nextUrl = uploadResult?.downloadUrl.trim() ?? '';
      final nextStoragePath = uploadResult?.storagePath.trim() ?? '';
      if (nextUrl.isEmpty || nextStoragePath.isEmpty) {
        throw 'Không thể tải nền chat lên lúc này.';
      }

      await _chatService.updateChatBackground(
        myHouseId: widget.myHouseId,
        isInternal: _isInternal,
        backgroundUrl: nextUrl,
        backgroundStoragePath: nextStoragePath,
        targetHouseId: _isInternal ? null : widget.targetHouseId,
      );
      didPersistNewBackground = true;
      try {
        await _deletePreviousChatBackground(
          previousBackgroundUrl: currentBackgroundUrl,
          previousBackgroundStoragePath: currentBackgroundStoragePath,
          nextStoragePath: nextStoragePath,
        );
      } catch (error) {
        cleanupError = error;
      }
      if (cleanupError != null) {
        debugPrint(
            'Delete old chat background after commit failed: $cleanupError');
        _showNotice(
          'Đã cập nhật nền chat nhưng chưa xóa được file cũ. Vui lòng thử lại.',
          error: true,
        );
        return;
      }
      await PendingUploadService.instance
          .clear(_pendingChatBackgroundUploadKey);
      _showNotice('Đã cập nhật nền chat.');
    } catch (e) {
      if (!didPersistNewBackground) {
        final uploadedPath = uploadResult?.storagePath.trim() ?? '';
        if (uploadedPath.isNotEmpty) {
          try {
            await _chatService.deleteChatBackgroundAsset(
              myHouseId: widget.myHouseId,
              isInternal: _isInternal,
              targetHouseId: _isInternal ? null : widget.targetHouseId,
              storagePath: uploadedPath,
            );
          } catch (cleanupError) {
            debugPrint(
              'Rollback new chat background upload failed: $cleanupError',
            );
          }
        }
      }
      _showNotice('Chưa thể cập nhật nền chat lúc này. Vui lòng thử lại.',
          error: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingChatBackground = false);
      }
    }
  }

  Future<void> _removeChatBackground({
    required String currentBackgroundUrl,
    required String currentBackgroundStoragePath,
  }) async {
    if (_isUpdatingChatBackground) {
      return;
    }

    final hasBackground = currentBackgroundUrl.trim().isNotEmpty ||
        currentBackgroundStoragePath.trim().isNotEmpty;
    if (!hasBackground) {
      _showNotice('Đoạn chat này chưa có nền riêng.');
      return;
    }

    if (mounted) {
      setState(() => _isUpdatingChatBackground = true);
    }

    try {
      await _chatService.clearChatBackground(
        myHouseId: widget.myHouseId,
        isInternal: _isInternal,
        targetHouseId: _isInternal ? null : widget.targetHouseId,
      );
      await _deletePreviousChatBackground(
        previousBackgroundUrl: currentBackgroundUrl,
        previousBackgroundStoragePath: currentBackgroundStoragePath,
      );
      _showNotice('Đã xóa nền chat.');
    } catch (e) {
      _showNotice('Chưa thể xóa nền chat lúc này. Vui lòng thử lại.',
          error: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingChatBackground = false);
      }
    }
  }

  Future<void> _deletePreviousChatBackground({
    required String previousBackgroundUrl,
    required String previousBackgroundStoragePath,
    String? nextStoragePath,
  }) async {
    final oldStoragePath = previousBackgroundStoragePath.trim();
    final oldUrl = previousBackgroundUrl.trim();
    final normalizedNextStoragePath = (nextStoragePath ?? '').trim();
    if (oldStoragePath.isEmpty && oldUrl.isEmpty) {
      return;
    }
    if (normalizedNextStoragePath.isNotEmpty &&
        oldStoragePath == normalizedNextStoragePath) {
      return;
    }

    if (oldStoragePath.isNotEmpty) {
      await _chatService.deleteChatBackgroundAsset(
        myHouseId: widget.myHouseId,
        isInternal: _isInternal,
        targetHouseId: _isInternal ? null : widget.targetHouseId,
        storagePath: oldStoragePath,
      );
      return;
    }

    final oldStoragePathFromUrl =
        _storageService.extractStoragePathFromUrl(oldUrl)?.trim() ?? '';
    if (oldStoragePathFromUrl.isNotEmpty) {
      if (normalizedNextStoragePath.isNotEmpty &&
          oldStoragePathFromUrl == normalizedNextStoragePath) {
        return;
      }
      await _chatService.deleteChatBackgroundAsset(
        myHouseId: widget.myHouseId,
        isInternal: _isInternal,
        targetHouseId: _isInternal ? null : widget.targetHouseId,
        storagePath: oldStoragePathFromUrl,
      );
      return;
    }

    final deletedByUrl = await _storageService.deleteImageByUrl(oldUrl);
    if (!deletedByUrl) {
      throw Exception('Không thể xóa file nền chat cũ trên Firebase Storage.');
    }
  }

  Future<void> _sendFriendlyResponse() async {
    final response = ChatFriendlyHelper.getFriendlyResponse(
      isOffline: !ConnectivityService().isOnline,
    );
    
    if (!ConnectivityService().isOnline) {
      _showNotice(response);
      return;
    }

    try {
      await _sendChatMessage(response);
      _showNotice('Đã gửi lời chúc thân thiện! ✨');
    } catch (e) {
      _showChatError(e);
    }
  }
}

