import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/cloud_functions_helper.dart';

class PrivateMediaUrlResult {
  const PrivateMediaUrlResult({required this.url, required this.expiresAt});
  final String url;
  final int expiresAt;
}

class PrivateMediaUrlService {
  PrivateMediaUrlService({
    String? Function()? currentUid,
    Stream<String?> Function()? authChanges,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? invoke,
  }) : _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _authChanges =
           authChanges ??
           (() => FirebaseAuth.instance.authStateChanges().map(
             (user) => user?.uid,
           )),
       _invoke = invoke ?? _invokeCallable;

  final String? Function() _currentUid;
  final Stream<String?> Function() _authChanges;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) _invoke;

  static Future<Map<String, dynamic>> _invokeCallable(
    Map<String, dynamic> payload,
  ) async {
    // Chuẩn bị App Check trước khi xin link; làm mới và thử lại một lần
    // nếu máy chủ từ chối token, như các callable bảo vệ khác trong app.
    final result = await CloudFunctionsHelper.callSecure<Map<String, dynamic>>(
      'resolveHouseMediaUrlSecure',
      payload: payload,
      timeout: const Duration(seconds: 20),
      requireAppCheck: true,
      throwOriginalException: true,
    );
    return result.data;
  }

  Future<PrivateMediaUrlResult> resolve({
    required String houseId,
    required String mediaId,
    required String kind,
  }) async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
    }
    final normalizedHouseId = houseId.trim();
    final normalizedMediaId = mediaId.trim();
    final normalizedKind = kind.trim();
    bool validId(String value) =>
        value.isNotEmpty &&
        value.length <= 128 &&
        !RegExp(r'[.#$\[\]/\\\s\x00-\x1f\x7f]').hasMatch(value);
    if (!validId(normalizedHouseId) ||
        !validId(normalizedMediaId) ||
        !const {
          'memory_image',
          'album_image',
          'voice',
        }.contains(normalizedKind)) {
      throw FirebaseFunctionsException(code: 'invalid-argument', message: '');
    }
    var sessionChanged = false;
    final subscription = _authChanges().listen(
      (nextUid) {
        if (nextUid != uid) sessionChanged = true;
      },
      onError: (Object _) {
        sessionChanged = true;
      },
    );
    try {
      final data = await _invoke({
        'houseId': normalizedHouseId,
        'mediaId': normalizedMediaId,
        'kind': normalizedKind,
      });
      if (sessionChanged || uid != _currentUid()) {
        throw FirebaseFunctionsException(code: 'unauthenticated', message: '');
      }
      final url = data['url']?.toString().trim() ?? '';
      final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
      final uri = Uri.tryParse(url);
      if (data['ok'] != true ||
          data['kind'] != normalizedKind ||
          data['mediaId'] != normalizedMediaId ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        throw FirebaseFunctionsException(code: 'unavailable', message: '');
      }
      return PrivateMediaUrlResult(url: url, expiresAt: expiresAt);
    } on FirebaseFunctionsException catch (error) {
      // Không chuyển message/details có thể chứa bearer URL ra UI hoặc log.
      throw FirebaseFunctionsException(code: error.code, message: '');
    } catch (_) {
      throw FirebaseFunctionsException(code: 'unavailable', message: '');
    } finally {
      await subscription.cancel();
    }
  }
}
