import 'dart:async';

abstract final class SoulMergeRoleStream {
  static Stream<Map<String, int>> watch({
    required Future<String?> Function() resolveHouseId,
    required Stream<Object?> Function(String houseId, String role) watchRole,
  }) {
    late final StreamController<Map<String, int>> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    final times = <String, int>{};
    final initializedRoles = <String>{};
    var cancelled = false;

    Future<void> start() async {
      try {
        final houseId = await resolveHouseId();
        if (cancelled) return;
        if (houseId == null || houseId.isEmpty) {
          controller.add(const {});
          return;
        }
        for (final role in ['user1', 'user2']) {
          subscriptions.add(
            watchRole(houseId, role).listen(
              (value) {
                if (cancelled) return;
                if (value is num) {
                  times[role] = value.toInt();
                } else {
                  times.remove(role);
                }
                initializedRoles.add(role);
                if (initializedRoles.length == 2) {
                  controller.add(Map<String, int>.unmodifiable(times));
                }
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!cancelled) controller.addError(error, stackTrace);
              },
            ),
          );
        }
      } catch (error, stackTrace) {
        if (!cancelled) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<Map<String, int>>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        cancelled = true;
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      },
    );
    return controller.stream;
  }
}
