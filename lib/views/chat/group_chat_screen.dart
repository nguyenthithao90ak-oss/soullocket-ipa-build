import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/services/admob_service.dart';
import '../../utils/services/l10n_service.dart';

import '../../core/sl_theme.dart';
import '../../models/chat_message.dart';
import '../../models/group_chat_room.dart';
import '../../utils/services/group_chat_service.dart';
import '../../utils/services/security_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/rapid_action_feedback_policy.dart';
import 'chat_house_info_loader.dart';

class GroupChatScreen extends StatefulWidget {
  final String myHouseId;
  final GroupChatRoom initialRoom;

  const GroupChatScreen({
    super.key,
    required this.myHouseId,
    required this.initialRoom,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final GroupChatService _groupChatService = GroupChatService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();

  static const int _chatPageSize = 40;

  final List<ChatMessage> _messages = <ChatMessage>[];
  final Set<String> _messageIds = <String>{};
  final Map<String, Map<dynamic, dynamic>> _housesInfo =
      <String, Map<dynamic, dynamic>>{};

  StreamSubscription<GroupChatRoom?>? _roomSub;
  StreamSubscription<ChatMessage>? _liveMessageSub;

  GroupChatRoom? _room;
  bool _isInitialMessagesLoading = true;
  bool _isLoadingOlderMessages = false;
  bool _hasMoreMessages = true;
  bool _hasComposerText = false;
  bool _isGroupMuted = false;
  int? _oldestMessageTs;
  int? _newestMessageTs;

  String get _groupId => widget.initialRoom.id;
  String get _mutePrefsKey => 'group_chat_muted_$_groupId';

  String _tr(String key) => context.tr(key);

  String _trFormat(String key, Map<String, Object?> params) =>
      L10nScope.of(context).format(key, params);

  bool _isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _pageBackground(BuildContext context) =>
      _isDarkMode(context) ? SLColors.darkBgMain : const Color(0xFFF8FAFC);

  Color _surfaceColor(BuildContext context) =>
      _isDarkMode(context) ? SLColors.darkBgCard : Colors.white;

  Color _elevatedSurfaceColor(BuildContext context) =>
      _isDarkMode(context) ? SLColors.darkBgElevated : const Color(0xFFF8FAFC);

  Color _borderColor(BuildContext context) =>
      _isDarkMode(context) ? SLColors.darkBorder : const Color(0xFFE2E8F0);

  Color _primaryTextColor(BuildContext context) =>
      _isDarkMode(context) ? SLColors.darkTextPrimary : SLColors.darkNavy;

  Color _secondaryTextColor(BuildContext context) =>
      _isDarkMode(context) ? SLColors.darkTextSecond : const Color(0xFF64748B);

  double _messageMaxWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.78).clamp(0.0, 420.0).toDouble();

  @override
  void initState() {
    super.initState();
    AdMobService().suppressAutoInterstitial();
    _room = widget.initialRoom;
    _msgController.addListener(_handleComposerTextChanged);
    _messagesScrollController.addListener(_handleMessageScroll);
    _roomSub = _groupChatService.streamGroupRoom(_groupId).listen((room) {
      if (!mounted || room == null) {
        return;
      }
      if (_sameGroupRoom(_room, room)) {
        return;
      }
      unawaited(_loadHousesInfo(room.memberHouseIds));
      setState(() {
        _room = room;
      });
    });
    unawaited(_loadMutedPref());
    unawaited(_loadHousesInfo(widget.initialRoom.memberHouseIds));
    unawaited(_loadInitialMessages());
  }

  @override
  void dispose() {
    AdMobService().resumeAutoInterstitial();
    _roomSub?.cancel();
    _liveMessageSub?.cancel();
    _msgController.removeListener(_handleComposerTextChanged);
    _msgController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMutedPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final muted = prefs.getBool(_mutePrefsKey) ?? false;
    if (_isGroupMuted == muted) {
      return;
    }
    setState(() {
      _isGroupMuted = muted;
    });
  }

  Future<void> _saveMutedPref(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutePrefsKey, muted);
  }

  Future<void> _loadHousesInfo(List<String> houseIds) async {
    final missing = houseIds
        .where((houseId) => !_housesInfo.containsKey(houseId))
        .toList(growable: false);
    if (missing.isEmpty) {
      return;
    }

    final entries = await Future.wait(
      missing.map(
        (houseId) async => MapEntry(houseId, await _fetchHouseInfo(houseId)),
      ),
    );
    final loaded = Map<String, Map<dynamic, dynamic>>.fromEntries(entries);

    if (!mounted) {
      return;
    }
    setState(() {
      _housesInfo.addAll(loaded);
    });
  }

