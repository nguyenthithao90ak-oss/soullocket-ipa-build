import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

enum AiTask {
  friendlyChat('friendly_chat'),
  appSupport('app_support'),
  notificationCopy('notification_copy');

  const AiTask(this.id);
  final String id;
}

typedef AiCallableInvoker =
    Future<dynamic> Function(String name, Map<String, Object?> payload);

class AiTaskOutcome {
  const AiTaskOutcome({
    required this.requestId,
    required this.status,
    this.text,
    this.errorMessage,
    this.memorySaved = false,
  });
  final String requestId;
  final String status;
  final String? text;
  final String? errorMessage;
  final bool memorySaved;
  bool get isPending => status == 'pending' || status == 'unknown';
}

class AiCounselorService {
  static final AiCounselorService _instance = AiCounselorService._internal();
  factory AiCounselorService() => _instance;
  AiCounselorService._internal()
    : _invoke = _invokeFirebase,
      _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _locale = (() => L10nService().localeCode),
      _translate = ((key) => L10nService().translate(key));

  @visibleForTesting
  AiCounselorService.forTesting(
    this._invoke,
    this._currentUid,
    this._locale,
    this._translate,
  );

  final AiCallableInvoker _invoke;
  final String? Function() _currentUid;
  final String Function() _locale;
  final String Function(String) _translate;

