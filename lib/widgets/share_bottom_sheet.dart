import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

const _zaloSvg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12.49 10.2722v-.4496h1.3467v6.3218h-.7704a.576.576 0 01-.5763-.5729l-.0006.0005a3.273 3.273 0 01-1.9372.6321c-1.8138 0-3.2844-1.4697-3.2844-3.2823 0-1.8125 1.4706-3.2822 3.2844-3.2822a3.273 3.273 0 011.9372.6321l.0006.0005zM6.9188 7.7896v.205c0 .3823-.051.6944-.2995 1.0605l-.03.0343c-.0542.0615-.1815.206-.2421.2843L2.024 14.8h4.8948v.7682a.5764.5764 0 01-.5767.5761H0v-.3622c0-.4436.1102-.6414.2495-.8476L4.8582 9.23H.1922V7.7896h6.7266zm8.5513 8.3548a.4805.4805 0 01-.4803-.4798v-7.875h1.4416v8.3548H15.47zM20.6934 9.6C22.52 9.6 24 11.0807 24 12.9044c0 1.8252-1.4801 3.306-3.3066 3.306-1.8264 0-3.3066-1.4808-3.3066-3.306 0-1.8237 1.4802-3.3044 3.3066-3.3044zm-10.1412 5.253c1.0675 0 1.9324-.8645 1.9324-1.9312 0-1.065-.865-1.9295-1.9324-1.9295s-1.9324.8644-1.9324 1.9295c0 1.0667.865 1.9312 1.9324 1.9312zm10.1412-.0033c1.0737 0 1.945-.8707 1.945-1.9453 0-1.073-.8713-1.9436-1.945-1.9436-1.0753 0-1.945.8706-1.945 1.9436 0 1.0746.8697 1.9453 1.945 1.9453z"/></svg>';
const _fbSvg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325a8.623 8.623 0 0 0-.653-.036 26.805 26.805 0 0 0-.733-.009c-.707 0-1.259.096-1.675.309a1.686 1.686 0 0 0-.679.622c-.258.42-.374.995-.374 1.752v1.297h3.919l-.386 2.103-.287 1.564h-3.246v8.245C19.396 23.238 24 18.179 24 12.044c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.628 3.874 10.35 9.101 11.647Z"/></svg>';
const _messengerSvg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 0C5.24 0 0 4.952 0 11.64c0 3.499 1.434 6.521 3.769 8.61a.96.96 0 0 1 .323.683l.065 2.135a.96.96 0 0 0 1.347.85l2.381-1.053a.96.96 0 0 1 .641-.046A13 13 0 0 0 12 23.28c6.76 0 12-4.952 12-11.64S18.76 0 12 0m6.806 7.44c.522-.03.971.567.63 1.094l-4.178 6.457a.707.707 0 0 1-.977.208l-3.87-2.504a.44.44 0 0 0-.49.007l-4.363 3.01c-.637.438-1.415-.317-.995-.966l4.179-6.457a.706.706 0 0 1 .977-.21l3.87 2.505c.15.097.344.094.491-.007l4.362-3.008a.7.7 0 0 1 .364-.13"/></svg>';
const _instagramSvg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M7.0301.084c-1.2768.0602-2.1487.264-2.911.5634-.7888.3075-1.4575.72-2.1228 1.3877-.6652.6677-1.075 1.3368-1.3802 2.127-.2954.7638-.4956 1.6365-.552 2.914-.0564 1.2775-.0689 1.6882-.0626 4.947.0062 3.2586.0206 3.6671.0825 4.9473.061 1.2765.264 2.1482.5635 2.9107.308.7889.72 1.4573 1.388 2.1228.6679.6655 1.3365 1.0743 2.1285 1.38.7632.295 1.6361.4961 2.9134.552 1.2773.056 1.6884.069 4.9462.0627 3.2578-.0062 3.668-.0207 4.9478-.0814 1.28-.0607 2.147-.2652 2.9098-.5633.7889-.3086 1.4578-.72 2.1228-1.3881.665-.6682 1.0745-1.3378 1.3795-2.1284.2957-.7632.4966-1.636.552-2.9124.056-1.2809.0692-1.6898.063-4.948-.0063-3.2583-.021-3.6668-.0817-4.9465-.0607-1.2797-.264-2.1487-.5633-2.9117-.3084-.7889-.72-1.4568-1.3876-2.1228C21.2982 1.33 20.628.9208 19.8378.6165 19.074.321 18.2017.1197 16.9244.0645 15.6471.0093 15.236-.005 11.977.0014 8.718.0076 8.31.0215 7.0301.0839m.1402 21.6932c-1.17-.0509-1.8053-.2453-2.2287-.408-.5606-.216-.96-.4771-1.3819-.895-.422-.4178-.6811-.8186-.9-1.378-.1644-.4234-.3624-1.058-.4171-2.228-.0595-1.2645-.072-1.6442-.079-4.848-.007-3.2037.0053-3.583.0607-4.848.05-1.169.2456-1.805.408-2.2282.216-.5613.4762-.96.895-1.3816.4188-.4217.8184-.6814 1.3783-.9003.423-.1651 1.0575-.3614 2.227-.4171 1.2655-.06 1.6447-.072 4.848-.079 3.2033-.007 3.5835.005 4.8495.0608 1.169.0508 1.8053.2445 2.228.408.5608.216.96.4754 1.3816.895.4217.4194.6816.8176.9005 1.3787.1653.4217.3617 1.056.4169 2.2263.0602 1.2655.0739 1.645.0796 4.848.0058 3.203-.0055 3.5834-.061 4.848-.051 1.17-.245 1.8055-.408 2.2294-.216.5604-.4763.96-.8954 1.3814-.419.4215-.8181.6811-1.3783.9-.4224.1649-1.0577.3617-2.2262.4174-1.2656.0595-1.6448.072-4.8493.079-3.2045.007-3.5825-.006-4.848-.0608M16.953 5.5864A1.44 1.44 0 1 0 18.39 4.144a1.44 1.44 0 0 0-1.437 1.4424M5.8385 12.012c.0067 3.4032 2.7706 6.1557 6.173 6.1493 3.4026-.0065 6.157-2.7701 6.1506-6.1733-.0065-3.4032-2.771-6.1565-6.174-6.1498-3.403.0067-6.156 2.771-6.1496 6.1738M8 12.0077a4 4 0 1 1 4.008 3.9921A3.9996 3.9996 0 0 1 8 12.0077"/></svg>';
const _telegramSvg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>';

