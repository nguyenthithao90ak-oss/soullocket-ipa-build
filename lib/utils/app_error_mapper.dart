import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

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
  static String get defaultNetworkMessage =>
      L10nService().translate('err_default_network');
  static String get defaultServerMessage =>
      L10nService().translate('err_default_server');
  static String get authSyncMessage =>
      L10nService().translate('err_auth_session_expired');
  static String get recentLoginMessage =>
      L10nService().translate('err_auth_recent_login_required');

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
      return AppErrorInfo(
        kind: AppErrorKind.network,
        message: L10nService().translate('err_network_timeout'),
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
    final cleaned = value
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Error:\s*'), '')
        .replaceFirst(RegExp(r'^\[firebase_auth\/[^\]]+\]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= 500) return cleaned;
    return '${cleaned.substring(0, 500).trim()}…';
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
        return AppErrorInfo(
          kind: AppErrorKind.network,
          message: defaultNetworkMessage,
        );
      case 'too-many-requests':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_too_many_requests'),
        );
      case 'user-not-found':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_user_not_found'),
        );
      case 'wrong-password':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_wrong_password'),
        );
      case 'invalid-credential':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_invalid_credential'),
        );
      case 'invalid-email':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_invalid_email'),
        );
      case 'email-already-in-use':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_email_in_use'),
        );
      case 'weak-password':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_weak_password'),
        );
      case 'popup-closed-by-user':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_popup_closed'),
        );
      case 'popup-blocked':
      case 'cancelled-popup-request':
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate('err_auth_popup_blocked'),
        );
      default:
        return AppErrorInfo(
          kind: AppErrorKind.server,
          message: _normalizeServerMessage(
            cleanMessage(error.message),
            fallbackMessage: L10nService().translate('err_auth_server_busy'),
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
      return AppErrorInfo(
        kind: AppErrorKind.user,
        message: recentLoginMessage,
      );
    }

    if (code == 'unauthenticated') {
      return AppErrorInfo(
        kind: AppErrorKind.user,
        message: authSyncMessage,
      );
    }

    if (code == 'network-request-failed' ||
        code == 'deadline-exceeded' ||
        code == 'timed-out') {
      return AppErrorInfo(
        kind: AppErrorKind.network,
        message: L10nService().translate('err_network_interrupted'),
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
      if (code == 'permission-denied') {
        return AppErrorInfo(
          kind: AppErrorKind.user,
          message: cleanMsg.isEmpty || cleanMsg == defaultServerMessage
              ? L10nService().translate('err_permission_denied')
              : cleanMsg,
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
        normalized.contains('already in use') ||
        normalized.contains('already-in-use') ||
        normalized.contains('email-already-in-use') ||
        normalized.contains('wrong-password') ||
        normalized.contains('wrong password') ||
        normalized.contains('invalid-credential') ||
        normalized.contains('invalid credential') ||
        normalized.contains('invalid-email') ||
        normalized.contains('invalid email') ||
        normalized.contains('weak-password') ||
        normalized.contains('weak password') ||
        normalized.contains('user-not-found') ||
        normalized.contains('user not found') ||
        normalized.contains('too-many-requests') ||
        normalized.contains('too many requests') ||
        normalized.contains('blocked all requests') ||
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
    if (normalized.contains('unauthenticated')) {
      return authSyncMessage;
    }
    if (normalized.contains('requires-recent-login')) {
      return recentLoginMessage;
    }
    if (normalized.contains('phiên đăng nhập') ||
        normalized.contains('đăng nhập để tạo liên kết')) {
      return recentLoginMessage;
    }
    if (normalized.contains('already in use') ||
        normalized.contains('already-in-use') ||
        normalized.contains('email-already-in-use')) {
      return L10nService().translate('err_auth_email_in_use');
    }
    if (normalized.contains('weak password') ||
        normalized.contains('weak-password')) {
      return L10nService().translate('err_auth_weak_password');
    }
    if (normalized.contains('invalid email') ||
        normalized.contains('invalid-email')) {
      return L10nService().translate('err_auth_invalid_email');
    }
    if (normalized.contains('wrong password') ||
        normalized.contains('wrong-password') ||
        normalized.contains('invalid-credential') ||
        normalized.contains('invalid login credentials')) {
      return L10nService().translate('err_auth_invalid_credential');
    }
    if (normalized.contains('too many requests') ||
        normalized.contains('too-many-requests') ||
        normalized.contains('blocked all requests')) {
      return L10nService().translate('err_auth_too_many_requests');
    }
    if (normalized.contains('user not found') ||
        normalized.contains('user-not-found')) {
      return L10nService().translate('err_auth_user_not_found');
    }
    if (message.isEmpty) {
      return L10nService().translate('err_invalid_input');
    }
    return message;
  }

  static String _normalizeNetworkMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('quá thời gian') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out')) {
      return L10nService().translate('err_network_timeout');
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
        return L10nService().translate('err_appcheck_debug_blocked');
      }
      return L10nService().translate('err_appcheck_verifying_device');
    }
    if (normalized.contains('permission denied')) {
      return L10nService().translate('err_server_blocking_action');
    }
    if (normalized.contains('api key') ||
        normalized.contains('internal error has occurred')) {
      return L10nService().translate('err_login_service_system');
    }
    if (normalized.contains('máy chủ chưa cấu hình otp_secret') ||
        normalized.contains('máy chủ chưa được cấu hình để gửi email otp') ||
        normalized.contains('otp_secret') ||
        normalized.contains('gmail_app_password')) {
      return L10nService().translate('err_otp_service_not_ready');
    }
    if (message.isEmpty) {
      return fallbackMessage ?? defaultServerMessage;
    }
    return message;
  }
}
