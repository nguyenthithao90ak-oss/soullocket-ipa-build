import 'dart:async';

/// Khi chưa có cursor (kể cả cache offline trả về rỗng), chỉ đọc một cửa
/// sổ seed giới hạn. Sau đó nối luồng inclusive từ seed cũ nhất để bù mọi
/// tin đến giữa hai subscription. Consumer hợp nhất theo ID để bỏ trùng.
Stream<T> seededLiveStream<T>({
  required int? afterTs,
  required Stream<List<T>> Function() seed,
  required Stream<T> Function(int inclusiveTs) live,
  required int Function(T item) timestampOf,
}) {
  late final StreamController<T> controller;
  StreamSubscription<List<T>>? seedSubscription;
  StreamSubscription<T>? liveSubscription;
  var cancelled = false;
  var anchored = false;

  void attachLive(int cursor) {
    if (cancelled) return;
    try {
      liveSubscription = live(cursor).listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    } catch (error, stack) {
      controller.addError(error, stack);
      unawaited(controller.close());
    }
  }

  controller = StreamController<T>(
    onListen: () {
      if (afterTs != null) {
        anchored = true;
        attachLive(afterTs);
        return;
      }
      try {
        seedSubscription = seed().listen(
          (page) {
            if (cancelled || anchored || page.isEmpty) return;
            anchored = true;
            unawaited(seedSubscription?.cancel());
            var oldest = timestampOf(page.first);
            for (final item in page) {
              final timestamp = timestampOf(item);
              if (timestamp < oldest) oldest = timestamp;
              controller.add(item);
            }
            attachLive(oldest);
          },
          onError: controller.addError,
          onDone: () {
            if (!anchored) unawaited(controller.close());
          },
        );
      } catch (error, stack) {
        controller.addError(error, stack);
        unawaited(controller.close());
      }
    },
    onPause: () {
      seedSubscription?.pause();
      liveSubscription?.pause();
    },
    onResume: () {
      seedSubscription?.resume();
      liveSubscription?.resume();
    },
    onCancel: () async {
      cancelled = true;
      await seedSubscription?.cancel();
      await liveSubscription?.cancel();
    },
  );
  return controller.stream;
}
