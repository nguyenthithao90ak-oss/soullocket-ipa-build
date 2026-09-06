import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/countdown_space_service.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/schedule_notification_presenter.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/app_error_mapper.dart';

part 'notification_center_screen_types.dart';
part 'notification_center_screen_sections.dart';
part 'notification_center_screen_detail.dart';

enum _NotifCategory { all, warning, friend, social }

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with WidgetsBindingObserver {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final HouseService _houseService = HouseService();
  final FriendsService _friendsService = FriendsService();
  final CountdownSpaceService _countdownSpaceService = CountdownSpaceService();

  String? _houseId;
  List<_NotifModel> _all = <_NotifModel>[];
  final Set<String> _readLocal = <String>{};
  final Set<String> _pinLocal = <String>{};
  _NotifCategory _cat = _NotifCategory.all;
  String _search = '';
  bool _isLoading = true;
  String _houseName = '';
  String _nameU1 = '';
  String _nameU2 = '';
  String _startDate = '';
  String _dobU1 = '';
  String _dobU2 = '';
  StreamSubscription<DatabaseEvent>? _notificationsSub;
  Timer? _notificationsDebounce;
  String _lastNotificationsFingerprint = '';

  static const int _notificationsLimit = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachNotificationsListener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncNotificationsListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNotificationsListener();
  }

  Future<void> _init() async {
    _houseId = await _houseService.getCurrentHouseId();
    if (_houseId == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      NotificationBadgeCounter.instance.update(0);
      return;
    }

    await _loadHouseIdentity();
    _syncNotificationsListener(forceRestart: true);
  }

  void _attachNotificationsListener({bool forceRestart = false}) {
    if (!_canListenToNotifications()) return;
    if (_notificationsSub != null && !forceRestart) {
      return;
    }

    _detachNotificationsListener();
    _notificationsSub = _db
        .ref('notifications/$_houseId')
        .limitToLast(_notificationsLimit)
        .onValue
        .listen(
          _handleNotificationsEvent,
          onError: (Object error) {
            debugPrint(
              '[NotificationCenter] listener error: ${AppErrorMapper.resolve(error).message}',
            );
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
        );
  }

  void _detachNotificationsListener() {
    _notificationsDebounce?.cancel();
    _notificationsDebounce = null;
    _notificationsSub?.cancel();
    _notificationsSub = null;
  }

  void _syncNotificationsListener({bool forceRestart = false}) {
    if (_canListenToNotifications()) {
      _attachNotificationsListener(forceRestart: forceRestart);
      return;
    }
    _detachNotificationsListener();
  }

  bool _canListenToNotifications() {
    final houseId = _houseId;
    if (!mounted || houseId == null || houseId.isEmpty) {
      return false;
    }
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isAppResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    final route = ModalRoute.of(context);
    final isCurrentRoute = route == null || route.isCurrent;
    return isAppResumed &&
        isCurrentRoute &&
        TickerMode.valuesOf(context).enabled;
  }

  void _handleNotificationsEvent(DatabaseEvent event) {
    if (!mounted) return;
    if (!event.snapshot.exists || event.snapshot.value == null) {
      _lastNotificationsFingerprint = '';
      _notificationsDebounce?.cancel();
      setState(() {
        _all = <_NotifModel>[];
        _isLoading = false;
      });
      _updateBadge();
      return;
    }

    final snapshotValue = event.snapshot.value;
    if (snapshotValue is! Map) {
      _lastNotificationsFingerprint = '';
      _notificationsDebounce?.cancel();
      setState(() {
        _all = <_NotifModel>[];
        _isLoading = false;
      });
      _updateBadge();
      return;
    }

    final raw = <String, dynamic>{};
    final rawMap = Map<dynamic, dynamic>.from(snapshotValue);
    rawMap.forEach((key, value) {
      raw[key.toString()] = value;
    });

    final fingerprint = _buildSnapshotFingerprint(raw);
    if (_lastNotificationsFingerprint == fingerprint) {
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
      return;
    }

    _lastNotificationsFingerprint = fingerprint;
    _notificationsDebounce?.cancel();
    _notificationsDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final items = <_NotifModel>[];
      raw.forEach((key, value) {
        if (value is Map) {
          try {
            final item = Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(value),
            );
            items.add(_NotifModel.fromMap(key.toString(), item));
          } catch (error) {
            debugPrint(
              '[NotificationCenter] Skipped malformed notification $key: $error',
            );
          }
        }
      });
      items.sort((a, b) {
        final ap = _pinLocal.contains(a.id) ? 1 : 0;
        final bp = _pinLocal.contains(b.id) ? 1 : 0;
        if (ap != bp) return bp - ap;
        return b.ts.compareTo(a.ts);
      });
      setState(() {
        _all = items;
        _isLoading = false;
      });
      _updateBadge();
    });
  }

  void _updateBadge() {
    final unread = _all.where((n) => !_isRead(n)).length;
    NotificationBadgeCounter.instance.update(unread);
  }

  String _buildSnapshotFingerprint(Map<String, dynamic> raw) {
    final keys = raw.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in keys) {
      buffer
        ..write(key)
        ..write(':')
        ..write(_stableSerialize(raw[key]))
        ..write(';');
    }
    return buffer.toString();
  }

  String _stableSerialize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      final buffer = StringBuffer('{');
      for (final key in keys) {
        buffer
          ..write(key)
          ..write(':')
          ..write(_stableSerialize(value[key]))
          ..write(',');
      }
      buffer.write('}');
      return buffer.toString();
    }
    if (value is List) {
      return '[${value.map(_stableSerialize).join(',')}]';
    }
    return value?.toString() ?? 'null';
  }

  Future<void> _loadHouseIdentity() async {
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) return;
    try {
      final snapshot = await _db.ref('houses/$houseId/settings').get();
      if (!mounted) return;
      final data = snapshot.value is Map
          ? Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(snapshot.value as Map),
            )
          : const <String, dynamic>{};
      setState(() {
        _houseName = (data['houseName'] ?? '').toString();
        _nameU1 = (data['nameU1'] ?? '').toString();
        _nameU2 = (data['nameU2'] ?? '').toString();
        _startDate = (data['startDate'] ?? '').toString();
        _dobU1 = (data['dobU1'] ?? '').toString();
        _dobU2 = (data['dobU2'] ?? '').toString();
      });
    } catch (error) {
      debugPrint('[NotificationCenter] Cannot load house metadata: $error');
    }
  }

  bool _isRead(_NotifModel n) => _readLocal.contains(n.id) || n.readAt != null;

  bool _isLocked(_NotifModel n) =>
      n.locked || _category(n) == _NotifCategory.warning;

  _NotifModel? _findNotif(String id) {
    for (final item in _all) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _markRead(String id) {
    setState(() => _readLocal.add(id));
    _db.ref('notifications/$_houseId/$id/readAt').set(ServerValue.timestamp);
    _updateBadge();
  }

  void _markAllRead() {
    const now = ServerValue.timestamp;
    final updates = <String, dynamic>{};
    for (final n in _all) {
      if (!_isRead(n)) {
        _readLocal.add(n.id);
        updates['notifications/$_houseId/${n.id}/readAt'] = now;
      }
    }
    if (updates.isNotEmpty) {
      _db.ref().update(updates);
    }
    setState(() {});
    NotificationBadgeCounter.instance.update(0);
  }

  void _togglePin(String id) {
    final target = _findNotif(id);
    if (target != null && _isLocked(target)) return;
    setState(() {
      if (_pinLocal.contains(id)) {
        _pinLocal.remove(id);
      } else {
        _pinLocal.add(id);
      }
      _all.sort((a, b) {
        final ap = _pinLocal.contains(a.id) ? 1 : 0;
        final bp = _pinLocal.contains(b.id) ? 1 : 0;
        if (ap != bp) return bp - ap;
        return b.ts.compareTo(a.ts);
      });
    });
  }

  void _setCategory(_NotifCategory value) {
    if (_cat == value) return;
    setState(() => _cat = value);
  }

  void _setSearchQuery(String value) {
    if (_search == value) return;
    setState(() => _search = value);
  }

  Future<bool> _confirmDeleteOne(String id) async {
    final target = _findNotif(id);
    if (target != null && _isLocked(target)) return false;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('p5_notif_delete_one_title')),
            content: Text(context.tr('p5_notif_delete_one_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('p5_cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(context.tr('p5_delete')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteOne(String id) async {
    if (!await _confirmDeleteOne(id)) return;
    await _db.ref('notifications/$_houseId/$id').remove();
  }

  Future<void> _clearAll() async {
    final deletable = _filtered.where((n) => !_isLocked(n)).toList();
    if (deletable.isEmpty) {
      _snack(L10nService().translate('notif_no_regular_to_delete'));
      return;
    }

    var catName = L10nService().translate('core_all');
    if (_cat == _NotifCategory.warning) {
      catName = L10nService().translate('notif_category_warning');
    }
    if (_cat == _NotifCategory.friend) {
      catName = L10nService().translate('notif_category_friend');
    }
    if (_cat == _NotifCategory.social) {
      catName = L10nService().translate('notif_category_social');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          L10nService().format('notif_delete_title', {'category': catName}),
        ),
        content: Text(
          L10nService().format('notif_delete_confirm_body', {
            'count': deletable.length,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10nService().translate('core_cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(L10nService().translate('notif_delete_all')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      final updates = <String, dynamic>{};
      for (final n in deletable) {
        updates['notifications/$_houseId/${n.id}'] = null;
      }
      if (updates.isNotEmpty) {
        await _db.ref().update(updates);
      }
      if (mounted) _updateBadge();
    }
  }

  Future<void> _acceptFriendReq(String notifId, String fromHouseId) async {
    if (_houseId == null) return;

    final reqSnap = await _db
        .ref('friend_requests')
        .orderByChild('to')
        .equalTo(_houseId)
        .once();

    String? reqId;
    if (reqSnap.snapshot.exists) {
      final snapshotValue = reqSnap.snapshot.value;
      if (snapshotValue is! Map) {
        _snack(L10nService().translate('notif_invite_not_found'));
        return;
      }
      final map = Map<dynamic, dynamic>.from(snapshotValue);
      for (final entry in map.entries) {
        if (entry.value is! Map) {
          continue;
        }
        final value = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(entry.value),
        );
        if (value['to'] == _houseId && value['status'] == 'pending') {
          reqId = entry.key.toString();
          break;
        }
      }
    }

    if (reqId == null) {
      _snack(L10nService().translate('notif_invite_not_found'));
      return;
    }

    final ok = await _friendsService.acceptFriendRequest(
      requestId: reqId,
      currentHouseId: _houseId!,
      fromHouseId: fromHouseId,
    );
    await _db.ref('notifications/$_houseId/$notifId').remove();
    _snack(
      ok
          ? L10nService().translate('notif_friend_accepted')
          : L10nService().translate('notif_invite_process_error'),
    );
  }

  Future<void> _declineFriendReq(String notifId, String fromHouseId) async {
    if (_houseId == null) return;

    final reqSnap = await _db
        .ref('friend_requests')
        .orderByChild('to')
        .equalTo(_houseId)
        .once();
    if (reqSnap.snapshot.exists) {
      final snapshotValue = reqSnap.snapshot.value;
      if (snapshotValue is! Map) {
        await _db.ref('notifications/$_houseId/$notifId').remove();
        _snack(L10nService().translate('notif_declined'));
        return;
      }
      final map = Map<dynamic, dynamic>.from(snapshotValue);
      for (final entry in map.entries) {
        if (entry.value is! Map) {
          continue;
        }
        final value = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(entry.value),
        );
        if (value['to'] == _houseId && value['status'] == 'pending') {
          await _friendsService.declineFriendRequest(
            entry.key.toString(),
            _houseId!,
          );
          break;
        }
      }
    }

    await _db.ref('notifications/$_houseId/$notifId').remove();
    _snack(L10nService().translate('notif_declined'));
  }

  bool _isCountdownSpaceRequest(_NotifModel notif) {
    return notif.type.toLowerCase() == 'countdown_space_request';
  }

  bool _isCountdownSpaceDeleteRequest(_NotifModel notif) {
    return notif.type.toLowerCase() == 'countdown_space_delete_request';
  }

  String _countdownRequestId(_NotifModel notif) {
    return (notif.raw['requestId'] ?? '').toString().trim();
  }

  String _countdownDeleteSpaceId(_NotifModel notif) {
    return (notif.raw['spaceId'] ?? '').toString().trim();
  }

  Future<void> _acceptCountdownSpaceReq(_NotifModel notif) async {
    final houseId = _houseId;
    final requestId = _countdownRequestId(notif);
    if (houseId == null || requestId.isEmpty) {
      _snack(context.tr('p5_notif_pair_request_missing'));
      return;
    }

    final result = await _countdownSpaceService.acceptRequest(
      requestId: requestId,
      currentHouseId: houseId,
      myHouseName: _houseName,
    );
    if (!result.success) {
      _snack(result.message);
      return;
    }

    await _db.ref('notifications/$houseId/${notif.id}').remove();
    _snack(L10nService().translate('p5_notif_pair_request_accepted'));
  }

  Future<void> _declineCountdownSpaceReq(_NotifModel notif) async {
    final houseId = _houseId;
    final requestId = _countdownRequestId(notif);
    if (houseId == null || requestId.isEmpty) {
      _snack(context.tr('p5_notif_pair_request_missing'));
      return;
    }

    final result = await _countdownSpaceService.declineRequest(
      requestId: requestId,
      currentHouseId: houseId,
    );
    if (!result.success) {
      _snack(result.message);
      return;
    }

    await _db.ref('notifications/$houseId/${notif.id}').remove();
    _snack(L10nService().translate('p5_notif_pair_request_declined'));
  }

  Future<void> _acceptCountdownSpaceDeleteReq(_NotifModel notif) async {
    final houseId = _houseId;
    final spaceId = _countdownDeleteSpaceId(notif);
    if (houseId == null || spaceId.isEmpty) {
      _snack(context.tr('p5_notif_delete_request_missing'));
      return;
    }

    final result = await _countdownSpaceService.acceptDelete(
      spaceId: spaceId,
      currentHouseId: houseId,
    );
    if (!result.success) {
      _snack(result.message);
      return;
    }

    await _db.ref('notifications/$houseId/${notif.id}').remove();
    _snack(result.message);
  }

  Future<void> _dismissCountdownSpaceDeleteReq(_NotifModel notif) async {
    final houseId = _houseId;
    if (houseId == null) return;

    await _db.ref('notifications/$houseId/${notif.id}').remove();
    _snack(L10nService().translate('p5_notif_delete_request_dismissed'));
  }

  @override
  Widget build(BuildContext context) {
    final unread = _all.where((n) => !_isRead(n)).length;
    return Scaffold(
      backgroundColor: SLColors.bgMuted,
      body: Column(
        children: [
          _buildHeader(unread),
          _buildStats(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: SLColors.primaryActive,
                    ),
                  )
                : _filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    physics: SLResponsive.scrollPhysicsForPlatform(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final n = _filtered[i];
                      final isLocked = _isLocked(n);
                      return Dismissible(
                        key: Key(n.id),
                        direction: isLocked
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: SLColors.danger,
                            borderRadius: SLRadius.lgAll,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                              Text(
                                context.tr('p5_delete'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (_) => _confirmDeleteOne(n.id),
                        onDismissed: (_) {
                          setState(() {
                            _all.removeWhere((item) => item.id == n.id);
                          });
                          _updateBadge();
                          unawaited(
                            _db.ref('notifications/$_houseId/${n.id}').remove(),
                          );
                        },
                        child: _buildCard(n),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
