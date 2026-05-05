import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';

enum AppErrorKind { user, network, server }

class AppErrorInfo {
  final AppErrorKind kind;
  final String message;

  const AppErrorInfo({
    required this.kind,
    required this.message,
  });

  bool get isUserError => kind == AppErrorKind.user;
  bool get isNetworkError => kind == AppErrorKind.network;
  bool get isServerError => kind == AppErrorKind.server;
}

class AppErrorMapper {
  static const String defaultNetworkMessage =
      'Không thể kết nối mạng. Vui lòng kiểm tra Wi‑Fi hoặc dữ liệu di động rồi thử lại.';
  static const String defaultServerMessage =
      'Máy chủ đang bận hoặc gặp sự cố. Vui lòng thử lại sau.';
  static const String authSyncMessage =
      'Phiên đăng nhập đang đồng bộ. Vui lòng chờ vài giây rồi thử lại.';
  static const String recentLoginMessage =
      'Đã lâu bạn chưa ghé, đăng nhập lại để tiếp tục viết tiếp chuyện tình mình nhé! 👋';

  static AppErrorInfo resolve(
    dynamic error, {
    String? fallbackMessage,
  }) {
    if (error is AppErrorInfo) {
      return error;
    }

    if (error is firebase_auth.FirebaseAuthException) {
      return _fromFirebaseAuth(error);
    }

    if (error is FirebaseException) {
      return _fromFirebase(error, fallbackMessage: fallbackMessage);
    }

    if (error is TimeoutException) {
      return const AppErrorInfo(
        kind: AppErrorKind.network,
        message:
            'Kết nối mạng quá chậm hoặc đã hết thời gian chờ. Vui lòng kiểm tra mạng rồi thử lại.',
      );
    }

    final message = cleanMessage(error);

    if (_looksLikeNetwork(message)) {
      return AppErrorInfo(
        kind: AppErrorKind.network,
        message: _normalizeNetworkMessage(message),
      );
    }

    if (_looksLikeUser(message)) {
      return AppErrorInfo(
        kind: AppErrorKind.user,
        message: _normalizeUserMessage(message),
      );
    }

    if (_looksLikeServer(message)) {
      return AppErrorInfo(
        kind: AppErrorKind.server,
        message: _normalizeServerMessage(
          message,
          fallbackMessage: fallbackMessage,
        ),
      );
    }

    return AppErrorInfo(
      kind: AppErrorKind.server,
      message: fallbackMessage ?? defaultServerMessage,
    );
  }

