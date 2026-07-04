import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/data_export_result.dart';
import 'offline_cache_service.dart';

class DataExportException implements Exception {
  const DataExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DataExportService {
  DataExportService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static const _consentKeys = <String>[
    'il_tos_accepted',
    'il_privacy_accepted',
    'il_cookie_storage_consent',
    'il_security_device_signals_consent',
  ];

  Future<DataExportResult> requestUserDataExport(
      {required int rangeDays}) async {
    try {
      final callable = _functions.httpsCallable('requestUserDataExport');
      final normalizedRangeDays = _normalizeRangeDays(rangeDays);
      final response = await callable.call(<String, dynamic>{
        'localConsent': await _buildLocalConsentSnapshot(),
        'rangeDays': normalizedRangeDays,
        'options': <String, dynamic>{
          'includeTemporaryMediaUrls': true,
          'includeMemoryImageLinks': true,
          'memoryImageLimit': 100,
          'includeGpsHistory': true,
          'rangeDays': normalizedRangeDays,
        },
      });
      final raw = response.data;
      if (raw is! Map) {
        throw const DataExportException('Phản hồi tải dữ liệu không hợp lệ.');
      }
      final result = DataExportResult.fromMap(Map<String, dynamic>.from(raw));
      if (result.downloadUrl.trim().isEmpty) {
        throw const DataExportException('Link tải dữ liệu chưa sẵn sàng.');
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw DataExportException(_mapFunctionsError(error));
    } on DataExportException {
      rethrow;
    } catch (_) {
      throw const DataExportException(
        'Không tạo được bản tải xuống dữ liệu. Hãy thử lại sau.',
      );
    }
  }

  int _normalizeRangeDays(int value) {
    if (value == 7 || value == 30 || value == 180) {
      return value;
    }
    return 30;
  }

  Future<Map<String, dynamic>> _buildLocalConsentSnapshot() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final values = <String, dynamic>{};
    for (final key in _consentKeys) {
      final value = prefs.get(key);
      if (value != null) {
        values[key] = value;
      }
    }
    return <String, dynamic>{
      'capturedAt': DateTime.now().toIso8601String(),
      'values': values,
    };
  }

  String _mapFunctionsError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Bạn cần đăng nhập lại để tải dữ liệu.';
      case 'permission-denied':
        return 'Bạn không có quyền tải dữ liệu này.';
      case 'resource-exhausted':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Bạn vừa tạo bản tải xuống gần đây. Hãy thử lại sau 15 phút.';
      case 'not-found':
        return 'Chức năng tải dữ liệu chưa được triển khai trên máy chủ.';
      default:
        return 'Không tạo được bản tải xuống dữ liệu. Hãy thử lại sau.';
    }
  }
}
