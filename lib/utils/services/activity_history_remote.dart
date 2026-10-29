import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'core/rtdb_settled_read.dart';
import 'house_service.dart';
import 'infrastructure/cloudflare_data_service.dart';

class ActivityScopeChanged implements Exception {
  const ActivityScopeChanged();
}

class ActivityHistorySnapshot {
  const ActivityHistorySnapshot(
    this.entries, {
    this.floorTs = 0,
    this.floorId = '',
  });
  final List<Map<String, dynamic>> entries;
  final int floorTs;
  final String floorId;

  bool includes(Map<String, dynamic> entry, String houseId) {
    final ts = (entry['ts'] as num?)?.toInt() ?? 0;
    final id = 'activity:$houseId:${entry['id']}';
    return ts > floorTs || (ts == floorTs && id.compareTo(floorId) > 0);
  }
}

/// Đọc lại cờ khi gửi lệnh cũ; lỗi đọc cờ không fallback sang RTDB.
class ActivityHistoryRemote {
  ActivityHistoryRemote()
    : _transport = CloudflareDataService(),
      _uid = (() => FirebaseAuth.instance.currentUser?.uid),
      _house = (() => HouseService().getCurrentHouseId()),
      _flag = ((house) async =>
          (await FirebaseDatabase.instance
                  .ref('houses/$house/settings/dataBackends/activity')
                  .get())
              .value),
      _readRtdb = _readLegacy,
      _writeRtdb = _writeLegacy;

  @visibleForTesting
  factory ActivityHistoryRemote.forTesting({
    required CloudflareDataService transport,
    required String? Function() currentUid,
    required Future<String?> Function() currentHouse,
    required Future<Object?> Function(String) readFlag,
    required Future<List<Map<String, dynamic>>> Function(String) readRtdb,
    required Future<void> Function(String, String, Map<String, dynamic>?, int)
    writeRtdb,
  }) => ActivityHistoryRemote._(
    transport,
    currentUid,
    currentHouse,
    readFlag,
    readRtdb,
    writeRtdb,
  );

  ActivityHistoryRemote._(
    this._transport,
    this._uid,
    this._house,
    this._flag,
    this._readRtdb,
    this._writeRtdb,
  );

  final CloudflareDataService _transport;
  final String? Function() _uid;
  final Future<String?> Function() _house;
  final Future<Object?> Function(String) _flag;
  final Future<List<Map<String, dynamic>>> Function(String) _readRtdb;
  final Future<void> Function(String, String, Map<String, dynamic>?, int)
  _writeRtdb;
  static final Map<String, DateTime> _lastLegacyTrim = {};

  static Future<List<Map<String, dynamic>>> _readLegacy(String house) async {
    final value = (await readQuerySettled(
      FirebaseDatabase.instance
          .ref('houses/$house/activity_history')
          .orderByChild('ts')
          .limitToLast(20),
    )).value;
    if (value == null) return [];
    return (value as Map).entries
        .map(
          (item) => <String, dynamic>{
            ...Map<String, dynamic>.from(item.value as Map),
            'id': item.key.toString(),
            'houseId': house,
          },
        )
        .toList();
  }

  static Future<void> _deleteLegacyThrough(
    DatabaseReference ref,
    int ts, {
    String? key,
  }) async {
    // Mỗi lượt tải tối đa 100 mục; retry tiếp tục cùng mốc thời gian.
    for (var page = 0; page < 20; page++) {
      final snapshot = await ref
          .orderByChild('ts')
          .endAt(ts, key: key)
          .limitToFirst(100)
          .get();
      if (!snapshot.exists) return;
      await ref.update({for (final item in snapshot.children) item.key!: null});
      if (snapshot.children.length < 100) return;
    }
    throw StateError('Activity cleanup requires retry');
  }

