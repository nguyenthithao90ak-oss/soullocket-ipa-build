import 'package:soullocket_app/utils/ui_copy.dart';
import '../chat_message_policy.dart';
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/chat_message.dart';
import '../../models/group_chat_room.dart';
import '../group_room_list_stream.dart';
import 'chat_service.dart';
import 'package:soullocket_app/utils/rapid_action_feedback_policy.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'anti_spam_service.dart';

class GroupChatService {
  static final GroupChatService _instance = GroupChatService._internal();

  factory GroupChatService() => _instance;
  GroupChatService._internal();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _groupStreams = <String, Stream<List<GroupChatRoom>>>{};
  final AntiSpamRateLimitService _antiSpamRateLimitService =
      AntiSpamRateLimitService();

  String _sanitize(String input) =>
      input.replaceAll('<', '&lt;').replaceAll('>', '&gt;').trim();

  bool isHouseMemberOfGroup(GroupChatRoom room, String houseId) {
    final normalizedHouseId = houseId.trim();
    return normalizedHouseId.isNotEmpty &&
        room.memberHouseIds.contains(normalizedHouseId);
  }

  bool isGroupLastMessageUnreadForHouse(
    GroupChatRoom room, {
    required String viewerHouseId,
  }) {
    return isChatMetaUnreadForHouse(
      room.lastMessage,
      viewerHouseId: viewerHouseId,
    );
  }

  Map<String, dynamic> buildSharePreviewPayload({
    required String senderHouseId,
    required String text,
    String type = 'share',
    String? sourceId,
    String? sourceType,
  }) {
    final safeText = _sanitize(text);
    return <String, dynamic>{
      'senderId': senderHouseId.trim(),
      'text': safeText,
      'type': type.trim().isEmpty ? 'share' : type.trim(),
      'ts': ServerValue.timestamp,
      'isRead': false,
      if ((sourceId ?? '').trim().isNotEmpty) 'sourceId': sourceId!.trim(),
      if ((sourceType ?? '').trim().isNotEmpty)
        'sourceType': sourceType!.trim(),
    };
  }

  Future<GroupChatRoom> fetchGroupRoom(String groupId) async {
    final roomSnap = await _dbRef.child('groups/$groupId').get();
    if (!roomSnap.exists || roomSnap.value is! Map) {
      throw UiCopyException('copy_1f23998464f3');
    }
    return GroupChatRoom.fromMap(
      groupId,
      Map<dynamic, dynamic>.from(roomSnap.value as Map),
    );
  }

  Future<GroupChatRoom> requireMemberRoom({
    required String groupId,
    required String viewerHouseId,
  }) async {
    final room = await fetchGroupRoom(groupId);
    if (!isHouseMemberOfGroup(room, viewerHouseId)) {
      throw UiCopyException('copy_f5c8f262e423');
    }
    await _functions.httpsCallable('syncGroupChatAccess').call<void>(
      <String, dynamic>{'groupId': groupId.trim()},
    );
    return room;
  }

  void _detectSpam(String text) =>
      ChatMessagePolicy.validate(text, maxLength: 1500, scanLinks: false);

  Future<void> _enforceRateLimit(String actionKey) async {
    final allowed = await _antiSpamRateLimitService.checkRateLimit(
      action: actionKey,
      maxCalls: 6,
      timeWindowMs: 4000,
    );
    if (allowed) {
      return;
    }
    final cooldown = await _antiSpamRateLimitService.remainingCooldownSeconds;
    if (!shouldShowRapidActionWarningSeconds(cooldown)) {
      throw const SilentRapidActionBlockException();
    }
    if (cooldown >= 0) {
      throw UiCopyException('copy_d9661cb7655a');
    }
    throw Exception(
      cooldown > 0
          ? 'Bạn gửi quá nhanh. Vui lòng chờ $cooldown giây rồi thử lại.'
          : 'Bạn gửi quá nhanh. Vui lòng thử lại sau.',
    );
  }