  Future<Map<dynamic, dynamic>> _fetchHouseInfo(String houseId) async {
    return loadChatHouseInfo(_dbRef, houseId);
  }

  String _houseName(String houseId) {
    final info = _housesInfo[houseId];
    final houseName = info?['houseName']?.toString().trim() ?? '';
    if (houseName.isNotEmpty) {
      return houseName;
    }
    final nameU1 = info?['nameU1']?.toString().trim() ?? '';
    final nameU2 = info?['nameU2']?.toString().trim() ?? '';
    if (nameU1.isNotEmpty || nameU2.isNotEmpty) {
      return [nameU1, nameU2].where((item) => item.isNotEmpty).join(' • ');
    }
    return houseId == widget.myHouseId
        ? _tr('p9_group_chat_your_house')
        : _trFormat('p9_group_chat_house_fallback', <String, Object?>{
            'houseId': houseId,
          });
  }

  String _houseAvatar(String houseId) {
    final info = _housesInfo[houseId];
    return info?['houseAvatar']?.toString().trim() ??
        info?['avatar']?.toString().trim() ??
        info?['avtUser1']?.toString().trim() ??
        '';
  }

  bool _sameGroupRoom(GroupChatRoom? left, GroupChatRoom? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return left == right;
    if (left.id != right.id ||
        left.name != right.name ||
        left.createdAtMs != right.createdAtMs ||
        left.updatedAtMs != right.updatedAtMs ||
        left.createdByHouseId != right.createdByHouseId ||
        left.createdByUid != right.createdByUid) {
      return false;
    }
    final leftMembers = left.memberHouseIds;
    final rightMembers = right.memberHouseIds;
    if (leftMembers.length != rightMembers.length) {
      return false;
    }
    for (var index = 0; index < leftMembers.length; index++) {
      if (leftMembers[index] != rightMembers[index]) {
        return false;
      }
    }
    final leftLast = left.lastMessage;
    final rightLast = right.lastMessage;
    if (leftLast == null || rightLast == null) {
      return leftLast == rightLast;
    }
    if (leftLast.length != rightLast.length) {
      return false;
    }
    for (final entry in leftLast.entries) {
      if (rightLast[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Future<void> _sendMsg() async {
    final room = _room;
    final text = _msgController.text.trim();
    if (room == null || text.isEmpty) {
      return;
    }
    if (!_groupChatService.isHouseMemberOfGroup(room, widget.myHouseId)) {
      _showNotice(_tr('p9_group_chat_not_member'), error: true);
      return;
    }
    if (!await SecurityService().guardAction(
      context,
      'group_chat_send_message',
      content: text,
    )) {
      return;
    }

    try {
      await _groupChatService.sendGroupMessage(
        groupId: room.id,
        senderHouseId: widget.myHouseId,
        text: text,
      );
      _msgController.clear();
    } catch (error) {
      if (isSilentRapidActionBlock(error)) {
        return;
      }
      _showNotice(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: _tr('p9_group_chat_send_failed'),
        ).message,
        error: true,
      );
    }
  }

  void _handleComposerTextChanged() {
    final nextValue = _msgController.text.trim().isNotEmpty;
    if (_hasComposerText == nextValue || !mounted) {
      return;
    }
    setState(() {
      _hasComposerText = nextValue;
    });
  }

  void _handleMessageScroll() {
    if (!_messagesScrollController.hasClients ||
        _isLoadingOlderMessages ||
        !_hasMoreMessages) {
      return;
    }
    if (_messagesScrollController.position.pixels >=
        _messagesScrollController.position.maxScrollExtent - 220) {
      unawaited(_loadOlderMessages());
    }
  }

  int _compareMessageOrder(ChatMessage left, ChatMessage right) {
    final byTime = right.timestamp.compareTo(left.timestamp);
    if (byTime != 0) {
      return byTime;
    }
    return right.id.compareTo(left.id);
  }

  int _findMessageInsertIndex(ChatMessage message) {
    var low = 0;
    var high = _messages.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_compareMessageOrder(message, _messages[mid]) < 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  void _replaceMessageState(List<ChatMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    _messageIds
      ..clear()
      ..addAll(messages.map((message) => message.id));
    _newestMessageTs = _messages.isEmpty
        ? null
        : _messages.first.timestamp.millisecondsSinceEpoch;
    _oldestMessageTs = _messages.isEmpty
        ? null
        : _messages.last.timestamp.millisecondsSinceEpoch;
    if (mounted) {
      setState(() {});
    }
  }

  void _upsertLiveMessage(ChatMessage message) {
    final existingIndex = _messages.indexWhere((item) => item.id == message.id);
    if (existingIndex >= 0) {
      final current = _messages[existingIndex];
      if (current.id == message.id &&
          current.text == message.text &&
          current.timestamp == message.timestamp &&
          current.senderId == message.senderId &&
          current.type == message.type) {
        return;
      }
      _messages.removeAt(existingIndex);
    } else {
      _messageIds.add(message.id);
    }
    _messages.insert(_findMessageInsertIndex(message), message);
    _newestMessageTs = _messages.isEmpty
        ? null
        : _messages.first.timestamp.millisecondsSinceEpoch;
    _oldestMessageTs = _messages.isEmpty
        ? null
        : _messages.last.timestamp.millisecondsSinceEpoch;
  }

  Future<void> _loadInitialMessages() async {
    if (!_isInitialMessagesLoading) {
      setState(() {
        _isInitialMessagesLoading = true;
      });
    }
    try {
      final page = await _groupChatService.fetchGroupMessagesPage(
        _groupId,
        viewerHouseId: widget.myHouseId,
        limit: _chatPageSize,
      );
      if (!mounted) {
        return;
      }
      _replaceMessageState(page);
      _hasMoreMessages = page.length >= _chatPageSize;
    } catch (_) {
      if (!mounted) {
        return;
      }
      _replaceMessageState(const <ChatMessage>[]);
      _hasMoreMessages = false;
    } finally {
      _listenForNewMessages();
      if (mounted) {
        setState(() {
          _isInitialMessagesLoading = false;
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final cursor = _oldestMessageTs;
    if (cursor == null) {
      _hasMoreMessages = false;
      return;
    }

    setState(() {
      _isLoadingOlderMessages = true;
    });
    try {
      final older = await _groupChatService.fetchGroupMessagesPage(
        _groupId,
        viewerHouseId: widget.myHouseId,
        limit: _chatPageSize,
        beforeTs: cursor,
      );
      if (!mounted) {
        return;
      }
      if (older.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingOlderMessages = false;
        });
        return;
      }

      final merged = <ChatMessage>[..._messages];
      for (final message in older) {
        if (_messageIds.add(message.id)) {
          merged.add(message);
        }
      }
      merged.sort(_compareMessageOrder);

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
        _newestMessageTs = _messages.isEmpty
            ? null
            : _messages.first.timestamp.millisecondsSinceEpoch;
        _oldestMessageTs = _messages.isEmpty
            ? null
            : _messages.last.timestamp.millisecondsSinceEpoch;
        _hasMoreMessages = older.length >= _chatPageSize;
        _isLoadingOlderMessages = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingOlderMessages = false;
      });
    }
  }

  void _listenForNewMessages() {
    _liveMessageSub?.cancel();
    _liveMessageSub = _groupChatService
        .streamNewGroupMessages(
          _groupId,
          viewerHouseId: widget.myHouseId,
          afterTs: _newestMessageTs,
        )
        .listen(
          (message) {
            if (!mounted) {
              return;
            }
            setState(() {
              _upsertLiveMessage(message);
            });
          },
          onError: (error) {
            if (!mounted) {
              return;
            }
            _showNotice(
              AppErrorMapper.resolve(
                error,
                fallbackMessage: _tr('p9_group_chat_sync_failed'),
              ).message,
              error: true,
            );
            setState(() {
              _room = null;
              _hasMoreMessages = false;
            });
          },
        );
  }

  String _buildHeaderPreview() {
    final room = _room ?? widget.initialRoom;
    final otherMembers = room.memberHouseIds
        .where((houseId) => houseId != widget.myHouseId)
        .toList(growable: false);
    if (otherMembers.isEmpty) {
      return _tr('p9_group_chat_private_space');
    }
    final previewNames = otherMembers
        .take(2)
        .map(_houseName)
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);
    if (previewNames.isEmpty) {
      return _trFormat('p9_group_chat_members_chatting', <String, Object?>{
        'count': room.memberHouseIds.length,
      });
    }
    final suffix = otherMembers.length > 2
        ? _trFormat('p9_group_chat_header_more_members', <String, Object?>{
            'count': otherMembers.length - 2,
          })
        : '';
    return '${previewNames.join(' • ')}$suffix';
  }

  Future<void> _toggleGroupMute() async {
    final nextValue = !_isGroupMuted;
    if (mounted) {
      setState(() {
        _isGroupMuted = nextValue;
      });
    }
    try {
      await _saveMutedPref(nextValue);
      _showNotice(
        nextValue
            ? _tr('p9_group_chat_notifications_muted')
            : _tr('p9_group_chat_notifications_enabled'),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGroupMuted = !nextValue;
      });
      _showNotice(_tr('p9_group_chat_notification_update_failed'), error: true);
    }
  }

  Future<void> _renameGroup() async {
    final room = _room;
    if (room == null) {
      return;
    }
    final controller = TextEditingController(text: room.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_tr('p9_group_chat_rename_title')),
          content: TextField(
            controller: controller,
            maxLength: 50,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _tr('p9_group_chat_rename_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tr('p9_group_chat_cancel')),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(_tr('p9_group_chat_save')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (nextName == null || nextName.trim().isEmpty) {
      return;
    }
    try {
      await _groupChatService.renameGroup(
        groupId: room.id,
        name: nextName,
        actorHouseId: widget.myHouseId,
      );
      _showNotice(_tr('p9_group_chat_rename_success'));
    } catch (error) {
      _showNotice(_tr('p9_group_chat_rename_failed'), error: true);
    }
  }

  Future<void> _reportGroup() async {
    final reasonCtrl = TextEditingController();
    String selected = 'spam';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(_tr('p9_group_chat_report_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: [
                      DropdownMenuItem(
                        value: 'spam',
                        child: Text(_tr('p9_group_chat_report_spam')),
                      ),
                      DropdownMenuItem(
                        value: 'harassment',
                        child: Text(_tr('p9_group_chat_report_harassment')),
                      ),
                      DropdownMenuItem(
                        value: 'inappropriate_content',
                        child: Text(
                          _tr('p9_group_chat_report_inappropriate_content'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(_tr('p9_group_chat_report_other')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selected = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLength: 140,
                    decoration: InputDecoration(
                      hintText: _tr('p9_group_chat_report_note_hint'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(_tr('p9_group_chat_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final extra = reasonCtrl.text.trim();
                    Navigator.of(
                      dialogContext,
                    ).pop(extra.isEmpty ? selected : '$selected: $extra');
                  },
                  child: Text(_tr('p9_group_chat_send_report')),
                ),
              ],
            );
          },
        );
      },
    );
    reasonCtrl.dispose();
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (!await SecurityService().guardAction(context, 'group_chat_report')) {
      return;
    }
    try {
      await _groupChatService.reportGroup(
        groupId: _groupId,
        reporterHouseId: widget.myHouseId,
        reason: reason,
      );
      _showNotice(_tr('p9_group_chat_report_success'));
    } catch (error) {
      _showNotice(_tr('p9_group_chat_report_failed'), error: true);
    }
  }

  Future<void> _openSettingsSheet() async {
    final room = _room;
    if (room == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final isCompactActionLayout =
            media.size.width < 360 ||
            MediaQuery.textScalerOf(sheetContext).scale(1) > 1.15;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              media.viewInsets.bottom + 12,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: _surfaceColor(sheetContext),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _borderColor(sheetContext),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    room.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: _primaryTextColor(sheetContext),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _trFormat('p9_group_chat_members_meta', <String, Object?>{
                      'count': room.memberHouseIds.length,
                      'date': _formatDateTime(room.createdAtMs),
                    }),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isCompactActionLayout)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            await _renameGroup();
                          },
                          child: Text(_tr('p9_group_chat_rename_action')),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            await _toggleGroupMute();
                          },
                          child: Text(
                            _isGroupMuted
                                ? _tr('p9_group_chat_enable_notifications')
                                : _tr('p9_group_chat_disable_notifications'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _renameGroup();
                            },
                            child: Text(_tr('p9_group_chat_rename_action')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await _toggleGroupMute();
                            },
                            child: Text(
                              _isGroupMuted
                                  ? _tr('p9_group_chat_enable_notifications')
                                  : _tr('p9_group_chat_disable_notifications'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _reportGroup();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      child: Text(_tr('p9_group_chat_report_title')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _tr('p9_group_chat_members_title'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _primaryTextColor(sheetContext),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: media.size.height * 0.42,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: room.memberHouseIds.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final houseId = room.memberHouseIds[index];
                        final isMine = houseId == widget.myHouseId;
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _elevatedSurfaceColor(sheetContext),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _borderColor(sheetContext),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildAvatarBubble(
                                avatarUrl: _houseAvatar(houseId),
                                label: _houseName(houseId),
                                radius: 20,
                                borderColor: const Color(0xFFFFD9E6),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _houseName(houseId),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                    color: _primaryTextColor(sheetContext),
                                  ),
                                ),
                              ),
                              Icon(
                                isMine
                                    ? Icons.home_rounded
                                    : Icons.groups_rounded,
                                size: 18,
                                color: isMine
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFFD81B60),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNotice(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFD81B60) : null,
      ),
    );
  }

  String _formatDateTime(int value) {
    if (value <= 0) {
      return '--/-- • --:--';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm • $hh:$min';
  }

  Widget _buildAvatarBubble({
    required String avatarUrl,
    required String label,
    required double radius,
    required Color borderColor,
  }) {
    final trimmedAvatar = avatarUrl.trim();
    final displayLabel = label.trim().isNotEmpty ? label.trim() : '?';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: ClipOval(
        child: trimmedAvatar.isNotEmpty
            ? Image(
                image: CachedNetworkImageProvider(trimmedAvatar),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildAvatarFallback(displayLabel),
              )
            : _buildAvatarFallback(displayLabel),
      ),
    );
  }

  Widget _buildAvatarFallback(String label) {
    return Container(
      color: _isDarkMode(context)
          ? SLColors.darkBgElevated
          : const Color(0xFFFFF1F6),
      alignment: Alignment.center,
      child: Text(
        label.substring(0, 1).toUpperCase(),
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w900,
          color: const Color(0xFFD81B60),
        ),
      ),
    );
  }

  Widget _buildGroupAvatarCluster(GroupChatRoom room) {
    final orderedMembers = <String>[
      if (room.memberHouseIds.contains(widget.myHouseId)) widget.myHouseId,
      ...room.memberHouseIds.where((houseId) => houseId != widget.myHouseId),
    ];
    final members = orderedMembers.take(3).toList(growable: false);
    if (members.isEmpty) {
      return SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          children: [
            _buildAvatarBubble(
              avatarUrl: '',
              label: room.name,
              radius: 24,
              borderColor: const Color(0xFFFFD9E6),
            ),
          ],
        ),
      );
    }
    final hasExtraMembers = room.memberHouseIds.length > members.length;
    return SizedBox(
      width: hasExtraMembers ? 74 : 68,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < members.length; index++)
            Positioned(
              left: (index * 21).toDouble(),
              top: index == 1 ? 0 : 6,
              child: _buildAvatarBubble(
                avatarUrl: _houseAvatar(members[index]),
                label: _houseName(members[index]),
                radius: 18,
                borderColor: members[index] == widget.myHouseId
                    ? const Color(0xFFF9A8D4)
                    : const Color(0xFFFFD1E1),
              ),
            ),
          if (hasExtraMembers)
            Positioned(
              right: 0,
              bottom: 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFD81B60),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${room.memberHouseIds.length - members.length}',
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isInitialMessagesLoading) {
      return Center(
        child: Semantics(
          label: _tr('p9_group_chat_loading_messages'),
          liveRegion: true,
          child: const CircularProgressIndicator(color: Color(0xFFD81B60)),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: _isDarkMode(context)
                      ? SLColors.darkBgElevated
                      : const Color(0xFFFFF1F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 36,
                  color: Color(0xFFD81B60),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _tr('p9_group_chat_empty_title'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _primaryTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tr('p9_group_chat_empty_description'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: _secondaryTextColor(context),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final itemCount = _messages.length + (_isLoadingOlderMessages ? 1 : 0);
    return ListView.builder(
      controller: _messagesScrollController,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      reverse: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (_isLoadingOlderMessages && index == _messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(
              label: _tr('p9_group_chat_loading_older_messages'),
              liveRegion: true,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFFD81B60),
                  ),
                ),
              ),
            ),
          );
        }
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isSystem = message.senderId == 'system';
    final isMe = !isSystem && message.senderId == widget.myHouseId;
    final senderName = isSystem
        ? _tr('p9_group_chat_system_sender')
        : _houseName(message.senderId);
    final timeLabel = DateFormat('HH:mm').format(message.timestamp);
    final bubbleColor = isMe ? const Color(0xFFD81B60) : _surfaceColor(context);
    final textColor = isMe ? Colors.white : _primaryTextColor(context);

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isDarkMode(context)
                  ? SLColors.darkBgElevated
                  : const Color(0xFFFFF1F6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _isDarkMode(context)
                    ? SLColors.darkBorder
                    : const Color(0xFFFFD9E6),
              ),
            ),
            child: Text(
              message.text.trim().isEmpty
                  ? _tr('p9_group_chat_created')
                  : message.text,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: const Color(0xFFD81B60),
              ),
            ),
          ),
        ),
      );
    }

    if (message.type == 'share') {
      return _buildShareMessageBubble(
        message: message,
        isMe: isMe,
        senderName: senderName,
        timeLabel: timeLabel,
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _messageMaxWidth(context)),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    senderName,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 18),
                  ),
                  border: Border.all(
                    color: isMe
                        ? const Color(0xFFD81B60)
                        : _borderColor(context),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.text,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        fontSize: message.type == 'sticker' ? 30 : 14,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.78)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareMessageBubble({
    required ChatMessage message,
    required bool isMe,
    required String senderName,
    required String timeLabel,
  }) {
    final lines = message.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final title = lines.isNotEmpty
        ? lines.first
        : _tr('p9_group_chat_share_fallback');
    final body = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _messageMaxWidth(context)),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    senderName,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isDarkMode(context)
                        ? const [SLColors.darkBgElevated, SLColors.darkBgCard]
                        : isMe
                        ? const [Color(0xFFFFF1F6), Color(0xFFFFFFFF)]
                        : const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isMe ? 22 : 8),
                    bottomRight: Radius.circular(isMe ? 8 : 22),
                  ),
                  border: Border.all(
                    color: _isDarkMode(context)
                        ? SLColors.darkBorder
                        : const Color(0xFFFFD9E6),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.share_rounded,
                            color: Color(0xFFD81B60),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _tr('p9_group_chat_shared_from_community'),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                              color: const Color(0xFFD81B60),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.2,
                        color: _primaryTextColor(context),
                        height: 1.3,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isDarkMode(context)
                              ? SLColors.darkBgCard
                              : Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderColor(context)),
                        ),
                        child: Text(
                          body,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: _secondaryTextColor(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        timeLabel,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          color: _secondaryTextColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final canSend =
        _room != null &&
        _groupChatService.isHouseMemberOfGroup(_room!, widget.myHouseId);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _elevatedSurfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor(context)),
                ),
                child: TextField(
                  controller: _msgController,
                  enabled: canSend,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: SLTheme.quicksand(
                    color: _primaryTextColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: canSend
                        ? _tr('p9_group_chat_composer_hint')
                        : _tr('p9_group_chat_not_member_hint'),
                    hintStyle: SLTheme.quicksand(
                      color: _secondaryTextColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMsg(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: _tr('p9_group_chat_send_message'),
              button: true,
              enabled: canSend,
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkResponse(
                  onTap: canSend ? _sendMsg : null,
                  radius: 26,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _hasComposerText
                          ? const Color(0xFFD81B60)
                          : _isDarkMode(context)
                          ? SLColors.darkBgElevated
                          : const Color(0xFFF8BBD0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room ?? widget.initialRoom;
    return Scaffold(
      backgroundColor: _pageBackground(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _tr('p9_group_chat_back'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: _primaryTextColor(context),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  _buildGroupAvatarCluster(room),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: _primaryTextColor(context),
                            fontSize: 16.4,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _buildHeaderPreview(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  color: _secondaryTextColor(context),
                                  fontSize: 11.6,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _elevatedSurfaceColor(context),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${room.memberHouseIds.length}',
                                style: SLTheme.quicksand(
                                  color: _secondaryTextColor(context),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: _tr('p9_group_chat_group_settings'),
                    button: true,
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkResponse(
                          onTap: _openSettingsSheet,
                          radius: 24,
                          customBorder: const CircleBorder(),
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _elevatedSurfaceColor(context),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                                color: _secondaryTextColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildInputArea(),
        ],
      ),
    );
  }
}
