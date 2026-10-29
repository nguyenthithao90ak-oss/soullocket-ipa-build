import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../health_data_privacy.dart';
import 'health_period_service.dart';

class HealthCycleAccess {
  const HealthCycleAccess({
    required this.path,
    required this.canEdit,
    this.data,
    this.hasRestrictedLegacy = false,
  });

  final String path;
  final bool canEdit;
  final Map<String, dynamic>? data;
  final bool hasRestrictedLegacy;
}

abstract interface class HealthCycleStore {
  Stream<HealthCycleAccess> watch(String houseId);
  Future<void> save(
    String houseId,
    HealthCycleAccess access,
    Map<String, dynamic> data,
  );
}

/// Hồ sơ mới tách theo UID. Dữ liệu cũ chưa rõ chủ vẫn được bảo vệ tại chỗ.
class HealthCycleRepository implements HealthCycleStore {
  HealthCycleRepository({
    String? Function()? currentUid,
    Stream<String?> Function()? authChanges,
    Stream<Object?> Function(String)? watchPath,
    Future<void> Function(String, Map<String, dynamic>)? writePath,
    Future<void> Function(String, Map<String, dynamic>)? saveLegacy,
  }) : _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _authChanges = authChanges ??
           (() => FirebaseAuth.instance.authStateChanges().map((u) => u?.uid)),
       _watchPath = watchPath ??
           ((p) => FirebaseDatabase.instance.ref(p).onValue.map(
             (event) => event.snapshot.value,
           )),
       _writePath = writePath ??
           ((p, data) => FirebaseDatabase.instance.ref(p).set(data)),
       _saveLegacy = saveLegacy ?? ((houseId, data) =>
           HealthPeriodService().logPeriodStart(
             houseId,
             DateTime.parse(data['lastDate'] as String),
             shareWithPartner: data['shareWithPartner'] == true,
             cycleData: data,
           ));

  final String? Function() _uid;
  final Stream<String?> Function() _authChanges;
  final Stream<Object?> Function(String) _watchPath;
  final Future<void> Function(String, Map<String, dynamic>) _writePath;
  final Future<void> Function(String, Map<String, dynamic>) _saveLegacy;

  static String personalPath(String houseId, String uid) =>
      'houses/$houseId/health_cycles/$uid';

  @override
  Stream<HealthCycleAccess> watch(String houseId) {
    final uid = _uid();
    if (uid == null || uid.isEmpty) {
      return Stream.error(StateError('Health session required'));
    }
    final ownPath = personalPath(houseId, uid);
    final legacyPath = 'houses/$houseId/health_cycle';
    final subscriptions = <String, StreamSubscription<Object?>>{};
    final values = <String, Map<String, dynamic>?>{};
    final ready = <String>{};
    final denied = <String>{};
    Set<String> peerPaths = {};
    var membersReady = false;
    var stopped = false;
    late StreamController<HealthCycleAccess> controller;

    bool current() => !stopped && _uid() == uid;
    void fail(Object error, [StackTrace? stack]) {
      if (stopped) return;
      stopped = true;
      controller.addError(error, stack);
      for (final subscription in subscriptions.values) {
        unawaited(subscription.cancel());
      }
      unawaited(controller.close());
    }

    void emit() {
      if (!current()) {
        return;
      }
      if (!ready.contains(ownPath) || !ready.contains(legacyPath) ||
          !membersReady) {
        return;
      }
      final own = values[ownPath];
      final legacy = values[legacyPath];
      if (own != null) {
        controller.add(HealthCycleAccess(path: ownPath, canEdit: true, data: own));
      } else if (legacy != null && legacy['ownerUid'] == uid) {
        controller.add(HealthCycleAccess(
          path: legacyPath, canEdit: true, data: legacy,
        ));
      } else {
        // Không cho tạo bản rỗng nếu chính đường ghi riêng đang bị chặn.
        if (denied.contains(ownPath)) {
          fail(FirebaseException(plugin: 'firebase_database', code: 'permission-denied'));
          return;
        }
        if (!peerPaths.every(ready.contains)) return;
        final shared = <MapEntry<String, Map<String, dynamic>>>[
          for (final p in peerPaths)
            if (values[p] != null) MapEntry(p, values[p]!),
          if (legacy != null) MapEntry(legacyPath, legacy),
        ];
        controller.add(HealthCycleAccess(
          path: shared.isEmpty ? ownPath : shared.first.key,
          canEdit: shared.isEmpty,
          data: shared.isEmpty ? null : shared.first.value,
          hasRestrictedLegacy: shared.isEmpty && denied.contains(legacyPath),
        ));
      }
    }

    void bindRecord(String p, {String? ownerUid}) {
      subscriptions[p] = _watchPath(p).listen((raw) {
        if (!current()) return;
        ready.add(p);
        denied.remove(p);
        if (raw == null) {
          values[p] = null;
        } else if (canDisplayHealthData(raw, uid) && raw is Map &&
            (ownerUid == null || raw['ownerUid'] == ownerUid)) {
          values[p] = Map<String, dynamic>.from(raw);
        } else {
          values[p] = null;
          denied.add(p);
        }
        emit();
      }, onError: (Object error, StackTrace stack) {
        if (!current()) return;
        values[p] = null;
        final permissionDenied = error is FirebaseException &&
            const {'permission-denied', 'permission_denied'}.contains(error.code);
        if (permissionDenied) {
          ready.add(p);
          denied.add(p);
          emit();
        } else {
          fail(error, stack);
        }
      });
    }

    controller = StreamController<HealthCycleAccess>(
      onListen: () {
        bindRecord(ownPath, ownerUid: uid);
        bindRecord(legacyPath);
        subscriptions['members'] = _watchPath('houses/$houseId/members').listen((raw) {
          if (!current()) return;
          final peers = raw is Map ? raw.keys.whereType<String>()
              .where((id) => id != uid).take(2) : const <String>[];
          final next = peers.map((id) => personalPath(houseId, id)).toSet();
          for (final removed in peerPaths.difference(next)) {
            final subscription = subscriptions.remove(removed);
            if (subscription != null) {
              unawaited(subscription.cancel());
            }
            values.remove(removed);
            ready.remove(removed);
            denied.remove(removed);
          }
          final added = next.difference(peerPaths);
          peerPaths = next;
          membersReady = true;
          for (final p in added) {
            bindRecord(p, ownerUid: p.split('/').last);
          }
          emit();
        }, onError: fail);
        subscriptions['auth'] = _authChanges().listen((next) {
          if (next != uid) fail(StateError('Health session changed'));
        }, onError: fail);
      },
      onCancel: () async {
        stopped = true;
        await Future.wait(subscriptions.values.map((s) => s.cancel()));
      },
    );
    return controller.stream;
  }

  @override
  Future<void> save(String houseId, HealthCycleAccess access,
      Map<String, dynamic> data) async {
    final uid = _uid();
    if (uid == null || !access.canEdit || data['ownerUid'] != uid ||
        (access.data != null && access.data!['ownerUid'] != uid)) {
      throw StateError('Health write ownership changed');
    }
    final ownPath = personalPath(houseId, uid);
    final legacyPath = 'houses/$houseId/health_cycle';
    if (access.path == ownPath) {
      await _writePath(ownPath, data);
    } else if (access.path == legacyPath && access.data?['ownerUid'] == uid) {
      await _saveLegacy(houseId, data);
    } else {
      throw StateError('Invalid health write path');
    }
    if (_uid() != uid) throw StateError('Health session changed');
  }
}
