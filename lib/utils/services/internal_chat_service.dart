import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart'
    show DatabaseReference, FirebaseDatabase, ServerValue;
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/models/chat_message.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import '../seeded_live_stream.dart';
import 'chat_message_query.dart';

/// InternalChatService — quản lý tin nhắn nội bộ (giữa 2 người trong 1 house)
/// Firestore path: houses/{houseId}/chat_room_messages/{msgId}
/// RTDB chỉ giữ lastMessage + metadata nhẹ để hiển thị badge thông báo
class InternalChatService {
  static final InternalChatService _instance = InternalChatService._internal();

  factory InternalChatService() => _instance;
  InternalChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final Set<String> _migratedHouses = {};
  final Map<String, Future<void>> _migrationInFlight = {};

  // ── Collection Reference ──────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _messagesRef(String houseId) {
    return _firestore
        .collection('houses')
        .doc(houseId)
        .collection('chat_room_messages');
  }

  // ── GỬI tin nhắn mới ─────────────────────────────────────────────────
  Future<String> sendMessage(String houseId, ChatMessage message) async {
    if (message.text.trim().length > 2000) {
      throw Exception('Tin nhắn vượt quá giới hạn 2000 ký tự.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{...message.toMap(), 'ts': now};

    // Ghi tin nhắn vào Firestore
    final docRef = await _messagesRef(houseId).add(payload);

    // Cập nhật lastMessage lên RTDB (chạy ngầm bất đồng bộ để gửi tin nhắn siêu tốc)
    unawaited(
      _rtdb
          .child('houses/$houseId/chat_room/lastMessage')
          .set({
            'text': message.type == 'image' ? '[Hình ảnh]' : message.text,
            'ts': now,
            'senderId': message.senderId,
            'isRead': false,
            'type': message.type,
            'messageId': docRef.id,
          })
          .catchError((e) {
            debugPrint(
              '[InternalChatService] Failed to set lastMessage on RTDB: $e',
            );
          }),
    );

    unawaited(
      _rtdb
          .child('houses/$houseId/chat_room/updatedAt')
          .set(ServerValue.timestamp)
          .catchError((e) {
            debugPrint(
              '[InternalChatService] Failed to set updatedAt on RTDB: $e',
            );
          }),
    );

    return docRef.id;
  }

  // ── STREAM tin nhắn mới realtime ─────────────────────────────────────
  Stream<ChatMessage> streamNewMessages(String houseId, {int? afterTs}) {
    final messages = _messagesRef(houseId);
    return seededLiveStream<ChatMessage>(
      afterTs: afterTs,
      seed: () => ChatMessageQuery.page(messages, limit: 25).snapshots()
          .map((snapshot) => snapshot.docs
              .map(ChatMessageQuery.readDocument)
              .whereType<ChatMessage>().toList()),
      timestampOf: (message) => message.timestamp.millisecondsSinceEpoch,
      live: (cursor) => ChatMessageQuery.live(messages, cursor)
        .snapshots()
        .expand(
          (snapshot) => snapshot.docChanges
              .where(
                (change) =>
                    change.type == DocumentChangeType.added ||
                    change.type == DocumentChangeType.modified,
              )
              .map((change) => ChatMessageQuery.readDocument(change.doc))
              .whereType<ChatMessage>(),
        ),
    );
  }

  // ── LẤY trang tin nhắn (phân trang) ──────────────────────────────────
  Future<List<ChatMessage>> fetchMessagesPage(
    String houseId, {
    int limit = 40,
    int? beforeTs,
    String? beforeId,
  }) async {
    final query = ChatMessageQuery.page(_messagesRef(houseId), limit: limit,
        beforeTs: beforeTs, beforeId: beforeId);
    final snap = await query.get().timeout(const Duration(seconds: 10));
    return snap.docs
        .map(ChatMessageQuery.readDocument)
        .whereType<ChatMessage>()
        .toList();
  }

  // ── THÊM REACTION ─────────────────────────────────────────────────────
  Future<void> addReaction(
    String houseId,
    String messageId,
    String senderRole,
    String emoji,
  ) async {
    final normalizedRole = senderRole == 'user2' ? 'user2' : 'user1';
    await _messagesRef(
      houseId,
    ).doc(messageId).update({'reactions.$normalizedRole': emoji});
  }

  // ── XÓA CONVERSATION ─────────────────────────────────────────────────
  Future<void> clearConversation(String houseId) async {
    // Xóa theo batch để tránh timeout
    while (true) {
      final snap = await _messagesRef(houseId).limit(300).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    // Xóa lastMessage trên RTDB
    await _rtdb.child('houses/$houseId/chat_room/messages').remove();
    await _rtdb.update({
      'houses/$houseId/chat_room/lastMessage': null,
      'houses/$houseId/chat_room/updatedAt': ServerValue.timestamp,
    });
  }

  // ── MIGRATION từ RTDB sang Firestore ──────────────────────────────────
  Future<void> migrateFromRTDB(String houseId) {
    if (_migratedHouses.contains(houseId)) return Future.value();
    return _migrationInFlight.putIfAbsent(
      houseId,
      () => _migrateFromRTDB(houseId).whenComplete(() {
        _migrationInFlight.remove(houseId);
      }),
    );
  }

  Future<void> _migrateFromRTDB(String houseId) async {
    try {
      final source = await _rtdb
          .child('houses/$houseId/chat_room/messages')
          .limitToFirst(1)
          .get();
      if (!source.exists) {
        _migratedHouses.add(houseId);
        return;
      }
      String? cursor;
      do {
        // Server lấy bản gốc từ RTDB; client không được giả danh người còn lại.
        final payload = <String, dynamic>{'houseId': houseId};
        if (cursor != null) payload['afterKey'] = cursor;
        final result = await FirebaseFunctions.instance
            .httpsCallable('migrateInternalChatSecure')
            .call<Map<String, dynamic>>(payload);
        cursor = result.data['nextCursor'] as String?;
      } while (cursor != null);
      _migratedHouses.add(houseId);
    } catch (e) {
      debugPrint(
        '[InternalChatService] Migration error: ${AppErrorMapper.resolve(e).message}',
      );
    }
  }
}