  static Future<void> _writeLegacy(
    String house,
    String action,
    Map<String, dynamic>? entry,
    int through,
  ) async {
    final ref = FirebaseDatabase.instance.ref('houses/$house/activity_history');
    if (action == 'clear') {
      await _deleteLegacyThrough(ref, through);
      return;
    }
    await ref.child(entry!['id'] as String).set(entry);
    final scope = '${FirebaseAuth.instance.currentUser?.uid}:$house';
    final now = DateTime.now();
    if (now.difference(_lastLegacyTrim[scope] ?? DateTime(1970)) <
        const Duration(minutes: 1)) {
      return;
    }
    final snapshot = await ref.orderByChild('ts').limitToLast(21).get();
    if (snapshot.children.length > 20) {
      final oldest = snapshot.children.first;
      final value = oldest.value as Map;
      await _deleteLegacyThrough(
        ref,
        (value['ts'] as num).toInt(),
        key: oldest.key,
      );
    }
    if (_lastLegacyTrim.length > 100) _lastLegacyTrim.clear();
    _lastLegacyTrim[scope] = now;
  }

  Future<void> _scope(String uid, String house) async {
    if (_uid() != uid || await _house() != house || _uid() != uid) {
      throw const ActivityScopeChanged();
    }
  }

  Future<String> _backend(String uid, String house) async {
    await _scope(uid, house);
    final flag = await _flag(house).timeout(const Duration(seconds: 12));
    await _scope(uid, house);
    if (flag == 'd1') return 'd1';
    if (flag == null || flag == 'rtdb') return 'rtdb';
    throw StateError('Activity backend not ready');
  }

  Future<ActivityHistorySnapshot> read(String house) async {
    final uid = _uid();
    if (uid == null) throw const ActivityScopeChanged();
    final backend = await _backend(uid, house);
    if (backend == 'rtdb') {
      final entries = await _readRtdb(house);
      await _scope(uid, house);
      return ActivityHistorySnapshot(entries);
    }
    final result = await _transport.readPage(
      houseId: house,
      resource: 'activity-history',
      parameters: {'limit': '20'},
    );
    await _scope(uid, house);
    final data = result['data'];
    final state = result['state'];
    if (result['complete'] != true ||
        data is! List ||
        data.length > 20 ||
        state is! Map ||
        state['floor_ts'] is! int ||
        state['floor_id'] is! String) {
      throw const FormatException('Invalid Activity snapshot');
    }
    final entries = data.map((item) {
      final entry = Map<String, dynamic>.from(item as Map);
      if (entry['houseId'] != house ||
          entry['id'] is! String ||
          entry['ts'] is! int) {
        throw const FormatException('Invalid Activity scope');
      }
      return entry;
    }).toList();
    return ActivityHistorySnapshot(
      entries,
      floorTs: state['floor_ts'] as int,
      floorId: state['floor_id'] as String,
    );
  }

  Future<void> send({
    required String houseId,
    required String action,
    required Map<String, dynamic>? entry,
    required int issuedAt,
    required String operationId,
    int? through,
    String? expectedUid,
  }) async {
    final uid = _uid();
    if (uid == null || (expectedUid != null && uid != expectedUid)) {
      throw const ActivityScopeChanged();
    }
    if (!['append', 'clear'].contains(action) ||
        (action == 'append' && entry == null)) {
      throw ArgumentError('Invalid Activity action');
    }
    // Giới hạn tuổi lệnh giống Worker, kể cả khi rollback về RTDB.
    if (issuedAt <
        DateTime.now().millisecondsSinceEpoch -
            const Duration(days: 7).inMilliseconds) {
      return;
    }
    final backend = await _backend(uid, houseId);
    final payload = entry == null
        ? null
        : (Map<String, dynamic>.from(entry)..remove('syncStatus'));
    if (payload != null &&
        (payload['houseId'] != houseId || payload['authorUid'] != uid)) {
      throw const ActivityScopeChanged();
    }
    if (backend == 'rtdb') {
      await _writeRtdb(houseId, action, payload, through ?? issuedAt);
      await _scope(uid, houseId);
      return;
    }
    final key = sha256
        .convert(utf8.encode(jsonEncode([uid, houseId, operationId])))
        .toString();
    await _transport.write(
      houseId: houseId,
      resource: 'activity-history',
      idempotencyKey: key,
      body: {
        'action': action,
        'issuedAt': issuedAt,
        if (action == 'append') 'entry': payload,
        if (action == 'clear') 'through': through ?? issuedAt,
      },
    );
    await _scope(uid, houseId);
  }

  void dispose() => _transport.dispose();
}
