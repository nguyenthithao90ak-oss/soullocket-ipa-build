import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

class LoveWheelService {
  static final LoveWheelService _instance = LoveWheelService._internal();

  factory LoveWheelService() => _instance;

  LoveWheelService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<int> spinTheWheel(String houseId, List<String> options) async {
    final normalizedOptions = options
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalizedOptions.isEmpty) {
      return 0;
    }

    final selectedIndex = Random.secure().nextInt(normalizedOptions.length);
    final payload = <String, dynamic>{
      'selectedIndex': selectedIndex,
      'resultText': normalizedOptions[selectedIndex],
      'options': normalizedOptions,
      'spinnedAt': ServerValue.timestamp,
    };

    final historyRef = _db.ref('houses/$houseId/wheel_history').push();
    final historyKey = historyRef.key;
    if (historyKey == null || historyKey.isEmpty) {
      await _db.ref('houses/$houseId/wheel_result').set(payload);
      return selectedIndex;
    }

    await _db.ref().update({
      'houses/$houseId/wheel_result': payload,
      'houses/$houseId/wheel_history/$historyKey': payload,
    });
    await _trimHistory(houseId);

    return selectedIndex;
  }

  Stream<Map<dynamic, dynamic>?> listenToWheelResult(String houseId) {
    return _db.ref('houses/$houseId/wheel_result').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return null;
      }
      return Map<dynamic, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Stream<List<Map<String, dynamic>>> listenToWheelHistory(String houseId) {
    return _db
        .ref('houses/$houseId/wheel_history')
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
    final snapshot = await _db
        .ref('houses/$houseId/wheel_history')
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
      updates['houses/$houseId/wheel_history/${entry.key}'] = null;
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
