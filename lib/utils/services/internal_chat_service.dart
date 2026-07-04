import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'
    show DatabaseReference, FirebaseDatabase, ServerValue;
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/models/chat_message.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

/// InternalChatService — quản lý tin nhắn nội bộ (giữa 2 người trong 1 house)
/// Firestore path: houses/{houseId}/chat_room/messages/{msgId}
/// RTDB chỉ giữ lastMessage + metadata nhẹ để hiển thị badge thông báo
class InternalChatService {
  static final InternalChatService _instance = InternalChatService._internal();

  factory InternalChatService() => _instance;
  InternalChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  // ── Collection Reference ──────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _messagesRef(String houseId) {
    return _firestore
        .collection('houses')
        .doc(houseId)
        .collection('chat_room_messages');
  }

  // ── GỬI tin nhắn mới ─────────────────────────────────────────────────
  Future<String> sendMessage(String houseId, ChatMessage message) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{
      ...message.toMap(),
      'ts': now,
    };

    // Ghi tin nhắn vào Firestore
    final docRef = await _messagesRef(houseId).add(payload);

    // Cập nhật lastMessage lên RTDB (nhẹ, chỉ vài bytes để hiển thị badge)
    await _rtdb.child('houses/$houseId/chat_room/lastMessage').set({
      'text': message.type == 'image' ? '[Hình ảnh]' : message.text,
      'ts': now,
      'senderId': message.senderId,
      'isRead': false,
      'type': message.type,
      'messageId': docRef.id,
    });
    await _rtdb
        .child('houses/$houseId/chat_room/updatedAt')
        .set(ServerValue.timestamp);

    return docRef.id;
  }

  // ── STREAM tin nhắn mới realtime ─────────────────────────────────────
  Stream<ChatMessage> streamNewMessages(String houseId, {int afterTs = 0}) {
    return _messagesRef(houseId)
        .where('ts', isGreaterThan: afterTs)
        .orderBy('ts')
        .snapshots()
        .expand((snapshot) => snapshot.docChanges
                .where((change) =>
                    change.type == DocumentChangeType.added ||
                    change.type == DocumentChangeType.modified)
                .map((change) {
              try {
                return ChatMessage.fromMap(change.doc.id, change.doc.data()!);
              } catch (_) {
                return null;
              }
            }).whereType<ChatMessage>());
  }

  // ── LẤY trang tin nhắn (phân trang) ──────────────────────────────────
  Future<List<ChatMessage>> fetchMessagesPage(
    String houseId, {
    int limit = 40,
    int? beforeTs,
  }) async {
    Query<Map<String, dynamic>> query =
        _messagesRef(houseId).orderBy('ts', descending: true).limit(limit);

    if (beforeTs != null) {
      query = query.where('ts', isLessThan: beforeTs);
    }

    final snap = await query.get();
    return snap.docs
        .map((doc) {
          try {
            return ChatMessage.fromMap(doc.id, doc.data());
          } catch (_) {
            return null;
          }
        })
        .whereType<ChatMessage>()
        .toList();
  }

  // ── THÊM REACTION ─────────────────────────────────────────────────────
  Future<void> addReaction(
      String houseId, String messageId, String senderRole, String emoji) async {
    final normalizedRole = senderRole == 'user2' ? 'user2' : 'user1';
    await _messagesRef(houseId)
        .doc(messageId)
        .update({'reactions.$normalizedRole': emoji});
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
  Future<void> migrateFromRTDB(String houseId) async {
    try {
      final snap =
          await _rtdb.child('houses/$houseId/chat_room/messages').get();
      if (!snap.exists || snap.value == null) return;
      final raw = snap.value;
      if (raw is! Map) return;

      // Kiểm tra xem Firestore đã có dữ liệu chưa (tránh migrate 2 lần)
      final existingCount = await _messagesRef(houseId).limit(1).get();
      if (existingCount.docs.isNotEmpty) return;

      final batch = _firestore.batch();
      int count = 0;
      raw.forEach((key, value) {
        if (value is Map) {
          final docRef = _messagesRef(houseId).doc(key.toString());
          batch.set(docRef, Map<String, dynamic>.from(value),
              SetOptions(merge: true));
          count++;
          // Firestore batch tối đa 500 operations
          if (count >= 490) return;
        }
      });

      if (count > 0) {
        await batch.commit();
        debugPrint(
            '[InternalChatService] Migrated $count messages for house $houseId');
      }
    } catch (e) {
      debugPrint(
          '[InternalChatService] Migration error: ${AppErrorMapper.resolve(e).message}');
    }
  }
}
