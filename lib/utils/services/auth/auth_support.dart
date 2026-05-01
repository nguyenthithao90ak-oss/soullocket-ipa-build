import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_config.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/flexible_date_input.dart';

typedef SharedPreferencesProvider = Future<SharedPreferences> Function();
typedef NowProvider = DateTime Function();
typedef GoogleSignInBuilder = GoogleSignIn Function();
typedef HttpGet = Future<http.Response> Function(Uri uri);
typedef HttpPost = Future<http.Response> Function(
  Uri uri, {
  Map<String, String>? headers,
  Object? body,
});

firebase_auth.ActionCodeSettings buildPasswordResetActionCodeSettings() {
  return firebase_auth.ActionCodeSettings(
    url: AppConfig.webResetPasswordUrl,
    handleCodeInApp: true,
    androidPackageName: AppConfig.androidPackageName,
    androidInstallApp: false,
    iOSBundleId: AppConfig.iOSBundleId,
  );
}

String normalizeEmailKey(String email) {
  return email.trim().toLowerCase().replaceAll('.', ',');
}

String normalizeSecurityEmail(String email) {
  return email.trim().toLowerCase();
}

String relationshipModePrefsKey(String email) {
  return 'il_rel_mode_${normalizeEmailKey(email)}';
}

String? normalizeRelationshipMode(String? value) {
  final mode = value?.trim().toLowerCase();
  if (mode == 'single' || mode == 'couple') {
    return mode;
  }
  return null;
}

