import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
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
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'sendFriendRequestSecure',
        payload: <String, dynamic>{'toHouseId': normalizedToHouseId},
        fallbackErrorMessage: 'Không thể gửi lời mời lúc này.',
      );
      final result = _asStringDynamicMap(response.data) ?? const {};
      final message = result['message']?.toString().trim();
      if (result['success'] == true) {
        return FriendRequestResult.success(
          message?.isNotEmpty == true ? message! : 'Đã gửi lời mời!',
        );
      }
      return FriendRequestResult.error(
        message?.isNotEmpty == true
            ? message!
            : 'Không thể gửi lời mời lúc này.',
      );
    } catch (error) {
      return FriendRequestResult.error(
        _callableErrorMessage(error, 'Không thể gửi lời mời lúc này.'),
      );
    }
  }

  String _normalizeHouseId(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
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
      final normalizedRequestId = requestId.trim();
      final normalizedCurrentHouseId = currentHouseId.trim();
      final normalizedFromHouseId = fromHouseId.trim();
      if (normalizedRequestId.isEmpty ||
          normalizedCurrentHouseId.isEmpty ||
          normalizedFromHouseId.isEmpty) {
        return false;
      }
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'respondFriendRequestSecure',
        payload: <String, dynamic>{
          'requestId': normalizedRequestId,
          'accept': true,
        },
        fallbackErrorMessage: 'Không thể chấp nhận lời mời.',
      );
      final result = _asStringDynamicMap(response.data) ?? const {};
      if (result['success'] != true) return false;
      try {
        await ChatService().seedFriendWelcomeIfEmpty(
          normalizedCurrentHouseId,
          normalizedFromHouseId,
        );
      } catch (error) {
        debugPrint('[FriendsService] Không seed được lời chào chat: $error');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> declineFriendRequest(String requestId, String houseId) async {
    final normalizedRequestId = requestId.trim();
    final normalizedHouseId = houseId.trim();
    if (normalizedRequestId.isEmpty || normalizedHouseId.isEmpty) return;
    await CloudFunctionsHelper.callSecure<dynamic>(
      'respondFriendRequestSecure',
      payload: <String, dynamic>{
        'requestId': normalizedRequestId,
        'accept': false,
      },
      fallbackErrorMessage: 'Không thể từ chối lời mời.',
    );
  }

  Future<void> cancelSentFriendRequest(String requestId, String houseId) async {
    final normalizedRequestId = requestId.trim();
    final normalizedHouseId = houseId.trim();
    if (normalizedRequestId.isEmpty || normalizedHouseId.isEmpty) return;
    await CloudFunctionsHelper.callSecure<dynamic>(
      'cancelFriendRequestSecure',
      payload: <String, dynamic>{'requestId': normalizedRequestId},
      fallbackErrorMessage: 'Không thể hủy lời mời.',
    );
  }

  Future<void> removeFriend(String myHouseId, String friendHouseId) async {
    final normalizedMyHouseId = myHouseId.trim();
    final normalizedFriendHouseId = friendHouseId.trim();
    if (normalizedMyHouseId.isEmpty || normalizedFriendHouseId.isEmpty) return;
    await CloudFunctionsHelper.callSecure<dynamic>(
      'removeFriendSecure',
      payload: <String, dynamic>{'friendHouseId': normalizedFriendHouseId},
      fallbackErrorMessage: 'Không thể hủy kết bạn.',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. GHIM BẠN THÂN (FAVORITE)
  // ─────────────────────────────────────────────────────────────

  Future<void> toggleFavoriteFriend(String houseId, String friendId) async {
    final normalizedHouseId = houseId.trim();
    final normalizedFriendId = friendId.trim();
    if (normalizedHouseId.isEmpty || normalizedFriendId.isEmpty) return;
    final ref = _db.ref(
      'houses/$normalizedHouseId/settings/favoriteFriends/$normalizedFriendId',
    );
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

  /// Stream danh sách ID bạn bè
  Stream<List<String>> streamFriends(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<String>>.value(const <String>[]);
    }
    return _db.ref('friends/$normalizedHouseId').onValue.map((event) {
      final raw = event.snapshot.value;
      if (!event.snapshot.exists || raw is! Map) return <String>[];
      final data = Map<dynamic, dynamic>.from(raw);
      return data.keys.map((e) => e.toString()).toList();
    }).asBroadcastStream();
  }

  /// Quan hệ hai chiều được máy chủ ghi nguyên tử; giữ API này để tương thích
  /// với các màn hình cũ đang gọi khi khởi động.
  void initGlobalSync(String houseId) {
    if (houseId.trim().isEmpty) return;
  }

  /// Stream danh sách lời mời (đến & đi)
  Stream<FriendRequestsData> streamFriendRequests(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<FriendRequestsData>.value(
        FriendRequestsData(sent: {}, received: {}),
      );
    }

    final sentStream = _db
        .ref('friend_requests')
        .orderByChild('from')
        .equalTo(normalizedHouseId)
        .onValue;

    final receivedStream = _db
        .ref('friend_requests')
        .orderByChild('to')
        .equalTo(normalizedHouseId)
        .onValue;

    late StreamController<FriendRequestsData> controller;
    StreamSubscription? sentSub;
    StreamSubscription? receivedSub;

    Map<String, String> currentSent = {};
    Map<String, String> currentReceived = {};

    void emitLatest() {
      if (!controller.isClosed) {
        controller.add(
          FriendRequestsData(
            sent: Map<String, String>.from(currentSent),
            received: Map<String, String>.from(currentReceived),
          ),
        );
      }
    }

    controller = StreamController<FriendRequestsData>.broadcast(
      onListen: () {
        sentSub = sentStream.listen(
          (event) {
            final newSent = <String, String>{};
            final raw = event.snapshot.value;
            if (event.snapshot.exists && raw is Map) {
              final map = Map<dynamic, dynamic>.from(raw);
              map.forEach((key, value) {
                if (value is Map) {
                  final req = Map<String, dynamic>.from(value);
                  if (req['status'] == 'pending') {
                    final to = req['to']?.toString().trim() ?? '';
                    if (to.isNotEmpty) {
                      newSent[to] = key.toString();
                    }
                  }
                }
              });
            }
            currentSent = newSent;
            emitLatest();
          },
          onError: (Object error) {
            if (!controller.isClosed) controller.addError(error);
          },
        );

        receivedSub = receivedStream.listen(
          (event) {
            final newReceived = <String, String>{};
            final raw = event.snapshot.value;
            if (event.snapshot.exists && raw is Map) {
              final map = Map<dynamic, dynamic>.from(raw);
              map.forEach((key, value) {
                if (value is Map) {
                  final req = Map<String, dynamic>.from(value);
                  if (req['status'] == 'pending') {
                    final from = req['from']?.toString().trim() ?? '';
                    if (from.isNotEmpty) {
                      newReceived[from] = key.toString();
                    }
                  }
                }
              });
            }
            currentReceived = newReceived;
            emitLatest();
          },
          onError: (Object error) {
            if (!controller.isClosed) controller.addError(error);
          },
        );
      },
      onCancel: () {
        sentSub?.cancel();
        receivedSub?.cancel();
      },
    );

    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  String _callableErrorMessage(Object error, String fallback) {
    final message = error.toString().replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );
    return message.trim().isEmpty ? fallback : message.trim();
  }

  // ─────────────────────────────────────────────────────────────
  // 5. GỬI LỜI CHÀO (WAVE)
  // ─────────────────────────────────────────────────────────────

  Future<void> sendFriendWave({
    required String myHouseId,
    required String myHouseName,
    required String friendHouseId,
  }) async {
    final normalizedMyHouseName = myHouseName.trim();
    final normalizedFriendHouseId = friendHouseId.trim();
    if (myHouseId.trim().isEmpty ||
        normalizedMyHouseName.isEmpty ||
        normalizedFriendHouseId.isEmpty) {
      return;
    }
    await CloudFunctionsHelper.callSecure<dynamic>(
      'sendFriendWaveSecure',
      payload: <String, dynamic>{'friendHouseId': normalizedFriendHouseId},
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. TÌM KIẾM
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchHouses(
    String query, {
    int limit = 50,
  }) async {
    final effectiveLimit = limit < 1 ? 1 : limit;
    // ⚡ Tối ưu hóa băng thông: Chỉ tải node houses_public (chứa thông tin công khai siêu nhẹ)
    // thay vì tải toàn bộ cây houses (chứa nhật ký, ảnh album của tất cả mọi nhà).
    final snap = await _db.ref('houses_public').get();
    final rawValue = snap.value;
    if (!snap.exists || rawValue is! Map) return [];
    final raw = Map<dynamic, dynamic>.from(rawValue);

    // Extract ID or Username from URL if user pastes a link
    String q = query.toLowerCase().trim();
    final webHost = AppConfig.webHost;
    final knownWebHosts = <String>{
      if (webHost.isNotEmpty) webHost,
      'soullockket.web.app',
      'soullocket.com',
    };
    if (knownWebHosts.any(q.contains)) {
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
      final bool searchPrivacy = settings is Map
          ? (settings['searchPrivacy'] != false)
          : true;
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
          'matchScore': nameLower.startsWith(q) || usernameLower.startsWith(q)
              ? 50
              : 10,
        });
      }
    });

    partialMatches.sort(
      (a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int),
    );

    if (q.isEmpty) {
      suggestions.sort((a, b) {
        final scoreDiff = (b['matchScore'] as int).compareTo(
          a['matchScore'] as int,
        );
        if (scoreDiff != 0) return scoreDiff;
        final nameA = (a['houseName'] ?? '').toString();
        final nameB = (b['houseName'] ?? '').toString();
        return nameA.compareTo(nameB);
      });
      return suggestions.take(effectiveLimit).toList();
    }

    final results = [...exactMatches, ...partialMatches];
    return results.take(effectiveLimit).toList();
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
