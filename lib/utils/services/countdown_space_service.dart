import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';

import 'push_notification_helper.dart';

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

class CountdownSpaceActionResult {
  const CountdownSpaceActionResult({
    required this.success,
    required this.message,
    this.spaceId,
    this.otherHouseId,
  });

  final bool success;
  final String message;
  final String? spaceId;
  final String? otherHouseId;
}

class CountdownSpaceRequestInfo {
  const CountdownSpaceRequestInfo({
    required this.requestId,
    required this.spaceId,
    required this.fromHouseId,
    required this.toHouseId,
    required this.fromHouseName,
    required this.status,
    required this.createdAt,
    required this.snapshot,
  });

  final String requestId;
  final String spaceId;
  final String fromHouseId;
  final String toHouseId;
  final String fromHouseName;
  final String status;
  final int createdAt;
  final Map<String, dynamic> snapshot;

  bool involvesHouse(String houseId) {
    final normalizedHouseId = houseId.trim();
    return normalizedHouseId.isNotEmpty &&
        (fromHouseId == normalizedHouseId || toHouseId == normalizedHouseId);
  }

  bool isOutgoingFor(String houseId) => fromHouseId == houseId.trim();

  String otherHouseIdFor(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId == fromHouseId) {
      return toHouseId;
    }
    if (normalizedHouseId == toHouseId) {
      return fromHouseId;
    }
    return '';
  }

  factory CountdownSpaceRequestInfo.fromMap(
    String requestId,
    Map<String, dynamic> data,
  ) {
    return CountdownSpaceRequestInfo(
      requestId: requestId,
      spaceId: (data['spaceId'] ?? '').toString().trim(),
      fromHouseId: (data['fromHouseId'] ?? '').toString().trim(),
      toHouseId: (data['toHouseId'] ?? '').toString().trim(),
      fromHouseName: (data['fromHouseName'] ?? '').toString().trim(),
      status: (data['status'] ?? 'pending').toString().trim().toLowerCase(),
      createdAt: (data['createdAt'] as num?)?.toInt() ??
          (data['ts'] as num?)?.toInt() ??
          0,
      snapshot: CountdownSpaceService._toStringDynamicMap(data['snapshot']),
    );
  }
}

class CountdownSpaceInfo {
  const CountdownSpaceInfo({
    required this.spaceId,
    required this.houseA,
    required this.houseB,
    required this.status,
    required this.updatedAt,
    required this.memberHouseIds,
    required this.snapshot,
  });

  final String spaceId;
  final String houseA;
  final String houseB;
  final String status;
  final int updatedAt;
  final Set<String> memberHouseIds;
  final Map<String, dynamic> snapshot;

  bool containsHouse(String houseId) => memberHouseIds.contains(houseId.trim());

  String otherHouseIdFor(String houseId) {
    final normalizedHouseId = houseId.trim();
    for (final memberHouseId in memberHouseIds) {
      if (memberHouseId != normalizedHouseId) {
        return memberHouseId;
      }
    }
    return '';
  }

  factory CountdownSpaceInfo.fromMap(
    String spaceId,
    Map<String, dynamic> data,
  ) {
    final rawMembers =
        CountdownSpaceService._toStringDynamicMap(data['memberHouseIds']);
    final members = <String>{};
    rawMembers.forEach((key, value) {
      if (value == true) {
        members.add(key.trim());
      }
    });
    final safeHouseA = (data['houseA'] ?? '').toString().trim();
    final safeHouseB = (data['houseB'] ?? '').toString().trim();
    if (safeHouseA.isNotEmpty) {
      members.add(safeHouseA);
    }
    if (safeHouseB.isNotEmpty) {
      members.add(safeHouseB);
    }
    return CountdownSpaceInfo(
      spaceId: spaceId,
      houseA: safeHouseA,
      houseB: safeHouseB,
      status: (data['status'] ?? 'active').toString().trim().toLowerCase(),
      updatedAt: (data['updatedAt'] as num?)?.toInt() ??
          (data['createdAt'] as num?)?.toInt() ??
          0,
      memberHouseIds: members,
      snapshot: CountdownSpaceService._toStringDynamicMap(data['snapshot']),
    );
  }
}

class CountdownSpaceDeleteRequestInfo {
  const CountdownSpaceDeleteRequestInfo({
    required this.spaceId,
    required this.houseA,
    required this.houseB,
    required this.requestedByHouseId,
    required this.requestedByHouseName,
    required this.status,
    required this.requestedAt,
    required this.deleteAt,
    required this.updatedAt,
  });

  final String spaceId;
  final String houseA;
  final String houseB;
  final String requestedByHouseId;
  final String requestedByHouseName;
  final String status;
  final int requestedAt;
  final int deleteAt;
  final int updatedAt;

