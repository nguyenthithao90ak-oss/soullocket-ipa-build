import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/sl_route.dart';
import '../../models/single_match_models.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/chat_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/single_match_service.dart';
import '../../widgets/sl_feedback.dart';
import '../chat/chat_detail_screen.dart';
import '../chat/chat_message_preview.dart';
import 'dialogs/single_match_secret_code_dialog.dart';
import 'widgets/single_match_messenger_view.dart';

class SingleMatchMessengerScreen extends StatefulWidget {
  const SingleMatchMessengerScreen({
    super.key,
    required this.houseId,
    required this.displayName,
    required this.avatarUrl,
    required this.preferences,
    required this.myAge,
    required this.onSettings,
    required this.onCall,
  });

  final String houseId;
  final String displayName;
  final String avatarUrl;
  final SingleMatchPreferences preferences;
  final int? myAge;
  final Future<void> Function() onSettings;
  final Future<void> Function(SingleMatchCandidate, bool isVideo) onCall;

  @override
  State<SingleMatchMessengerScreen> createState() =>
      _SingleMatchMessengerScreenState();
}

class _SingleMatchMessengerScreenState extends State<SingleMatchMessengerScreen>
    with WidgetsBindingObserver {
  final _service = SingleMatchService.instance;
  final _chat = ChatService();
  final _meta = <String, ChatRoomMeta>{};
  final _metaSubs = <String, StreamSubscription<ChatRoomMeta>>{};
  StreamSubscription<List<Map<String, dynamic>>>? _mappingsSub;
  StreamSubscription<List<SingleMatchHistoryEntry>>? _historySub;
  StreamSubscription<User?>? _authSub;
  List<Map<String, dynamic>> _mappings = [];
  List<SingleMatchCandidate> _people = [];
  List<SingleMatchHistoryEntry> _calls = [];
  SingleMatchNearbyResult _nearby = const SingleMatchNearbyResult(
    enabled: false,
  );
  Timer? _expiry;
  late final String? _uid;
  bool _busy = false;
  bool _loadingPeople = true;
  bool _loadingInbox = true;
  bool _nearbyLoading = false;
  bool _active = true;
  int _generation = 0;
  String? _inboxError;
  String? _peopleError;
  String? _nearbyError;

  bool get _valid =>
      mounted && _uid != null && FirebaseAuth.instance.currentUser?.uid == _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != _uid && mounted) {
        _stopStreams();
        setState(() {
          _mappings = [];
          _meta.clear();
          _people = [];
          _calls = [];
          _nearby = const SingleMatchNearbyResult(enabled: false);
          _inboxError = context.tr('core_err_general');
        });
      }
    });
    _startStreams();
    unawaited(_loadPeople());
    unawaited(_loadNearby(allowPrompt: false));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_active == active) return;
    _active = active;
    if (active && _valid) {
      _startStreams();
      unawaited(_loadPeople());
      unawaited(_loadNearby(allowPrompt: false));
    } else {
      _stopStreams();
    }
  }

  void _startStreams() {
    if (!_valid || _mappingsSub != null) return;
    _mappingsSub = _service
        .streamChatMappings(widget.houseId)
        .listen(
          (rows) {
            if (!_valid || !_active) return;
            // Metadata gọn, tối đa 50 phòng; không nghe toàn bộ lịch sử tin nhắn.
            final next = rows
                .where((r) => (r['peerHouseId']?.toString() ?? '').isNotEmpty)
                .take(50)
                .toList();
            final ids = next.map((r) => r['peerHouseId'].toString()).toSet();
            for (final id in _metaSubs.keys.toList()) {
              if (ids.contains(id)) continue;
              unawaited(_metaSubs.remove(id)?.cancel());
              _meta.remove(id);
            }
            for (final id in ids) {
              if (_metaSubs.containsKey(id)) continue;
              final roomId = _chat.roomIdFor(widget.houseId, id);
              _metaSubs[id] = _chat
                  .streamRoomMeta(roomId, viewerHouseId: widget.houseId)
                  .listen(
                    (meta) {
                      if (_valid && _active) {
                        setState(() => _meta[id] = meta);
                      }
                    },
                    onError: (Object _) {
                      if (_valid && _active) setState(() => _meta.remove(id));
                    },
                  );
            }
            setState(() {
              _mappings = next;
              _inboxError = null;
              _loadingInbox = false;
            });
          },
          onError: (Object error) {
            if (_valid) {
              setState(() {
                _inboxError = _error(error);
                _loadingInbox = false;
              });
            }
          },
        );
    _historySub = _service.streamHistory(widget.houseId).listen((entries) {
      if (_valid && _active) {
        setState(() => _calls = entries.where((e) => e.isCall).toList());
      }
    });
  }

  void _stopStreams() {
    unawaited(_mappingsSub?.cancel());
    unawaited(_historySub?.cancel());
    _mappingsSub = null;
    _historySub = null;
    for (final sub in _metaSubs.values) {
      unawaited(sub.cancel());
    }
    _metaSubs.clear();
    _generation++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStreams();
    unawaited(_authSub?.cancel());
    _expiry?.cancel();
    super.dispose();
  }

  String _error(Object error) => error is StateError
      ? error.message.toString()
      : AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('sm_load_error'),
        ).message;

  Future<bool> _sameScope() async =>
      _valid &&
      await HouseService().getCurrentHouseId() == widget.houseId &&
      _valid;

  Future<void> _loadPeople() async {
    final generation = ++_generation;
    try {
      final list = await _service
          .fetchCandidates(currentHouseId: widget.houseId)
          .timeout(const Duration(seconds: 15));
      if (!await _sameScope() ||
          !mounted ||
          !_active ||
          generation != _generation) {
        return;
      }
      final tags = widget.preferences.tags.map((t) => t.toLowerCase()).toSet();
      int score(SingleMatchCandidate c) =>
          c.tags.where((t) => tags.contains(t.toLowerCase())).length * 6 +
          (c.goal == widget.preferences.goal ? 4 : 0) +
          (c.voiceStyle == widget.preferences.voiceStyle ? 2 : 0);
      list.sort((a, b) => score(b).compareTo(score(a)));
      setState(() {
        _people = list;
        _peopleError = null;
        _loadingPeople = false;
      });
    } catch (error) {
      if (_valid && generation == _generation) {
        setState(() {
          _peopleError = _error(error);
          _loadingPeople = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (!_valid) return;
    _stopStreams();
    _startStreams();
    await _loadPeople();
    if (_nearby.enabled) await _loadNearby(allowPrompt: false);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    try {
      if (!await _sameScope()) return;
      await action();
    } catch (error) {
      if (_valid) _snack(_error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SLSnackBar(content: Text(message)));
  }

  Future<void> _openChat(String houseId, String name, String avatar) async {
    if (!await _sameScope()) return;
    // Dùng mapping đã có sau khi ghép mã; nếu chưa có thì backend kiểm lại
    // tuổi, discovery và chặn hai chiều trước khi tạo phòng.
    await _service.getOrCreateMatchChatRoom(
      myHouseId: widget.houseId,
      peerHouseId: houseId,
      peerName: name,
      peerAvatarUrl: avatar,
    );
    if (!await _sameScope() || !mounted) return;
    await slPush<void>(
      context,
      ChatDetailScreen(
        myHouseId: widget.houseId,
        targetHouseId: houseId,
        targetName: name,
        targetAvatar: avatar,
      ),
    );
  }

  Future<void> _showPerson(
    SingleMatchCandidate person, {
    bool? preferredVideo,
  }) async {
    if (!_valid) return;
    final action = await showModalBottomSheet<MatchPersonAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: MatchMessengerPalette.of(context).surface,
      builder: (context) => MatchPersonSheet(
        person: person,
        preferences: widget.preferences,
        preferredVideo: preferredVideo,
      ),
    );
    if (action == null || !await _sameScope()) return;
    if (action == MatchPersonAction.message) {
      await _openChat(person.houseId, person.displayName, person.avatarUrl);
    } else {
      // Làm mới khả năng gọi và quyền riêng tư, không gọi lại người đã rời discovery.
      final fresh = await _service.fetchCandidates(
        currentHouseId: widget.houseId,
      );
      final eligible = fresh
          .where((c) => c.houseId == person.houseId)
          .firstOrNull;
      if (!mounted) return;
      if (eligible == null) throw StateError(context.tr('sm_no_results'));
      final video = action == MatchPersonAction.video;
      if (video
          ? !eligible.allowVideoCalls || !widget.preferences.allowVideoCalls
          : !eligible.allowAudioCalls || !widget.preferences.allowAudioCalls) {
        throw StateError(context.tr('sm_enable_call'));
      }
      if (!await _sameScope()) return;
      await widget.onCall(eligible, video);
    }
  }

  Future<void> _connect(MatchConnectAction action) => _run(() async {
    if (action == MatchConnectAction.secretCode) {
      final peerId = await showDialog<String>(
        context: context,
        builder: (_) => SingleMatchSecretCodeDialog(houseId: widget.houseId),
      );
      if (peerId == null || !await _sameScope()) return;
      final mapping = await _service.readMatchChatMapping(
        myHouseId: widget.houseId,
        peerHouseId: peerId,
      );
      if (mapping == null) {
        if (mounted) {
          _snack(context.tr('sm_no_results'));
        }
        return;
      }
      final peerName = mapping['peerName']?.toString().trim() ?? '';
      final peerAvatar = mapping['peerAvatarUrl']?.toString().trim() ?? '';
      await _openChat(peerId, peerName, peerAvatar);
      return;
    }
    final video = action == MatchConnectAction.video;
    if (video
        ? !widget.preferences.allowVideoCalls
        : !widget.preferences.allowAudioCalls) {
      _snack(context.tr('sm_enable_call'));
      return;
    }
    final prefs = widget.preferences;
    final person = await _service.pickScoredMatch(
      currentHouseId: widget.houseId,
      excludeHouseIds: const {},
      goal: prefs.goal,
      voiceStyle: prefs.voiceStyle,
      myTags: prefs.tags,
      myAge: widget.myAge,
      preferredAgeMin: prefs.preferredAgeMin,
      preferredAgeMax: prefs.preferredAgeMax,
      needAudio: !video,
      needVideo: video,
    );
    if (!await _sameScope() || !mounted) return;
    if (person == null) {
      _snack(context.tr('sm_no_results'));
      return;
    }
    // Chỉ mở camera/micro sau khi người dùng chọn gửi lời mời trên hồ sơ thật.
    await _showPerson(person, preferredVideo: video);
  });

  Future<void> _loadNearby({bool allowPrompt = true}) async {
    if (_nearbyLoading || !_valid) return;
    setState(() {
      _nearbyLoading = true;
      _nearbyError = null;
    });
    try {
      var result = await _service.nearby(
        houseId: widget.houseId,
        action: 'status',
      );
      if (!await _sameScope() || !mounted || !_active) return;
      if (!result.enabled && allowPrompt) {
        final consent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('sm_nearby_consent_title')),
            content: SingleChildScrollView(
              child: Text(context.tr('sm_nearby_consent')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('sm_nearby_on')),
              ),
            ],
          ),
        );
        if (consent != true || !await _sameScope() || !_active) return;
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) return;
        if (!serviceEnabled) {
          throw StateError(context.tr('map_refresh_service_off_body'));
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (!mounted) return;
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw StateError(context.tr('map_refresh_permission_blocked_body'));
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
        if (!await _sameScope() || !_active) return;
        result = await _service.nearby(
          houseId: widget.houseId,
          action: 'enable',
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
      if (!await _sameScope() || !mounted) return;
      // Nếu tải kết quả lỗi, vẫn giữ công tắc tắt cho vùng vừa bật thành công.
      _setNearby(result);
      if (result.enabled) {
        result = await _service.nearby(houseId: widget.houseId, action: 'list');
      }
      if (!await _sameScope() || !mounted) return;
      _setNearby(result);
    } catch (error) {
      if (_valid) {
        setState(() => _nearbyError = _error(error));
      }
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
  }

  void _setNearby(SingleMatchNearbyResult result) {
    _expiry?.cancel();
    final remaining = result.expiresAt - DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _nearby = result.enabled && remaining <= 0
          ? const SingleMatchNearbyResult(enabled: false)
          : result;
    });
    // Lập lịch ngay khi biết opt-in còn hạn, kể cả lượt tải danh sách sau đó lỗi.
    if (_nearby.enabled && remaining > 0) {
      _expiry = Timer(Duration(milliseconds: remaining), () {
        if (mounted) {
          setState(
            () => _nearby = const SingleMatchNearbyResult(enabled: false),
          );
        }
      });
    }
  }

  Future<void> _disableNearby() async {
    if (_nearbyLoading || !_valid) return;
    setState(() => _nearbyLoading = true);
    try {
      final result = await _service.nearby(
        houseId: widget.houseId,
        action: 'disable',
      );
      if (!await _sameScope() || !mounted) return;
      _expiry?.cancel();
      setState(() {
        _nearby = result;
        _nearbyError = null;
      });
    } catch (error) {
      if (_valid) setState(() => _nearbyError = _error(error));
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
  }

  List<MatchConversationPreview> _conversations(BuildContext context) {
    final labels = ChatMessagePreviewLabels(
      fallback: context.tr('messenger_start_conversation'),
      callInvite: context.tr('ui_chat_b_t_u_m_t_cu_c_9ec67f'),
      watchInvite: context.tr('ui_chat_chia_s_ph_ng_xem_chung_d1656b'),
      image: context.tr('ui_chat_g_i_m_t_h_nh_nh_141621'),
      share: context.tr('ui_chat_chia_s_m_t_b_i_vi_b78759'),
    );
    final rows = _mappings.map((mapping) {
      final id = mapping['peerHouseId'].toString();
      final meta = _meta[id];
      return MatchConversationPreview(
        houseId: id,
        name: meta?.isClosed == true
            ? context.tr('chat_deleted_user')
            : (mapping['peerName']?.toString().trim().isNotEmpty == true
                  ? mapping['peerName'].toString()
                  : context.tr('match_bnmi_5e3d3b')),
        avatar: mapping['peerAvatarUrl']?.toString() ?? '',
        message: meta?.isClosed == true
            ? context.tr('chat_closed_history_only')
            : formatChatMessagePreview(meta?.lastMessage, labels: labels),
        updatedAt: meta?.lastMessage == null
            ? 0
            : readChatMetaTimestamp(meta!.lastMessage),
        // Chỉ đánh dấu tin gần nhất chưa đọc; metadata cũ chưa có tổng đếm đáng tin.
        unread: isChatMetaUnreadForHouse(
          meta?.lastMessage,
          viewerHouseId: widget.houseId,
        ),
      );
    }).toList();
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  Future<void> _onCallEntry(SingleMatchHistoryEntry entry) => _run(() async {
    final people = await _service.fetchCandidates(
      currentHouseId: widget.houseId,
    );
    final person = people
        .where((p) => p.houseId == entry.peerHouseId)
        .firstOrNull;
    if (!_valid || !mounted) return;
    if (person == null) {
      _snack(context.tr('sm_no_results'));
      return;
    }
    await _showPerson(person, preferredVideo: entry.action == 'video_call');
  });

  @override
  Widget build(BuildContext context) => SingleMatchMessengerView(
    name: widget.displayName,
    avatar: widget.avatarUrl,
    conversations: _conversations(context),
    people: _people,
    calls: _calls,
    myTags: widget.preferences.tags,
    nearbyPeople: _nearby.candidates,
    distanceBands: _nearby.distanceBands,
    loading: _loadingPeople || _loadingInbox,
    busy: _busy,
    nearbyLoading: _nearbyLoading,
    nearbyEnabled: _nearby.enabled,
    inboxError: _inboxError,
    peopleError: _peopleError,
    nearbyError: _nearbyError,
    onBack: () => Navigator.maybePop(context),
    onSettings: () => _run(widget.onSettings),
    onRefresh: _refresh,
    onConversation: (p) => _run(() => _openChat(p.houseId, p.name, p.avatar)),
    onPerson: (p) => _run(() => _showPerson(p)),
    onConnect: _connect,
    onCallEntry: _onCallEntry,
    onNearby: () => _loadNearby(),
    onDisableNearby: _disableNearby,
  );
}
