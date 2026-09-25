import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../private_media_url_service.dart';

/// Tải theo quyền hiện hành, không đọc/ghi cache chung và không theo redirect.
class PrivateMemoryDownloadHelper {
  const PrivateMemoryDownloadHelper();

  Future<({Uint8List bytes, String url})> download({
    required Future<PrivateMediaUrlResult> Function() resolve,
    required http.Client client,
    required String? Function() currentUid,
    required Stream<String?> authChanges,
    required bool Function() scopeIsCurrent,
    int maxBytes = 100 * 1024 * 1024,
  }) async {
    final uid = currentUid();
    var changed = false;
    final auth = authChanges.listen(
      (next) {
        if (next != uid) {
          changed = true;
        }
      },
      onError: (Object _) {
        changed = true;
      },
    );
    Never fail(String code) =>
        throw FirebaseFunctionsException(code: code, message: '');
    void guard() {
      if (uid == null || changed || currentUid() != uid) {
        fail('unauthenticated');
      }
      if (!scopeIsCurrent()) {
        fail('cancelled');
      }
    }

    try {
      guard();
      final signed = await resolve();
      guard();
      final uri = Uri.tryParse(signed.url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          signed.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        fail('unavailable');
      }
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      guard();
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxBytes) {
        fail('unavailable');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        guard();
        if (bytes.length + chunk.length > maxBytes) {
          fail('resource-exhausted');
        }
        bytes.add(chunk);
      }
      guard();
      if (bytes.isEmpty ||
          (response.contentLength != null &&
              bytes.length != response.contentLength)) {
        fail('unavailable');
      }
      // Quyền có thể bị thu hồi trong lúc tải; không lưu ra thư viện trước khi kiểm tra lại.
      await resolve();
      guard();
      return (bytes: bytes.takeBytes(), url: signed.url);
    } on FirebaseFunctionsException catch (error) {
      fail(error.code);
    } catch (_) {
      fail('unavailable');
    } finally {
      await auth.cancel();
    }
  }
}
