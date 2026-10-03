import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SupportPendingSend {
  SupportPendingSend({required this.id, required Map<String, dynamic> payload})
    : payload = Map.unmodifiable(payload);

  final String id;
  final Map<String, dynamic> payload;
  String get text => payload['text'] as String;
  String get uid => payload['user_uid'] as String;
  String get ticketId => payload['ticket_id'] as String;

  Map<String, dynamic> replyPayload({
    required String text,
    required int timestamp,
  }) => {
    'text': text,
    'is_bot': true,
    'is_admin': false,
    'ticket_id': ticketId,
    'user_uid': uid,
    'in_reply_to': id,
    if (payload['session_id'] != null) 'session_id': payload['session_id'],
    'ts': timestamp,
  };

  bool matches(Map<String, dynamic>? receipt) =>
      receipt != null &&
      receipt['text'] == text &&
      receipt['user_uid'] == uid &&
      receipt['ticket_id'] == ticketId &&
      receipt['is_admin'] == false &&
      receipt['is_bot'] == false;
}

class SupportPendingSendStore {
  SupportPendingSendStore({
    required this.readValue,
    required this.writeValue,
    required this.deleteValue,
  });

  factory SupportPendingSendStore.secure() {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    return SupportPendingSendStore(
      readValue: (key) => storage.read(key: key),
      writeValue: (key, value) => storage.write(key: key, value: value),
      deleteValue: (key) => storage.delete(key: key),
    );
  }

  final Future<String?> Function(String) readValue;
  final Future<void> Function(String, String) writeValue;
  final Future<void> Function(String) deleteValue;

  String _key(String uid, String ticketId) =>
      'support_pending_v1_${sha256.convert(utf8.encode('$uid|$ticketId'))}';

  Future<SupportPendingSend?> read(String uid, String ticketId) async {
    final raw = await readValue(_key(uid, ticketId));
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map || value['payload'] is! Map) {
      throw const FormatException('Invalid support pending record');
    }
    final payload = Map<String, dynamic>.from(value['payload'] as Map);
    final id = value['id'];
    if (id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
        payload['user_uid'] != uid ||
        payload['ticket_id'] != ticketId ||
        payload['text'] is! String ||
        (payload['text'] as String).trim().isEmpty ||
        (payload['text'] as String).length > 5000 ||
        payload['is_bot'] != false ||
        payload['is_admin'] != false ||
        payload['ts'] is! int) {
      throw const FormatException('Invalid support pending scope');
    }
    return SupportPendingSend(id: id, payload: payload);
  }

  Future<void> save(SupportPendingSend pending) async {
    final old = await read(pending.uid, pending.ticketId);
    if (old != null && old.id != pending.id) {
      throw StateError('Support pending send already exists');
    }
    await writeValue(
      _key(pending.uid, pending.ticketId),
      jsonEncode({'id': pending.id, 'payload': pending.payload}),
    );
  }

  Future<void> clear(SupportPendingSend pending) async {
    final old = await read(pending.uid, pending.ticketId);
    if (old?.id == pending.id) {
      await deleteValue(_key(pending.uid, pending.ticketId));
    }
  }
}

Future<void> deliverSupportMessage({
  required SupportPendingSend pending,
  required bool Function() scopeIsCurrent,
  required Future<void> Function(SupportPendingSend) commit,
  required Future<Map<String, dynamic>?> Function() readReceipt,
}) async {
  void guard() {
    if (!scopeIsCurrent()) throw StateError('Support scope changed');
  }

  guard();
  await commit(pending);
  guard();
  final receipt = await readReceipt();
  guard();
  if (!pending.matches(receipt) || receipt?['source'] != 'firestore_user') {
    throw StateError('Support delivery not confirmed');
  }
}
