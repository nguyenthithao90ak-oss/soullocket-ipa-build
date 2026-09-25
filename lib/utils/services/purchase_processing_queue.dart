import 'dart:async';

/// Xếp hàng callback store; một giao dịch lỗi không làm mất callback tiếp theo.
class PurchaseProcessingQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> add(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> get drained => _tail;
}
