import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum MapLocationAccessStatus {
  checking,
  permissionRequired,
  deniedForever,
  serviceDisabled,
  ready,
  unavailable,
}

/// Trạng thái quyền của thiết bị, độc lập với dữ liệu vị trí đã đồng bộ.
class MapLocationAccess {
  const MapLocationAccess(this.status, {this.approximate = false});

  final MapLocationAccessStatus status;
  final bool approximate;

  bool get canTrack => status == MapLocationAccessStatus.ready;

  static MapLocationAccess resolve({
    required LocationPermission permission,
    required bool serviceEnabled,
    bool approximate = false,
  }) {
    if (permission == LocationPermission.deniedForever) {
      return const MapLocationAccess(MapLocationAccessStatus.deniedForever);
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return const MapLocationAccess(
        MapLocationAccessStatus.permissionRequired,
      );
    }
    if (!serviceEnabled) {
      return const MapLocationAccess(MapLocationAccessStatus.serviceDisabled);
    }
    return MapLocationAccess(
      MapLocationAccessStatus.ready,
      approximate: approximate,
    );
  }

  /// Chỉ kiểm tra; tuyệt đối không bật hộp thoại hệ thống khi mở lại màn hình.
  static Future<MapLocationAccess> inspect() async {
    try {
      final permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 6),
      );
      // Trình duyệt không cung cấp API bật/tắt GPS hệ thống như Android.
      final enabled =
          kIsWeb ||
          await Geolocator.isLocationServiceEnabled().timeout(
            const Duration(seconds: 6),
          );
      var approximate = false;
      if (!kIsWeb &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always)) {
        try {
          approximate =
              await Geolocator.getLocationAccuracy().timeout(
                const Duration(seconds: 3),
              ) ==
              LocationAccuracyStatus.reduced;
        } catch (_) {
          // Một số nền tảng không hỗ trợ đọc mức chính xác của quyền.
        }
      }
      return resolve(
        permission: permission,
        serviceEnabled: enabled,
        approximate: approximate,
      );
    } catch (_) {
      return const MapLocationAccess(MapLocationAccessStatus.unavailable);
    }
  }
}
