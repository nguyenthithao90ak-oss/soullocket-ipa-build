import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../models/chat_message.dart';
import '../../models/group_chat_room.dart';
import 'chat_service.dart';
import 'package:soullocket_app/utils/rapid_action_feedback_policy.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'anti_spam_service.dart';

class GroupChatService {
  static final GroupChatService _instance = GroupChatService._internal();

  factory GroupChatService() => _instance;
  GroupChatService._internal();

  static final RegExp _repeatCharRegex = RegExp(r'(.)\1{11,}');
  static final RegExp _repeatWordRegex = RegExp(
    r'\b([^\s]+)\b(?:\s+\1\b){5,}',
    caseSensitive: false,
  );
  static final List<String> _blockedPhrases = <String>[
    'lừa đảo',
    'chiếm đoạt',
    'phishing',
    'hack',
    'malware',
    'spam',
    'bitch',
    'fuck',
  ];

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AntiSpamRateLimitService _antiSpamRateLimitService =
      AntiSpamRateLimitService();

  String _sanitize(String input) =>
      input.replaceAll('<', '&lt;').replaceAll('>', '&gt;').trim();

  Map<String, dynamic> _buildGroupMessagePayload({
    required String senderHouseId,
    required String text,
    required String type,
    required Object timestampValue,
  }) {
    return <String, dynamic>{
      'senderId': senderHouseId,
      'text': text,
      'type': type,
      'ts': timestampValue,
      'isRead': false,
    };
  }

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
      throw Exception('Nhóm chat không còn tồn tại.');
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
      throw Exception('Bạn không còn là thành viên của nhóm này.');
    }
    return room;
  }

  void _detectSpam(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('Tin nhắn trống');
    }
    if (trimmed.length > 1500) {
      throw Exception('Tin nhắn quá dài');
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final phrase in _blockedPhrases) {
      if (normalized.contains(phrase)) {
        throw Exception('Tin nhắn vi phạm tiêu chuẩn cộng đồng');
      }
    }

    if (_repeatCharRegex.hasMatch(normalized) ||
        _repeatWordRegex.hasMatch(normalized)) {
      throw Exception('Tin nhắn có dấu hiệu spam lặp lại');
    }
  }

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
      throw Exception('Bạn gửi hơi nhanh. Vui lòng chờ một lát rồi thử lại.');
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
            : 'Nhóm chat',
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
      throw Exception('Không thể tạo nhóm chat lúc này.');
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

    await requireMemberRoom(
      groupId: groupId,
      viewerHouseId: senderHouseId,
    );

    final pushRef = _dbRef.child('groups/$groupId/messages').push();
    final messageId = pushRef.key ?? '';
    const serverTimestamp = ServerValue.timestamp;
    final messagePayload = _buildGroupMessagePayload(
      senderHouseId: senderHouseId,
      text: safeText,
      type: type,
      timestampValue: serverTimestamp,
    );
    final lastMessagePayload = <String, dynamic>{
      ...messagePayload,
      if (messageId.isNotEmpty) 'messageId': messageId,
    };

    await _dbRef.update({
      'groups/$groupId/messages/$messageId': messagePayload,
      'groups/$groupId/lastMessage': lastMessagePayload,
      'groups/$groupId/updatedAt': serverTimestamp,
    });
  }

  Future<void> renameGroup({
    required String groupId,
    required String name,
    String? actorHouseId,
  }) async {
    final nextName = name.trim();
    if (nextName.isEmpty) {
      throw Exception('Tên nhóm không được để trống.');
    }
    if (nextName.length > 50) {
      throw Exception('Tên nhóm tối đa 50 ký tự.');
    }
    if ((actorHouseId ?? '').trim().isNotEmpty) {
      await requireMemberRoom(
        groupId: groupId,
        viewerHouseId: actorHouseId!.trim(),
      );
    }
    await _dbRef.child('groups/$groupId').update({
      'name': nextName,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> reportGroup({
    required String groupId,
    required String reporterHouseId,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw Exception(
          'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thử tiếp.');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Hãy chọn lý do báo cáo.');
    }
    await requireMemberRoom(
      groupId: groupId,
      viewerHouseId: reporterHouseId,
    );
    await _dbRef.child('reports').push().set({
      'type': 'group_report',
      'groupId': groupId.trim(),
      'target': groupId.trim(),
      'by': uid,
      'reporterHouseId': reporterHouseId.trim(),
      'reason': normalizedReason.length > 500
          ? normalizedReason.substring(0, 500)
          : normalizedReason,
      'status': 'open',
      'ts': ServerValue.timestamp,
    });
  }

  Future<List<ChatMessage>> fetchGroupMessagesPage(
    String groupId, {
    required String viewerHouseId,
    int limit = 40,
    String? endBeforeKey,
  }) async {
    await requireMemberRoom(
      groupId: groupId,
      viewerHouseId: viewerHouseId,
    );
    Query query = _dbRef.child('groups/$groupId/messages').orderByKey();
    final fetchLimit = endBeforeKey == null ? limit : limit + 1;
    if (endBeforeKey != null && endBeforeKey.isNotEmpty) {
      query = query.endAt(endBeforeKey);
    }

    final snap = await query.limitToLast(fetchLimit).get();
    if (!snap.exists || snap.value is! Map) {
      return const <ChatMessage>[];
    }

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final messages = <ChatMessage>[];
    data.forEach((key, value) {
      if (value is Map) {
        messages.add(ChatMessage.fromMap(key.toString(), value));
      }
    });

    if (endBeforeKey != null && endBeforeKey.isNotEmpty) {
      messages.removeWhere((message) => message.id == endBeforeKey);
    }

    messages.sort((a, b) {
      final byTime = b.timestamp.compareTo(a.timestamp);
      if (byTime != 0) {
        return byTime;
      }
      return b.id.compareTo(a.id);
    });

    return messages.length > limit ? messages.sublist(0, limit) : messages;
  }

  Stream<ChatMessage> streamNewGroupMessages(
    String groupId, {
    required String viewerHouseId,
    String? afterKey,
  }) {
    late final StreamController<ChatMessage> controller;
    StreamSubscription<ChatMessage>? addedSub;
    StreamSubscription<ChatMessage>? changedSub;

    ChatMessage readMessage(DatabaseEvent event) {
      final raw = event.snapshot.value;
      if (raw is! Map) {
        throw StateError('Tin nhắn nhóm không hợp lệ');
      }
      return ChatMessage.fromMap(
        event.snapshot.key ?? '',
        Map<dynamic, dynamic>.from(raw),
      );
    }

    late final StreamSubscription<DatabaseEvent> membershipSub;
    Query query = _dbRef.child('groups/$groupId/messages').orderByKey();
    if (afterKey != null && afterKey.isNotEmpty) {
      query = query.startAt(afterKey);
    }

    controller = StreamController<ChatMessage>(
      onListen: () {
        Timer? addedDebounce;
        Timer? changedDebounce;
        addedSub = query.onChildAdded.map(readMessage).listen(
          (msg) {
            addedDebounce?.cancel();
            addedDebounce = Timer(const Duration(milliseconds: 150), () {
              controller.add(msg);
            });
          },
          onError: (Object error) {
            debugPrint(
              '[GroupChat] message add stream failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể tải tin nhắn nhóm.',
              ).message}',
            );
          },
        );
        changedSub = query.onChildChanged.map(readMessage).listen(
          (msg) {
            changedDebounce?.cancel();
            changedDebounce = Timer(const Duration(milliseconds: 150), () {
              controller.add(msg);
            });
          },
          onError: (Object error) {
            debugPrint(
              '[GroupChat] message change stream failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể cập nhật tin nhắn nhóm.',
              ).message}',
            );
          },
        );
        Timer? membershipDebounce;
        membershipSub =
            _dbRef.child('groups/$groupId/memberHouseIds').onValue.listen((
          event,
        ) {
          membershipDebounce?.cancel();
          membershipDebounce = Timer(const Duration(milliseconds: 200), () {
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
          controller
              .addError(Exception('Bạn không còn là thành viên của nhóm này.'));
        });
      },
      onError: (Object error) {
          debugPrint(
            '[GroupChat] membership stream failed: ${AppErrorMapper.resolve(
              error,
              fallbackMessage: 'Không thể tải danh sách thành viên nhóm.',
            ).message}',
          );
        });
      },
      onCancel: () async {
        await membershipSub.cancel();
        await addedSub?.cancel();
        await changedSub?.cancel();
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
    late final StreamController<List<GroupChatRoom>> controller;
    StreamSubscription<DatabaseEvent>? indexSub;
    final Map<String, StreamSubscription<DatabaseEvent>> groupSubs =
        <String, StreamSubscription<DatabaseEvent>>{};
    final Map<String, GroupChatRoom> groups = <String, GroupChatRoom>{};
    Timer? emitDebounce;

    void emit() {
      if (controller.isClosed) {
        return;
      }
      emitDebounce?.cancel();
      emitDebounce = Timer(const Duration(milliseconds: 200), () {
        if (controller.isClosed) return;
        final items = groups.values.toList()
          ..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
        controller.add(items);
      });
    }

    Future<void> syncGroupSubscriptions(List<String> nextIds) async {
      final nextSet = nextIds.toSet();

      final removedIds = groupSubs.keys.where((id) => !nextSet.contains(id));
      for (final groupId in removedIds.toList()) {
        await groupSubs.remove(groupId)?.cancel();
        groups.remove(groupId);
      }

      for (final groupId in nextIds) {
        if (groupSubs.containsKey(groupId)) {
          continue;
        }
        groupSubs[groupId] = _dbRef.child('groups/$groupId').onValue.listen(
          (event) {
            if (!event.snapshot.exists || event.snapshot.value is! Map) {
              groups.remove(groupId);
              emit();
              return;
            }
            groups[groupId] = GroupChatRoom.fromMap(
              event.snapshot.key ?? groupId,
              Map<dynamic, dynamic>.from(event.snapshot.value as Map),
            );
            emit();
          },
          onError: (Object error) {
            debugPrint(
                '[GroupChat] group room stream failed: ${AppErrorMapper.resolve(
              error,
              fallbackMessage: 'Không thể tải phòng chat nhóm.',
            ).message}');
          },
        );
      }

      emit();
    }

    controller = StreamController<List<GroupChatRoom>>(
      onListen: () {
        indexSub = _dbRef.child('houses/$houseId/group_ids').onValue.listen(
          (event) {
            final ids = <String>[];
            final raw = event.snapshot.value;
            if (raw is Map) {
              for (final entry in raw.entries) {
                final groupId = entry.key.toString().trim();
                final enabled = entry.value == true || entry.value == 1;
                if (groupId.isNotEmpty && enabled) {
                  ids.add(groupId);
                }
              }
            }
            ids.sort();
            unawaited(syncGroupSubscriptions(ids));
          },
          onError: (Object error) {
            debugPrint(
              '[GroupChat] group index stream failed: ${AppErrorMapper.resolve(
                error,
                fallbackMessage: 'Không thể tải chỉ mục nhóm.',
              ).message}',
            );
          },
        );
      },
      onCancel: () async {
        await indexSub?.cancel();
        for (final sub in groupSubs.values) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }
}