bool hasAdminClaim(Map<String, dynamic>? claims) {
  if (claims == null) return false;
  final dynamic adminClaim = claims['admin'];
  if (adminClaim == true || adminClaim == 'true' || adminClaim == 1) {
    return true;
  }
  final role = (claims['admin_role'] ?? claims['role'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  return role == 'admin' || role == 'super_admin';
}

bool isGoogleSignInConfigMismatch(Object error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('sign_in_failed') ||
      raw.contains('apiexception: 10') ||
      raw.contains('api exception: 10') ||
      raw.contains('statuscode=10') ||
      raw.contains('developer_error');
}

bool isGoogleSignInNetworkIssue(Object error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('network_error') ||
      raw.contains('network-request-failed');
}

bool isFacebookSignInConfigMismatch(Object error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('invalid_key_hash') ||
      raw.contains('key hash') ||
      raw.contains('app not set up') ||
      raw.contains("app isn't available") ||
      raw.contains('sorry, something went wrong') ||
      raw.contains("we're working on it") ||
      raw.contains('we are working on it') ||
      raw.contains('error validating application') ||
      raw.contains('redirect_uri') ||
      raw.contains('application is misconfigured') ||
      raw.contains('facebook app id') ||
      raw.contains('facebook app secret') ||
      raw.contains('login for this app is currently disabled') ||
      raw.contains('operation-not-allowed') ||
      raw.contains('provider is not enabled') ||
      (raw.contains('facebook.com') && raw.contains('not enabled'));
}

bool isFacebookSignInNetworkIssue(Object error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('network_error') ||
      raw.contains('network-request-failed') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection reset') ||
      raw.contains('socketexception');
}

String normalizeFacebookLoginFailureMessage(String? message) {
  final cleaned = AppErrorMapper.cleanMessage(message);
  final normalized = cleaned.toLowerCase();
  if (normalized.contains('sorry, something went wrong') ||
      normalized.contains("we're working on it") ||
      normalized.contains('we are working on it')) {
    return 'Cấu hình đăng nhập Facebook chưa khớp. '
        'Nếu đang test Android, hãy kiểm tra đúng package name ${AppConfig.androidPackageName} '
        'và thêm Facebook Key Hash của máy build này vào Meta Developer. '
        'Đồng thời kiểm tra Firebase Authentication đã bật Facebook và điền đúng App ID/App Secret.';
  }
  if (isFacebookSignInConfigMismatch(cleaned)) {
    return 'Cấu hình đăng nhập Facebook chưa khớp. '
        'Nếu đang test bản debug, hãy thêm Facebook Key Hash của máy build này vào Facebook Developer. '
        'Đồng thời kiểm tra Firebase Authentication đã bật Facebook và điền đúng App ID/App Secret.';
  }
  if (isFacebookSignInNetworkIssue(cleaned)) {
    return 'Mạng đang lỗi hoặc bị chặn, chưa thể đăng nhập Facebook lúc này.';
  }
  if (cleaned.isNotEmpty) {
    return cleaned;
  }
  return 'Đăng nhập Facebook thất bại.';
}

String handleFirebaseAuthError(firebase_auth.FirebaseAuthException error) {
  switch (error.code) {
    case 'user-not-found':
      return 'Tài khoản không tồn tại.';
    case 'wrong-password':
      return 'Sai mật khẩu. Vui lòng thử lại.';
    case 'invalid-credential':
      return 'Thông tin đăng nhập không đúng. Vui lòng kiểm tra lại.';
    case 'invalid-email':
      return 'Định dạng email không hợp lệ.';
    case 'email-already-in-use':
      return 'Email này đã có tài khoản. Hãy chuyển sang tab Đăng nhập hoặc dùng Quên mật khẩu nếu bạn không nhớ mật khẩu.';
    case 'weak-password':
      return 'Mật khẩu quá yếu. Vui lòng nhập ít nhất 6 ký tự.';
    case 'too-many-requests':
      return 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.';
    default:
      final cleanedMessage = AppErrorMapper.cleanMessage(error.message);
      if (_shouldSurfaceRawAuthMessage(cleanedMessage)) {
        return cleanedMessage;
      }
      return AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Máy chủ xác thực đang bận hoặc gặp sự cố. Vui lòng thử lại sau.',
      ).message;
  }
}

bool _shouldSurfaceRawAuthMessage(String message) {
  if (message.isEmpty || message.length > 220) {
    return false;
  }

  final normalized = message.toLowerCase();
  if (normalized.contains('firebase') ||
      normalized.contains('www.googleapis.com') ||
      normalized.contains('configuration_not_found') ||
      normalized.contains('internal error has occurred') ||
      normalized.contains('api key')) {
    return false;
  }

  return normalized.contains('vui long') ||
      normalized.contains('tai khoan') ||
      normalized.contains('dang ky') ||
      normalized.contains('email') ||
      normalized.contains('thiet bi') ||
      normalized.contains('mang nay');
}

String maskEmail(String email) {
  if (email.isEmpty) return '';
  final parts = email.split('@');
  if (parts.length != 2) return email;

  final namePart = parts[0];
  final domainPart = parts[1];

  if (namePart.length <= 4) {
    return '${namePart[0]}${'*' * (namePart.length - 1)}@$domainPart';
  }

  final firstTwo = namePart.substring(0, 2);
  final lastTwo = namePart.substring(namePart.length - 2);
  final stars = '*' * (namePart.length - 4);
  return '$firstTwo$stars$lastTwo@$domainPart';
}

bool matchesRecoveryAnswer(String? storedAnswer, String inputAnswer) {
  if (storedAnswer == null || storedAnswer.trim().isEmpty) return false;
  final inputCandidates = DateInputUtils.recoveryAnswerCandidates(inputAnswer);
  if (inputCandidates.isEmpty) return false;
  final normalizedStored = storedAnswer.trim().toLowerCase();
  final looksHashed = RegExp(r'^[a-f0-9]{64}$').hasMatch(normalizedStored);
  if (looksHashed) {
    return inputCandidates.any(
      (candidate) => normalizedStored == _sha256Hex(candidate),
    );
  }
  return inputCandidates.contains(normalizedStored);
}

String hashRecoveryAnswer(String input) {
  return _sha256Hex(DateInputUtils.canonicalRecoveryAnswer(input));
}

String hashHousePin(String input) {
  return _sha256Hex(input.trim());
}

String _sha256Hex(String input) {
  final bytes = Uint8List.fromList(utf8.encode(input));
  final digest = SHA256Digest().process(bytes);
  final buffer = StringBuffer();
  for (final value in digest) {
    buffer.write(value.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
