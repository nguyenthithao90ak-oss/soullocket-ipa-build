import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../core/sl_theme.dart';
import '../../services/friends_service.dart';
import '../../services/house_service.dart';
import '../../services/schedule_notification_presenter.dart';
import 'package:soullocket_app/services/l10n_service.dart';
import '../../utils/app_error_mapper.dart';

part 'notification_screen_types.dart';
part 'notification_screen_sections.dart';

/// ============================================================
///  NotificationScreen — GRA (UI + Logic)
///  Màn hình danh sách thông báo đầy đủ
///
///  Tính năng (theo core-notifications.js):
///  1. Hiển thị toàn bộ thông báo từ Firebase notifications/{houseId}
///  2. Lọc theo loại: Tất cả / Bạn bè / Like / Bình luận / Hệ thống
///  3. Đánh dấu đã đọc (readAt timestamp)
///  4. Ghim thông báo quan trọng
///  5. Badge đếm chưa đọc (trả về qua GlobalKey)
///  6. Xóa thông báo
/// ============================================================

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _db = FirebaseDatabase.instance;
  final _houseService = HouseService();
  final _friendsService = FriendsService();

  String? _houseId;
  List<_NotifItem> _allNotifs = [];
  final Set<String> _readIds = {};
  final Set<String> _pinnedIds = {};
  NotifFilter _filter = NotifFilter.all;
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  bool _isMarkingAllRead = false;
  bool _isClearingAll = false;
  late final TabController _tabController;
  StreamSubscription<DatabaseEvent>? _notificationsSub;
  Timer? _notificationsDebounce;
  String _lastNotificationsFingerprint = '';
  final Set<String> _busyNotifIds = {};
  String _houseName = '';
  String _nameU1 = '';
  String _nameU2 = '';
  String _startDate = '';
  String _dobU1 = '';
  String _dobU2 = '';
  static const int _notificationsLimit = 100;

  static const _kTabs = [
    (label: 'Tất cả', icon: Icons.notifications_outlined),
    (label: 'Bạn bè', icon: Icons.people_outlined),
    (label: 'Like', icon: Icons.favorite_border),
    (label: 'Bình luận', icon: Icons.chat_bubble_outline),
    (label: 'Hệ thống', icon: Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: _kTabs.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _filter = NotifFilter.values[_tabController.index]);
        }
      });
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachNotificationsListener();
    _tabController.dispose();
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
      NotificationBadgeNotifier().update(0);
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
        .listen(_handleNotificationsEvent);
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
    return isAppResumed && isCurrentRoute && TickerMode.valuesOf(context).enabled;
  }

  void _handleNotificationsEvent(DatabaseEvent event) {
    if (!mounted) return;
    final snap = event.snapshot;
    if (!snap.exists || snap.value == null) {
      _lastNotificationsFingerprint = '';
      _notificationsDebounce?.cancel();
      setState(() {
        _allNotifs = [];
        _isLoading = false;
      });
      NotificationBadgeNotifier().update(0);
      return;
    }

    final snapshotValue = snap.value;
    if (snapshotValue is! Map) {
      _lastNotificationsFingerprint = '';
      _notificationsDebounce?.cancel();
      setState(() {
        _allNotifs = [];
        _isLoading = false;
      });
      NotificationBadgeNotifier().update(0);
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
      final items = <_NotifItem>[];
      raw.forEach((key, value) {
        if (value is Map) {
          try {
            items.add(
              _NotifItem.fromMap(
                key.toString(),
                Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value)),
              ),
            );
          } catch (_) {}
        }
      });
      _sortNotifications(items);
      final unread = items
          .where((n) => !_readIds.contains(n.id) && n.readAt == null)
          .length;
      NotificationBadgeNotifier().update(unread);
      setState(() {
        _allNotifs = items;
        _isLoading = false;
      });
    });
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

  void _sortNotifications(List<_NotifItem> items) {
    items.sort((a, b) {
      final aPinned = a.canPin && _pinnedIds.contains(a.id);
      final bPinned = b.canPin && _pinnedIds.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return b.timestamp.compareTo(a.timestamp);
    });
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
    } catch (_) {}
  }

  ScheduleIdentityContext get _scheduleIdentity => ScheduleIdentityContext(
        houseId: _houseId ?? '',
        houseName: _houseName,
        nameU1: _nameU1,
        nameU2: _nameU2,
        startDate: _startDate,
        dobU1: _dobU1,
        dobU2: _dobU2,
      );

  ScheduleEventPresentation? _schedulePresentation(_NotifItem item) {
    final raw = item.raw;
    final isSchedule =
        raw['kind']?.toString() == 'schedule' || item.id.startsWith('sched_d');
    if (!isSchedule) return null;
    return describeScheduleNotification(
      notificationId: item.id,
      fallbackTitle: item.title,
      fallbackMessage: item.body,
      eventTitle: raw['eventTitle']?.toString() ?? '',
      eventDate: raw['eventDate']?.toString(),
      identity: _scheduleIdentity,
    );
  }

  String _normalizeNotificationText(String value) {
    if (value.trim().isEmpty) {
      return value;
    }
    return value
        .replaceAll(RegExp(r'\bHe thong\b'), 'Hệ thống')
        .replaceAll(RegExp(r'\bhe thong\b'), 'hệ thống')
        .replaceAll(RegExp(r'\bThong bao\b'), 'Thông báo')
        .replaceAll(RegExp(r'\bthong bao\b'), 'thông báo')
        .replaceAll(RegExp(r'\bCanh bao\b'), 'Cảnh báo')
        .replaceAll(RegExp(r'\bcanh bao\b'), 'cảnh báo');
  }

  String _sourceText(_NotifItem item) => _normalizeNotificationText(
        _schedulePresentation(item)?.sourceLabel ?? item.from,
      );

  String _titleText(_NotifItem item) => _normalizeNotificationText(
        _schedulePresentation(item)?.title ?? item.title,
      );

  String _bodyText(_NotifItem item) => _normalizeNotificationText(
        _schedulePresentation(item)?.message ?? item.body,
      );

  bool _matchesFilter(_NotifItem item) {
    if (_filter == NotifFilter.all) return true;
    return switch (_filter) {
      NotifFilter.friend => item.category == 'friend',
      NotifFilter.like => item.category == 'like',
      NotifFilter.comment => item.category == 'comment',
      NotifFilter.system => item.category == 'system',
      NotifFilter.all => true,
    };
  }

  List<_NotifItem> get _filteredNotifs {
    return _allNotifs.where((item) {
      if (!_matchesFilter(item)) return false;
      if (_showUnreadOnly && _isRead(item)) return false;
      return true;
    }).toList();
  }

  int get _unreadCount => _allNotifs
      .where((n) => !_readIds.contains(n.id) && n.readAt == null)
      .length;

  void _toggleUnreadOnly() {
    setState(() => _showUnreadOnly = !_showUnreadOnly);
  }

  Future<void> _markRead(String id) async {
    if (_houseId == null || _readIds.contains(id)) return;
    setState(() => _readIds.add(id));
    final unread = _unreadCount;
    NotificationBadgeNotifier().update(unread);
    try {
      await _db
          .ref('notifications/$_houseId/$id/readAt')
          .set(ServerValue.timestamp);
    } catch (error) {
      if (!mounted) return;
      setState(() => _readIds.remove(id));
      NotificationBadgeNotifier().update(_unreadCount);
      _snack(AppErrorMapper.resolve(error,
              fallbackMessage:
                  'Không đánh dấu đã đọc được: hãy kiểm tra mạng hoặc quyền truy cập.')
          .message);
    }
  }

  Future<void> _markAllRead() async {
    if (_houseId == null || _isMarkingAllRead) return;
    final toMark = _allNotifs
        .where((n) => !_readIds.contains(n.id) && n.readAt == null)
        .toList();
    if (toMark.isEmpty) return;

    final ids = toMark.map((item) => item.id).toList(growable: false);
    setState(() {
      _isMarkingAllRead = true;
      _readIds.addAll(ids);
    });
    NotificationBadgeNotifier().update(0);

    final updates = <String, dynamic>{};
    for (final id in ids) {
      updates['notifications/$_houseId/$id/readAt'] = ServerValue.timestamp;
    }

    try {
      await _db.ref().update(updates);
    } catch (error) {
      if (mounted) {
        setState(() => _readIds.removeAll(ids));
      }
      NotificationBadgeNotifier().update(_unreadCount);
      _snack(AppErrorMapper.resolve(error,
              fallbackMessage:
                  'Không đánh dấu tất cả đã đọc được: hãy kiểm tra mạng hoặc quyền truy cập.')
          .message);
    } finally {
      if (!mounted) {
        _isMarkingAllRead = false;
      } else {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }

  Future<void> _togglePin(_NotifItem item) async {
    if (!item.canPin) return;
    setState(() {
      if (_pinnedIds.contains(item.id)) {
        _pinnedIds.remove(item.id);
      } else {
        _pinnedIds.add(item.id);
      }
      _sortNotifications(_allNotifs);
    });
  }

  Future<bool> _deleteNotif(_NotifItem item) async {
    if (_houseId == null ||
        !item.canDelete ||
        _busyNotifIds.contains(item.id)) {
      return false;
    }

    setState(() => _busyNotifIds.add(item.id));
    try {
      await _db.ref('notifications/$_houseId/${item.id}').remove();
      return true;
    } catch (error) {
      _snack(AppErrorMapper.resolve(error,
              fallbackMessage:
                  'Không xóa được thông báo: có thể thông báo đã bị xóa hoặc bạn không còn quyền.')
          .message);
      return false;
    } finally {
      if (!mounted) {
        _busyNotifIds.remove(item.id);
      } else {
        setState(() => _busyNotifIds.remove(item.id));
      }
    }
  }

  bool _isRead(_NotifItem n) => _readIds.contains(n.id) || n.readAt != null;

  Future<void> _clearAllDeletable() async {
    if (_houseId == null || _isClearingAll) return;
    final deletable = _allNotifs.where((item) => item.canDelete).toList();
    if (deletable.isEmpty) {
      _snack(
          'Không có thông báo nào có thể xóa. Thông báo hệ thống được giữ nguyên.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa thông báo?'),
        content: Text(
          'Sẽ xóa ${deletable.length} thông báo thường. Thông báo hệ thống sẽ được giữ lại.',
          style: SLTheme.quicksand(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updates = <String, dynamic>{};
    for (final item in deletable) {
      updates['notifications/$_houseId/${item.id}'] = null;
    }
    setState(() => _isClearingAll = true);
    try {
      await _db.ref().update(updates);
      _snack('Đã xóa toàn bộ thông báo thường.');
    } catch (error) {
      _snack(AppErrorMapper.resolve(error,
              fallbackMessage:
                  'Không xóa được thông báo: có thể một số thông báo đã bị xóa hoặc bạn không còn quyền.')
          .message);
    } finally {
      if (!mounted) {
        _isClearingAll = false;
      } else {
        setState(() => _isClearingAll = false);
      }
    }
  }

  Future<void> _openDetails(_NotifItem item) async {
    if (!_isRead(item)) {
      await _markRead(item.id);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildDetailSheet(sheetContext, item),
    );
  }

  Future<void> _acceptFriendRequest(_NotifItem item) async {
    if (_houseId == null || _busyNotifIds.contains(item.id)) return;
    setState(() => _busyNotifIds.add(item.id));
    try {
      final fromHouseId =
          (item.fromId ?? item.raw['from']?.toString() ?? '').trim();
      if (fromHouseId.isEmpty) {
        _snack('Không tìm thấy người gửi lời mời.');
        return;
      }

      final requestSnap = await _db
          .ref('friend_requests')
          .orderByChild('from')
          .equalTo(fromHouseId)
          .once();

      String? requestId;
      if (requestSnap.snapshot.exists) {
        final snapshotValue = requestSnap.snapshot.value;
        if (snapshotValue is! Map) {
          _snack('Không tìm thấy lời mời.');
          return;
        }
        final map = Map<dynamic, dynamic>.from(snapshotValue);
        for (final entry in map.entries) {
          if (entry.value is! Map) {
            continue;
          }
          final request = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(entry.value),
          );

          if (request['to'] == _houseId && request['status'] == 'pending') {
            requestId = entry.key.toString();
            break;
          }
        }
      }

      if (requestId == null) {
        _snack('Lời mời này đã được xử lý hoặc không còn tồn tại.');
        return;
      }

      final ok = await _friendsService.acceptFriendRequest(
        requestId: requestId,
        currentHouseId: _houseId!,
        fromHouseId: fromHouseId,
      );
      if (!ok) {
        _snack(
            'Không chấp nhận được lời mời: lời mời có thể đã đổi trạng thái hoặc kết nối đang lỗi.');
        return;
      }

      await _db.ref('notifications/$_houseId/${item.id}').remove();
      _snack('Đã chấp nhận lời mời kết bạn.');
    } catch (error) {
      _snack(AppErrorMapper.resolve(error,
              fallbackMessage:
                  'Không xử lý được lời mời kết bạn: hãy kiểm tra mạng hoặc trạng thái lời mời.')
          .message);
    } finally {
      if (!mounted) {
        _busyNotifIds.remove(item.id);
      } else {
        setState(() => _busyNotifIds.remove(item.id));
      }
    }
  }

  Future<void> _declineFriendRequest(_NotifItem item) async {
    if (_houseId == null || _busyNotifIds.contains(item.id)) return;
    setState(() => _busyNotifIds.add(item.id));
    try {
      final fromHouseId =
          (item.fromId ?? item.raw['from']?.toString() ?? '').trim();
      if (fromHouseId.isEmpty) {
        _snack('Không tìm thấy người gửi lời mời.');
        return;
      }

      final requestSnap = await _db
          .ref('friend_requests')
          .orderByChild('from')
          .equalTo(fromHouseId)
          .once();

      if (requestSnap.snapshot.exists) {
        final snapshotValue = requestSnap.snapshot.value;
        if (snapshotValue is! Map) {
          await _db.ref('notifications/$_houseId/${item.id}').remove();
          _snack('Đã từ chối ❌');
          return;
        }
        final map = Map<dynamic, dynamic>.from(snapshotValue);
        for (final entry in map.entries) {
          if (entry.value is! Map) {
            continue;
          }
          final request = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(entry.value),
          );

          if (request['to'] == _houseId && request['status'] == 'pending') {
            await _friendsService.declineFriendRequest(
              entry.key.toString(),
              _houseId!,
            );
            break;
          }
        }
      }

      await _db.ref('notifications/$_houseId/${item.id}').remove();
      _snack('Đã từ chối lời mời.');
    } catch (error) {
      _snack(AppErrorMapper.resolve(error,
              fallbackMessage:
                  'Không từ chối được lời mời: hãy kiểm tra mạng hoặc trạng thái lời mời.')
          .message);
    } finally {
      if (!mounted) {
        _busyNotifIds.remove(item.id);
      } else {
        setState(() => _busyNotifIds.remove(item.id));
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SLColors.bgMuted,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          _buildUtilityBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: SLColors.primaryActive,
                    ),
                  )
                : _filteredNotifs.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredNotifs.length,
                        itemBuilder: (context, i) =>
                            _buildCard(_filteredNotifs[i]),
                      ),
          ),
        ],
      ),
    );
  }
}
