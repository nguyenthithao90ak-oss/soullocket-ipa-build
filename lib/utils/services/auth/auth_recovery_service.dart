import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'auth_support.dart' as auth_support;
import '../core/cloud_functions_helper.dart';

class AuthRecoveryService {
  AuthRecoveryService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    DatabaseReference? databaseRef,
    FirebaseFunctions? firebaseFunctions,
  })  : _firebaseAuth = firebaseAuth,
        _databaseRef = databaseRef;

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final DatabaseReference? _databaseRef;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  DatabaseReference get _db => _databaseRef ?? FirebaseDatabase.instance.ref();

  Map<String, dynamic>? _asStringDynamicMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static const Duration _appCheckRetryDelay = Duration(milliseconds: 350);

  bool _isAppCheckFailure(
    FirebaseFunctionsException error, {
    bool allowUnauthenticatedWithoutMarkers = false,
  }) {
    final code = error.code.trim().toLowerCase();
    final isPossibleAppCheckCode = code == 'failed-precondition' ||
        code == 'permission-denied' ||
        code == 'unauthenticated';
    if (!isPossibleAppCheckCode) {
      return false;
    }

    final message =
        '${error.message ?? ''} ${error.details ?? ''}'.trim().toLowerCase();

    const appCheckMarkers = <String>[
      'app check',
      'appcheck',
      'debug token',
      'play integrity',
      'attestation',
      'firebase app check api',
      'x-firebase-appcheck',
      'recaptcha',
      'app attest',
      'device check',
      'missing appcheck token',
      'invalid appcheck token',
    ];
    final hasAppCheckMarker = appCheckMarkers.any(message.contains);
    if (hasAppCheckMarker) {
      return true;
    }

    if (!allowUnauthenticatedWithoutMarkers || code != 'unauthenticated') {
      return false;
    }

    const authRequiredMarkers = <String>[
      'user must be authenticated',
      'must be authenticated',
      'requires authentication',
      'requires login',
      'requires sign in',
      'dang nhap',
      'đăng nhập',
      'sign in again',
      'login again',
    ];
    return !authRequiredMarkers.any(message.contains);
  }

  Future<bool> _warmUpAppCheck({bool forceRefresh = false}) async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      return (token ?? '').trim().isNotEmpty;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AuthRecoveryService App Check warm-up failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể chuẩn bị App Check.',
        ).message}');
      }
    }
    return false;
  }

  Future<void> _refreshCurrentUserSession({
    bool forceRefreshIdToken = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await user.reload();
    } catch (_) {}

    if (!forceRefreshIdToken) {
      return;
    }

    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {}
  }

  Future<T> _callOtpFunction<T>(
    Future<T> Function() action, {
    bool allowUnauthenticatedWithoutMarkers = false,
  }) async {
    await _warmUpAppCheck();
    try {
      return await action();
    } on FirebaseFunctionsException catch (error) {
      if (!_isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: allowUnauthenticatedWithoutMarkers,
      )) {
        rethrow;
      }

      final refreshed = await _warmUpAppCheck(forceRefresh: true);
      if (refreshed) {
        await Future<void>.delayed(_appCheckRetryDelay);
      }
      return await action();
    }
  }

  String _messageFromFunctionsError(
    FirebaseFunctionsException error, {
    required String fallbackMessage,
    String? permissionDeniedMessage,
    String? deadlineExceededMessage,
    String? failedPreconditionMessage,
    String? resourceExhaustedMessage,
    String? unauthenticatedMessage,
    String? invalidArgumentMessage,
    String? appCheckMessage,
    bool allowUnauthenticatedWithoutMarkers = false,
  }) {
    if (_isAppCheckFailure(
      error,
      allowUnauthenticatedWithoutMarkers: allowUnauthenticatedWithoutMarkers,
    )) {
      return appCheckMessage ??
          AppErrorMapper.resolve(
            error,
            fallbackMessage: fallbackMessage,
          ).message;
    }

    switch (error.code) {
      case 'permission-denied':
        return permissionDeniedMessage ??
            error.message ??
            'Mã OTP không đúng. Vui lòng kiểm tra lại.';
      case 'deadline-exceeded':
        return deadlineExceededMessage ??
            error.message ??
            'Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.';
      case 'failed-precondition':
        return failedPreconditionMessage ??
            error.message ??
            'Email OTP không khớp email chính của tài khoản hiện tại.';
      case 'resource-exhausted':
        return resourceExhaustedMessage ??
            error.message ??
            'Bạn đã nhập sai OTP quá nhiều lần. Vui lòng thử lại sau.';
      case 'unauthenticated':
        return unauthenticatedMessage ??
            'Bạn cần đăng nhập lại trước khi xác thực email chính.';
      case 'invalid-argument':
        return invalidArgumentMessage ??
            error.message ??
            'Thiếu email hoặc mã OTP.';
      default:
        return error.message ?? fallbackMessage;
    }
  }

  Future<Map<String, dynamic>?> getHouseSecurityData(String houseId) async {
    try {
      final snapshot = await _db.child('houses/$houseId').get();
      if (!snapshot.exists) return null;
      final data = _asStringDynamicMap(snapshot.value);
      if (data == null) {
        return null;
      }

      final security =
          _asStringDynamicMap(data['security']) ?? <String, dynamic>{};
      final recovery =
          _asStringDynamicMap(security['recovery']) ?? <String, dynamic>{};
      final question = (recovery['question'] ??
              data['recovery_q'] ??
              security['question'] ??
              '')
          .toString()
          .trim();
      final answerHash = (recovery['answerHash'] ??
              data['recovery_a'] ??
              security['answer'] ??
              security['answerHash'] ??
              '')
          .toString()
          .trim();
      if (question.isNotEmpty) {
        security['question'] = question;
      }
      if (answerHash.isNotEmpty) {
        security['answer'] = answerHash;
        security['answerHash'] = answerHash;
      }
      if (question.isNotEmpty || answerHash.isNotEmpty) {
        security['recovery'] = {
          ...recovery,
          if (question.isNotEmpty) 'question': question,
          if (answerHash.isNotEmpty) 'answerHash': answerHash,
        };
      }
      if (data['email'] != null && security['email'] == null) {
        security['email'] = data['email'];
      }
      final backupEmail =
          (security['backupEmail'] ?? security['secondaryEmail'] ?? '')
              .toString()
              .trim();
      if (backupEmail.isNotEmpty) {
        security['backupEmail'] = backupEmail;
        security['secondaryEmail'] = backupEmail;
      }

      return security;
    } catch (_) {
      return null;
    }
  }

  String maskEmail(String email) => auth_support.maskEmail(email);

  Future<String?> findEmailByHouseId(String houseId) async {
    try {
      final securitySnap =
          await _db.child('houses/$houseId/security/email').get();
      final securityEmail = securitySnap.value?.toString().trim();
      if (securityEmail != null && securityEmail.isNotEmpty) {
        return securityEmail;
      }
      final snapshot = await _db.child('houses/$houseId/email').get();
      final email = snapshot.value?.toString().trim();
      return (email == null || email.isEmpty) ? null : email;
    } catch (_) {
      return null;
    }
  }

  Future<bool> verifySecurityAnswer(String houseId, String answer) async {
    try {
      final security = await getHouseSecurityData(houseId);
      final storedAnswer =
          (security?['answerHash'] ?? security?['answer'])?.toString();
      return matchesRecoveryAnswer(storedAnswer, answer);
    } catch (_) {
      return false;
    }
  }

  bool matchesRecoveryAnswer(String? storedAnswer, String inputAnswer) {
    return auth_support.matchesRecoveryAnswer(storedAnswer, inputAnswer);
  }

  Future<bool> verifyPin(String houseId, String pin) async {
    try {
      final result = await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'verifyHousePin',
          payload: {
            'houseId': houseId.trim(),
            'pin': pin.trim(),
          },
          throwOriginalException: true,
        ),
      );
      final rawData = result.data;
      if (rawData is! Map) {
        return false;
      }
      final data = Map<String, dynamic>.from(rawData);
      return data['success'] == true;
    } on FirebaseFunctionsException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: auth_support.buildPasswordResetActionCodeSettings(),
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-email':
          throw 'Email khôi phục không hợp lệ.';
        case 'missing-email':
          throw 'Vui lòng nhập email để nhận link khôi phục.';
        case 'user-not-found':
          throw 'Không tìm thấy tài khoản ứng với email này.';
        case 'network-request-failed':
          throw 'Không thể kết nối mạng để gửi link khôi phục.';
        case 'too-many-requests':
          throw 'Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau ít phút.';
        default:
          throw auth_support.handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không gửi được link khôi phục: hãy kiểm tra email, kết nối mạng và cấu hình Firebase Auth.',
      ).message;
    }
  }

  Future<void> sendOtpEmail(String email) async {
    try {
      final deviceId = await SecurityService().getDeviceId();
      await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'requestEmailOTP',
          payload: {
            'email': email.trim(),
            if (deviceId.trim().isNotEmpty) 'deviceId': deviceId.trim(),
          },
          throwOriginalException: true,
        ),
        allowUnauthenticatedWithoutMarkers: true,
      );
    } catch (error) {
      if (error is FirebaseFunctionsException) {
        throw _messageFromFunctionsError(
          error,
          fallbackMessage: 'Không gửi được mã xác nhận.',
          permissionDeniedMessage: 'Yêu cầu bị từ chối. Thử lại sau.',
          failedPreconditionMessage:
              'Máy chủ OTP chưa được cấu hình xong.',
          resourceExhaustedMessage:
              'Bạn yêu cầu mã quá nhiều lần. Hãy chờ rồi thử lại.',
          unauthenticatedMessage:
              'Phiên bảo mật chưa sẵn sàng. Mở lại app rồi thử lại.',
          invalidArgumentMessage: 'Email không hợp lệ hoặc thiếu email.',
          appCheckMessage: kDebugMode
              ? 'App Check chưa sẵn sàng. Chờ vài giây rồi thử lại.'
              : 'Phiên bảo mật chưa sẵn sàng. Chờ vài giây rồi thử lại.',
          allowUnauthenticatedWithoutMarkers: true,
        );
      }
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không gửi được mã xác nhận.',
      ).message;
    }
  }

  Future<String> verifyOtpAndGetToken(String email, String otp) async {
    try {
      final result = await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'verifyEmailOTP',
          payload: {
            'email': email.trim(),
            'otp': otp.trim(),
          },
          throwOriginalException: true,
        ),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final rawData = result.data;
      if (rawData is! Map) {
        throw 'Phản hồi từ máy chủ không hợp lệ (Type mismatch).';
      }
      final data = Map<String, dynamic>.from(rawData);
      if (data['success'] == true) {
        final token = data['customToken'];
        if (token == null || token.toString().isEmpty) {
          throw 'Hệ thống không trả về mã đăng nhập hợp lệ.';
        }
        return token.toString();
      }
      throw data['message'] ?? 'Mã không hợp lệ hoặc đã hết hạn.';
    } catch (error) {
      if (error is FirebaseFunctionsException) {
        throw _messageFromFunctionsError(
          error,
          fallbackMessage:
              'Không xác nhận được mã OTP: hãy kiểm tra mã vừa nhập, thời hạn mã và kết nối mạng.',
          appCheckMessage: kDebugMode
              ? 'Phiên App Check chưa sẵn sàng. Vui lòng chờ vài giây rồi thử xác nhận lại.'
              : 'Phiên bảo mật chưa sẵn sàng. Hãy chờ vài giây rồi xác nhận lại.',
          allowUnauthenticatedWithoutMarkers: true,
        );
      }
      if (error is String) rethrow;
      throw 'Không xác nhận được mã OTP: máy chủ không trả về chi tiết lỗi, hãy kiểm tra mã và thử lại.';
    }
  }

  Future<void> verifyPrimaryEmailOTP(String email, String otp) async {
    final normalizedEmail = auth_support.normalizeSecurityEmail(email);
    try {
      await _refreshCurrentUserSession(forceRefreshIdToken: true);

      final currentEmail =
          auth_support.normalizeSecurityEmail(_auth.currentUser?.email ?? '');
      if (currentEmail.isEmpty) {
        throw 'Không tìm thấy email chính của tài khoản hiện tại.';
      }
      if (currentEmail != normalizedEmail) {
        throw 'Email OTP không khớp email chính của tài khoản hiện tại.';
      }

      final result = await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'verifyPrimaryEmailOTP',
          payload: {
            'email': normalizedEmail,
            'otp': otp.trim(),
          },
          throwOriginalException: true,
        ),
      );
      final data = _asStringDynamicMap(result.data);
      if (data == null) {
        throw 'Không xác thực được email chính: máy chủ không trả về dữ liệu hợp lệ.';
      }
      if (data['success'] != true) {
        throw 'Không xác thực được email chính: email hoặc mã xác thực không hợp lệ.';
      }
    } catch (error) {
      if (error is FirebaseFunctionsException) {
        throw _messageFromFunctionsError(
          error,
          fallbackMessage:
              'Không xác thực được email chính: hãy kiểm tra email, mã xác thực và kết nối mạng.',
          appCheckMessage: kDebugMode
              ? 'Phiên App Check chưa sẵn sàng. Vui lòng chờ vài giây rồi thử lại.'
              : 'Phiên bảo mật chưa sẵn sàng. Hãy chờ vài giây rồi thử lại.',
        );
      }
      if (error is String) rethrow;
      throw 'Không xác thực được email chính: máy chủ không trả về chi tiết lỗi.';
    }
  }

  Future<void> validateEmailOTP(String email, String otp) async {
    try {
      final result = await _callOtpFunction(
        () => CloudFunctionsHelper.callSecure<dynamic>(
          'validateEmailOTP',
          payload: {
            'email': email.trim(),
            'otp': otp.trim(),
          },
          throwOriginalException: true,
        ),
        allowUnauthenticatedWithoutMarkers: true,
      );
      final data = _asStringDynamicMap(result.data);
      if (data == null) {
        throw 'Mã không hợp lệ hoặc đã hết hạn.';
      }
      if (data['success'] != true) {
        throw 'Mã không hợp lệ hoặc đã hết hạn.';
      }
    } catch (error) {
      if (error is FirebaseFunctionsException) {
        throw _messageFromFunctionsError(
          error,
          fallbackMessage: 'Mã không hợp lệ hoặc đã hết hạn.',
          appCheckMessage: kDebugMode
              ? 'Phiên App Check chưa sẵn sàng. Vui lòng chờ vài giây rồi thử lại.'
              : 'Phiên bảo mật chưa sẵn sàng. Hãy chờ vài giây rồi thử lại.',
          allowUnauthenticatedWithoutMarkers: true,
        );
      }
      throw 'Mã không hợp lệ hoặc đã hết hạn.';
    }
  }

  Future<void> signInWithCustomTokenAndSetPassword(
    String token,
    String newPassword,
  ) async {
    final userCredential = await _auth.signInWithCustomToken(token);
    final user = userCredential.user;
    if (user != null) {
      final hasPasswordProvider = user.providerData
          .any((provider) => provider.providerId == 'password');
      if (hasPasswordProvider) {
        await user.updatePassword(newPassword);
        return;
      }

      final email = user.email?.trim() ?? '';
      if (email.isEmpty) {
        throw 'Tài khoản hiện tại chưa có email nên chưa thể tạo mật khẩu đăng nhập.';
      }

      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: newPassword.trim(),
      );
      await user.linkWithCredential(credential);
      return;
    }
    throw 'Đăng nhập không thành công bằng mã OTP.';
  }

  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await _auth.verifyPasswordResetCode(code.trim());
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-action-code':
          throw 'Link đặt lại mật khẩu không hợp lệ. Có thể bạn đã mở nhầm email cũ.';
        case 'expired-action-code':
          throw 'Link đặt lại mật khẩu đã hết hạn. Hãy yêu cầu email mới nhất rồi thử lại.';
        case 'user-disabled':
          throw 'Tài khoản này đã bị vô hiệu hóa nên chưa thể đặt lại mật khẩu.';
        case 'user-not-found':
          throw 'Không tìm thấy tài khoản cho link đặt lại mật khẩu này.';
        default:
          throw auth_support.handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không kiểm tra được link đặt lại mật khẩu: link có thể hết hạn, sai mã hoặc mạng đang lỗi.',
      ).message;
    }
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(
        code: code.trim(),
        newPassword: newPassword,
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-action-code':
          throw 'Link đặt lại mật khẩu không hợp lệ. Có thể bạn đã mở nhầm email cũ.';
        case 'expired-action-code':
          throw 'Link đặt lại mật khẩu đã hết hạn. Hãy yêu cầu email mới nhất rồi thử lại.';
        case 'weak-password':
          throw 'Mật khẩu mới quá yếu. Hãy dùng ít nhất 6 ký tự.';
        case 'user-disabled':
          throw 'Tài khoản này đã bị vô hiệu hóa nên chưa thể đặt lại mật khẩu.';
        case 'user-not-found':
          throw 'Không tìm thấy tài khoản cho link đặt lại mật khẩu này.';
        default:
          throw auth_support.handleFirebaseAuthError(error);
      }
    } catch (error) {
      if (error is String) rethrow;
      throw AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không cập nhật được mật khẩu mới: hãy kiểm tra link đặt lại, độ mạnh mật khẩu và kết nối mạng.',
      ).message;
    }
  }

  String hashRecoveryAnswer(String input) {
    return auth_support.hashRecoveryAnswer(input);
  }

  String hashHousePin(String input) {
    return auth_support.hashHousePin(input);
  }
}
