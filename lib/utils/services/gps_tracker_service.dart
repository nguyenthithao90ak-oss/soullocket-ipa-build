import 'dart:async';
import 'dart:math' show asin, cos, sqrt;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../app_error_mapper.dart';

typedef GeofenceCallback = void Function(
  String zoneName,
  double distanceMeters,
);

class GpsTrackerService {
  static const int _kGpsHistoryRetentionDays = 14;
  static const int _kGpsHistoryMaxPointsPerDay = 600;
  static const Duration _kGpsHistoryCleanupInterval = Duration(hours: 6);

  static final GpsTrackerService _instance = GpsTrackerService._internal();
  factory GpsTrackerService() => _instance;
  GpsTrackerService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  GeofenceCallback? onGeofenceAlert;

  static const double nearbyThresholdMeters = 50.0;

  StreamSubscription<DatabaseEvent>? _partnerLocationSubscription;
  String? _monitoredHouseId;
  String? _partnerUid;
  Map<String, dynamic>? _partnerLocation;
  final Map<String, int> _historyCleanupTsByScope = <String, int>{};

  Future<void> updateMyLocation(String houseId, double lat, double lng) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final role = await _resolveMyRole(houseId, uid);
    if (role == null || role.isEmpty) return;

    final now = DateTime.now();
    final locationData = {
      'lat': lat,
      'lng': lng,
      'ts': ServerValue.timestamp,
    };

    await _db.ref('gps/$houseId/$role').set(locationData);

    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _db.ref('gps_history/$houseId/$role/$dateKey').push().set({
      'lat': lat,
      'lng': lng,
      'ts': now.millisecondsSinceEpoch,
    });

    unawaited(
      _maybeTrimGpsHistory(
        houseId: houseId,
        role: role,
        dateKey: dateKey,
      ),
    );

