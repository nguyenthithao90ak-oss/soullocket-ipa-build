import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/chat_message.dart';

/// Cùng thứ tự timestamp/id cho trang đầu và trang cũ, không bỏ sót tin
/// nhắn trùng millisecond ở ranh giới trang.
abstract final class ChatMessageQuery {
  /// Một bản ghi cũ sai kiểu không được làm hỏng cả trang seed hoặc luồng live.
  static ChatMessage? readDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    try {
      final data = document.data();
      return data == null ? null : ChatMessage.fromMap(document.id, data);
    } catch (_) {
      return null;
    }
  }

  static Query<Map<String, dynamic>> page(
    Query<Map<String, dynamic>> messages, {
    required int limit,
    int? beforeTs,
    String? beforeId,
  }) {
    var query = messages
        .orderBy('ts', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);
    if (beforeTs != null) {
      query = beforeId == null
          ? query.where('ts', isLessThan: beforeTs)
          : query.startAfter([beforeTs, beforeId]);
    }
    return query;
  }

  static Query<Map<String, dynamic>> live(
    Query<Map<String, dynamic>> messages,
    int inclusiveTs,
  ) => messages.where('ts', isGreaterThanOrEqualTo: inclusiveTs).orderBy('ts');
}
