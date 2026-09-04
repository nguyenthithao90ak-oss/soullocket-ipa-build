import 'dart:async';
import 'dart:convert';

import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/auth/auth_house_context_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/services/offline_cache_service.dart';
import '../../utils/services/admob_service.dart';

import '../../models/group_chat_room.dart';
import '../../models/chat_group_draft.dart';
import '../../utils/services/presence_service.dart';
import '../../utils/services/chat_service.dart';
import '../../utils/services/group_chat_service.dart';
import '../../utils/app_error_mapper.dart';
import 'chat_house_info_loader.dart';
import 'chat_detail_screen.dart';
import 'chat_message_preview.dart';
import 'group_chat_screen.dart';
import '../../core/sl_theme.dart';
import '../../core/sl_route.dart';

part 'messenger/messenger_search_filter_part.dart';
part 'messenger/messenger_room_list_part.dart';
part 'messenger/messenger_group_section_part.dart';
part 'messenger/messenger_empty_loading_part.dart';
part 'messenger/messenger_inline_actions_part.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ChatService _chatService = ChatService();
  final GroupChatService _groupChatService = GroupChatService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String? _myHouseId;
  String _myRole = 'user1';
  String _searchQuery = '';
  List<String> _friends = [];
  Map<dynamic, dynamic> _myHouseInfo = {};
  final Map<String, Map<dynamic, dynamic>> _housesInfo = {};
  StreamSubscription<DatabaseEvent>? _friendsSub;
  StreamSubscription<DatabaseEvent>? _internalPartnerPresenceSub;
  StreamSubscription<ChatRoomMeta>? _internalRoomMetaSub;
  StreamSubscription<List<GroupChatRoom>>? _groupRoomsSub;

  Timer? _friendsRealtimeDebounce;
  Timer? _internalPartnerPresenceDebounce;
  Timer? _internalRoomMetaDebounce;
  final Map<String, Timer> _friendPresenceDebounce = {};
  final Map<String, Timer> _friendRoomMetaDebounce = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _presenceSubs = {};
  final Map<String, StreamSubscription<ChatRoomMeta>> _roomMetaSubs = {};
  final Map<String, Map<dynamic, dynamic>?> _presenceByFriendId = {};
  final Map<String, ChatRoomMeta> _roomMetaByFriendId = {};
  final Set<String> _activeRealtimeFriendIds = <String>{};
  final Map<String, Timer> _friendRealtimeReleaseTimers = <String, Timer>{};
  final Set<String> _friendIdsSet = <String>{};
  List<String> _sortedFriendsCache = const <String>[];
  bool _sortedFriendsDirty = true;
  final List<ChatGroupDraft> _groupDrafts = [];
  final List<GroupChatRoom> _groupRooms = <GroupChatRoom>[];
  Map<dynamic, dynamic>? _internalPartnerPresence;
  ChatRoomMeta _internalPartnerRoomMeta = const ChatRoomMeta();
  bool _isBootstrapping = true;
  static const Duration _friendRealtimeReleaseDelay = Duration(seconds: 5);
  static const Duration _realtimeUiDebounce = Duration(milliseconds: 140);
  static const int _friendRealtimeWarmupCount = 3;
  static const ChatMessagePreviewLabels
  _lastMessagePreviewLabels = ChatMessagePreviewLabels(
    fallback:
        'Nh\u1ea5n \u0111\u1ec3 b\u1eaft \u0111\u1ea7u tr\u00f2 chuy\u1ec7n...',
    callInvite:
        '\u0110\u00e3 b\u1eaft \u0111\u1ea7u m\u1ed9t cu\u1ed9c g\u1ecdi',
    watchInvite: '\u0110\u00e3 chia s\u1ebb ph\u00f2ng xem chung',
    image: '\u0110\u00e3 g\u1eedi m\u1ed9t h\u00ecnh \u1ea3nh',
    share: '\u0110\u00e3 chia s\u1ebb m\u1ed9t b\u00e0i vi\u1ebft',
  );
  static const String _deletedUserLabel = 'Người dùng đã xóa';

  @override
  void initState() {
    super.initState();
    AdMobService().suppressAutoInterstitial();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() {
      if (!mounted) return;
      final nextQuery = _searchCtrl.text.trim().toLowerCase();
      if (nextQuery == _searchQuery) {
        return;
      }
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || nextQuery == _searchQuery) return;
        setState(() => _searchQuery = nextQuery);
      });
    });
    unawaited(_loadMyRole());
    _loadMyHouseId();
  }

  String get _partnerRole => _myRole == 'user2' ? 'user1' : 'user2';

  Future<void> _loadMyRole() async {
    final prefs = await OfflineCacheService.getPrefs();
    final role = prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
    if (!mounted) return;
    setState(() {
      _myRole = role;
    });
    if (_myHouseId != null) {
      _listenToInternalPartnerRealtime();
    }
  }

  Future<void> _loadMyHouseId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
      return;
    }

    // Try quickHouseId cache first
    String? houseId = await AuthHouseContextService.quickHouseId();

    if (houseId == null || houseId.isEmpty) {
      // Check both houseId and legacy house_id keys
      final primarySnap = await _dbRef.child('users/$uid/houseId').get();
      houseId = primarySnap.value?.toString().trim();

      if (houseId == null || houseId.isEmpty) {
        final legacySnap = await _dbRef.child('users/$uid/house_id').get();
        houseId = legacySnap.value?.toString().trim();
        if (houseId != null && houseId.isNotEmpty) {
          await _dbRef.child('users/$uid').update({'houseId': houseId});
        }
      }

      if (houseId != null && houseId.isNotEmpty) {
        AuthHouseContextService.setMemHouseId(houseId);
      }
    }

    if (houseId == null || houseId.isEmpty) {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _myHouseId = houseId;
        _isBootstrapping = false;
      });
    }
    unawaited(_loadMyHouseInfo(houseId));
    _listenToGroupsRealtime(houseId);
    _listenToInternalPartnerRealtime();
    _listenToFriends();
  }

  Future<void> _loadMyHouseInfo(String houseId) async {
    final info = await _fetchHouseInfo(houseId);
    if (!mounted) return;
    setState(() {
      _myHouseInfo = info;
    });
  }

  void _listenToFriends() {
    if (_myHouseId == null) return;

    _friendsSub?.cancel();
    _friendsSub = _dbRef
        .child('friends/$_myHouseId')
        .onValue
        .listen(
          (event) {
            _friendsRealtimeDebounce?.cancel();
            _friendsRealtimeDebounce = Timer(_realtimeUiDebounce, () {
              if (!mounted) return;

              final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
              final ids = <String>[];

              data.forEach((key, value) {
                final friendId = key.toString();
                ids.add(friendId);
              });

              if (_sameStringList(_friends, ids)) {
                return;
              }

              final changed = !_sameStringList(_friends, ids);
              if (!changed) {
                return;
              }

              _friends = ids;
              _friendIdsSet
                ..clear()
                ..addAll(ids);
              _sortedFriendsDirty = true;
              if (mounted) {
                setState(() {});
              }
              _pruneRemovedFriendRealtime(ids);
              _warmupFriendRealtime(ids);
              _loadHousesInfo(ids);
            });
          },
          onError: (Object error) {
            debugPrint(
              'Messenger friends listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể tải danh sách bạn bè.').message}',
            );
          },
        );
  }

  Future<void> _loadHousesInfo(List<String> houseIds) async {
    final missing = houseIds
        .where((id) => !_housesInfo.containsKey(id))
        .toList();
    if (missing.isEmpty) {
      return;
    }

    final entries = await Future.wait(
      missing.map((id) async => MapEntry(id, await _fetchHouseInfo(id))),
    );
    final loaded = Map<String, Map<dynamic, dynamic>>.fromEntries(entries);

    if (!mounted) return;
    var didChange = false;
    loaded.forEach((id, info) {
      final nextValue = info.isNotEmpty
          ? info
          : <dynamic, dynamic>{'__deleted__': true};
      if (_housesInfo[id] != nextValue) {
        _housesInfo[id] = nextValue;
        didChange = true;
      }
    });
    if (didChange && mounted) {
      setState(() {
        _sortedFriendsDirty = true;
      });
    } else {
      _sortedFriendsDirty = true;
    }
  }

  Future<Map<dynamic, dynamic>> _fetchHouseInfo(String houseId) async {
    final merged = await loadChatHouseInfo(_dbRef, houseId);
    return merged;
  }

  void _listenToInternalPartnerRealtime() {
    final houseId = _myHouseId;
    if (houseId == null || houseId.isEmpty) {
      return;
    }

    _internalPartnerPresenceSub?.cancel();
    _internalRoomMetaSub?.cancel();

    _internalPartnerPresenceSub = _dbRef
        .child('houses/$houseId/presence/$_partnerRole')
        .onValue
        .listen(
          (event) {
            final rawPresence = event.snapshot.value;
            final presence = rawPresence is Map
                ? Map<dynamic, dynamic>.from(rawPresence)
                : null;
            if (_samePresence(_internalPartnerPresence, presence)) {
              return;
            }

            _internalPartnerPresenceDebounce?.cancel();
            _internalPartnerPresenceDebounce = Timer(_realtimeUiDebounce, () {
              if (!mounted) return;
              setState(() {
                _internalPartnerPresence = presence;
              });
            });
          },
          onError: (Object error) {
            debugPrint(
              'Messenger partner presence listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể tải trạng thái người ấy.').message}',
            );
          },
        );

    _internalRoomMetaSub = _chatService
        .streamInternalRoomMeta(houseId)
        .listen(
          (meta) {
            if (_internalPartnerRoomMeta.sameAs(meta)) {
              return;
            }

            _internalRoomMetaDebounce?.cancel();
            _internalRoomMetaDebounce = Timer(_realtimeUiDebounce, () {
              if (!mounted) return;
              setState(() {
                _internalPartnerRoomMeta = meta;
              });
            });
          },
          onError: (Object error) {
            debugPrint(
              'Messenger internal room meta listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể tải tin nhắn gần nhất.').message}',
            );
          },
        );
  }

  String _roomIdFor(String friendId) {
    final ids = [_myHouseId ?? '', friendId]..sort();
    return '${ids.first}_${ids.last}';
  }

  void _pruneRemovedFriendRealtime(List<String> friendIds) {
    final nextIds = friendIds.toSet();
    final trackedIds = <String>{
      ..._presenceSubs.keys,
      ..._roomMetaSubs.keys,
      ..._activeRealtimeFriendIds,
      ..._friendRealtimeReleaseTimers.keys,
      ..._presenceByFriendId.keys,
      ..._roomMetaByFriendId.keys,
    };
    for (final friendId in trackedIds.difference(nextIds)) {
      _activeRealtimeFriendIds.remove(friendId);
      _friendRealtimeReleaseTimers.remove(friendId)?.cancel();
      _stopFriendRealtime(friendId, dropCache: true);
    }
  }

  void _warmupFriendRealtime(List<String> friendIds) {
    final warmupIds = friendIds.take(_friendRealtimeWarmupCount);
    for (final friendId in warmupIds) {
      _activateFriendRealtime(friendId);
    }
  }

  void _activateFriendRealtime(String friendId) {
    if (friendId.isEmpty || !_friendIdsSet.contains(friendId)) {
      return;
    }
    _friendRealtimeReleaseTimers.remove(friendId)?.cancel();
    if (!_activeRealtimeFriendIds.add(friendId)) {
      return;
    }
    _startFriendRealtimeIfNeeded(friendId);
  }

  void _deactivateFriendRealtime(String friendId) {
    if (friendId.isEmpty) {
      return;
    }
    _activeRealtimeFriendIds.remove(friendId);
    _friendRealtimeReleaseTimers.remove(friendId)?.cancel();
    _friendRealtimeReleaseTimers[friendId] = Timer(
      _friendRealtimeReleaseDelay,
      () {
        _friendRealtimeReleaseTimers.remove(friendId);
        if (_activeRealtimeFriendIds.contains(friendId)) {
          return;
        }
        _stopFriendRealtime(friendId);
      },
    );
  }

  void _startFriendRealtimeIfNeeded(String friendId) {
    _presenceSubs.putIfAbsent(friendId, () {
      return _dbRef
          .child('houses/$friendId/presence')
          .onValue
          .listen(
            (event) {
              final rawPresence = event.snapshot.value;
              final presence = rawPresence is Map
                  ? Map<dynamic, dynamic>.from(rawPresence)
                  : null;
              if (_samePresence(_presenceByFriendId[friendId], presence)) {
                return;
              }

              _friendPresenceDebounce[friendId]?.cancel();
              _friendPresenceDebounce[friendId] = Timer(
                _realtimeUiDebounce,
                () {
                  if (!mounted) return;
                  setState(() {
                    _presenceByFriendId[friendId] = presence;
                  });
                },
              );
            },
            onError: (Object error) {
              debugPrint(
                'Messenger friend presence listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể tải trạng thái bạn bè.').message}',
              );
            },
          );
    });

    _roomMetaSubs.putIfAbsent(friendId, () {
      final roomId = _roomIdFor(friendId);
      return _chatService
          .streamRoomMeta(
            roomId,
            viewerHouseId: _myHouseId,
            includeClosedMessage: false,
            includeDeletedDisplayName: false,
          )
          .listen(
            (meta) {
              final current =
                  _roomMetaByFriendId[friendId] ?? const ChatRoomMeta();
              if (current.sameAs(meta)) {
                return;
              }
              final shouldResort =
                  _lastMessageTsFromMeta(current) !=
                  _lastMessageTsFromMeta(meta);

              _friendRoomMetaDebounce[friendId]?.cancel();
              _friendRoomMetaDebounce[friendId] = Timer(
                _realtimeUiDebounce,
                () {
                  if (!mounted) return;
                  setState(() {
                    _roomMetaByFriendId[friendId] = meta;
                    if (shouldResort) {
                      _sortedFriendsDirty = true;
                    }
                  });
                },
              );
            },
            onError: (Object error) {
              debugPrint(
                'Messenger room meta listener failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể tải tin nhắn gần nhất.').message}',
              );
            },
          );
    });
  }

  void _stopFriendRealtime(String friendId, {bool dropCache = false}) {
    _friendPresenceDebounce.remove(friendId)?.cancel();
    _friendRoomMetaDebounce.remove(friendId)?.cancel();
    _presenceSubs.remove(friendId)?.cancel();
    _roomMetaSubs.remove(friendId)?.cancel();
    if (dropCache) {
      _presenceByFriendId.remove(friendId);
      _roomMetaByFriendId.remove(friendId);
    }
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _samePresence(
    Map<dynamic, dynamic>? left,
    Map<dynamic, dynamic>? right,
  ) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return left == right;
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  String _displayName(String friendId) {
    final info = _housesInfo[friendId];
    if (info?['__deleted__'] == true) {
      return repairMojibakeText(_deletedUserLabel);
    }
    final houseName = info?['houseName']?.toString().trim() ?? '';
    return houseName.isNotEmpty
        ? repairMojibakeText(houseName)
        : repairMojibakeText('Ngôi nhà $friendId');
  }

  String _internalPartnerName({bool allowFallback = true}) {
    final field = _partnerRole == 'user1' ? 'nameU1' : 'nameU2';
    final name = _myHouseInfo[field]?.toString().trim() ?? '';
    if (name.isNotEmpty || !allowFallback) {
      return repairMojibakeText(name);
    }
    return repairMojibakeText(
      _partnerRole == 'user1'
          ? L10nService().translate('male_role_default')
          : L10nService().translate('female_role_default'),
    );
  }

  String _internalPartnerAvatar() {
    final field = _partnerRole == 'user1' ? 'avtUser1' : 'avtUser2';
    return _myHouseInfo[field]?.toString().trim() ?? '';
  }

  bool get _isCoupleHouse {
    final mode =
        _myHouseInfo['relationshipMode']?.toString().trim().toLowerCase() ?? '';
    if (mode == 'single') {
      return false;
    }
    if (mode.isNotEmpty) {
      return true;
    }
    return _internalPartnerName(allowFallback: false).isNotEmpty ||
        _internalPartnerAvatar().isNotEmpty;
  }

  bool get _shouldShowInternalPartnerTile {
    final houseId = _myHouseId;
    return houseId != null && houseId.isNotEmpty && _isCoupleHouse;
  }

  String _displayUsername(String friendId) {
    final info = _housesInfo[friendId];
    if (info?['__deleted__'] == true) {
      return '';
    }
    final raw = repairMojibakeText(info?['username']?.toString().trim() ?? '');
    if (raw.isEmpty) {
      return '';
    }
    return raw.startsWith('@') ? raw.substring(1) : raw;
  }

  String _primaryLabel(String friendId) {
    final username = _displayUsername(friendId);
    if (username.isNotEmpty) {
      return '@$username';
    }
    return _displayName(friendId);
  }

  String _secondaryLabel(String friendId) {
    final houseName = _displayName(friendId);
    final primary = _primaryLabel(friendId);
    if (houseName.isEmpty || houseName == primary) {
      return friendId;
    }
    return houseName;
  }

  bool _isSingleHouse(String friendId) {
    final mode =
        _housesInfo[friendId]?['relationshipMode']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    return mode == 'single';
  }

  List<_HouseMatePreview> _houseMates(String friendId) {
    final info = _housesInfo[friendId];
    if (info?['__deleted__'] == true) {
      return const [];
    }

    final mates = <_HouseMatePreview>[];

    void addMate({
      required String nameKey,
      required String avatarKey,
      required String fallbackName,
    }) {
      final name = repairMojibakeText(info?[nameKey]?.toString().trim() ?? '');
      final avatar = info?[avatarKey]?.toString().trim() ?? '';
      if (name.isEmpty && avatar.isEmpty) {
        return;
      }
      mates.add(
        _HouseMatePreview(
          name: name.isNotEmpty ? name : repairMojibakeText(fallbackName),
          avatar: avatar,
        ),
      );
    }

    addMate(nameKey: 'nameU1', avatarKey: 'avtUser1', fallbackName: 'Người 1');
    if (!_isSingleHouse(friendId)) {
      addMate(
        nameKey: 'nameU2',
        avatarKey: 'avtUser2',
        fallbackName: 'Người 2',
      );
    }

    return mates;
  }

  int _lastMessageTs(String friendId) {
    return readChatMetaTimestamp(_roomMetaByFriendId[friendId]?.lastMessage);
  }

  int _lastMessageTsFromMeta(ChatRoomMeta meta) {
    return readChatMetaTimestamp(meta.lastMessage);
  }

  bool _friendHasUnread(String friendId) {
    final houseId = _myHouseId;
    if (houseId == null || houseId.isEmpty) {
      return false;
    }
    return isChatMetaUnreadForHouse(
      _roomMetaByFriendId[friendId]?.lastMessage,
      viewerHouseId: houseId,
    );
  }

  bool get _internalPartnerHasUnread {
    final houseId = _myHouseId;
    if (houseId == null || houseId.isEmpty) {
      return false;
    }
    return isChatMetaUnreadForHouse(
      _internalPartnerRoomMeta.lastMessage,
      viewerHouseId: houseId,
    );
  }

  bool _groupHasUnread(GroupChatRoom room) {
    final houseId = _myHouseId;
    if (houseId == null || houseId.isEmpty) {
      return false;
    }
    return _groupChatService.isGroupLastMessageUnreadForHouse(
      room,
      viewerHouseId: houseId,
    );
  }

  String _displayAvatar(String friendId) {
    final info = _housesInfo[friendId];
    if (info?['__deleted__'] == true) {
      return '';
    }
    return info?['houseAvatar']?.toString() ??
        info?['avtUser1']?.toString() ??
        '';
  }

  List<String> get _sortedFriends {
    if (_sortedFriendsDirty) {
      final items = [..._friends];
      items.sort((a, b) {
        final byUnread = (_friendHasUnread(b) ? 1 : 0).compareTo(
          _friendHasUnread(a) ? 1 : 0,
        );
        if (byUnread != 0) {
          return byUnread;
        }
        final byRecent = _lastMessageTs(b).compareTo(_lastMessageTs(a));
        if (byRecent != 0) {
          return byRecent;
        }
        final byName = _primaryLabel(
          a,
        ).toLowerCase().compareTo(_primaryLabel(b).toLowerCase());
        if (byName != 0) {
          return byName;
        }
        return a.compareTo(b);
      });
      _sortedFriendsCache = items;
      _sortedFriendsDirty = false;
    }
    return _sortedFriendsCache;
  }

  List<String> get _filteredFriends {
    final base = _sortedFriends;
    if (_searchQuery.isEmpty) return base;
    return base.where((friendId) {
      final members = _houseMates(
        friendId,
      ).map((mate) => mate.name).join(' ').toLowerCase();
      final querySource = [
        _primaryLabel(friendId),
        _secondaryLabel(friendId),
        _displayUsername(friendId),
        members,
        friendId,
      ].join(' ').toLowerCase();
      return querySource.contains(_searchQuery);
    }).toList();
  }

  bool _presenceIsOnline(Map<dynamic, dynamic>? raw) {
    if (raw == null) return false;
    for (final value in raw.values) {
      if (value is Map && PresenceService.isPresenceOnline(value)) {
        return true;
      }
    }
    return false;
  }

  int? _presenceLastSeen(Map<dynamic, dynamic>? raw) {
    if (raw == null) return null;
    int? latest;
    for (final value in raw.values) {
      if (value is! Map) {
        continue;
      }
      final ts =
          PresenceService.latestSessionTimestamp(value) ??
          PresenceService.lastSeenMs(value);
      if (ts != null && (latest == null || ts > latest)) {
        latest = ts;
      }
    }
    return latest;
  }

  String _presenceLabel(Map<dynamic, dynamic>? raw) {
    if (_presenceIsOnline(raw)) {
      return '\u0110ang online';
    }
    final lastSeen = _presenceLastSeen(raw);
    if (lastSeen == null) {
      return 'Ch\u01b0a r\u00f5 tr\u1ea1ng th\u00e1i';
    }
    return PresenceService.formatLastSeen(lastSeen);
  }

  Color _presenceColor(Map<dynamic, dynamic>? raw) {
    return _presenceIsOnline(raw)
        ? const Color(0xFF22C55E)
        : const Color(0xFF94A3B8);
  }

  bool _rolePresenceIsOnline(Map<dynamic, dynamic>? raw) {
    return PresenceService.isPresenceOnline(raw);
  }

  int? _rolePresenceLastSeen(Map<dynamic, dynamic>? raw) {
    if (raw == null) return null;
    return PresenceService.latestSessionTimestamp(raw) ??
        PresenceService.lastSeenMs(raw);
  }

  String _internalPartnerStatusLabel() {
    if (_rolePresenceIsOnline(_internalPartnerPresence)) {
      return '\u0110ang online';
    }
    final lastSeen = _rolePresenceLastSeen(_internalPartnerPresence);
    if (lastSeen == null) {
      return 'Ch\u01b0a r\u00f5 tr\u1ea1ng th\u00e1i';
    }
    return PresenceService.formatLastSeen(lastSeen);
  }

  Color _internalPartnerStatusColor() {
    return _rolePresenceIsOnline(_internalPartnerPresence)
        ? const Color(0xFF22C55E)
        : const Color(0xFF94A3B8);
  }

  String _formatLastMessage(
    Map<dynamic, dynamic>? raw, {
    String fallback =
        'Nh\u1ea5n \u0111\u1ec3 b\u1eaft \u0111\u1ea7u tr\u00f2 chuy\u1ec7n...',
  }) {
    return formatChatMessagePreview(
      raw,
      labels: _lastMessagePreviewLabels,
      fallbackOverride: fallback,
    );
  }

  String _formatLastMessageTime(Map<dynamic, dynamic>? raw) {
    final ts = readChatMetaTimestamp(raw);
    if (ts <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  void _listenToGroupsRealtime(String houseId) {
    _groupRoomsSub?.cancel();
    _groupRoomsSub = _groupChatService.streamGroupsForHouse(houseId).listen((
      groups,
    ) {
      final relatedHouseIds = groups
          .expand((group) => group.memberHouseIds)
          .where((id) => id != houseId)
          .toSet()
          .toList();
      if (relatedHouseIds.isNotEmpty) {
        unawaited(_loadHousesInfo(relatedHouseIds));
      }
      if (!mounted) return;
      setState(() {
        _groupRooms.clear();
        _groupRooms.addAll(groups);
      });
    }, onError: (_) {});
  }

  List<GroupChatRoom> get _sortedGroupRooms {
    final items = <GroupChatRoom>[..._groupRooms];
    items.sort((a, b) {
      final byUnread = (_groupHasUnread(b) ? 1 : 0).compareTo(
        _groupHasUnread(a) ? 1 : 0,
      );
      if (byUnread != 0) {
        return byUnread;
      }
      return b.sortTimestamp.compareTo(a.sortTimestamp);
    });
    return items;
  }

  List<GroupChatRoom> get _filteredGroupRooms {
    final base = _sortedGroupRooms;
    if (_searchQuery.isEmpty) return base;
    return base.where((group) {
      final source = [
        repairMojibakeText(group.name),
        group.memberHouseIds.map(_groupHouseName).join(' '),
        group.memberHouseIds.join(' '),
      ].join(' ').toLowerCase();
      return source.contains(_searchQuery);
    }).toList();
  }

  String _groupHouseName(String houseId) {
    if (houseId == _myHouseId) {
      final mine = _myHouseInfo['houseName']?.toString().trim() ?? '';
      return mine.isNotEmpty
          ? repairMojibakeText(mine)
          : repairMojibakeText('Nhà của bạn');
    }
    return _displayName(houseId);
  }

  String _groupHouseAvatar(String houseId) {
    if (houseId == _myHouseId) {
      return _myHouseInfo['houseAvatar']?.toString().trim() ??
          _myHouseInfo['avtUser1']?.toString().trim() ??
          '';
    }
    return _displayAvatar(houseId).trim();
  }

  String _formatGroupCreatedAt(int createdAtMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm \u2022 $hh:$min';
  }

  GroupChatRoom? _findGroupRoomById(String groupId) {
    for (final room in _groupRooms) {
      if (room.id == groupId) {
        return room;
      }
    }
    return null;
  }

  String _groupPreviewText(GroupChatRoom group) {
    return repairMojibakeText(
      formatChatMessagePreview(
        group.lastMessage,
        labels: _lastMessagePreviewLabels,
        fallbackOverride: 'Tạo lúc ',
      ),
    );
  }

  String _defaultGroupName(List<String> memberHouseIds) {
    final others = memberHouseIds
        .where((houseId) => houseId != _myHouseId)
        .take(2)
        .map(_groupHouseName)
        .toList();
    if (others.isEmpty) {
      return repairMojibakeText('Nhóm mới');
    }
    if (others.length == 1) {
      return repairMojibakeText('Nhóm với ${others.first}');
    }
    return repairMojibakeText('Nhóm ${others.first} & ${others.last}');
  }

  void _showMessengerNotice(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(repairMojibakeText(message)),
          backgroundColor: error
              ? const Color(0xFFDC2626)
              : const Color(0xFFD81B60),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    AdMobService().resumeAutoInterstitial();
    _searchDebounce?.cancel();
    _friendsRealtimeDebounce?.cancel();
    _internalPartnerPresenceDebounce?.cancel();
    _internalRoomMetaDebounce?.cancel();

    _friendsSub?.cancel();
    _internalPartnerPresenceSub?.cancel();
    _internalRoomMetaSub?.cancel();
    _groupRoomsSub?.cancel();

    for (final timer in _friendPresenceDebounce.values) {
      timer.cancel();
    }
    _friendPresenceDebounce.clear();

    for (final timer in _friendRoomMetaDebounce.values) {
      timer.cancel();
    }
    _friendRoomMetaDebounce.clear();

    for (final timer in _friendRealtimeReleaseTimers.values) {
      timer.cancel();
    }
    _friendRealtimeReleaseTimers.clear();
    _activeRealtimeFriendIds.clear();

    for (final sub in _presenceSubs.values) {
      sub.cancel();
    }
    for (final sub in _roomMetaSubs.values) {
      sub.cancel();
    }
    _presenceSubs.clear();
    _roomMetaSubs.clear();

    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = _filteredFriends;
    final filteredGroups = _filteredGroupRooms;

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentInset = viewportWidth > 760 ? (viewportWidth - 760) / 2 : 0.0;

    return Scaffold(
      backgroundColor: SLColors.paperCanvas,
      body: SLTheme.softCanvasBackdrop(
        baseColor: SLColors.paperCanvas,
        accentColor: SLColors.secondary,
        secondaryAccent: SLColors.thread,
        motif: SLCanvasBackdropMotif.notes,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: contentInset),
          child: Column(
            children: [
              _buildMessengerHeader(context),
              _buildMessengerSearchBar(),
              _buildMessengerTabBar(),
              SLSpacing.h6,
              Expanded(
                child: _buildMessengerTabBody(
                  filteredFriends: filteredFriends,
                  filteredGroups: filteredGroups,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChatDetail(
    String targetHouseId,
    String targetName,
    String targetAvatar,
  ) {
    slPush(
      context,
      ChatDetailScreen(
        myHouseId: _myHouseId!,
        targetHouseId: targetHouseId,
        targetName: targetName,
        targetAvatar: targetAvatar,
      ),
    );
  }

  void _openInternalChatDetail() {
    final houseId = _myHouseId;
    if (houseId == null || houseId.isEmpty) {
      return;
    }

    slPush(
      context,
      ChatDetailScreen(
        myHouseId: houseId,
        targetHouseId: houseId,
        targetName: _internalPartnerName(),
        targetAvatar: _internalPartnerAvatar(),
        isInternal: true,
        currentRole: _myRole,
        targetRole: _partnerRole,
      ),
    );
  }

  void _openGroupChat(GroupChatRoom group) {
    final houseId = _myHouseId;
    if (houseId == null || houseId.isEmpty) {
      return;
    }

    slPush(
      context,
      GroupChatScreen(
        myHouseId: houseId,
        initialRoom: _findGroupRoomById(group.id) ?? group,
      ),
    );
  }

  Future<void> _saveGroupDrafts() async {
    final houseId = _myHouseId;
    if (houseId == null || houseId.isEmpty) {
      return;
    }

    final prefs = await OfflineCacheService.getPrefs();
    final encoded = jsonEncode(
      _groupDrafts.map((group) => group.toJson()).toList(),
    );
    await prefs.setString('messenger_group_drafts_v1_$houseId', encoded);
  }
}

class _FriendRealtimeScope extends StatefulWidget {
  final String friendId;
  final ValueChanged<String> onActivate;
  final ValueChanged<String> onDeactivate;
  final Widget child;

  const _FriendRealtimeScope({
    super.key,
    required this.friendId,
    required this.onActivate,
    required this.onDeactivate,
    required this.child,
  });

  @override
  State<_FriendRealtimeScope> createState() => _FriendRealtimeScopeState();
}

class _FriendRealtimeScopeState extends State<_FriendRealtimeScope> {
  @override
  void initState() {
    super.initState();
    widget.onActivate(widget.friendId);
  }

  @override
  void didUpdateWidget(covariant _FriendRealtimeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friendId == widget.friendId) {
      return;
    }
    widget.onDeactivate(oldWidget.friendId);
    widget.onActivate(widget.friendId);
  }

  @override
  void dispose() {
    widget.onDeactivate(widget.friendId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _HouseMatePreview {
  final String name;
  final String avatar;

  const _HouseMatePreview({required this.name, required this.avatar});
}
