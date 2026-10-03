import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

Stream<Map<String, List<Map<String, dynamic>>>> watchSleepHistory({
  required DatabaseReference root,
  required String houseId,
  required String uid,
  required String role,
  required DateTime now,
  required bool Function() isCurrentScope,
}) {
  bool validKey(String value) =>
      value.isNotEmpty &&
      value.length <= 128 &&
      value == value.trim() &&
      !RegExp(r'[.#$\[\]/\\\x00-\x1f\x7f]').hasMatch(value);

  if (!validKey(houseId) || !validKey(uid)) {
    return Stream.error(ArgumentError('Invalid sleep history scope'));
  }

  final scopes = <String>{'user1', 'user2', 'husband', 'wife', uid};
  if (validKey(role)) scopes.add(role);
  final windowStart = now
      .subtract(const Duration(days: 8))
      .millisecondsSinceEpoch;
  final subscriptions = <StreamSubscription<DatabaseEvent>>[];
  final snapshots = <String, Map<String, Map<String, Map<String, dynamic>>>>{};
  final history = <String, List<Map<String, dynamic>>>{};
  late StreamController<Map<String, List<Map<String, dynamic>>>> controller;

  void handleError(Object error, StackTrace stackTrace) {
    if (controller.isClosed) return;
    if (!isCurrentScope()) {
      unawaited(controller.close());
      return;
    }
    controller.addError(error, stackTrace);
  }

  void accept(String scope, String kind, DatabaseEvent event) {
    if (controller.isClosed) return;
    if (!isCurrentScope()) {
      unawaited(controller.close());
      return;
    }
    final sessions = <String, Map<String, dynamic>>{};
    for (final child in event.snapshot.children) {
      final key = child.key;
      final raw = child.value;
      if (key == null || raw is! Map || raw['start_time'] is! num) continue;
      sessions[key] = Map<String, dynamic>.from(raw);
    }
    final scopeSnapshots = snapshots.putIfAbsent(scope, () => {});
    scopeSnapshots[kind] = sessions;
    if (scopeSnapshots.length < 2) return;
    final merged = <String, Map<String, dynamic>>{
      ...scopeSnapshots['latest']!,
      ...scopeSnapshots['week']!,
    };
    if (merged.isEmpty) {
      history.remove(scope);
    } else {
      final ordered = merged.values.toList()
        ..sort(
          (first, second) => (second['start_time'] as num).compareTo(
            first['start_time'] as num,
          ),
        );
      history[scope] = List.unmodifiable(ordered);
    }
    controller.add(Map.unmodifiable(history));
  }

  controller = StreamController<Map<String, List<Map<String, dynamic>>>>(
    onListen: () {
      if (!isCurrentScope()) {
        unawaited(controller.close());
        return;
      }
      for (final scope in scopes) {
        final reference = root.child('houses/$houseId/sleep_history/$scope');
        subscriptions.add(
          reference
              .orderByChild('start_time')
              .startAt(windowStart)
              .onValue
              .listen(
                (event) => accept(scope, 'week', event),
                onError: handleError,
              ),
        );
        subscriptions.add(
          reference
              .orderByChild('start_time')
              .limitToLast(1)
              .onValue
              .listen(
                (event) => accept(scope, 'latest', event),
                onError: handleError,
              ),
        );
      }
    },
    onPause: () {
      for (final subscription in subscriptions) {
        subscription.pause();
      }
    },
    onResume: () {
      for (final subscription in subscriptions) {
        subscription.resume();
      }
    },
    onCancel: () async {
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    },
  );
  return controller.stream;
}
