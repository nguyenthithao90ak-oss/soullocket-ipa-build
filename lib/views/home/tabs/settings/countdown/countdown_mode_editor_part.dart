part of '../../settings_tab.dart';
// ignore_for_file: dead_code, unused_element

Future<XFile?> _cropCountdownModeAvatarFile(XFile file) async {
  if (kIsWeb) {
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
        IOSUiSettings(
          title: L10nService().translate('home_chnhavatar_d974c0'),
          aspectRatioPresets: const [CropAspectRatioPreset.square],
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
  } catch (_) {
    return file;
  }
}

Future<XFile?> _cropCountdownModeBackgroundFile(XFile file) async {
  if (kIsWeb) {
    return file;
  }
  try {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: _themeBackgroundAspectRatio,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      maxWidth: 1080,
      maxHeight: 2560,
      uiSettings: [
        IOSUiSettings(
          title: L10nService().translate('home_chnhnnkhng_a929e1'),
          aspectRatioPresets: const [_themeBackgroundAspectRatioPreset],
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
  } catch (_) {
    return file;
  }
}

class _CountdownModeEditorScreen extends StatefulWidget {
  const _CountdownModeEditorScreen({
    required this.currentHouseId,
    required this.isVipActive,
    required this.spaceTitle,
    required this.isAccepted,
    required this.showDeleteSection,
    required this.canRequestDelete,
    required this.canAcceptDelete,
    required this.deleteStatusTitle,
    required this.deleteStatusDescription,
    required this.singleMode,
    required this.anchorDate,
    required this.themeKey,
    required this.styleKey,
    required this.frameKey,
    required this.fontKey,
    required this.transparentMode,
    required this.sizePx,
    required this.topLabel,
    required this.bottomLabel,
    required this.nameU1,
    required this.nameU2,
    required this.avatarUrl1,
    required this.avatarUrl2,
    required this.customBackgroundUrl,
    required this.centerIconType,
  });

  final String? currentHouseId;
  final bool isVipActive;
  final String spaceTitle;
  final bool isAccepted;
  final bool showDeleteSection;
  final bool canRequestDelete;
  final bool canAcceptDelete;
  final String deleteStatusTitle;
  final String deleteStatusDescription;
  final bool singleMode;
  final DateTime? anchorDate;
  final String themeKey;
  final String styleKey;
  final String frameKey;
  final String fontKey;
  final bool transparentMode;
  final double sizePx;
  final String topLabel;
  final String bottomLabel;
  final String nameU1;
  final String nameU2;
  final String avatarUrl1;
  final String avatarUrl2;
  final String customBackgroundUrl;
  final String centerIconType;

  @override
  State<_CountdownModeEditorScreen> createState() =>
      _CountdownModeEditorScreenState();
}

class _CountdownModeEditorScreenState
    extends State<_CountdownModeEditorScreen> {
  static const String _pendingAvatarUploadKeyPrefix =
      'countdown_editor_avatar_';
  static const String _pendingBackgroundUploadKeyPrefix =
      'countdown_editor_background_';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) {
      fn();
      return;
    }
    setState(fn);
  }

  final StorageService _storageService = StorageService();
  final Set<String> _temporaryUploadedUrls = <String>{};
  late final TextEditingController _topCtrl;
  late final TextEditingController _bottomCtrl;
  late final TextEditingController _leftCtrl;
  late final TextEditingController _rightCtrl;
  late final TextEditingController _leftAvatarCtrl;
  late final TextEditingController _rightAvatarCtrl;

  late bool _singleMode;
  late DateTime? _anchorDate;
  late String _themeKey;
  late String _styleKey;
  late String _frameKey;
  late String _fontKey;
  late String _customBackgroundUrl;
  late String _centerIconType;
  late bool _transparentMode;
  late double _sizePx;
  String? _uploadingAvatarRole;
  double? _avatarUploadProgress;
  bool _isUploadingBackground = false;
  bool _isUnlockingCountdownStyle = false;
  bool _didPromptPendingUploadRetry = false;
  Set<String> _unlockedStyles = {};

  Future<void> _loadUnlockedStyles() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final loaded = <String>{};
    for (final styleKey in _CountdownModeIndependentScreenState._premiumCountdownStyleKeys) {
      final expiryKey = 'il_countdown_style_unlock_expiry_$styleKey';
      final expiry = prefs.getInt(expiryKey) ?? 0;
      if (expiry > now) {
        loaded.add(styleKey);
      }
    }
    // Migration: legacy global unlocks
    final legacyExpiry = prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    if (legacyExpiry > now) {
      loaded.addAll(_CountdownModeIndependentScreenState._premiumCountdownStyleKeys);
    } else {
      final legacyTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
      if (legacyTs > 0) {
        final fallbackExpiry = legacyTs + const Duration(days: 7).inMilliseconds;
        if (fallbackExpiry > now) {
          loaded.addAll(_CountdownModeIndependentScreenState._premiumCountdownStyleKeys);
        }
      }
    }
    if (mounted) {
      setState(() {
        _unlockedStyles = loaded;
      });
    }
  }

  static List<MapEntry<String, String>> get _themeOptions =>
      _CountdownModeIndependentScreenState._themeOptions;
  static List<MapEntry<String, String>> get _countdownStyleOptions =>
      _CountdownModeIndependentScreenState._countdownStyleOptions;
  static List<MapEntry<String, String>> get _avatarFrameOptions =>
      _CountdownModeIndependentScreenState._avatarFrameOptions;

  @override
  void initState() {
    super.initState();
    _topCtrl = TextEditingController(text: widget.topLabel);
    _bottomCtrl = TextEditingController(text: widget.bottomLabel);
    _leftCtrl = TextEditingController(text: widget.nameU1);
    _rightCtrl = TextEditingController(text: widget.nameU2);
    _leftAvatarCtrl = TextEditingController(text: widget.avatarUrl1);
    _rightAvatarCtrl = TextEditingController(text: widget.avatarUrl2);
    _singleMode = widget.singleMode;
    _anchorDate = widget.anchorDate;
    _themeKey = _themeOptions.any((item) => item.value == widget.themeKey)
        ? widget.themeKey
        : _themeOptions.first.value;
    final initialStyleKey = widget.styleKey.trim().toLowerCase();
    _styleKey = _countdownStyleOptions.any(
      (item) => item.value == initialStyleKey,
    )
        ? initialStyleKey
        : 'default';
    _frameKey = _avatarFrameOptions.any((item) => item.value == widget.frameKey)
        ? widget.frameKey
        : _avatarFrameOptions.first.value;
    _fontKey =
        SLTheme.cleanFontOptions.any((item) => item.key == widget.fontKey)
            ? widget.fontKey
            : SLTheme.cleanFontOptions.first.key;
    _customBackgroundUrl = widget.customBackgroundUrl.trim();
    _centerIconType =
        _normalizeCountdownModeCenterIconType(widget.centerIconType);
    _transparentMode = widget.transparentMode;
    _sizePx = widget.sizePx.clamp(200.0, UiPrefs.maxCountdownSizePx).toDouble();
    _unlockedStyles = {};
    _loadUnlockedStyles();
    unawaited(_promptPendingUploadRetryIfNeeded());
  }

  @override
  void dispose() {
    for (final url in _temporaryUploadedUrls) {
      unawaited(_storageService.deleteImageByUrl(url));
    }
    _topCtrl.dispose();
    _bottomCtrl.dispose();
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    _leftAvatarCtrl.dispose();
    _rightAvatarCtrl.dispose();
    super.dispose();
  }

  String _resolveThemeKey(String rawKey) {
    final key = rawKey.trim();
    if (key.isNotEmpty && key != 'theme-auto') return key;
    final now = DateTime.now();
    if (now.hour >= 19 || now.hour < 5) return 'theme-night';
    switch (now.month) {
      case 6:
      case 7:
      case 8:
        return 'theme-ocean';
      case 9:
      case 10:
      case 11:
        return 'theme-sunset';
      default:
        return 'theme-pink-glow';
    }
  }

  int _daysSince(DateTime startDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalized = DateTime(startDate.year, startDate.month, startDate.day);
    final days = today.difference(normalized).inDays;
    return days < 0 ? 0 : days;
  }

  String _previewTopLabel() {
    final value = _topCtrl.text.trim();
    if (value.isNotEmpty) return value;
    return _singleMode ? context.tr('home_tuicati_5c654c') : context.tr('home_yunhau_501102');
  }

  String _previewBottomLabel() {
    final value = _bottomCtrl.text.trim();
    if (value.isNotEmpty) return value;
    return _singleMode ? context.tr('home_ngytui_22bed4') : context.tr('home_ngy_41ec10');
  }

  String? get _uploadHouseId {
    final houseId = (widget.currentHouseId ?? '').trim();
    return houseId.isEmpty ? null : houseId;
  }

  String? get _pendingAvatarUploadKey {
    final houseId = _uploadHouseId;
    if (houseId == null) {
      return null;
    }
    return '$_pendingAvatarUploadKeyPrefix$houseId';
  }

  String? get _pendingBackgroundUploadKey {
    final houseId = _uploadHouseId;
    if (houseId == null) {
      return null;
    }
    return '$_pendingBackgroundUploadKeyPrefix$houseId';
  }

  Future<void> _promptPendingUploadRetryIfNeeded() async {
    if (_didPromptPendingUploadRetry || !mounted) {
      return;
    }
    final avatarPendingKey = _pendingAvatarUploadKey;
    final backgroundPendingKey = _pendingBackgroundUploadKey;
    if (avatarPendingKey == null || backgroundPendingKey == null) {
      return;
    }
    final avatarPending =
        await PendingUploadService.instance.load(avatarPendingKey);
    final backgroundPending =
        await PendingUploadService.instance.load(backgroundPendingKey);
    if (avatarPending == null && backgroundPending == null) {
      return;
    }
    _didPromptPendingUploadRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.tr('home_lnuploadkh_b2b1ac')),
          action: SnackBarAction(
            label: context.tr('home_thli_4dffdf'),
            onPressed: () {
              unawaited(_retryPendingUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingUpload() async {
    final avatarPendingKey = _pendingAvatarUploadKey;
    if (avatarPendingKey != null) {
      final avatarPending =
          await PendingUploadService.instance.load(avatarPendingKey);
      if (avatarPending != null) {
        final filePath = avatarPending['filePath']?.toString().trim() ?? '';
        if (filePath.isNotEmpty) {
          final file = XFile(filePath);
          try {
            if (await file.length() > 0) {
              await _pickAvatarImage(
                isLeft: avatarPending['role']?.toString() != 'right',
                presetFile: file,
              );
              return;
            }
          } catch (_) {}
        }
        await PendingUploadService.instance.clear(avatarPendingKey);
      }
    }

    final backgroundPendingKey = _pendingBackgroundUploadKey;
    if (backgroundPendingKey == null) {
      return;
    }
    final backgroundPending =
        await PendingUploadService.instance.load(backgroundPendingKey);
    if (backgroundPending == null) {
      return;
    }
    final filePath = backgroundPending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(backgroundPendingKey);
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(backgroundPendingKey);
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(backgroundPendingKey);
      return;
    }
    await _pickBackgroundImage(presetFile: file);
  }

  void _showMessage(String message) => _showMessageImpl(message);

  void _disposeTemporaryUrl(String url) => _disposeTemporaryUrlImpl(url);

  void _rememberUploadedUrl({
    required String previousUrl,
    required String nextUrl,
  }) =>
      _rememberUploadedUrlImpl(
        previousUrl: previousUrl,
        nextUrl: nextUrl,
      );

  void _preserveCurrentUploads() => _preserveCurrentUploadsImpl();

  Future<void> _handleCountdownStyleSelection(String styleKey) async {
    final normalized = styleKey.trim().toLowerCase();
    final exists = _countdownStyleOptions.any((item) => item.value == normalized);
    if (!exists) {
      _showMessage('Giao diện vòng đếm không hợp lệ: $styleKey');
      return;
    }
    final requiresAd =
        _CountdownModeIndependentScreenState._isPremiumCountdownStyleKey(
            normalized);
    if (!requiresAd || widget.isVipActive) {
      setState(() => _styleKey = normalized);
      return;
    }

    if (_unlockedStyles.contains(normalized)) {
      setState(() => _styleKey = normalized);
      return;
    }

    if (_isUnlockingCountdownStyle) {
      return;
    }
    setState(() => _isUnlockingCountdownStyle = true);
    try {
      final adSuccess = await AdMobService().showRewardedAd();
      if (!mounted) {
        return;
      }
      if (!adSuccess) {
        _showMessage(context.tr('home_cnxemqungc_fe69b5'));
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiry = now + const Duration(days: 7).inMilliseconds;
      final expiryKey = 'il_countdown_style_unlock_expiry_$normalized';
      await prefs.setInt(expiryKey, expiry);
      await prefs.setInt('il_last_any_rewarded_ad_ts', now);

      if (!mounted) {
        return;
      }
      setState(() {
        _unlockedStyles = {..._unlockedStyles, normalized};
        _styleKey = normalized;
      });
      _showMessage('Đã mở khóa "${_countdownStyleOptions.firstWhere((e) => e.value == normalized).key}" trong 7 ngày!');
    } finally {
      if (mounted) {
        setState(() => _isUnlockingCountdownStyle = false);
      }
    }
  }

  Future<bool> _ensureBackgroundUploadAccess() async {
    if (widget.isVipActive) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final lastAdStr = prefs.getString('last_bg_ad_time');
    var shouldShowAd = true;
    if (lastAdStr != null) {
      final lastAd = DateTime.tryParse(lastAdStr);
      if (lastAd != null && DateTime.now().difference(lastAd).inMinutes < 20) {
        shouldShowAd = false;
      }
    }
    if (!shouldShowAd) {
      return true;
    }
    final adSuccess = await AdMobService().showRewardedAd();
    if (!mounted) {
      return false;
    }
    if (!adSuccess) {
      _showMessage(context.tr('home_cnxemqungc_370ee8'));
      return false;
    }
    await prefs.setString('last_bg_ad_time', DateTime.now().toIso8601String());
    return true;
  }

  Future<void> _pickAvatarImage({
    required bool isLeft,
    XFile? presetFile,
  }) async {
    final houseId = _uploadHouseId;
    if (houseId == null) {
      _showMessage(context.tr('home_khngtmthym_b7eeff'));
      return;
    }
    final role = isLeft ? 'left' : 'right';
    if (_uploadingAvatarRole != null) {
      return;
    }

    XFile? file = presetFile ?? await _storageService.pickImage();
    if (file == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _uploadingAvatarRole = role;
    });

    try {
      if (presetFile == null) {
        file = await _cropCountdownModeAvatarFile(file);
      }
      if (file == null) {
        return;
      }
      final pendingKey = _pendingAvatarUploadKey;
      if (pendingKey != null) {
        await PendingUploadService.instance.save(
          pendingKey,
          <String, dynamic>{
            'role': role,
            'filePath': file.path,
          },
        );
      }
      final url = await _storageService.uploadImage(
        houseId,
        'avatars',
        file,
        quality: 84,
        minWidth: 512,
        minHeight: 512,
        onProgress: (p) {
          if (mounted) setState(() => _avatarUploadProgress = p);
        },
      );
      if (!mounted || url == null || url.trim().isEmpty) {
        if (mounted) {
          _showMessage(context.tr('home_khngticava_73ea14'));
        }
        return;
      }

      final controller = isLeft ? _leftAvatarCtrl : _rightAvatarCtrl;
      final previousUrl = controller.text.trim();
      _rememberUploadedUrl(previousUrl: previousUrl, nextUrl: url.trim());
      setState(() {
        controller.text = url.trim();
      });
      if (pendingKey != null) {
        await PendingUploadService.instance.clear(pendingKey);
      }
    } catch (e) {
      _showMessage('Không thể tải avatar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatarRole = null;
          _avatarUploadProgress = null;
        });
      }
    }
  }

  Future<void> _pickBackgroundImage({XFile? presetFile}) async {
    final houseId = _uploadHouseId;
    if (houseId == null) {
      _showMessage(context.tr('home_khngtmthym_6caf0b'));
      return;
    }
    if (_isUploadingBackground) {
      return;
    }
    final allowUpload = await _ensureBackgroundUploadAccess();
    if (!allowUpload || !mounted) {
      return;
    }

    XFile? file = presetFile ?? await _storageService.pickImage();
    if (file == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _isUploadingBackground = true;
    });

    try {
      if (presetFile == null) {
        file = await _cropCountdownModeBackgroundFile(file);
      }
      if (file == null) {
        return;
      }
      final pendingKey = _pendingBackgroundUploadKey;
      if (pendingKey != null) {
        await PendingUploadService.instance.save(
          pendingKey,
          <String, dynamic>{'filePath': file.path},
        );
      }
      final url = await _storageService.uploadImage(
        houseId,
        'themes',
        file,
        quality: 78,
        minWidth: 900,
        minHeight: 900,
        onProgress: (p) {
          // Progress updates can be handled here when UI is ready
        },
      );
      if (!mounted || url == null || url.trim().isEmpty) {
        if (mounted) {
          _showMessage(context.tr('home_khngticnnm_27a6df'));
        }
        return;
      }

      final previousUrl = _customBackgroundUrl.trim();
      _rememberUploadedUrl(previousUrl: previousUrl, nextUrl: url.trim());
      setState(() {
        _customBackgroundUrl = url.trim();
      });
      if (pendingKey != null) {
        await PendingUploadService.instance.clear(pendingKey);
      }
    } catch (e) {
      _showMessage('Không thể tải nền: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBackground = false;
        });
      }
    }
  }

  void _clearBackgroundImage() => _clearBackgroundImageImpl();

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    bool dark = false,
  }) =>
      _fieldDecorationImpl(label: label, hint: hint, dark: dark);

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) =>
      _sectionCardImpl(
        icon: icon,
        title: title,
        subtitle: subtitle,
        child: child,
      );

  Future<void> _pickAnchorDate() => _pickAnchorDateImpl();

  _CountdownModeSettingsResult _buildResult(
    _CountdownModeSettingsAction action,
  ) =>
      _buildResultImpl(action);

  @override
  Widget build(BuildContext context) {
    final themeData =
        _CountdownModeThemeData.resolve(_resolveThemeKey(_themeKey));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeData.background,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: themeData.overlay,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: -36,
            right: -18,
            child: _CountdownModeGlowOrb(color: themeData.orbA, size: 236),
          ),
          Positioned(
            left: -20,
            bottom: 44,
            child: _CountdownModeGlowOrb(color: themeData.orbB, size: 196),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          constraints.maxWidth > 680 ? 620 : double.infinity,
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 
                                        themeData.isDark ? 0.14 : 0.82,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 
                                          themeData.isDark ? 0.22 : 0.94,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: themeData.foreground,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('home_citkhnggia_09f866'),
                                      style: SLTheme.quicksand(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: themeData.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr('home_bccytngtmc_c1f7aa'),
                                      style: SLTheme.quicksand(
                                        fontSize: 12.2,
                                        fontWeight: FontWeight.w700,
                                        color: themeData.foreground.withValues(alpha: 
                                          themeData.isDark ? 0.78 : 0.72,
                                        ),
                                        height: 1.42,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionCard(
                            icon: Icons.timelapse_rounded,
                            title: 'Xem nhanh không gian',
                            subtitle: 'Xem vòng đếm gọn trước khi lưu',
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF6FA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF4D2E1)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _previewTopLabel(),
                                    style: SLTheme.textStyleForKey(
                                      _fontKey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF7C6D76),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _anchorDate == null
                                        ? '--'
                                        : _daysSince(_anchorDate!).toString(),
                                    style: SLTheme.textStyleForKey(
                                      _fontKey,
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFD81B60),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _previewBottomLabel(),
                                    style: SLTheme.textStyleForKey(
                                      _fontKey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF7C6D76),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _sectionCard(
                            icon: Icons.edit_note_rounded,
                            title: 'Nội dung hiển thị',
                            subtitle: 'Tên, avatar và icon trung tâm',
                            child: Column(
                              children: [
                                TextField(
                                  controller: _leftCtrl,
                                  maxLength: 22,
                                  decoration: _fieldDecoration(
                                    label: context.tr('home_tnbntri_538c6b'),
                                    hint: context.tr('home_bn_1fd75b'),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _rightCtrl,
                                  maxLength: 22,
                                  decoration: _fieldDecoration(
                                    label: context.tr('home_tnbnphi_855cc7'),
                                    hint: context.tr('home_ngiy_5bab37'),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _uploadingAvatarRole == null
                                            ? () => _pickAvatarImage(
                                                  isLeft: true,
                                                )
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF2563EB),
                                          side: const BorderSide(
                                            color: Color(0xFFCFE0FF),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: _uploadingAvatarRole == 'left'
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.upload_rounded,
                                                size: 18,
                                              ),
                                        label: Text(_uploadingAvatarRole == 'left' && _avatarUploadProgress != null
                                            ? 'ĐANG TẢI... ${(_avatarUploadProgress! * 100).toInt()}%'
                                            : context.tr('home_tinhtri_3bb821')),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _uploadingAvatarRole == null
                                            ? () => _pickAvatarImage(
                                                  isLeft: false,
                                                )
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFD81B60),
                                          side: const BorderSide(
                                            color: Color(0xFFF2C3D7),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: _uploadingAvatarRole == 'right'
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.upload_rounded,
                                                size: 18,
                                              ),
                                        label: Text(_uploadingAvatarRole == 'right' && _avatarUploadProgress != null
                                            ? 'ĐANG TẢI... ${(_avatarUploadProgress! * 100).toInt()}%'
                                            : context.tr('home_tinhphi_3b6cd5')),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    context.tr('home_icongia_641af3'),
                                    style: SLTheme.quicksand(
                                      fontSize: 12.8,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF8A5B76),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _kCountdownModeCenterIconPresets
                                      .map((preset) {
                                    final isSelected =
                                        preset.type == _centerIconType;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => _centerIconType = preset.type,
                                      ),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        width: 62,
                                        height: 62,
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.94),
                                          border: Border.all(
                                            color: isSelected
                                                ? preset.accent
                                                : Colors.white.withValues(alpha: 0.78),
                                            width: isSelected ? 2.2 : 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: preset.accent.withValues(alpha: 
                                                isSelected ? 0.22 : 0.10,
                                              ),
                                              blurRadius: isSelected ? 18 : 11,
                                              offset: const Offset(0, 7),
                                            ),
                                          ],
                                        ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: preset.gradient,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.84),
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child:
                                                _buildCountdownModeCenterIconVisual(
                                              preset: preset,
                                              size: 36,
                                              emojiSize: 26,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _sectionCard(
                            icon: Icons.event_available_rounded,
                            title: 'Mốc thời gian & kiểu hiển thị',
                            subtitle: 'Chọn ngày mốc, theme, vòng đếm, kính mờ',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    ChoiceChip(
                                      selected: _singleMode,
                                      label: Text(context.tr('home_cnhn_9d6cf4')),
                                      labelStyle: SLTheme.quicksand(
                                        fontWeight: FontWeight.w800,
                                        color: _singleMode
                                            ? Colors.white
                                            : const Color(0xFF7C6D76),
                                      ),
                                      selectedColor: const Color(0xFFD81B60),
                                      onSelected: (_) =>
                                          setState(() => _singleMode = true),
                                    ),
                                    ChoiceChip(
                                      selected: !_singleMode,
                                      label: Text(context.tr('home_cpi_d525b0')),
                                      labelStyle: SLTheme.quicksand(
                                        fontWeight: FontWeight.w800,
                                        color: !_singleMode
                                            ? Colors.white
                                            : const Color(0xFF7C6D76),
                                      ),
                                      selectedColor: const Color(0xFFD81B60),
                                      onSelected: (_) =>
                                          setState(() => _singleMode = false),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ActionChip(
                                      label: Text(context.tr('countdown_today')),
                                      onPressed: () {
                                        final now = DateTime.now();
                                        setState(() {
                                          _anchorDate = DateTime(
                                            now.year,
                                            now.month,
                                            now.day,
                                          );
                                        });
                                      },
                                    ),
                                    ActionChip(
                                      label: Text(context.tr('countdown_default_love_date')),
                                      onPressed: () {
                                        final parsed = DateInputUtils.parse(
                                          widget.anchorDate == null
                                              ? ''
                                              : DateInputUtils.formatIsoDate(
                                                  widget.anchorDate!,
                                                ),
                                        );
                                        if (parsed == null) return;
                                        setState(() {
                                          _anchorDate = DateTime(
                                            parsed.year,
                                            parsed.month,
                                            parsed.day,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF6FA),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFF4D2E1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr('home_ngymchinti_2f583e'),
                                              style: SLTheme.quicksand(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF8A5B76),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _anchorDate == null
                                                  ? context.tr('home_chachn_cf29c8')
                                                  : DateInputUtils
                                                      .formatDisplayDate(
                                                      _anchorDate!,
                                                    ),
                                              style: SLTheme.quicksand(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w900,
                                                color: const Color(0xFF243041),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: _pickAnchorDate,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFD81B60),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.event_rounded,
                                          size: 18,
                                        ),
                                        label: Text(context.tr('home_chnngy_d2cce5')),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            icon: Icons.palette_rounded,
                            title: L10nService().translate('home_giaodinvng_2311dc'),
                            subtitle:
                                context.tr('home_kiuhinthny_15f695'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CountdownModeSheetDropdown(
                                  label: context.tr('home_ch_f5d6a5'),
                                  value: _themeKey,
                                  options: _themeOptions,
                                  onChanged: (value) =>
                                      setState(() => _themeKey = value),
                                ),
                                const SizedBox(height: 12),
                                _CountdownModeSheetDropdown(
                                  label: _isUnlockingCountdownStyle
                                      ? context.tr('home_angmkhakiu_38c380')
                                      : context.tr('home_kiuvngm_96b8db'),
                                  value: _styleKey,
                                  options: _countdownStyleOptions.map((entry) {
                                    final locked = !widget.isVipActive &&
                                        _CountdownModeIndependentScreenState
                                            ._isPremiumCountdownStyleKey(
                                          entry.value,
                                        ) &&
                                        !_unlockedStyles.contains(entry.value);
                                    return MapEntry(
                                      locked
                                          ? '${entry.key} • Quảng cáo'
                                          : entry.key,
                                      entry.value,
                                    );
                                  }).toList(growable: false),
                                  onChanged: (value) => unawaited(
                                    _handleCountdownStyleSelection(value),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _CountdownModeSheetDropdown(
                                  label: 'Khung avatar',
                                  value: _frameKey,
                                  options: _avatarFrameOptions,
                                  onChanged: (value) =>
                                      setState(() => _frameKey = value),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _fontKey,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF162136),
                                  iconEnabledColor: Colors.white70,
                                  decoration: _fieldDecoration(
                                    label: context.tr('home_phngch_9b3aa7'),
                                    dark: true,
                                  ),
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  items: SLTheme.cleanFontOptions
                                      .map(
                                        (font) => DropdownMenuItem<String>(
                                          value: font.key,
                                          child: Text(
                                            font.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: SLTheme.quicksand(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _fontKey = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 14),
                                SwitchListTile.adaptive(
                                  value: _transparentMode,
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: const Color(0xFFD81B60),
                                  title: Text(
                                    context.tr('home_knhm_33b8ab'),
                                    style: SLTheme.quicksand(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF243041),
                                    ),
                                  ),
                                  subtitle: Text(
                                    context.tr('home_gicmgictro_a2b87f'),
                                    style: SLTheme.quicksand(
                                      fontSize: 11.8,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF7C6D76),
                                    ),
                                  ),
                                  onChanged: (value) => setState(
                                    () => _transparentMode = value,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                StatefulBuilder(
                                  builder: (context, setStateSlider) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kích thước vòng đếm: ${_sizePx.round()}px',
                                          style: SLTheme.quicksand(
                                            fontSize: 12.8,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF8A5B76),
                                          ),
                                        ),
                                        Slider(
                                          min: 200,
                                          max: UiPrefs.maxCountdownSizePx,
                                          activeColor: const Color(0xFFD81B60),
                                          inactiveColor: const Color(0xFFF2C3D7),
                                          value: _sizePx.clamp(
                                            200.0,
                                            UiPrefs.maxCountdownSizePx,
                                          ),
                                          onChanged: (value) {
                                            setStateSlider(() {
                                              _sizePx = value;
                                            });
                                          },
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () => Navigator.of(context).pop(
                                              _buildResult(
                                                _CountdownModeSettingsAction.save,
                                              ),
                                            ),
                                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                            label: Text(
                                              'Lưu kích thước',
                                              style: SLTheme.quicksand(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFFD81B60),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              backgroundColor: const Color(0xFFD81B60).withValues(alpha: 0.1),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (widget.showDeleteSection) ...[
                            _sectionCard(
                              icon: Icons.delete_outline_rounded,
                              title: L10nService().translate('home_xakhnggian_e79cf3'),
                              subtitle:
                                  context.tr('home_giyucuxayb_e0eb6b'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.deleteStatusTitle
                                          .trim()
                                          .isNotEmpty ||
                                      widget.deleteStatusDescription
                                          .trim()
                                          .isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF4F6),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFF3CDD8),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (widget.deleteStatusTitle
                                              .trim()
                                              .isNotEmpty)
                                            Text(
                                              widget.deleteStatusTitle,
                                              style: SLTheme.quicksand(
                                                fontSize: 13.2,
                                                fontWeight: FontWeight.w900,
                                                color: const Color(0xFFB4234F),
                                              ),
                                            ),
                                          if (widget.deleteStatusDescription
                                              .trim()
                                              .isNotEmpty) ...[
                                            if (widget.deleteStatusTitle
                                                .trim()
                                                .isNotEmpty)
                                              const SizedBox(height: 6),
                                            Text(
                                              widget.deleteStatusDescription,
                                              style: SLTheme.quicksand(
                                                fontSize: 11.8,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF7C6D76),
                                                height: 1.42,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  if (widget.canRequestDelete) ...[
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            Navigator.of(context).pop(
                                          _buildResult(
                                            _CountdownModeSettingsAction
                                                .requestDeleteSpace,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFD81B60),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.mail_rounded,
                                        ),
                                        label: Text(
                                          context.tr('home_giyucuxa_d2e564'),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (widget.canAcceptDelete) ...[
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            Navigator.of(context).pop(
                                          _buildResult(
                                            _CountdownModeSettingsAction
                                                .acceptDeleteSpace,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFC62828),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.delete_forever_rounded,
                                        ),
                                        label: Text(
                                          context.tr('home_xcnhnxanga_0b6891'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _sectionCard(
                            icon: Icons.check_circle_rounded,
                            title: L10nService().translate('home_thaotcnhan_c45625'),
                            subtitle:
                                context.tr('home_lucuhnhcho_40e113'),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(
                                      _buildResult(
                                        _CountdownModeSettingsAction.save,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD81B60),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon:
                                        const Icon(Icons.check_circle_rounded),
                                    label: Text(context.tr('home_luthayi_0dc3cc')),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(
                                      _buildResult(
                                        _CountdownModeSettingsAction
                                            .backToSpaces,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF243041),
                                      side: const BorderSide(
                                        color: Color(0xFFF2C3D7),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(Icons.grid_view_rounded),
                                    label:
                                        Text(context.tr('home_vdanhschkh_0a2542')),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(
                                      _buildResult(
                                        _CountdownModeSettingsAction.exit,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF8A5B76),
                                      side: const BorderSide(
                                        color: Color(0xFFF2C3D7),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                    label: Text(
                                      context.tr('home_thotkhnggi_4055ed'),
                                    ),
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}
