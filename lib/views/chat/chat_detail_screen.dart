import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/image_picker_recovery_service.dart';
import '../../services/military_lock_service.dart';
import '../../services/social_service.dart';
import '../../services/storage_service.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../utils/services/storage_upload_result.dart';
import 'package:intl/intl.dart';
import '../relationship/video_call_screen.dart';
import 'chat_message_preview.dart';
import 'watch_together_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/security_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/rapid_action_feedback_policy.dart';
import '../../widgets/animated_rabbit_sticker.dart';
import '../../services/connectivity_service.dart';
import 'chat_friendly_helper.dart';
import '../../widgets/skeleton_container.dart';



part 'chat_detail/chat_detail_helpers_part.dart';
part 'chat_detail/chat_detail_actions_part.dart';
part 'chat_detail/chat_detail_dialogs_part.dart';
part 'chat_detail/chat_detail_messages_part.dart';
part 'chat_detail/chat_detail_layout_part.dart';

class ChatDetailScreen extends StatefulWidget {
  final String myHouseId;
  final String targetHouseId;
  final String targetName;
  final String targetAvatar;
  final bool isInternal;
  final String currentRole;
  final String targetRole;

  const ChatDetailScreen({
    super.key,
    required this.myHouseId,
    required this.targetHouseId,
    required this.targetName,
    this.targetAvatar = '',
    this.isInternal = false,
    this.currentRole = 'user1',
    this.targetRole = 'user2',
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatInfoShortcut {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final bool closeDrawerBeforeAction;
  final Future<void> Function() onTap;

  const _ChatInfoShortcut({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.closeDrawerBeforeAction,
    required this.onTap,
  });
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const String _pendingChatImageUploadKeyPrefix = 'chat_image_';
  static const String _pendingChatBackgroundUploadKeyPrefix = 'chat_bg_';

  final ChatService _chatService = ChatService();
  final SocialService _socialService = SocialService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();

  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;
  bool _isUploading = false;
  bool _isUpdatingChatBackground = false;
  bool _isInitialMessagesLoading = true;
  bool _isLoadingOlderMessages = false;
  bool _hasMoreMessages = true;
  bool _hasComposerText = false;
  bool _didPromptPendingChatRetry = false;
  String _nickname = '';
  String _targetBio = '';
  String _quickReactionEmoji = '\u{1F44D}';
  bool _isChatMuted = false;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final MilitaryLockService _militaryLockService = MilitaryLockService();

  static const int _chatPageSize = 40;
  static const List<String> _quickReactionOptions = <String>[
    '\u{1F44D}',
    '\u2764\uFE0F',
    '\u{1F970}',
    '\u{1F602}',
    '\u{1F62E}',
    '\u{1F622}',
    '\u{1F621}',
    '\u{1F525}',
    '\u{1F44F}',
    '\u{1F4AF}',
  ];
  static const ChatMessagePreviewLabels _conversationPreviewLabels =
      ChatMessagePreviewLabels(
    fallback:
        'Nh\u1eafn tin \u0111\u1ec3 b\u1eaft \u0111\u1ea7u tr\u00f2 chuy\u1ec7n',
    callInvite: '\u0110\u00e3 b\u1eaft \u0111\u1ea7u cu\u1ed9c g\u1ecdi',
    watchInvite: '\u0110\u00e3 chia s\u1ebb ph\u00f2ng xem c\u00f9ng',
    image: '\u0110\u00e3 g\u1eedi h\u00ecnh \u1ea3nh',
    share: '\u0110\u00e3 chia s\u1ebb m\u1ed9t b\u00e0i vi\u1ebft',
  );
  late final Stream<ChatRoomMeta> _roomMetaStream;
  StreamSubscription<ChatMessage>? _liveMessageSub;
  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = <String>{};
  String? _oldestMessageKey;
  String? _newestMessageKey;
  String get _roomId => _chatService.roomIdFor(
        widget.myHouseId,
        widget.targetHouseId,
      );
  bool get _isInternal => widget.isInternal;
  String get _currentRole => widget.currentRole == 'user2' ? 'user2' : 'user1';
  String get _chatPrefsScope =>
      _isInternal ? 'internal_${widget.myHouseId}' : _roomId;
  String get _nicknamePrefsKey => 'chat_detail_nickname_$_chatPrefsScope';
  String get _quickReactionPrefsKey =>
      'chat_detail_quick_reaction_$_chatPrefsScope';
  String get _muteNotificationsPrefsKey => 'chat_detail_muted_$_chatPrefsScope';
  String get _groupDraftPrefsKey =>
      'messenger_group_drafts_v1_${widget.myHouseId}';
  String get _pendingChatImageUploadKey =>
      '$_pendingChatImageUploadKeyPrefix$_chatPrefsScope';
  String get _pendingChatBackgroundUploadKey =>
      '$_pendingChatBackgroundUploadKeyPrefix$_chatPrefsScope';

  @override
  void initState() {
    super.initState();
    _quickReactionEmoji = _quickReactionOptions.first;
    _checkChatLock();
    unawaited(_loadChatPrefs());
    _roomMetaStream = _isInternal
        ? _chatService.streamInternalRoomMeta(widget.myHouseId)
        : _chatService.streamRoomMeta(
            _roomId,
            viewerHouseId: widget.myHouseId,
          );
    _messagesScrollController.addListener(_handleMessageScroll);
    _msgController.addListener(_handleComposerTextChanged);
    unawaited(_loadTargetBio());
    unawaited(_loadInitialMessages());
    unawaited(_promptPendingChatUploadRetryIfNeeded());
  }

  Future<void> _loadChatPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = (prefs.getString(_nicknamePrefsKey) ?? '').trim();
    final quick = (prefs.getString(_quickReactionPrefsKey) ?? '').trim();
    final muted = prefs.getBool(_muteNotificationsPrefsKey) ?? false;
    if (!mounted) return;
    setState(() {
      _nickname = nickname;
      _quickReactionEmoji = quick.isEmpty ? _quickReactionOptions.first : quick;
      _isChatMuted = muted;
    });
  }

  Future<void> _loadTargetBio() async {
    if (_isInternal || widget.targetHouseId.trim().isEmpty) {
      return;
    }
    final candidates = <String>[
      'houses/${widget.targetHouseId}/settings/bio',
      'houses/${widget.targetHouseId}/bio',
      'houses_public/${widget.targetHouseId}/bio',
      'house_profiles/${widget.targetHouseId}/bio',
    ];
    for (final path in candidates) {
      try {
        final snap = await _dbRef.child(path).get();
        final bio = snap.value?.toString().trim() ?? '';
        if (bio.isNotEmpty) {
          if (!mounted) return;
          setState(() => _targetBio = bio);
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _saveNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknamePrefsKey, nickname.trim());
  }

  Future<void> _saveQuickReaction(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_quickReactionPrefsKey, emoji.trim());
  }

  Future<void> _saveChatMute(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteNotificationsPrefsKey, muted);
  }

  @override
  void dispose() {
    _msgController.removeListener(_handleComposerTextChanged);
    _msgController.dispose();
    _messagesScrollController.dispose();
    _liveMessageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // Skeleton Header
            Container(
              height: MediaQuery.of(context).padding.top + 74,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SkeletonContainer.circle(size: 32),
                    const SizedBox(width: 12),
                    const SkeletonContainer.circle(size: 40),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonContainer.rounded(width: 120, height: 16),
                        SizedBox(height: 6),
                        SkeletonContainer.rounded(width: 80, height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Skeleton Messages
            Expanded(
              child: ListView.builder(
                itemCount: 8,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final isMe = index % 2 == 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          const SkeletonContainer.circle(size: 32),
                          const SizedBox(width: 8),
                        ],
                        SkeletonContainer.rounded(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 44,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Skeleton Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
                  const SkeletonContainer.circle(size: 36),
                  const SizedBox(width: 12),
                  const Expanded(child: SkeletonContainer.rounded(height: 40)),
                  const SizedBox(width: 12),
                  const SkeletonContainer.circle(size: 36),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Tin nhắn riêng',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SLSpacing.h16,
              Text(
                'Tin nhắn đang được khóa',
                style: SLTheme.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[700],
                ),
              ),
              SLSpacing.h8,
              Text(
                'Mở khóa để xem lại cuộc trò chuyện và tiếp tục nhắn với ${_nickname.trim().isEmpty ? widget.targetName : _nickname.trim()}.',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SLSpacing.h24,
              ElevatedButton(
                onPressed: _checkChatLock,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    foregroundColor: Colors.white),
                child: Text(
                  'Mở khóa',
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              )
            ],
          ),
        ),
      );
    }

    return StreamBuilder<ChatRoomMeta>(
      stream: _roomMetaStream,
      builder: (context, roomSnapshot) {
        final meta = roomSnapshot.data ?? const ChatRoomMeta();
        final isChatClosed = meta.isClosed;
        final closedMessage = meta.closedMessage.trim();
        final deletedDisplayName = meta.deletedDisplayName.trim();
        final displayName = isChatClosed
            ? (deletedDisplayName.isEmpty
                ? 'Người dùng đã xóa'
                : deletedDisplayName)
            : widget.targetName;
        final headerDisplayName = _nickname.trim().isNotEmpty && !isChatClosed
            ? _nickname.trim()
            : displayName;
        final displayAvatar = isChatClosed ? '' : widget.targetAvatar;
        final headerPreview = _buildHeaderPreview(meta);
        final headerSubtitle = _targetBio.trim().isNotEmpty && !isChatClosed
            ? _targetBio.trim()
            : headerPreview;
        final currentBackgroundUrl = meta.backgroundUrl.trim();
        final currentBackgroundStoragePath = meta.backgroundStoragePath.trim();
        final hasChatBackground = currentBackgroundUrl.isNotEmpty;
        final topInset = MediaQuery.paddingOf(context).top;
        final appBarHeight = topInset + 74;

        return Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(appBarHeight),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final compactHeader =
                        constraints.maxWidth < 390 || textScale > 1.05;
                    final avatarRadius = compactHeader ? 20.0 : 22.0;
                    final onlineDotSize = compactHeader ? 11.0 : 12.0;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compactHeader ? 6 : 8,
                        vertical: compactHeader ? 8 : 10,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: BoxConstraints.tightFor(
                              width: compactHeader ? 36 : 40,
                              height: compactHeader ? 36 : 40,
                            ),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: Color(0xFF1E293B),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFD6E4FF),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: avatarRadius,
                                  backgroundColor: Colors.pink[50],
                                  backgroundImage: displayAvatar.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          displayAvatar)
                                      : null,
                                  child: displayAvatar.isEmpty
                                      ? Text(
                                          headerDisplayName.isNotEmpty
                                              ? headerDisplayName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: const Color(0xFF0A7CFF),
                                            fontSize: compactHeader ? 15 : 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              if (!isChatClosed)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: onlineDotSize,
                                    height: onlineDotSize,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(width: compactHeader ? 8 : 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headerDisplayName.replaceAll('\n', ' '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    color: const Color(0xFF1E293B),
                                    fontSize: compactHeader ? 15 : 16,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  headerSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    color: const Color(0xFF64748B),
                                    fontSize: compactHeader ? 11 : 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildAppBarAction(
                            Icons.info_outline_rounded,
                            () => _openChatSettingsSheet(
                              isChatClosed: isChatClosed,
                              displayName: headerDisplayName,
                              displayAvatar: displayAvatar,
                              headerPreview: headerPreview,
                              currentBackgroundUrl: currentBackgroundUrl,
                              currentBackgroundStoragePath:
                                  currentBackgroundStoragePath,
                            ),
                            compact: compactHeader,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _buildConversationBackground(currentBackgroundUrl),
              ),
              Column(
                children: [
                  if (isChatClosed)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F4).withOpacity(
                          hasChatBackground ? 0.88 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD5DE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_clock_rounded,
                            color: Color(0xFFD81B60),
                          ),
                          SLSpacing.w8,
                          Expanded(
                            child: Text(
                              closedMessage.isEmpty
                                  ? 'Đoạn chat này đã bị đóng và chỉ còn xem lại lịch sử.'
                                  : closedMessage,
                              style: SLTheme.quicksand(
                                color: const Color(0xFFD81B60),
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _buildMessagesList(
                      isChatClosed,
                      hasChatBackground: hasChatBackground,
                    ),
                  ),
                  _buildInputArea(
                    isChatClosed,
                    hasChatBackground: hasChatBackground,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
