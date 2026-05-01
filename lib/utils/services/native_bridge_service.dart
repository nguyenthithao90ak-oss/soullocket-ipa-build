import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'local_database_service.dart';
import 'pet_garden_service.dart';

/// ============================================================
///  NativeBridgeService — Gra (Logic/Data)
///  Cầu nối dữ liệu giữa Flutter và Native Widget iOS/Android (Phase 7)
///
///  Chức năng:
///  1. Khởi tạo MethodChannel tên 'com.soullocket.app/widget'.
///  2. Lắng nghe yêu cầu từ Widget ngoài màn hình (như xin dữ liệu thú nuôi).
///  3. Truy vấn SQLite (Offline) và gửi trả ngược lại cho Native vẽ UI.
/// ============================================================
class NativeBridgeService {
  static final NativeBridgeService _instance = NativeBridgeService._internal();
  factory NativeBridgeService() => _instance;
  NativeBridgeService._internal();

  static const platform = MethodChannel('com.soullocket.app/widget');

  /// Gọi hàm này trong main.dart để hệ thống bắt đầu lắng nghe Native
  Future<void> initialize() async {
    platform.setMethodCallHandler(_handleNativeCall);
    debugPrint(
        "🚀 [NativeBridgeService] Đã mở cổng kết nối với Home Screen Widgets");
  }

  /// Hàm bắt sự kiện khi Android/iOS gửi yêu cầu xin dữ liệu
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'getWidgetData':
        // Gọi dữ liệu từ Local App (Không cần mạng)
        final houseId = call.arguments?['houseId'] as String?;
        if (houseId == null) return null;

        return await _buildWidgetPayload(houseId);

      case 'feedPetQuickAction':
        // Khi người dùng bấm nút "Cho ăn" thẳng ngoài màn hình Home
        final houseId = call.arguments?['houseId'] as String?;
        if (houseId != null) {
          await PetGardenService().feedPet(houseId);
          return await _buildWidgetPayload(houseId);
        }
        return false;

      default:
        throw MissingPluginException('Không hỗ trợ hàm: ${call.method}');
    }
  }

  /// Cấu trúc khối dữ liệu JSON gửi ra ngoài màn hình chính cho Trae vẽ
  Future<String> _buildWidgetPayload(String houseId) async {
    // 1. Phân tích Thú cưng
    final pet = await PetGardenService().getPet(houseId);

    // 2. Phân tích Tin nhắn offline gần nhất
    final msgs = await LocalDatabaseService().getCachedMessages(houseId);
    final lastMsg = msgs.isNotEmpty ? msgs.first['text'] : 'Chưa có tin nhắn';

    // 3. Đóng gói JSON
    final payload = {
      'petName': pet?.name ?? 'Chưa đón pet',
      'petLevel': pet?.level ?? 1,
      'petHunger': pet?.hunger ?? 100,
      'petHappiness': pet?.happiness ?? 100,
      'lastMessage': lastMsg,
      'loveDays': 100 // Tạm hardcode, có thể lấy từ DB
    };

    return jsonEncode(payload);
  }

  /// Hàm chủ động đẩy dữ liệu ra Native (ví dụ khi có thông báo mới)
  Future<void> updateNativeWidget(String houseId) async {
    try {
      final payload = await _buildWidgetPayload(houseId);
      await platform.invokeMethod('updateWidget', {'data': payload});
    } on PlatformException catch (e) {
      debugPrint("Lỗi không đẩy được Widget: ${e.message}");
    }
  }
}
