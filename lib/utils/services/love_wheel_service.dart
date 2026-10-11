import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WheelHistoryStore {
  const WheelHistoryStore(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String houseId) {
    final scope = base64Url.encode(utf8.encode(houseId.trim()));
    return 'love_wheel_latest_v1_$scope';
  }

  static String _legacyCleanupKey(String houseId) {
    final scope = base64Url.encode(utf8.encode(houseId.trim()));
    return 'love_wheel_legacy_cleanup_v1_$scope';
  }

  Future<void> saveLatest(String houseId, Map<String, dynamic> payload) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    final saved = await _preferences.setString(
      _key(normalizedHouseId),
      jsonEncode(<String, dynamic>{...payload, 'id': 'local-latest'}),
    );
    if (!saved) throw StateError('wheel-history-save-failed');
  }

  Future<void> importLegacyLatest(
    String houseId,
    Map<String, dynamic> payload,
  ) async {
    final resultText = payload['resultText'];
    if (resultText is! String || resultText.trim().isEmpty) return;
    if (readLatest(houseId) != null) return;
    await saveLatest(houseId, payload);
  }

  Map<String, dynamic>? readLatest(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return null;
    final encoded = _preferences.getString(_key(normalizedHouseId));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    }
  }

  bool legacyCleanupCompleted(String houseId) {
    final normalizedHouseId = houseId.trim();
    return normalizedHouseId.isNotEmpty &&
        _preferences.getBool(_legacyCleanupKey(normalizedHouseId)) == true;
  }

  Future<void> markLegacyCleanupCompleted(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return;
    await _preferences.setBool(_legacyCleanupKey(normalizedHouseId), true);
  }
}

class LoveWheelService {
  static final LoveWheelService _instance = LoveWheelService._internal();

  factory LoveWheelService() => _instance;

  LoveWheelService._internal()
    : _db = FirebaseDatabase.instance.ref(),
      _preferences = SharedPreferences.getInstance,
      _migrationTimeout = const Duration(seconds: 5);

  @visibleForTesting
  LoveWheelService.forTesting(
    this._db,
    this._preferences, {
    this._migrationTimeout = const Duration(seconds: 5),
  });

  final DatabaseReference _db;
  final Future<SharedPreferences> Function() _preferences;
  final Duration _migrationTimeout;
  final Map<String, Future<void>> _cleanupOperations = {};

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
      'spinnedAt': DateTime.now().millisecondsSinceEpoch,
    };

    final preferences = await _preferences();
    await WheelHistoryStore(preferences).saveLatest(normalizedHouseId, payload);

    return selectedIndex;
  }

  Future<List<Map<String, dynamic>>> loadLocalWheelHistory(
    String houseId,
  ) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      return const [];
    }
    final preferences = await _preferences();
    final latest = WheelHistoryStore(preferences).readLatest(normalizedHouseId);
    return latest == null ? const [] : <Map<String, dynamic>>[latest];
  }

  Future<void> clearLegacyServerHistory(String houseId) {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Future<void>.value();
    return _cleanupOperations.putIfAbsent(normalizedHouseId, () async {
      try {
        await _preserveLatestAndClear(normalizedHouseId);
      } finally {
        _cleanupOperations.remove(normalizedHouseId);
      }
    });
  }

  Future<void> _preserveLatestAndClear(String houseId) async {
    try {
      final preferences = await _preferences();
      final store = WheelHistoryStore(preferences);
      if (store.legacyCleanupCompleted(houseId)) return;

      if (store.readLatest(houseId) == null) {
        final snapshot = await _db
            .child('houses/$houseId/wheel_history')
            .orderByChild('spinnedAt')
            .limitToLast(1)
            .get()
            .timeout(_migrationTimeout);
        final history = snapshot.value;
        Map<String, dynamic>? latest;
        if (history is Map) {
          for (final payload in history.values.whereType<Map>()) {
            latest = Map<String, dynamic>.from(payload);
          }
        }
        if (latest == null) {
          final result = await _db
              .child('houses/$houseId/wheel_result')
              .get()
              .timeout(_migrationTimeout);
          if (result.value is Map) {
            latest = Map<String, dynamic>.from(result.value as Map);
          }
        }
        if (latest != null) await store.importLegacyLatest(houseId, latest);
      }

      await _db
          .update({
            'houses/$houseId/wheel_history': null,
            'houses/$houseId/wheel_result': null,
          })
          .timeout(_migrationTimeout);
      await store.markLegacyCleanupCompleted(houseId);
    } catch (_) {}
  }
}
