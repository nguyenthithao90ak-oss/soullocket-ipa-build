import 'dart:async';

/// VideoCompress chỉ cho phép một lần nén; lỗi một tệp không chặn hàng đợi.
class StorageUploadQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
