// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:async';
import '../../../widgets/share_bottom_sheet.dart';

import '../../../core/sl_theme.dart';
import '../../../core/sl_route.dart';
import '../../../services/admob_service.dart';

import '../../../services/friends_service.dart';
import '../../../services/house_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/social_service.dart';
import '../../../utils/services/chat_service.dart';
import '../../../widgets/legacy_web_ui.dart';
import '../../../widgets/manual_retry_cached_image.dart';
// import '../widgets/story_bar.dart'; // Removed StoryBar
import '../../notifications/notification_center_screen.dart';
import '../../chat/messenger_screen.dart';
import '../../visitors/friends_management_screen.dart';
import '../../visitors/visitor_profile_screen.dart';
import '../../community/top_hot_screen.dart';
import '../../community/community_settings_screen.dart';
import '../../community/house_qr_screen.dart';
import '../../../services/offline_cache_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../utils/services/community_feed_service.dart';
import '../../../utils/services/pending_upload_service.dart';
import '../../../utils/sl_notice.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../services/security_service.dart';
import 'package:flutter/gestures.dart';
import '../screens/locket_camera_screen.dart';
import '../../../services/l10n_service.dart';
import '../../ui_prefs.dart';
import 'community/rich_post_text_parser.dart';

part 'community/community_tab_config.dart';
part 'community/community_text_policy.dart';
part 'community_tab_rich_post_text.dart';
part 'community_tab_animations.dart';
part 'community_tab_comments_sheet.dart';
part 'community_tab_feed_logic.dart';
part 'community_tab_composer.dart';
part 'community_tab_interactions.dart';
part 'community_tab_locket.dart';
part 'community/community_feed_selector_config.dart';
part 'community/feed/community_feed_states.dart';
part 'community/feed/community_feed_surface.dart';
part 'community/widgets/community_feed_composer.dart';
part 'community/widgets/community_feed_filter_bar.dart';
part 'community/widgets/community_feed_header.dart';
part 'community/widgets/community_feed_post_actions.dart';
part 'community/widgets/community_feed_post_header.dart';
part 'community/widgets/community_feed_post_media.dart';
part 'community_tab_feed_widgets.dart';
part 'community_tab_search_screen.dart';

String _communityPrivacyLabel(String value) {
  switch (value) {
    case 'private':
      return L10nService().translate('home_ringt_03b49a');
    case 'friends':
      return L10nService().translate('home_bnb_411da0');
    default:
      return L10nService().translate('home_cngkhai_c7e9f6');
  }
}

IconData _communityPrivacyIcon(String value) {
  switch (value) {
    case 'private':
      return Icons.lock_rounded;
    case 'friends':
      return Icons.group_rounded;
    default:
      return Icons.public_rounded;
  }
}

Color _communityPrivacyColor(String value) {
  switch (value) {
    case 'private':
      return const Color(0xFF7C3AED);
    case 'friends':
      return const Color(0xFF2563EB);
    default:
      return const Color(0xFFD81B60);
  }
}

class CommunityRulesCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool compact;

  const CommunityRulesCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.gavel_rounded,
    this.accent = LegacyWebUi.accentPink,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = compact ? 22 : 24;
    return Container(
      width: double.infinity,
      padding: SLSpacing.all16,
      decoration: LegacyWebUi.softPanelDecoration(
        accent: accent,
        radius: radius,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.98),
          Color.lerp(accent, Colors.white, 0.93) ?? Colors.white,
          Colors.white.withValues(alpha: 0.98),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (false)
                Container(
                  width: compact ? 38 : 42,
                  height: compact ? 38 : 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        accent.withValues(alpha: 0.18),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: SLRadius.mdAll,
                    border: Border.all(color: accent.withValues(alpha: 0.16)),
                  ),
                  child: Icon(icon, color: accent, size: compact ? 18 : 20),
                ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTypography.labelLarge.copyWith(
                        fontSize: compact ? 13.5 : 14.5,
                        color: accent,
                      ),
                    ),
                    SLSpacing.gapH(2),
                    Text(
                      subtitle,
                      style: SLTypography.bodySmall.copyWith(
                        fontSize: compact ? 11.5 : 12.2,
                        color: const Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          ..._communityGuidelines().map(
            (item) => Padding(
              padding: SLSpacing.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: SLSpacing.only(top: SLSpacing.xxs),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: accent.withValues(alpha: 0.75),
                    ),
                  ),
                  SLSpacing.w8,
                  Expanded(
                    child: Text(
                      item,
                      style: SLTypography.bodySmall.copyWith(
                        fontSize: compact ? 11.5 : 12.3,
                        color: Colors.grey[400],
                        height: 1.4,
                      ),
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
}

class CommunityTab extends StatefulWidget {
  final bool isActive;

  const CommunityTab({
    super.key,
    this.isActive = true,
  });

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab>
    with TickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();
  final StorageService _storageService = StorageService();
  final SocialService _socialService = SocialService();

  bool _isCommunityMaintenance = false;
  String _communityMaintenanceMsg = L10nService().translate('home_tnhnngmngx_a56b2f');
  String _communityMaintenanceEta = '';
  StreamSubscription? _communityMaintenanceSub;
  bool _isInitialized = false;

  bool _isLoading = true;
  String _currentFeedType = 'foryou';
  bool _isFeedSelectorExpanded = false;

  String? _houseId;
  String get _defaultHouseName => context.tr('home_nginhndanh_500dbb');
  String _houseName = '';
  String _houseAvatar = 'light';

  final String _communityTheme = 'light';
  bool get _isLight => _communityTheme == 'light';
  bool get _isDark => _communityTheme == 'dark';
  Color get _bgColor => _isLight
      ? const Color(0xFFF0F2F5)
      : (_isDark ? Colors.black : const Color(0xFF18191A));
  Color get _cardColor => _isLight
      ? Colors.white
      : (_isDark ? const Color(0xFF121212) : const Color(0xFF242526));
  Color get _textColor => _isLight ? const Color(0xFF1C1E21) : Colors.white;
  Color get _subTextColor =>
      _isLight ? const Color(0xFF65676B) : Colors.grey[400]!;
  Color get _actionBgColor =>
      _isLight ? const Color(0xFFF0F2F5) : const Color(0xFF3A3B3C);
  Color get _borderColor => _isLight ? const Color(0xFFE4E6EB) : Colors.white12;
  Color get _headerColor => _isLight
      ? Colors.white
      : (_isDark ? const Color(0xFF121212) : const Color(0xFF18191A));
  Map<String, dynamic> _houseSettings = {};
  bool _didPromptPendingCommunityUploadRetry = false;

  String _resolveCommunityAvatarThemeKey(String themeKey) {
    final key = themeKey.trim();
    if (key.isEmpty) return '';
    if (key != 'theme-auto') return key;

    final now = DateTime.now();
    final isNight = now.hour >= 19 || now.hour < 6;
    if (isNight) return 'theme-night';

    switch (now.month) {
      case 12:
      case 1:
      case 2:
        return 'theme-pink-glow';
      case 6:
      case 7:
      case 8:
        return 'theme-ocean';
      case 9:
      case 10:
      case 11:
        return 'theme-sunset';
      default:
        return 'theme-default';
    }
  }

  List<Color>? _communityAvatarRingColors(UiPrefsState uiState) {
    final resolvedThemeKey =
        _resolveCommunityAvatarThemeKey(uiState.themeKey).trim();
    if (resolvedThemeKey.isEmpty ||
        resolvedThemeKey == 'off' ||
        resolvedThemeKey == 'theme-default' ||
        resolvedThemeKey == UiPrefsState.defaults.themeKey) {
      return null;
    }

    switch (resolvedThemeKey) {
      case 'theme-night':
        return const [Color(0xFF31466F), Color(0xFF7E74FF)];
      case 'theme-dark':
        return const [Color(0xFF404040), Color(0xFF8B8B8B)];
      case 'theme-true-black':
        return const [Color(0xFF262626), Color(0xFF737373)];
      case 'theme-mystic-dark':
        return const [Color(0xFF3F3785), Color(0xFF9A73FF)];
      case 'theme-ocean':
        return const [Color(0xFF4FACFE), Color(0xFF38F9D7)];
      case 'theme-sunset':
        return const [Color(0xFFFF8A65), Color(0xFFFEE140)];
      case 'theme-crazy-party':
        return const [Color(0xFFFF5A5F), Color(0xFF6A5CFF)];
      default:
        return null;
    }
  }

  Widget _buildCommunityAuthorAvatar({
    required String avatarUrl,
    required bool isAnon,
    bool disableThemedBorder = false,
    double radius = 20,
  }) {
    final ImageProvider<Object>? avatarProvider =
        avatarUrl.isNotEmpty && !isAnon
            ? ResizeImage.resizeIfNeeded(
                (radius * 4).round(),
                (radius * 4).round(),
                CachedNetworkImageProvider(avatarUrl),
              )
            : null;
    final avatarCore = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[100],
      backgroundImage: avatarProvider,
      child: avatarUrl.isEmpty || isAnon
          ? Icon(
              isAnon ? Icons.visibility_off_rounded : Icons.person_rounded,
              color: isAnon ? const Color(0xFFD81B60) : Colors.grey,
              size: radius + 1,
            )
          : null,
    );

    if (isAnon || disableThemedBorder) return avatarCore;

    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      child: avatarCore,
      builder: (context, uiState, child) {
        final ringColors = _communityAvatarRingColors(uiState);
        if (ringColors == null) {
          return child!;
        }

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: ringColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cardColor,
            ),
            padding: const EdgeInsets.all(1),
            child: child,
          ),
        );
      },
    );
  }

  Timer? _sessionTimer;
  final _adMob = AdMobService();
  final FriendsService _friendsService = FriendsService();
  bool _isCheckingAd = false;
  DateTime? _communityUsageStartedAt;

  Map<String, dynamic> _friends = {};
  Map<String, dynamic> _blockedUsers = {};
  Map<String, String> _sentFriendRequestIds = <String, String>{};
  Map<String, String> _receivedFriendRequestIds = <String, String>{};
  List<Map<String, dynamic>> _allPosts = [];
  final Map<String, int> _feedIndexById = <String, int>{};
  List<Map<String, dynamic>>? _filteredPostsCache;
  String? _filteredPostsCacheKey;
  final Map<String, String> _postFormattedDateCache = <String, String>{};
  final Map<String, String> _postSanitizedTextCache = <String, String>{};
  int _feedRevision = 0;
  Set<String> _bookmarkedPostIds = <String>{};
  Set<String> _hiddenPostIds = <String>{};
  int _friendsRevision = 0;
  int _blockedUsersRevision = 0;
  int _hiddenPostsRevision = 0;
  int _friendRequestsRevision = 0;
  final Set<String> _pendingLikePostIds = <String>{};
  final Map<String, int> _likeSyncHoldUntilByPostId = <String, int>{};
  static List<Map<String, String>> get _composerMoodPresets => [
        {'emoji': '😊', 'label': L10nService().translate('home_vuiv_2d8b13')},
        {'emoji': '😍', 'label': L10nService().translate('home_yui_b139a4')},
        {'emoji': '🥰', 'label': L10nService().translate('home_ngtngo_5da115')},
        {'emoji': '😌', 'label': L10nService().translate('home_bnhyn_325c26')},
        {'emoji': '😴', 'label': L10nService().translate('home_mtnh_035761')},
        {'emoji': '😢', 'label': L10nService().translate('home_tms_418cf9')},
        {'emoji': '🔥', 'label': L10nService().translate('home_bngchy_a9de69')},
        {'emoji': '🤍', 'label': L10nService().translate('home_nhnhng_100576')},
      ];
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _friendsRequestSubscription;
  StreamSubscription? _blockedUsersSubscription;
  final ScrollController _scrollController = ScrollController();
  int _lastFeedPreloadStartIndex = -1;
  int _currentLimit = 30;
  int? _oldestLoadedTs;
  static const int _feedPageSize = 20;
  static const int _feedPreloadMinIndexDelta = 8;
  static const Duration _feedPreloadThrottleDelay = Duration(milliseconds: 250);
  static const Duration _feedCachePersistDelay = Duration(milliseconds: 350);
  static const Duration _likeSyncHoldDuration = Duration(seconds: 4);
  static const double _feedLoadMoreThreshold = 480;
  bool _isLoadingMoreFeed = false;
  bool _hasMoreFeed = true;
  StreamSubscription? _feedSub;
  Timer? _feedCachePersistTimer;
  Timer? _feedPreloadThrottleTimer;
  Timer? _communityMessengerButtonPersistTimer;
  Timer? _friendsDebounce;
  Timer? _blockedUsersDebounce;
  StreamSubscription? _communityMessengerPreviewSubscription;
  int _communityMessengerUnreadCount = 0;
  String _communityMessengerPreviewText = '';
  late AnimationController _heartController;
  final List<HeartAnimation> _hearts = <HeartAnimation>[];
  final List<EmojiReactionAnimation> _reactionAnimations = <EmojiReactionAnimation>[];
  bool _isHeartTickerActive = false;

  Offset? _communityMessengerButtonOffset;

  static const Size _communityMessengerButtonSize = Size(64, 74);
  static const double _communityMessengerButtonMargin = 14;

  void _ensureHeartTickerRunning() {
    if (_isHeartTickerActive ||
        (_hearts.isEmpty && _reactionAnimations.isEmpty)) {
      return;
    }
    _isHeartTickerActive = true;
    _heartController.repeat();
  }

  void _stopHeartTickerIfIdle() {
    if (!_isHeartTickerActive ||
        _hearts.isNotEmpty ||
        _reactionAnimations.isNotEmpty) {
      return;
    }
    _isHeartTickerActive = false;
    _heartController.stop();
  }

  void _cancelFeedFilterSubscriptions() {
    _friendsSubscription?.cancel();
    _friendsSubscription = null;
    _friendsRequestSubscription?.cancel();
    _friendsRequestSubscription = null;
    _blockedUsersSubscription?.cancel();
    _blockedUsersSubscription = null;
    _friendsDebounce?.cancel();
    _friendsDebounce = null;
    _blockedUsersDebounce?.cancel();
    _blockedUsersDebounce = null;
  }

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() {
        if (_hearts.isNotEmpty || _reactionAnimations.isNotEmpty) {
          _hearts.removeWhere((h) => h.isDone());
          for (var h in _hearts) {
            h.update();
          }
          _reactionAnimations.removeWhere((r) => r.isDone());
          for (var r in _reactionAnimations) {
            r.update();
          }
          _stopHeartTickerIfIdle();
        }
      });
    _scrollController.addListener(() {
      // ⚡ Trigger lazy preload when scrolling
      final preloadPosts = _filteredPostsCache ?? _filteredPosts();
      if (widget.isActive &&
          preloadPosts.isNotEmpty &&
          _scrollController.hasClients) {
        final position = _scrollController.position;
        final double maxExtent = position.maxScrollExtent;
        if (maxExtent > 0 && !position.outOfRange) {
          final scrollPercent =
              (position.pixels / maxExtent).clamp(0.0, 1.0).toDouble();
          final int currentIndex = (scrollPercent * preloadPosts.length)
              .floor()
              .clamp(0, preloadPosts.length - 1);
          if ((currentIndex - _lastFeedPreloadStartIndex).abs() >=
              _feedPreloadMinIndexDelta) {
            _lastFeedPreloadStartIndex = currentIndex;
            _feedPreloadThrottleTimer?.cancel();
            _feedPreloadThrottleTimer = Timer(
              _feedPreloadThrottleDelay,
              () {
                if (!mounted || !widget.isActive) return;
                CommunityFeedService().preloadMoreImages(
                  currentIndex,
                  preloadPosts,
                );
              },
            );
          }
        }
      }

      // Load more feed when reaching end
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - _feedLoadMoreThreshold) {
        if (!_isLoading && !_isLoadingMoreFeed && _hasMoreFeed) {
          _loadMoreFeed();
        }
      }
    });
    if (widget.isActive) {
      _activateTab();
    }
    unawaited(_restoreCommunityMessengerButtonOffset());
  }

  @override
  void dispose() {
    _deactivateTab();
    _feedCachePersistTimer?.cancel();
    _communityMessengerButtonPersistTimer?.cancel();
    _scrollController.dispose();
    _heartController.dispose();
    
    // Hủy trực tiếp StreamSubscriptions để thỏa mãn rule cancel_subscriptions
    _communityMaintenanceSub?.cancel();
    _friendsSubscription?.cancel();
    _friendsRequestSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    _feedSub?.cancel();
    _communityMessengerPreviewSubscription?.cancel();
    _friendsDebounce?.cancel();
    _blockedUsersDebounce?.cancel();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CommunityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) {
      return;
    }
    if (!widget.isActive) {
      _deactivateTab();
    } else {
      _activateTab();
    }
  }
  static int _adShowCount = 0;

  void _updateState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _restoreCommunityMessengerButtonOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble(_communityMessengerButtonOffsetXPrefsKey);
    final dy = prefs.getDouble(_communityMessengerButtonOffsetYPrefsKey);
    if (dx == null || dy == null || !mounted) {
      return;
    }
    setState(() {
      _communityMessengerButtonOffset = Offset(dx, dy);
    });
  }

  void _persistCommunityMessengerButtonOffset(Offset offset) {
    _communityMessengerButtonPersistTimer?.cancel();
    _communityMessengerButtonPersistTimer = Timer(
      const Duration(milliseconds: 180),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(
          _communityMessengerButtonOffsetXPrefsKey,
          offset.dx,
        );
        await prefs.setDouble(
          _communityMessengerButtonOffsetYPrefsKey,
          offset.dy,
        );
      },
    );
  }

  Offset _defaultCommunityMessengerButtonOffset(
    Size viewport,
    EdgeInsets safePadding,
  ) {
    final maxX = viewport.width -
        _communityMessengerButtonSize.width -
        _communityMessengerButtonMargin;
    final liftedBottom = math.max(safePadding.bottom + 108, 118).toDouble();
    final targetY =
        viewport.height - _communityMessengerButtonSize.height - liftedBottom;
    final minY = safePadding.top + 12;
    return Offset(
      maxX,
      math.max(minY, targetY).toDouble(),
    );
  }

  Offset _clampCommunityMessengerButtonOffset(
    Offset offset,
    Size viewport,
    EdgeInsets safePadding,
  ) {
    const minX = _communityMessengerButtonMargin;
    final maxX = math.max(
      minX,
      viewport.width -
          _communityMessengerButtonSize.width -
          _communityMessengerButtonMargin,
    );
    final minY = safePadding.top + 12;
    final maxY = math.max(
      minY,
      viewport.height -
          _communityMessengerButtonSize.height -
          math.max(safePadding.bottom + 14, 18).toDouble(),
    );
    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _listenCommunityMessengerPreview(String houseId) {
    _communityMessengerPreviewSubscription?.cancel();
    _communityMessengerPreviewSubscription =
        _dbRef.child('house_chat_rooms/$houseId').limitToLast(8).onValue.listen(
      (event) async {
        if (!mounted) return;
        final rawRooms = event.snapshot.value;
        if (rawRooms is! Map) {
          _updateState(() {
            _communityMessengerUnreadCount = 0;
            _communityMessengerPreviewText = '';
          });
          return;
        }

        final activeSubscription = _communityMessengerPreviewSubscription;
        final roomIds = rawRooms.keys
            .map((key) => key.toString().trim())
            .where((roomId) => roomId.isNotEmpty)
            .take(8)
            .toList(growable: false);
        if (roomIds.isEmpty) {
          _updateState(() {
            _communityMessengerUnreadCount = 0;
            _communityMessengerPreviewText = '';
          });
          return;
        }

        final snapshots = await Future.wait<DataSnapshot?>(
          roomIds.map((roomId) async {
            try {
              return await _dbRef.child('chats/$roomId/lastMessage').get();
            } catch (_) {
              return null;
            }
          }),
        );
        if (!mounted ||
            activeSubscription != _communityMessengerPreviewSubscription) {
          return;
        }

        var unread = 0;
        var latestTs = 0;
        var latestPreview = '';

        for (final snap in snapshots) {
          final value = snap?.value;
          if (value is! Map) continue;
          final lastMessage = Map<dynamic, dynamic>.from(value);
          final ts = readChatMetaTimestamp(lastMessage);
          final text = readChatMetaText(lastMessage);
          if (isChatMetaUnreadForHouse(
            lastMessage,
            viewerHouseId: houseId,
          )) {
            unread++;
          }
          if (ts >= latestTs && text.isNotEmpty) {
            latestTs = ts;
            latestPreview = text;
          }
        }

        _updateState(() {
          _communityMessengerUnreadCount = unread.clamp(0, 99).toInt();
          _communityMessengerPreviewText = latestPreview;
        });
      },
      onError: (Object error) {
        debugPrint(
          'Community messenger preview listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: context.tr('home_khngthtixe_2dfd82'),
          ).message}',
        );
      },
    );
  }

  Future<void> _openCommunityMessenger() async {
    if (!mounted) return;
    await slPush(
      context,
      const MessengerScreen(),
    );
  }

  Widget _buildCommunityMessengerButton() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final safePadding = MediaQuery.of(context).padding;
          final resolvedOffset = _clampCommunityMessengerButtonOffset(
            _communityMessengerButtonOffset ??
                _defaultCommunityMessengerButtonOffset(viewport, safePadding),
            viewport,
            safePadding,
          );

          return Stack(
            children: [
              Positioned(
                left: resolvedOffset.dx,
                top: resolvedOffset.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final current =
                        _communityMessengerButtonOffset ?? resolvedOffset;
                    final next = _clampCommunityMessengerButtonOffset(
                      current + details.delta,
                      viewport,
                      safePadding,
                    );
                    _updateState(() {
                      _communityMessengerButtonOffset = next;
                    });
                  },
                  onPanEnd: (_) {
                    final current =
                        _communityMessengerButtonOffset ?? resolvedOffset;
                    final snapX =
                        current.dx + (_communityMessengerButtonSize.width / 2) <
                                (viewport.width / 2)
                            ? _communityMessengerButtonMargin
                            : viewport.width -
                                _communityMessengerButtonSize.width -
                                _communityMessengerButtonMargin;
                    final snapped = _clampCommunityMessengerButtonOffset(
                      Offset(snapX, current.dy),
                      viewport,
                      safePadding,
                    );
                    _updateState(() {
                      _communityMessengerButtonOffset = snapped;
                    });
                    _persistCommunityMessengerButtonOffset(snapped);
                  },
                  child: Material(
                    color: Colors.transparent,
                    elevation: 0,
                    child: InkWell(
                      onTap: _openCommunityMessenger,
                      borderRadius: BorderRadius.circular(22),
                      child: Ink(
                        width: _communityMessengerButtonSize.width,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF6EAD),
                              Color(0xFFFF4D97),
                              Color(0xFFE23C83),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.26),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD81B60)
                                  .withValues(alpha: 0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFFFFC1D8)
                                  .withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.20),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.forum_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  if (_communityMessengerUnreadCount > 0)
                                    Positioned(
                                      top: -6,
                                      right: -8,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.4,
                                          ),
                                        ),
                                        child: Text(
                                          _communityMessengerUnreadCount > 99
                                              ? '99+'
                                              : '$_communityMessengerUnreadCount',
                                          textAlign: TextAlign.center,
                                          style: SLTheme.quicksand(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        width: 15,
                                        height: 15,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.favorite_rounded,
                                          color: Color(0xFFFF5A98),
                                          size: 8.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _ct(context.tr('home_nhntin_3e833a'), 'Message'),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontSize: 9.6,
                                  height: 1.08,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_communityMessengerPreviewText
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _communityMessengerPreviewText.trim(),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SLTheme.quicksand(
                                      color:
                                          Colors.white.withValues(alpha: 0.88),
                                      fontSize: 8.1,
                                      height: 1.12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formattedPostDate(Map<String, dynamic> post) {
    final int timestamp = _getTimestamp(post);
    final String cacheKey = '${post['id'] ?? ''}|$timestamp';
    final String? cached = _postFormattedDateCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (_postFormattedDateCache.length > 600) {
      _postFormattedDateCache.clear();
    }
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      timestamp == 0 ? DateTime.now().millisecondsSinceEpoch : timestamp,
    );
    final String value = _kCommunityPostDateFormat.format(date);
    _postFormattedDateCache[cacheKey] = value;
    return value;
  }

  String _sanitizedPostContent(Map<String, dynamic> post) {
    final String raw = (post['content'] ?? '').toString();
    if (raw.isEmpty) {
      return '';
    }
    final String cacheKey = '${post['id'] ?? ''}|${raw.length}|${raw.hashCode}';
    final String? cached = _postSanitizedTextCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (_postSanitizedTextCache.length > 600) {
      _postSanitizedTextCache.clear();
    }
    final String value = _sanitizeCommunityRenderText(raw);
    _postSanitizedTextCache[cacheKey] = value;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (_communityClosedUntilNextVersion) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _CommunityFeedErrorState(
          icon: Icons.rocket_launch_rounded,
          accentColor: const Color(0xFFD81B60),
          title: _ct(
            context.tr('home_cngngsramt_66c56c'),
            'Community will launch in the next version',
          ),
          message: _ct(
            context.tr('home_tabcngnghi_7e02d9'),
            'The Community tab is temporarily closed and will launch in the next version.',
          ),
          titleColor: Colors.white,
          messageColor: Colors.white70,
        ),
      );
    }

    if (_isCommunityMaintenance) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _CommunityFeedErrorState(
          icon: Icons.auto_awesome_rounded,
          accentColor: const Color(0xFFD81B60),
          title: _ct(
            context.tr('home_cngngtmthi_9ca62a'),
            'Community is temporarily unavailable',
          ),
          message: _ct(
            context.tr('home_community_maintenance_message'),
            'Community is under temporary maintenance. Please try again later.\n\nOther house features remain available as usual.',
          ),
          titleColor: Colors.white,
          messageColor: Colors.white70,
        ),
      );
    }

    final posts = _filteredPosts();

    return Scaffold(
      backgroundColor: _bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openComposer(),
        backgroundColor: const Color(0xFFD81B60),
        tooltip: _ct(context.tr('home_ngbimi_525829'), 'New post'),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _buildFeedBody(context, posts),
              ),
            ],
          ),

          // Render floating hearts and emojis
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _heartController,
                builder: (context, child) {
                  if (_hearts.isEmpty && _reactionAnimations.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Stack(
                    children: [
                      ..._hearts.map((h) {
                        return Positioned(
                          left: h.x,
                          top: h.y,
                          child: Opacity(
                            opacity: h.opacity,
                            child: Icon(Icons.favorite,
                                color: Colors.pinkAccent, size: h.size),
                          ),
                        );
                      }),
                      ..._reactionAnimations.map((r) {
                        return Positioned(
                          left: r.x,
                          top: r.y,
                          child: Opacity(
                            opacity: r.opacity,
                            child: Text(
                              r.emoji,
                              style: TextStyle(fontSize: r.size),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
          _buildCommunityMessengerButton(),
        ],
      ),
    );
  }
}