  Future<GroupChatCreateResult> createGroup({
    required String houseId,
    required String name,
    required List<String> memberHouseIds,
    String? groupId,
  }) async {
    try {
      final callable = _functions.httpsCallable('createGroupChatSecure');
      final response = await callable.call(<String, dynamic>{
        'houseId': houseId.trim(),
        'name': name.trim(),
        'memberHouseIds': memberHouseIds,
        if ((groupId ?? '').trim().isNotEmpty) 'groupId': groupId!.trim(),
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final createdAtMs = data['createdAt'] is num
          ? (data['createdAt'] as num).toInt()
          : int.tryParse(data['createdAt']?.toString() ?? '') ?? 0;
      final updatedAtMs = data['updatedAt'] is num
          ? (data['updatedAt'] as num).toInt()
          : int.tryParse(data['updatedAt']?.toString() ?? '') ?? createdAtMs;
      return GroupChatCreateResult(
        groupId: data['groupId']?.toString().trim() ?? '',
        name: data['name']?.toString().trim().isNotEmpty == true
            ? data['name'].toString().trim()
            : UiCopy.text('copy_eb9036bf8765'),
        memberHouseIds: (data['memberHouseIds'] as List? ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs,
        alreadyExists: data['alreadyExists'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      throw UiCopyException('copy_e19477281240');
    }
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderHouseId,
    required String text,
    String type = 'text',
  }) async {
    final safeText = _sanitize(text);
    if (type == 'text' || type == 'sticker') {
      _detectSpam(safeText);
    }
    await _enforceRateLimit('group_chat_send_${groupId}_$senderHouseId');

    await requireMemberRoom(groupId: groupId, viewerHouseId: senderHouseId);

    final docRef = await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .add({
          'senderId': senderHouseId,
          'text': safeText,
          'type': type,
          'ts': DateTime.now().millisecondsSinceEpoch,
          'isRead': false,
        });
    final messageId = docRef.id;

    try {
      await _functions
          .httpsCallable('updateGroupChatMetadataSecure')
          .call<void>(<String, dynamic>{
            'action': 'last_message',
            'groupId': groupId.trim(),
            'messageId': messageId,
          });
    } catch (error) {
      // Tin nhắn đã được lưu ở Firestore; không báo thất bại để tránh gửi trùng.
      debugPrint(
        '[GroupChat] last message metadata sync failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể cập nhật bản xem trước tin nhắn nhóm.').message}',
      );
    }
  }

  Future<void> renameGroup({
    required String groupId,
    required String name,
    String? actorHouseId,
  }) async {
    final nextName = name.trim();
    if (nextName.isEmpty) {
      throw UiCopyException('copy_79fdef77def1');
    }
    if (nextName.length > 50) {
      throw UiCopyException('copy_f6be47a34bad');
    }
    if ((actorHouseId ?? '').trim().isNotEmpty) {
      await requireMemberRoom(
        groupId: groupId,
        viewerHouseId: actorHouseId!.trim(),
      );
    }
    try {
      await _functions
          .httpsCallable('updateGroupChatMetadataSecure')
          .call<void>(<String, dynamic>{
            'action': 'rename',
            'groupId': groupId.trim(),
            'name': nextName,
          });
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      throw UiCopyException('copy_f8aeb4013d6f');
    }
  }

  Future<void> reportGroup({
    required String groupId,
    required String reporterHouseId,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw UiCopyException('copy_afdd2528b4bd');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw UiCopyException('copy_6d0814fa4b91');
    }
    await requireMemberRoom(groupId: groupId, viewerHouseId: reporterHouseId);
    await FirebaseFirestore.instance.collection('reports').add({
      'type': 'group_report',
      'groupId': groupId.trim(),
      'target': groupId.trim(),
      'by': uid,
      'reporterHouseId': reporterHouseId.trim(),
      'reason': normalizedReason.length > 500
          ? normalizedReason.substring(0, 500)
          : normalizedReason,
      'status': 'open',
      'ts': FieldValue.serverTimestamp(),
    });
  }

  Future<List<ChatMessage>> fetchGroupMessagesPage(
    String groupId, {
    required String viewerHouseId,
    int limit = 40,
    int? beforeTs,
  }) async {
    await requireMemberRoom(groupId: groupId, viewerHouseId: viewerHouseId);
    var query = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .orderBy('ts', descending: true)
        .limit(limit);

    if (beforeTs != null) {
      query = query.where('ts', isLessThan: beforeTs);
    }

    try {
      final snap = await query.get().timeout(const Duration(seconds: 10));
      if (snap.docs.isEmpty) return const <ChatMessage>[];

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
    } on TimeoutException {
      return const <ChatMessage>[];
    }
  }

  Stream<ChatMessage> streamNewGroupMessages(
    String groupId, {
    required String viewerHouseId,
    int? afterTs,
  }) {
    late final StreamController<ChatMessage> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    StreamSubscription<DatabaseEvent>? membershipSub;

    // Listener chỉ dùng để bắt tin mới sau trang đầu. Khi trang đầu chưa có
    // mốc (ví dụ phòng mới hoặc lần đọc đầu bị lỗi), không được mở query từ
    // epoch vì Firestore sẽ replay toàn bộ lịch sử nhóm.
    const liveMessageLimit = 40;

    controller = StreamController<ChatMessage>(
      onListen: () async {
        try {
          await requireMemberRoom(
            groupId: groupId,
            viewerHouseId: viewerHouseId,
          );
        } catch (error) {
          controller.addError(error);
          return;
        }
        var query = FirebaseFirestore.instance
            .collection('group_chats')
            .doc(groupId)
            .collection('messages')
            .orderBy('ts');
        if (afterTs == null) {
          query = query.limitToLast(liveMessageLimit);
        } else {
          query = query
              .where('ts', isGreaterThan: afterTs)
              .limit(liveMessageLimit);
        }
        firestoreSub = query.snapshots().listen(
              (snapshot) {
                for (final change in snapshot.docChanges) {
                  if (change.type == DocumentChangeType.added ||
                      change.type == DocumentChangeType.modified) {
                    try {
                      final msg = ChatMessage.fromMap(
                        change.doc.id,
                        change.doc.data()!,
                      );
                      controller.add(msg);
                    } catch (error) {
                      debugPrint('[GroupChat] Bỏ qua tin nhắn lỗi: $error');
                    }
                  }
                }
              },
              onError: (Object error) {
                debugPrint(
                  '[GroupChat] firestore message stream failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể tải tin nhắn nhóm.').message}',
                );
              },
            );

        Timer? membershipDebounce;
        membershipSub = _dbRef
            .child('groups/$groupId/memberHouseIds')
            .onValue
            .listen(
              (event) {
                membershipDebounce?.cancel();
                membershipDebounce = Timer(
                  const Duration(milliseconds: 200),
                  () {
                    final raw = event.snapshot.value;
                    final nextMembers = <String>[];
                    if (raw is Map) {
                      for (final entry in raw.entries) {
                        final houseId = entry.key.toString().trim();
                        final enabled = entry.value == true || entry.value == 1;
                        if (houseId.isNotEmpty && enabled) {
                          nextMembers.add(houseId);
                        }
                      }
                    } else if (raw is List) {
                      for (final item in raw) {
                        final houseId = item.toString().trim();
                        if (houseId.isNotEmpty) {
                          nextMembers.add(houseId);
                        }
                      }
                    }
                    if (viewerHouseId.trim().isEmpty ||
                        nextMembers.contains(viewerHouseId.trim())) {
                      return;
                    }
                    controller.addError(UiCopyException('copy_f5c8f262e423'));
                  },
                );
              },
              onError: (Object error) {
                debugPrint(
                  '[GroupChat] membership stream failed: ${AppErrorMapper.resolve(error, fallbackMessage: 'Không thể tải danh sách thành viên nhóm.').message}',
                );
              },
            );
      },
      onCancel: () async {
        await firestoreSub?.cancel();
        await membershipSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<GroupChatRoom?> streamGroupRoom(String groupId) {
    return _dbRef.child('groups/$groupId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return null;
      }
      return GroupChatRoom.fromMap(
        event.snapshot.key ?? groupId,
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  Stream<List<GroupChatRoom>> streamGroupsForHouse(String houseId) {
    final normalized = houseId.trim();
    final uid = _auth.currentUser?.uid;
    if (uid == null ||
        normalized.isEmpty ||
        RegExp(r'[.#$\[\]/\\\s]').hasMatch(normalized)) {
      return Stream.value(const []);
    }
    final key = '$uid/$normalized';
    final existing = _groupStreams[key];
    if (existing != null) return existing;
    late final Stream<List<GroupChatRoom>> stream;
    stream = sharedGroupRoomList(
      index: _dbRef
          .child('houses/$normalized/group_ids')
          .limitToLast(20)
          .onValue
          .map((event) {
            final raw = event.snapshot.value;
            if (raw is! Map) return <String>[];
            return raw.entries
                .where((entry) => entry.value == true || entry.value == 1)
                .map((entry) => entry.key.toString())
                .toList()
              ..sort();
          }),
      watchRoom: (groupId) => streamGroupRoom(groupId).map(
        (room) => room != null && isHouseMemberOfGroup(room, normalized)
            ? room
            : null,
      ),
      revoked: _auth
          .authStateChanges()
          .where((user) => user?.uid != uid)
          .map<void>((_) {}),
      onIdle: () {
        if (identical(_groupStreams[key], stream)) _groupStreams.remove(key);
      },
    );
    _groupStreams[key] = stream;
    return stream;
  }
}
