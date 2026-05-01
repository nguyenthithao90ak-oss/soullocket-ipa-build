// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../services/single_match_service.dart';
import 'settings/sections/community_settings_hero_section.dart';
import 'settings/sections/community_settings_interaction_section.dart';
import 'settings/sections/community_settings_privacy_section.dart';
import 'settings/sections/community_settings_profile_section.dart';
import 'settings/sections/community_settings_safety_section.dart';
import 'settings/sections/community_settings_tools_section.dart';
import 'settings/sections/community_settings_unsaved_banner.dart';
import '../../utils/sl_notice.dart';
import '../utilities/block_list_screen.dart';
import 'house_qr_screen.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final String houseId;

  const CommunitySettingsScreen({
    super.key,
    required this.houseId,
  });

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isLoading = true;

  String _houseName = '';
  String _username = '';
  String _bio = '';
  String _privacy = 'public';
  int _friendRequestLimit = 30;
  String _likedVisibility = 'private';
  String _locketVisibility = 'private';
  String _highlightSort = 'date_desc';
  String _friendRequestPolicy = 'all';
  String _commentPolicy = 'all';

  bool _keywordFilter = true;
  bool _searchPrivacy = true;
  bool _msgPrivacy = false;
  bool _hideActiveStatus = false;
  bool _hideLikeCount = false;
  bool _taggingPolicy = false;
  bool _allowDownload = true;
  bool _dndMode = false;
  bool _showCreationDate = true;

  String _avatarUrl = '';
  String _headerImageUrl = '';
  String _headerThemeKey = 'soft_default';

  String _origHouseName = '';
  String _origUsername = '';
  String _origBio = '';
  String _origPrivacy = 'public';
  int _origFriendRequestLimit = 30;
  String _origLikedVisibility = 'private';
  String _origLocketVisibility = 'private';
  String _origHighlightSort = 'date_desc';
  String _origFriendRequestPolicy = 'all';
  String _origCommentPolicy = 'all';
  bool _origKeywordFilter = true;
  bool _origSearchPrivacy = true;
  bool _origMsgPrivacy = false;
  bool _origHideActiveStatus = false;
  bool _origHideLikeCount = false;
  bool _origTaggingPolicy = false;
  bool _origAllowDownload = true;
  bool _origDndMode = false;
  bool _origShowCreationDate = true;

  int? _lastUsernameUpdate;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onDraftChanged);
    _usernameController.addListener(_onDraftChanged);
    _bioController.addListener(_onDraftChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onDraftChanged);
    _usernameController.removeListener(_onDraftChanged);
    _bioController.removeListener(_onDraftChanged);
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    try {
      final snap = await _dbRef.child('houses/${widget.houseId}').get();
      if (!mounted) return;

      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(snap.value as Map),
        );
        final settings = data['settings'] is Map
            ? Map<String, dynamic>.from(
                Map<dynamic, dynamic>.from(data['settings'] as Map),
              )
            : <String, dynamic>{};

        setState(() {
          _houseName = data['houseName']?.toString().trim() ?? '';
          _username = (data['username'] ?? settings['username'] ?? '')
              .toString()
              .trim();
          _bio = settings['bio']?.toString().trim() ?? '';
          _lastUsernameUpdate = settings['lastUsernameUpdate'] is int
              ? settings['lastUsernameUpdate'] as int
              : null;

          _privacy = settings['privacy']?.toString() ?? 'public';
          _friendRequestLimit = int.tryParse(
                  settings['friendRequestLimit']?.toString() ?? '30') ??
              30;
          _likedVisibility =
              settings['likedVisibility']?.toString() ?? 'private';
          _locketVisibility =
              settings['locketVisibility']?.toString() ?? 'private';
          _highlightSort = settings['highlightSort']?.toString() ?? 'date_desc';
          _friendRequestPolicy =
              settings['friendRequestPolicy']?.toString() ?? 'all';
          _commentPolicy = settings['commentPolicy']?.toString() ?? 'all';

          _keywordFilter = settings['keywordFilter'] == true;
          _searchPrivacy = settings['searchPrivacy'] != false;
          _msgPrivacy = settings['msgPrivacy'] == true;
          _hideActiveStatus = settings['hideActiveStatus'] == true;
          _hideLikeCount = settings['hideLikeCount'] == true;
          _taggingPolicy = settings['taggingPolicy'] == true;
          _allowDownload = settings['allowDownload'] != false;
          _dndMode = settings['dndMode'] == true;
          _showCreationDate = settings['showCreationDate'] != false;

          _avatarUrl = (settings['houseAvatar'] ??
                  data['houseAvatar'] ??
                  data['avatar'] ??
                  '')
              .toString()
              .trim();
          _headerImageUrl = (settings['profileHeaderImageUrl'] ??
                  data['profileHeaderImageUrl'] ??
                  '')
              .toString()
              .trim();
          _headerThemeKey = ((settings['profileHeaderThemeKey'] ??
                      data['profileHeaderThemeKey']) ??
                  'soft_default')
              .toString()
              .trim();

          _nameController.text = _houseName;
          _usernameController.text = _username;
          _bioController.text = _bio;

          _origHouseName = _houseName;
          _origUsername = _username;
          _origBio = _bio;
          _origPrivacy = _privacy;
          _origFriendRequestLimit = _friendRequestLimit;
          _origLikedVisibility = _likedVisibility;
          _origLocketVisibility = _locketVisibility;
          _origHighlightSort = _highlightSort;
          _origFriendRequestPolicy = _friendRequestPolicy;
          _origCommentPolicy = _commentPolicy;
          _origKeywordFilter = _keywordFilter;
          _origSearchPrivacy = _searchPrivacy;
          _origMsgPrivacy = _msgPrivacy;
          _origHideActiveStatus = _hideActiveStatus;
          _origHideLikeCount = _hideLikeCount;
          _origTaggingPolicy = _taggingPolicy;
          _origAllowDownload = _allowDownload;
          _origDndMode = _dndMode;
          _origShowCreationDate = _showCreationDate;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading community settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _hasChanges() {
    if (_isLoading) return false;

    return _nameController.text.trim() != _origHouseName ||
        _normalizedUsername != _origUsername ||
        _bioController.text.trim() != _origBio ||
        _privacy != _origPrivacy ||
        _friendRequestLimit != _origFriendRequestLimit ||
        _likedVisibility != _origLikedVisibility ||
        _locketVisibility != _origLocketVisibility ||
        _highlightSort != _origHighlightSort ||
        _friendRequestPolicy != _origFriendRequestPolicy ||
        _commentPolicy != _origCommentPolicy ||
        _keywordFilter != _origKeywordFilter ||
        _searchPrivacy != _origSearchPrivacy ||
        _msgPrivacy != _origMsgPrivacy ||
        _hideActiveStatus != _origHideActiveStatus ||
        _hideLikeCount != _origHideLikeCount ||
        _taggingPolicy != _origTaggingPolicy ||
        _allowDownload != _origAllowDownload ||
        _dndMode != _origDndMode ||
        _showCreationDate != _origShowCreationDate;
  }

  String get _normalizedUsername => _usernameController.text
      .trim()
      .replaceAll('@', '')
      .replaceAll(' ', '')
      .toLowerCase();

  String get _previewName => _nameController.text.trim().isNotEmpty
      ? _nameController.text.trim()
      : 'Nhà chưa đặt tên';

  String get _previewHandle =>
      _normalizedUsername.isNotEmpty ? '@$_normalizedUsername' : '@username';

  String get _previewBio => _bioController.text.trim().isNotEmpty
      ? _bioController.text.trim()
      : 'Thêm tiểu sử để hồ sơ cộng đồng nhìn rõ câu chuyện và cá tính hơn.';

  int get _profileCompletion {
    var score = 0;
    if (_nameController.text.trim().isNotEmpty) score++;
    if (_normalizedUsername.isNotEmpty) score++;
    if (_bioController.text.trim().isNotEmpty) score++;
    if (_avatarUrl.isNotEmpty) score++;
    if (_headerImageUrl.isNotEmpty) score++;
    return ((score / 5) * 100).round();
  }

  String _privacyLabel(String value) {
    switch (value) {
      case 'friends':
        return 'Chỉ bạn bè';
      case 'private':
        return 'Chỉ hai người';
      case 'public':
      default:
        return 'Công khai';
    }
  }

  String _visibilityLabel(String value) {
    switch (value) {
      case 'public':
        return 'Công khai';
      case 'private':
      default:
        return 'Ẩn với người khác';
    }
  }

  String _friendRequestPolicyLabel(String value) {
    switch (value) {
      case 'mutual':
        return 'Chỉ bạn chung';
      case 'none':
        return 'Tắt lời mời';
      case 'all':
      default:
        return 'Mọi người';
    }
  }

  String _commentPolicyLabel(String value) {
    switch (value) {
      case 'friends':
        return 'Chỉ bạn bè';
      case 'none':
        return 'Tắt bình luận';
      case 'all':
      default:
        return 'Mọi người';
    }
  }

  String _friendLimitLabel() {
    final safeLimit = _friendRequestLimit <= 0 ? 30 : _friendRequestLimit;
    return 'Tối đa $safeLimit bạn';
  }

  String _headerThemeLabel() {
    switch (_headerThemeKey) {
      case 'rose_blush':
        return 'Hồng dịu';
      case 'sunset_glow':
        return 'Hoàng hôn';
      case 'ocean_breeze':
        return 'Biển mát';
      case 'mint_cloud':
        return 'Mint sáng';
      case 'midnight_velvet':
        return 'Đêm êm';
      case 'soft_default':
      default:
        return 'Mặc định';
    }
  }

  List<Color> _headerThemeColors() {
    switch (_headerThemeKey) {
      case 'rose_blush':
        return const [
          Color(0xFFE5719C),
          Color(0xFFCF4D80),
          Color(0xFF8A0D54),
        ];
      case 'sunset_glow':
        return const [
          Color(0xFFFFA76B),
          Color(0xFFF06292),
          Color(0xFF8B1E5A),
        ];
      case 'ocean_breeze':
        return const [
          Color(0xFF59C1FF),
          Color(0xFF3282F6),
          Color(0xFF0B4F9F),
        ];
      case 'mint_cloud':
        return const [
          Color(0xFF7ED7C1),
          Color(0xFF3AB49A),
          Color(0xFF136F63),
        ];
      case 'midnight_velvet':
        return const [
          Color(0xFF445173),
          Color(0xFF28324F),
          Color(0xFF12192B),
        ];
      case 'soft_default':
      default:
        return const [
          Color(0xFFD97996),
          Color(0xFF8C6EA6),
          Color(0xFF4B5E86),
        ];
    }
  }

  String _renameRuleText() {
    if (_lastUsernameUpdate == null) {
      return 'Tên nhà và username có thể chỉnh ngay. Sau mỗi lần đổi, hệ thống sẽ khóa 7 ngày để hồ sơ ổn định hơn.';
    }

    final nextAllowed = DateTime.fromMillisecondsSinceEpoch(
      _lastUsernameUpdate!,
    ).add(const Duration(days: 7));
    final remaining = nextAllowed.difference(DateTime.now());

    if (remaining.isNegative) {
      return 'Bạn đã qua mốc 7 ngày. Có thể đổi tên nhà và username nếu cần.';
    }

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    if (days > 0) {
      return 'Bạn có thể đổi lại sau $days ngày${hours > 0 ? ' $hours giờ' : ''}.';
    }
    return 'Bạn có thể đổi lại sau ${remaining.inHours} giờ.';
  }

  String _avatarInitials() {
    final raw = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _normalizedUsername;
    final tokens =
        raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    if (tokens.length >= 2) {
      return '${tokens.first.substring(0, 1)}${tokens.last.substring(0, 1)}'
          .toUpperCase();
    }
    if (tokens.isNotEmpty) {
      final token = tokens.first;
      return token.length >= 2
          ? token.substring(0, 2).toUpperCase()
          : token.toUpperCase();
    }
    return 'IN';
  }

  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();

    if (!_hasChanges()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có thay đổi nào để lưu.')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final username = _normalizedUsername;
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên nhà không được để trống.')),
      );
      return;
    }

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username không được để trống.')),
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final isNameChanged = name != _houseName || username != _username;
    if (isNameChanged && _lastUsernameUpdate != null) {
      final diff = now - _lastUsernameUpdate!;
      if (diff < 7 * 24 * 60 * 60 * 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_renameRuleText())),
        );
        return;
      }
    }

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{
        'houses/${widget.houseId}/houseName': name,
        'houses/${widget.houseId}/username': username,
        'houses/${widget.houseId}/settings/username': username,
        if (isNameChanged)
          'houses/${widget.houseId}/settings/lastUsernameUpdate':
              ServerValue.timestamp,
        'houses/${widget.houseId}/settings/bio': bio,
        'houses/${widget.houseId}/settings/privacy': _privacy,
        'houses/${widget.houseId}/settings/friendRequestLimit':
            _friendRequestLimit,
        'houses/${widget.houseId}/settings/friendRequestPolicy':
            _friendRequestPolicy,
        'houses/${widget.houseId}/settings/commentPolicy': _commentPolicy,
        'houses/${widget.houseId}/settings/likedVisibility': _likedVisibility,
        'houses/${widget.houseId}/settings/locketVisibility': _locketVisibility,
        'houses/${widget.houseId}/settings/highlightSort': _highlightSort,
        'houses/${widget.houseId}/settings/keywordFilter': _keywordFilter,
        'houses/${widget.houseId}/settings/searchPrivacy': _searchPrivacy,
        'houses/${widget.houseId}/settings/msgPrivacy': _msgPrivacy,
        'houses/${widget.houseId}/settings/hideActiveStatus': _hideActiveStatus,
        'houses/${widget.houseId}/settings/hideLikeCount': _hideLikeCount,
        'houses/${widget.houseId}/settings/taggingPolicy': _taggingPolicy,
        'houses/${widget.houseId}/settings/allowDownload': _allowDownload,
        'houses/${widget.houseId}/settings/dndMode': _dndMode,
        'houses/${widget.houseId}/settings/showCreationDate': _showCreationDate,
        'house_profiles/${widget.houseId}/houseName': name,
        'house_profiles/${widget.houseId}/username': username,
        'house_profiles/${widget.houseId}/settings/username': username,
        'house_profiles/${widget.houseId}/settings/bio': bio,
        'house_profiles/${widget.houseId}/settings/privacy': _privacy,
        'house_profiles/${widget.houseId}/settings/searchPrivacy':
            _searchPrivacy,
        'house_profiles/${widget.houseId}/settings/hideActiveStatus':
            _hideActiveStatus,
        'house_profiles/${widget.houseId}/settings/hideLikeCount':
            _hideLikeCount,
        'houses_public/${widget.houseId}/houseName': name,
        'houses_public/${widget.houseId}/username': username,
        'houses_public/${widget.houseId}/settings/username': username,
        'houses_public/${widget.houseId}/settings/bio': bio,
        'houses_public/${widget.houseId}/settings/privacy': _privacy,
        'houses_public/${widget.houseId}/settings/hideActiveStatus':
            _hideActiveStatus,
        ...SingleMatchService.profileIndexUpdates(
          houseId: widget.houseId,
          houseName: name,
          bio: bio,
          privacy: _privacy,
          searchPrivacy: _searchPrivacy,
          updatedAt: nowMs,
        ),
      };

      await _dbRef.update(updates);
      if (!mounted) return;
      Navigator.of(context).pop();
      SLNotice.showSuccess(context, 'Đã lưu cài đặt cộng đồng.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      SLNotice.showError(
          context, 'Chưa thể lưu cài đặt cộng đồng lúc này. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = _hasChanges();
    const sectionDivider = Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFE7ECF4),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: SLColors.textPrimary),
        title: Text(
          'Cài đặt cộng đồng',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            color: SLColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: (_isLoading || !hasChanges) ? null : _saveSettings,
              style: TextButton.styleFrom(
                backgroundColor: (_isLoading || !hasChanges)
                    ? const Color(0xFFF1F3F8)
                    : const Color(0xFFFFE3EC),
                foregroundColor: (_isLoading || !hasChanges)
                    ? const Color(0xFF94A3B8)
                    : SLColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Lưu',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 16, bottom: 40),
              children: [
                if (hasChanges) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CommunitySettingsUnsavedBanner(),
                  ),
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CommunitySettingsHeroSection(
                    headerThemeColors: _headerThemeColors(),
                    headerImageUrl: _headerImageUrl,
                    privacyLabel: _privacyLabel(_privacy),
                    headerThemeLabel: _headerThemeLabel(),
                    searchPrivacy: _searchPrivacy,
                    profileCompletion: _profileCompletion,
                    previewName: _previewName,
                    previewHandle: _previewHandle,
                    previewBio: _previewBio,
                    avatarUrl: _avatarUrl,
                    avatarInitials: _avatarInitials(),
                    friendLimitLabel: _friendLimitLabel(),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CommunitySettingsProfileSection(
                    nameController: _nameController,
                    usernameController: _usernameController,
                    bioController: _bioController,
                    avatarUrl: _avatarUrl,
                    headerImageUrl: _headerImageUrl,
                    headerThemeLabel: _headerThemeLabel(),
                    previewHandle: _previewHandle,
                    renameRuleText: _renameRuleText(),
                  ),
                ),
                const SizedBox(height: 24),
                sectionDivider,
                CommunitySettingsPrivacySection(
                  privacy: _privacy,
                  privacyLabel: _privacyLabel(_privacy),
                  likedVisibility: _likedVisibility,
                  likedVisibilityLabel: _visibilityLabel(_likedVisibility),
                  locketVisibility: _locketVisibility,
                  locketVisibilityLabel: _visibilityLabel(_locketVisibility),
                  highlightSort: _highlightSort,
                  allowDownload: _allowDownload,
                  showCreationDate: _showCreationDate,
                  hideLikeCount: _hideLikeCount,
                  onPrivacyChanged: (value) {
                    if (value == null) return;
                    setState(() => _privacy = value);
                  },
                  onLikedVisibilityChanged: (value) {
                    if (value == null) return;
                    setState(() => _likedVisibility = value);
                  },
                  onLocketVisibilityChanged: (value) {
                    if (value == null) return;
                    setState(() => _locketVisibility = value);
                  },
                  onHighlightSortChanged: (value) {
                    if (value == null) return;
                    setState(() => _highlightSort = value);
                  },
                  onAllowDownloadChanged: (value) {
                    setState(() => _allowDownload = value);
                  },
                  onShowCreationDateChanged: (value) {
                    setState(() => _showCreationDate = value);
                  },
                  onHideLikeCountChanged: (value) {
                    setState(() => _hideLikeCount = value);
                  },
                ),
                sectionDivider,
                CommunitySettingsInteractionSection(
                  searchPrivacy: _searchPrivacy,
                  friendRequestPolicy: _friendRequestPolicy,
                  friendRequestPolicyLabel:
                      _friendRequestPolicyLabel(_friendRequestPolicy),
                  commentPolicy: _commentPolicy,
                  commentPolicyLabel: _commentPolicyLabel(_commentPolicy),
                  msgPrivacy: _msgPrivacy,
                  friendRequestLimit: _friendRequestLimit,
                  taggingPolicy: _taggingPolicy,
                  onSearchPrivacyChanged: (value) {
                    setState(() => _searchPrivacy = value);
                  },
                  onFriendRequestPolicyChanged: (value) {
                    if (value == null) return;
                    setState(() => _friendRequestPolicy = value);
                  },
                  onCommentPolicyChanged: (value) {
                    if (value == null) return;
                    setState(() => _commentPolicy = value);
                  },
                  onFriendRequestLimitChanged: (value) {
                    if (value == null) return;
                    setState(() => _friendRequestLimit = int.parse(value));
                  },
                  onMsgPrivacyChanged: (value) {
                    setState(() => _msgPrivacy = value);
                  },
                  onTaggingPolicyChanged: (value) {
                    setState(() => _taggingPolicy = value);
                  },
                ),
                sectionDivider,
                CommunitySettingsSafetySection(
                  keywordFilter: _keywordFilter,
                  hideActiveStatus: _hideActiveStatus,
                  dndMode: _dndMode,
                  onKeywordFilterChanged: (value) {
                    setState(() => _keywordFilter = value);
                  },
                  onHideActiveStatusChanged: (value) {
                    setState(() => _hideActiveStatus = value);
                  },
                  onDndModeChanged: (value) {
                    setState(() => _dndMode = value);
                  },
                ),
                sectionDivider,
                CommunitySettingsToolsSection(
                  searchPrivacy: _searchPrivacy,
                  dndMode: _dndMode,
                  onOpenQr: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HouseQRScreen(houseId: widget.houseId),
                      ),
                    );
                  },
                  onOpenBlockList: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BlockListScreen(),
                      ),
                    );
                  },
                  onToggleSearchPrivacy: () {
                    setState(() => _searchPrivacy = !_searchPrivacy);
                  },
                  onToggleDndMode: () {
                    setState(() => _dndMode = !_dndMode);
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
