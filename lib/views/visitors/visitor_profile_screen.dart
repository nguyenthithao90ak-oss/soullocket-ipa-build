import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../models/social_post.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/social_service.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../utils/services/house_settings_service.dart';
import '../../utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/helpers/cloudflare_image_helper.dart';
import '../../utils/services/storage/storage_service.dart';
import '../../utils/app_error_mapper.dart';
import 'profile/dialogs/profile_appearance_sheet.dart';
import 'profile/dialogs/profile_confirm_dialog.dart';
import 'profile/dialogs/profile_reason_dialog.dart';
import 'profile/sections/profile_action_widgets.dart';
import 'profile/sections/profile_header_section.dart';
import 'profile/sections/profile_section_models.dart';
import 'profile/sections/profile_stats_section.dart';
import 'profile/sections/profile_tab_bar_section.dart';
import 'profile/sections/profile_tab_content_section.dart';

// import '../community/community_settings_screen.dart'; // DELETED_COMMUNITY_FEATURE 2026-06-28
import '../home/tabs/short_video_feed_screen.dart';
import '../home/widgets/visitor_heart_anim.dart';

/// ============================================================
///  VisitorProfileScreen — GRA (Phase 42 — UI 2026 Overhaul)
///  Design: SoulLocket Design System 2026
/// ============================================================
class VisitorProfileScreen extends StatefulWidget {
  final String targetHouseId;
  final bool showBackButton;
  const VisitorProfileScreen({
    super.key,
    required this.targetHouseId,
    this.showBackButton = true,
  });

  @override
  State<VisitorProfileScreen> createState() => _VisitorProfileScreenState();
}