Widget _buildModernSocialIcon({
  required double size,
  required String svgData,
  Gradient? customGradient,
  List<Color>? fallbackColors,
}) {
  final gradient = customGradient ?? LinearGradient(
    colors: fallbackColors ?? [Colors.grey, Colors.grey],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.28),
      gradient: gradient,
      boxShadow: [
        BoxShadow(
          color: gradient.colors.last.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: SvgPicture.string(
      svgData,
      width: size * 0.55,
      height: size * 0.55,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    ),
  );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.shareUrl.trim().isNotEmpty) {
        Clipboard.setData(ClipboardData(text: '${widget.contentToShare}\n${widget.shareUrl}'.trim()));
        ScaffoldMessenger.of(context).showSnackBar(
          _buildFeedbackSnackBar(
            message: L10nService().translate('share_copied'),
            icon: Icons.check_circle_rounded,
            accentColor: const Color(0xFF0F9D58),
          ),
        );
      }
    });
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
    // ignore: deprecated_member_use
    Share.share(text, sharePositionOrigin: rect);
    Navigator.pop(context);
  }

  void _shareToSpecific(String platform) async {
    final link = Uri.encodeComponent(widget.shareUrl.trim());
    final text = Uri.encodeComponent('${widget.contentToShare}\n${widget.shareUrl}'.trim());
    String urlStr = '';
    
    switch (platform) {
      case 'Facebook':
        urlStr = 'https://www.facebook.com/sharer/sharer.php?u=$link';
        break;
      case 'Messenger':
        urlStr = 'fb-messenger://share?link=$link';
        break;
      case 'Zalo':
        urlStr = 'https://zalo.me/share?url=$link';
        break;
      case 'Telegram':
        urlStr = 'tg://msg?text=$text';
        break;
      case 'Instagram':
        _copyToClipboard();
        urlStr = 'instagram://app';
        break;
      case 'SMS':
        urlStr = 'sms:?body=$text';
        break;
      default:
        _shareToExternal();
        return;
    }
    
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) Navigator.pop(context);
      } else {
        _shareToExternal();
      }
    } catch (_) {
      _shareToExternal();
    }
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
                            borderRadius: BorderRadius.all(Radius.circular(14)),
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
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFFCE7F3),
                                            Color(0xFFF8FAFC),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.all(Radius.circular(14)),
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
                              icon: _buildModernSocialIcon(
                                size: SLResponsive.dp(compact ? 48 : 52, screenWidth),
                                svgData: _zaloSvg,
                                fallbackColors: const [Color(0xFF00B2FF), Color(0xFF0068FF)],
                              ),
                              label: 'Zalo',
                              onTap: () => _shareToSpecific('Zalo'),
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: _buildModernSocialIcon(
                                size: SLResponsive.dp(compact ? 48 : 52, screenWidth),
                                svgData: _fbSvg,
                                fallbackColors: const [Color(0xFF1877F2), Color(0xFF0C56B6)],
                              ),
                              label: 'Facebook',
                              onTap: () => _shareToSpecific('Facebook'),
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: _buildModernSocialIcon(
                                size: SLResponsive.dp(compact ? 48 : 52, screenWidth),
                                svgData: _messengerSvg,
                                fallbackColors: const [
                                  Color(0xFF00B2FF),
                                  Color(0xFF006AFF),
                                  Color(0xFFA100FF),
                                  Color(0xFFFF2E93),
                                ],
                              ),
                              label: 'Messenger',
                              onTap: () => _shareToSpecific('Messenger'),
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: _buildModernSocialIcon(
                                size: SLResponsive.dp(compact ? 48 : 52, screenWidth),
                                svgData: _instagramSvg,
                                customGradient: const RadialGradient(
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
                              label: 'Instagram',
                              onTap: () => _shareToSpecific('Instagram'),
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: _buildModernSocialIcon(
                                size: SLResponsive.dp(compact ? 48 : 52, screenWidth),
                                svgData: _telegramSvg,
                                fallbackColors: const [Color(0xFF24A1DE), Color(0xFF1E88BE)],
                              ),
                              label: 'Telegram',
                              onTap: () => _shareToSpecific('Telegram'),
                              compact: compact,
                              screenWidth: screenWidth,
                            ),
                            _buildExternalShareItem(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
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
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
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
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
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
            borderRadius: BorderRadius.all(Radius.circular(14)),
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
              borderRadius: const BorderRadius.all(Radius.circular(14)),
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
                            borderRadius: const BorderRadius.all(Radius.circular(14)),
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
                                    filterQuality: FilterQuality.medium,
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
                              borderRadius: const BorderRadius.all(Radius.circular(14)),
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
                    borderRadius: BorderRadius.all(Radius.circular(14)),
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
