// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/group_chat_room.dart';
import '../utils/app_error_mapper.dart';
import '../utils/services/chat_service.dart';
import '../utils/services/group_chat_service.dart';
import '../utils/services/social_service.dart';
import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';

class ShareBottomSheet extends StatefulWidget {
  final String myHouseId;
  final String contentToShare;
  final String shareUrl; // or deep link
  final String sourceType;
  final String sourceId;
  final bool loadInAppTargets;

  const ShareBottomSheet({
    super.key,
    required this.myHouseId,
    required this.contentToShare,
    this.shareUrl = '',
    this.sourceType = 'community_post',
    this.sourceId = '',
    this.loadInAppTargets = true,
  });

  static void show({
    required BuildContext context,
    required String myHouseId,
    required String contentToShare,
    String shareUrl = '',
    String sourceType = 'community_post',
    String sourceId = '',
    bool loadInAppTargets = true,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ShareBottomSheet(
        myHouseId: myHouseId,
        contentToShare: contentToShare,
        shareUrl: shareUrl,
        sourceType: sourceType,
        sourceId: sourceId,
        loadInAppTargets: loadInAppTargets,
      ),
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ChatService _chatService = ChatService();
  final GroupChatService _groupChatService = GroupChatService();
  final SocialService _socialService = SocialService();
  List<Map<String, dynamic>> _friends = [];
  List<GroupChatRoom> _groups = <GroupChatRoom>[];
  final Set<String> _sendingTargetIds = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.loadInAppTargets) {
      _loadFriends();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadFriends() async {
    final houseId = widget.myHouseId.trim();
    if (houseId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snap = await _dbRef
          .child('friends/$houseId')
          .get()
          .timeout(const Duration(seconds: 8));
      final data = snap.exists
          ? snap.value as Map<dynamic, dynamic>? ?? {}
          : <dynamic, dynamic>{};
      final List<Map<String, dynamic>> loadedFriends = [];

      for (var entry in data.entries) {
        final friendId = entry.key.toString();
        // final friendData = entry.value as Map<dynamic, dynamic>? ?? {}; // We don't really need friendData for favorite anymore if we sort by recency

        // Fetch house info
        final houseSnap = await _dbRef
            .child('houses/$friendId/settings')
            .get()
            .timeout(const Duration(seconds: 6));
        String name = L10nService().format('share_house_name_fallback', {'id': friendId});
        String avatar = '';

        if (houseSnap.exists) {
          final houseInfo = houseSnap.value as Map<dynamic, dynamic>? ?? {};
          name = houseInfo['houseName']?.toString().trim().isNotEmpty == true
              ? houseInfo['houseName'].toString().trim()
              : name;
          avatar = houseInfo['houseAvatar']?.toString() ??
              houseInfo['avtUser1']?.toString() ??
              '';
        }

        // Fetch last message timestamp for sorting
        final roomId = _chatService.roomIdFor(widget.myHouseId, friendId);
        final lastMsgSnap = await _dbRef
            .child('chats/$roomId/lastMessage/ts')
            .get()
            .timeout(const Duration(seconds: 6));
        int lastTs = 0;
        if (lastMsgSnap.exists) {
          lastTs = int.tryParse(lastMsgSnap.value.toString()) ?? 0;
        }

        try {
          await _socialService
              .assertCanInteractWithHouse(
                myHouseId: houseId,
                targetHouseId: friendId,
              )
              .timeout(const Duration(seconds: 6));
        } catch (_) {
          continue;
        }

        loadedFriends.add({
          'id': friendId,
          'name': name,
          'avatar': avatar,
          'lastTs': lastTs,
        });
      }

      // Sort: most recent message first
      loadedFriends.sort((a, b) {
        return b['lastTs'].compareTo(a['lastTs']);
      });

      final loadedGroups = await _groupChatService
          .streamGroupsForHouse(houseId)
          .first
          .timeout(const Duration(seconds: 8));
      loadedGroups.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));

      if (mounted) {
        setState(() {
          _friends = loadedFriends;
          _groups = loadedGroups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareToExternal() {
    final text = '${widget.contentToShare}\n${widget.shareUrl}'.trim();
    final box = context.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    Share.share(text, sharePositionOrigin: rect);
    Navigator.pop(context);
  }

  void _copyContentToClipboard({bool closeSheet = false}) {
    final text = '${widget.contentToShare}\n${widget.shareUrl}'.trim();
    Clipboard.setData(ClipboardData(text: text));
    if (closeSheet && mounted) {
      Navigator.pop(context);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      _buildFeedbackSnackBar(
        message: L10nService().translate('share_copied'),
        icon: Icons.check_circle_rounded,
        accentColor: const Color(0xFF0F9D58),
      ),
    );
  }

  void _copyToClipboard() {
    _copyContentToClipboard(closeSheet: true);
  }

  String _composeShareMessage() {
    final lines = <String>[
      L10nService().translate('share_message_prefix'),
      widget.contentToShare.trim(),
      if (widget.shareUrl.trim().isNotEmpty) widget.shareUrl.trim(),
    ];
    return lines.where((item) => item.trim().isNotEmpty).join('\n');
  }

  void _sendToFriend(String friendId) async {
    final targetKey = 'friend:$friendId';
    if (_sendingTargetIds.contains(targetKey)) {
      return;
    }
    setState(() => _sendingTargetIds.add(targetKey));
    try {
      final message = _composeShareMessage();
      await _chatService
          .sendMessage(
            widget.myHouseId,
            friendId,
            message,
            type: 'share',
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        _buildFeedbackSnackBar(
          message: L10nService().translate('share_sent'),
          icon: Icons.send_rounded,
          accentColor: const Color(0xFFD81B60),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _buildFeedbackSnackBar(
          message: AppErrorMapper.resolve(
            e,
            fallbackMessage: L10nService().translate('share_send_failed'),
          ).message,
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingTargetIds.remove(targetKey));
      }
    }
  }

  void _sendToGroup(GroupChatRoom group) async {
    final targetKey = 'group:${group.id}';
    if (_sendingTargetIds.contains(targetKey)) {
      return;
    }
    setState(() => _sendingTargetIds.add(targetKey));
    try {
      final payload = _groupChatService.buildSharePreviewPayload(
        senderHouseId: widget.myHouseId,
        text: _composeShareMessage(),
        sourceId: widget.sourceId,
        sourceType: widget.sourceType,
      );
      await _groupChatService
          .sendGroupMessage(
            groupId: group.id,
            senderHouseId: widget.myHouseId,
            text: (payload['text'] ?? '').toString(),
            type: (payload['type'] ?? 'share').toString(),
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        _buildFeedbackSnackBar(
          message: L10nService().translate('share_sent_group'),
          icon: Icons.groups_rounded,
          accentColor: const Color(0xFF7C3AED),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _buildFeedbackSnackBar(
          message: AppErrorMapper.resolve(
            e,
            fallbackMessage: L10nService().translate('share_send_group_failed'),
          ).message,
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingTargetIds.remove(targetKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final compact = SLResponsive.isCompactWidth(screenWidth);
    final textScaler = SLResponsive.textScalerFor(context);
    final contentHorizontalPadding = SLResponsive.dp(
      compact ? 14.0 : 16.0,
      screenWidth,
      min: 0.92,
      max: 1.08,
    );
    final friendsListHeight = SLResponsive.dp(
      compact ? 122.0 : 132.0,
      screenWidth,
      min: 0.92,
      max: 1.08,
    );
    final externalListHeight = SLResponsive.dp(
      compact ? 84.0 : 90.0,
      screenWidth,
      min: 0.92,
      max: 1.08,
    );

    final sheetHeight = (screenHeight * 0.94).clamp(320.0, screenHeight);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: textScaler),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFBFD), Color(0xFFF8FAFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 36,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(
                    vertical: SLResponsive.dp(12, screenWidth),
                  ),
                  width: SLResponsive.dp(56, screenWidth),
                  height: SLResponsive.dp(6, screenWidth, min: 0.9, max: 1.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF9A8D4), Color(0xFFF472B6)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1FD81B60),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentHorizontalPadding,
                    SLResponsive.dp(4, screenWidth),
                    contentHorizontalPadding,
                    SLResponsive.dp(12, screenWidth),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chia sẻ kỷ niệm',
                        style: SLTheme.quicksand(
                          fontSize: SLResponsive.sp(18, screenWidth),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          contentHorizontalPadding,
                          2,
                          contentHorizontalPadding,
                          SLResponsive.dp(10, screenWidth),
                        ),
                        child: _buildSharePreviewCard(
                          compact: compact,
                          screenWidth: screenWidth,
                        ),
                      ),
                      if (widget.loadInAppTargets) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentHorizontalPadding,
                            vertical: SLResponsive.dp(8, screenWidth),
                          ),
                          child: _buildSectionHeader(
                            title: L10nService().translate('share_send_to'),
                            subtitle: L10nService().translate('share_recent_friends'),
                            compact: compact,
                            screenWidth: screenWidth,
                          ),
                        ),
                        if (_isLoading)
                          SizedBox(
                            height: friendsListHeight,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: SLResponsive.dp(
                                  compact ? 16 : 18,
                                  screenWidth,
                                ),
                              ),
                              itemCount: 4,
                              separatorBuilder: (_, __) => SizedBox(
                                width: SLResponsive.dp(12, screenWidth),
                              ),
                              itemBuilder: (ctx, i) {
                                return Column(
                                  children: [
                                    Container(
                                      width: SLResponsive.dp(
                                        compact ? 52 : 56,
                                        screenWidth,
                                      ),
                                      height: SLResponsive.dp(
                                        compact ? 52 : 56,
                                        screenWidth,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFCE7F3),
                                            Color(0xFFF8FAFC),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(
                                      height: SLResponsive.dp(8, screenWidth),
                                    ),
                                    Container(
                                      width: SLResponsive.dp(
                                        compact ? 48 : 52,
                                        screenWidth,
                                      ),
                                      height: SLResponsive.dp(10, screenWidth),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFCE7F3),
                                            Color(0xFFE2E8F0),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        else if (_friends.isEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              contentHorizontalPadding,
                              SLResponsive.dp(6, screenWidth),
                              contentHorizontalPadding,
                              SLResponsive.dp(12, screenWidth),
                            ),
                            child: _buildEmptyStateCard(
                              compact: compact,
                              icon: Icons.people_alt_rounded,
                              title: L10nService().translate('share_no_friends_title'),
                              subtitle: L10nService().translate('share_no_friends_subtitle'),
                              screenWidth: screenWidth,
                            ),
                          )
                        else
                          SizedBox(
                            height: friendsListHeight,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: SLResponsive.dp(
                                  compact ? 10 : 12,
                                  screenWidth,
                                ),
                              ),
                              itemCount: _friends.length,
                              itemBuilder: (ctx, i) {
                                final f = _friends[i];
                                final isSending = _sendingTargetIds
                                    .contains('friend:${f['id']}');
                                return _buildShareTargetBlock(
                                  compact: compact,
                                  label: f['name'].toString(),
                                  avatarUrl: f['avatar'].toString(),
                                  icon: Icons.home_rounded,
                                  accentColor: const Color(0xFFD81B60),
                                  isSending: isSending,
                                  onTap: isSending
                                      ? null
                                      : () => _sendToFriend(f['id']),
                                  screenWidth: screenWidth,
                                );
                              },
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentHorizontalPadding,
                            vertical: SLResponsive.dp(4, screenWidth),
                          ),
                          child: const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentHorizontalPadding,
                            vertical: SLResponsive.dp(8, screenWidth),
                          ),
                          child: _buildSectionHeader(
                            title: L10nService().translate('share_send_to_group'),
                            subtitle: L10nService().translate('share_groups_member'),
                            compact: compact,
                            screenWidth: screenWidth,
                          ),
                        ),
                        if (_groups.isEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              contentHorizontalPadding,
                              SLResponsive.dp(6, screenWidth),
                              contentHorizontalPadding,
                              SLResponsive.dp(12, screenWidth),
                            ),
                            child: _buildEmptyStateCard(
                              compact: compact,
                              icon: Icons.groups_rounded,
                              title: L10nService().translate('share_no_groups_title'),
                              subtitle: L10nService().translate('share_no_groups_subtitle'),
                              screenWidth: screenWidth,
                            ),
                          )
                        else
                          SizedBox(
                            height: friendsListHeight,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: SLResponsive.dp(
                                  compact ? 10 : 12,
                                  screenWidth,
                                ),
                              ),
                              itemCount: _groups.length,
                              itemBuilder: (ctx, i) {
                                final group = _groups[i];
                                final isSending = _sendingTargetIds
                                    .contains('group:${group.id}');
                                return _buildShareTargetBlock(
                                  compact: compact,
                                  label: group.name,
                                  avatarUrl: '',
                                  icon: Icons.groups_rounded,
                                  accentColor: const Color(0xFF7C3AED),
                                  isSending: isSending,
                                  onTap: isSending
                                      ? null
                                      : () => _sendToGroup(group),
                                  screenWidth: screenWidth,
                                );
                              },
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentHorizontalPadding,
                            vertical: SLResponsive.dp(4, screenWidth),
                          ),
                          child: const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                        ),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: contentHorizontalPadding,
                          vertical: SLResponsive.dp(8, screenWidth),
                        ),
                        child: _buildSectionHeader(
                          title: L10nService().translate('share_via'),
                          subtitle: L10nService().translate('share_external_copy'),
                          compact: compact,
                          screenWidth: screenWidth,
                        ),
                      ),
                      SizedBox(
                        height: externalListHeight,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                            horizontal: SLResponsive.dp(
                              compact ? 10 : 12,
                              screenWidth,
                            ),
                          ),
                          children: [
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0068FF),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_rounded,
                                      color: Colors.white,
                                      size: SLResponsive.dp(compact ? 30 : 34, screenWidth),
                                    ),
                                    Positioned(
                                      top: SLResponsive.dp(compact ? 8 : 9, screenWidth),
                                      child: Text(
                                        'zalo',
                                        style: TextStyle(
                                          fontFamily: 'sans-serif',
                                          color: const Color(0xFF0068FF),
                                          fontWeight: FontWeight.w900,
                                          fontSize: SLResponsive.sp(compact ? 8 : 9, screenWidth),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              label: 'Zalo',
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1877F2),
                                  shape: BoxShape.circle,
                                ),
                                alignment: const Alignment(0.15, 1.0),
                                child: Text(
                                  'f',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'sans-serif',
                                    fontSize: SLResponsive.sp(compact ? 42 : 46, screenWidth),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              label: 'Facebook',
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF00B2FF),
                                      Color(0xFF006AFF),
                                      Color(0xFFA100FF),
                                      Color(0xFFFF2E93),
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: ClipPath(
                                  clipper: LightningBoltClipper(),
                                  child: Container(
                                    width: SLResponsive.dp(compact ? 20 : 22, screenWidth),
                                    height: SLResponsive.dp(compact ? 20 : 22, screenWidth),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              label: 'Messenger',
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xFFFFDD55),
                                      Color(0xFFFF543F),
                                      Color(0xFFC837AB),
                                      Color(0xFF3770E0),
                                    ],
                                    center: Alignment(-0.6, 0.9),
                                    radius: 1.3,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: SLResponsive.dp(compact ? 22 : 24, screenWidth),
                                  height: SLResponsive.dp(compact ? 22 : 24, screenWidth),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 2.2),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  alignment: Alignment.center,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: SLResponsive.dp(compact ? 8 : 9, screenWidth),
                                        height: SLResponsive.dp(compact ? 8 : 9, screenWidth),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.white, width: 2.0),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          width: 3,
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              label: 'Instagram',
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF24A1DE),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: SLResponsive.dp(compact ? 24 : 26, screenWidth),
                                ),
                              ),
                              label: 'Telegram',
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.chat_bubble_rounded,
                                  color: Colors.white,
                                  size: SLResponsive.dp(compact ? 22 : 24, screenWidth),
                                ),
                              ),
                              label: 'Tin nhắn',
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF64748B),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.copy_all_rounded,
                                  color: Colors.white,
                                  size: SLResponsive.dp(compact ? 22 : 24, screenWidth),
                                ),
                              ),
                              label: L10nService().translate('core_copy'),
                              onTap: _copyToClipboard,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                  size: SLResponsive.dp(compact ? 22 : 24, screenWidth),
                                ),
                              ),
                              label: L10nService().translate('core_other'),
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: SLResponsive.dp(16, screenWidth)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required bool compact,
    required double screenWidth,
  }) {
    return Row(
      children: [
        Container(
          width: SLResponsive.dp(compact ? 8 : 9, screenWidth),
          height: SLResponsive.dp(compact ? 8 : 9, screenWidth),
          decoration: const BoxDecoration(
            color: Color(0xFFD81B60),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: SLResponsive.dp(10, screenWidth)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: SLResponsive.sp(compact ? 15.6 : 16.4, screenWidth),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(
                height: SLResponsive.dp(2, screenWidth, min: 0.9, max: 1.0),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: SLResponsive.sp(compact ? 11.2 : 11.8, screenWidth),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard({
    required bool compact,
    required IconData icon,
    required String title,
    required String subtitle,
    required double screenWidth,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: SLResponsive.dp(compact ? 14 : 16, screenWidth),
        vertical: SLResponsive.dp(compact ? 13 : 14, screenWidth),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBFD), Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SLResponsive.dp(20, screenWidth)),
        border: Border.all(color: const Color(0xFFFFE4EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: SLResponsive.dp(compact ? 38 : 42, screenWidth),
            height: SLResponsive.dp(compact ? 38 : 42, screenWidth),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFCE7F3), Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(SLResponsive.dp(14, screenWidth)),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFB83280),
              size: SLResponsive.dp(20, screenWidth),
            ),
          ),
          SizedBox(width: SLResponsive.dp(12, screenWidth)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: SLResponsive.sp(compact ? 12.2 : 12.8, screenWidth),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF334155),
                  ),
                ),
                SizedBox(
                  height: SLResponsive.dp(3, screenWidth, min: 0.9, max: 1.0),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: SLResponsive.sp(compact ? 11.1 : 11.6, screenWidth),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharePreviewCard({
    required bool compact,
    required double screenWidth,
  }) {
    final previewText = widget.contentToShare.trim();
    final previewUrl = widget.shareUrl.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        SLResponsive.dp(compact ? 16 : 18, screenWidth),
        SLResponsive.dp(compact ? 14 : 16, screenWidth),
        SLResponsive.dp(compact ? 16 : 18, screenWidth),
        SLResponsive.dp(compact ? 14 : 16, screenWidth),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4F8), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SLResponsive.dp(24, screenWidth)),
        border: Border.all(color: const Color(0xFFFFD1E3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SLResponsive.dp(compact ? 42 : 46, screenWidth),
            height: SLResponsive.dp(compact ? 42 : 46, screenWidth),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFEEF4), Color(0xFFFFF5F8)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD8E6)),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFD81B60),
            ),
          ),
          SizedBox(width: SLResponsive.dp(12, screenWidth)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nội dung bạn đang chia sẻ',
                      style: SLTheme.quicksand(
                        fontSize: SLResponsive.sp(compact ? 12.8 : 13.4, screenWidth),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _copyContentToClipboard(closeSheet: false),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFE0EB)),
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            size: SLResponsive.dp(14, screenWidth),
                            color: const Color(0xFFD81B60),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: SLResponsive.dp(6, screenWidth)),
                GestureDetector(
                  onTap: () => _copyContentToClipboard(closeSheet: false),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      previewText.isEmpty ? 'Chưa có nội dung hiển thị.' : previewText,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: SLResponsive.sp(compact ? 12.6 : 13.2, screenWidth),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                if (previewUrl.isNotEmpty) ...[
                  SizedBox(height: SLResponsive.dp(10, screenWidth)),
                  GestureDetector(
                    onTap: () => _copyContentToClipboard(closeSheet: false),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SLResponsive.dp(12, screenWidth),
                          vertical: SLResponsive.dp(8, screenWidth),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(SLResponsive.dp(14, screenWidth)),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: SLResponsive.dp(16, screenWidth),
                              color: const Color(0xFF64748B),
                            ),
                            SizedBox(width: SLResponsive.dp(8, screenWidth)),
                            Expanded(
                              child: Text(
                                previewUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: SLResponsive.sp(11.6, screenWidth),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            SizedBox(width: SLResponsive.dp(8, screenWidth)),
                            Icon(
                              Icons.copy_rounded,
                              size: SLResponsive.dp(13, screenWidth),
                              color: const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareTargetBlock({
    required bool compact,
    required String label,
    required String avatarUrl,
    required IconData icon,
    required Color accentColor,
    required bool isSending,
    required VoidCallback? onTap,
    required double screenWidth,
  }) {
    final blockWidth = SLResponsive.dp(compact ? 86.0 : 94.0, screenWidth);
    final avatarSize = SLResponsive.dp(compact ? 50.0 : 56.0, screenWidth);
    return SizedBox(
      width: blockWidth,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SLResponsive.dp(6, screenWidth, min: 0.9, max: 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              SLResponsive.dp(22, screenWidth),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: isSending ? 0.62 : 1,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  SLResponsive.dp(8, screenWidth),
                  SLResponsive.dp(9, screenWidth),
                  SLResponsive.dp(8, screenWidth),
                  SLResponsive.dp(8, screenWidth),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.14),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(
                    SLResponsive.dp(22, screenWidth),
                  ),
                  border: Border.all(color: accentColor.withValues(alpha: 0.16)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x100F172A),
                      blurRadius: 14,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: avatarSize + SLResponsive.dp(8, screenWidth),
                          height: avatarSize + SLResponsive.dp(8, screenWidth),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              SLResponsive.dp(20, screenWidth),
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            SLResponsive.dp(18, screenWidth),
                          ),
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            color: accentColor.withValues(alpha: 0.12),
                            child: avatarUrl.trim().isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                    errorWidget: (_, __, ___) => Icon(
                                      icon,
                                      color: accentColor,
                                    ),
                                  )
                                : Icon(
                                    icon,
                                    color: accentColor,
                                    size: SLResponsive.dp(
                                      compact ? 24 : 27,
                                      screenWidth,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: SLResponsive.dp(-3, screenWidth, min: 1, max: 1),
                          bottom: SLResponsive.dp(-3, screenWidth, min: 1, max: 1),
                          child: Container(
                            width: SLResponsive.dp(compact ? 20 : 22, screenWidth),
                            height: SLResponsive.dp(compact ? 20 : 22, screenWidth),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: isSending
                                ? Padding(
                                    padding: EdgeInsets.all(
                                      SLResponsive.dp(
                                        4,
                                        screenWidth,
                                        min: 0.9,
                                        max: 1.0,
                                      ),
                                    ),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: SLResponsive.dp(11, screenWidth),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SLResponsive.dp(7, screenWidth)),
                    Text(
                      label,
                      style: SLTheme.quicksand(
                        fontSize: SLResponsive.sp(
                          compact ? 11.2 : 11.8,
                          screenWidth,
                        ),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
  Widget _buildExternalShareItem({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    required bool compact,
    required double screenWidth,
  }) {
    return SizedBox(
      width: SLResponsive.dp(compact ? 74 : 80, screenWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SLResponsive.dp(6, screenWidth, min: 0.9, max: 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              SLResponsive.dp(22, screenWidth),
            ),
            child: Column(
              children: [
                Container(
                  width: SLResponsive.dp(compact ? 52 : 58, screenWidth),
                  height: SLResponsive.dp(compact ? 52 : 58, screenWidth),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: icon,
                ),
                SizedBox(height: SLResponsive.dp(8, screenWidth)),
                Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: SLResponsive.sp(compact ? 11.5 : 12, screenWidth),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  SnackBar _buildFeedbackSnackBar({
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: 0.96),
              accentColor.withValues(alpha: 0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 12.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LightningBoltClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.58, h * 0.15);
    path.lineTo(w * 0.30, h * 0.55);
    path.lineTo(w * 0.52, h * 0.55);
    path.lineTo(w * 0.42, h * 0.85);
    path.lineTo(w * 0.70, h * 0.45);
    path.lineTo(w * 0.48, h * 0.45);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
