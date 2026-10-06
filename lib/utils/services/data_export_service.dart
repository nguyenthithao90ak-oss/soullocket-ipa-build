import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'l10n_service.dart';
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
  DataExportService({FirebaseFunctions? functions, FirebaseAuth? auth,
    Future<String> Function()? readTimeZone})
      : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _readTimeZone = readTimeZone ?? _deviceTimeZone;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final Future<String> Function() _readTimeZone;

  static Future<String> _deviceTimeZone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // Thiếu bridge chỉ ảnh hưởng định dạng export, không làm mất dữ liệu.
      return 'UTC';
    }
  }

  static const _consentKeys = <String>[
    'il_tos_accepted',
    'il_privacy_accepted',
    'il_cookie_storage_consent',
    'il_security_device_signals_consent',
  ];

  Future<DataExportResult> requestUserDataExport(
      {required int rangeDays}) async {
    final uid = _auth.currentUser?.uid;
    final locale = L10nService().localeCode;
    void assertCurrentUser() {
      if (uid == null || _auth.currentUser?.uid != uid) {
        throw DataExportException(UiCopy.text('copy_99c1b9afbfb7'));
      }
    }
    try {
      assertCurrentUser();
      final timeZone = await _readTimeZone();
      final consent = await _buildLocalConsentSnapshot();
      assertCurrentUser();
      final callable = _functions.httpsCallable('requestUserDataExport');
      final normalizedRangeDays = _normalizeRangeDays(rangeDays);
      final response = await callable.call(<String, dynamic>{
        'localConsent': consent,
        'locale': locale,
        'timeZone': timeZone,
        'rangeDays': normalizedRangeDays,
        'options': <String, dynamic>{
          'includeTemporaryMediaUrls': true,
          'includeMemoryImageLinks': true,
          'memoryImageLimit': 100,
          'includeGpsHistory': true,
          'rangeDays': normalizedRangeDays,
        },
      });
      assertCurrentUser();
      final raw = response.data;
      if (raw is! Map) {
        throw DataExportException(UiCopy.text('copy_b12a97b2710a')); 
      }
      final result = DataExportResult.fromMap(Map<String, dynamic>.from(raw));
      if (result.downloadUrl.trim().isEmpty) {
        throw DataExportException(UiCopy.text('copy_c09794f546c5')); 
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw DataExportException(_mapFunctionsError(error));
    } on DataExportException {
      rethrow;
    } catch (_) {
      throw DataExportException(UiCopy.text('copy_f83f74a051ab')); 
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
        return UiCopy.text('copy_99c1b9afbfb7');
      case 'permission-denied':
        return UiCopy.text('copy_cb72ed85751d');
      case 'resource-exhausted':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : UiCopy.text('copy_d659040949af');
      case 'not-found':
        return UiCopy.text('copy_e3f8f7475f6d');
      default:
        return UiCopy.text('copy_f83f74a051ab');
    }
  }
}
