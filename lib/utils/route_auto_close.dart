import 'package:flutter/widgets.dart';

/// Đóng route đang chứa [context] khi route đó còn nằm trên cùng.
///
/// `Navigator.pop()` luôn đóng route trên cùng *còn hiện diện*. Nếu hộp thoại
/// đã được đóng ở nơi khác và đang chạy hiệu ứng thoát, một lệnh pop muộn
/// (hẹn giờ tự đóng, chạm lần hai) sẽ đóng nhầm màn bên dưới — với Trang chủ
/// là route gốc của router, app chỉ còn lại nền trống. Hàm này bỏ qua khi
/// route đã đóng hoặc đang có route khác đè lên.
bool closeRouteIfCurrent(BuildContext context) {
  final route = ModalRoute.of(context);
  final navigator = route?.navigator;
  if (route == null || navigator == null || !route.isCurrent) return false;
  navigator.pop();
  return true;
}
