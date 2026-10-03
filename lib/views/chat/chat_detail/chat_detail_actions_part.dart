// ignore_for_file: invalid_use_of_protected_member
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
                  L10nService().format('ui_chat_unlock_to_review_the_conversation_with_value1_c2d8c8', {'value1': _nickname.trim().isEmpty ? widget.targetName : _nickname.trim()}),
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
    if (text.isEmpty || _isSendingMessage) {
      return;
    }

    if (text.startsWith('/')) {
      String code = '';
      if (text.toLowerCase().startsWith('/code ')) {
        code = text.substring(6).trim();
      } else if (text.toLowerCase().startsWith('/giftcode ')) {
        code = text.substring(10).trim();
      } else {
        code = text.substring(1).trim();
      }

      final RegExp giftcodeRegex = RegExp(r'^[a-zA-Z0-9_-]{3,32}$');
      if (giftcodeRegex.hasMatch(code)) {
        _isSendingMessage = true;
        _msgController.clear();
        try {
          final result = await GiftcodeService().redeemGiftcode(
            houseId: widget.myHouseId,
            code: code,
          );
          if (!mounted) return;

          String displayMessage = result.message;
          if (result.success) {
            final days = result.daysAdded ?? 0;
            if (days > 0) {
              displayMessage =
                  L10nService().format('ui_chat_congratulations_you_have_successfully_received_value1_vip_b6450f', {'value1': days});
            } else {
              displayMessage =
                  L10nService().translate('ui_chat_congratulations_you_have_successfully_activated_the_gift_2ccae4');
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SLSnackBar(
              content: Text(displayMessage),
              backgroundColor: result.success ? Colors.green : Colors.red,
            ),
          );
        } catch (e) {
          debugPrint('Error redeeming giftcode in chat: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SLSnackBar(
                content: Text(context.tr('ui_chat_an_error_occurred_while_activating_giftcode_4977e4')),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          _isSendingMessage = false;
        }
        return;
      }
    }

    if (!await SecurityService().guardAction(context, 'chat_send_message')) {
      return;
    }

    _isSendingMessage = true;
    try {
      await _sendChatMessage(text);
      _msgController.clear();
    } catch (e) {
      if (!mounted) return;
      _showChatError(e);
    } finally {
      _isSendingMessage = false;
    }
  }

  void _handleComposerTextChanged() {
    final nextValue = _msgController.text.trim().isNotEmpty;
    if (_hasComposerText == nextValue || !mounted) {
      return;
    }
    setState(() => _hasComposerText = nextValue);
  }

  Future<void> _sendChatMessage(String text, {String type = 'text'}) async {
    if (_isInternal) {
      await _chatService.sendInternalMessage(
        widget.myHouseId,
        ChatMessage(
          id: '',
          senderId: _currentRole,
          text: text,
          type: type,
          timestamp: DateTime.now(),
        ),
      );
    } else {
      await _chatService.sendMessage(
        widget.myHouseId,
        widget.targetHouseId,
        text,
        type: type,
      );
    }
    // Một âm chung cho text/sticker, chỉ sau khi ghi tin nhắn thành công.
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
      unawaited(SoundService().playSent());
    }
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
        SLSnackBar(
          content: Text(context.tr('chat_upload_interrupted')),
          action: SnackBarAction(
            label: context.tr('Thử lại'),
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
        } catch (error) {
          debugPrint(
            '[SuppressedError] lib/views/chat/chat_detail/chat_detail_actions_part.dart: $error',
          );
        }
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
      await PendingUploadService.instance.clear(
        _pendingChatBackgroundUploadKey,
      );
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
      await PendingUploadService.instance.clear(
        _pendingChatBackgroundUploadKey,
      );
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

    try {
      final vipAccess = await PurchaseService().getVipAccessInfo();
      final limit = vipAccess.isVip ? 50 : 20;

      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final countKey = 'chat_sent_images_count_$todayStr';
      final sentCount = prefs.getInt(countKey) ?? 0;

      if (sentCount >= limit) {
        final noticeMsg = vipAccess.isVip
            ? L10nService().translate('ui_chat_you_have_reached_the_sending_limit_of_debc2f')
            : L10nService().translate('ui_chat_oops_you_ve_sent_all_20_photos_372f19');
        _showNotice(noticeMsg, error: true);
        return;
      }
    } catch (e) {
      debugPrint('Error checking chat image limit: $e');
    }

    final XFile? image =
        presetImage ??
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

        try {
          final prefs = await SharedPreferences.getInstance();
          final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
          final countKey = 'chat_sent_images_count_$todayStr';
          final sentCount = prefs.getInt(countKey) ?? 0;
          await prefs.setInt(countKey, sentCount + 1);
        } catch (e) {
          debugPrint('Error incrementing sent image count: $e');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showNotice(context.tr('ui_chat_can_t_send_photos_at_this_time_a8440f'), error: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _startCall(bool isVideo) async {
    await slPush(
      context,
      VideoCallScreen(
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
    );
  }

  Future<void> _joinCall(ChatMessage msg) async {
    final roomId = msg.callRoomId;
    if (roomId == null || roomId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SLSnackBar(content: Text(context.tr('ui_chat_call_room_not_found_7b6fe4'))));
      return;
    }

    await slPush(
      context,
      VideoCallScreen(
        houseId: widget.myHouseId,
        targetHouseId: widget.targetHouseId,
        targetName: widget.targetName,
        isVideo: msg.callMode != 'audio',
        roomId: roomId,
      ),
    );
  }

  Future<void> _openWatchTogether({String? initialUrl}) async {
    await slPush(
      context,
      WatchTogetherScreen(
        myHouseId: widget.myHouseId,
        targetHouseId: widget.targetHouseId,
        targetName: widget.targetName,
        initialUrl: initialUrl,
      ),
    );
  }

  Future<bool> _sendSticker(String sticker) async {
    if (_isSendingMessage) {
      return false;
    }
    if (!await SecurityService().guardAction(context, 'chat_send_sticker')) {
      return false;
    }

    _isSendingMessage = true;
    try {
      await _sendChatMessage(sticker, type: 'sticker');
      return true;
    } catch (e) {
      _showChatError(e);
      return false;
    } finally {
      _isSendingMessage = false;
    }
  }

  void _showChatError(Object error) {
    if (!mounted) return;
    if (isSilentRapidActionBlock(error)) {
      return;
    }
    final message = AppErrorMapper.resolve(
      error,
      fallbackMessage: context.tr('ui_chat_messages_cannot_be_sent_at_this_time_74fe87'),
    ).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(
        content: Text(message.isEmpty ? context.tr('ui_chat_cannot_send_message_b931ba') : message),
      ),
    );
  }

  void _showNotice(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(
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
            ? context.tr('ui_chat_notifications_for_this_chat_have_been_turned_62a0d8')
            : context.tr('ui_chat_notifications_have_been_turned_back_on_for_1e4a51'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChatMuted = !nextValue);
      _showNotice(
        context.tr('p9_group_chat_notification_update_failed'),
        error: true,
      );
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
      aspectRatio: CropAspectRatio(ratioX: size.width, ratioY: cropHeight),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 86,
      maxWidth: 1440,
      maxHeight: 2560,
      uiSettings: [
        IOSUiSettings(
          title: context.tr('ui_chat_crop_chat_background_c0c52d'),
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
      await PendingUploadService.instance
          .save(_pendingChatBackgroundUploadKey, <String, dynamic>{
            'filePath': file.path,
            'currentBackgroundUrl': currentBackgroundUrl,
            'currentBackgroundStoragePath': currentBackgroundStoragePath,
          });
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
        throw L10nService().translate('ui_chat_chat_background_cannot_be_uploaded_at_this_5d1a3c');
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
          'Delete old chat background after commit failed: ${AppErrorMapper.cleanMessage(cleanupError)}',
        );
        _showNotice(
          context.tr('ui_chat_the_chat_background_has_been_updated_but_8095b4'),
          error: true,
        );
        return;
      }
      await PendingUploadService.instance.clear(
        _pendingChatBackgroundUploadKey,
      );
      _showNotice(context.tr('ui_chat_updated_chat_background_b3d37a'));
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
              'Rollback new chat background upload failed: ${AppErrorMapper.cleanMessage(cleanupError)}',
            );
          }
        }
      }
      _showNotice(
        context.tr('ui_chat_chat_background_cannot_be_updated_at_this_5ccf1c'),
        error: true,
      );
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

    final hasBackground =
        currentBackgroundUrl.trim().isNotEmpty ||
        currentBackgroundStoragePath.trim().isNotEmpty;
    if (!hasBackground) {
      _showNotice(context.tr('ui_chat_this_chat_does_not_have_its_own_f59ecd'));
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
      _showNotice(context.tr('ui_chat_removed_chat_background_cc75d0'));
    } catch (e) {
      _showNotice(
        context.tr('ui_chat_it_is_not_possible_to_delete_the_672dcc'),
        error: true,
      );
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
      throw Exception(L10nService().translate('ui_chat_old_chat_background_files_cannot_be_deleted_c6e145'));
    }
  }
}
