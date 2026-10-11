import 'dart:async';

Stream<T> withInitialEventTimeout<T>(
  Stream<T> source, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return Stream.multi((controller) {
    Timer? deadline;
    StreamSubscription<T>? subscription;
    var receivedFirstEvent = false;

    void cancelDeadline() {
      deadline?.cancel();
      deadline = null;
    }

    controller.onCancel = () async {
      cancelDeadline();
      await subscription?.cancel();
    };
    controller.onPause = () => subscription?.pause();
    controller.onResume = () => subscription?.resume();
    deadline = Timer(timeout, () {
      if (receivedFirstEvent || controller.isClosed) return;
      controller.addError(TimeoutException('initial_event_timeout', timeout));
    });
    subscription = source.listen(
      (event) {
        receivedFirstEvent = true;
        cancelDeadline();
        controller.add(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        cancelDeadline();
        controller.addError(error, stackTrace);
      },
      onDone: () {
        cancelDeadline();
        controller.close();
      },
    );
  });
}