  static String cleanMessage(dynamic error) {
    final value = error?.toString() ?? '';
    return value
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Error:\s*'), '')
        .replaceFirst(RegExp(r'^\[firebase_auth\/[^\]]+\]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool shouldOfferPasswordRecovery(dynamic error) {
    final message = cleanMessage(error).toLowerCase();
    return message.contains('mật khẩu không chính xác') ||
        message.contains('sai mật khẩu') ||
        message.contains('thông tin đăng nhập không đúng') ||
        message.contains('wrong-password') ||
        message.contains('invalid-credential') ||
        message.contains('invalid login credentials') ||
        message.contains(
            'tài khoản chưa được đăng ký hoặc mật khẩu không chính xác');
  }

  static AppErrorInfo _fromFirebaseAuth(
    firebase_auth.FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'network-request-failed':
        return const AppErrorInfo(
          kind: AppErrorKind.network,
          message: defaultNetworkMessage,
        );
      case 'too-many-requests':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message:
              'Bạn đã thử quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.',
        );
      case 'user-not-found':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message:
              'Tài khoản không tồn tại. Vui lòng kiểm tra lại email hoặc tạo tài khoản mới.',
        );
      case 'wrong-password':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message: 'Mã này chưa đúng rồi, nhớ lại một chút hoặc thử mã khác xem sao nhé! 🔒',
        );
      case 'invalid-credential':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message: 'Thông tin chưa đúng nè, kiểm tra kỹ lại một xíu nha! ✨',
        );
      case 'invalid-email':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message: 'Định dạng email không hợp lệ.',
        );
      case 'email-already-in-use':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message: 'Email này đã được sử dụng.',
        );
      case 'weak-password':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message: 'Mật khẩu này hơi dễ đoán nè, nhập ít nhất 6 ký tự để an toàn hơn nha! 💪',
        );
      case 'popup-closed-by-user':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message: 'Bạn đã đóng cửa sổ đăng nhập.',
        );
      case 'popup-blocked':
      case 'cancelled-popup-request':
        return const AppErrorInfo(
          kind: AppErrorKind.user,
          message:
              'Trình duyệt đang chặn cửa sổ đăng nhập. Vui lòng cho phép popup rồi thử lại.',
        );
      default:
        return AppErrorInfo(
          kind: AppErrorKind.server,
          message: _normalizeServerMessage(
            cleanMessage(error.message),
            fallbackMessage:
                'Máy chủ xác thực đang bận hoặc gặp sự cố. Vui lòng thử lại sau.',
          ),
        );
    }
  }

  static AppErrorInfo _fromFirebase(
    FirebaseException error, {
    String? fallbackMessage,
  }) {
    final code = error.code.toLowerCase();
    final message = cleanMessage(error.message);

    if (code == 'requires-recent-login') {
      return const AppErrorInfo(
        kind: AppErrorKind.user,
        message: recentLoginMessage,
      );
    }

    if (code == 'unauthenticated') {
      return const AppErrorInfo(
        kind: AppErrorKind.network,
        message: authSyncMessage,
      );
    }

    if (code == 'network-request-failed' ||
        code == 'deadline-exceeded' ||
        code == 'timed-out') {
      return const AppErrorInfo(
        kind: AppErrorKind.network,
        message:
            'Kết nối mạng quá chậm hoặc bị gián đoạn. Vui lòng kiểm tra mạng rồi thử lại.',
      );
    }

    if (code == 'permission-denied' ||
        code == 'unavailable' ||
        code == 'internal' ||
        code == 'internal-error') {
      final cleanMsg = _normalizeServerMessage(
        message,
        fallbackMessage: fallbackMessage,
      );
      if (code == 'permission-denied' && (cleanMsg.isEmpty || cleanMsg == defaultServerMessage)) {
        return const AppErrorInfo(
          kind: AppErrorKind.server,
          message: 'Chỗ này cần bạn cấp quyền một xíu để mình phục vụ tốt hơn nè! 🔑',
        );
      }
      return AppErrorInfo(
        kind: AppErrorKind.server,
        message: cleanMsg,
      );
    }

    if (_looksLikeNetwork(message)) {
      return AppErrorInfo(
        kind: AppErrorKind.network,
        message: _normalizeNetworkMessage(message),
      );
    }

    return AppErrorInfo(
      kind: AppErrorKind.server,
      message: _normalizeServerMessage(
        message,
        fallbackMessage: fallbackMessage,
      ),
    );
  }

  static bool _looksLikeNetwork(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('network-request-failed') ||
        normalized.contains('network error') ||
        normalized.contains('network_error') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection reset') ||
        normalized.contains('connection aborted') ||
        normalized.contains('socketexception') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('quá thời gian') ||
        normalized.contains('mất kết nối') ||
        normalized.contains('không có mạng') ||
        normalized.contains('kiểm tra mạng') ||
        normalized.contains('không thể kết nối mạng') ||
        normalized.contains('lỗi kết nối') ||
        normalized.contains('kết nối mạng');
  }

  static bool _looksLikeUser(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('vui lòng nhập') ||
        normalized.contains('không được để trống') ||
        normalized.contains('không hợp lệ') ||
        normalized.contains('không chính xác') ||
        normalized.contains('không tồn tại') ||
        normalized.contains('đã được sử dụng') ||
        normalized.contains('mật khẩu quá yếu') ||
        normalized.contains('too-many-requests') ||
        normalized.contains('user-not-found') ||
        normalized.contains('wrong-password') ||
        normalized.contains('invalid-credential') ||
        normalized.contains('invalid-email') ||
        normalized.contains('weak-password') ||
        normalized.contains('email-already-in-use') ||
        normalized.contains('unauthenticated') ||
        normalized.contains('requires-recent-login') ||
        normalized.contains('phiên đăng nhập') ||
        normalized.contains('đăng nhập để tạo liên kết') ||
        normalized.contains('bạn đã đóng cửa sổ đăng nhập') ||
        normalized.contains('chặn cửa sổ đăng nhập') ||
        normalized.contains('không có quyền xóa bài viết này');
  }

  static bool _looksLikeServer(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('permission-denied') ||
        normalized.contains('app check') ||
        normalized.contains('appcheck') ||
        normalized.contains('debug token') ||
        normalized.contains('play integrity') ||
        normalized.contains('attestation') ||
        normalized.contains('firebase app check api') ||
        normalized.contains('server') ||
        normalized.contains('máy chủ') ||
        normalized.contains('internal') ||
        normalized.contains('api key') ||
        normalized.contains('service unavailable') ||
        normalized.contains('unavailable') ||
        normalized.contains('500') ||
        normalized.contains('403') ||
        normalized.contains('401') ||
        normalized.contains('hệ thống') ||
        normalized.contains('quá tải');
  }

  static String _normalizeUserMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('unauthenticated') ||
        normalized.contains('requires-recent-login') ||
        normalized.contains('phiên đăng nhập') ||
        normalized.contains('đăng nhập để tạo liên kết')) {
      return 'Đã lâu bạn chưa ghé, đăng nhập lại để tiếp tục viết tiếp chuyện tình mình nhé! 👋';
    }
    if (message.isEmpty) {
      return 'Thông tin bạn nhập chưa hợp lệ. Vui lòng kiểm tra lại.';
    }
    return message;
  }

  static String _normalizeNetworkMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('quá thời gian') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out')) {
      return 'Kết nối mạng quá chậm hoặc đã hết thời gian chờ. Vui lòng kiểm tra mạng rồi thử lại.';
    }
    if (message.isEmpty) {
      return defaultNetworkMessage;
    }
    return message;
  }

  static String _normalizeServerMessage(
    String message, {
    String? fallbackMessage,
  }) {
    final normalized = message.toLowerCase();
    if (normalized.contains('firebase app check api') ||
        normalized.contains('app check') ||
        normalized.contains('appcheck') ||
        normalized.contains('debug token') ||
        normalized.contains('play integrity') ||
        normalized.contains('attestation')) {
      if (kDebugMode) {
        return 'Hệ thống xác thực bảo mật đang chặn thao tác này. Hãy kiểm tra cấu hình bảo mật thiết bị hoặc debug token rồi thử lại.';
      }
      return 'Thiết bị chưa được xác nhận để thực hiện thao tác này. Hãy chờ vài giây rồi thử lại hoặc đăng nhập lại.';
    }
    if (normalized.contains('permission denied')) {
      return 'Máy chủ đang chặn thao tác này. Vui lòng thử lại sau hoặc liên hệ hỗ trợ.';
    }
    if (normalized.contains('api key') ||
        normalized.contains('internal error has occurred')) {
      return 'Dịch vụ đăng nhập đang gặp sự cố hệ thống. Vui lòng thử lại sau.';
    }
    if (normalized.contains('máy chủ chưa cấu hình otp_secret') ||
        normalized.contains('máy chủ chưa được cấu hình để gửi email otp') ||
        normalized.contains('otp_secret') ||
        normalized.contains('gmail_app_password')) {
      return 'Dịch vụ gửi mã OTP chưa được thiết lập đầy đủ trên máy chủ. Hãy kiểm tra OTP_SECRET và Gmail App Password trong Firebase Secrets.';
    }
    if (message.isEmpty) {
      return fallbackMessage ?? defaultServerMessage;
    }
    return message;
  }
}
