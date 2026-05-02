// lib/models/chat_message.dart
class ChatMessage {
  final String id;
  final String senderId; // 'U1' hoặc 'U2'
  final String text; // Tương thích với UI cũ (Đổi content -> text)
  final String type; // 'text' hoặc 'image' hoặc 'voice'
  final DateTime timestamp; // Tương thích với UI cũ (Đổi int -> DateTime)
  final bool isRead;
  final String? replyToId; // ID của tin nhắn đang trả lời (vuốt để reply)
  final Map<String, String> reactions; // { userId: emoji }
  final String? callRoomId;
  final String? callMode;
  final String? sharedUrl;
  final String? storagePath;
  final DateTime? expiresAt;
  final String imageStatus;
  final DateTime? deletedAt;
  final String? deletedReason;
  final String? blurHash;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    required this.timestamp,
    this.isRead = false,
    this.replyToId,
    this.reactions = const {},
    this.callRoomId,
    this.callMode,
    this.sharedUrl,
    this.storagePath,
    this.expiresAt,
    this.imageStatus = '',
    this.deletedAt,
    this.deletedReason,
    this.blurHash,
  });

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    Map<String, String> parsedReactions = {};
    if (map['reactions'] is Map) {
      map['reactions'].forEach((k, v) {
        parsedReactions[k.toString()] = v.toString();
      });
    }

    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? 'U1',
      text: map['text'] ?? map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: map['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['ts'])
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      replyToId: map['replyTo'],
      reactions: parsedReactions,
      callRoomId: map['callRoomId']?.toString(),
      callMode: map['callMode']?.toString(),
      sharedUrl: map['sharedUrl']?.toString(),
      storagePath: map['storagePath']?.toString(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'])
          : null,
      imageStatus: map['imageStatus']?.toString() ?? '',
      deletedAt: map['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'])
          : null,
      deletedReason: map['deletedReason']?.toString(),
      blurHash: map['blurHash']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'ts': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      if (replyToId != null) 'replyTo': replyToId,
      if (reactions.isNotEmpty) 'reactions': reactions,
      if (callRoomId != null) 'callRoomId': callRoomId,
      if (callMode != null) 'callMode': callMode,
      if (sharedUrl != null) 'sharedUrl': sharedUrl,
      if (storagePath != null) 'storagePath': storagePath,
      if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
      if (imageStatus.trim().isNotEmpty) 'imageStatus': imageStatus.trim(),
      if (deletedAt != null) 'deletedAt': deletedAt!.millisecondsSinceEpoch,
      if (deletedReason != null) 'deletedReason': deletedReason,
      if (blurHash != null) 'blurHash': blurHash,
    };
  }

  bool get isImage => type == 'image';

  String get normalizedImageStatus {
    final normalized = imageStatus.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return isImage ? 'active' : '';
  }

  bool get hasActiveImage =>
      isImage && normalizedImageStatus == 'active' && text.trim().isNotEmpty;

  bool get isExpiredImage => isImage && normalizedImageStatus == 'expired';

  String get imageDisplayText {
    final normalizedDeletedReason = deletedReason?.trim().toLowerCase() ?? '';
    if (normalizedDeletedReason == 'ttl_expired' || isExpiredImage) {
      return 'Ảnh đã bị xóa sau 15 ngày';
    }
    if (isImage && normalizedImageStatus != 'active') {
      final fallback = text.trim();
      return fallback.isEmpty ? 'Ảnh không còn khả dụng' : fallback;
    }
    return text.trim();
  }
}
