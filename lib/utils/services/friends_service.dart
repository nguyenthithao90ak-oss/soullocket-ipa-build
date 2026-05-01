import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';
import '../core/constants/app_config.dart';
import 'push_notification_helper.dart';
import 'chat_service.dart';

/// ============================================================
///  FriendsService — GRA (Phase 39)
///  Quản Lý Bạn Bè — Friend Management
///
///  Logic theo web gốc: core-friends.js
///  - Gửi/Chấp nhận/Từ chối/Huỷ kết bạn
///  - Giới hạn 1000 bạn bè
///  - Kiểm tra friendRequestPolicy (all, mutual, none) & Limit
///  - Ghim bạn thân (favoriteFriends)
///  - Gửi lời chào (friend_wave)
/// ============================================================

enum FriendRequestPolicy { all, mutual, none }

class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  final _db = FirebaseDatabase.instance;

  Map<String, dynamic>? _asStringDynamicMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. GỬI LỜI MỜI
  // ─────────────────────────────────────────────────────────────

  Future<FriendRequestResult> sendFriendRequest({
    required String fromHouseId,
    required String fromHouseName,
    required String toHouseId,
  }) async {
    final normalizedFromHouseId = fromHouseId.trim();
    final normalizedToHouseId = _normalizeHouseId(toHouseId);
    final normalizedFromHouseName = fromHouseName.trim().isEmpty
        ? normalizedFromHouseId
        : fromHouseName.trim();
    if (normalizedFromHouseId.isEmpty) {
      return FriendRequestResult.error(
        'Không xác định được mã nhà hiện tại để gửi yêu cầu.',
      );
    }

    if (normalizedToHouseId.isEmpty) {
      return FriendRequestResult.error(
        'Bạn chưa nhập mã nhà. Hãy nhập đúng mã như NH_ABC123.',
      );
    }

    if (normalizedFromHouseId == normalizedToHouseId) {
      return FriendRequestResult.error('Không thể kết bạn với chính mình');
    }

    try {
      final targetChecks = await Future.wait([
        _db.ref('houses_public/$normalizedToHouseId').get(),
        _db.ref('friends/$normalizedFromHouseId/$normalizedToHouseId').get(),
        _db
            .ref('friend_requests')
            .orderByChild('from')
            .equalTo(normalizedFromHouseId)
            .get(),
        _db
            .ref('friend_requests')
            .orderByChild('to')
            .equalTo(normalizedFromHouseId)
            .get(),
        _db
            .ref(
              'houses/$normalizedFromHouseId/blocked_users/$normalizedToHouseId',
            )
            .get(),
      ]);

      final targetPublicSnap = targetChecks[0];
      final existingFriendOutSnap = targetChecks[1];
      final outgoingRequestSnap = targetChecks[2];
      final incomingRequestSnap = targetChecks[3];
      final blockedByMeSnap = targetChecks[4];

      if (!targetPublicSnap.exists) {
        return FriendRequestResult.error(
          'Không tìm thấy mã nhà "$normalizedToHouseId". Hãy kiểm tra lại chữ, số và dấu "_" trong mã nhà.',
        );
      }

      if (existingFriendOutSnap.exists) {
        return FriendRequestResult.error(
          'Hai nhà này đã kết nối bạn bè rồi, không cần gửi thêm yêu cầu.',
        );
      }

      if (_hasPendingRequest(
        outgoingRequestSnap,
        fromHouseId: normalizedFromHouseId,
        toHouseId: normalizedToHouseId,
      )) {
        return FriendRequestResult.error(
          'Bạn đã gửi yêu cầu tới mã nhà "$normalizedToHouseId" rồi. Hãy chờ người kia chấp nhận.',
        );
      }

      if (_hasPendingRequest(
        incomingRequestSnap,
        fromHouseId: normalizedToHouseId,
        toHouseId: normalizedFromHouseId,
      )) {
        return FriendRequestResult.error(
          'Mã nhà "$normalizedToHouseId" đã gửi lời mời cho bạn trước đó. Hãy vào mục Lời mời để chấp nhận.',
        );
      }
      if (blockedByMeSnap.value == true) {
        return FriendRequestResult.error(
          'Bạn đã chặn mã nhà này. Hãy bỏ chặn trước khi gửi lời mời.',
        );
      }

      // 1. Đọc settings của người nhận từ houses_public.
      final settingsRoot = targetPublicSnap.value;
      final rootMap = settingsRoot is Map
          ? Map<dynamic, dynamic>.from(settingsRoot)
          : <dynamic, dynamic>{};
      final rawSettings = rootMap['settings'];
      final settings = rawSettings is Map
          ? Map<String, dynamic>.from(rawSettings)
          : <String, dynamic>{};

      final policyStr = settings['friendRequestPolicy']?.toString() ?? 'all';
      final limit = _readInt(settings['friendRequestLimit']) ?? 30;

      // 2. Chặn theo policy
      if (policyStr == 'none') {
        return FriendRequestResult.error(
            'Nhà này đang tắt nhận lời mời kết bạn.');
      }
      if (policyStr == 'mutual') {
        final mutualCount = await _countMutualFriendsBestEffort(
          normalizedFromHouseId,
          normalizedToHouseId,
        );
        if (mutualCount == null) {
          return FriendRequestResult.error(
            'Nhà này chỉ nhận lời mời từ người có bạn chung. Hiện tại app chưa thể kiểm tra điều kiện này.',
          );
        }
        if (mutualCount < 1) {
          return FriendRequestResult.error(
              'Nhà này chỉ nhận lời mời từ người có bạn chung.');
        }
      }

      // 3. Chặn theo giới hạn đang chờ
      final pendingCount =
          await _countPendingRequestsForTarget(normalizedToHouseId);
      if (pendingCount >= limit) {
        return FriendRequestResult.error(
            'Nhà này đã đạt giới hạn lời mời đang chờ.');
      }

      // 4. Gửi request
      await _db.ref('friend_requests').push().set({
        'from': normalizedFromHouseId,
        'fromName': normalizedFromHouseName,
        'to': normalizedToHouseId,
        'ts': ServerValue.timestamp,
        'status': 'pending',
      });

      // Gửi push notification cho người nhận
      await PushNotificationHelper.friendRequest(
        toHouseId: normalizedToHouseId,
        fromHouseId: normalizedFromHouseId,
        fromName: normalizedFromHouseName,
      );

      return FriendRequestResult.success('Đã gửi lời mời! 📨');
    } on FirebaseException catch (error) {
      return FriendRequestResult.error(_mapSendRequestFirebaseError(error));
    } catch (e) {
      return FriendRequestResult.error(_mapSendRequestFallbackError(e));
    }
  }

  String _normalizeHouseId(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  bool _hasPendingRequest(
    DataSnapshot snapshot, {
    required String fromHouseId,
    required String toHouseId,
  }) {
    if (!snapshot.exists || snapshot.value is! Map) {
      return false;
    }

    final entries = _asStringDynamicMap(snapshot.value);
    if (entries == null) {
      return false;
    }
    for (final value in entries.values) {
      final request = _asStringDynamicMap(value);
      if (request == null) {
        continue;
      }
      final requestFrom = request['from']?.toString().trim() ?? '';
      final requestTo = request['to']?.toString().trim() ?? '';
      final status = request['status']?.toString().trim() ?? '';
      if (requestFrom == fromHouseId &&
          requestTo == toHouseId &&
          status == 'pending') {
        return true;
      }
    }

    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // 2. CHẤP NHẬN / TỪ CHỐI / HUỶ
  // ─────────────────────────────────────────────────────────────

  Future<bool> acceptFriendRequest({
    required String requestId,
    required String currentHouseId,
    required String fromHouseId,
  }) async {
    try {
      final reqRef = _db.ref('friend_requests/$requestId');

      // 1. Giới hạn 1000 bạn bè
      final myFriendsSnap = await _db.ref('friends/$currentHouseId').get();
      if (myFriendsSnap.exists) {
        final friends = _asStringDynamicMap(myFriendsSnap.value);
        if ((friends?.length ?? 0) >= 1000) return false;
      }

      // 2. Cập nhật trạng thái request
      await reqRef.child('status').set('accepted');

      // 3. Thêm list bạn bè 2 chiều
      await _db.ref('friends/$currentHouseId/$fromHouseId').set(true);

      // Try to set for the other user.
      // It might fail due to Firebase security rules (only the user can write to their own friends list),
      // so we catch the error to prevent the whole function from failing.
      try {
        await _db.ref('friends/$fromHouseId/$currentHouseId').set(true);
      } catch (_) {}

      // 4. Tạo conversation tự động (DM)
      final convId = _getConversationId(currentHouseId, fromHouseId);
      final convRef = _db.ref('conversations/$convId');

      await convRef.update({
        'ts': ServerValue.timestamp,
        'members/$currentHouseId': true,
        'members/$fromHouseId': true,
        'participants/$currentHouseId': true,
        'participants/$fromHouseId': true,
        'type': 'dm',
      });

      await convRef.child('messages').push().set({
        'from': 'system',
        'senderId': 'system',
        'text': 'Hai bạn đã trở thành bạn bè. Hãy bắt đầu trò chuyện nhé! 👋',
        'ts': ServerValue.timestamp,
        'type': 'system',
      });

      await ChatService().seedFriendWelcomeIfEmpty(currentHouseId, fromHouseId);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> declineFriendRequest(String requestId, String houseId) async {
    await _db.ref('friend_requests/$requestId').update({
      'status': 'declined',
      'declinedBy': houseId,
      'declinedAt': ServerValue.timestamp,
    });
  }

  Future<void> cancelSentFriendRequest(String requestId, String houseId) async {
    await _db.ref('friend_requests/$requestId').update({
      'status': 'declined',
      'canceledBy': houseId,
      'canceledAt': ServerValue.timestamp,
    });
  }

  Future<void> removeFriend(String myHouseId, String friendHouseId) async {
    await _db.ref('friends/$myHouseId/$friendHouseId').remove();
    await _db.ref('friends/$friendHouseId/$myHouseId').remove();
  }

  // ─────────────────────────────────────────────────────────────
  // 3. GHIM BẠN THÂN (FAVORITE)
  // ─────────────────────────────────────────────────────────────

  Future<void> toggleFavoriteFriend(String houseId, String friendId) async {
    final ref = _db.ref('houses/$houseId/settings/favoriteFriends/$friendId');
    final snap = await ref.get();

    if (snap.exists) {
      await ref.remove(); // Bỏ ghim
    } else {
      await ref.set(ServerValue.timestamp); // Ghim
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. STREAM DỮ LIỆU
  // ─────────────────────────────────────────────────────────────

  String? _syncingHouseId;

  /// Stream danh sách ID bạn bè
  Stream<List<String>> streamFriends(String houseId) {
    // Khởi chạy đồng bộ ngầm các lời mời mình gửi đã được người khác chấp nhận
    _startAcceptedRequestsSync(houseId);

    return _db.ref('friends/$houseId').onValue.map((event) {
      final raw = event.snapshot.value;
      if (!event.snapshot.exists || raw is! Map) return <String>[];
      final data = Map<dynamic, dynamic>.from(raw);
      return data.keys.map((e) => e.toString()).toList();
    }).asBroadcastStream();
  }

  void _startAcceptedRequestsSync(String houseId) {
    if (_syncingHouseId == houseId) return;
    _syncingHouseId = houseId;

    // Lắng nghe các thay đổi trên friend_requests mà mình gửi đi
    _db
        .ref('friend_requests')
        .orderByChild('from')
        .equalTo(houseId)
        .onValue
        .listen((event) async {
      final raw = event.snapshot.value;
      if (!event.snapshot.exists || raw is! Map) return;

      final map = Map<dynamic, dynamic>.from(raw);
      for (final entry in map.entries) {
        if (entry.value is! Map) continue;
        final req = Map<String, dynamic>.from(entry.value);
        if (req['status'] == 'accepted') {
          final toHouseId = req['to'] as String?;
          if (toHouseId != null) {
            // Thêm vào danh sách bạn bè của mình
            try {
              await _db.ref('friends/$houseId/$toHouseId').set(true);
              await ChatService().seedFriendWelcomeIfEmpty(houseId, toHouseId);
              // Xoá request sau khi đã đồng bộ
              await _db.ref('friend_requests/${entry.key}').remove();
            } catch (_) {}
          }
        }
      }
    });
  }

  /// Gọi hàm này khi khởi động app hoặc ở HomeScreen để đảm bảo luôn đồng bộ bạn bè
  void initGlobalSync(String houseId) {
    _startAcceptedRequestsSync(houseId);
  }

  /// Stream danh sách lời mời (đến & đi)
  Stream<FriendRequestsData> streamFriendRequests(String houseId) {
    return _db
        .ref('friend_requests')
        .orderByChild('status')
        .equalTo('pending')
        .onValue
        .map((event) {
      final data = FriendRequestsData(sent: {}, received: {});
      final raw = event.snapshot.value;
      if (!event.snapshot.exists || raw is! Map) return data;

      final map = Map<dynamic, dynamic>.from(raw);
      map.forEach((key, value) {
        if (value is! Map) return;
        final req = Map<String, dynamic>.from(value);
        if (req['from'] == houseId) {
          data.sent[req['to']] = key.toString();
        } else if (req['to'] == houseId) {
          data.received[req['from']] = key.toString();
        }
      });
      return data;
    }).asBroadcastStream();
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  Future<int> _countPendingRequestsForTarget(String targetId) async {
    final snap = await _db
        .ref('friend_requests')
        .orderByChild('to')
        .equalTo(targetId)
        .once();
    final raw = snap.snapshot.value;
    if (!snap.snapshot.exists || raw is! Map) return 0;

    final map = Map<dynamic, dynamic>.from(raw);
    return map.values.where((v) => v is Map && v['status'] == 'pending').length;
  }

  Future<int?> _countMutualFriendsBestEffort(String fromId, String toId) async {
    final fromSnap = await _db.ref('friends/$fromId').get();
    try {
      final toSnap = await _db.ref('friends/$toId').get();

      final fromRaw = fromSnap.value;
      final toRaw = toSnap.value;
      if (!fromSnap.exists ||
          !toSnap.exists ||
          fromRaw is! Map ||
          toRaw is! Map) {
        return 0;
      }

      final fromSet = Map<dynamic, dynamic>.from(fromRaw).keys.toSet();
      final toSet = Map<dynamic, dynamic>.from(toRaw).keys.toSet();

      return fromSet.intersection(toSet).length;
    } on FirebaseException catch (error) {
      if (error.code.toLowerCase() == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _mapSendRequestFirebaseError(FirebaseException error) {
    final code = error.code.toLowerCase();
    final raw = (error.message ?? '').toLowerCase();

    if (code == 'permission-denied' ||
        raw.contains('permission-denied') ||
        raw.contains('permission_denied')) {
      return 'Không thể gửi lời mời lúc này. Mã nhà này có thể đã chặn bạn, tắt nhận lời mời, hoặc dữ liệu công khai chưa sẵn sàng.';
    }
    if (code == 'network-request-failed' ||
        code == 'unavailable' ||
        raw.contains('network') ||
        raw.contains('timeout')) {
      return 'Kết nối mạng không ổn định. Hãy kiểm tra mạng rồi thử lại.';
    }
    return 'Không thể gửi lời mời lúc này. Thử lại sau.';
  }

  String _mapSendRequestFallbackError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') ||
        raw.contains('permission_denied')) {
      return 'Không thể gửi lời mời lúc này. Mã nhà này có thể đã chặn bạn, tắt nhận lời mời, hoặc dữ liệu công khai chưa sẵn sàng.';
    }
    if (raw.contains('network') || raw.contains('timeout')) {
      return 'Kết nối mạng không ổn định. Hãy kiểm tra mạng rồi thử lại.';
    }
    return 'Không thể gửi lời mời lúc này. Thử lại sau.';
  }

  String _getConversationId(String id1, String id2) {
    final list = [id1, id2]..sort();
    return '${list[0]}_${list[1]}';
  }

  // ─────────────────────────────────────────────────────────────
  // 5. GỬI LỜI CHÀO (WAVE)
  // ─────────────────────────────────────────────────────────────

  Future<void> sendFriendWave({
    required String myHouseId,
    required String myHouseName,
    required String friendHouseId,
  }) async {
    await PushNotificationHelper.friendWave(
      toHouseId: friendHouseId,
      fromName: myHouseName,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. TÌM KIẾM
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchHouses(String query,
      {int limit = 50}) async {
    final snap = await _db.ref('houses').get();
    final rawValue = snap.value;
    if (!snap.exists || rawValue is! Map) return [];
    final raw = Map<dynamic, dynamic>.from(rawValue);

    // Extract ID or Username from URL if user pastes a link
    String q = query.toLowerCase().trim();
    final webHost = Uri.parse(AppConfig.webBaseUrl).host.toLowerCase();
    if (q.contains('soullocket.com') ||
        q.contains('soullockket.web.app') ||
        q.contains(webHost)) {
      final uri = Uri.tryParse(q);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        q = uri.pathSegments.last.toLowerCase();
      } else {
        final parts = q.split('/');
        q = parts.last.toLowerCase();
      }
    }

    final exactMatches = <Map<String, dynamic>>[];
    final partialMatches = <Map<String, dynamic>>[];
    final suggestions = <Map<String, dynamic>>[];

    raw.forEach((hid, data) {
      if (data is! Map) return;
      final settings = data['settings'];

      // Kiểm tra cài đặt bảo mật: Có cho phép tìm kiếm không?
      final bool searchPrivacy =
          settings is Map ? (settings['searchPrivacy'] != false) : true;
      if (!searchPrivacy) return;

      final name =
          (settings is Map ? settings['houseName']?.toString() : null) ?? '';
      final username =
          (settings is Map ? settings['username']?.toString() : null) ?? '';
      final houseIdStr = hid.toString().toLowerCase();

      final nameLower = name.toLowerCase();
      final usernameLower = username.toLowerCase();

      if (q.isEmpty) {
        suggestions.add({
          'id': hid.toString(),
          'houseName': name.isEmpty ? hid.toString() : name,
          'username': username,
          'houseAvatar': settings is Map ? settings['houseAvatar'] : null,
          'matchScore':
              (username.isNotEmpty ? 30 : 0) + (name.isNotEmpty ? 20 : 0),
        });
        return;
      }

      // Check exact match
      if (houseIdStr == q || usernameLower == q) {
        exactMatches.add({
          'id': hid.toString(),
          'houseName': name,
          'username': username,
          'houseAvatar': settings is Map ? settings['houseAvatar'] : null,
          'matchScore': 100,
        });
        return;
      }

      // Check partial match
      if (nameLower.contains(q) ||
          usernameLower.contains(q) ||
          houseIdStr.contains(q)) {
        partialMatches.add({
          'id': hid.toString(),
          'houseName': name,
          'username': username,
          'houseAvatar': settings is Map ? settings['houseAvatar'] : null,
          'matchScore':
              nameLower.startsWith(q) || usernameLower.startsWith(q) ? 50 : 10,
        });
      }
    });

    partialMatches.sort(
        (a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int));

    if (q.isEmpty) {
      suggestions.sort((a, b) {
        final scoreDiff =
            (b['matchScore'] as int).compareTo(a['matchScore'] as int);
        if (scoreDiff != 0) return scoreDiff;
        final nameA = (a['houseName'] ?? '').toString();
        final nameB = (b['houseName'] ?? '').toString();
        return nameA.compareTo(nameB);
      });
      return suggestions.take(limit).toList();
    }

    final results = [...exactMatches, ...partialMatches];
    return results.take(limit).toList();
  }
}

class FriendRequestResult {
  final bool success;
  final String message;
  FriendRequestResult.success(this.message) : success = true;
  FriendRequestResult.error(this.message) : success = false;
}

class FriendRequestsData {
  final Map<String, String> sent; // {toHouseId: requestId}
  final Map<String, String> received; // {fromHouseId: requestId}

  FriendRequestsData({required this.sent, required this.received});
  int get pendingCount => received.length;
}
