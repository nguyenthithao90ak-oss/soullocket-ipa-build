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
              context.tr('home_lnuploadbi_0904e6'),
              'The last community upload was interrupted.',
            ),
          ),
          action: SnackBarAction(
            label: _ct(context.tr('home_thli_4dffdf'), 'Retry'),
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
    final errUploadFailed = context.tr('home_khngthtinh_bfad65');
    final defaultMood = context.tr('home_tho_ebaeb2');
    final successMsg = context.tr('home_gikhonhkhc_804cd1');
    final defaultErr = context.tr('home_khngthnglo_8f3faa');
    final errorTitle = context.tr('home_li_aaf377');
    final retryLabel = context.tr('home_thli_4dffdf');

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
        throw Exception(errUploadFailed);
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
        mood: _ct(defaultMood, 'Proud'),
        moodEmoji: 'âœ¨',
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
          successMsg,
          'Moment sent to friends!',
        ),
        title: 'Locket',
        icon: Icons.rocket_launch_rounded,
      );
    } catch (e) {
      final resolvedError = AppErrorMapper.resolve(
        e,
        fallbackMessage: _ct(
          defaultErr,
          'Cannot post this Locket right now.',
        ),
      );
      if (pendingKey != null) {
        await PendingUploadService.instance.markFailed(pendingKey, e);
      }
      if (!mounted) return;
      LegacyWebUi.showNoticeWithAction(
        context,
        message: resolvedError.message,
        title: _ct(errorTitle, 'Error'),
        icon: Icons.error_outline_rounded,
        actionLabel: _ct(retryLabel, 'Retry'),
        success: false,
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
    final errUploadFailed = context.tr('home_khngthtinh_bfad65');
    final flaggedReasonMsg = context.tr('home_moderation_flagged_reason');
    final violationWarningMsg = context.tr('home_bivitcabnc_37c237');
    final violationTitle = context.tr('home_cnhboviphm_bba9b1');
    final successMsg = context.tr('home_bivitcabnl_588521');
    final successTitle = context.tr('home_ngbithnhcn_bf3b57');
    final fallbackErrMsg = context.tr('home_chathngbil_2a8a6b');
    final failedTitle = context.tr('home_ngbichathn_682670');
    final retryLabel = context.tr('home_thli_4dffdf');

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
          throw Exception(errUploadFailed);
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
                  flaggedReasonMsg,
                  'Your post was flagged for moderation. Reason: {reason}. The visibility was reduced to a safer level to avoid repeated violations.',
                  {'reason': moderationReason},
                )
              : _ct(
                  violationWarningMsg,
                  'Your post contains violating keywords. It has been removed from the community and moved to private mode. This is a warning for violating community standards. Repeated violations may lead to an account lock.',
                ),
          title: _ct(violationTitle, 'Violation warning'),
          icon: Icons.warning_amber_rounded,
          success: false,
        );
      } else {
        LegacyWebUi.showNotice(
          context,
          message: _ct(
            successMsg,
            'Your post is now live in the community and follows the visibility rules.',
          ),
          title: _ct(successTitle, 'Post published'),
          icon: Icons.celebration_rounded,
        );
      }
    } catch (e) {
      final resolvedError = AppErrorMapper.resolve(
        e,
        fallbackMessage: _ct(
          fallbackErrMsg,
          'Cannot publish the post right now. Please try again later.',
        ),
      );
      debugPrint('Error submit post: ${resolvedError.message}');
      if (!mounted) return;
      LegacyWebUi.showNoticeWithAction(
        context,
        message: resolvedError.message,
        success: false,
        title: _ct(failedTitle, 'Post not published'),
        icon: Icons.cloud_off_rounded,
        actionLabel: _ct(retryLabel, 'Retry'),
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
    final editPhotoTitle = context.tr('home_chnhsanh_aa8a34');
    final errEditorFailed = context.tr('home_khngthmtrn_18f5b5');
    final errEditPhotoFailed = context.tr('home_khngthchnh_fafc68');
    final errPickPhotoFailed = context.tr('home_khngthchnn_951911');
    final cropIssueTitle = context.tr('home_nhnhkmangg_924f31');
    final photoNotAddedTitle = context.tr('home_chathmcnh_e259af');
    final advicePrefix = context.tr('home_xinlikhuyn_cd284a');

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
          text.endsWith('ØŸ') ||
          text.toLowerCase().startsWith(_ct(advicePrefix, 'need advice'));
    }

    String fallbackPostType() {
      if (selectedImage != null) return 'polaroid';
      if (looksLikeQuestion(controller.text)) return 'question';
      return 'mood';
    }

    String resolveComposerPostType() => fallbackPostType();

    // ignore: unused_element
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
                title: _ct(editPhotoTitle, 'Edit photo'),
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
          final resolvedError = AppErrorMapper.resolve(
            e,
            fallbackMessage: _ct(
              errEditorFailed,
              'Cannot open the photo editor right now.',
            ),
          );
          debugPrint('Edit cropping failed: ${resolvedError.message}');
          if (!mounted) return;
          LegacyWebUi.showNotice(
            context,
            message: resolvedError.message,
            success: false,
            title: _ct(context.tr('home_li_aaf377'), 'Error'),
            icon: Icons.broken_image_outlined,
          );
        }
      } catch (e) {
        final resolvedError = AppErrorMapper.resolve(
          e,
          fallbackMessage: _ct(
            errEditPhotoFailed,
            'Cannot edit the photo right now.',
          ),
        );
        if (!mounted) return;
        LegacyWebUi.showNotice(
          context,
          message: resolvedError.message,
          success: false,
          title:
              _ct(cropIssueTitle, 'Attached photo has an issue'),
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
                title: _ct(editPhotoTitle, 'Edit photo'),
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
          final resolvedError = AppErrorMapper.resolve(
            e,
            fallbackMessage: _ct(
              errEditPhotoFailed,
              'Cannot edit the photo right now.',
            ),
          );
          debugPrint('Cropping failed: ${resolvedError.message}');
          if (!bottomSheetContext.mounted) return;
          setInner(() {
            selectedImage = file;
          });
        }
      } catch (e) {
        final resolvedError = AppErrorMapper.resolve(
          e,
          fallbackMessage: _ct(
            errPickPhotoFailed,
            'Cannot pick a photo right now.',
          ),
        );
        if (!mounted) return;
        LegacyWebUi.showNotice(
          context,
          message: resolvedError.message,
          success: false,
          title: _ct(photoNotAddedTitle, 'Photo not added'),
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
              _ct(context.tr('home_gnvtrchobi_cf0363'), 'Add a location to the post'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w900),
            ),
            content: TextField(
              controller: locationController,
              autofocus: true,
              style: SLTheme.quicksand(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: _ct(
                  context.tr('home_vdhniqunqu_02afe3'),
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
                child: Text(_ct(context.tr('home_hy_1e4050'), 'Cancel')),
              ),
              if (locationText.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: Text(_ct(context.tr('home_xa_4ed187'), 'Delete')),
                ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, locationController.text.trim()),
                child: Text(_ct(context.tr('home_lu_49fac1'), 'Save')),
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
                  _ct(context.tr('home_chntmtrngc_7fe6ac'),
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
                      _ct(context.tr('home_xatmtrngch_141960'), 'Clear selected mood'),
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
              openImagePicker = false; // Chá»‰ má»Ÿ 1 láº§n
            }

            final selectedAudience =
                visibility == 'friends' ? 'friends' : 'public';


            // ignore: unused_element
            Widget buildAudienceOption({
              required String value,
              required String label,
              required IconData icon,
              required Color color,
            }) {
              final isSelected = selectedAudience == value;
              return InkWell(
                onTap: () => setInner(() { visibility = value == 'private' ? 'private' : 'friends'; }),
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


            var selectedPostType = resolveComposerPostType();

            Widget buildPostTypeOption({
              required String value,
              required String label,
              required String subtitle,
              required IconData icon,
              required Color color,
            }) {
              final isSelected = selectedPostType == value;
              return InkWell(
                onTap: () => setInner(() => selectedPostType = value),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 148,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(height: 8),
                      Text(label, style: SLTheme.quicksand(fontWeight: FontWeight.w900, color: color)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: SLTheme.quicksand(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              );
            }

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
                                  _ct(context.tr('home_hy_1e4050'), 'Cancel'),
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _ct(context.tr('home_tobivit_42e413'), 'Create post'),
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
                                    _ct(context.tr('home_ng_a91c66'), 'POST'),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: const Color(0xFFF0F2F5),
                                          backgroundImage: _houseAvatar.isNotEmpty
                                              ? CachedNetworkImageProvider(_houseAvatar)
                                              : null,
                                          child: _houseAvatar.isEmpty
                                              ? const Icon(
                                                  Icons.favorite_rounded,
                                                  color: Color(0xFFD81B60),
                                                )
                                              : null,
                                        ),
                                        SLSpacing.w12,
                                        Expanded(
                                          child: Text(
                                            _houseName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: SLTheme.quicksand(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SLSpacing.h16,
                                    Text(
                                      _ct(
                                        context.tr('home_chnkiuhint_cc235b'),
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
                                          label: _ct('Mood card', 'Mood card'),
                                          subtitle: _ct(
                                            context.tr('home_nnitheocmx_0b199c'),
                                            'Mood background based on the feeling.',
                                          ),
                                          icon: Icons.auto_awesome_rounded,
                                          color: const Color(0xFFD81B60),
                                        ),
                                        buildPostTypeOption(
                                          value: 'polaroid',
                                          label: _ct('Polaroid', 'Polaroid'),
                                          subtitle: _ct(
                                            context.tr('home_utinnhvcap_e82e26'),
                                            'Photo-first layout with a framed caption.',
                                          ),
                                          icon: Icons.photo_camera_back_rounded,
                                          color: const Color(0xFF2563EB),
                                        ),
                                        buildPostTypeOption(
                                          value: 'question',
                                          label: _ct('Question', 'Question'),
                                          subtitle: _ct(
                                            context.tr('home_dnhchobixi_797865'),
                                            'Best for advice or help requests.',
                                          ),
                                          icon: Icons.help_outline_rounded,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                        buildPostTypeOption(
                                          value: 'confession',
                                          label: _ct('Confession', 'Confession'),
                                          subtitle: _ct(
                                            context.tr('home_tbtndanhch_bef1f7'),
                                            'Automatically posts as anonymous.',
                                          ),
                                          icon: Icons.lock_outline_rounded,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ],
                                    ),
                                    SLSpacing.h16,
                                    Row(
                                      children: [
                                        Text(
                                          _ct(
                                            context.tr('home_iconiconsf_3982b3'),
                                            'Post content',
                                          ),
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
                                          context.tr('home_bnmunchias_08f77e'),
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
                                        context.tr('home_post_max_chars_policy'),
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
                              const SizedBox(height: 14),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildComposerAction(
                                      icon: Icons.image_outlined,
                                      label: _ct(context.tr('home_nh_217304'), 'Photo'),
                                      bg: const Color(0xFFFDF2F8),
                                      color: const Color(0xFFD81B60),
                                      onTap: () => pickComposerImage(setInner, ctx),
                                    ),
                                    SLSpacing.w8,
                                    _buildComposerAction(
                                      icon: Icons.emoji_emotions_outlined,
                                      label: _ct(context.tr('home_cmxc_0d1460'), 'Mood'),
                                      bg: const Color(0xFFFFF7ED),
                                      color: const Color(0xFFF97316),
                                      onTap: () => pickMood(setInner),
                                    ),
                                    SLSpacing.w8,
                                    _buildComposerAction(
                                      icon: Icons.location_on_outlined,
                                      label: _ct(context.tr('home_vtr_69ea36'), 'Location'),
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
          context.tr('home_bnchanhpni_47bc83'),
          'You have not entered any text or added a photo yet.',
        ),
        success: false,
        title: _ct(context.tr('home_thiunidung_6c95cf'), 'Missing post content'),
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
          title: _ct(context.tr('home_bivitchahp_f1b1ec'), 'Post is not valid'),
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
          context.tr('home_kiupolaroi_c3835a'),
          'The Polaroid style needs a photo. Add an image or switch to another post style.',
        ),
        success: false,
        title: _ct(context.tr('home_thiunh_4e52fb'), 'Missing photo'),
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
          context.tr('home_phinngnhph_fd17bb'),
          'Your session has expired. Please sign in again and try once more.',
        ),
        success: false,
        title: _ct(
          context.tr('home_phinngnhpk_0224d2'),
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

  // ignore: unused_element
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