  static Future<dynamic> _invokeFirebase(
    String name,
    Map<String, Object?> payload,
  ) async {
    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      name,
      payload: payload,
      timeout: Duration(seconds: name == 'generateAiTask' ? 40 : 15),
      requireAppCheck: true,
      throwOriginalException: true,
    );
    return response.data;
  }

  Future<dynamic> _call(String name, Map<String, Object?> payload) async {
    final uid = _currentUid();
    if (uid == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: _translate('err_auth_recent_login_required'),
      );
    }
    final result = await _invoke(name, payload);
    // Không đưa kết quả của phiên cũ vào UI/cache của tài khoản vừa đăng nhập.
    if (_currentUid() != uid) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: _translate('err_auth_recent_login_required'),
      );
    }
    return result;
  }

  String? lastErrorMessage;
  bool lastMemorySaved = true;

  static String createRequestId() {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  String _errorText(String code) => _translate(switch (code) {
    'unauthenticated' || 'permission-denied' => 'ai_task_auth_error',
    'resource-exhausted' => 'ai_task_quota_error',
    'invalid-argument' => 'ai_task_input_error',
    'failed-precondition' => 'ai_task_busy_error',
    _ => 'friendly_chat_connection_error',
  });

  AiTaskOutcome _parseReply(dynamic data, AiTask task, String requestId) {
    if (data is! Map ||
        data['requestId'] != requestId ||
        data['taskId'] != task.id ||
        data['text'] is! String ||
        (data['text'] as String).trim().isEmpty) {
      throw const FormatException('Invalid AI task response');
    }
    return AiTaskOutcome(
      requestId: requestId,
      status: 'completed',
      text: (data['text'] as String).trim(),
      memorySaved: data['memorySaved'] == true,
    );
  }

  /// Chỉ đọc kết quả đã có. Hàm này không gọi model hoặc trừ lượt.
  Future<AiTaskOutcome> getTaskResult(AiTask task, String requestId) async {
    try {
      final data = await _call('getAiTaskResult', {'requestId': requestId});
      if (data is! Map) throw const FormatException('Invalid status');
      switch (data['status']) {
        case 'completed':
          return _parseReply(data['result'], task, requestId);
        case 'pending':
        case 'unknown':
          return AiTaskOutcome(
            requestId: requestId,
            status: data['status'] as String,
            errorMessage: _translate('ai_task_pending_message'),
          );
        case 'cancelled':
          return AiTaskOutcome(
            requestId: requestId,
            status: 'cancelled',
            errorMessage: _translate('ai_task_cancelled_message'),
          );
        case 'failed':
          return AiTaskOutcome(
            requestId: requestId,
            status: 'failed',
            errorMessage: _errorText(data['code']?.toString() ?? 'unavailable'),
          );
        default:
          throw const FormatException('Invalid status');
      }
    } on FirebaseFunctionsException catch (error) {
      return AiTaskOutcome(
        requestId: requestId,
        status: error.code == 'invalid-argument' ? 'expired' : 'unknown',
        errorMessage: error.code == 'invalid-argument'
            ? _translate('ai_task_result_expired')
            : _errorText(error.code),
      );
    } catch (_) {
      return AiTaskOutcome(
        requestId: requestId,
        status: 'unknown',
        errorMessage: _translate('ai_task_pending_message'),
      );
    }
  }

  Future<AiTaskOutcome> generateTaskOutcome(
    AiTask task,
    Map<String, Object?> input, {
    String? requestId,
  }) async {
    final id = requestId ?? createRequestId();
    final uid = _currentUid();
    try {
      final data = await _call('generateAiTask', {
        'taskId': task.id,
        'input': input,
        'locale': _locale(),
        'requestId': id,
      });
      return _parseReply(data, task, id);
    } catch (error) {
      final code = error is FirebaseFunctionsException
          ? error.code
          : 'unavailable';
      final uncertain =
          error is TimeoutException ||
          error is FormatException ||
          const [
            'unavailable',
            'deadline-exceeded',
            'internal',
            'unknown',
            'failed-precondition',
          ].contains(code);
      // Timeout/mất ACK chỉ kiểm tra trạng thái. Không tự phát lại generate.
      if (uncertain && uid != null && _currentUid() == uid) {
        final recovered = await getTaskResult(task, id);
        if (code != 'failed-precondition' || recovered.status != 'unknown') {
          return recovered;
        }
      }
      return AiTaskOutcome(
        requestId: id,
        status: 'failed',
        errorMessage: _errorText(code),
      );
    }
  }

  Future<List<AiChatHistoryMessage>> loadChatHistory({
    String memoryScope = 'friendly_chat',
  }) async {
    try {
      final data = await _call('getAiChatHistory', {
        'memoryScope': memoryScope,
      });
      if (data is! Map || data['messages'] is! List) return const [];
      return (data['messages'] as List)
          .whereType<Map>()
          .map((item) {
            final text = item['text']?.toString().trim() ?? '';
            final role = item['role']?.toString().trim();
            if (text.isEmpty || (role != 'user' && role != 'assistant')) {
              return null;
            }
            return AiChatHistoryMessage(
              text: text,
              isUser: role == 'user',
              createdAt: int.tryParse(item['createdAt']?.toString() ?? '') ?? 0,
              requestId: item['requestId'] is String
                  ? item['requestId'] as String
                  : null,
            );
          })
          .whereType<AiChatHistoryMessage>()
          .toList(growable: false);
    } catch (_) {
      debugPrint('[AiCounselor] history unavailable');
      return const [];
    }
  }

  /// Chỉ gửi dữ liệu tác vụ. Prompt, model, quota và quyền đọc do server quyết định.
  /// Không tự gọi lại hoặc chuyển Worker sau lỗi: lượt cũ có thể đã được tính phí.
  Future<String?> generateTask(AiTask task, Map<String, Object?> input) async {
    final outcome = await generateTaskOutcome(task, input);
    lastErrorMessage = outcome.errorMessage;
    lastMemorySaved = outcome.memorySaved;
    return outcome.text;
  }

  /// Adapter cho UI hiện tại. Gateway trả bản hoàn chỉnh đã kiểm tra nội dung;
  /// chưa phải streaming token từ provider và không giả lập hiệu ứng từng từ.
  Stream<String> streamTask(AiTask task, Map<String, Object?> input) async* {
    final reply = await generateTask(task, input);
    if (reply != null) yield reply;
  }

  Future<bool> clearChatHistory() async {
    try {
      await _call('clearAiChatHistory', const <String, Object?>{});
      return true;
    } catch (_) {
      lastErrorMessage = _translate('friendly_chat_connection_error');
      return false;
    }
  }

  Future<bool> reportAiReply({
    required String assistantText,
    required String reason,
    String? userText,
    String? houseId,
  }) async {
    try {
      await _call('reportAiReply', {
        'assistantText': assistantText,
        'reason': reason,
        if (userText?.trim().isNotEmpty == true) 'userText': userText!.trim(),
        if (houseId?.trim().isNotEmpty == true) 'houseId': houseId!.trim(),
      });
      return true;
    } catch (_) {
      debugPrint('[AiCounselor] report failed');
      return false;
    }
  }
}

class AiChatHistoryMessage {
  const AiChatHistoryMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.requestId,
  });
  final String text;
  final bool isUser;
  final int createdAt;
  final String? requestId;
}
