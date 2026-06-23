import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'offline_cache_service.dart';

/// ============================================================
///  IotSmarthomeService — Gra (Phase 18)
///  Lâu Đài Ánh Sáng — Điều khiển đèn thông minh qua mạng nội bộ
///
///  Hoạt động:
///  - Kết nối tới cầu IoT Bridge (Philips Hue / Xiaomi / Tuya).
///  - Người dùng cấu hình IP/host của hub trong phần Cài đặt.
///  - Gửi RGB hoặc scene preset qua REST.
///
///  ⚠️ Lưu ý: Đây là tính năng nâng cao. Nếu bạn không có thiết bị
///  đèn thông minh, service này vẫn load bình thường — chỉ không
///  kết nối được tới hub.
/// ============================================================
class IotSmarthomeService {
  static const String _defaultBridgePath = '/api/v1/light';
  static const String _prefsHubAddressKey = 'il_iot_hub_address';
  static const String _prefsUseHttpsKey = 'il_iot_use_https';
  static final IotSmarthomeService _instance = IotSmarthomeService._internal();
  factory IotSmarthomeService() => _instance;
  IotSmarthomeService._internal();

  Future<IotHubConfig> loadConfig() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return IotHubConfig(
      hubAddress: (prefs.getString(_prefsHubAddressKey) ?? '').trim(),
      useHttps: prefs.getBool(_prefsUseHttpsKey) ?? false,
    );
  }

  Future<void> saveConfig({
    required String hubAddress,
    required bool useHttps,
  }) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(_prefsHubAddressKey, hubAddress.trim());
    await prefs.setBool(_prefsUseHttpsKey, useHttps);
  }

  bool isValidHubAddress(String value) {
    return _normalizeHubUri(
          hubAddress: value,
          useHttps: false,
        ) !=
        null;
  }

  Uri? _normalizeHubUri({
    required String hubAddress,
    required bool useHttps,
  }) {
    final raw = hubAddress.trim();
    if (raw.isEmpty) return null;
    final candidate =
        raw.contains('://') ? raw : '${useHttps ? 'https' : 'http'}://$raw';
    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    if (uri.host.trim().isEmpty) return null;
    return Uri(
      scheme: useHttps ? 'https' : 'http',
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: _defaultBridgePath,
    );
  }

  Future<Uri?> resolveBridgeUri() async {
    final config = await loadConfig();
    return _normalizeHubUri(
      hubAddress: config.hubAddress,
      useHttps: config.useHttps,
    );
  }

  Future<bool> changePartnerRoomColor(int r, int g, int b) async {
    try {
      final bridgeUri = await resolveBridgeUri();
      if (bridgeUri == null) return false;
      final response = await http
          .post(
            bridgeUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'rgb': [r, g, b]
            }),
          )
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IoT] Hub unreachable: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Không thể kết nối hub IoT.',
        ).message}');
      }
      return false; // Không có hub / không có mạng LAN → bỏ qua
    }
  }

  Future<bool> sendRomanticSignal() => changePartnerRoomColor(255, 105, 180);

  Future<bool> sendGoodnightSignal() => changePartnerRoomColor(100, 149, 237);

  Future<bool> sendUrgeSignal() => changePartnerRoomColor(220, 20, 60);

  Future<bool> turnOff() => changePartnerRoomColor(0, 0, 0);

  Future<bool> setNeutralWhite() => changePartnerRoomColor(255, 248, 220);
}

class IotHubConfig {
  final String hubAddress;
  final bool useHttps;

  const IotHubConfig({
    required this.hubAddress,
    required this.useHttps,
  });

  bool get isConfigured => hubAddress.isNotEmpty;
}
