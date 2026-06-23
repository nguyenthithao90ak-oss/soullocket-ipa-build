import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

class LoveWheelService {
  static final LoveWheelService _instance = LoveWheelService._internal();

  factory LoveWheelService() => _instance;

  LoveWheelService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<int> spinTheWheel(String houseId, List<String> options) async {
    final normalizedHouseId = houseId.trim();
    final normalizedOptions = options
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalizedHouseId.isEmpty || normalizedOptions.isEmpty) {
      return 0;
    }

    final selectedIndex = Random.secure().nextInt(normalizedOptions.length);
    final payload = <String, dynamic>{
      'selectedIndex': selectedIndex,
      'resultText': normalizedOptions[selectedIndex],
      'options': normalizedOptions,
      'spinnedAt': ServerValue.timestamp,
    };

    final historyRef = _db.ref('houses/$normalizedHouseId/wheel_history').push();
    final historyKey = historyRef.key;
    if (historyKey == null || historyKey.isEmpty) {
      await _db.ref('houses/$normalizedHouseId/wheel_result').set(payload);
      return selectedIndex;
    }

    await _db.ref().update({
      'houses/$normalizedHouseId/wheel_result': payload,
      'houses/$normalizedHouseId/wheel_history/$historyKey': payload,
    });
    await _trimHistory(normalizedHouseId);

    return selectedIndex;
  }

  Stream<Map<dynamic, dynamic>?> listenToWheelResult(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<Map<dynamic, dynamic>?>.value(null);
    }
    return _db.ref('houses/$normalizedHouseId/wheel_result').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return null;
      }
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Stream<List<Map<String, dynamic>>> listenToWheelHistory(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }
    return _db
        .ref('houses/$normalizedHouseId/wheel_history')
        .orderByChild('spinnedAt')
        .limitToLast(5)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return const <Map<String, dynamic>>[];
      }

      final rawMap = Map<Object?, Object?>.from(event.snapshot.value as Map);
      final history = rawMap.entries
          .map((entry) {
            final rawValue = entry.value;
            if (rawValue is! Map) {
              return null;
            }
            final item = Map<String, dynamic>.from(rawValue);
            item['id'] = entry.key.toString();
            return item;
          })
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort(
          (a, b) => _asTimestamp(b['spinnedAt']).compareTo(
            _asTimestamp(a['spinnedAt']),
          ),
        );

      return history;
    });
  }

  Future<void> _trimHistory(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final snapshot = await _db
        .ref('houses/$normalizedHouseId/wheel_history')
        .orderByChild('spinnedAt')
        .get();
    if (!snapshot.exists || snapshot.value is! Map) {
      return;
    }

    final rawMap = Map<Object?, Object?>.from(snapshot.value as Map);
    final entries = rawMap.entries.map((entry) {
      final rawValue = entry.value;
      if (rawValue is! Map) {
        return MapEntry(entry.key.toString(), 0);
      }
      final item = Map<Object?, Object?>.from(rawValue);
      return MapEntry(entry.key.toString(), _asTimestamp(item['spinnedAt']));
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.length <= 5) {
      return;
    }

    final updates = <String, Object?>{};
    for (final entry in entries.skip(5)) {
      updates['houses/$normalizedHouseId/wheel_history/${entry.key}'] = null;
    }
    await _db.ref().update(updates);
  }

  static int _asTimestamp(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
