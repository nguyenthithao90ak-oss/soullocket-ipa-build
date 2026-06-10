import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';

class _MapPinReadResult {
  final dynamic value;

  const _MapPinReadResult({
    required this.value,
  });
}

class MapPinLimitSnapshot {
  final Set<String> occupiedLocationKeys;
  final int maxPins;

  const MapPinLimitSnapshot({
    required this.occupiedLocationKeys,
    this.maxPins = MapPinLimitService.maxPins,
  });

  int get totalPins => occupiedLocationKeys.length;
  int get remainingSlots => math.max(0, maxPins - totalPins);
  bool get isFull => remainingSlots <= 0;

  bool containsLocation(double lat, double lng) {
    return occupiedLocationKeys.contains(
      MapPinLimitService.locationKeyFromCoordinates(lat, lng),
    );
  }
}

class MapPinLimitService {
  static const int maxPins = 30;

  final DatabaseReference _dbRef;

  MapPinLimitService({DatabaseReference? dbRef})
      : _dbRef = dbRef ?? FirebaseDatabase.instance.ref();

  Future<MapPinLimitSnapshot> getSnapshot(String houseId) async {
    final results = await Future.wait<_MapPinReadResult>([
      _safeGet('houses/$houseId/memories'),
      _safeGet('checkins/$houseId'),
    ]);

    final occupiedLocationKeys = <String>{};
    _collectLocationKeys(results[0].value, occupiedLocationKeys);
    _collectLocationKeys(results[1].value, occupiedLocationKeys);

    return MapPinLimitSnapshot(occupiedLocationKeys: occupiedLocationKeys);
  }

  Future<_MapPinReadResult> _safeGet(String path) async {
    try {
      final snapshot = await _dbRef.child(path).get();
      return _MapPinReadResult(value: snapshot.value);
    } on FirebaseException catch (error) {
      if (_isPermissionDenied(error)) {
        return const _MapPinReadResult(value: null);
      }
      rethrow;
    }
  }

  bool _isPermissionDenied(FirebaseException error) {
    final code = error.code.trim().toLowerCase();
    final message = error.message?.trim().toLowerCase() ?? '';
    return code == 'permission-denied' ||
        code == 'permission_denied' ||
        message.contains('permission denied');
  }

  static String locationKeyFromCoordinates(double lat, double lng) {
    return '${lat.toStringAsFixed(5)}|${lng.toStringAsFixed(5)}';
  }

  void _collectLocationKeys(dynamic raw, Set<String> sink) {
    final map = _toStringDynamicMap(raw);
    for (final entry in map.entries) {
      final item = _toStringDynamicMap(entry.value);
      final lat = _readDouble(item['lat'] ?? item['lt']);
      final lng = _readDouble(item['lng'] ?? item['lg']);
      if (lat == null || lng == null || !_isValidCoordinate(lat, lng)) {
        continue;
      }
      sink.add(locationKeyFromCoordinates(lat, lng));
    }
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  double? _readDouble(dynamic value) {
    double? result;
    if (value is num) {
      result = value.toDouble();
    } else {
      result = double.tryParse(value?.toString() ?? '');
    }
    if (result != null && (result.isNaN || result.isInfinite)) {
      return null;
    }
    return result;
  }

  bool _isValidCoordinate(double lat, double lng) {
    if (lat.isNaN || lat.isInfinite || lng.isNaN || lng.isInfinite) {
      return false;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return false;
    }
    if (lat.abs() < 0.000001 && lng.abs() < 0.000001) {
      return false;
    }
    return true;
  }
}
