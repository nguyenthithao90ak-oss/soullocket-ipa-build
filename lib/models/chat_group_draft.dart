import 'package:soullocket_app/views/chat/chat_message_preview.dart' show repairMojibakeText;

class ChatGroupDraft {
  final String id;
  final String name;
  final List<String> memberHouseIds;
  final int createdAtMs;

  const ChatGroupDraft({
    required this.id,
    required this.name,
    required this.memberHouseIds,
    required this.createdAtMs,
  });

  ChatGroupDraft copyWith({
    String? id,
    String? name,
    List<String>? memberHouseIds,
    int? createdAtMs,
  }) {
    return ChatGroupDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      memberHouseIds: memberHouseIds ?? this.memberHouseIds,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  factory ChatGroupDraft.fromJson(Map<String, dynamic> json) {
    final nameVal = json['name']?.toString().trim() ?? '';
    final name = nameVal.isNotEmpty ? repairMojibakeText(nameVal) : 'Nhóm mới';
    return ChatGroupDraft(
      id: json['id']?.toString() ?? '',
      name: name,
      memberHouseIds: (json['memberHouseIds'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      createdAtMs: json['createdAtMs'] is num
          ? (json['createdAtMs'] as num).toInt()
          : int.tryParse(json['createdAtMs']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'memberHouseIds': memberHouseIds,
      'createdAtMs': createdAtMs,
    };
  }
}
