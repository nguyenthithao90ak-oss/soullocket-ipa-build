import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// Đọc một truy vấn RTDB qua listener ngắn thay cho `get()`.
///
/// App bật persistence nên listener gửi kèm mã băm của bản đã lưu trên máy: dữ liệu
/// không đổi thì server không gửi lại (gần 0 byte), còn `get()` luôn tải lại toàn bộ
/// kết quả. Sự kiện đầu có thể là bản lưu trên máy, nên chờ thêm [settle] sau sự kiện
/// cuối để nhận bản mới từ server khi dữ liệu đã đổi. Chưa có sự kiện nào trước
/// [timeout] thì báo [TimeoutException] giống `get().timeout(...)`.
///
/// Chỉ dùng cho dữ liệu chấp nhận được độ trễ ngắn (danh sách ảnh cho widget, ảnh bìa).
/// Không dùng cho kiểm tra quyền, số dư hay dữ liệu cần chính xác tức thời.
Future<DataSnapshot> readQuerySettled(
  Query query, {
  Duration settle = const Duration(milliseconds: 800),
  Duration timeout = const Duration(seconds: 12),
}) async {
  final event = await settleLatest<DatabaseEvent>(
    query.onValue,
    settle: settle,
    timeout: timeout,
  );
  return event.snapshot;
}

/// Lấy giá trị mới nhất của [events] khi luồng im lặng đủ [settle] rồi hủy listener.
///
/// Lỗi của luồng (ví dụ mất quyền đọc) luôn được trả về, kể cả khi đã có bản lưu trên
/// máy, để caller không dùng dữ liệu của phạm vi không còn quyền. Hết [timeout] mà luồng
/// vẫn phát liên tục thì trả bản mới nhất đang có.
Future<T> settleLatest<T>(
  Stream<T> events, {
  required Duration settle,
  required Duration timeout,
}) {
  final completer = Completer<T>();
  StreamSubscription<T>? subscription;
  Timer? settleTimer;
  Timer? timeoutTimer;
  var hasValue = false;
  T? latest;

  void finish(void Function() complete) {
    if (completer.isCompleted) return;
    settleTimer?.cancel();
    timeoutTimer?.cancel();
    complete();
    final active = subscription;
    if (active != null) unawaited(active.cancel());
  }

  void completeLatest() => completer.complete(latest as T);

  subscription = events.listen(
    (value) {
      latest = value;
      hasValue = true;
      settleTimer?.cancel();
      settleTimer = Timer(settle, () => finish(completeLatest));
    },
    onError: (Object error, StackTrace stackTrace) =>
        finish(() => completer.completeError(error, stackTrace)),
    onDone: () => finish(
      () => hasValue
          ? completeLatest()
          : completer.completeError(
              StateError('RTDB stream closed without data'),
            ),
    ),
    cancelOnError: true,
  );
  if (completer.isCompleted) unawaited(subscription.cancel());
  timeoutTimer = Timer(
    timeout,
    () => finish(
      () => hasValue
          ? completeLatest()
          : completer.completeError(
              TimeoutException('RTDB read timed out', timeout),
            ),
    ),
  );
  return completer.future;
}
