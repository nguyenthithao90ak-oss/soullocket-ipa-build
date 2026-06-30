import 'dart:async';

import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

import 'push_notification_helper.dart';
import 'local_database_service.dart';

class CountdownSpaceRequestResult {
  const CountdownSpaceRequestResult({
    required this.success,
    required this.message,
    this.requestId,
  });

  final bool success;
  final String message;
  final String? requestId;
}

typedef CountdownSpaceRequestInfo = CountdownSpaceRequest;
typedef CountdownSpaceInfo = CountdownSpace;

class CountdownSpaceRequest {
  final String requestId;
  final String spaceId;
  final String fromHouseId;
  final String fromHouseName;
  final String toHouseId;
  final String status;
  final int createdAt;
  final Map<String, dynamic> snapshot;

  const CountdownSpaceRequest({
    required this.requestId,
    required this.spaceId,
    required this.fromHouseId,
    required this.fromHouseName,
    required this.toHouseId,
    required this.status,
    required this.createdAt,
    required this.snapshot,
  });

  String otherHouseIdFor(String myHouseId) =>
      fromHouseId == myHouseId ? toHouseId : fromHouseId;

  bool isOutgoingFor(String myHouseId) => fromHouseId == myHouseId;

  factory CountdownSpaceRequest.fromMap(Map<String, dynamic> map) {
    return CountdownSpaceRequest(
      requestId: map['requestId']?.toString() ?? '',
      spaceId: map['spaceId']?.toString() ?? '',
      fromHouseId: map['fromHouseId']?.toString() ?? '',
      fromHouseName: map['fromHouseName']?.toString() ?? '',
      toHouseId: map['toHouseId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      createdAt: _toInt(map['createdAt']),
      snapshot: _toMap(map['snapshot']),
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'spaceId': spaceId,
        'fromHouseId': fromHouseId,
        'fromHouseName': fromHouseName,
        'toHouseId': toHouseId,
        'status': status,
        'createdAt': createdAt,
        'snapshot': snapshot,
      };
}

class CountdownSpace {
  final String spaceId;
  final String status;
  final Map<String, dynamic> snapshot;
  final int updatedAt;

  const CountdownSpace({
    required this.spaceId,
    required this.status,
    required this.snapshot,
    required this.updatedAt,
  });

  String otherHouseIdFor(String myHouseId) {
    final parts = spaceId.split('_');
    if (parts.length < 2) return '';
    return parts[0] == myHouseId ? parts[1] : parts[0];
  }

  factory CountdownSpace.fromMap(String spaceId, Map<String, dynamic> map) {
    return CountdownSpace(
      spaceId: spaceId,
      status: map['status']?.toString() ?? 'active',
      snapshot: _toMap(map['snapshot']),
      updatedAt: _toInt(map['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'spaceId': spaceId,
        'status': status,
        'snapshot': snapshot,
        'updatedAt': updatedAt,
      };
}

class CountdownSpaceDeleteRequestInfo {
  final String spaceId;
  final String requestedBy;
  final int requestedAt;
  final int deleteAt;
  final String status;

  const CountdownSpaceDeleteRequestInfo({
    required this.spaceId,
    required this.requestedBy,
    required this.requestedAt,
    required this.deleteAt,
    required this.status,
  });

  bool get isPending => status == 'pending';
  bool isRequestedBy(String houseId) => requestedBy == houseId;

  String otherHouseIdFor(String myHouseId) {
    final parts = spaceId.split('_');
    if (parts.length < 2) return '';
    return parts[0] == myHouseId ? parts[1] : parts[0];
  }

  factory CountdownSpaceDeleteRequestInfo.fromMap(
      String spaceId, Map<String, dynamic> map) {
    return CountdownSpaceDeleteRequestInfo(
      spaceId: spaceId,
      requestedBy: map['requestedBy']?.toString() ?? '',
      requestedAt: _toInt(map['requestedAt']),
      deleteAt: _toInt(map['deleteAt']),
      status: map['status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'spaceId': spaceId,
        'requestedBy': requestedBy,
        'requestedAt': requestedAt,
        'deleteAt': deleteAt,
        'status': status,
      };
}

class CountdownSpaceService {
  static final CountdownSpaceService _instance =
      CountdownSpaceService._internal();
  factory CountdownSpaceService() => _instance;
  CountdownSpaceService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  static const int maxSpacesPerHouse = 5;

  Future<CountdownSpaceRequestResult> requestConnection({
    required String fromHouseId,
    required String fromHouseName,
    required String toHouseId,
    required Map<String, dynamic> initialSnapshot,
  }) async {
    final normalizedFromHouseId = fromHouseId.trim();
    final normalizedToHouseId = toHouseId.trim();
    final normalizedFromHouseName = fromHouseName.trim();

    if (normalizedFromHouseId.isEmpty || normalizedToHouseId.isEmpty) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Không xác định được mã nhà để ghép nối.',
      );
    }

    if (normalizedFromHouseId == normalizedToHouseId) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Không thể ghép nối với chính nhà hiện tại.',
      );
    }

    try {
      final targetPublicSnap =
          await _db.ref('houses_public/$normalizedToHouseId').get();
      if (!targetPublicSnap.exists) {
        return CountdownSpaceRequestResult(
          success: false,
          message:
              'Không tìm thấy mã nhà "$normalizedToHouseId". Hãy kiểm tra lại.',
        );
      }

      final spaceId = pairKeyFor(normalizedFromHouseId, normalizedToHouseId);
      final existingSpaces = await _loadSpacesForHouse(normalizedFromHouseId);
      final relatedRequests =
          await _loadRequestsForHouse(normalizedFromHouseId);
      final occupiedHouseIds = _collectOccupiedHouseIds(
        houseId: normalizedFromHouseId,
        spaces: existingSpaces,
        requests: relatedRequests,
      );
      if (!occupiedHouseIds.contains(normalizedToHouseId) &&
          occupiedHouseIds.length >= maxSpacesPerHouse) {
        return const CountdownSpaceRequestResult(
          success: false,
          message:
              'Bạn đã dùng đủ 5 không gian. Hãy xóa bớt một không gian trước khi tạo thêm.',
        );
      }
      for (final existing in existingSpaces) {
        if (existing.spaceId != spaceId) {
          continue;
        }
        if (existing.status == 'active') {
          return const CountdownSpaceRequestResult(
            success: false,
            message: 'Hai nhà này đã ghép chung một không gian đếm rồi.',
          );
        }
      }
      for (final request in relatedRequests) {
        if (request.spaceId != spaceId) {
          continue;
        }
        if (request.status == 'pending') {
          return const CountdownSpaceRequestResult(
            success: false,
            message:
                'Đã có một yêu cầu ghép nối đang chờ xử lý giữa hai nhà này.',
          );
        }
      }

      final requestRef = _db.ref('countdown_space_requests').push();
      final requestId = requestRef.key;
      if (requestId == null || requestId.trim().isEmpty) {
        return const CountdownSpaceRequestResult(
          success: false,
          message: 'Không thể tạo yêu cầu ghép nối lúc này.',
        );
      }

      final payload = <String, dynamic>{
        'requestId': requestId,
        'spaceId': spaceId,
        'fromHouseId': normalizedFromHouseId,
        'fromHouseName': normalizedFromHouseName,
        'toHouseId': normalizedToHouseId,
        'status': 'pending',
        'createdAt': ServerValue.timestamp,
        'snapshot': _sanitizeSnapshot(initialSnapshot),
      };

      await requestRef.set(payload);
      try {
        await PushNotificationHelper.push(
          toHouseId: normalizedToHouseId,
          type: 'countdown_space_request',
          from: normalizedFromHouseId,
          fromId: normalizedFromHouseId,
          fromLabel: normalizedFromHouseName,
          title: 'Yêu cầu ghép nối không gian đếm',
          msg: '$normalizedFromHouseName muốn ghép nối không gian đếm với bạn.',
          extra: <String, dynamic>{
            'requestId': requestId,
            'spaceId': spaceId,
          },
        );
      } catch (_) {}

      return CountdownSpaceRequestResult(
        success: true,
        message: 'Đã gửi yêu cầu ghép nối đến nhà "$normalizedToHouseId".',
        requestId: requestId,
      );
    } catch (e) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Chưa thể hoàn tất thao tác này lúc này. Bạn thử lại sau.',
      );
    }
  }

  Future<CountdownSpaceRequestResult> acceptRequest({
    CountdownSpaceRequest? request,
    String? requestId,
    required String currentHouseId,
    required String myHouseName,
  }) async {
    try {
      CountdownSpaceRequest? finalRequest = request;
      if (finalRequest == null && requestId != null) {
        final snap = await _db.ref('countdown_space_requests/$requestId').get();
        if (snap.exists) {
          finalRequest = CountdownSpaceRequest.fromMap(_toMap(snap.value));
        }
      }

      if (finalRequest == null) {
        return const CountdownSpaceRequestResult(
          success: false,
          message: 'Không tìm thấy yêu cầu ghép nối.',
        );
      }

      final spaceId = finalRequest.spaceId;
      final parts = spaceId.split('_');
      if (parts.length < 2) {
        return const CountdownSpaceRequestResult(
          success: false,
          message: 'Không xác định được không gian ghép nối.',
        );
      }

      final updates = <String, dynamic>{};
      updates['countdown_spaces/$spaceId'] = {
        'spaceId': spaceId,
        'houseA': parts[0],
        'houseB': parts[1],
        'status': 'active',
        'updatedAt': ServerValue.timestamp,
        'snapshot': finalRequest.snapshot,
      };
      updates['countdown_space_requests/${finalRequest.requestId}/status'] =
          'accepted';

      await _db.ref().update(updates);

      try {
        await PushNotificationHelper.push(
          toHouseId: finalRequest.fromHouseId,
          type: 'countdown_space_accepted',
          from: finalRequest.toHouseId,
          fromId: finalRequest.toHouseId,
          fromLabel: myHouseName,
          title: 'Yêu cầu ghép nối được chấp nhận',
          msg: '$myHouseName đã chấp nhận ghép nối không gian đếm với bạn.',
          extra: <String, dynamic>{
            'spaceId': spaceId,
          },
        );
      } catch (_) {}

      return const CountdownSpaceRequestResult(
        success: true,
        message: 'Đã chấp nhận yêu cầu ghép nối.',
      );
    } catch (e) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Chưa thể hoàn tất thao tác này lúc này. Bạn thử lại sau.',
      );
    }
  }

  Future<CountdownSpaceRequestResult> rejectRequest(String requestId) async {
    try {
      final normalizedRequestId = requestId.trim();
      if (normalizedRequestId.isEmpty) {
        return const CountdownSpaceRequestResult(
          success: false,
          message: 'Không xác định được yêu cầu ghép nối.',
        );
      }
      await _db.ref('countdown_space_requests/$normalizedRequestId').update({
        'status': 'rejected',
      });
      return const CountdownSpaceRequestResult(
        success: true,
        message: 'Đã từ chối yêu cầu ghép nối.',
      );
    } catch (e) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Chưa thể hoàn tất thao tác này lúc này. Bạn thử lại sau.',
      );
    }
  }

  Future<CountdownSpaceRequestResult> cancelRequest(String requestId) async {
    try {
      final normalizedRequestId = requestId.trim();
      if (normalizedRequestId.isEmpty) {
        return const CountdownSpaceRequestResult(
          success: false,
          message: 'Không xác định được yêu cầu ghép nối.',
        );
      }
      await _db.ref('countdown_space_requests/$normalizedRequestId').remove();
      return const CountdownSpaceRequestResult(
        success: true,
        message: 'Đã hủy yêu cầu ghép nối.',
      );
    } catch (e) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Chưa thể hoàn tất thao tác này lúc này. Bạn thử lại sau.',
      );
    }
  }

  Future<void> updateSnapshot({
    required String spaceId,
    required Map<String, dynamic> snapshot,
  }) async {
    final normalizedSpaceId = spaceId.trim();
    if (normalizedSpaceId.isEmpty) return;
    await _db.ref('countdown_spaces/$normalizedSpaceId').update({
      'snapshot': _sanitizeSnapshot(snapshot),
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> requestDeleteSpace(String spaceId) async {
    final normalizedSpaceId = spaceId.trim();
    if (normalizedSpaceId.isEmpty) return;
    await _db.ref('countdown_spaces/$normalizedSpaceId').update({
      'status': 'deleted',
      'updatedAt': ServerValue.timestamp,
    });
  }

  Stream<List<CountdownSpaceRequest>> streamIncomingRequests(String houseId) {
    return _db
        .ref('countdown_space_requests')
        .orderByChild('toHouseId')
        .equalTo(houseId.trim())
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      final raw = _toMap(event.snapshot.value);
      final list = <CountdownSpaceRequest>[];
      raw.forEach((key, value) {
        final data = _toMap(value);
        if (data['status'] == 'pending') {
          list.add(CountdownSpaceRequest.fromMap(data));
        }
      });
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<CountdownSpaceRequest>> streamOutgoingRequests(String houseId) {
    return _db
        .ref('countdown_space_requests')
        .orderByChild('fromHouseId')
        .equalTo(houseId.trim())
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      final raw = _toMap(event.snapshot.value);
      final list = <CountdownSpaceRequest>[];
      raw.forEach((key, value) {
        final data = _toMap(value);
        if (data['status'] == 'pending') {
          list.add(CountdownSpaceRequest.fromMap(data));
        }
      });
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<CountdownSpace>> streamActiveSpaces(String houseId) async* {
    final hId = houseId.trim();
    final cacheKey = 'countdown_spaces_$hId';

    final cacheData = await LocalDatabaseService().getCacheEntry(cacheKey);
    if (cacheData != null) {
      try {
        final raw = jsonDecode(cacheData);
        if (raw is List) {
          final list = raw.map((e) => CountdownSpace.fromMap(e['spaceId']?.toString() ?? '', e as Map<String, dynamic>)).toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          yield list;
        }
      } catch (_) {}
    }

    yield* _db.ref('countdown_spaces').onValue.asyncMap((event) async {
      if (event.snapshot.value == null) return [];
      final raw = _toMap(event.snapshot.value);
      final list = <CountdownSpace>[];
      raw.forEach((key, value) {
        final data = _toMap(value);
        if (data['status'] == 'active' && _spaceContainsHouse(key, hId)) {
          list.add(CountdownSpace.fromMap(key, data));
        }
      });
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      final cacheJson = jsonEncode(list.map((e) => e.toJson()).toList());
      LocalDatabaseService().setCacheEntry(cacheKey, cacheJson);

      return list;
    });
  }

  Future<CountdownSpaceRequestResult> sendRequest({
    required String fromHouseId,
    required String fromHouseName,
    required String toHouseId,
    required Map<String, dynamic> initialSnapshot,
  }) =>
      requestConnection(
        fromHouseId: fromHouseId,
        fromHouseName: fromHouseName,
        toHouseId: toHouseId,
        initialSnapshot: initialSnapshot,
      );

  Future<CountdownSpaceRequestResult> declineRequest({
    required String requestId,
    required String currentHouseId,
  }) =>
      rejectRequest(requestId);

  Future<void> updatePendingRequestSnapshot({
    required String requestId,
    required String fromHouseId,
    required Map<String, dynamic> snapshot,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return;
    await _db.ref('countdown_space_requests/$normalizedRequestId').update({
      'snapshot': _sanitizeSnapshot(snapshot),
    });
  }

  Future<void> updateSpaceSnapshot({
    required String selfHouseId,
    required String otherHouseId,
    required Map<String, dynamic> snapshot,
  }) async {
    final normalizedSelfHouseId = selfHouseId.trim();
    final normalizedOtherHouseId = otherHouseId.trim();
    if (normalizedSelfHouseId.isEmpty || normalizedOtherHouseId.isEmpty) return;
    final spaceId = pairKeyFor(normalizedSelfHouseId, normalizedOtherHouseId);
    await updateSnapshot(spaceId: spaceId, snapshot: snapshot);
  }

  Future<CountdownSpaceRequestResult> requestDelete({
    required String spaceId,
    required String currentHouseId,
    required String currentHouseName,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final deleteAt = now + (15 * 24 * 60 * 60 * 1000); // 15 days
      final parts = spaceId.split('_');
      if (parts.length < 2) {
        return const CountdownSpaceRequestResult(
          success: false,
          message: 'Không xác định được không gian cần xóa.',
        );
      }
      await _db.ref('countdown_space_delete_requests/$spaceId').set({
        'spaceId': spaceId,
        'houseA': parts[0],
        'houseB': parts[1],
        'requestedBy': currentHouseId,
        'requestedByHouseId': currentHouseId,
        'requestedAt': now,
        'deleteAt': deleteAt,
        'status': 'pending',
      });
      return const CountdownSpaceRequestResult(
        success: true,
        message: 'Đã gửi yêu cầu xóa không gian.',
      );
    } catch (e) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Chưa thể hoàn tất thao tác này lúc này. Bạn thử lại sau.',
      );
    }
  }

  Future<CountdownSpaceRequestResult> acceptDelete({
    required String spaceId,
    required String currentHouseId,
  }) async {
    try {
      final updates = <String, dynamic>{};
      updates['countdown_spaces/$spaceId/status'] = 'deleted';
      updates['countdown_space_delete_requests/$spaceId/status'] = 'accepted';
      await _db.ref().update(updates);
      return const CountdownSpaceRequestResult(
        success: true,
        message: 'Đã xóa không gian đếm.',
      );
    } catch (e) {
      return const CountdownSpaceRequestResult(
        success: false,
        message: 'Chưa thể hoàn tất thao tác này lúc này. Bạn thử lại sau.',
      );
    }
  }

  Future<void> evaluateDeleteRequest({
    required String spaceId,
    required String currentHouseId,
  }) async {
    final snap =
        await _db.ref('countdown_space_delete_requests/$spaceId').get();
    if (!snap.exists) return;
    final data = _toMap(snap.value);
    if (data['status'] != 'pending') return;
    final deleteAt = _toInt(data['deleteAt']);
    if (DateTime.now().millisecondsSinceEpoch >= deleteAt) {
      await acceptDelete(spaceId: spaceId, currentHouseId: currentHouseId);
    }
  }

  Stream<List<CountdownSpaceRequest>> watchRequestsForHouse(String houseId) {
    final hId = houseId.trim();
    return _db.ref('countdown_space_requests').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = _toMap(event.snapshot.value);
      final list = <CountdownSpaceRequest>[];
      raw.forEach((key, value) {
        final data = _toMap(value);
        if (data['fromHouseId'] == hId || data['toHouseId'] == hId) {
          list.add(CountdownSpaceRequest.fromMap(data));
        }
      });
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<CountdownSpace>> watchSpacesForHouse(String houseId) =>
      streamActiveSpaces(houseId);

  Stream<List<CountdownSpaceDeleteRequestInfo>> watchDeleteRequestsForHouse(
      String houseId) {
    final hId = houseId.trim();
    return _db.ref('countdown_space_delete_requests').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = _toMap(event.snapshot.value);
      final list = <CountdownSpaceDeleteRequestInfo>[];
      raw.forEach((key, value) {
        if (_spaceContainsHouse(key, hId)) {
          list.add(CountdownSpaceDeleteRequestInfo.fromMap(key, _toMap(value)));
        }
      });
      return list;
    });
  }

  String pairKeyFor(String id1, String id2) {
    final ids = [id1.trim(), id2.trim()]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<List<CountdownSpace>> _loadSpacesForHouse(String houseId) async {
    final hId = houseId.trim();
    final snap = await _db.ref('countdown_spaces').get();
    if (!snap.exists || snap.value == null) return [];
    final raw = _toMap(snap.value);
    final list = <CountdownSpace>[];
    raw.forEach((key, value) {
      if (_spaceContainsHouse(key, hId)) {
        list.add(CountdownSpace.fromMap(key, _toMap(value)));
      }
    });
    return list;
  }

  Future<List<CountdownSpaceRequest>> _loadRequestsForHouse(
      String houseId) async {
    final hId = houseId.trim();
    final snap = await _db.ref('countdown_space_requests').get();
    if (!snap.exists || snap.value == null) return [];
    final raw = _toMap(snap.value);
    final list = <CountdownSpaceRequest>[];
    raw.forEach((key, value) {
      final data = _toMap(value);
      if (data['fromHouseId'] == hId || data['toHouseId'] == hId) {
        list.add(CountdownSpaceRequest.fromMap(data));
      }
    });
    return list;
  }

  Set<String> _collectOccupiedHouseIds({
    required String houseId,
    required List<CountdownSpace> spaces,
    required List<CountdownSpaceRequest> requests,
  }) {
    final hId = houseId.trim();
    final result = <String>{};
    for (final s in spaces) {
      if (s.status == 'active') {
        final parts = s.spaceId.split('_');
        for (final p in parts) {
          if (p != hId) result.add(p);
        }
      }
    }
    for (final r in requests) {
      if (r.status == 'pending') {
        if (r.fromHouseId == hId) result.add(r.toHouseId);
        if (r.toHouseId == hId) result.add(r.fromHouseId);
      }
    }
    return result;
  }

  bool _spaceContainsHouse(String spaceId, String houseId) {
    final hId = houseId.trim();
    if (hId.isEmpty) return false;
    return spaceId.split('_').any((part) => part.trim() == hId);
  }

  Map<String, dynamic> _sanitizeSnapshot(Map<String, dynamic> raw) {
    final result = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
