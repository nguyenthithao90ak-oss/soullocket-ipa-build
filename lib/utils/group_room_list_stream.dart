import 'dart:async';

import '../models/group_chat_room.dart';

Stream<List<GroupChatRoom>> sharedGroupRoomList({
  required Stream<List<String>> index,
  required Stream<GroupChatRoom?> Function(String) watchRoom,
  required Stream<void> revoked,
  void Function()? onIdle,
}) {
  final listeners = <MultiStreamController<List<GroupChatRoom>>>{};
  final subscriptions = <String, StreamSubscription<GroupChatRoom?>>{};
  final rooms = <String, GroupChatRoom>{};
  final tokens = <String, Object>{};
  StreamSubscription<List<String>>? indexSubscription;
  StreamSubscription<void>? revokedSubscription;
  List<GroupChatRoom>? latest;
  var generation = 0;
  var accessRevoked = false;

  void emit() {
    latest = rooms.values.toList()
      ..sort(
        (first, second) => second.sortTimestamp.compareTo(first.sortTimestamp),
      );
    for (final listener in listeners.toList()) {
      listener.add(List.unmodifiable(latest!));
    }
  }

  void stop() {
    generation++;
    unawaited(indexSubscription?.cancel());
    unawaited(revokedSubscription?.cancel());
    indexSubscription = null;
    revokedSubscription = null;
    for (final subscription in subscriptions.values) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
    tokens.clear();
    rooms.clear();
    latest = null;
    onIdle?.call();
  }

  return Stream<List<GroupChatRoom>>.multi((listener) {
    listeners.add(listener);
    if (latest != null) listener.add(List.unmodifiable(latest!));
    if (listeners.length == 1 && !accessRevoked) {
      final currentGeneration = generation;
      bool current() => generation == currentGeneration && listeners.isNotEmpty;
      void revoke() {
        if (!current()) return;
        accessRevoked = true;
        stop();
        emit();
      }

      revokedSubscription = revoked.listen(
        (_) => revoke(),
        onError: (Object _) => revoke(),
      );
      indexSubscription = index.listen(
        (ids) {
          if (!current()) return;
          final wanted = ids.where((id) => id.isNotEmpty).take(20).toSet();
          for (final removed
              in subscriptions.keys
                  .where((id) => !wanted.contains(id))
                  .toList()) {
            final subscription = subscriptions.remove(removed);
            tokens.remove(removed);
            rooms.remove(removed);
            unawaited(subscription?.cancel());
          }
          for (final id in wanted) {
            if (subscriptions.containsKey(id)) continue;
            final token = Object();
            tokens[id] = token;
            subscriptions[id] = watchRoom(id).listen(
              (room) {
                if (!current() || tokens[id] != token) return;
                if (room == null) {
                  rooms.remove(id);
                } else {
                  rooms[id] = room;
                }
                emit();
              },
              onError: (Object error, StackTrace stack) {
                if (!current() || tokens[id] != token) return;
                rooms.remove(id);
                emit();
                for (final listener in listeners.toList()) {
                  listener.addError(error, stack);
                }
              },
            );
          }
          emit();
        },
        onError: (Object error, StackTrace stack) {
          if (!current()) return;
          stop();
          emit();
          for (final listener in listeners.toList()) {
            listener.addError(error, stack);
          }
        },
      );
    } else if (accessRevoked && latest == null) {
      listener.add(const []);
    }
    listener.onCancel = () {
      listeners.remove(listener);
      if (listeners.isEmpty) stop();
    };
  }, isBroadcast: true);
}