    await _ensurePartnerMonitor(houseId, myUid: uid);
    _checkNearbyPartner(lat, lng);
  }

  Stream<Map<String, dynamic>?> listenLoverLocation(
    String houseId,
    String loverRole,
  ) {
    return _db.ref('gps/$houseId/$loverRole').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Future<List<Map<String, dynamic>>> getHistoryForDate(
    String houseId,
    String role,
    String dateKey,
  ) async {
    final snap = await _db
        .ref('gps_history/$houseId/$role/$dateKey')
        .orderByChild('ts')
        .limitToLast(_kGpsHistoryMaxPointsPerDay)
        .get();
    if (!snap.exists) return [];

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = data.entries.map((e) {
      return Map<String, dynamic>.from(e.value as Map);
    }).toList();
    list.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
    return list;
  }

  Future<void> startPartnerGeofenceMonitoring(String houseId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    await _ensurePartnerMonitor(houseId, myUid: myUid, forceRefresh: true);
  }

  Future<void> startListeningPartner(String houseId, String myUid) async {
    await _ensurePartnerMonitor(houseId, myUid: myUid, forceRefresh: true);
  }

  Future<void> stopListeningPartner() async {
    await stopPartnerGeofenceMonitoring();
  }

  Future<void> stopPartnerGeofenceMonitoring() async {
    await _partnerLocationSubscription?.cancel();
    _partnerLocationSubscription = null;
    _monitoredHouseId = null;
    _partnerUid = null;
    _partnerLocation = null;
  }

  Future<void> _ensurePartnerMonitor(
    String houseId, {
    required String myUid,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _monitoredHouseId == houseId &&
        _partnerUid != null &&
        _partnerLocationSubscription != null) {
      return;
    }

    final myRole = await _resolveMyRole(houseId, myUid);
    final partnerRole = _partnerRoleOf(myRole);
    if (partnerRole == null || partnerRole.isEmpty) {
      await stopPartnerGeofenceMonitoring();
      return;
    }

    if (!forceRefresh &&
        _monitoredHouseId == houseId &&
        _partnerUid == partnerRole &&
        _partnerLocationSubscription != null) {
      return;
    }

    await _partnerLocationSubscription?.cancel();
    _monitoredHouseId = houseId;
    _partnerUid = partnerRole;
    _partnerLocation = null;

    _partnerLocationSubscription =
        _db.ref('gps/$houseId/$partnerRole').onValue.listen(
      (event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          _partnerLocation = null;
          return;
        }
        _partnerLocation =
            Map<String, dynamic>.from(event.snapshot.value as Map);
      },
      onError: (Object error) {
        debugPrint('[GPS] Partner monitor error: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể theo dõi vị trí đối phương.',
        ).message}');
      },
    );
  }

  Future<String?> _resolveMyRole(String houseId, String myUid) async {
    try {
      final ownerSnap = await _db.ref('houses/$houseId/owner_uid').get();
      final ownerUid = ownerSnap.value?.toString().trim() ?? '';
      if (ownerUid.isNotEmpty && ownerUid == myUid) {
        return 'user1';
      }

      final snap = await _db.ref('houses/$houseId/members').get();
      if (!snap.exists || snap.value == null) return null;

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      for (final entry in data.entries) {
        final uid = entry.key.toString().trim();
        if (uid != myUid) {
          continue;
        }
        final item = _toStringDynamicMap(entry.value);
        final role = item['role']?.toString().trim() ?? '';
        if (role == 'user1' || role == 'user2') return role;
      }
    } catch (e) {
      debugPrint('[GPS] Resolve role error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xác định vai trò GPS.',
      ).message}');
    }
    return null;
  }

  String? _partnerRoleOf(String? myRole) {
    final normalized = myRole?.trim();
    if (normalized == 'user1') return 'user2';
    if (normalized == 'user2') return 'user1';
    return null;
  }

  void _checkNearbyPartner(double myLat, double myLng) {
    try {
      final locData = _partnerLocation;
      if (locData == null) return;

      final partnerLat = (locData['lat'] as num?)?.toDouble();
      final partnerLng = (locData['lng'] as num?)?.toDouble();
      if (partnerLat == null || partnerLng == null) return;

      final distance = _calculateDistance(myLat, myLng, partnerLat, partnerLng);

      if (distance <= nearbyThresholdMeters) {
        onGeofenceAlert?.call('nearby_partner', distance);
      }
    } catch (e) {
      debugPrint('[GPS] Geofence check error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra vùng GPS.',
      ).message}');
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  double calculateDistanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return _calculateDistance(lat1, lon1, lat2, lon2);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  Future<void> _maybeTrimGpsHistory({
    required String houseId,
    required String role,
    required String dateKey,
  }) async {
    final scopeKey = '$houseId|$role';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastCleanup = _historyCleanupTsByScope[scopeKey] ?? 0;
    if (nowMs - lastCleanup < _kGpsHistoryCleanupInterval.inMilliseconds) {
      return;
    }
    _historyCleanupTsByScope[scopeKey] = nowMs;

    try {
      await _trimExpiredHistoryDays(houseId: houseId, role: role);
      await _trimOverflowHistoryPoints(
        houseId: houseId,
        role: role,
        dateKey: dateKey,
      );
    } catch (e) {
      debugPrint('[GPS] History cleanup error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể dọn lịch sử GPS.',
      ).message}');
    }
  }

  Future<void> _trimExpiredHistoryDays({
    required String houseId,
    required String role,
  }) async {
    final historyRoot = _db.ref('gps_history/$houseId/$role');
    final oldestKeptDay = DateTime.now()
        .subtract(const Duration(days: _kGpsHistoryRetentionDays - 1));
    final deleteThroughKey =
        _formatDateKey(oldestKeptDay.subtract(const Duration(days: 1)));
    final snap = await historyRoot.orderByKey().endAt(deleteThroughKey).get();
    final raw = _toStringDynamicMap(snap.value);
    if (raw.isEmpty) {
      return;
    }

    final updates = <String, dynamic>{
      for (final key in raw.keys) 'gps_history/$houseId/$role/$key': null,
    };
    await _db.ref().update(updates);
  }

  Future<void> _trimOverflowHistoryPoints({
    required String houseId,
    required String role,
    required String dateKey,
  }) async {
    final dayPath = 'gps_history/$houseId/$role/$dateKey';
    final snap = await _db.ref(dayPath).get();
    final raw = _toStringDynamicMap(snap.value);
    if (raw.length <= _kGpsHistoryMaxPointsPerDay) {
      return;
    }

    final rankedEntries = raw.entries
        .map(
          (entry) => MapEntry(
            entry.key,
            _readTimestamp(_toStringDynamicMap(entry.value)['ts']),
          ),
        )
        .where((entry) => entry.value != null)
        .cast<MapEntry<String, int>>()
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (rankedEntries.length <= _kGpsHistoryMaxPointsPerDay) {
      return;
    }

    final overflowCount = rankedEntries.length - _kGpsHistoryMaxPointsPerDay;
    final updates = <String, dynamic>{
      for (final entry in rankedEntries.take(overflowCount))
        '$dayPath/${entry.key}': null,
    };
    await _db.ref().update(updates);
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  int? _readTimestamp(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      if (raw.isNaN || raw.isInfinite) {
        return null;
      }
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  String _formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }
}
