// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/models/group_chat_room.dart';
import 'package:soullocket_app/utils/services/chat_service.dart';
import 'package:soullocket_app/utils/services/group_chat_service.dart';
import 'package:soullocket_app/utils/services/social_service.dart';
import '../core/sl_theme.dart';

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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    try {
      final snap = await _dbRef.child('friends/${widget.myHouseId}').get();
      final data = snap.exists
          ? snap.value as Map<dynamic, dynamic>? ?? {}
          : <dynamic, dynamic>{};
      final List<Map<String, dynamic>> loadedFriends = [];

      for (var entry in data.entries) {
        final friendId = entry.key.toString();
        // final friendData = entry.value as Map<dynamic, dynamic>? ?? {}; // We don't really need friendData for favorite anymore if we sort by recency

        // Fetch house info
        final houseSnap = await _dbRef.child('houses/$friendId/settings').get();
        String name = 'Ngôi nhà $friendId';
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
        final lastMsgSnap =
            await _dbRef.child('chats/$roomId/lastMessage/ts').get();
        int lastTs = 0;
        if (lastMsgSnap.exists) {
          lastTs = int.tryParse(lastMsgSnap.value.toString()) ?? 0;
        }

        try {
          await _socialService.assertCanInteractWithHouse(
            myHouseId: widget.myHouseId,
            targetHouseId: friendId,
          );
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
          .streamGroupsForHouse(widget.myHouseId)
          .first;
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

  void _copyToClipboard() {
    final text = '${widget.contentToShare}\n${widget.shareUrl}'.trim();
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép nội dung.')),
    );
  }

  String _composeShareMessage() {
    final lines = <String>[
      'Mình vừa chia sẻ một nội dung từ Cộng đồng:',
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
      await _chatService.sendMessage(
        widget.myHouseId,
        friendId,
        message,
        type: 'share',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi nội dung chia sẻ.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Chưa thể gửi nội dung chia sẻ lúc này. Vui lòng thử lại.'),
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
      await _groupChatService.sendGroupMessage(
        groupId: group.id,
        senderHouseId: widget.myHouseId,
        text: (payload['text'] ?? '').toString(),
        type: (payload['type'] ?? 'share').toString(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi nội dung chia sẻ vào nhóm.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể gửi vào nhóm lúc này. Vui lòng thử lại.'),
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

    final sheetHeight = (screenHeight * 0.86).clamp(320.0, screenHeight);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: textScaler),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(
                    vertical: SLResponsive.dp(12, screenWidth),
                  ),
                  width: SLResponsive.dp(40, screenWidth),
                  height: SLResponsive.dp(5, screenWidth, min: 0.9, max: 1.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: SLRadius.smAll,
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
                            title: 'Gửi đến',
                            subtitle: 'Bạn bè trò chuyện gần đây',
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
                                        color: Colors.grey[200],
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
                                        color: Colors.grey[200],
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
                              title: 'Chưa có bạn bè để chia sẻ',
                              subtitle:
                                  'Khi có cuộc trò chuyện phù hợp, mục này sẽ hiện ngay ở đây.',
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
                            title: 'Gửi vào nhóm',
                            subtitle: 'Nhóm bạn vẫn còn là thành viên',
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
                              title: 'Chưa có nhóm phù hợp để chia sẻ',
                              subtitle:
                                  'Chỉ các nhóm còn quyền tham gia mới xuất hiện trong danh sách này.',
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
                          title: 'Chia sẻ qua',
                          subtitle: 'Ứng dụng bên ngoài và sao chép nhanh',
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
                              icon: Icons.message_rounded,
                              label: 'Zalo',
                              color: const Color(0xFF0068FF),
                              onTap: _shareToExternal,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Icons.copy_all_rounded,
                              label: 'Sao chép',
                              color: Colors.blueGrey,
                              onTap: _copyToClipboard,
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Icons.share_rounded,
                              label: 'Khác',
                              color: Colors.grey,
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(SLResponsive.dp(20, screenWidth)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: SLResponsive.dp(compact ? 38 : 42, screenWidth),
            height: SLResponsive.dp(compact ? 38 : 42, screenWidth),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(SLResponsive.dp(14, screenWidth)),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF64748B),
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
        SLResponsive.dp(compact ? 14 : 16, screenWidth),
        SLResponsive.dp(compact ? 13 : 14, screenWidth),
        SLResponsive.dp(compact ? 14 : 16, screenWidth),
        SLResponsive.dp(compact ? 13 : 14, screenWidth),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4F8), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SLResponsive.dp(22, screenWidth)),
        border: Border.all(color: const Color(0xFFFFD8E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
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
              color: const Color(0xFFD81B60).withOpacity(0.12),
              borderRadius: BorderRadius.circular(SLResponsive.dp(16, screenWidth)),
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
                Text(
                  'Nội dung bạn đang chia sẻ',
                  style: SLTheme.quicksand(
                    fontSize: SLResponsive.sp(compact ? 12.2 : 12.8, screenWidth),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                SizedBox(height: SLResponsive.dp(6, screenWidth)),
                Text(
                  previewText.isEmpty ? 'Chưa có nội dung hiển thị.' : previewText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: SLResponsive.sp(compact ? 12.4 : 13, screenWidth),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    height: 1.35,
                  ),
                ),
                if (previewUrl.isNotEmpty) ...[
                  SizedBox(height: SLResponsive.dp(8, screenWidth)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: SLResponsive.dp(10, screenWidth),
                      vertical: SLResponsive.dp(7, screenWidth),
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
                          size: SLResponsive.dp(15, screenWidth),
                          color: const Color(0xFF64748B),
                        ),
                        SizedBox(width: SLResponsive.dp(6, screenWidth)),
                        Expanded(
                          child: Text(
                            previewUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: SLResponsive.sp(11.4, screenWidth),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: isSending ? 0.62 : 1,
        child: Container(
          width: blockWidth,
          margin: EdgeInsets.symmetric(
            horizontal: SLResponsive.dp(6, screenWidth, min: 0.9, max: 1.0),
          ),
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
            borderRadius: BorderRadius.circular(SLResponsive.dp(22, screenWidth)),
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
                      borderRadius: BorderRadius.circular(SLResponsive.dp(20, screenWidth)),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SLResponsive.dp(18, screenWidth)),
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      color: accentColor.withValues(alpha: 0.12),
                      child: avatarUrl.trim().isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                icon,
                                color: accentColor,
                              ),
                            )
                          : Icon(
                              icon,
                              color: accentColor,
                              size: SLResponsive.dp(compact ? 24 : 27, screenWidth),
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
                                SLResponsive.dp(4, screenWidth, min: 0.9, max: 1.0),
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
                  fontSize: SLResponsive.sp(compact ? 11.2 : 11.8, screenWidth),
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
    );
  }

  Widget _buildExternalShareItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool compact,
    required double screenWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: SLResponsive.dp(compact ? 66 : 70, screenWidth),
        margin: EdgeInsets.symmetric(
          horizontal: SLResponsive.dp(6, screenWidth, min: 0.9, max: 1.0),
        ),
        child: Column(
          children: [
            Container(
              width: SLResponsive.dp(compact ? 46 : 50, screenWidth),
              height: SLResponsive.dp(compact ? 46 : 50, screenWidth),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: SLResponsive.dp(compact ? 22 : 24, screenWidth),
              ),
            ),
            SizedBox(height: SLResponsive.dp(8, screenWidth)),
            Text(
              label,
              style: SLTheme.quicksand(
                fontSize: SLResponsive.sp(compact ? 11.5 : 12, screenWidth),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
