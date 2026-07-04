import 'package:soullocket_app/utils/services/l10n_service.dart';

class GroupChatRoom {
  final String id;
  final String name;
  final List<String> memberHouseIds;
  final Map<String, dynamic>? lastMessage;
  final int createdAtMs;
  final int updatedAtMs;
  final String createdByHouseId;
  final String createdByUid;

  const GroupChatRoom({
    required this.id,
    required this.name,
    required this.memberHouseIds,
    this.lastMessage,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.createdByHouseId = '',
    this.createdByUid = '',
  });

  factory GroupChatRoom.fromMap(String id, Map<dynamic, dynamic> raw) {
    final memberHouseIds = <String>[];
    final rawMemberHouseIds = raw['memberHouseIds'];
    if (rawMemberHouseIds is Map) {
      for (final entry in rawMemberHouseIds.entries) {
        final houseId = entry.key.toString().trim();
        final enabled = entry.value == true || entry.value == 1;
        if (houseId.isNotEmpty && enabled) {
          memberHouseIds.add(houseId);
        }
      }
    } else if (rawMemberHouseIds is List) {
      for (final item in rawMemberHouseIds) {
        final houseId = item.toString().trim();
        if (houseId.isNotEmpty) {
          memberHouseIds.add(houseId);
        }
      }
    }

    Map<String, dynamic>? lastMessage;
    final rawLastMessage = raw['lastMessage'];
    if (rawLastMessage is Map) {
      lastMessage = Map<String, dynamic>.from(
        rawLastMessage.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    int readInt(dynamic value) {
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    memberHouseIds.sort();

    return GroupChatRoom(
      id: id,
      name: (raw['name']?.toString().trim().isNotEmpty ?? false)
          ? raw['name'].toString().trim()
          : L10nService().translate('chat_group_default_name'),
      memberHouseIds: memberHouseIds,
      lastMessage: lastMessage,
      createdAtMs: readInt(raw['createdAt']),
      updatedAtMs: readInt(raw['updatedAt']),
      createdByHouseId: raw['createdByHouseId']?.toString().trim() ?? '',
      createdByUid: raw['createdByUid']?.toString().trim() ?? '',
    );
  }

  int get sortTimestamp {
    final lastTs = lastMessage?['ts'];
    if (lastTs is num && lastTs.toInt() > 0) {
      return lastTs.toInt();
    }
    if (updatedAtMs > 0) {
      return updatedAtMs;
    }
    return createdAtMs;
  }

  bool get hasMessages {
    final text = lastMessage?['text']?.toString().trim() ?? '';
    return text.isNotEmpty;
  }
}

class GroupChatCreateResult {
  final String groupId;
  final String name;
  final List<String> memberHouseIds;
  final int createdAtMs;
  final int updatedAtMs;
  final bool alreadyExists;

  const GroupChatCreateResult({
    required this.groupId,
    required this.name,
    required this.memberHouseIds,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.alreadyExists = false,
  });
}
