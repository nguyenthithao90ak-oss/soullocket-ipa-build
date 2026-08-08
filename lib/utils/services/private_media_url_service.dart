import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

class PrivateMediaUrlResult {
  const PrivateMediaUrlResult({required this.url, required this.expiresAt});
  final String url;
  final int expiresAt;
}

class PrivateMediaUrlService {
  PrivateMediaUrlService();

  Future<User?> _waitForCurrentUser() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null) return currentUser;
    try {
      return auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return auth.currentUser;
    }
  }

  Future<PrivateMediaUrlResult> resolve({
    required String houseId,
    required String mediaId,
    required String kind,
  }) async {
    final user = await _waitForCurrentUser();
    if (user == null) throw Exception('Vui lòng đăng nhập lại để xem nội dung này.');
    final idToken = await user.getIdToken() ?? '';

    final normalizedHouseId = houseId.trim();
    final normalizedMediaId = mediaId.trim();
    final normalizedKind = kind.trim();
    if (normalizedHouseId.isEmpty || normalizedMediaId.isEmpty || normalizedKind.isEmpty) {
      throw Exception('Thiếu thông tin media cần mở.');
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.cloudflareWorkerUrl}/api/resolvePrivateMediaUrl'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'houseId': normalizedHouseId,
          'mediaId': normalizedMediaId,
          'kind': normalizedKind,
        }),
      );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final msg = (decoded['error'] as Map?)?['message'] ?? 'Lỗi không xác định.';
        throw Exception(msg);
      }
      final data = Map<String, dynamic>.from(decoded['result'] as Map);
      final url = data['url']?.toString().trim() ?? '';
      final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
      if (url.isEmpty || expiresAt <= 0) throw Exception('Không lấy được liên kết media tạm thời.');
      return PrivateMediaUrlResult(url: url, expiresAt: expiresAt);
    } catch (error) {
      throw Exception(AppErrorMapper.resolve(error).message);
    }
  }
}
