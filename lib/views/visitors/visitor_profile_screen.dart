import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/widgets/sl_image_crop_file.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../core/sl_route.dart';
import '../../models/social_post.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/social_service.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../utils/services/house_settings_service.dart';
import '../../utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/helpers/cloudflare_image_helper.dart';
import '../../utils/services/storage/storage_service.dart';
import '../../utils/services/storage/storage_media_commit.dart';
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
  VisitorProfileTabLoadStatus _likedStatus = VisitorProfileTabLoadStatus.idle;
  VisitorProfileTabLoadStatus _postsStatus = VisitorProfileTabLoadStatus.idle;
  VisitorProfileTabLoadStatus _repostStatus = VisitorProfileTabLoadStatus.idle;
  VisitorProfileTabLoadStatus _privateStatus = VisitorProfileTabLoadStatus.idle;
  VisitorProfileTabLoadStatus _locketStatus = VisitorProfileTabLoadStatus.idle;
  Future<List<SocialPost>>? _likedRequest;
  Future<List<SocialPost>>? _repostRequest;
  Future<List<SocialPost>>? _privateRequest;
  Future<List<SocialPost>>? _locketRequest;
  bool _isUpdatingProfileAppearance = false;
  bool _isUploadingProfileImage = false;
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
    bool propagateFailure = false,
  }) async {
    final houseId = _editableProfileHouseId;
    if (houseId == null || _isUpdatingProfileAppearance) {
      if (propagateFailure) throw StateError('Profile is not writable');
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
      if (propagateFailure) rethrow;
      if (!mounted) return;
      _showSnack(context.tr('p5_profile_update_failed'));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingProfileAppearance = false);
      }
    }
  }

  Future<XFile?> _cropProfileHeaderImage(XFile file) {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = _editableProfileHouseId;
    return cropAndConfirmImage(
      context: context,
      image: file,
      aspectRatio:
          MediaQuery.sizeOf(context).width / _kProfileHeaderExpandedHeight,
      maxOutputSize: const Size(1080, 1080),
      titleKey: 'p5_profile_crop_header',
      isScopeCurrent: () =>
          mounted &&
          ownerUid != null &&
          _editableProfileHouseId == houseId &&
          FirebaseAuth.instance.currentUser?.uid == ownerUid,
    );
  }

  Future<XFile?> _cropHouseAvatarImage(XFile file) {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = _editableProfileHouseId;
    return cropAndConfirmImage(
      context: context,
      image: file,
      aspectRatio: 1,
      circular: true,
      maxOutputSize: const Size(800, 800),
      titleKey: 'p5_profile_crop_avatar',
      isScopeCurrent: () =>
          mounted &&
          ownerUid != null &&
          _editableProfileHouseId == houseId &&
          FirebaseAuth.instance.currentUser?.uid == ownerUid,
    );
  }

  Future<void> _promptPendingProfileUploadRetryIfNeeded() async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (!_canEditProfile || !mounted || ownerUid == null || ownerUid.isEmpty) {
      return;
    }
    if (!_didPromptPendingProfileHeaderRetry) {
      final pendingHeader = await PendingUploadService.instance.load(
        _pendingProfileHeaderUploadKey,
        expectedUid: ownerUid,
      );
      if (pendingHeader != null && mounted) {
        _didPromptPendingProfileHeaderRetry = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SLSnackBar(
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
        expectedUid: ownerUid,
      );
      if (pendingAvatar != null && mounted) {
        _didPromptPendingHouseAvatarRetry = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SLSnackBar(
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
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || ownerUid.isEmpty) return;
    final pending = await PendingUploadService.instance.load(
      _pendingProfileHeaderUploadKey,
      expectedUid: ownerUid,
    );
    if (pending == null || !mounted) {
      return;
    }
    final filePath = pending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(
        _pendingProfileHeaderUploadKey,
        expectedUid: ownerUid,
      );
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(
          _pendingProfileHeaderUploadKey,
          expectedUid: ownerUid,
        );
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(
        _pendingProfileHeaderUploadKey,
        expectedUid: ownerUid,
      );
      return;
    }
    await _pickAndUploadProfileHeaderImage(presetFile: file);
  }

  Future<void> _retryPendingHouseAvatarUpload() async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || ownerUid.isEmpty) return;
    final pending = await PendingUploadService.instance.load(
      _pendingHouseAvatarUploadKey,
      expectedUid: ownerUid,
    );
    if (pending == null || !mounted) {
      return;
    }
    final filePath = pending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(
        _pendingHouseAvatarUploadKey,
        expectedUid: ownerUid,
      );
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(
          _pendingHouseAvatarUploadKey,
          expectedUid: ownerUid,
        );
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(
        _pendingHouseAvatarUploadKey,
        expectedUid: ownerUid,
      );
      return;
    }
    await _pickAndUploadHouseAvatar(presetFile: file);
  }

  Future<void> _pickAndUploadProfileHeaderImage({XFile? presetFile}) async {
    final houseId = _editableProfileHouseId;
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final pendingKey = _pendingProfileHeaderUploadKey;
    bool isCurrent() =>
        mounted &&
        ownerUid != null &&
        _editableProfileHouseId == houseId &&
        FirebaseAuth.instance.currentUser?.uid == ownerUid;
    if (houseId == null ||
        !isCurrent() ||
        _isUpdatingProfileAppearance ||
        _isUploadingProfileImage) {
      return;
    }

    _isUploadingProfileImage = true;
    try {
      XFile? file =
          presetFile ?? await _storageService.pickImage(preserveOriginal: true);
      if (file == null || !isCurrent()) return;
      if (presetFile == null) {
        file = await _cropProfileHeaderImage(file);
      }
      if (file == null || !isCurrent()) return;
      await PendingUploadService.instance.save(pendingKey, <String, dynamic>{
        'filePath': file.path,
      }, expectedUid: ownerUid);

      if (!mounted || !isCurrent()) return;
      final freshHouseId = await _houseService.getCurrentHouseId();
      if (!isCurrent() || freshHouseId != houseId) return;
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
        throw L10nService().translate(
          'ui_visitors_unable_to_upload_the_background_image_a60d58',
        );
      }
      final refreshedUrl = _withRefreshToken(url);
      await StorageMediaCommit.commit(
        scopeIsCurrent: isCurrent,
        persist: () => _saveProfilePresentation(
          headerImageUrl: refreshedUrl,
          propagateFailure: true,
        ),
        clearPending: () => PendingUploadService.instance.clear(
          pendingKey,
          expectedUid: ownerUid,
        ),
      );
      if (!mounted || !isCurrent()) return;
      await discardConfirmedCropImage(file);
      if (!mounted || !isCurrent()) return;
      _showSnack(L10nService().translate('p5_profile_header_updated'));
    } catch (e) {
      if (!mounted || !isCurrent()) return;
      _showSnack(context.tr('p5_profile_header_change_failed'));
    } finally {
      _isUploadingProfileImage = false;
    }
  }

  Future<void> _pickAndUploadHouseAvatar({XFile? presetFile}) async {
    final houseId = _editableProfileHouseId;
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final pendingKey = _pendingHouseAvatarUploadKey;
    bool isCurrent() =>
        mounted &&
        ownerUid != null &&
        _editableProfileHouseId == houseId &&
        FirebaseAuth.instance.currentUser?.uid == ownerUid;
    if (houseId == null ||
        !isCurrent() ||
        _isUpdatingProfileAppearance ||
        _isUploadingProfileImage) {
      return;
    }

    _isUploadingProfileImage = true;
    try {
      XFile? file =
          presetFile ?? await _storageService.pickImage(preserveOriginal: true);
      if (file == null || !isCurrent()) return;
      if (presetFile == null) {
        file = await _cropHouseAvatarImage(file);
      }
      if (file == null || !isCurrent()) return;
      await PendingUploadService.instance.save(pendingKey, <String, dynamic>{
        'filePath': file.path,
      }, expectedUid: ownerUid);

      if (!mounted || !isCurrent()) return;
      final freshHouseId = await _houseService.getCurrentHouseId();
      if (!isCurrent() || freshHouseId != houseId) return;
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
        throw L10nService().translate(
          'ui_visitors_unable_to_upload_the_profile_photo_242a6c',
        );
      }
      final refreshedUrl = _withRefreshToken(url);
      if (!mounted || !isCurrent()) return;

      setState(() => _isUpdatingProfileAppearance = true);
      try {
        await StorageMediaCommit.commit(
          scopeIsCurrent: isCurrent,
          persist: () => _houseSettingsService.updateHouseAvatarOnly(
            houseId: houseId,
            avatarUrl: refreshedUrl,
          ),
          clearPending: () => PendingUploadService.instance.clear(
            pendingKey,
            expectedUid: ownerUid,
          ),
        );
        if (!mounted || !isCurrent()) return;
        await discardConfirmedCropImage(file);
        if (!mounted || !isCurrent()) return;
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
      if (!mounted || !isCurrent()) return;
      _showSnack(context.tr('p5_profile_avatar_change_failed'));
    } finally {
      _isUploadingProfileImage = false;
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
      _myHouseId = await _houseService.getCurrentHouseId().timeout(
        const Duration(seconds: 12),
      );
      if (_myHouseId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;

      await Future.wait<void>([
        () async {
          try {
            final mySnap = await _db
                .ref('houses/$_myHouseId/settings/houseName')
                .get()
                .timeout(const Duration(seconds: 12));
            _myHouseName = mySnap.value?.toString() ?? _myHouseId;
          } catch (error) {
            debugPrint(
              '[SuppressedError] lib/views/visitors/visitor_profile_screen.dart: $error',
            );
          }
        }(),
        () async {
          try {
            final targetSnap = await _db
                .ref('house_profiles/${widget.targetHouseId}')
                .get()
                .timeout(const Duration(seconds: 12));
            if (targetSnap.exists && targetSnap.value is Map) {
              _targetData = Map<String, dynamic>.from(
                Map<dynamic, dynamic>.from(targetSnap.value as Map),
              );
              _targetSettings = _targetData['settings'] is Map
                  ? Map<String, dynamic>.from(
                      Map<dynamic, dynamic>.from(
                        _targetData['settings'] as Map,
                      ),
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
                ...kSettingsFields.map(
                  (f) => _db.ref('$base/settings/$f').get(),
                ),
              ]).timeout(const Duration(seconds: 12));

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
                  if (houseAvatarSnap.exists)
                    'houseAvatar': houseAvatarSnap.value,
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
        }(),
        () async {
          try {
            final fireSnap = await _db
                .ref('uploads/fire_totals/${widget.targetHouseId}')
                .get()
                .timeout(const Duration(seconds: 12));
            _heartCount = (fireSnap.value as num?)?.toInt() ?? 0;
          } catch (error) {
            debugPrint(
              '[SuppressedError] lib/views/visitors/visitor_profile_screen.dart: $error',
            );
          }
        }(),
        () async {
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
                .get()
                .timeout(const Duration(seconds: 12));
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
                .get()
                .timeout(const Duration(seconds: 12));
            _isFriend =
                friendSnap.exists &&
                (friendSnap.value == true || friendSnap.value != null);

            if (!_isFriend) {
              // Check for pending request sent to them
              final reqSnap = await _db
                  .ref('friend_requests')
                  .orderByChild('from')
                  .equalTo(_myHouseId)
                  .once()
                  .timeout(const Duration(seconds: 12));
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
                    .once()
                    .timeout(const Duration(seconds: 12));
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
            debugPrint(
              'Lỗi check bạn bè: ${AppErrorMapper.resolve(e).message}',
            );
          }
        }(),
        _loadPosts(),
      ]);
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
    if (_postsStatus == VisitorProfileTabLoadStatus.loading ||
        _postsStatus == VisitorProfileTabLoadStatus.loaded) {
      return;
    }
    if (mounted) {
      setState(() => _postsStatus = VisitorProfileTabLoadStatus.loading);
    }
    try {
      final posts = await _socialService
          .fetchHouseFeedPage(widget.targetHouseId)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _posts = posts
            .where((p) => p.imageUrl.isNotEmpty || p.videoUrl.isNotEmpty)
            .toList();
        _postsStatus = VisitorProfileTabLoadStatus.loaded;
      });
    } catch (e) {
      debugPrint('Error loading posts: ${AppErrorMapper.resolve(e).message}');
      if (mounted) {
        setState(() => _postsStatus = VisitorProfileTabLoadStatus.failed);
      }
    }
  }

  Future<void> _loadReposts({bool retry = false}) async {
    if (_repostRequest != null) return;
    if (_repostStatus == VisitorProfileTabLoadStatus.loading ||
        (_repostStatus == VisitorProfileTabLoadStatus.loaded && !retry) ||
        (_repostStatus == VisitorProfileTabLoadStatus.failed && !retry)) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingRepost = true;
        _repostStatus = VisitorProfileTabLoadStatus.loading;
      });
    }
    Future<List<SocialPost>>? request;
    try {
      request = _socialService.fetchRepostFeedPage(widget.targetHouseId);
      _repostRequest = request;
      final posts = await request.timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _repostPosts = posts
            .where((p) => p.imageUrl.isNotEmpty || p.videoUrl.isNotEmpty)
            .toList();
        _repostStatus = VisitorProfileTabLoadStatus.loaded;
      });
    } catch (e) {
      debugPrint('Error loading reposts: ${AppErrorMapper.resolve(e).message}');
      if (mounted) {
        setState(() => _repostStatus = VisitorProfileTabLoadStatus.failed);
      }
    } finally {
      if (identical(_repostRequest, request)) _repostRequest = null;
      if (mounted) setState(() => _isLoadingRepost = false);
    }
  }

  Future<void> _loadPrivatePosts({bool retry = false}) async {
    if (_privateRequest != null) return;
    if (_privateStatus == VisitorProfileTabLoadStatus.loading ||
        (_privateStatus == VisitorProfileTabLoadStatus.loaded && !retry) ||
        (_privateStatus == VisitorProfileTabLoadStatus.failed && !retry)) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingPrivate = true;
        _privateStatus = VisitorProfileTabLoadStatus.loading;
      });
    }
    Future<List<SocialPost>>? request;
    try {
      request = _socialService.fetchPrivateFeedPage(widget.targetHouseId);
      _privateRequest = request;
      final posts = await request.timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _privatePosts = posts
            .where((p) => p.imageUrl.isNotEmpty || p.videoUrl.isNotEmpty)
            .toList();
        _privateStatus = VisitorProfileTabLoadStatus.loaded;
      });
    } catch (e) {
      debugPrint(
        'Error loading private posts: ${AppErrorMapper.resolve(e).message}',
      );
      if (mounted) {
        setState(() => _privateStatus = VisitorProfileTabLoadStatus.failed);
      }
    } finally {
      if (identical(_privateRequest, request)) _privateRequest = null;
      if (mounted) setState(() => _isLoadingPrivate = false);
    }
  }

  Future<void> _loadLocketPosts({bool retry = false}) async {
    if (_locketRequest != null) return;
    if (_locketStatus == VisitorProfileTabLoadStatus.loading ||
        (_locketStatus == VisitorProfileTabLoadStatus.loaded && !retry) ||
        (_locketStatus == VisitorProfileTabLoadStatus.failed && !retry)) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingLocket = true;
        _locketStatus = VisitorProfileTabLoadStatus.loading;
      });
    }
    Future<List<SocialPost>>? request;
    try {
      request = _socialService.fetchLocketFeedPage(widget.targetHouseId);
      _locketRequest = request;
      final posts = await request.timeout(const Duration(seconds: 12));
      final isMe = _canEditProfile;
      if (!mounted) return;
      setState(() {
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
        _locketStatus = VisitorProfileTabLoadStatus.loaded;
      });
    } catch (e) {
      debugPrint(
        'Error loading locket posts: ${AppErrorMapper.resolve(e).message}',
      );
      if (mounted) {
        setState(() => _locketStatus = VisitorProfileTabLoadStatus.failed);
      }
    } finally {
      if (identical(_locketRequest, request)) _locketRequest = null;
      if (mounted) setState(() => _isLoadingLocket = false);
    }
  }

  Future<void> _loadLikedPosts({bool retry = false}) async {
    if (_likedRequest != null) return;
    if (_likedStatus == VisitorProfileTabLoadStatus.loading ||
        (_likedStatus == VisitorProfileTabLoadStatus.loaded && !retry) ||
        (_likedStatus == VisitorProfileTabLoadStatus.failed && !retry)) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingLiked = true;
        _likedStatus = VisitorProfileTabLoadStatus.loading;
      });
    }
    Future<List<SocialPost>>? request;
    try {
      request = _socialService.fetchLikedFeedPage(widget.targetHouseId);
      _likedRequest = request;
      final posts = await request.timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _likedPosts = posts;
        _likedStatus = VisitorProfileTabLoadStatus.loaded;
      });
    } catch (e) {
      debugPrint(
        'Error loading liked posts: ${AppErrorMapper.resolve(e).message}',
      );
      if (mounted) {
        setState(() => _likedStatus = VisitorProfileTabLoadStatus.failed);
      }
    } finally {
      if (identical(_likedRequest, request)) _likedRequest = null;
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
            backgroundColor: SLColors.paper,
            foregroundColor: SLColors.ink,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SLTheme.pageSystemOverlayStyle,
            elevation: 0,
            leading: widget.showBackButton
                ? IconButton(
                    icon: Container(
                      padding: SLSpacing.all8,
                      decoration: const BoxDecoration(
                        color: SLColors.paper,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: SLColors.ink,
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
    if (tab == 'repost' && _repostStatus == VisitorProfileTabLoadStatus.idle) {
      unawaited(_loadReposts());
    }
    if (tab == 'private' &&
        _privateStatus == VisitorProfileTabLoadStatus.idle) {
      unawaited(_loadPrivatePosts());
    }
    if (tab == 'locket' && _locketStatus == VisitorProfileTabLoadStatus.idle) {
      unawaited(_loadLocketPosts());
    }
    if (tab == 'liked' && _likedStatus == VisitorProfileTabLoadStatus.idle) {
      unawaited(_loadLikedPosts());
    }
  }

  Map<String, VisitorProfileTabContentData> _tabContentById() {
    return {
      'posts': VisitorProfileTabContentData(
        isLoading: _postsStatus == VisitorProfileTabLoadStatus.loading,
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
    final loadStatus = switch (_activeTab) {
      'locket' => _locketStatus,
      'repost' => _repostStatus,
      'private' => _privateStatus,
      'liked' => _likedStatus,
      _ => _postsStatus,
    };
    return buildVisitorProfileTabContentSlivers(
      activeTab: _activeTab,
      tabContent: _tabContentById(),
      buildPostThumb: _buildPostThumb,
      onOpenPost: _openTabFeed,
      loadStatus: loadStatus,
      errorText: context.tr('runtime_error_retry'),
      retryText: context.tr('p5_retry'),
      onRetry: () {
        if (_activeTab == 'posts') unawaited(_loadPosts());
        if (_activeTab == 'locket') unawaited(_loadLocketPosts(retry: true));
        if (_activeTab == 'repost') unawaited(_loadReposts(retry: true));
        if (_activeTab == 'private') unawaited(_loadPrivatePosts(retry: true));
        if (_activeTab == 'liked') unawaited(_loadLikedPosts(retry: true));
      },
    );
  }

  void _openTabFeed(int index, VisitorProfileTabContentData data) {
    slPush<void>(
      context,
      ShortVideoFeedScreen(
        houseId: _myHouseId ?? widget.targetHouseId,
        targetHouseId: widget.targetHouseId,
        filterType: data.filterType,
        initialIndex: index,
        initialPosts: data.posts,
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
      SLSnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,

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
