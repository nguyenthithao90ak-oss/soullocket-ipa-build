part of 'community_tab.dart';

extension _CommunityTabComposer on _CommunityTabState {
  String? get _pendingCommunityPostUploadKey {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) {
      return null;
    }
    return 'community_post_$houseId';
  }

  String? get _pendingCommunityLocketUploadKey {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) {
      return null;
    }
    return 'community_locket_$houseId';
  }

  Future<void> _promptPendingCommunityUploadRetryIfNeeded() async {
    if (_didPromptPendingCommunityUploadRetry || !mounted) {
      return;
    }
    final postKey = _pendingCommunityPostUploadKey;
    final locketKey = _pendingCommunityLocketUploadKey;
    if (postKey == null || locketKey == null) {
      return;
    }
    final pendingPost = await PendingUploadService.instance.load(postKey);
    final pendingLocket = await PendingUploadService.instance.load(locketKey);
    if (pendingPost == null && pendingLocket == null) {
      return;
    }
    _didPromptPendingCommunityUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _ct(
              'Lần upload bài cộng đồng trước đã bị gián đoạn.',
              'The last community upload was interrupted.',
            ),
          ),
          action: SnackBarAction(
            label: _ct('Thử lại', 'Retry'),
            onPressed: () {
              unawaited(_retryPendingCommunityUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingCommunityUpload() async {
    final postKey = _pendingCommunityPostUploadKey;
    if (postKey != null) {
      final pendingPost = await PendingUploadService.instance.load(postKey);
      if (pendingPost != null) {
        final imagePath = pendingPost['imagePath']?.toString().trim() ?? '';
        if (imagePath.isNotEmpty) {
          final file = XFile(imagePath);
          try {
            if (await file.length() > 0) {
              await _submitCommunityPost(
                content: pendingPost['content']?.toString() ?? '',
                visibility: pendingPost['visibility']?.toString() ?? 'public',
                isAnon: pendingPost['isAnon'] == true,
                selectedImage: file,
                locationText: pendingPost['locationText']?.toString() ?? '',
                moodEmoji: pendingPost['moodEmoji']?.toString() ?? '',
                moodLabel: pendingPost['moodLabel']?.toString() ?? '',
                isLocketPost: pendingPost['isLocketPost'] == true,
                resolvedPostType:
                    pendingPost['resolvedPostType']?.toString() ?? 'polaroid',
              );
              return;
            }
          } catch (_) {}
        }
        await PendingUploadService.instance.clear(postKey);
      }
    }

    final locketKey = _pendingCommunityLocketUploadKey;
    if (locketKey == null) {
      return;
    }
    final pendingLocket = await PendingUploadService.instance.load(locketKey);
    if (pendingLocket == null) {
      return;
    }
    final imagePath = pendingLocket['imagePath']?.toString().trim() ?? '';
    if (imagePath.isEmpty) {
      await PendingUploadService.instance.clear(locketKey);
      return;
    }
    final file = XFile(imagePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(locketKey);
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(locketKey);
      return;
    }
    await _submitLocketPost(file);
  }

  Future<void> _submitLocketPost(XFile capturedImage) async {
    if (_isLoading) return;
    _updateState(() => _isLoading = true);
    final pendingKey = _pendingCommunityLocketUploadKey;
    try {
      final hid = _houseId;
      if (hid == null || hid.isEmpty) return;
      final authorUid = _auth.currentUser?.uid ?? '';
      if (authorUid.isEmpty) return;

      if (pendingKey != null) {
        await PendingUploadService.instance.save(
          pendingKey,
          <String, dynamic>{'imagePath': capturedImage.path},
          category: 'community_locket',
        );
      }

      final upload = await _storageService.uploadPublicImage(
        hid,
        'social_post',
        capturedImage,
        quality: 65,
        minWidth: 800,
        minHeight: 800,
      );
      final sessionId = upload?.sessionId?.trim() ?? '';
      if (sessionId.isEmpty) {
        throw Exception('Không thể tải ảnh lên lúc này.');
      }

      await _storageService.finalizePublicImageUpload(
        houseId: hid,
        sessionId: sessionId,
        target: 'social_post',
        houseName: _houseName,
        authorRole: authorUid,
        authorName: _houseName,
        authorAvt: _houseAvatar,
        content: '',
        privacy: 'friends',
        mood: _ct('Tự hào', 'Proud'),
        moodEmoji: '✨',
        location: '',
        postType: 'polaroid',
        isAnon: false,
        isLocket: true,
        commentsEnabled: _houseSettings['settings']?['commentPolicy'] != 'none',
      );
      if (pendingKey != null) {
        await PendingUploadService.instance.clear(pendingKey);
      }

      if (!mounted) return;
      LegacyWebUi.showNotice(
        context,
        message: _ct(
          'Đã gửi khoảnh khắc cho bạn bè!',
          'Moment sent to friends!',
        ),
        title: 'Locket',
        icon: Icons.rocket_launch_rounded,
      );
    } catch (e) {
      if (pendingKey != null) {
        await PendingUploadService.instance.markFailed(pendingKey, e);
      }
      if (!mounted) return;
      LegacyWebUi.showNoticeWithAction(
        context,
        message: _ct(
          'Không thể đăng Locket lúc này: $e',
          'Cannot post this Locket right now: $e',
        ),
        success: false,
        title: _ct('Lỗi', 'Error'),
        icon: Icons.error_outline_rounded,
        actionLabel: _ct('Thử lại', 'Retry'),
        onAction: () {
          unawaited(_submitLocketPost(capturedImage));
        },
      );
    } finally {
      _updateState(() => _isLoading = false);
    }
  }

  Future<void> _submitCommunityPost({
    required String content,
    required String visibility,
    required bool isAnon,
    required XFile? selectedImage,
    required String locationText,
    required String moodEmoji,
    required String moodLabel,
    required bool isLocketPost,
    required String resolvedPostType,
  }) async {
    if (_isLoading) return;
    _updateState(() => _isLoading = true);
    try {
      final hid = _houseId;
      if (hid == null || hid.isEmpty) return;
      final authorUid = _auth.currentUser?.uid ?? '';
      if (authorUid.isEmpty) return;

      var hasViolations = false;
      var resolvedVisibility = visibility;
      var moderationReason = '';
      final moderation = _moderateCommunityText(content);
      if (moderation.hasViolation) {
        hasViolations = true;
        moderationReason = moderation.reason;
        if (moderation.shouldPrivate) {
          resolvedVisibility = 'private';
        }
      }

      if (selectedImage == null) {
        await _socialService.createPostUnified(
          houseId: hid,
          houseName: _houseName,
          authorRole: authorUid,
          authorName: _houseName,
          authorAvt: _houseAvatar,
          content: content,
          imageUrl: '',
          videoUrl: '',
          privacy: resolvedVisibility,
          mood: moodLabel,
          moodEmoji: moodEmoji,
          location: locationText,
          postType: resolvedPostType,
          isAnon: isAnon,
          isLocket: isLocketPost,
          commentsEnabled:
              _houseSettings['settings']?['commentPolicy'] != 'none',
        );
      } else {
        final pendingKey = _pendingCommunityPostUploadKey;
        if (pendingKey != null) {
          await PendingUploadService.instance.save(
            pendingKey,
            <String, dynamic>{
              'content': content,
              'visibility': resolvedVisibility,
              'isAnon': isAnon,
              'imagePath': selectedImage.path,
              'locationText': locationText,
              'moodEmoji': moodEmoji,
              'moodLabel': moodLabel,
              'isLocketPost': isLocketPost,
              'resolvedPostType': resolvedPostType,
            },
            category: 'community_post',
          );
        }

        final upload = await _storageService.uploadPublicImage(
          hid,
          'social_post',
          selectedImage,
          quality: 80,
          minWidth: 1280,
          minHeight: 1280,
        );
        final sessionId = upload?.sessionId?.trim() ?? '';
        if (sessionId.isEmpty) {
          throw Exception('Không thể tải ảnh lên lúc này.');
        }
        await _storageService.finalizePublicImageUpload(
          houseId: hid,
          sessionId: sessionId,
          target: 'social_post',
          houseName: _houseName,
          authorRole: authorUid,
          authorName: _houseName,
          authorAvt: _houseAvatar,
          content: content,
          privacy: resolvedVisibility,
          mood: moodLabel,
          moodEmoji: moodEmoji,
          location: locationText,
          postType: resolvedPostType,
          isAnon: isAnon,
          isLocket: isLocketPost,
          commentsEnabled:
              _houseSettings['settings']?['commentPolicy'] != 'none',
          flagged: hasViolations,
        );
        if (pendingKey != null) {
          await PendingUploadService.instance.clear(pendingKey);
        }
      }
      if (!mounted) return;
      if (hasViolations) {
        LegacyWebUi.showNotice(
          context,
          message: moderationReason.isNotEmpty
              ? _ctf(
                  'Bài viết của bạn đã bị đánh dấu kiểm duyệt. Lý do: {reason}. Bài viết đã được hạ mức hiển thị an toàn để tránh vi phạm lặp lại.',
                  'Your post was flagged for moderation. Reason: {reason}. The visibility was reduced to a safer level to avoid repeated violations.',
                  {'reason': moderationReason},
                )
              : _ct(
                  'Bài viết của bạn chứa từ khóa vi phạm (tục tĩu/chửi bới). Bài viết đã bị gỡ khỏi cộng đồng và chuyển về chế độ riêng tư. Hình phạt: Cảnh cáo vi phạm tiêu chuẩn cộng đồng, nếu tái phạm sẽ bị khóa tài khoản.',
                  'Your post contains violating keywords. It has been removed from the community and moved to private mode. This is a warning for violating community standards. Repeated violations may lead to an account lock.',
                ),
          title: _ct('Cảnh báo vi phạm', 'Violation warning'),
          icon: Icons.warning_amber_rounded,
          success: false,
        );
      } else {
        LegacyWebUi.showNotice(
          context,
          message: _ct(
            'Bài viết của bạn đã lên cộng đồng và giữ đúng luật hiển thị.',
            'Your post is now live in the community and follows the visibility rules.',
          ),
          title: _ct('Đăng bài thành công', 'Post published'),
          icon: Icons.celebration_rounded,
        );
      }
    } catch (e, stackTrace) {
      final pendingKey = _pendingCommunityPostUploadKey;
      if (pendingKey != null) {
        await PendingUploadService.instance.markFailed(pendingKey, e);
      }
      debugPrint('Error submit post: $e\n$stackTrace');
      if (!mounted) return;
      LegacyWebUi.showNoticeWithAction(
        context,
        message: _ct(
          'Không thể đăng bài lúc này: $e',
          'Cannot publish the post right now: $e',
        ),
        success: false,
        title: _ct('Đăng bài chưa thành công', 'Post not published'),
        icon: Icons.cloud_off_rounded,
        actionLabel: _ct('Thử lại', 'Retry'),
        onAction: () {
          unawaited(
            _submitCommunityPost(
              content: content,
              visibility: visibility,
              isAnon: isAnon,
              selectedImage: selectedImage,
              locationText: locationText,
              moodEmoji: moodEmoji,
              moodLabel: moodLabel,
              isLocketPost: isLocketPost,
              resolvedPostType: resolvedPostType,
            ),
          );
        },
      );
    } finally {
      _updateState(() => _isLoading = false);
    }
  }

  Future<void> _openComposer({bool openImagePicker = false}) async {
    if (_currentFeedType == 'locket') {
      // Nhảy thẳng vào camera nếu là tab Locket
      if (!mounted) return;
      final capturedImage = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (_) => const LocketCameraScreen()),
      );

      if (capturedImage != null) {
        await _submitLocketPost(capturedImage);
      }
      return;
    }

    final controller = TextEditingController();
    String visibility = 'public';
    bool isAnon = false;
    XFile? selectedImage;
    bool isPickingImage = false;
    String locationText = '';
    String moodEmoji = '';
    String moodLabel = '';
    bool looksLikeQuestion(String value) {
      final text = value.trim();
      if (text.isEmpty) return false;
      return text.contains('?') ||
          text.endsWith('؟') ||
          text.toLowerCase().startsWith(_ct('xin lời khuyên', 'need advice'));
    }

    String fallbackPostType() {
      if (selectedImage != null) return 'polaroid';
      if (looksLikeQuestion(controller.text)) return 'question';
      return 'mood';
    }

    String resolveComposerPostType() => fallbackPostType();

    Future<void> editComposerImage(
      void Function(void Function()) setInner,
      BuildContext bottomSheetContext,
    ) async {
      if (selectedImage == null) return;
      setInner(() => isPickingImage = true);
      try {
        if (!bottomSheetContext.mounted) return;

        try {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: selectedImage!.path,
            compressFormat: ImageCompressFormat.jpg,
            compressQuality: 70,
            uiSettings: [
              IOSUiSettings(
                title: _ct('Chỉnh sửa ảnh', 'Edit photo'),
              ),
            ],
          );

          if (croppedFile != null) {
            if (!bottomSheetContext.mounted) return;
            setInner(() {
              selectedImage = XFile(croppedFile.path);
            });
          }
        } catch (e) {
          debugPrint('Edit cropping failed: $e');
          if (!mounted) return;
          LegacyWebUi.showNotice(
            context,
            message: _ct(
              'Không thể mở trình chỉnh sửa ảnh: $e',
              'Cannot open the photo editor: $e',
            ),
            success: false,
            title: _ct('Lỗi', 'Error'),
            icon: Icons.broken_image_outlined,
          );
        }
      } catch (e) {
        if (!mounted) return;
        LegacyWebUi.showNotice(
          context,
          message: _ct(
            'Không thể chỉnh sửa ảnh: $e',
            'Cannot edit the photo: $e',
          ),
          success: false,
          title:
              _ct('Ảnh đính kèm đang gặp lỗi', 'Attached photo has an issue'),
          icon: Icons.broken_image_outlined,
        );
      } finally {
        if (bottomSheetContext.mounted) {
          setInner(() => isPickingImage = false);
        }
      }
    }

    Future<void> pickComposerImage(
      void Function(void Function()) setInner,
      BuildContext bottomSheetContext,
    ) async {
      setInner(() => isPickingImage = true);
      try {
        final file = await _storageService.pickImage();
        if (file == null) {
          if (bottomSheetContext.mounted) {
            setInner(() => isPickingImage = false);
          }
          return;
        }
        if (!bottomSheetContext.mounted) return;

        try {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: file.path,
            compressFormat: ImageCompressFormat.jpg,
            compressQuality: 70,
            uiSettings: [
              IOSUiSettings(
                title: _ct('Chỉnh sửa ảnh', 'Edit photo'),
              ),
            ],
          );

          if (croppedFile != null) {
            if (!bottomSheetContext.mounted) return;
            setInner(() {
              selectedImage = XFile(croppedFile.path);
            });
          } else {
            // User cancelled cropping, keep original image
            if (!bottomSheetContext.mounted) return;
            setInner(() {
              selectedImage = file;
            });
          }
        } catch (e) {
          // If cropping fails (some devices have issues with ImageCropper), use original image
          debugPrint('Cropping failed: $e');
          if (!bottomSheetContext.mounted) return;
          setInner(() {
            selectedImage = file;
          });
        }
      } catch (e) {
        if (!mounted) return;
        LegacyWebUi.showNotice(
          context,
          message: _ct(
            'Không thể chọn ảnh: $e',
            'Cannot pick a photo: $e',
          ),
          success: false,
          title: _ct('Chưa thêm được ảnh', 'Photo not added'),
          icon: Icons.image_not_supported_outlined,
        );
      } finally {
        if (bottomSheetContext.mounted) {
          setInner(() => isPickingImage = false);
        }
      }
    }

    Future<void> editLocation(void Function(void Function()) setInner) async {
      final locationController = TextEditingController(text: locationText);
      final nextValue = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: SLRadius.xlAll,
            ),
            title: Text(
              _ct('Gắn vị trí cho bài viết', 'Add a location to the post'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w900),
            ),
            content: TextField(
              controller: locationController,
              autofocus: true,
              style: SLTheme.quicksand(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: _ct(
                  'Ví dụ: Hà Nội, quán quen, Đà Lạt...',
                  'Example: Hanoi, favorite cafe, Da Lat...',
                ),
                border: OutlineInputBorder(
                  borderRadius: SLRadius.lgAll,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, locationText),
                child: Text(_ct('Hủy', 'Cancel')),
              ),
              if (locationText.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: Text(_ct('Xóa', 'Delete')),
                ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, locationController.text.trim()),
                child: Text(_ct('Lưu', 'Save')),
              ),
            ],
          );
        },
      );
      locationController.dispose();
      if (nextValue == null) return;
      setInner(() => locationText = nextValue.trim());
    }

    Future<void> pickMood(void Function(void Function()) setInner) async {
      final selected = await showModalBottomSheet<Map<String, String>>(
        context: context,
        backgroundColor: const Color(0xFF18191A),
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ct('Chọn tâm trạng cho bài viết',
                      'Choose a mood for the post'),
                  style: SLTheme.quicksand(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF222222),
                  ),
                ),
                SLSpacing.h12,
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final preset
                        in _CommunityTabState._composerMoodPresets)
                      InkWell(
                        onTap: () => Navigator.pop(ctx, preset),
                        borderRadius: SLRadius.lgAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F5),
                            borderRadius: SLRadius.lgAll,
                            border: Border.all(
                              color: const Color(0xFFF8BBD0),
                            ),
                          ),
                          child: Text(
                            '${preset['emoji']} ${preset['label']}',
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD81B60),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (moodLabel.isNotEmpty) ...[
                  SLSpacing.h12,
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx, <String, String>{}),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      _ct('Xóa tâm trạng đã chọn', 'Clear selected mood'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );

      if (selected == null) return;
      setInner(() {
        moodEmoji = (selected['emoji'] ?? '').trim();
        moodLabel = (selected['label'] ?? '').trim();
      });
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            // Tự động mở bộ chọn ảnh nếu được yêu cầu
            if (openImagePicker && selectedImage == null && !isPickingImage) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                pickComposerImage(setInner, ctx);
              });
              openImagePicker = false; // Chỉ mở 1 lần
            }

            final selectedAudience =
                visibility == 'friends' ? 'friends' : 'public';

            /*

            Widget buildAudienceOption({
              required String value,
              required String label,
              required IconData icon,
              required Color color,
            }) {
              final isSelected = selectedAudience == value;
              return InkWell(
                onTap: () => applyAudience(value),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.12)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.42)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected ? color : const Color(0xFF64748B),
                      ),
                      SLSpacing.w8,
                      Text(
                        label,
                        style: SLTheme.quicksand(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? color : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

                                'Cần thêm ảnh để dùng kiểu này.',

            */
            return FractionallySizedBox(
              heightFactor: 1,
              child: Material(
                color: const Color(0xFFF8FAFC),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        color: Colors.white,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 86,
                              child: TextButton.icon(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                icon: const Icon(Icons.close_rounded),
                                label: Text(
                                  _ct('Hủy', 'Cancel'),
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _ct('Tạo bài viết', 'Create post'),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD81B60),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 86,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFD81B60),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: SLRadius.pillAll,
                                    ),
                                  ),
                                  child: Text(
                                    _ct('ĐĂNG', 'POST'),
                                    style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: SLSpacing.all16,
                                decoration: LegacyWebUi.softPanelDecoration(
                                  accent: const Color(0xFFD81B60),
                                  radius: 24,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFFF0F2F5),
                                      backgroundImage: _houseAvatar.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              _houseAvatar)
                                          : null,
                                      child: _houseAvatar.isEmpty
                                          ? const Icon(
                                              Icons.favorite_rounded,
                                              color: Color(0xFFD81B60),
                                            )
                                          : null,
                                    ),
                                    SLSpacing.w12,
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          /*
                                          Text(
                                            _houseName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: SLTheme.quicksand(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                          SLSpacing.h8,
                                          if (selectedAudience ==
                                              'legacy-never')
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF1F5F9),
                                                    borderRadius:
                                                        SLRadius.smAll,
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFE2E8F0),
                                                    ),
                                                  ),
                                                  child:
                                                      DropdownButtonHideUnderline(
                                                    child:
                                                        DropdownButton<String>(
                                                      value: visibility,
                                                      isDense: true,
                                                      style: SLTheme.quicksand(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: const Color(
                                                            0xFF475569),
                                                      ),
                                                      items: [
                                                        DropdownMenuItem(
                                                          value: 'public',
                                                          child: Text(
                                                            _ct(
                                                              '🌐 Công khai',
                                                              '🌐 Public',
                                                            ),
                                                          ),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'friends',
                                                          child: Text(
                                                            _ct(
                                                              '👥 Bạn bè',
                                                              '👥 Friends',
                                                            ),
                                                          ),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'private',
                                                          child: Text(
                                                            _ct(
                                                              '🔒 Riêng tư',
                                                              '🔒 Private',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      onChanged: (v) {
                                                        if (v == null) return;
                                                        setInner(() =>
                                                            visibility = v);
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () => setInner(
                                                      () => isAnon = !isAnon),
                                                  borderRadius: SLRadius.smAll,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFF1F5F9),
                                                      borderRadius:
                                                          SLRadius.smAll,
                                                      border: Border.all(
                                                        color: const Color(
                                                            0xFFE2E8F0),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Checkbox(
                                                          value: isAnon,
                                                          onChanged: (v) =>
                                                              setInner(
                                                            () => isAnon =
                                                                v ?? false,
                                                          ),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          activeColor:
                                                              const Color(
                                                            0xFFD81B60,
                                                          ),
                                                        ),
                                                        Text(
                                                          _ct('Ẩn danh',
                                                              'Anonymous'),
                                                          style:
                                                              SLTheme.quicksand(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: const Color(
                                                                0xFF475569),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          Text(
                                            _ct(
                                              'Chọn cách hiển thị cho bài viết',
                                              'Choose how this post will appear',
                                            ),
                                            style: SLTheme.quicksand(
                                              fontSize: 12.2,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              buildAudienceOption(
                                                value: 'public',
                                                label:
                                                    _ct('Công khai', 'Public'),
                                                icon: Icons.public_rounded,
                                                color: const Color(0xFF2563EB),
                                              ),
                                              buildAudienceOption(
                                                value: 'friends',
                                                label: _ct('Bạn bè', 'Friends'),
                                                icon: Icons.people_alt_rounded,
                                                color: const Color(0xFF0F766E),
                                              ),
                                              buildAudienceOption(
                                                value: 'anonymous',
                                                label:
                                                    _ct('Ẩn danh', 'Anonymous'),
                                                icon: Icons
                                                    .visibility_off_rounded,
                                                color: const Color(0xFFD81B60),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            _ct(
                                              'Chọn kiểu hiển thị cho bài viết',
                                              'Choose the post style',
                                            ),
                                            style: SLTheme.quicksand(
                                              fontSize: 12.2,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              buildPostTypeOption(
                                                value: 'mood',
                                                label: _ct(
                                                    'Mood card', 'Mood card'),
                                                subtitle: _ct(
                                                  'Nền đổi theo cảm xúc và tâm trạng.',
                                                  'Mood background based on the feeling.',
                                                ),
                                                icon:
                                                    Icons.auto_awesome_rounded,
                                                color: const Color(0xFFD81B60),
                                              ),
                                              buildPostTypeOption(
                                                value: 'polaroid',
                                                label:
                                                    _ct('Polaroid', 'Polaroid'),
                                                subtitle: _ct(
                                                  'Ưu tiên ảnh và caption như khung ảnh.',
                                                  'Photo-first layout with a framed caption.',
                                                ),
                                                icon: Icons
                                                    .photo_camera_back_rounded,
                                                color: const Color(0xFF2563EB),
                                              ),
                                              buildPostTypeOption(
                                                value: 'question',
                                                label:
                                                    _ct('Question', 'Question'),
                                                subtitle: _ct(
                                                  'Dành cho bài xin lời khuyên.',
                                                  'Best for advice or help requests.',
                                                ),
                                                icon:
                                                    Icons.help_outline_rounded,
                                                color: const Color(0xFFF59E0B),
                                              ),
                                              buildPostTypeOption(
                                                value: 'confession',
                                                label: _ct(
                                                    'Confession', 'Confession'),
                                                subtitle: _ct(
                                                  'Tự bật ẩn danh cho bài tâm sự.',
                                                  'Automatically posts as anonymous.',
                                                ),
                                                icon: Icons
                                                    .favorite_border_rounded,
                                                color: const Color(0xFF7C3AED),
                                              ),
                                            ],
                                          ),
                                          */
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SLSpacing.h16,
                              // Đã loại bỏ _buildCommunityRulesCard ở đây để ẩn thẻ nội quy
                              Container(
                                width: double.infinity,
                                padding: SLSpacing.all20,
                                decoration: LegacyWebUi.softPanelDecoration(
                                  accent: const Color(0xFFD81B60),
                                  radius: 28,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _ct('Nội dung bài viết',
                                              'Post content'),
                                          style: SLTheme.quicksand(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFD81B60),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF1F5),
                                            borderRadius: SLRadius.pillAll,
                                            border: Border.all(
                                              color: const Color(0xFFF8BBD0),
                                            ),
                                          ),
                                          child: Text(
                                            '${controller.text.trim().length}/$_communityPostMaxLength',
                                            style: SLTheme.quicksand(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFFD81B60),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SLSpacing.h12,
                                    TextField(
                                      controller: controller,
                                      maxLines: null,
                                      minLines: 10,
                                      maxLength: _communityPostMaxLength,
                                      onChanged: (_) => setInner(() {}),
                                      style: SLTheme.quicksand(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF334155),
                                        height: 1.5,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: _ct(
                                          'Bạn muốn chia sẻ điều gì với cộng đồng?',
                                          'What do you want to share with the community?',
                                        ),
                                        hintStyle: SLTheme.quicksand(
                                          color: const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        border: InputBorder.none,
                                        counterText: '',
                                      ),
                                    ),
                                    Text(
                                      _ctf(
                                        'Tối đa {count} ký tự. Hệ thống sẽ từ chối bài có dấu hiệu spam hoặc nội dung 18+.',
                                        'Up to {count} characters. The system rejects spam-like or 18+ content.',
                                        {'count': _communityPostMaxLength},
                                      ),
                                      style: SLTheme.quicksand(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF94A3B8),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox.shrink(),
                              if (selectedAudience == 'legacy-never')
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildComposerStarterChip(
                                        label: _ct('Kỷ niệm', 'Memory'),
                                        color: const Color(0xFF2563EB),
                                        onTap: () {
                                          final starter = _ct(
                                            'Kể một kỷ niệm đáng nhớ nè...',
                                            'Tell everyone about a memorable moment...',
                                          );
                                          controller.value = TextEditingValue(
                                            text: starter,
                                            selection: TextSelection.collapsed(
                                              offset: starter.length,
                                            ),
                                          );
                                        },
                                      ),
                                      _buildComposerStarterChip(
                                        label: _ct('Lời yêu', 'Sweet note'),
                                        color: const Color(0xFFD81B60),
                                        onTap: () {
                                          final starter = _ct(
                                            'Hôm nay mình muốn gửi một lời yêu thương tới mọi người...',
                                            'Today I want to send a warm note to everyone...',
                                          );
                                          controller.value = TextEditingValue(
                                            text: starter,
                                            selection: TextSelection.collapsed(
                                              offset: starter.length,
                                            ),
                                          );
                                        },
                                      ),
                                      _buildComposerStarterChip(
                                        label: _ct('Check-in', 'Check-in'),
                                        color: const Color(0xFF10B981),
                                        onTap: () {
                                          final starter = _ct(
                                            'Check-in một khoảnh khắc dễ thương hôm nay...',
                                            'Checking in with a cute moment from today...',
                                          );
                                          controller.value = TextEditingValue(
                                            text: starter,
                                            selection: TextSelection.collapsed(
                                              offset: starter.length,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              if (locationText.isNotEmpty ||
                                  moodLabel.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (locationText.isNotEmpty)
                                          _buildComposerStarterChip(
                                            label: '📍 $locationText',
                                            color: const Color(0xFF2563EB),
                                            onTap: () => editLocation(setInner),
                                          ),
                                        if (moodLabel.isNotEmpty)
                                          _buildComposerStarterChip(
                                            label: '$moodEmoji $moodLabel',
                                            color: const Color(0xFFD81B60),
                                            onTap: () => pickMood(setInner),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (selectedImage != null || isPickingImage) ...[
                                SLSpacing.h16,
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: double.infinity,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: isPickingImage
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(
                                                color: Color(0xFFD81B60),
                                              ),
                                              SLSpacing.h12,
                                              Text(
                                                _ct(
                                                  'Đang chuẩn bị ảnh...',
                                                  'Preparing photo...',
                                                ),
                                                style: SLTheme.quicksand(
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.grey[400],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: kIsWeb
                                                  ? Image.network(
                                                      selectedImage!.path,
                                                      fit: BoxFit.cover,
                                                      filterQuality: FilterQuality.high,
                                                    )
                                                  : Image.file(
                                                      File(selectedImage!.path),
                                                      fit: BoxFit.cover,
                                                      filterQuality: FilterQuality.high,
                                                    ),
                                            ),
                                            Positioned(
                                              bottom: 12,
                                              right: 12,
                                              child: InkWell(
                                                onTap: () => editComposerImage(
                                                    setInner, ctx),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.edit_rounded,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                      SLSpacing.w8,
                                                      Text(
                                                        _ct('Chỉnh sửa',
                                                            'Edit'),
                                                        style:
                                                            SLTheme.quicksand(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 12,
                                              right: 12,
                                              child: InkWell(
                                                onTap: () => setInner(
                                                    () => selectedImage = null),
                                                borderRadius: SLRadius.lgAll,
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.58),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 12,
                                              right: 12,
                                              bottom: 12,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.55),
                                                  borderRadius: SLRadius.lgAll,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.image_rounded,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                    SLSpacing.w8,
                                                    Expanded(
                                                      child: Text(
                                                        selectedImage?.name ??
                                                            _ct(
                                                              'Ảnh đã chọn',
                                                              'Selected photo',
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            SLTheme.quicksand(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                SLSpacing.h12,
                                Text(
                                  _ct(
                                    'Ảnh xem trước sẽ được tải lên cùng bài viết.',
                                    'The preview photo will be uploaded with the post.',
                                  ),
                                  style: SLTheme.quicksand(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (selectedAudience == 'legacy-never')
                              Expanded(
                                child: Text(
                                  _ct('Thêm vào bài viết', 'Add to post'),
                                  style: SLTheme.quicksand(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                            _buildComposerAction(
                              icon: Icons.image_outlined,
                              label: _ct('Ảnh', 'Photo'),
                              bg: const Color(0xFFF0FDF4),
                              color: const Color(0xFF10B981),
                              onTap: () => pickComposerImage(setInner, ctx),
                            ),
                            SLSpacing.w8,
                            _buildComposerAction(
                              icon: Icons.mood_rounded,
                              label: _ct('Cảm xúc', 'Mood'),
                              bg: const Color(0xFFFFF7ED),
                              color: const Color(0xFFF97316),
                              onTap: () => pickMood(setInner),
                            ),
                            SLSpacing.w8,
                            _buildComposerAction(
                              icon: Icons.location_on_outlined,
                              label: _ct('Vị trí', 'Location'),
                              bg: const Color(0xFFEFF6FF),
                              color: const Color(0xFF3B82F6),
                              onTap: () => editLocation(setInner),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true) {
      return;
    }

    final content = controller.text.trim();
    if (!mounted || !context.mounted) {
      return;
    }
    if (!await SecurityService()
        .guardAction(context, 'community_post', content: content)) {
      return;
    }
    if (content.isEmpty && selectedImage == null) {
      if (!mounted || !context.mounted) {
        return;
      }
      LegacyWebUi.showNotice(
        context,
        message: _ct(
          'Bạn chưa nhập nội dung hoặc thêm ảnh nên chưa thể đăng.',
          'You have not entered any text or added a photo yet.',
        ),
        success: false,
        title: _ct('Thiếu nội dung bài viết', 'Missing post content'),
        icon: Icons.edit_note_rounded,
      );
      return;
    }

    if (content.isNotEmpty) {
      final validationError = _validateCommunityText(content, isComment: false);
      if (validationError != null) {
        if (!mounted || !context.mounted) return;
        LegacyWebUi.showNotice(
          context,
          message: validationError,
          success: false,
          title: _ct('Bài viết chưa hợp lệ', 'Post is not valid'),
          icon: Icons.rule_folder_outlined,
        );
        return;
      }
    }

    final resolvedPostType = resolveComposerPostType();
    if (resolvedPostType == 'polaroid' && selectedImage == null) {
      if (!mounted || !context.mounted) return;
      LegacyWebUi.showNotice(
        context,
        message: _ct(
          'Kiểu Polaroid cần có ảnh đi kèm. Hãy thêm ảnh hoặc đổi sang kiểu bài viết khác.',
          'The Polaroid style needs a photo. Add an image or switch to another post style.',
        ),
        success: false,
        title: _ct('Thiếu ảnh', 'Missing photo'),
        icon: Icons.photo_library_outlined,
      );
      return;
    }

    final hid = _houseId;
    if (hid == null || hid.isEmpty) return;
    if ((_auth.currentUser?.uid ?? '').isEmpty) {
      if (!mounted || !context.mounted) return;
      LegacyWebUi.showNotice(
        context,
        message: _ct(
          'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thử tiếp.',
          'Your session has expired. Please sign in again and try once more.',
        ),
        success: false,
        title: _ct(
          'Phiên đăng nhập không còn hiệu lực',
          'Session is no longer valid',
        ),
        icon: Icons.lock_clock_outlined,
      );
      return;
    }

    bool isLocketPost = _currentFeedType == 'locket';
    if (isLocketPost) {
      visibility = 'friends'; // Khoảnh khắc chỉ có bài viết cho bạn bè
    }

    await _submitCommunityPost(
      content: content,
      visibility: visibility,
      isAnon: isAnon,
      selectedImage: selectedImage,
      locationText: locationText,
      moodEmoji: moodEmoji,
      moodLabel: moodLabel,
      isLocketPost: isLocketPost,
      resolvedPostType: resolvedPostType,
    );
  }

  Widget _buildComposerAction({
    required IconData icon,
    String? label,
    required Color bg,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: SLRadius.lgAll,
      child: Container(
        constraints: BoxConstraints(
          minWidth: label == null ? 50 : 96,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: label == null ? 12 : 16,
          vertical: 11.5,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.96),
              bg,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: SLRadius.lgAll,
          border: Border.all(color: color.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (label != null) ...[
              SLSpacing.w8,
              Text(
                label,
                style: SLTheme.quicksand(
                  color: color,
                  fontSize: 12.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposerStarterChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: SLRadius.pillAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: SLRadius.pillAll,
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Text(
          label,
          style: SLTheme.quicksand(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
