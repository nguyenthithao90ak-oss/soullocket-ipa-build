import 'package:soullocket_app/widgets/sl_image_crop_file.dart';
import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:soullocket_app/views/home/widgets/soul_merge/sticker_bottom_sheet.dart';
import '../../utils/services/l10n_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_message.dart';
import '../../utils/services/chat_service.dart';
import '../../utils/services/image_picker_recovery_service.dart';
import '../../utils/services/military_lock_service.dart';
import '../../utils/services/social_service.dart';
import '../../utils/services/sound_service.dart';
import '../../utils/services/storage/storage_service.dart';
import '../../utils/services/app_lifecycle_presence_guard.dart';
import '../../utils/services/pending_upload_service.dart';
import '../../utils/services/storage/storage_upload_result.dart';
import 'package:intl/intl.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/app_cache_manager.dart';
import '../relationship/video_call_screen.dart';
import 'chat_message_preview.dart';
import 'widgets/chat_message_retry_notice.dart';
import 'widgets/chat_text_widgets.dart';
import 'watch_together_screen.dart';
import '../../utils/services/purchase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/admob_service.dart';

import '../../utils/services/security_service.dart';
import '../../utils/services/giftcode_service.dart';
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../core/sl_route.dart';
import '../../utils/rapid_action_feedback_policy.dart';
import '../../widgets/animated_rabbit_sticker.dart';

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
  bool _isSendingMessage = false;
  bool _isUpdatingChatBackground = false;
  bool _isInitialMessagesLoading = true;
  bool _initialMessageRequestInFlight = false;
  bool _hasInitialMessageError = false;
  bool _hasOlderMessageError = false;
  bool _hasLiveMessageError = false;
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

  static const int _chatPageSize = 25;
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
  static ChatMessagePreviewLabels get _conversationPreviewLabels =>
      ChatMessagePreviewLabels(
        fallback: L10nService().translate(
          'ui_chat_text_to_start_chatting_dab6a3',
        ),
        callInvite: L10nService().translate('ui_chat_b_t_u_cu_c_g_i_f0e203'),
        watchInvite: L10nService().translate(
          'ui_chat_chia_s_ph_ng_xem_c_ng_a94571',
        ),
        image: L10nService().translate('ui_chat_g_i_h_nh_nh_a669bb'),
        share: L10nService().translate('ui_chat_chia_s_m_t_b_i_vi_b78759'),
      );
  late final Stream<ChatRoomMeta> _roomMetaStream;
  StreamSubscription<ChatMessage>? _liveMessageSub;
  final List<ChatMessage> _messages = [];
  late final ValueNotifier<List<ChatMessage>> _messagesNotifier = ValueNotifier(
    _messages,
  );

  void _notifyMessagesChanged() {
    _messagesNotifier.value = List.from(_messages);
  }

  final Set<String> _messageIds = <String>{};
  int? _oldestMessageTs;
  int? _newestMessageTs;
  int? _liveMessageAnchorTs;
  String get _roomId =>
      _chatService.roomIdFor(widget.myHouseId, widget.targetHouseId);
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
    AdMobService().suppressAutoInterstitial();
    _quickReactionEmoji = _quickReactionOptions.first;
    _checkChatLock();
    unawaited(_loadChatPrefs());
    _roomMetaStream = _isInternal
        ? _chatService.streamInternalRoomMeta(widget.myHouseId)
        : _chatService.streamRoomMeta(_roomId, viewerHouseId: widget.myHouseId);
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
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/chat/chat_detail_screen.dart: $error',
        );
      }
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
    AdMobService().resumeAutoInterstitial();
    _msgController.removeListener(_handleComposerTextChanged);
    _msgController.dispose();
    _messagesScrollController.dispose();
    _liveMessageSub?.cancel();
    _messagesNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: SLColors.paperCanvas,
        body: SLTheme.softCanvasBackdrop(
          baseColor: SLColors.paperCanvas,
          accentColor: SLColors.secondary,
          secondaryAccent: SLColors.thread,
          motif: SLCanvasBackdropMotif.notes,
          child: Center(
            child: SLTheme.softPanel(
              padding: const EdgeInsets.all(20),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: SLColors.primary,
                  strokeWidth: 2.8,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: SLColors.paperCanvas,
        appBar: AppBar(
          backgroundColor: SLColors.paper,
          surfaceTintColor: Colors.transparent,
          title: Text(
            L10nService().translate('chat_private_messages'),
            style: SLTheme.quicksand(fontWeight: FontWeight.w900),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SLTheme.softCanvasBackdrop(
          baseColor: SLColors.paperCanvas,
          accentColor: SLColors.secondary,
          secondaryAccent: SLColors.thread,
          motif: SLCanvasBackdropMotif.notes,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: SLTheme.softPanel(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 58,
                        color: SLColors.primary,
                      ),
                      SLSpacing.h16,
                      Text(
                        L10nService().translate('chat_locked_title'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: SLColors.textPrimary,
                        ),
                      ),
                      SLSpacing.h8,
                      Text(
                        L10nService().format('chat_locked_desc', {
                          'name': _nickname.trim().isEmpty
                              ? widget.targetName
                              : _nickname.trim(),
                        }),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      SLSpacing.h24,
                      SLTheme.primaryButton(
                        text: L10nService().translate('chat_unlock'),
                        onPressed: _checkChatLock,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                  ? L10nService().translate('chat_deleted_user')
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
        final palette = _ChatDetailPalette.of(context);

        return Scaffold(
          backgroundColor: palette.canvas,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(ChatDetailHeader.heightFor(context)),
            child: ChatDetailHeader(
              displayName: headerDisplayName,
              subtitle: headerSubtitle,
              avatarUrl: displayAvatar,
              showStatusDot: !isChatClosed,
              backLabel: context.tr('messenger_back'),
              infoLabel: context.tr('settings_menu_preferences'),
              onBack: () => Navigator.pop(context),
              onInfo: () => _openChatSettingsSheet(
                isChatClosed: isChatClosed,
                displayName: headerDisplayName,
                displayAvatar: displayAvatar,
                headerPreview: headerPreview,
                currentBackgroundUrl: currentBackgroundUrl,
                currentBackgroundStoragePath: currentBackgroundStoragePath,
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _buildConversationBackground(currentBackgroundUrl),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final contentInset = constraints.maxWidth > 960
                      ? (constraints.maxWidth - 960) / 2
                      : 0.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: contentInset),
                    child: Column(
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
                              color: const Color(
                                0xFFFFF1F4,
                              ).withValues(alpha: hasChatBackground ? 0.88 : 1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFD5DE),
                              ),
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
                                        ? L10nService().translate(
                                            'chat_closed_history_only',
                                          )
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
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Header chỉ nhận dữ liệu/callback; không sở hữu listener hoặc nghiệp vụ chat.
class ChatDetailHeader extends StatelessWidget {
  const ChatDetailHeader({
    super.key,
    required this.displayName,
    required this.subtitle,
    required this.avatarUrl,
    required this.showStatusDot,
    required this.backLabel,
    required this.infoLabel,
    required this.onBack,
    required this.onInfo,
  });
  final String displayName;
  final String subtitle;
  final String avatarUrl;
  final bool showStatusDot;
  final String backLabel;
  final String infoLabel;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return (scaler.scale(16) * 1.3 * 2 + scaler.scale(13) * 1.3 + 22)
        .clamp(74, double.infinity)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ChatDetailPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: backLabel,
                    onPressed: onBack,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: palette.ink,
                      size: 21,
                    ),
                  ),
                  ExcludeSemantics(
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.surface,
                            border: Border.all(color: palette.line, width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: palette.wash,
                            backgroundImage: avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: SLTheme.quicksand(
                                      color: palette.accent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (showStatusDot)
                          PositionedDirectional(
                            end: 1,
                            bottom: 1,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: SLColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: palette.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            displayName.replaceAll('\n', ' '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: palette.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: palette.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: infoLabel,
                    onPressed: onInfo,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: palette.accent,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatDetailPalette {
  _ChatDetailPalette.of(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get canvas => dark ? SLColors.darkBgMain : Colors.white;
  Color get surface => dark ? SLColors.darkBgCard : SLColors.paper;
  Color get ink => dark ? SLColors.darkTextPrimary : SLColors.ink;
  Color get muted => dark ? SLColors.darkTextSecond : SLColors.textSecond;
  Color get line => dark ? SLColors.darkBorder : SLColors.borderLight;
  Color get accent => dark ? const Color(0xFFE7B5C5) : const Color(0xFF864758);
  Color get wash => Color.alphaBlend(accent.withValues(alpha: .12), surface);
}
