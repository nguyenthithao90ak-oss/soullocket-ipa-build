part of '../../settings_tab.dart';

extension _SettingsTabThemePanelActionsPart on _SettingsTabState {
  bool _isPremiumCountdownStyle(String styleKey) {
    return _countdownPremiumStyleKeys.contains(styleKey);
  }

  String _formatCountdownUnlockExpiry(int expiryMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} • '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _countdownUnlockRemainingText() {
    final remainingMs =
        _countdownAdUnlockExpiryMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) return 'Đã hết hạn';
    final remaining = Duration(milliseconds: remainingMs);
    if (remaining.inDays >= 1) {
      return 'Còn ${remaining.inDays} ngày';
    }
    if (remaining.inHours >= 1) {
      return 'Còn ${remaining.inHours} giờ';
    }
    if (remaining.inMinutes >= 1) {
      return 'Còn ${remaining.inMinutes} phút';
    }
    return 'Sắp hết hạn';
  }

  // ignore: unused_element
  Widget _buildCountdownAdStylesPanel({
    required List<(String, String, bool)> countdownStyles,
    required String selectedStyleKey,
    required bool hasCountdownAdPass,
  }) {
    return _buildCountdownAdStylesPanelBody(
      countdownStyles: countdownStyles,
      selectedStyleKey: selectedStyleKey,
      hasCountdownAdPass: hasCountdownAdPass,
    );
  }

  Widget _buildCountdownAdStylesPanelBody({
    required List<(String, String, bool)> countdownStyles,
    required String selectedStyleKey,
    required bool hasCountdownAdPass,
  }) {
    final premiumStyles = countdownStyles.where((style) => style.$3).toList();
    if (premiumStyles.isEmpty) return const SizedBox.shrink();

    final summaryText = hasCountdownAdPass
        ? 'Bạn đã mở toàn bộ giao diện Quảng cáo tới '
            '${_formatCountdownUnlockExpiry(_countdownAdUnlockExpiryMs)}. '
            'Sau thời điểm này app sẽ yêu cầu xem quảng cáo lại.'
        : 'Xem 1 quảng cáo để mở toàn bộ ${premiumStyles.length} giao diện '
            'Quảng cáo trong 5 tiếng. Hết hạn sẽ reset và cần xem lại.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFFFFCFE),
            Color(0xFFFFF3F7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C4D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasCountdownAdPass
                      ? Icons.verified_rounded
                      : Icons.ondemand_video_rounded,
                  size: 18,
                  color: const Color(0xFFD81B60),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giao diện Quảng cáo',
                      style: SLTheme.quicksand(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF7C254C),
                      ),
                    ),
                    Text(
                      hasCountdownAdPass
                          ? _countdownUnlockRemainingText()
                          : 'Đang khóa',
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: hasCountdownAdPass
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD81B60),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summaryText,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.38,
              color: const Color(0xFF8A5B76),
            ),
          ),
          const SizedBox(height: 10),
          ...premiumStyles.map((style) {
            final isActive = selectedStyleKey == style.$2;
            final isLocked = !hasCountdownAdPass;
            final buttonLabel = isLocked
                ? (_isUnlockingStyle
                    ? 'Đang tải quảng cáo...'
                    : 'Xem quảng cáo')
                : (isActive ? 'Đang dùng' : 'Dùng ngay');
            final buttonIcon = isLocked
                ? Icons.ondemand_video_rounded
                : (isActive ? Icons.check_rounded : Icons.play_arrow_rounded);
            final subtitle = isLocked
                ? 'Mở khóa 5 tiếng cho toàn bộ giao diện quảng cáo.'
                : isActive
                    ? 'Đang dùng • Hết hạn '
                        '${_formatCountdownUnlockExpiry(_countdownAdUnlockExpiryMs)}.'
                    : 'Đã mở khóa • Dùng đến '
                        '${_formatCountdownUnlockExpiry(_countdownAdUnlockExpiryMs)}.';

            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFD81B60)
                      : const Color(0xFFF3D6E2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isLocked
                          ? const Color(0xFFFFEEF5)
                          : const Color(0xFFEAF8EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLocked
                          ? Icons.lock_rounded
                          : Icons.auto_awesome_rounded,
                      size: 18,
                      color: isLocked
                          ? const Color(0xFFD81B60)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                style.$1,
                                style: SLTheme.quicksand(
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF4A3340),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isLocked
                                    ? const Color(0xFFFFE3EE)
                                    : const Color(0xFFEAF8EE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isLocked ? 'Quảng cáo' : 'Đã mở',
                                style: SLTheme.quicksand(
                                  fontSize: 10.4,
                                  fontWeight: FontWeight.w900,
                                  color: isLocked
                                      ? const Color(0xFFD81B60)
                                      : const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8A5B76),
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: isLocked
                        ? (_isUnlockingStyle
                            ? null
                            : () => _handleCountdownStyleChange(style.$2))
                        : (isActive
                            ? null
                            : () => _updateThemeDraft(
                                  () => _draftCountdownStyleKey = style.$2,
                                )),
                    icon: Icon(buttonIcon, size: 16),
                    label: Text(buttonLabel),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: isLocked
                          ? const Color(0xFFD81B60)
                          : const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isActive
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFFE0E0E0),
                      disabledForegroundColor:
                          isActive ? Colors.white : const Color(0xFF7A7A7A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: SLTheme.quicksand(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String? get _pendingThemeBackgroundUploadKey {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty) {
      return null;
    }
    return 'settings_theme_bg_$houseId';
  }

  Future<void> _promptPendingThemeBackgroundRetryIfNeeded() async {
    final pendingKey = _pendingThemeBackgroundUploadKey;
    if (_didPromptPendingThemeBackgroundRetry ||
        pendingKey == null ||
        !mounted) {
      return;
    }
    final pending = await PendingUploadService.instance.load(pendingKey);
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingThemeBackgroundRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('upload_background_interrupted')),
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(_retryPendingThemeBackgroundUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingThemeBackgroundUpload() async {
    final pendingKey = _pendingThemeBackgroundUploadKey;
    if (pendingKey == null) {
      return;
    }
    final pending = await PendingUploadService.instance.load(pendingKey);
    if (pending == null || !mounted) {
      return;
    }
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
      return;
    }
    await _pickThemeBackgroundImage(presetFile: file);
  }

  Future<void> _pickThemeBackgroundImage({XFile? presetFile}) async {
    if (_houseId == null || _houseId!.trim().isEmpty) {
      _showToast(context.tr('theme_err_need_house_for_bg'), success: false);
      return;
    }

    if (mounted) {
      setState(() {
        _isUploadingThemeBackground = true;
        _themeUploadProgress = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAdStr = prefs.getString('last_bg_ad_time');
      final bool requiresAd = !_isVipActive;
      bool shouldShowAd = requiresAd;
      if (requiresAd && lastAdStr != null) {
        final lastAd = DateTime.tryParse(lastAdStr);
        if (lastAd != null) {
          final diff = DateTime.now().difference(lastAd);
          if (diff.inMinutes < 60) {
            // Trong khoảng 60 phút sau khi xem quảng cáo, cho phép tải lên miễn phí
            shouldShowAd = false;
          }
        }
      }

      if (shouldShowAd) {
        final adMob = AdMobService();
        // ignoreCooldown=true: tránh bị block bởi cooldown 45s giữa các ad toàn màn hình
        // loadTimeout=12s: cho đủ thời gian load ad nếu chưa preload
        final adSuccess = await adMob.showRewardedAd(
          ignoreCooldown: true,
          loadTimeout: const Duration(seconds: 12),
        );
        if (!mounted) return;
        if (!adSuccess) {
          if (mounted) {
            setState(() {
              _isUploadingThemeBackground = false;
            });
          }
          _showToast(context.tr('theme_err_ad_for_bg'), success: false);
          return;
        }
        await prefs.setString(
            'last_bg_ad_time', DateTime.now().toIso8601String());
      }

      final pickedFile = presetFile ?? await _storageService.pickImage();
      if (pickedFile == null || !mounted) return;
      XFile file = pickedFile;

      bool cropCancelled = false;
      if (presetFile == null && !kIsWeb) {
        try {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: file.path,
            aspectRatio: _themeBackgroundAspectRatio,
            compressFormat: ImageCompressFormat.jpg,
            compressQuality: 82,
            maxWidth: 1440,
            maxHeight: 3200,
            uiSettings: [
              IOSUiSettings(
                title: 'Chỉnh sửa ảnh nền',
                aspectRatioPresets: const [_themeBackgroundAspectRatioPreset],
                aspectRatioLockEnabled: true,
                aspectRatioPickerButtonHidden: true,
                resetAspectRatioEnabled: false,
              ),
            ],
          );
          if (croppedFile != null) {
            file = XFile(croppedFile.path);
          } else {
            cropCancelled = true;
          }
        } catch (e) {
          debugPrint('Lỗi cắt ảnh (dùng ảnh gốc): $e');
        }
      }

      if (cropCancelled || !mounted) return;

      if (mounted) {
        setState(() {
          _themeUploadProgress = 0.0;
        });
      }

      final previousDraftUrl = _draftCustomBackgroundUrl;
      final pendingKey = _pendingThemeBackgroundUploadKey;
      if (pendingKey != null) {
        await PendingUploadService.instance.save(
          pendingKey,
          <String, dynamic>{'filePath': file.path},
        );
      }

      final url = await _storageService.uploadImage(
        _houseId!,
        'themes',
        file,
        quality: 95,
        minWidth: 1440,
        minHeight: 1440,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _themeUploadProgress = progress;
            });
          }
        },
      );
      if (!mounted || url == null || url.trim().isEmpty) {
        if (!mounted) return;
        _showToast(context.tr('theme_err_upload_bg'), success: false);
        return;
      }

      if (previousDraftUrl != null &&
          previousDraftUrl.isNotEmpty &&
          previousDraftUrl != UiPrefs.notifier.value.customBackgroundUrl) {
        try {
          _storageService.deleteImageByUrl(previousDraftUrl);
        } catch (_) {}
      }

      _updateThemeDraft(() => _draftCustomBackgroundUrl = url.trim());
      if (pendingKey != null) {
        await PendingUploadService.instance.clear(pendingKey);
      }
      if (!mounted) return;
      _showToast(context.tr('theme_success_bg_saved'), success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast(context.tr('err_upload_background'), success: false);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingThemeBackground = false;
          _themeUploadProgress = null;
        });
      }
    }
  }

  void _clearThemeBackgroundImage() {
    final oldDraft = _draftCustomBackgroundUrl;
    if (oldDraft != null &&
        oldDraft.isNotEmpty &&
        oldDraft != UiPrefs.notifier.value.customBackgroundUrl) {
      try {
        _storageService.deleteImageByUrl(oldDraft);
      } catch (_) {}
    }
    _updateThemeDraft(() => _draftCustomBackgroundUrl = '');
    _showToast(context.tr('theme_success_bg_removed'), success: true);
  }

  /// Xử lý khi người dùng chọn giao diện vòng đếm từ dropdown.
  /// - Style không cần QC, đã unlock hoặc tài khoản Pro → chọn ngay.
  /// - Style cần QC: mỗi style khóa cần xem đủ 1 quảng cáo để mở.
  Future<void> _handleCountdownStyleChange(String styleKey) async {
    final requiresAd = _isPremiumCountdownStyle(styleKey);

    if (!requiresAd || _isVipActive || _hasActiveCountdownAdUnlock()) {
      _updateThemeDraft(() => _draftCountdownStyleKey = styleKey);
      return;
    }

    if (_isUnlockingStyle) return;
    setState(() => _isUnlockingStyle = true);
    try {
      final adMob = AdMobService();
      final adSuccess = await adMob.showRewardedAd();
      if (!mounted) return;
      if (adSuccess) {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('il_last_any_rewarded_ad_ts', now);
        await _saveCountdownAdUnlockWindow();
        if (mounted) {
          setState(() {});
          _updateThemeDraft(() => _draftCountdownStyleKey = styleKey);
          _showToast(context.tr('countdown_unlock_success'), success: true);
        }
      } else {
        if (mounted) {
          _showToast(context.tr('countdown_unlock_fail'), success: false);
        }
      }
    } finally {
      if (mounted) setState(() => _isUnlockingStyle = false);
    }
  }

  Future<void> _pickAnniversaryDate() async {
    final initialDate = _draftAnniversaryDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _draftAnniversaryDate = picked;
      _anniversaryDateErrorText = null;
      _anniversaryDateCtrl.text = _formatThemeDate(picked);
    });
  }
}
