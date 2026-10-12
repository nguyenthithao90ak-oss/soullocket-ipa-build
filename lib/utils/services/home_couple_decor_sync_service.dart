import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/views/home/widgets/main_home/home_couple_decor_model.dart';

class HomeCoupleDecorSnapshot {
  const HomeCoupleDecorSnapshot({
    required this.decor,
    this.revision = 0,
    this.requestId = '',
    this.updatedBy = '',
    this.updatedAt = 0,
  });

  factory HomeCoupleDecorSnapshot.empty() =>
      HomeCoupleDecorSnapshot(decor: HomeCoupleCardDecor.defaultValue());

  final HomeCoupleCardDecor decor;
  final int revision;
  final String requestId;
  final String updatedBy;
  final int updatedAt;

  static List<dynamic> _items(dynamic raw) {
    if (raw is List) return raw;
    if (raw is! Map) return [];
    final keys = raw.keys.toList()
      ..sort(
        (first, second) => int.parse('$first').compareTo(int.parse('$second')),
      );
    return [for (final key in keys) raw[key]];
  }

  factory HomeCoupleDecorSnapshot.fromRaw(Object? raw) {
    if (raw == null) return HomeCoupleDecorSnapshot.empty();
    if (raw is! Map ||
        raw['decor'] is! Map ||
        raw['revision'] is! int ||
        (raw['revision'] as int) < 1 ||
        raw['updatedAt'] is! int ||
        raw['updatedBy'] is! String ||
        raw['requestId'] is! String) {
      throw const FormatException('invalid_shared_decor');
    }
    final design = Map<String, dynamic>.from(raw['decor'] as Map);
    design['stickers'] = _items(design['stickers']);
    design['drawings'] = [
      for (final stroke in _items(design['drawings']))
        if (stroke is Map) {...stroke, 'points': _items(stroke['points'])},
    ];
    return HomeCoupleDecorSnapshot(
      decor: HomeCoupleCardDecor.fromJson(design),
      revision: raw['revision'] as int,
      requestId: raw['requestId'] as String,
      updatedBy: raw['updatedBy'] as String,
      updatedAt: raw['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'decor': decor.toSharedJson(),
    'revision': revision,
    'requestId': requestId,
    'updatedBy': updatedBy,
    'updatedAt': updatedAt,
  };
}

class HomeCoupleDecorQuota {
  const HomeCoupleDecorQuota(this.times, this.requestIds);

  factory HomeCoupleDecorQuota.fromRaw(Object? raw) {
    if (raw == null) {
      return const HomeCoupleDecorQuota([0, 0, 0, 0, 0], ['', '', '', '', '']);
    }
    if (raw is! Map || raw['version'] != 1) {
      throw const FormatException('invalid_decor_quota');
    }
    final times = <int>[];
    final ids = <String>[];
    for (var index = 0; index < 5; index++) {
      final time = raw['at$index'];
      final id = raw['id$index'];
      if (time is! int ||
          time < 0 ||
          id is! String ||
          (time == 0) != id.isEmpty ||
          (index > 0 && time > times.last)) {
        throw const FormatException('invalid_decor_quota');
      }
      times.add(time);
      ids.add(id);
    }
    return HomeCoupleDecorQuota(times, ids);
  }

  final List<int> times;
  final List<String> requestIds;
  static const window = Duration(minutes: 30);

  int retryAfterMs(int nowMs) =>
      max(0, times.last + window.inMilliseconds - nowMs);

  Map<String, dynamic> next(String houseId, int revision, String requestId) => {
    'version': 1,
    'houseId': houseId,
    'revision': revision,
    'at0': ServerValue.timestamp,
    'id0': requestId,
    for (var index = 1; index < 5; index++) ...{
      'at$index': times[index - 1],
      'id$index': requestIds[index - 1],
    },
  };
}

enum HomeCoupleDecorSaveStatus {
  saved,
  unchanged,
  rateLimited,
  conflict,
  pending,
  failed,
  scopeChanged,
}

class HomeCoupleDecorSaveResult {
  const HomeCoupleDecorSaveResult(
    this.status, {
    this.snapshot,
    this.retryAfterMs = 0,
    this.message,
  });

  final HomeCoupleDecorSaveStatus status;
  final HomeCoupleDecorSnapshot? snapshot;
  final int retryAfterMs;
  final String? message;
}

typedef HomeCoupleDecorSave =
    Future<HomeCoupleDecorSaveResult> Function({
      required HomeCoupleCardDecor decor,
      required int expectedRevision,
      required String requestId,
    });

abstract interface class HomeCoupleDecorTransport {
  String? get currentUid;
  Stream<Object?> watch(String houseId);
  Future<Object?> readDecor(String houseId);
  Future<Object?> readQuota(String uid);
  Future<int> serverNowMs();
  Future<void> write(Map<String, dynamic> update);
}

class _FirebaseCoupleDecorTransport implements HomeCoupleDecorTransport {
  DatabaseReference get _root => FirebaseDatabase.instance.ref();
  @override
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  @override
  Stream<Object?> watch(String houseId) => _root
      .child('houses/$houseId/homeCoupleDecor')
      .onValue
      .map((event) => event.snapshot.value);
  @override
  Future<Object?> readDecor(String houseId) async =>
      (await _root
              .child('houses/$houseId/homeCoupleDecor')
              .get()
              .timeout(const Duration(seconds: 6)))
          .value;
  @override
  Future<Object?> readQuota(String uid) async =>
      (await _root
              .child('users/$uid/homeCoupleDecorQuota')
              .get()
              .timeout(const Duration(seconds: 6)))
          .value;
  @override
  Future<int> serverNowMs() async {
    final snapshot = await FirebaseDatabase.instance
        .ref('.info/serverTimeOffset')
        .onValue
        .first
        .timeout(const Duration(seconds: 3));
    if (snapshot.snapshot.value is! num) {
      throw const FormatException('invalid_server_time');
    }
    return DateTime.now().millisecondsSinceEpoch +
        (snapshot.snapshot.value as num).toInt();
  }

  @override
  Future<void> write(Map<String, dynamic> update) => _root.update(update);
}

class _PendingDecorSave {
  const _PendingDecorSave(this.requestId, this.result);
  final String requestId;
  final Future<HomeCoupleDecorSaveResult> result;
}

class _ConfirmedDecor {
  const _ConfirmedDecor(this.scope, this.snapshot);
  final String scope;
  final HomeCoupleDecorSnapshot snapshot;
}

class HomeCoupleDecorSyncService {
  HomeCoupleDecorSyncService({HomeCoupleDecorTransport? transport})
    : _transport = transport ?? _FirebaseCoupleDecorTransport();

  final HomeCoupleDecorTransport _transport;
  final _pending = <String, _PendingDecorSave>{};
  final _confirmed = StreamController<_ConfirmedDecor>.broadcast();
  static const _cachePrefix = 'home_couple_shared_decor_v2_';
  static const saveTimeout = Duration(seconds: 15);

  static String newRequestId() {
    final random = Random.secure();
    return List.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
  }

  Future<HomeCoupleDecorSnapshot> loadCached(String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix${Uri.encodeComponent(scope)}');
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['revision'] == 0) {
          return HomeCoupleDecorSnapshot(
            decor: HomeCoupleCardDecor.fromJson(decoded['decor']),
          );
        }
        return HomeCoupleDecorSnapshot.fromRaw(decoded);
      }
    } catch (_) {}
    return HomeCoupleDecorSnapshot(
      decor: await HomeCoupleDecorStore.load(scope),
    );
  }

  Future<HomeCoupleDecorSnapshot> loadForScope({
    required String uid,
    required String houseId,
  }) async {
    try {
      final raw = await _transport.readDecor(houseId);
      if (raw != null) {
        final snapshot = HomeCoupleDecorSnapshot.fromRaw(raw);
        await cache('$uid|$houseId', snapshot);
        return snapshot;
      }
    } catch (_) {}
    return loadCached('$uid|$houseId');
  }

  Future<void> cache(String scope, HomeCoupleDecorSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix${Uri.encodeComponent(scope)}',
        jsonEncode(snapshot.toJson()),
      );
    } catch (_) {}
  }

  Stream<HomeCoupleDecorSnapshot> watch({
    required String uid,
    required String houseId,
    required bool Function() isCurrent,
  }) {
    final scope = '$uid|$houseId';
    StreamSubscription<Object?>? remote;
    StreamSubscription<_ConfirmedDecor>? confirmed;
    late final StreamController<HomeCoupleDecorSnapshot> controller;
    bool current() => isCurrent() && _transport.currentUid == uid;
    void emit(HomeCoupleDecorSnapshot snapshot) {
      if (current() && !controller.isClosed) controller.add(snapshot);
    }

    controller = StreamController<HomeCoupleDecorSnapshot>(
      onListen: () {
        remote = _transport
            .watch(houseId)
            .listen(
              (raw) {
                if (!current()) return;
                try {
                  final snapshot = HomeCoupleDecorSnapshot.fromRaw(raw);
                  if (_pending[scope]?.requestId == snapshot.requestId &&
                      snapshot.updatedBy == uid) {
                    return;
                  }
                  emit(snapshot);
                } catch (error, stack) {
                  controller.addError(error, stack);
                }
              },
              onError: (Object error, StackTrace stack) {
                if (current()) {
                  controller.addError(error, stack);
                }
              },
            );
        confirmed = _confirmed.stream.listen((event) {
          if (event.scope == scope) emit(event.snapshot);
        });
      },
      onCancel: () async {
        await remote?.cancel();
        await confirmed?.cancel();
      },
    );
    return controller.stream;
  }

  Future<HomeCoupleDecorSaveResult> save({
    required String uid,
    required String houseId,
    required HomeCoupleCardDecor decor,
    required int expectedRevision,
    required String requestId,
    required bool Function() isCurrent,
  }) async {
    final scope = '$uid|$houseId';
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(uid) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(houseId) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId)) {
      return const HomeCoupleDecorSaveResult(HomeCoupleDecorSaveStatus.failed);
    }
    final existing = _pending[scope];
    if (existing != null && existing.requestId != requestId) {
      return const HomeCoupleDecorSaveResult(HomeCoupleDecorSaveStatus.pending);
    }
    final future =
        existing?.result ??
        _save(
          uid: uid,
          houseId: houseId,
          decor: decor,
          expectedRevision: expectedRevision,
          requestId: requestId,
          isCurrent: isCurrent,
        );
    if (existing == null) {
      _pending[scope] = _PendingDecorSave(requestId, future);
      unawaited(
        future.then((result) {
          _pending.remove(scope);
          if (result.snapshot != null && !_confirmed.isClosed) {
            _confirmed.add(_ConfirmedDecor(scope, result.snapshot!));
          }
        }),
      );
    }
    return future.timeout(
      saveTimeout,
      onTimeout: () =>
          const HomeCoupleDecorSaveResult(HomeCoupleDecorSaveStatus.pending),
    );
  }

  Future<HomeCoupleDecorSaveResult> _save({
    required String uid,
    required String houseId,
    required HomeCoupleCardDecor decor,
    required int expectedRevision,
    required String requestId,
    required bool Function() isCurrent,
  }) async {
    bool current() => isCurrent() && _transport.currentUid == uid;
    if (!current()) {
      return const HomeCoupleDecorSaveResult(
        HomeCoupleDecorSaveStatus.scopeChanged,
      );
    }
    try {
      final values = await Future.wait<Object?>([
        _transport.readDecor(houseId),
        _transport.readQuota(uid),
        _transport.serverNowMs(),
      ]);
      if (!current()) {
        return const HomeCoupleDecorSaveResult(
          HomeCoupleDecorSaveStatus.scopeChanged,
        );
      }
      final latest = HomeCoupleDecorSnapshot.fromRaw(values[0]);
      final quota = HomeCoupleDecorQuota.fromRaw(values[1]);
      final nowMs = values[2] as int;
      if (quota.requestIds.contains(requestId)) {
        return HomeCoupleDecorSaveResult(
          HomeCoupleDecorSaveStatus.saved,
          snapshot: latest,
        );
      }
      if (latest.revision > 0 && decor.sameDesign(latest.decor)) {
        return HomeCoupleDecorSaveResult(
          HomeCoupleDecorSaveStatus.unchanged,
          snapshot: latest,
        );
      }
      if (latest.revision != expectedRevision) {
        return HomeCoupleDecorSaveResult(
          HomeCoupleDecorSaveStatus.conflict,
          snapshot: latest,
        );
      }
      final retryAfterMs = quota.retryAfterMs(nowMs);
      if (retryAfterMs > 0) {
        return HomeCoupleDecorSaveResult(
          HomeCoupleDecorSaveStatus.rateLimited,
          retryAfterMs: retryAfterMs,
        );
      }
      final revision = latest.revision + 1;
      await _transport.write({
        'houses/$houseId/homeCoupleDecor': {
          'decor': decor.toSharedJson(),
          'revision': revision,
          'requestId': requestId,
          'updatedBy': uid,
          'updatedAt': ServerValue.timestamp,
        },
        'users/$uid/homeCoupleDecorQuota': quota.next(
          houseId,
          revision,
          requestId,
        ),
      });
      if (!current()) {
        return const HomeCoupleDecorSaveResult(
          HomeCoupleDecorSaveStatus.scopeChanged,
        );
      }
      final snapshot = HomeCoupleDecorSnapshot(
        decor: HomeCoupleCardDecor.fromJson(decor.toSharedJson()),
        revision: revision,
        requestId: requestId,
        updatedBy: uid,
        updatedAt: nowMs,
      );
      await cache('$uid|$houseId', snapshot);
      return HomeCoupleDecorSaveResult(
        HomeCoupleDecorSaveStatus.saved,
        snapshot: snapshot,
      );
    } catch (error) {
      if (!current()) {
        return const HomeCoupleDecorSaveResult(
          HomeCoupleDecorSaveStatus.scopeChanged,
        );
      }
      if (error is FirebaseException && error.code == 'permission-denied') {
        try {
          final latest = HomeCoupleDecorSnapshot.fromRaw(
            await _transport.readDecor(houseId),
          );
          final quota = HomeCoupleDecorQuota.fromRaw(
            await _transport.readQuota(uid),
          );
          final nowMs = await _transport.serverNowMs();
          if (!current()) {
            return const HomeCoupleDecorSaveResult(
              HomeCoupleDecorSaveStatus.scopeChanged,
            );
          }
          if (quota.requestIds.contains(requestId)) {
            return HomeCoupleDecorSaveResult(
              HomeCoupleDecorSaveStatus.saved,
              snapshot: latest,
            );
          }
          if (latest.revision != expectedRevision) {
            return HomeCoupleDecorSaveResult(
              HomeCoupleDecorSaveStatus.conflict,
              snapshot: latest,
            );
          }
          final wait = quota.retryAfterMs(nowMs);
          if (wait > 0) {
            return HomeCoupleDecorSaveResult(
              HomeCoupleDecorSaveStatus.rateLimited,
              retryAfterMs: wait,
            );
          }
        } catch (_) {}
      }
      return HomeCoupleDecorSaveResult(
        HomeCoupleDecorSaveStatus.failed,
        message: AppErrorMapper.resolve(error).message,
      );
    }
  }

  Future<void> dispose() => _confirmed.close();
}
