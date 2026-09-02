import 'dart:async';

import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';

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
  final String houseA;
  final String houseB;
  final String status;
  final Map<String, dynamic> snapshot;
  final int updatedAt;

  const CountdownSpace({
    required this.spaceId,
    required this.houseA,
    required this.houseB,
    required this.status,
    required this.snapshot,
    required this.updatedAt,
  });

  String otherHouseIdFor(String myHouseId) {
    final normalized = myHouseId.trim();
    if (houseA == normalized) return houseB;
    if (houseB == normalized) return houseA;
    return '';
  }

  bool containsHouse(String houseId) {
    final normalized = houseId.trim();
    return normalized.isNotEmpty &&
        (houseA == normalized || houseB == normalized);
  }

  factory CountdownSpace.fromMap(String spaceId, Map<String, dynamic> map) {
    return CountdownSpace(
      spaceId: spaceId,
      houseA: map['houseA']?.toString() ?? '',
      houseB: map['houseB']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      snapshot: _toMap(map['snapshot']),
      updatedAt: _toInt(map['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'spaceId': spaceId,
    'houseA': houseA,
    'houseB': houseB,
    'status': status,
    'snapshot': snapshot,
    'updatedAt': updatedAt,
  };
}

class CountdownSpaceDeleteRequestInfo {
  final String spaceId;
  final String houseA;
  final String houseB;
  final String requestedBy;
  final int requestedAt;
  final int deleteAt;
  final String status;

  const CountdownSpaceDeleteRequestInfo({
    required this.spaceId,
    required this.houseA,
    required this.houseB,
    required this.requestedBy,
    required this.requestedAt,
    required this.deleteAt,
    required this.status,
  });

  bool get isPending => status == 'pending';
  bool isRequestedBy(String houseId) => requestedBy == houseId;

  String otherHouseIdFor(String myHouseId) {
    final normalized = myHouseId.trim();
    if (houseA == normalized) return houseB;
    if (houseB == normalized) return houseA;
    return '';
  }

  factory CountdownSpaceDeleteRequestInfo.fromMap(
    String spaceId,
    Map<String, dynamic> map,
  ) {
    return CountdownSpaceDeleteRequestInfo(
      spaceId: spaceId,
      houseA: map['houseA']?.toString() ?? '',
      houseB: map['houseB']?.toString() ?? '',
      requestedBy:
          map['requestedByHouseId']?.toString() ??
          map['requestedBy']?.toString() ??
          '',
      requestedAt: _toInt(map['requestedAt']),
      deleteAt: _toInt(map['deleteAt']),
      status: map['status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'spaceId': spaceId,
    'houseA': houseA,
    'houseB': houseB,
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
      final targetPublicSnap = await _db
          .ref('houses_public/$normalizedToHouseId')
          .get();
      if (!targetPublicSnap.exists) {
        return CountdownSpaceRequestResult(
          success: false,
          message:
              'Không tìm thấy mã nhà "$normalizedToHouseId". Hãy kiểm tra lại.',
        );
      }

      final existingSpaces = await _loadSpacesForHouse(normalizedFromHouseId);
      final relatedRequests = await _loadRequestsForHouse(
        normalizedFromHouseId,
      );
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
        if (existing.otherHouseIdFor(normalizedFromHouseId) !=
            normalizedToHouseId) {
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
        if (request.otherHouseIdFor(normalizedFromHouseId) !=
            normalizedToHouseId) {
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

      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'requestCountdownSpaceSecure',
        payload: <String, dynamic>{
          'fromHouseName': normalizedFromHouseName,
          'toHouseId': normalizedToHouseId,
          'snapshot': _sanitizeSnapshot(initialSnapshot),
        },
      );
      final responseData = _toMap(response.data);
      final requestId = responseData['requestId']?.toString().trim() ?? '';
      final spaceId = responseData['spaceId']?.toString().trim() ?? '';
      if (responseData['success'] != true ||
          requestId.isEmpty ||
          spaceId.isEmpty) {
        return const CountdownSpaceRequestResult(
          success: false,
          message: 'Không thể tạo yêu cầu ghép nối lúc này.',
        );
      }
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

      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'respondCountdownSpaceRequestSecure',
        payload: <String, dynamic>{
          'requestId': finalRequest.requestId,
          'action': 'accept',
        },
      );
      final responseData = _toMap(response.data);
      if (responseData['success'] != true) {
        return CountdownSpaceRequestResult(
          success: false,
          message: responseData['message']?.toString().trim().isNotEmpty == true
              ? responseData['message'].toString().trim()
              : 'Không thể chấp nhận yêu cầu ghép nối.',
        );
      }
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
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'respondCountdownSpaceRequestSecure',
        payload: <String, dynamic>{
          'requestId': normalizedRequestId,
          'action': 'reject',
        },
      );
      final responseData = _toMap(response.data);
      if (responseData['success'] != true) {
        return CountdownSpaceRequestResult(
          success: false,
          message: responseData['message']?.toString().trim().isNotEmpty == true
              ? responseData['message'].toString().trim()
              : 'Không thể từ chối yêu cầu ghép nối.',
        );
      }
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
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'cancelCountdownSpaceRequestSecure',
        payload: <String, dynamic>{'requestId': normalizedRequestId},
      );
      final responseData = _toMap(response.data);
      if (responseData['success'] != true) {
        return CountdownSpaceRequestResult(
          success: false,
          message: responseData['message']?.toString().trim().isNotEmpty == true
              ? responseData['message'].toString().trim()
              : 'Không thể hủy yêu cầu ghép nối.',
        );
      }
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
    await CloudFunctionsHelper.callSecure<dynamic>(
      'updateCountdownSpaceSecure',
      payload: <String, dynamic>{
        'spaceId': normalizedSpaceId,
        'snapshot': _sanitizeSnapshot(snapshot),
      },
    );
  }

  Future<void> requestDeleteSpace(String spaceId) async {
    final normalizedSpaceId = spaceId.trim();
    if (normalizedSpaceId.isEmpty) return;
    await CloudFunctionsHelper.callSecure<dynamic>(
      'requestCountdownSpaceDeleteSecure',
      payload: <String, dynamic>{'spaceId': normalizedSpaceId},
    );
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
          final list = raw
              .map(
                (e) => CountdownSpace.fromMap(
                  e['spaceId']?.toString() ?? '',
                  e as Map<String, dynamic>,
                ),
              )
              .where((space) => space.containsHouse(hId))
              .toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          yield list;
        }
      } catch (_) {}
    }

    yield* _watchPairedRecords(
      rootPath: 'countdown_spaces',
      firstField: 'houseA',
      secondField: 'houseB',
      houseId: hId,
    ).asyncMap((raw) async {
      final list = <CountdownSpace>[];
      raw.forEach((key, value) {
        final data = _toMap(value);
        final space = CountdownSpace.fromMap(key, data);
        if (space.status == 'active' && space.containsHouse(hId)) {
          list.add(space);
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
  }) => requestConnection(
    fromHouseId: fromHouseId,
    fromHouseName: fromHouseName,
    toHouseId: toHouseId,
    initialSnapshot: initialSnapshot,
  );

  Future<CountdownSpaceRequestResult> declineRequest({
    required String requestId,
    required String currentHouseId,
  }) => rejectRequest(requestId);

  Future<void> updatePendingRequestSnapshot({
    required String requestId,
    required String fromHouseId,
    required Map<String, dynamic> snapshot,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return;
    await CloudFunctionsHelper.callSecure<dynamic>(
      'updateCountdownSpaceRequestSecure',
      payload: <String, dynamic>{
        'requestId': normalizedRequestId,
        'snapshot': _sanitizeSnapshot(snapshot),
      },
    );
  }

  Future<void> updateSpaceSnapshot({
    required String spaceId,
    required Map<String, dynamic> snapshot,
  }) async {
    await updateSnapshot(spaceId: spaceId, snapshot: snapshot);
  }

  Future<CountdownSpaceRequestResult> requestDelete({
    required String spaceId,
    required String currentHouseId,
    required String currentHouseName,
  }) async {
    try {
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'requestCountdownSpaceDeleteSecure',
        payload: <String, dynamic>{'spaceId': spaceId},
      );
      final responseData = _toMap(response.data);
      if (responseData['success'] != true) {
        return CountdownSpaceRequestResult(
          success: false,
          message: responseData['message']?.toString().trim().isNotEmpty == true
              ? responseData['message'].toString().trim()
              : 'Không thể gửi yêu cầu xóa không gian.',
        );
      }
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
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'respondCountdownSpaceDeleteSecure',
        payload: <String, dynamic>{'spaceId': spaceId},
      );
      final responseData = _toMap(response.data);
      if (responseData['success'] != true) {
        return CountdownSpaceRequestResult(
          success: false,
          message: responseData['message']?.toString().trim().isNotEmpty == true
              ? responseData['message'].toString().trim()
              : 'Không thể xác nhận xóa không gian.',
        );
      }
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
    final snap = await _db
        .ref('countdown_space_delete_requests/$spaceId')
        .get();
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
    return _watchPairedRecords(
      rootPath: 'countdown_space_requests',
      firstField: 'fromHouseId',
      secondField: 'toHouseId',
      houseId: hId,
    ).map((raw) {
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
    String houseId,
  ) {
    final hId = houseId.trim();
    return _watchPairedRecords(
      rootPath: 'countdown_space_delete_requests',
      firstField: 'houseA',
      secondField: 'houseB',
      houseId: hId,
    ).map((raw) {
      final list = <CountdownSpaceDeleteRequestInfo>[];
      raw.forEach((key, value) {
        final request = CountdownSpaceDeleteRequestInfo.fromMap(
          key,
          _toMap(value),
        );
        if (request.status == 'pending' &&
            request.otherHouseIdFor(hId).isNotEmpty) {
          list.add(request);
        }
      });
      return list;
    });
  }

  Future<List<CountdownSpace>> _loadSpacesForHouse(String houseId) async {
    final hId = houseId.trim();
    final raw = await _loadPairedRecords(
      rootPath: 'countdown_spaces',
      firstField: 'houseA',
      secondField: 'houseB',
      houseId: hId,
    );
    final list = <CountdownSpace>[];
    raw.forEach((key, value) {
      final space = CountdownSpace.fromMap(key, _toMap(value));
      if (space.containsHouse(hId)) list.add(space);
    });
    return list;
  }

  Future<List<CountdownSpaceRequest>> _loadRequestsForHouse(
    String houseId,
  ) async {
    final hId = houseId.trim();
    final raw = await _loadPairedRecords(
      rootPath: 'countdown_space_requests',
      firstField: 'fromHouseId',
      secondField: 'toHouseId',
      houseId: hId,
    );
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
        final otherHouseId = s.otherHouseIdFor(hId);
        if (otherHouseId.isNotEmpty) result.add(otherHouseId);
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

  Future<Map<String, dynamic>> _loadPairedRecords({
    required String rootPath,
    required String firstField,
    required String secondField,
    required String houseId,
  }) async {
    final hId = houseId.trim();
    if (hId.isEmpty) return {};
    final snapshots = await Future.wait([
      _db.ref(rootPath).orderByChild(firstField).equalTo(hId).get(),
      _db.ref(rootPath).orderByChild(secondField).equalTo(hId).get(),
    ]);
    return <String, dynamic>{
      ..._toMap(snapshots[0].value),
      ..._toMap(snapshots[1].value),
    };
  }

  Stream<Map<String, dynamic>> _watchPairedRecords({
    required String rootPath,
    required String firstField,
    required String secondField,
    required String houseId,
  }) {
    final hId = houseId.trim();
    late StreamController<Map<String, dynamic>> controller;
    StreamSubscription<DatabaseEvent>? firstSubscription;
    StreamSubscription<DatabaseEvent>? secondSubscription;
    var firstRecords = <String, dynamic>{};
    var secondRecords = <String, dynamic>{};
    var firstReady = false;
    var secondReady = false;

    void emitWhenReady() {
      if (!firstReady || !secondReady || controller.isClosed) return;
      controller.add(<String, dynamic>{...firstRecords, ...secondRecords});
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        if (hId.isEmpty) {
          firstReady = true;
          secondReady = true;
          emitWhenReady();
          return;
        }
        firstSubscription = _db
            .ref(rootPath)
            .orderByChild(firstField)
            .equalTo(hId)
            .onValue
            .listen((event) {
              firstRecords = _toMap(event.snapshot.value);
              firstReady = true;
              emitWhenReady();
            }, onError: controller.addError);
        secondSubscription = _db
            .ref(rootPath)
            .orderByChild(secondField)
            .equalTo(hId)
            .onValue
            .listen((event) {
              secondRecords = _toMap(event.snapshot.value);
              secondReady = true;
              emitWhenReady();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await firstSubscription?.cancel();
        await secondSubscription?.cancel();
      },
    );
    return controller.stream;
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
