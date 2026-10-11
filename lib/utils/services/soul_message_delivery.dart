import 'package:flutter/foundation.dart';

bool soulMessageIsSelf(
  Map<String, dynamic> message,
  String? uid,
  String role,
) => message['senderUid'] is String && uid != null
    ? message['senderUid'] == uid
    : message['sender'] == role;

/// Chỉ công nhận biên nhận của người còn lại, theo cursor của tin đã nhìn thấy.
bool soulMessageWasSeen(
  Map<String, dynamic> message,
  Map<String, dynamic> receipts,
) {
  final sender = message['senderUid'];
  final timestamp = message['timestamp'];
  final id = message['id'];
  if (sender is! String || timestamp is! num || id is! String) return false;
  for (final entry in receipts.entries) {
    final receipt = entry.value;
    if (entry.key == sender ||
        receipt is! Map ||
        receipt['role'] == message['sender']) {
      continue;
    }
    final time = receipt['timestamp'];
    final cursorId = receipt['messageId'];
    if (time is num &&
        cursorId is String &&
        (time > timestamp ||
            (time == timestamp && cursorId.compareTo(id) >= 0))) {
      return true;
    }
  }
  return false;
}

enum SoulDeliveryState { sending, failed, sent }

class SoulPendingMessage {
  SoulPendingMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.uid,
    required this.timestamp,
    this.imageUrl,
    this.replyTo,
    this.draft,
    this.state = SoulDeliveryState.sending,
  });
  final String id, text, role, uid;
  final int timestamp;
  final String? imageUrl, replyTo, draft;
  SoulDeliveryState state;

  bool matches(String value, String? image, String? reply) =>
      text == value && imageUrl == image && replyTo == reply;
  Map<String, dynamic> get message => {
    'id': id,
    'text': text,
    'sender': role,
    'senderUid': uid,
    'timestamp': timestamp,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (replyTo != null) 'replyTo': replyTo,
    '__delivery': state.name,
  };
  Map<String, dynamic> toJson() => {
    ...message,
    if (draft != null) '__draft': draft,
  };
  static SoulPendingMessage? restore(Object? raw, String expectedUid) {
    if (raw is! Map ||
        raw['senderUid'] != expectedUid ||
        raw['id'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(raw['id']) ||
        raw['text'] is! String ||
        raw['timestamp'] is! int ||
        (raw['sender'] != 'user1' && raw['sender'] != 'user2')) {
      return null;
    }
    return SoulPendingMessage(
      id: raw['id'],
      text: raw['text'],
      role: raw['sender'],
      uid: expectedUid,
      timestamp: raw['timestamp'],
      imageUrl: raw['imageUrl'] as String?,
      replyTo: raw['replyTo'] as String?,
      draft: raw['__draft'] as String?,
      state: raw['__delivery'] == 'sent'
          ? SoulDeliveryState.sent
          : SoulDeliveryState.failed,
    );
  }
}

/// Pending và echo realtime được gộp theo cùng ID; echo chưa chứng minh server đã nhận.
class SoulMessageOutbox extends ChangeNotifier {
  final Map<String, SoulPendingMessage> _entries = {};
  List<SoulPendingMessage> get entries =>
      _entries.values.toList(growable: false);
  SoulPendingMessage? operator [](String id) => _entries[id];
  void add(SoulPendingMessage message) {
    _entries[message.id] = message;
    notifyListeners();
  }

  void setState(String id, SoulDeliveryState state) {
    final m = _entries[id];
    if (m != null) {
      m.state = state;
      notifyListeners();
    }
  }

  void reconcile(List<Map<String, dynamic>> history) {
    final ids = history.map((m) => m['id']).toSet();
    _entries.removeWhere(
      (id, m) => m.state == SoulDeliveryState.sent && ids.contains(id),
    );
  }

  List<Map<String, dynamic>> merge(List<Map<String, dynamic>> history) {
    final all = {for (final m in history) m['id'].toString(): m};
    for (final m in entries) {
      all[m.id] = {...m.message, ...?all[m.id], '__delivery': m.state.name};
    }
    return all.values.toList()..sort((a, b) {
      final t = (a['timestamp'] as num).compareTo(b['timestamp'] as num);
      return t != 0 ? t : a['id'].toString().compareTo(b['id'].toString());
    });
  }
}