  bool get isPending => status == 'pending';

  bool involvesHouse(String houseId) {
    final normalizedHouseId = houseId.trim();
    return normalizedHouseId.isNotEmpty &&
        (houseA == normalizedHouseId || houseB == normalizedHouseId);
  }

  bool isRequestedBy(String houseId) =>
      requestedByHouseId == houseId.trim().toUpperCase();

  String otherHouseIdFor(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId == houseA) {
      return houseB;
    }
    if (normalizedHouseId == houseB) {
      return houseA;
    }
    return '';
  }

  factory CountdownSpaceDeleteRequestInfo.fromMap(
    String spaceId,
    Map<String, dynamic> data,
  ) {
    return CountdownSpaceDeleteRequestInfo(
      spaceId: spaceId,
      houseA: (data['houseA'] ?? '').toString().trim(),
      houseB: (data['houseB'] ?? '').toString().trim(),
      requestedByHouseId:
          (data['requestedByHouseId'] ?? '').toString().trim().toUpperCase(),
      requestedByHouseName:
          (data['requestedByHouseName'] ?? '').toString().trim(),
      status: (data['status'] ?? 'pending').toString().trim().toLowerCase(),
      requestedAt: (data['requestedAt'] as num?)?.toInt() ??
          (data['createdAt'] as num?)?.toInt() ??
          0,
      deleteAt: (data['deleteAt'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updatedAt'] as num?)?.toInt() ??
          (data['requestedAt'] as num?)?.toInt() ??
          0,
    );
  }
}

class CountdownSpaceService {
  CountdownSpaceService._();

  static final CountdownSpaceService _instance = CountdownSpaceService._();
  static const int maxSpacesPerHouse = 5;
  static const Duration deleteGracePeriod = Duration(days: 15);

  factory CountdownSpaceService() => _instance;

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  String pairKeyFor(String houseIdA, String houseIdB) {
    final a = houseIdA.trim().toUpperCase();
    final b = houseIdB.trim().toUpperCase();
    if (a.isEmpty || b.isEmpty) {
      return '';
    }
    final pair = [a, b]..sort();
    return '${pair[0]}__${pair[1]}';
  }

  Stream<List<CountdownSpaceRequestInfo>> watchRequestsForHouse(
      String houseId) {
    final normalizedHouseId = houseId.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) {
      return const Stream<List<CountdownSpaceRequestInfo>>.empty();
    }

    return _mergeRequestStreams(
      _watchRequestsByHouseField('fromHouseId', normalizedHouseId),
      _watchRequestsByHouseField('toHouseId', normalizedHouseId),
    );
  }

  Stream<List<CountdownSpaceInfo>> watchSpacesForHouse(String houseId) {
    final normalizedHouseId = houseId.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) {
      return const Stream<List<CountdownSpaceInfo>>.empty();
    }

    return _mergeSpaceStreams(
      _watchSpacesByHouseField('houseA', normalizedHouseId),
      _watchSpacesByHouseField('houseB', normalizedHouseId),
    );
  }

  Stream<List<CountdownSpaceDeleteRequestInfo>> watchDeleteRequestsForHouse(
    String houseId,
  ) {
    final normalizedHouseId = houseId.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) {
      return const Stream<List<CountdownSpaceDeleteRequestInfo>>.empty();
    }

    return _mergeDeleteRequestStreams(
      _watchDeleteRequestsByHouseField('houseA', normalizedHouseId),
      _watchDeleteRequestsByHouseField('houseB', normalizedHouseId),
    );
  }

  Future<CountdownSpaceRequestResult> sendRequest({
    required String fromHouseId,
    required String fromHouseName,
    required String toHouseId,
    required Map<String, dynamic> initialSnapshot,
  }) async {
    final normalizedFromHouseId = fromHouseId.trim().toUpperCase();
    final normalizedToHouseId = toHouseId.trim().toUpperCase();
    final normalizedFromHouseName = fromHouseName.trim().isEmpty
        ? normalizedFromHouseId
        : fromHouseName.trim();

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

      return CountdownSpaceRequestResult(
        success: true,
        message: 'Đã gửi yêu cầu ghép nối.',
        requestId: requestId,
      );
    } on FirebaseException catch (error) {
      return CountdownSpaceRequestResult(
        success: false,
        message: _mapSendRequestFirebaseError(error),
      );
    } catch (error) {
      return CountdownSpaceRequestResult(
        success: false,
        message: _mapSendRequestFallbackError(error),
      );
    }
  }

  Future<void> updatePendingRequestSnapshot({
    required String requestId,
    required String fromHouseId,
    required Map<String, dynamic> snapshot,
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedFromHouseId = fromHouseId.trim().toUpperCase();
    if (normalizedRequestId.isEmpty || normalizedFromHouseId.isEmpty) {
      return;
    }

    final ref = _db.ref('countdown_space_requests/$normalizedRequestId');
    final snap = await ref.get();
    if (!snap.exists || snap.value is! Map) {
      return;
    }

    final request = CountdownSpaceRequestInfo.fromMap(
      normalizedRequestId,
      Map<String, dynamic>.from(snap.value as Map),
    );
    if (request.status != 'pending' ||
        request.fromHouseId != normalizedFromHouseId) {
      return;
    }

    await ref.update(<String, dynamic>{
      'snapshot': _sanitizeSnapshot(snapshot),
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<CountdownSpaceActionResult> acceptRequest({
    required String requestId,
    required String currentHouseId,
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedCurrentHouseId = currentHouseId.trim().toUpperCase();
    if (normalizedRequestId.isEmpty || normalizedCurrentHouseId.isEmpty) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Không xác định được yêu cầu ghép nối.',
      );
    }

    final requestRef = _db.ref('countdown_space_requests/$normalizedRequestId');
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists || requestSnap.value is! Map) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Yêu cầu ghép nối đã không còn tồn tại.',
      );
    }

    final request = CountdownSpaceRequestInfo.fromMap(
      normalizedRequestId,
      Map<String, dynamic>.from(requestSnap.value as Map),
    );
    if (!request.involvesHouse(normalizedCurrentHouseId)) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Bạn không có quyền xử lý yêu cầu này.',
      );
    }

    if (request.status == 'accepted') {
      return CountdownSpaceActionResult(
        success: true,
        message: 'Không gian đã được ghép nối trước đó.',
        spaceId: request.spaceId,
        otherHouseId: request.otherHouseIdFor(normalizedCurrentHouseId),
      );
    }

    if (request.status != 'pending') {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Yêu cầu này không còn ở trạng thái chờ xử lý.',
      );
    }

    final currentSpaces = await _loadSpacesForHouse(normalizedCurrentHouseId);
    final currentRequests =
        await _loadRequestsForHouse(normalizedCurrentHouseId);
    final occupiedHouseIds = _collectOccupiedHouseIds(
      houseId: normalizedCurrentHouseId,
      spaces: currentSpaces,
      requests: currentRequests,
    );
    final nextOtherHouseId = request.otherHouseIdFor(normalizedCurrentHouseId);
    if (!occupiedHouseIds.contains(nextOtherHouseId) &&
        occupiedHouseIds.length >= maxSpacesPerHouse) {
      return const CountdownSpaceActionResult(
        success: false,
        message:
            'Nhà của bạn đã đủ 5 không gian. Hãy xóa bớt một không gian trước khi chấp nhận thêm.',
      );
    }

    final spaceId = request.spaceId.trim().isEmpty
        ? pairKeyFor(request.fromHouseId, request.toHouseId)
        : request.spaceId;
    final updates = <String, dynamic>{
      'countdown_space_requests/$normalizedRequestId/status': 'accepted',
      'countdown_space_requests/$normalizedRequestId/respondedAt':
          ServerValue.timestamp,
      'countdown_spaces/$spaceId/spaceId': spaceId,
      'countdown_spaces/$spaceId/houseA': _sortedPair(
        request.fromHouseId,
        request.toHouseId,
      )[0],
      'countdown_spaces/$spaceId/houseB': _sortedPair(
        request.fromHouseId,
        request.toHouseId,
      )[1],
      'countdown_spaces/$spaceId/memberHouseIds/${request.fromHouseId}': true,
      'countdown_spaces/$spaceId/memberHouseIds/${request.toHouseId}': true,
      'countdown_spaces/$spaceId/status': 'active',
      'countdown_spaces/$spaceId/requestId': normalizedRequestId,
      'countdown_spaces/$spaceId/createdAt': ServerValue.timestamp,
      'countdown_spaces/$spaceId/snapshot': _sanitizeSnapshot(request.snapshot),
      'countdown_spaces/$spaceId/updatedAt': ServerValue.timestamp,
      'countdown_spaces/$spaceId/updatedByHouseId': normalizedCurrentHouseId,
    };

    await _db.ref().update(updates);

    final otherHouseId = request.otherHouseIdFor(normalizedCurrentHouseId);
    final actorLabel = await _resolveHouseLabel(normalizedCurrentHouseId);
    if (otherHouseId.isNotEmpty) {
      await PushNotificationHelper.push(
        toHouseId: otherHouseId,
        type: 'countdown_space_accept',
        from: normalizedCurrentHouseId,
        fromId: normalizedCurrentHouseId,
        fromLabel: actorLabel,
        title: 'Ghép nối không gian đếm thành công',
        msg:
            '$actorLabel đã chấp nhận ghép nối. Hai bên đang dùng chung một không gian đếm.',
        extra: <String, dynamic>{
          'requestId': normalizedRequestId,
          'spaceId': spaceId,
        },
      );
    }

    return CountdownSpaceActionResult(
      success: true,
      message: 'Đã chấp nhận ghép nối không gian.',
      spaceId: spaceId,
      otherHouseId: otherHouseId,
    );
  }

  Future<CountdownSpaceActionResult> declineRequest({
    required String requestId,
    required String currentHouseId,
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedCurrentHouseId = currentHouseId.trim().toUpperCase();
    if (normalizedRequestId.isEmpty || normalizedCurrentHouseId.isEmpty) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Không xác định được yêu cầu ghép nối.',
      );
    }

    final ref = _db.ref('countdown_space_requests/$normalizedRequestId');
    final snap = await ref.get();
    if (!snap.exists || snap.value is! Map) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Yêu cầu ghép nối đã không còn tồn tại.',
      );
    }

    final request = CountdownSpaceRequestInfo.fromMap(
      normalizedRequestId,
      Map<String, dynamic>.from(snap.value as Map),
    );
    if (!request.involvesHouse(normalizedCurrentHouseId)) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Bạn không có quyền xử lý yêu cầu này.',
      );
    }

    await ref.update(<String, dynamic>{
      'status': 'declined',
      'respondedAt': ServerValue.timestamp,
    });

    return const CountdownSpaceActionResult(
      success: true,
      message: 'Đã từ chối yêu cầu ghép nối.',
    );
  }

  Future<void> updateSpaceSnapshot({
    required String selfHouseId,
    required String otherHouseId,
    required Map<String, dynamic> snapshot,
  }) async {
    final spaceId = pairKeyFor(selfHouseId, otherHouseId);
    if (spaceId.isEmpty) {
      return;
    }
    await _db.ref('countdown_spaces/$spaceId').update(<String, dynamic>{
      'snapshot': _sanitizeSnapshot(snapshot),
      'updatedAt': ServerValue.timestamp,
      'updatedByHouseId': selfHouseId.trim().toUpperCase(),
    });
  }

  Future<CountdownSpaceActionResult> requestDelete({
    required String spaceId,
    required String currentHouseId,
    required String currentHouseName,
  }) async {
    final normalizedSpaceId = spaceId.trim();
    final normalizedCurrentHouseId = currentHouseId.trim().toUpperCase();
    if (normalizedSpaceId.isEmpty || normalizedCurrentHouseId.isEmpty) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Không xác định được không gian cần xóa.',
      );
    }

    final space = await _getSpaceById(normalizedSpaceId);
    if (space == null || space.status != 'active') {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Không gian này không còn tồn tại hoặc đã bị xóa.',
      );
    }
    if (!space.containsHouse(normalizedCurrentHouseId)) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Bạn không có quyền gửi yêu cầu xóa không gian này.',
      );
    }

    final existingRequest = await _getDeleteRequestBySpaceId(normalizedSpaceId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existingRequest != null && existingRequest.isPending) {
      if (existingRequest.deleteAt > 0 && now >= existingRequest.deleteAt) {
        await _deleteSpaceFromDeleteRequest(
          existingRequest,
          actorHouseId: normalizedCurrentHouseId,
          reason: 'expired_15_days',
        );
        return const CountdownSpaceActionResult(
          success: true,
          message: 'Không gian đã tự xóa sau thời gian chờ 15 ngày.',
        );
      }

      final deadlineLabel = _formatDateTime(existingRequest.deleteAt);
      if (existingRequest.isRequestedBy(normalizedCurrentHouseId)) {
        return CountdownSpaceActionResult(
          success: false,
          message:
              'Yêu cầu xóa đã được gửi trước đó. Không gian sẽ tự xóa vào $deadlineLabel nếu bên kia chưa xác nhận.',
        );
      }
      return CountdownSpaceActionResult(
        success: false,
        message:
            'Phía bên kia đã gửi yêu cầu xóa. Bạn có thể xác nhận ngay hoặc chờ đến $deadlineLabel để hệ thống tự xóa.',
      );
    }

    final deleteAt = now + deleteGracePeriod.inMilliseconds;
    final actorLabel = currentHouseName.trim().isEmpty
        ? await _resolveHouseLabel(normalizedCurrentHouseId)
        : currentHouseName.trim();
    final pair = _sortedPair(space.houseA, space.houseB);
    final otherHouseId = space.otherHouseIdFor(normalizedCurrentHouseId);

    await _db.ref('countdown_space_delete_requests/$normalizedSpaceId').set(
      <String, dynamic>{
        'spaceId': normalizedSpaceId,
        'houseA': pair[0],
        'houseB': pair[1],
        'requestedByHouseId': normalizedCurrentHouseId,
        'requestedByHouseName': actorLabel,
        'status': 'pending',
        'requestedAt': now,
        'deleteAt': deleteAt,
        'updatedAt': ServerValue.timestamp,
      },
    );

    if (otherHouseId.isNotEmpty) {
      await PushNotificationHelper.push(
        toHouseId: otherHouseId,
        type: 'countdown_space_delete_request',
        from: normalizedCurrentHouseId,
        fromId: normalizedCurrentHouseId,
        fromLabel: actorLabel,
        title: 'Yêu cầu xóa không gian đếm',
        msg:
            '$actorLabel muốn xóa không gian đếm này. Nếu bạn không xác nhận, không gian sẽ tự xóa sau 15 ngày.',
        extra: <String, dynamic>{
          'spaceId': normalizedSpaceId,
          'deleteAt': deleteAt,
        },
      );
    }

    return CountdownSpaceActionResult(
      success: true,
      message:
          'Đã gửi yêu cầu xóa. Nếu bên kia không xác nhận, không gian sẽ tự xóa vào ${_formatDateTime(deleteAt)}.',
      spaceId: normalizedSpaceId,
      otherHouseId: otherHouseId,
    );
  }

  Future<CountdownSpaceActionResult> acceptDelete({
    required String spaceId,
    required String currentHouseId,
  }) async {
    final normalizedSpaceId = spaceId.trim();
    final normalizedCurrentHouseId = currentHouseId.trim().toUpperCase();
    if (normalizedSpaceId.isEmpty || normalizedCurrentHouseId.isEmpty) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Không xác định được yêu cầu xóa không gian.',
      );
    }

    final request = await _getDeleteRequestBySpaceId(normalizedSpaceId);
    if (request == null || !request.isPending) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Yêu cầu xóa không gian không còn khả dụng.',
      );
    }
    if (!request.involvesHouse(normalizedCurrentHouseId)) {
      return const CountdownSpaceActionResult(
        success: false,
        message: 'Bạn không có quyền xác nhận yêu cầu xóa này.',
      );
    }
    if (request.isRequestedBy(normalizedCurrentHouseId)) {
      return const CountdownSpaceActionResult(
        success: false,
        message:
            'Bạn đã gửi yêu cầu xóa trước đó. Hãy chờ bên kia xác nhận hoặc đợi hệ thống tự xóa sau 15 ngày.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = request.deleteAt > 0 && now >= request.deleteAt;
    await _deleteSpaceFromDeleteRequest(
      request,
      actorHouseId: normalizedCurrentHouseId,
      reason: expired ? 'expired_15_days' : 'partner_approved',
    );

    return CountdownSpaceActionResult(
      success: true,
      message: expired
          ? 'Không gian đã tự xóa do hết thời gian chờ 15 ngày.'
          : 'Đã xác nhận xóa. Không gian này đã được gỡ cho cả hai bên.',
      spaceId: normalizedSpaceId,
      otherHouseId: request.otherHouseIdFor(normalizedCurrentHouseId),
    );
  }

  Future<void> evaluateDeleteRequest({
    required String spaceId,
    required String currentHouseId,
  }) async {
    final normalizedSpaceId = spaceId.trim();
    final normalizedCurrentHouseId = currentHouseId.trim().toUpperCase();
    if (normalizedSpaceId.isEmpty || normalizedCurrentHouseId.isEmpty) {
      return;
    }

    final request = await _getDeleteRequestBySpaceId(normalizedSpaceId);
    if (request == null ||
        !request.isPending ||
        !request.involvesHouse(normalizedCurrentHouseId)) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (request.deleteAt <= 0 || now < request.deleteAt) {
      return;
    }

    await _deleteSpaceFromDeleteRequest(
      request,
      actorHouseId: normalizedCurrentHouseId,
      reason: 'expired_15_days',
    );
  }

  static Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _sanitizeSnapshot(Map<String, dynamic> snapshot) {
    const blockedKeys = <String>{
      'avatarUrl1',
      'avatarUrl2',
      'customBackgroundUrl',
      'leftAvatarUrl',
      'rightAvatarUrl',
      'backgroundUrl',
      'bg_url',
      'custom_background_url',
    };
    final safe = <String, dynamic>{};
    snapshot.forEach((key, value) {
      if (value == null) {
        return;
      }
      final normalizedKey = key.toString().trim();
      if (blockedKeys.contains(normalizedKey)) {
        return;
      }
      if (value is String || value is num || value is bool) {
        safe[normalizedKey] = value;
        return;
      }
      if (value is Map) {
        safe[normalizedKey] = Map<String, dynamic>.from(value);
      }
    });
    return safe;
  }

  Future<String> _resolveHouseLabel(String houseId) async {
    final normalizedHouseId = houseId.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) {
      return 'Người ấy';
    }

    try {
      final snap = await _db.ref('houses/$normalizedHouseId/settings').get();
      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final houseName = (data['houseName'] ?? '').toString().trim();
        if (houseName.isNotEmpty) {
          return houseName;
        }
        final nameU1 = (data['nameU1'] ?? '').toString().trim();
        if (nameU1.isNotEmpty) {
          return nameU1;
        }
      }
    } catch (_) {}

    return normalizedHouseId;
  }

  List<String> _sortedPair(String houseIdA, String houseIdB) {
    final pair = [houseIdA.trim().toUpperCase(), houseIdB.trim().toUpperCase()]
      ..sort();
    return pair;
  }

  Set<String> _collectOccupiedHouseIds({
    required String houseId,
    required List<CountdownSpaceInfo> spaces,
    required List<CountdownSpaceRequestInfo> requests,
  }) {
    final normalizedHouseId = houseId.trim().toUpperCase();
    final occupied = <String>{};
    if (normalizedHouseId.isNotEmpty) {
      occupied.add(normalizedHouseId);
    }
    for (final space in spaces) {
      if (space.status != 'active') {
        continue;
      }
      final otherHouseId = space.otherHouseIdFor(normalizedHouseId);
      if (otherHouseId.isNotEmpty) {
        occupied.add(otherHouseId);
      }
    }
    for (final request in requests) {
      if (request.status != 'pending') {
        continue;
      }
      final otherHouseId = request.otherHouseIdFor(normalizedHouseId);
      if (otherHouseId.isNotEmpty) {
        occupied.add(otherHouseId);
      }
    }
    return occupied;
  }

  Stream<List<CountdownSpaceRequestInfo>> _watchRequestsByHouseField(
    String field,
    String houseId,
  ) {
    return _db
        .ref('countdown_space_requests')
        .orderByChild(field)
        .equalTo(houseId)
        .onValue
        .map(_requestItemsFromEvent);
  }

  Stream<List<CountdownSpaceInfo>> _watchSpacesByHouseField(
    String field,
    String houseId,
  ) {
    return _db
        .ref('countdown_spaces')
        .orderByChild(field)
        .equalTo(houseId)
        .onValue
        .map(_spaceItemsFromEvent);
  }

  Stream<List<CountdownSpaceDeleteRequestInfo>>
      _watchDeleteRequestsByHouseField(
    String field,
    String houseId,
  ) {
    return _db
        .ref('countdown_space_delete_requests')
        .orderByChild(field)
        .equalTo(houseId)
        .onValue
        .map(_deleteRequestItemsFromEvent);
  }

  Future<List<CountdownSpaceRequestInfo>> _loadRequestsForHouse(
    String houseId,
  ) async {
    final results = await Future.wait<List<CountdownSpaceRequestInfo>>([
      _db
          .ref('countdown_space_requests')
          .orderByChild('fromHouseId')
          .equalTo(houseId)
          .get()
          .then(_requestItemsFromSnapshot),
      _db
          .ref('countdown_space_requests')
          .orderByChild('toHouseId')
          .equalTo(houseId)
          .get()
          .then(_requestItemsFromSnapshot),
    ]);
    return _mergeRequestLists(results[0], results[1]);
  }

  Future<List<CountdownSpaceInfo>> _loadSpacesForHouse(String houseId) async {
    final results = await Future.wait<List<CountdownSpaceInfo>>([
      _db
          .ref('countdown_spaces')
          .orderByChild('houseA')
          .equalTo(houseId)
          .get()
          .then(_spaceItemsFromSnapshot),
      _db
          .ref('countdown_spaces')
          .orderByChild('houseB')
          .equalTo(houseId)
          .get()
          .then(_spaceItemsFromSnapshot),
    ]);
    return _mergeSpaceLists(results[0], results[1]);
  }

  Future<CountdownSpaceInfo?> _getSpaceById(String spaceId) async {
    final snap = await _db.ref('countdown_spaces/$spaceId').get();
    if (!snap.exists || snap.value is! Map) {
      return null;
    }
    return CountdownSpaceInfo.fromMap(
      spaceId,
      Map<String, dynamic>.from(snap.value as Map),
    );
  }

  Future<CountdownSpaceDeleteRequestInfo?> _getDeleteRequestBySpaceId(
    String spaceId,
  ) async {
    final snap =
        await _db.ref('countdown_space_delete_requests/$spaceId').get();
    if (!snap.exists || snap.value is! Map) {
      return null;
    }
    return CountdownSpaceDeleteRequestInfo.fromMap(
      spaceId,
      Map<String, dynamic>.from(snap.value as Map),
    );
  }

  Stream<List<CountdownSpaceRequestInfo>> _mergeRequestStreams(
    Stream<List<CountdownSpaceRequestInfo>> first,
    Stream<List<CountdownSpaceRequestInfo>> second,
  ) {
    late StreamController<List<CountdownSpaceRequestInfo>> controller;
    StreamSubscription<List<CountdownSpaceRequestInfo>>? firstSub;
    StreamSubscription<List<CountdownSpaceRequestInfo>>? secondSub;
    var firstItems = const <CountdownSpaceRequestInfo>[];
    var secondItems = const <CountdownSpaceRequestInfo>[];

    void emitMerged() {
      if (controller.isClosed) {
        return;
      }
      controller.add(_mergeRequestLists(firstItems, secondItems));
    }

    controller = StreamController<List<CountdownSpaceRequestInfo>>(
      onListen: () {
        firstSub = first.listen(
          (items) {
            firstItems = items;
            emitMerged();
          },
          onError: controller.addError,
        );
        secondSub = second.listen(
          (items) {
            secondItems = items;
            emitMerged();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await firstSub?.cancel();
        await secondSub?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<List<CountdownSpaceInfo>> _mergeSpaceStreams(
    Stream<List<CountdownSpaceInfo>> first,
    Stream<List<CountdownSpaceInfo>> second,
  ) {
    late StreamController<List<CountdownSpaceInfo>> controller;
    StreamSubscription<List<CountdownSpaceInfo>>? firstSub;
    StreamSubscription<List<CountdownSpaceInfo>>? secondSub;
    var firstItems = const <CountdownSpaceInfo>[];
    var secondItems = const <CountdownSpaceInfo>[];

    void emitMerged() {
      if (controller.isClosed) {
        return;
      }
      controller.add(_mergeSpaceLists(firstItems, secondItems));
    }

    controller = StreamController<List<CountdownSpaceInfo>>(
      onListen: () {
        firstSub = first.listen(
          (items) {
            firstItems = items;
            emitMerged();
          },
          onError: controller.addError,
        );
        secondSub = second.listen(
          (items) {
            secondItems = items;
            emitMerged();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await firstSub?.cancel();
        await secondSub?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<List<CountdownSpaceDeleteRequestInfo>> _mergeDeleteRequestStreams(
    Stream<List<CountdownSpaceDeleteRequestInfo>> first,
    Stream<List<CountdownSpaceDeleteRequestInfo>> second,
  ) {
    late StreamController<List<CountdownSpaceDeleteRequestInfo>> controller;
    StreamSubscription<List<CountdownSpaceDeleteRequestInfo>>? firstSub;
    StreamSubscription<List<CountdownSpaceDeleteRequestInfo>>? secondSub;
    var firstItems = const <CountdownSpaceDeleteRequestInfo>[];
    var secondItems = const <CountdownSpaceDeleteRequestInfo>[];

    void emitMerged() {
      if (controller.isClosed) {
        return;
      }
      controller.add(_mergeDeleteRequestLists(firstItems, secondItems));
    }

    controller = StreamController<List<CountdownSpaceDeleteRequestInfo>>(
      onListen: () {
        firstSub = first.listen(
          (items) {
            firstItems = items;
            emitMerged();
          },
          onError: controller.addError,
        );
        secondSub = second.listen(
          (items) {
            secondItems = items;
            emitMerged();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await firstSub?.cancel();
        await secondSub?.cancel();
      },
    );
    return controller.stream;
  }

  List<CountdownSpaceRequestInfo> _requestItemsFromEvent(
    DatabaseEvent event,
  ) {
    return _requestItemsFromSnapshot(event.snapshot);
  }

  List<CountdownSpaceRequestInfo> _requestItemsFromSnapshot(
    DataSnapshot snapshot,
  ) {
    if (!snapshot.exists || snapshot.value is! Map) {
      return const <CountdownSpaceRequestInfo>[];
    }
    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final items = <CountdownSpaceRequestInfo>[];
    raw.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      items.add(
        CountdownSpaceRequestInfo.fromMap(
          key.toString(),
          Map<String, dynamic>.from(value),
        ),
      );
    });
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<CountdownSpaceInfo> _spaceItemsFromEvent(DatabaseEvent event) {
    return _spaceItemsFromSnapshot(event.snapshot);
  }

  List<CountdownSpaceDeleteRequestInfo> _deleteRequestItemsFromEvent(
    DatabaseEvent event,
  ) {
    return _deleteRequestItemsFromSnapshot(event.snapshot);
  }

  List<CountdownSpaceInfo> _spaceItemsFromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value is! Map) {
      return const <CountdownSpaceInfo>[];
    }
    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final items = <CountdownSpaceInfo>[];
    raw.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      items.add(
        CountdownSpaceInfo.fromMap(
          key.toString(),
          Map<String, dynamic>.from(value),
        ),
      );
    });
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<CountdownSpaceDeleteRequestInfo> _deleteRequestItemsFromSnapshot(
    DataSnapshot snapshot,
  ) {
    if (!snapshot.exists || snapshot.value is! Map) {
      return const <CountdownSpaceDeleteRequestInfo>[];
    }
    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final items = <CountdownSpaceDeleteRequestInfo>[];
    raw.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      items.add(
        CountdownSpaceDeleteRequestInfo.fromMap(
          key.toString(),
          Map<String, dynamic>.from(value),
        ),
      );
    });
    items.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return items;
  }

  List<CountdownSpaceRequestInfo> _mergeRequestLists(
    List<CountdownSpaceRequestInfo> first,
    List<CountdownSpaceRequestInfo> second,
  ) {
    final merged = <String, CountdownSpaceRequestInfo>{};
    for (final item in [...first, ...second]) {
      merged[item.requestId] = item;
    }
    final items = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<CountdownSpaceInfo> _mergeSpaceLists(
    List<CountdownSpaceInfo> first,
    List<CountdownSpaceInfo> second,
  ) {
    final merged = <String, CountdownSpaceInfo>{};
    for (final item in [...first, ...second]) {
      merged[item.spaceId] = item;
    }
    final items = merged.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<CountdownSpaceDeleteRequestInfo> _mergeDeleteRequestLists(
    List<CountdownSpaceDeleteRequestInfo> first,
    List<CountdownSpaceDeleteRequestInfo> second,
  ) {
    final merged = <String, CountdownSpaceDeleteRequestInfo>{};
    for (final item in [...first, ...second]) {
      merged[item.spaceId] = item;
    }
    final items = merged.values.toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return items;
  }

  Future<void> _deleteSpaceFromDeleteRequest(
    CountdownSpaceDeleteRequestInfo request, {
    required String actorHouseId,
    required String reason,
  }) async {
    final normalizedActorHouseId = actorHouseId.trim().toUpperCase();
    await _db.ref().update(<String, dynamic>{
      'countdown_spaces/${request.spaceId}': null,
      'countdown_space_delete_requests/${request.spaceId}': null,
    });

    final otherHouseId = request.otherHouseIdFor(normalizedActorHouseId);
    if (otherHouseId.isEmpty) {
      return;
    }

    final actorLabel = await _resolveHouseLabel(normalizedActorHouseId);
    final message = reason == 'partner_approved'
        ? '$actorLabel đã xác nhận xóa không gian đếm.'
        : 'Không gian đếm này đã tự xóa sau 15 ngày chờ xác nhận.';
    await PushNotificationHelper.push(
      toHouseId: otherHouseId,
      type: 'countdown_space_deleted',
      from: normalizedActorHouseId,
      fromId: normalizedActorHouseId,
      fromLabel: actorLabel,
      title: 'Không gian đếm đã được xóa',
      msg: message,
      extra: <String, dynamic>{
        'spaceId': request.spaceId,
      },
    );
  }

  String _formatDateTime(int value) {
    if (value <= 0) {
      return 'không xác định';
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(value);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} lúc $hour:$minute';
  }

  String _mapSendRequestFirebaseError(FirebaseException error) {
    final code = error.code.toLowerCase();
    final raw = (error.message ?? '').toLowerCase();

    if (code == 'permission-denied' ||
        raw.contains('permission-denied') ||
        raw.contains('permission_denied')) {
      return 'Không thể thêm không gian lúc này. Mã nhà này có thể đã chặn bạn, dữ liệu công khai chưa sẵn sàng, hoặc bạn không còn trong nhà hiện tại.';
    }
    if (code == 'network-request-failed' ||
        code == 'unavailable' ||
        raw.contains('network') ||
        raw.contains('timeout')) {
      return 'Kết nối mạng đang không ổn định. Hãy kiểm tra mạng rồi thử lại.';
    }
    return 'Không thể thêm không gian lúc này. Thử lại sau.';
  }

  String _mapSendRequestFallbackError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') ||
        raw.contains('permission_denied')) {
      return 'Không thể thêm không gian lúc này. Mã nhà này có thể đã chặn bạn, dữ liệu công khai chưa sẵn sàng, hoặc bạn không còn trong nhà hiện tại.';
    }
    if (raw.contains('network') || raw.contains('timeout')) {
      return 'Kết nối mạng đang không ổn định. Hãy kiểm tra mạng rồi thử lại.';
    }
    return 'Không thể thêm không gian lúc này. Thử lại sau.';
  }
}