class _VisitorProfileScreenState extends State<VisitorProfileScreen>
    with TickerProviderStateMixin {
  static const String _pendingProfileHeaderUploadKeyPrefix =
      'visitor_profile_header_';
  static const String _pendingHouseAvatarUploadKeyPrefix =
      'visitor_house_avatar_';
  static const double _kProfileHeaderExpandedHeight = 300;
  static const double _kDefaultProfileAvatarSize = 90;
  static const double _kMinProfileAvatarSize = 74;
  static const double _kMaxProfileAvatarSize = 110;

  final _db = FirebaseDatabase.instance;
  final _houseService = HouseService();
  final _houseSettingsService = HouseSettingsService();
  final _friendsService = FriendsService();
  final _socialService = SocialService();
  final _storageService = StorageService();

  String _withRefreshToken(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final separator = trimmed.contains('?') ? '&' : '?';
    return '$trimmed${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  String? _myHouseId;
  String? _myHouseName;
  Map<String, dynamic> _targetData = {};
  Map<String, dynamic> _targetSettings = {};
  bool _isLoading = true;
  bool _isFriend = false;
  bool _isPendingSent = false;
  bool _isIncomingPending = false;
  bool _heartDroppedToday = false;
  bool _heartHasContributed = false;
  int _heartCount = 0;
  String _activeTab = 'posts';
  List<SocialPost> _posts = [];
  List<SocialPost> _locketPosts = [];
  List<SocialPost> _likedPosts = [];
  List<SocialPost> _privatePosts = [];
  List<SocialPost> _repostPosts = [];
  bool _isLoadingLiked = false;
  bool _isLoadingRepost = false;
  bool _isLoadingPrivate = false;
  bool _isLoadingLocket = false;
  bool _isUpdatingProfileAppearance = false;
  bool _didPromptPendingProfileHeaderRetry = false;
  bool _didPromptPendingHouseAvatarRetry = false;

  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_heartController);
    _load();
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  bool get _canEditProfile {
    final currentHouseId = _myHouseId?.trim() ?? '';
    final targetHouseId = widget.targetHouseId.trim();
    return currentHouseId.isNotEmpty &&
        targetHouseId.isNotEmpty &&
        currentHouseId == targetHouseId;
  }

  String? get _editableProfileHouseId {
    if (!_canEditProfile) return null;
    final targetHouseId = widget.targetHouseId.trim();
    return targetHouseId.isEmpty ? null : targetHouseId;
  }

  String get _pendingProfileHeaderUploadKey =>
      '$_pendingProfileHeaderUploadKeyPrefix${widget.targetHouseId}';

  String get _pendingHouseAvatarUploadKey =>
      '$_pendingHouseAvatarUploadKeyPrefix${widget.targetHouseId}';

  String _profileHeaderImageUrl() {
    final fromSettings = (_targetSettings['profileHeaderImageUrl'] ?? '')
        .toString()
        .trim();
    if (fromSettings.isNotEmpty) return fromSettings;
    return (_targetData['profileHeaderImageUrl'] ?? '').toString().trim();
  }

  String _profileHeaderThemeKey() {
    final raw =
        ((_targetSettings['profileHeaderThemeKey'] ??
                    _targetData['profileHeaderThemeKey']) ??
                '')
            .toString()
            .trim();
    if (visitorProfileHeaderThemes.any((theme) => theme.key == raw)) {
      return raw;
    }
    return visitorProfileHeaderThemes.first.key;
  }

  double _profileAvatarSizePx() {
    return _kDefaultProfileAvatarSize;
  }

  VisitorProfileHeaderThemeData _currentProfileHeaderTheme() {
    final activeKey = _profileHeaderThemeKey();
    for (final theme in visitorProfileHeaderThemes) {
      if (theme.key == activeKey) {
        return theme;
      }
    }
    return visitorProfileHeaderFallbackTheme;
  }

  void _applyProfilePresentationLocally({
    String? headerImageUrl,
    String? headerThemeKey,
    double? avatarSizePx,
    String? houseAvatar,
  }) {
    if (headerImageUrl != null) {
      _targetSettings['profileHeaderImageUrl'] = headerImageUrl;
      _targetData['profileHeaderImageUrl'] = headerImageUrl;
    }
    if (headerThemeKey != null) {
      _targetSettings['profileHeaderThemeKey'] = headerThemeKey;
      _targetData['profileHeaderThemeKey'] = headerThemeKey;
    }
    if (avatarSizePx != null) {
      _targetSettings['profileAvatarSizePx'] = avatarSizePx;
      _targetData['profileAvatarSizePx'] = avatarSizePx;
    }
    if (houseAvatar != null) {
      _targetSettings['houseAvatar'] = houseAvatar;
      _targetSettings['avatar'] = houseAvatar;
      _targetData['houseAvatar'] = houseAvatar;
      _targetData['avatar'] = houseAvatar;
    }
  }

  Future<void> _saveProfilePresentation({
    String? headerImageUrl,
    String? headerThemeKey,
    double? avatarSizePx,
  }) async {
    final houseId = _editableProfileHouseId;
    if (houseId == null || _isUpdatingProfileAppearance) {
      return;
    }

    final safeAvatarSize =
        (avatarSizePx?.clamp(_kMinProfileAvatarSize, _kMaxProfileAvatarSize)
                as num?)
            ?.toDouble();

    setState(() => _isUpdatingProfileAppearance = true);
    try {
      await _houseSettingsService.updateProfilePresentation(
        houseId: houseId,
        headerImageUrl: headerImageUrl,
        headerThemeKey: headerThemeKey,
        avatarSizePx: safeAvatarSize,
      );
      if (!mounted) return;
      setState(() {
        _applyProfilePresentationLocally(
          headerImageUrl: headerImageUrl,
          headerThemeKey: headerThemeKey,
          avatarSizePx: safeAvatarSize,
        );
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(context.tr('p5_profile_update_failed'));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingProfileAppearance = false);
      }
    }
  }

  Future<XFile?> _cropProfileHeaderImage(XFile file) async {
    if (kIsWeb || file.path.isEmpty) {
      return file;
    }

    final cropRatioX = MediaQuery.sizeOf(context).width;
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: CropAspectRatio(
        ratioX: cropRatioX,
        ratioY: _kProfileHeaderExpandedHeight,
      ),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      maxWidth: 1080,
      maxHeight: 1080,
      uiSettings: [
        IOSUiSettings(
          title: context.tr('p5_profile_crop_header'),
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return null;
    return XFile(croppedFile.path);
  }

  Future<XFile?> _cropHouseAvatarImage(XFile file) async {
    if (kIsWeb || file.path.isEmpty) {
      return file;
    }

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 82,
        maxWidth: 800,
        maxHeight: 800,
        uiSettings: [
          IOSUiSettings(
            title: context.tr('p5_profile_crop_avatar'),
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile == null) return null;
      return XFile(croppedFile.path);
    } catch (_) {
      return file;
    }
  }

  Future<void> _promptPendingProfileUploadRetryIfNeeded() async {
    if (!_canEditProfile || !mounted) {
      return;
    }
    if (!_didPromptPendingProfileHeaderRetry) {
      final pendingHeader = await PendingUploadService.instance.load(
        _pendingProfileHeaderUploadKey,
      );
      if (pendingHeader != null && mounted) {
        _didPromptPendingProfileHeaderRetry = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('p5_profile_header_retry_message')),
              action: SnackBarAction(
                label: context.tr('p5_retry'),
                onPressed: () {
                  unawaited(_retryPendingProfileHeaderUpload());
                },
              ),
            ),
          );
        });
      }
    }
    if (!_didPromptPendingHouseAvatarRetry) {
      final pendingAvatar = await PendingUploadService.instance.load(
        _pendingHouseAvatarUploadKey,
      );
      if (pendingAvatar != null && mounted) {
        _didPromptPendingHouseAvatarRetry = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('p5_profile_avatar_retry_message')),
              action: SnackBarAction(
                label: context.tr('p5_retry'),
                onPressed: () {
                  unawaited(_retryPendingHouseAvatarUpload());
                },
              ),
            ),
          );
        });
      }
    }
  }

  Future<void> _retryPendingProfileHeaderUpload() async {
    final pending = await PendingUploadService.instance.load(
      _pendingProfileHeaderUploadKey,
    );
    if (pending == null || !mounted) {
      return;
    }
    final filePath = pending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(_pendingProfileHeaderUploadKey);
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(
          _pendingProfileHeaderUploadKey,
        );
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(_pendingProfileHeaderUploadKey);
      return;
    }
    await _pickAndUploadProfileHeaderImage(presetFile: file);
  }

  Future<void> _retryPendingHouseAvatarUpload() async {
    final pending = await PendingUploadService.instance.load(
      _pendingHouseAvatarUploadKey,
    );
    if (pending == null || !mounted) {
      return;
    }
    final filePath = pending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(_pendingHouseAvatarUploadKey);
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(_pendingHouseAvatarUploadKey);
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(_pendingHouseAvatarUploadKey);
      return;
    }
    await _pickAndUploadHouseAvatar(presetFile: file);
  }

  Future<void> _pickAndUploadProfileHeaderImage({XFile? presetFile}) async {
    final houseId = _editableProfileHouseId;
    if (houseId == null || _isUpdatingProfileAppearance) {
      return;
    }

    XFile? file = presetFile ?? await _storageService.pickImage();
    if (file == null) return;

    try {
      if (presetFile == null) {
        file = await _cropProfileHeaderImage(file);
      }
      if (file == null) return;
      await PendingUploadService.instance.save(
        _pendingProfileHeaderUploadKey,
        <String, dynamic>{'filePath': file.path},
      );

      final upload = await _storageService.uploadPublicImage(
        houseId,
        'profile_header',
        file,
        quality: 84,
        minWidth: 1080,
        minHeight: 780,
      );
      final url = upload?.downloadUrl.trim() ?? '';
      if (url.isEmpty) {
        throw 'Ảnh nền chưa tải lên được.';
      }
      await PendingUploadService.instance.clear(_pendingProfileHeaderUploadKey);
      final refreshedUrl = _withRefreshToken(url);
      await _saveProfilePresentation(headerImageUrl: refreshedUrl);
      _showSnack(L10nService().translate('p5_profile_header_updated'));
    } catch (e) {
      if (!mounted) return;
      _showSnack(context.tr('p5_profile_header_change_failed'));
    }
  }

  Future<void> _pickAndUploadHouseAvatar({XFile? presetFile}) async {
    final houseId = _editableProfileHouseId;
    if (houseId == null || _isUpdatingProfileAppearance) {
      return;
    }

    XFile? file = presetFile ?? await _storageService.pickImage();
    if (file == null) return;

    try {
      if (presetFile == null) {
        file = await _cropHouseAvatarImage(file);
      }
      if (file == null) return;
      await PendingUploadService.instance.save(
        _pendingHouseAvatarUploadKey,
        <String, dynamic>{'filePath': file.path},
      );

      final upload = await _storageService.uploadPublicImage(
        houseId,
        'house_avatar',
        file,
        quality: 88,
        minWidth: 720,
        minHeight: 720,
      );
      final url = upload?.downloadUrl.trim() ?? '';
      if (url.isEmpty) {
        throw 'Avatar chưa tải lên được.';
      }
      await PendingUploadService.instance.clear(_pendingHouseAvatarUploadKey);
      final refreshedUrl = _withRefreshToken(url);
      if (!mounted) return;

      setState(() => _isUpdatingProfileAppearance = true);
      try {
        await _houseSettingsService.updateHouseAvatarOnly(
          houseId: houseId,
          avatarUrl: refreshedUrl,
        );
        if (!mounted) return;
        setState(() {
          _applyProfilePresentationLocally(houseAvatar: refreshedUrl);
        });
        _showSnack(context.tr('p5_profile_avatar_updated'));
      } finally {
        if (mounted) {
          setState(() => _isUpdatingProfileAppearance = false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(context.tr('p5_profile_avatar_change_failed'));
    }
  }

  Future<void> _removeProfileHeaderImage() async {
    await _saveProfilePresentation(headerImageUrl: '');
    if (!mounted) return;
    _showSnack(context.tr('p5_profile_header_reset'));
  }

  Future<void> _openCommunitySettingsScreen() async {
    // DELETED_COMMUNITY_FEATURE 2026-06-28
    _showSnack(context.tr('p5_profile_community_unavailable'));
  }

  Future<void> _openProfileAppearanceSheet() async {
    if (!_canEditProfile) return;

    await showVisitorProfileAppearanceSheet(
      context: context,
      isUpdatingProfileAppearance: _isUpdatingProfileAppearance,
      initialThemeKey: _profileHeaderThemeKey(),
      hasCustomHeaderImage: _profileHeaderImageUrl().isNotEmpty,
      themes: visitorProfileHeaderThemes,
      onPickHeaderImage: _pickAndUploadProfileHeaderImage,
      onPickAvatar: _pickAndUploadHouseAvatar,
      onRemoveHeaderImage: _removeProfileHeaderImage,
      onThemeSelected: (themeKey) => _saveProfilePresentation(
        headerImageUrl: '',
        headerThemeKey: themeKey,
      ),
      onOpenCommunitySettings: _openCommunitySettingsScreen,
      showThemeSelection: false,
    );
  }

  Future<void> _load() async {
    try {
      _myHouseId = await _houseService.getCurrentHouseId();
      if (_myHouseId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      try {
        final mySnap = await _db
            .ref('houses/$_myHouseId/settings/houseName')
            .get();
        _myHouseName = mySnap.value?.toString() ?? _myHouseId;
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/visitors/visitor_profile_screen.dart: $error',
        );
      }

      try {
        final targetSnap = await _db
            .ref('house_profiles/${widget.targetHouseId}')
            .get();
        if (targetSnap.exists && targetSnap.value is Map) {
          _targetData = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(targetSnap.value as Map),
          );
          _targetSettings = _targetData['settings'] is Map
              ? Map<String, dynamic>.from(
                  Map<dynamic, dynamic>.from(_targetData['settings'] as Map),
                )
              : {};
        }
      } catch (e) {
        debugPrint(
          'Lỗi tải house_profiles: ${AppErrorMapper.resolve(e).message}',
        );
      }

      if (_targetData.isEmpty) {
        try {
          // Chỉ fetch field cần, không load toàn bộ settings node (~10KB)
          const kSettingsFields = [
            'bio',
            'privacy',
            'proUntil',
            'relationshipMode',
            'avtUser1',
            'avtUser2',
            'hideLikeCount',
            'likedVisibility',
            'locketVisibility',
            'profileHeaderImageUrl',
            'profileHeaderThemeKey',
            'profileAvatarSizePx',
          ];
          final base = 'houses/${widget.targetHouseId}';
          final allSnaps = await Future.wait([
            _db.ref('$base/houseName').get(),
            _db.ref('$base/houseAvatar').get(),
            _db.ref('$base/avatar').get(),
            ...kSettingsFields.map((f) => _db.ref('$base/settings/$f').get()),
          ]);

          final houseNameSnap = allSnaps[0];
          final houseAvatarSnap = allSnaps[1];
          final avatarSnap = allSnaps[2];
          final settingsSnaps = allSnaps.skip(3).toList();

          final settingsMap = <String, dynamic>{};
          for (var i = 0; i < kSettingsFields.length; i++) {
            final s = settingsSnaps[i];
            if (s.exists && s.value != null) {
              settingsMap[kSettingsFields[i]] = s.value;
            }
          }

          if (allSnaps.any((s) => s.exists)) {
            _targetData = {
              if (settingsMap.isNotEmpty) 'settings': settingsMap,
              if (houseNameSnap.exists) 'houseName': houseNameSnap.value,
              if (houseAvatarSnap.exists) 'houseAvatar': houseAvatarSnap.value,
              if (avatarSnap.exists) 'avatar': avatarSnap.value,
            };
            _targetSettings = settingsMap;
          }
        } catch (error) {
          debugPrint(
            '[SuppressedError] lib/views/visitors/visitor_profile_screen.dart: $error',
          );
        }
      }

      try {
        final fireSnap = await _db
            .ref('uploads/fire_totals/${widget.targetHouseId}')
            .get();
        _heartCount = (fireSnap.value as num?)?.toInt() ?? 0;
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/visitors/visitor_profile_screen.dart: $error',
        );
      }

      try {
        final today = DateTime.now().toLocal();
        final todayKey = '${today.year}-${today.month}-${today.day}';
        final storeKey = 'fire_log_${_myHouseId}_${widget.targetHouseId}';
        final cachedHeartState = _HeartDropCache.hasDroppedToday(
          storeKey,
          todayKey,
        );
        final heartStateSnap = await _db
            .ref(
              'houses/$_myHouseId/settings/visitorHeartStates/${widget.targetHouseId}',
            )
            .get();
        if (heartStateSnap.exists && heartStateSnap.value is Map) {
          final heartState = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(heartStateSnap.value as Map),
          );
          _heartDroppedToday = heartState['active'] == true;
          _heartHasContributed = heartState['hasContributed'] == true;
        } else {
          _heartDroppedToday = cachedHeartState;
          _heartHasContributed = cachedHeartState;
        }

        final friendSnap = await _db
            .ref('friends/$_myHouseId/${widget.targetHouseId}')
            .get();
        _isFriend =
            friendSnap.exists &&
            (friendSnap.value == true || friendSnap.value != null);

        if (!_isFriend) {
          // Check for pending request sent to them
          final reqSnap = await _db
              .ref('friend_requests')
              .orderByChild('from')
              .equalTo(_myHouseId)
              .once();
          if (reqSnap.snapshot.exists && reqSnap.snapshot.value is Map) {
            final reqMap = Map<dynamic, dynamic>.from(
              reqSnap.snapshot.value as Map,
            );
            for (final entry in reqMap.entries) {
              if (entry.value is! Map) continue;
              final req = Map<String, dynamic>.from(entry.value);
              if (req['to'] == widget.targetHouseId) {
                if (req['status'] == 'pending') {
                  _isPendingSent = true;
                  break;
                } else if (req['status'] == 'accepted') {
                  _isFriend = true;
                  break;
                }
              }
            }
          }

          // Check if they sent us a pending request
          if (!_isFriend && !_isPendingSent) {
            final incomingSnap = await _db
                .ref('friend_requests')
                .orderByChild('to')
                .equalTo(_myHouseId)
                .once();
            if (incomingSnap.snapshot.exists &&
                incomingSnap.snapshot.value is Map) {
              final incomingMap = Map<dynamic, dynamic>.from(
                incomingSnap.snapshot.value as Map,
              );
              for (final v in incomingMap.values) {
                if (v is! Map) continue;
                final req = Map<String, dynamic>.from(v);
                if (req['from'] == widget.targetHouseId &&
                    req['status'] == 'pending') {
                  _isIncomingPending = true;
                  break;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Lỗi check bạn bè: ${AppErrorMapper.resolve(e).message}');
      }

      try {
        await _loadPosts();
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/visitors/visitor_profile_screen.dart: $error',
        );
      }
    } catch (e) {
      debugPrint('Lỗi profile: ${AppErrorMapper.resolve(e).message}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      unawaited(_promptPendingProfileUploadRetryIfNeeded());
    }
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await _socialService.fetchHouseFeedPage(
        widget.targetHouseId,
      );
      _posts = posts
          .where((p) => p.imageUrl.isNotEmpty || p.videoUrl.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error loading posts: ${AppErrorMapper.resolve(e).message}');
    }
  }

  Future<void> _loadReposts() async {
    setState(() => _isLoadingRepost = true);
    try {
      final posts = await _socialService.fetchRepostFeedPage(
        widget.targetHouseId,
      );
      _repostPosts = posts
          .where((p) => p.imageUrl.isNotEmpty || p.videoUrl.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error loading reposts: ${AppErrorMapper.resolve(e).message}');
    } finally {
      if (mounted) setState(() => _isLoadingRepost = false);
    }
  }

  Future<void> _loadPrivatePosts() async {
    setState(() => _isLoadingPrivate = true);
    try {
      final posts = await _socialService.fetchPrivateFeedPage(
        widget.targetHouseId,
      );
      _privatePosts = posts
          .where((p) => p.imageUrl.isNotEmpty || p.videoUrl.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint(
        'Error loading private posts: ${AppErrorMapper.resolve(e).message}',
      );
    } finally {
      if (mounted) setState(() => _isLoadingPrivate = false);
    }
  }

  Future<void> _loadLocketPosts() async {
    setState(() => _isLoadingLocket = true);
    try {
      final posts = await _socialService.fetchLocketFeedPage(
        widget.targetHouseId,
      );
      final isMe = _canEditProfile;
      _locketPosts = posts.where((p) {
        if (!p.isLocket) return false;
        if (p.imageUrl.isEmpty && p.videoUrl.isEmpty) return false;

        if (!isMe) {
          if (_isFriend) {
            if (p.privacy != 'public' && p.privacy != 'friends') return false;
          } else {
            if (p.privacy != 'public') return false;
          }
        }
        return true;
      }).toList();
    } catch (e) {
      debugPrint(
        'Error loading locket posts: ${AppErrorMapper.resolve(e).message}',
      );
    } finally {
      if (mounted) setState(() => _isLoadingLocket = false);
    }
  }

  Future<void> _loadLikedPosts() async {
    setState(() => _isLoadingLiked = true);
    try {
      _likedPosts = await _socialService.fetchLikedFeedPage(
        widget.targetHouseId,
      );
    } catch (e) {
      debugPrint(
        'Error loading liked posts: ${AppErrorMapper.resolve(e).message}',
      );
    } finally {
      if (mounted) setState(() => _isLoadingLiked = false);
    }
  }

  bool _isDroppingHeart = false;

  Future<void> _toggleHeart() async {
    if (_myHouseId == null || _isDroppingHeart) return;
    if (_myHouseId == widget.targetHouseId) {
      _showSnack(context.tr('p5_profile_cannot_heart_self'));
      return;
    }

    final wasDropped = _heartDroppedToday;
    final hadContributed = _heartHasContributed;
    final previousCount = _heartCount;
    final today = DateTime.now().toLocal();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final storeKey = 'fire_log_${_myHouseId}_${widget.targetHouseId}';

    // Optimistic UI update
    setState(() {
      _isDroppingHeart = true;
      if (wasDropped) {
        _heartDroppedToday = false;
        if (_heartCount > 0) {
          _heartCount--;
        }
      } else {
        _heartDroppedToday = true;
        _heartCount++;
      }
    });

    _heartController.forward(from: 0);
    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('dropVisitorHeart')
          .call(<String, dynamic>{
            'targetHouseId': widget.targetHouseId,
            'active': !wasDropped,
          });
      final payload = response.data;
      if (payload is! Map || payload['success'] != true) {
        throw StateError('Visitor heart update was not accepted.');
      }
      final resolvedActive = payload['active'] == true;
      final resolvedCount =
          (payload['count'] as num?)?.toInt() ?? previousCount;
      if (resolvedActive) {
        _HeartDropCache.setDropped(storeKey, todayKey);
      } else {
        _HeartDropCache.clearDropped(storeKey);
      }
      if (!mounted) return;
      if (!wasDropped && resolvedActive) {
        VisitorHeartAnim.drop(context);
      }
      setState(() {
        _heartDroppedToday = resolvedActive;
        _heartHasContributed = resolvedActive;
        _heartCount = resolvedCount;
        _isDroppingHeart = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _heartDroppedToday = wasDropped;
        _heartHasContributed = hadContributed;
        _heartCount = previousCount;
        _isDroppingHeart = false;
      });
      _showSnack(context.tr('p5_profile_connection_unstable'));
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_myHouseId == null) return;
    setState(() => _isPendingSent = true);
    final result = await _friendsService.sendFriendRequest(
      fromHouseId: _myHouseId!,
      fromHouseName: _myHouseName ?? _myHouseId!,
      toHouseId: widget.targetHouseId,
    );
    if (result.success) {
      _showSnack(L10nService().translate('p5_profile_friend_request_sent'));
    } else {
      if (!mounted) return;
      setState(() => _isPendingSent = false);
      _showSnack(result.message);
    }
  }

  Future<void> _reportUser() async {
    final reason = await _promptReason(context.tr('p5_profile_report_hint'));
    final reporterHouseId = _myHouseId;
    if (reason == null || reporterHouseId == null || reporterHouseId.isEmpty) {
      return;
    }
    try {
      await _socialService.reportUser(
        targetHouseId: widget.targetHouseId,
        reporterHouseId: reporterHouseId,
        reason: reason,
      );
      _showSnack(L10nService().translate('p5_profile_report_sent'));
    } catch (e) {
      _showSnack(L10nService().translate('p5_profile_report_failed'));
    }
  }

  Future<void> _blockUser() async {
    final myHouseId = _myHouseId;
    if (myHouseId == null || myHouseId.isEmpty) {
      _showSnack(context.tr('p5_profile_block_no_house'));
      return;
    }
    final ok = await _confirm(
      context.tr('p5_profile_block_title'),
      context.tr('p5_profile_block_message'),
    );
    if (!ok) return;
    try {
      await _socialService.blockHouse(
        sourceHouseId: myHouseId,
        targetHouseId: widget.targetHouseId,
      );
      _showSnack(L10nService().translate('p5_profile_blocked'));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack(L10nService().translate('p5_profile_block_failed'));
    }
  }

  void _copyProfileLink() {
    final link = AppConfig.webUri(
      '/profile/${widget.targetHouseId}',
    ).toString();
    Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _showSnack(context.tr('p5_profile_link_copied'));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SLColors.bgMain,
        body: Center(child: CircularProgressIndicator(color: SLColors.primary)),
      );
    }

    final name = (_targetData['houseName'] ?? '').toString();
    final avatar =
        _targetSettings['houseAvatar']?.toString() ??
        _targetData['houseAvatar']?.toString() ??
        _targetData['avatar']?.toString();
    final bio = _targetSettings['bio']?.toString() ?? '';
    final privacy = _targetSettings['privacy']?.toString() ?? 'public';
    final isMe = _canEditProfile;
    final isPro =
        ((_targetSettings['proUntil'] as num?)?.toInt() ?? 0) >
        DateTime.now().millisecondsSinceEpoch;

    return Scaffold(
      backgroundColor: SLColors.bgMain,
      body: CustomScrollView(
        physics: SLResponsive.scrollPhysicsForPlatform(),
        slivers: [
          SliverAppBar(
            expandedHeight: _kProfileHeaderExpandedHeight,
            pinned: true,
            automaticallyImplyLeading: widget.showBackButton,
            backgroundColor: SLColors.primary,
            elevation: 0,
            leading: widget.showBackButton
                ? IconButton(
                    icon: Container(
                      padding: SLSpacing.all8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    tooltip: context.tr('p5_back'),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: [
              VisitorProfileAppBarActions(
                isMe: isMe,
                isUpdatingProfileAppearance: _isUpdatingProfileAppearance,
                menuActions: _buildProfileMenuActions(),
                onOpenAppearance: _openProfileAppearanceSheet,
                onSelected: _handleProfileMenuSelection,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: RepaintBoundary(
                child: _buildProfileHeader(
                  name: name,
                  avatar: avatar,
                  bio: bio,
                  isMe: isMe,
                  isPro: isPro,
                ),
              ),
            ),
          ),
          if (privacy == 'private' && !isMe && !_isFriend)
            SliverToBoxAdapter(
              child: VisitorProfilePrivacyBlock(
                title: context.tr('p5_profile_private_title'),
                subtitle: context.tr('p5_profile_private_subtitle'),
              ),
            )
          else if (privacy == 'friends' && !isMe && !_isFriend)
            SliverToBoxAdapter(
              child: VisitorProfilePrivacyBlock(
                title: context.tr('p5_profile_friends_only_title'),
                subtitle: context.tr('p5_profile_friends_only_subtitle'),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: _buildStatsRow()),
            SliverToBoxAdapter(child: _buildTabBar(isMe)),
            ..._buildActiveTabSlivers(),
          ],
          SliverToBoxAdapter(child: SLSpacing.gapH(48)),
        ],
      ),
    );
  }

  Widget _buildProfileHeader({
    required String name,
    required String? avatar,
    required String bio,
    required bool isMe,
    required bool isPro,
  }) {
    return VisitorProfileHeaderSection(
      name: name,
      avatarUrl: avatar,
      bio: bio,
      isMe: isMe,
      isPro: isPro,
      isSingle: _targetSettings['relationshipMode'] == 'single',
      partnerAvatar1: _targetSettings['avtUser1']?.toString().trim() ?? '',
      partnerAvatar2: _targetSettings['avtUser2']?.toString().trim() ?? '',
      avatarSize: _profileAvatarSizePx(),
      headerImageUrl: _profileHeaderImageUrl(),
      theme: _currentProfileHeaderTheme(),
      isUpdatingProfileAppearance: _isUpdatingProfileAppearance,
      isDroppingHeart: _isDroppingHeart,
      isHeartDroppedToday: _heartDroppedToday,
      heartCount: _heartCount,
      heartScale: _heartScale,
      onOpenAppearance: _openProfileAppearanceSheet,
      onPickAvatar: isMe ? _pickAndUploadHouseAvatar : null,
      onToggleHeart: _toggleHeart,
    );
  }

  Widget _buildStatsRow() {
    return VisitorProfileStatsSection(
      postCount: _posts.length,
      heartCount: _heartCount,
      hideLikeCount: _targetSettings['hideLikeCount'] == true,
      isMe: _canEditProfile,
      isFriend: _isFriend,
    );
  }

  Widget _buildTabBar(bool isMe) {
    return VisitorProfileTabBarSection(
      activeTab: _activeTab,
      items: _visibleTabItems(isMe),
      onSelected: _handleTabSelected,
    );
  }

  List<VisitorProfileMenuAction> _buildProfileMenuActions() {
    final actions = <VisitorProfileMenuAction>[];

    if (!_isFriend && !_isPendingSent && !_isIncomingPending) {
      actions.add(
        VisitorProfileMenuAction(
          value: 'add_friend',
          icon: Icons.person_add_rounded,
          label: context.tr('p5_profile_add_friend'),
          iconColor: SLColors.primary,
          textColor: SLColors.primary,
        ),
      );
    }

    if (_isPendingSent) {
      actions.add(
        VisitorProfileMenuAction(
          value: 'pending_sent',
          icon: Icons.schedule_rounded,
          label: context.tr('p5_profile_pending_sent'),
          iconColor: Colors.grey,
          textColor: Colors.grey,
          enabled: false,
        ),
      );
    }

    if (_isIncomingPending) {
      actions.add(
        VisitorProfileMenuAction(
          value: 'incoming_pending',
          icon: Icons.mark_email_unread_rounded,
          label: context.tr('p5_profile_incoming_pending'),
          iconColor: Colors.grey,
          textColor: Colors.grey,
          enabled: false,
        ),
      );
    }

    actions.addAll([
      VisitorProfileMenuAction(
        value: 'copy_link',
        icon: Icons.link_rounded,
        label: context.tr('p5_profile_copy_link'),
        iconColor: SLColors.textSecond,
      ),
      VisitorProfileMenuAction(
        value: 'report',
        icon: Icons.flag_outlined,
        label: context.tr('p5_profile_report'),
        iconColor: SLColors.textSecond,
      ),
      VisitorProfileMenuAction(
        value: 'block',
        icon: Icons.block,
        label: context.tr('p5_profile_block'),
        iconColor: Colors.red,
        textColor: Colors.red,
      ),
    ]);

    return actions;
  }

  void _handleProfileMenuSelection(String value) {
    if (value == 'add_friend') _sendFriendRequest();
    if (value == 'copy_link') _copyProfileLink();
    if (value == 'report') _reportUser();
    if (value == 'block') _blockUser();
  }

  List<VisitorProfileTabItem> _visibleTabItems(bool isMe) {
    final items = <VisitorProfileTabItem>[
      VisitorProfileTabItem(
        id: 'posts',
        icon: Icons.grid_on_rounded,
        label: context.tr('p5_profile_tab_posts'),
      ),
    ];

    final likedVisibility =
        _targetSettings['likedVisibility']?.toString() ?? 'private';
    final canSeeLiked = isMe || likedVisibility == 'public';
    final locketVisibility =
        _targetSettings['locketVisibility']?.toString() ?? 'private';
    final canSeeLocket = isMe || locketVisibility == 'public';

    if (canSeeLocket) {
      items.add(
        VisitorProfileTabItem(
          id: 'locket',
          icon: Icons.camera_alt_rounded,
          label: context.tr('p5_profile_tab_locket'),
        ),
      );
    }

    if (canSeeLiked) {
      items.add(
        VisitorProfileTabItem(
          id: 'liked',
          icon: Icons.favorite_rounded,
          label: context.tr('p5_profile_tab_liked'),
        ),
      );
    }

    items.add(
      VisitorProfileTabItem(
        id: 'repost',
        icon: Icons.repeat_rounded,
        label: context.tr('p5_profile_tab_repost'),
      ),
    );

    if (isMe) {
      items.add(
        VisitorProfileTabItem(
          id: 'private',
          icon: Icons.lock_outline_rounded,
          label: context.tr('p5_profile_tab_private'),
        ),
      );
    }

    return items;
  }

  void _handleTabSelected(String tab) {
    setState(() => _activeTab = tab);
    if (tab == 'repost' && _repostPosts.isEmpty) _loadReposts();
    if (tab == 'private' && _privatePosts.isEmpty) _loadPrivatePosts();
    if (tab == 'locket' && _locketPosts.isEmpty) _loadLocketPosts();
    if (tab == 'liked' && _likedPosts.isEmpty && !_isLoadingLiked) {
      _loadLikedPosts();
    }
  }

  Map<String, VisitorProfileTabContentData> _tabContentById() {
    return {
      'posts': VisitorProfileTabContentData(
        isLoading: false,
        posts: _posts,
        emptyText: context.tr('p5_profile_empty_posts'),
        valueKeyPrefix: 'post',
        filterType: 'house',
      ),
      'locket': VisitorProfileTabContentData(
        isLoading: _isLoadingLocket,
        posts: _locketPosts,
        emptyText: context.tr('p5_profile_empty_locket'),
        valueKeyPrefix: 'locket',
        filterType: 'locket_profile',
      ),
      'repost': VisitorProfileTabContentData(
        isLoading: _isLoadingRepost,
        posts: _repostPosts,
        emptyText: context.tr('p5_profile_empty_reposts'),
        valueKeyPrefix: 'repost',
        filterType: 'repost',
      ),
      'private': VisitorProfileTabContentData(
        isLoading: _isLoadingPrivate,
        posts: _privatePosts,
        emptyText: context.tr('p5_profile_empty_private'),
        valueKeyPrefix: 'private',
        filterType: 'private',
      ),
      'liked': VisitorProfileTabContentData(
        isLoading: _isLoadingLiked,
        posts: _likedPosts,
        emptyText: context.tr('p5_profile_empty_liked'),
        valueKeyPrefix: 'liked',
        filterType: 'liked',
      ),
    };
  }

  List<Widget> _buildActiveTabSlivers() {
    return buildVisitorProfileTabContentSlivers(
      activeTab: _activeTab,
      tabContent: _tabContentById(),
      buildPostThumb: _buildPostThumb,
      onOpenPost: _openTabFeed,
    );
  }

  void _openTabFeed(int index, VisitorProfileTabContentData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShortVideoFeedScreen(
          houseId: _myHouseId ?? widget.targetHouseId,
          targetHouseId: widget.targetHouseId,
          filterType: data.filterType,
          initialIndex: index,
          initialPosts: data.posts,
        ),
      ),
    );
  }

  Widget _buildPostThumb(SocialPost post) {
    final img = post.imageUrl.isNotEmpty ? post.imageUrl : post.videoUrl;
    final likes = post.likes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (img.isNotEmpty)
            CachedNetworkImage(
              maxWidthDiskCache: 300,
              memCacheWidth: 300,
              imageUrl: CloudflareImageHelper.optimizeUrl(img, width: 300),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) => Container(color: SLColors.borderLight),
              errorWidget: (_, _, _) => Container(color: SLColors.border),
            )
          else
            Container(
              color: SLColors.borderLight,
              child: const Icon(
                Icons.image_outlined,
                color: Colors.grey,
                size: 28,
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  SLSpacing.w4,
                  Text(
                    '$likes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
        backgroundColor: SLColors.textPrimary,
      ),
    );
  }

  Future<String?> _promptReason(String hint) {
    return showVisitorProfileReasonDialog(context: context, hint: hint);
  }

  Future<bool> _confirm(String title, String msg) {
    return showVisitorProfileConfirmDialog(
      context: context,
      title: title,
      message: msg,
    );
  }
}

class _HeartDropCache {
  static final Map<String, String> _cache = {};
  static bool hasDroppedToday(String key, String todayKey) =>
      _cache[key] == todayKey;
  static void setDropped(String key, String todayKey) => _cache[key] = todayKey;
  static void clearDropped(String key) => _cache.remove(key);
}
