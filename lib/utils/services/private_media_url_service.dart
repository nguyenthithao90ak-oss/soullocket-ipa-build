import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivateMediaUrlResult {
  const PrivateMediaUrlResult({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final int expiresAt;
}

class PrivateMediaUrlService {
  PrivateMediaUrlService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<User?> _waitForCurrentUser() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }
    try {
      return auth.authStateChanges().firstWhere(
            (user) => user != null,
          ).timeout(const Duration(seconds: 3));
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
    if (user == null) {
      throw Exception('Vui lòng đăng nhập lại để xem nội dung này.');
    }
    await user.getIdToken(true);

    final callable = _functions.httpsCallable('resolvePrivateMediaUrl');
    final response = await callable.call(<String, dynamic>{
      'houseId': houseId.trim(),
      'mediaId': mediaId.trim(),
      'kind': kind.trim(),
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final url = data['url']?.toString().trim() ?? '';
    final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
    if (url.isEmpty || expiresAt <= 0) {
      throw Exception('Không lấy được liên kết media tạm thời.');
    }
    return PrivateMediaUrlResult(url: url, expiresAt: expiresAt);
  }
}
