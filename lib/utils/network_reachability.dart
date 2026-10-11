import 'dart:async';

/// Cầu nối nhẹ tới trạng thái mạng của app để widget không phải import cả `ConnectivityService`
/// (kéo theo presence, đồng bộ dữ liệu...). `ConnectivityService.initialize` gắn nguồn thật vào đây.
/// Chưa gắn nguồn thì coi như đang online, nên không làm đổi hành vi của test hay màn hình cũ.
class NetworkReachability {
  NetworkReachability._();

  static bool Function() _isOnline = () => true;
  static Stream<bool> _changes = const Stream<bool>.empty();

  static bool get isOnline => _isOnline();
  static Stream<bool> get changes => _changes;

  static void bind({
    required bool Function() isOnline,
    required Stream<bool> changes,
  }) {
    _isOnline = isOnline;
    _changes = changes;
  }
}
