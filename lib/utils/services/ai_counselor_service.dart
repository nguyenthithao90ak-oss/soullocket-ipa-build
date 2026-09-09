import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'app_check_http_headers.dart';

class AiCounselorService {
  static final AiCounselorService _instance = AiCounselorService._internal();

  factory AiCounselorService() => _instance;

  AiCounselorService._internal();

  String? lastErrorMessage;

  Future<List<AiChatHistoryMessage>> loadChatHistory({
    String memoryScope = 'friendly_chat',
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'getAiChatHistory',
      );
      final response = await callable.call(<String, dynamic>{
        'memoryScope': memoryScope,
      });
      final data = response.data;
      if (data is! Map || data['messages'] is! List) {
        return const <AiChatHistoryMessage>[];
      }
      return (data['messages'] as List)
          .whereType<Map>()
          .map((item) {
            final text = item['text']?.toString().trim() ?? '';
            final role = item['role']?.toString().trim();
            final createdAt =
                int.tryParse(item['createdAt']?.toString() ?? '') ?? 0;
            if (text.isEmpty || (role != 'user' && role != 'assistant')) {
              return null;
            }
            return AiChatHistoryMessage(
              text: text,
              isUser: role == 'user',
              createdAt: createdAt,
            );
          })
          .whereType<AiChatHistoryMessage>()
          .toList(growable: false);
    } catch (error) {
      debugPrint(
        '[AiCounselor] getAiChatHistory failed: ${AppErrorMapper.resolve(error).message}',
      );
      return const <AiChatHistoryMessage>[];
    }
  }

  Stream<String> streamTextGeneration(
    String prompt,
    String systemInstruction, {
    String? memoryScope,
    String? memoryText,
    String? persona,
  }) async* {
    lastErrorMessage = null;
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    bool hasYielded = false;

    if (token != null) {
      final projectId = FirebaseFunctions.instance.app.options.projectId;
      final url =
          'https://us-central1-$projectId.cloudfunctions.net/generateAiReplyStream';

      final client = http.Client();
      try {
        final request = http.Request('POST', Uri.parse(url));
        request.headers.addAll(
          await AppCheckHttpHeaders.withRequiredToken({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          }),
        );
        request.body = jsonEncode({
          'data': {
            'prompt': prompt,
            'systemInstruction': systemInstruction,
            'memoryScope': memoryScope,
            'memoryText': memoryText,
            'persona': persona,
          },
        });

        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 429) {
          lastErrorMessage = _mapFunctionsError(
            FirebaseFunctionsException(
              message: '',
              code: response.statusCode == 429
                  ? 'resource-exhausted'
                  : 'unauthenticated',
            ),
          );
          // Không chuyển provider khi server đã từ chối quyền/hạn mức.
          return;
        }
        if (response.statusCode == 200) {
          await for (var line
              in response.stream
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())) {
            if (line.startsWith('data: ')) {
              try {
                final payload = jsonDecode(line.substring(6));
                if (payload['chunk'] != null) {
                  hasYielded = true;
                  yield payload['chunk'] as String;
                }
                if (payload['text'] != null) {
                  hasYielded = true;
                  yield payload['text'] as String;
                }
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint(
          '[AiCounselor] streamTextGeneration stream attempt failed: $e',
        );
      } finally {
        client.close();
      }
    }

    if (hasYielded) {
      return;
    }

    // Tự động chuyển tiếp sang callTextGeneration khi stream endpoint không khả dụng
    final fallbackReply = await callTextGeneration(
      prompt,
      systemInstruction,
      memoryScope: memoryScope,
      memoryText: memoryText,
    );

    if (fallbackReply != null && fallbackReply.trim().isNotEmpty) {
      final words = fallbackReply.trim().split(' ');
      for (int i = 0; i < words.length; i++) {
        final chunk = (i == 0 ? '' : ' ') + words[i];
        yield chunk;
        await Future.delayed(const Duration(milliseconds: 20));
      }
      return;
    }

    lastErrorMessage =
        'Mình đang gặp lỗi kết nối nên chưa trả lời được. Bạn thử lại sau nhé!';
  }

  Future<String?> callTextGeneration(
    String prompt,
    String systemInstruction, {
    String? memoryScope,
    String? memoryText,
  }) async {
    lastErrorMessage = null;
    String? openAiReply;
    try {
      openAiReply = await _callOpenAiFunction(
        prompt,
        systemInstruction,
        memoryScope: memoryScope,
        memoryText: memoryText,
      );
    } on FirebaseFunctionsException {
      // Lỗi xác thực/hạn mức đã được ánh xạ; không thử backend khác để vượt chặn.
      return null;
    }
    if (openAiReply != null && openAiReply.isNotEmpty) {
      return openAiReply;
    }

    final workerReply = await _callWorkerAi(
      prompt,
      systemInstruction,
      endpoint: '/api/v1/ai/chat',
      memoryContext: memoryText,
    );
    if (workerReply != null && workerReply.isNotEmpty) {
      return workerReply;
    }

    // Mọi fallback đều qua backend có xác thực; client không giữ API key AI.
    return null;
  }

  Future<bool> reportAiReply({
    required String assistantText,
    required String reason,
    String? userText,
    String? houseId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'reportAiReply',
      );
      await callable.call(<String, dynamic>{
        'assistantText': assistantText,
        'reason': reason,
        if (userText?.trim().isNotEmpty == true) 'userText': userText!.trim(),
        if (houseId?.trim().isNotEmpty == true) 'houseId': houseId!.trim(),
      });
      return true;
    } catch (error) {
      debugPrint(
        '[AiCounselor] reportAiReply failed: ${AppErrorMapper.resolve(error).message}',
      );
      return false;
    }
  }

  Future<String?> _callOpenAiFunction(
    String prompt,
    String systemInstruction, {
    String? memoryScope,
    String? memoryText,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateAiReply',
      );
      final payload = <String, dynamic>{
        'prompt': prompt,
        'systemInstruction': systemInstruction,
      };
      if (memoryScope?.trim().isNotEmpty == true) {
        payload['memoryScope'] = memoryScope!.trim();
      }
      if (memoryText?.trim().isNotEmpty == true) {
        payload['memoryText'] = memoryText!.trim();
      }
      final response = await callable.call(payload);
      final data = response.data;
      if (data is! Map) {
        return null;
      }
      final text = data['text']?.toString().trim();
      if (text == null || text.isEmpty) {
        return null;
      }
      return text;
    } on FirebaseFunctionsException catch (error) {
      lastErrorMessage = _mapFunctionsError(error);
      if (const {
        'unauthenticated',
        'permission-denied',
        'resource-exhausted',
        'invalid-argument',
      }.contains(error.code.trim().toLowerCase())) {
        rethrow;
      }
      debugPrint(
        '[AiCounselor] generateAiReply failed: ${AppErrorMapper.resolve(error).message}',
      );
      return null;
    } catch (_) {
      lastErrorMessage =
          'Mình đang gặp lỗi kết nối nên chưa trả lời được. Bạn thử lại sau một chút nhé, sorry.';
      return null;
    }
  }

  Future<String?> _callWorkerAi(
    String prompt,
    String systemInstruction, {
    String endpoint = '/api/v1/ai/chat',
    String? memoryContext,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return null;
      }

      var headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };
      headers = await AppCheckHttpHeaders.withRequiredToken(headers);

      final workerUrl = AppConfig.cloudflareWorkerUrl.isNotEmpty
          ? AppConfig.cloudflareWorkerUrl
          : 'https://soullocket-api.soullocket-api.workers.dev';

      final response = await http
          .post(
            Uri.parse('$workerUrl$endpoint'),
            headers: headers,
            body: jsonEncode({
              'prompt': prompt,
              'systemInstruction': systemInstruction,
              if (memoryContext?.trim().isNotEmpty == true)
                'memoryContext': memoryContext!.trim(),
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint(
          '[AiCounselor] Worker $endpoint failed: ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final text = data['text']?.toString().trim();
      if (text == null || text.isEmpty) return null;
      return text;
    } catch (e) {
      debugPrint('[AiCounselor] Worker $endpoint error: $e');
      return null;
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    switch (error.code.trim().toLowerCase()) {
      case 'not-found':
        return 'Mình đang gặp lỗi hệ thống chat nên chưa trả lời được. Bạn thử lại sau một chút nhé, sorry.';
      case 'failed-precondition':
        return message?.isNotEmpty == true
            ? message!
            : 'Mình đang gặp lỗi cấu hình chat nên chưa trả lời được. Bạn thử lại sau một chút nhé, sorry.';
      case 'unauthenticated':
        return 'Bạn cần đăng nhập lại để dùng Chat thân thiện.';
      case 'resource-exhausted':
        return message?.isNotEmpty == true
            ? message!
            : 'Bạn đã dùng quá nhiều lượt AI trong giờ này.';
      case 'unavailable':
      case 'deadline-exceeded':
        return message?.isNotEmpty == true
            ? message!
            : 'Mình đang gặp trục trặc hoặc phản hồi hơi chậm nên chưa trả lời được. Bạn thử lại sau một chút nhé, sorry.';
      case 'invalid-argument':
        return message?.isNotEmpty == true
            ? message!
            : 'Tin nhắn gửi tới AI chưa hợp lệ.';
      default:
        return message?.isNotEmpty == true
            ? message!
            : 'Mình đang gặp lỗi nên chưa trả lời được. Bạn thử lại sau một chút nhé, sorry.';
    }
  }
}

class AiChatHistoryMessage {
  const AiChatHistoryMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
  });

  final String text;
  final bool isUser;
  final int createdAt;
}
