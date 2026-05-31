import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// ============================================================
///  BleOfflineService — Gra (Logic/Data)
///  Truyền dữ liệu không cần Internet (Smartwatch / BLE Mode) (Phase 8)
///
///  Chức năng:
///  1. Quét tìm thiết bị của người yêu (nếu cách nhau dưới 10m).
///  2. Ghép nối tự động theo House ID mã hoá.
///  3. Bắn tin nhắn (Gửi nhịp tim, tỏ tình) trực tiếp qua Bluetooth Low Energy.
/// ============================================================
class BleOfflineService {
  static final BleOfflineService _instance = BleOfflineService._internal();
  factory BleOfflineService() => _instance;
  BleOfflineService._internal();

  // Dùng flutter_blue_plus (Sẽ khai báo ở pubspec sau)
  // Ở đây Gra mô phỏng Logic Lõi (Mock Architecture) để Trae gọi API trước.
  bool _isBleSupported = false;
  bool _isConnected = false;

  final _heartbeatController = StreamController<int>.broadcast();
  Stream<int> get heartbeatStream => _heartbeatController.stream;

  final _offlineMsgController = StreamController<String>.broadcast();
  Stream<String> get offlineMsgStream => _offlineMsgController.stream;

  /// Khởi tạo và xin quyền Bluetooth
  Future<void> initializeBle() async {
    // 1. Kiểm tra Permission Bluetooth
    // 2. Chuyển trạng thái sang Listening (Kênh ẩn)
    _isBleSupported = true; // Giả lập OK
    debugPrint(
        "📡 [BleOfflineService] Đã kích hoạt sóng quét Bluetooth Low Energy.");
  }

  /// Quét tìm thiết bị có phát đúng chuỗi mã hoá (houseId_hashed)
  Future<void> scanForLoverDevice(String hashedHouseId) async {
    final normalizedHashedHouseId = hashedHouseId.trim();
    if (!_isBleSupported || normalizedHashedHouseId.isEmpty) return;

    // Quét các thiết bị BLE xung quanh phát tín hiệu trùng HouseID
    // Mô phỏng tìm thấy sau 3 giây...
    Timer(const Duration(seconds: 3), () {
      _isConnected = true;
      debugPrint(
          "👩‍❤️‍👨 [BleOfflineService] Bắt sóng thành công thiết bị người yêu ở gần!");
    });
  }

  /// Truyền một chuỗi dữ liệu siêu nhỏ (Tối đa 20 Bytes / Gói tin) qua sóng BLE
  Future<void> sendOfflinePing(String action, int data) async {
    final normalizedAction = action.trim();
    if (!_isConnected || normalizedAction.isEmpty) return;

    final payload = jsonEncode({'a': normalizedAction, 'd': data});
    final bytes = utf8.encode(payload);

    if (bytes.length > 20) {
      debugPrint("Cảnh báo: Bản tin BLE quá lớn! Yêu cầu nén lại.");
    }

    // Đẩy qua kênh gửi BLE tới thiết bị kia
    debugPrint(
        "💌 [BleOfflineService] Bắn tín hiệu BLE thành công: $normalizedAction = $data");
  }

  /// Gửi phím tắt Emoji (❤️, 🥺) từ Apple Watch / ĐT không mạng
  Future<void> sendEmojiBite(String emoji) async {
    final normalizedEmoji = emoji.trim();
    if (normalizedEmoji.isEmpty) return;
    await sendOfflinePing('emoji', normalizedEmoji.runes.first);
  }

  /// Gửi xung nhịp tim trực tiếp
  Future<void> sendHeartbeat(int bpm) async {
    if (bpm <= 0) return;
    await sendOfflinePing('bpm', bpm.clamp(1, 240));
  }

  /// Rút ăng-ten, tắt thiết bị phát
  void dispose() {
    _isConnected = false;
    _heartbeatController.close();
    _offlineMsgController.close();
  }
}
