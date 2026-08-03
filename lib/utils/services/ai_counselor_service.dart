import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:soullocket_app/utils/app_error_mapper.dart';

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
            final createdAt = int.tryParse(
                  item['createdAt']?.toString() ?? '',
                ) ??
                0;
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
          '[AiCounselor] getAiChatHistory failed: ${AppErrorMapper.resolve(error).message}');
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
    if (token == null) {
      lastErrorMessage = 'Bạn cần đăng nhập để dùng tính năng này.';
      return;
    }

    final projectId = FirebaseFunctions.instance.app.options.projectId;
    final url =
        'https://us-central1-$projectId.cloudfunctions.net/generateAiReplyStream';

    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'data': {
          'prompt': prompt,
          'systemInstruction': systemInstruction,
          'memoryScope': memoryScope,
          'memoryText': memoryText,
          'persona': persona,
        }
      });

      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        lastErrorMessage = 'Lỗi kết nối máy chủ (Mã: ${response.statusCode})';
        return;
      }

      await for (var line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          try {
            final payload = jsonDecode(line.substring(6));
            if (payload['chunk'] != null) {
              yield payload['chunk'] as String;
            }
            if (payload['text'] != null) {
              yield payload['text'] as String;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[AiCounselor] streamTextGeneration failed: $e');
      lastErrorMessage =
          'Mình đang gặp lỗi kết nối nên chưa trả lời được. Bạn thử lại sau nhé!';
    }
  }

  Future<String?> callTextGeneration(
    String prompt,
    String systemInstruction, {
    String? memoryScope,
    String? memoryText,
  }) async {
    lastErrorMessage = null;
    final openAiReply = await _callOpenAiFunction(
      prompt,
      systemInstruction,
      memoryScope: memoryScope,
      memoryText: memoryText,
    );
    if (openAiReply != null && openAiReply.isNotEmpty) {
      return openAiReply;
    }
    return _callGeminiProxy(prompt, systemInstruction);
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
          '[AiCounselor] reportAiReply failed: ${AppErrorMapper.resolve(error).message}');
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

  Future<String?> _callGeminiProxy(
    String prompt,
    String systemInstruction,
  ) async {
    const proxyUrl =
        String.fromEnvironment('GEMINI_PROXY_URL', defaultValue: '');
    const apiKeysString =
        String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    const model = String.fromEnvironment('GEMINI_MODEL',
        defaultValue: 'gemini-1.5-flash');

    final apiKeys = apiKeysString
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != 'ĐIỀN_KEY_CỦA_BẠN_VÀO_ĐÂY')
        .toList();

    List<String> urlsToTry = [];
    if (proxyUrl.isNotEmpty) {
      urlsToTry.add(proxyUrl);
    }
    for (final key in apiKeys) {
      urlsToTry.add(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
    }

    if (urlsToTry.isEmpty) {
      return null;
    }

    for (final url in urlsToTry) {
      final uri = Uri.parse(url);

      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': systemInstruction}
              ]
            },
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.7,
            }
          }),
        );

        if (response.statusCode != 200) {
          continue; // Try next URL/key
        }

        final data = jsonDecode(response.body);
        final candidates = data['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          continue;
        }

        final first = candidates.first;
        final content = first['content'];
        final parts = content['parts'];
        if (parts is! List || parts.isEmpty) {
          continue;
        }

        final text = parts.first['text']?.toString().trim();
        if (text == null || text.isEmpty) {
          continue;
        }

        return text;
      } catch (_) {
        continue;
      }
    }
    return null;
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
