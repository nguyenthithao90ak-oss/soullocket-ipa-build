import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_error_mapper.dart';
import 'app_check_http_headers.dart';
import '../../core/constants/app_config.dart';

/// Kết quả kiểm tra compliance — liệu user có bị restriction không.
class ComplianceResult {
  const ComplianceResult({
    required this.isRestricted,
    required this.level,
    required this.reason,
    required this.status,
  });

  final bool isRestricted;
  final String level; // 'none', 'soft', 'hard'
  final String reason;
  final String status; // 'ok', 'review', 'restricted'

  bool get isHardRestricted => isRestricted && level == 'hard';
  bool get isSoftRestricted => isRestricted && level == 'soft';
}

/// Service kiểm tra trạng thái ad compliance.
///
/// App gọi `checkCompliance()` trước khi thực hiện các hành động
/// nhạy cảm để biết có bị restriction không.
class AdComplianceService {
  AdComplianceService._();

  static final AdComplianceService _instance = AdComplianceService._();
  factory AdComplianceService() => _instance;

  static AdComplianceService get instance => _instance;

  // Cache kết quả để không gọi API quá nhiều
  ComplianceResult? _cachedResult;
  DateTime? _lastCheckAt;
  static const Duration _cacheTtl = Duration(minutes: 5);

  Future<ComplianceResult> checkCompliance() async {
    // Dùng cache nếu còn hạn
    if (_cachedResult != null && _lastCheckAt != null) {
      if (DateTime.now().difference(_lastCheckAt!) < _cacheTtl) {
        return _cachedResult!;
      }
    }

    // Kiểm tra nếu là Pro user thì không restriction
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _cacheResult(const ComplianceResult(
        isRestricted: false,
        level: 'none',
        reason: '',
        status: 'ok',
      ));
    }

    final endpoint = AppConfig.adComplianceCheckUrl.trim();
    if (endpoint.isEmpty) {
      // Nếu chưa cấu hình endpoint, cho phép mọi thứ
      return _cacheResult(const ComplianceResult(
        isRestricted: false,
        level: 'none',
        reason: '',
        status: 'ok',
      ));
    }

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return _cacheResult(const ComplianceResult(
          isRestricted: false,
          level: 'none',
          reason: '',
          status: 'ok',
        ));
      }

      final headers = await AppCheckHttpHeaders.withOptionalToken({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      });

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _cacheResult(const ComplianceResult(
          isRestricted: false,
          level: 'none',
          reason: '',
          status: 'ok',
        ));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return _cacheResult(const ComplianceResult(
          isRestricted: false,
          level: 'none',
          reason: '',
          status: 'ok',
        ));
      }

      final restriction = decoded['restriction'] as Map?;
      if (restriction == null) {
        return _cacheResult(const ComplianceResult(
          isRestricted: false,
          level: 'none',
          reason: '',
          status: 'ok',
        ));
      }

      return _cacheResult(ComplianceResult(
        isRestricted: restriction['isRestricted'] == true,
        level: restriction['level']?.toString() ?? 'none',
        reason: restriction['reason']?.toString() ?? '',
        status: decoded['status']?.toString() ?? 'ok',
      ));
    } catch (e) {
      debugPrint('AdComplianceService error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể kiểm tra tình trạng compliance.',
      ).message}');
      return _cacheResult(const ComplianceResult(
        isRestricted: false,
        level: 'none',
        reason: '',
        status: 'ok',
      ));
    }
  }

  /// Báo cáo với server rằng user đã xem ad để giảm restriction
  Future<bool> reportAdResolution() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final endpoint = AppConfig.adComplianceResolutionUrl.trim();
    if (endpoint.isEmpty) return false;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return false;

      final headers = await AppCheckHttpHeaders.withOptionalToken({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      });

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Xoá cache để lần sau check lại
        _cachedResult = null;
        _lastCheckAt = null;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Xoá cache (gọi khi user logout hoặc cần check lại ngay)
  void invalidateCache() {
    _cachedResult = null;
    _lastCheckAt = null;
  }

  ComplianceResult _cacheResult(ComplianceResult result) {
    _cachedResult = result;
    _lastCheckAt = DateTime.now();
    return result;
  }
}
