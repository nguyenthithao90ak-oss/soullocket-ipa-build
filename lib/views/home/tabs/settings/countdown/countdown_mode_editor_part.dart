// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../settings_tab.dart';

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
    for (final styleKey
        in _CountdownModeIndependentScreenState._premiumCountdownStyleKeys) {
      final expiryKey = 'il_countdown_style_unlock_expiry_$styleKey';
      final expiry = prefs.getInt(expiryKey) ?? 0;
      if (expiry > now) {
        loaded.add(styleKey);
      }
    }
    // Migration: legacy global unlocks
    final legacyExpiry =
        prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    if (legacyExpiry > now) {
      loaded.addAll(
          _CountdownModeIndependentScreenState._premiumCountdownStyleKeys);
    } else {
      final legacyTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
      if (legacyTs > 0) {
        final fallbackExpiry =
            legacyTs + const Duration(days: 7).inMilliseconds;
        if (fallbackExpiry > now) {
          loaded.addAll(
              _CountdownModeIndependentScreenState._premiumCountdownStyleKeys);
        }
      }
    }
    if (mounted) {
      setState(() {
        _unlockedStyles = loaded;
      });
    }
  }

  Future<void> _copyFromMainCountdown() async {
    final houseId = widget.currentHouseId;
    if (houseId == null || houseId.isEmpty) {
      _showMessage('Không tìm thấy mã nhà hiện tại.');
      return;
    }
    try {
      final settings = await HouseSettingsService().fetchSettings(houseId);
      if (settings == null) {
        _showMessage('Không thể tải cấu hình Vòng Đếm chính.');
        return;
      }
      setState(() {
        if (settings.startDate.isNotEmpty) {
          _anchorDate = DateTime.tryParse(settings.startDate);
        }
        _topCtrl.text = settings.countdownTopLabel.isNotEmpty
            ? settings.countdownTopLabel
            : settings.houseName;
        _bottomCtrl.text = settings.countdownBottomLabel.isNotEmpty
            ? settings.countdownBottomLabel
            : 'ngày yêu';
        _leftCtrl.text = settings.nameU1;
        _rightCtrl.text = settings.nameU2;
        _leftAvatarCtrl.text = settings.avtUser1;
        _rightAvatarCtrl.text = settings.avtUser2;
        _styleKey = settings.countdownStyle.trim().isNotEmpty
            ? settings.countdownStyle.trim().toLowerCase()
            : 'default';
        _themeKey = settings.theme.trim().isNotEmpty
            ? settings.theme.trim()
            : 'theme-default';
        _transparentMode = settings.transparentMode;
      });
      _showMessage('Đã sao chép dữ liệu từ Vòng Đếm chính.');
    } catch (e) {
      _showMessage('Lỗi khi sao chép: ${AppErrorMapper.resolve(e).message}');
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
    return _singleMode
        ? context.tr('home_tuicati_5c654c')
        : context.tr('home_yunhau_501102');
  }

  String _previewBottomLabel() {
    final value = _bottomCtrl.text.trim();
    if (value.isNotEmpty) return value;
    return _singleMode
        ? context.tr('home_ngytui_22bed4')
        : context.tr('home_ngy_41ec10');
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
          content: Text(context.tr('home_lnuploadkh_b2b1ac')),
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
    final exists =
        _countdownStyleOptions.any((item) => item.value == normalized);
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
      _showMessage(
          'Đã mở khóa "${_countdownStyleOptions.firstWhere((e) => e.value == normalized).key}" trong 5 tiếng!');
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
    await AdMobService().showInterstitialAd();
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
    List<Color>? iconGradient,
    required Widget child,
  }) =>
      _sectionCardImpl(
        icon: icon,
        title: title,
        subtitle: subtitle,
        iconGradient: iconGradient,
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
                          ..._buildEditorHeader(context, themeData),
                          ..._buildEditorPreview(context, themeData),
                          ..._buildEditorLabels(context, themeData),
                          ..._buildEditorDate(context, themeData),
                          ..._buildEditorStyles(context, themeData),
                          ..._buildEditorBackground(context, themeData),
                          ..._buildEditorDelete(context, themeData),
                          ..._buildEditorAvatars(context, themeData),
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
