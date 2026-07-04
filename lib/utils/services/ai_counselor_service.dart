import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
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
    if (proxyUrl.isEmpty) {
      return null;
    }
    final uri = Uri.parse(proxyUrl);

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
        return null;
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        return null;
      }

      final first = candidates.first;
      final content = first['content'];
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) {
        return null;
      }

      final text = parts.first['text']?.toString().trim();
      if (text == null || text.isEmpty) {
        return null;
      }

      return text;
    } catch (_) {
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
