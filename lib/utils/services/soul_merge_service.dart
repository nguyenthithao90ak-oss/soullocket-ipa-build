import 'package:soullocket_app/utils/ui_copy.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'house_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';
import 'soul_message_history.dart';
import 'soul_message_actions.dart';
import 'soul_merge_role_stream.dart';
import 'package:soullocket_app/utils/services/core/presence_service.dart';

class SoulMergeService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();

  Future<String?> getCurrentHouseId() => _houseService.getCurrentHouseId();

  /// Report a physical bump event to Firebase using server time.
  /// Dùng role ('user1'/'user2') làm key thay vì uid vì 2 người dùng chung 1 uid.
  Future<void> reportBump() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));

      await _db
          .ref('houses/$houseId/soul_merge/$role')
          .set(ServerValue.timestamp);
    } catch (e) {
      debugPrint('[SoulMergeService] reportBump error: $e');
    }
  }

  /// Listen to the bump times of both partners (resolved by server time).
  /// Key trong map là role ('user1'/'user2').
  Stream<Map<String, int>> watchMergeTimes() {
    return SoulMergeRoleStream.watch(
      resolveHouseId: _houseService.getCurrentHouseId,
      watchRole: (houseId, role) => _db
          .ref('houses/$houseId/soul_merge/$role')
          .onValue
          .map((event) => event.snapshot.value),
    );
  }

  /// Clear the soul merge bump record của role hiện tại.
  Future<void> clearBumps() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));
      await _db.ref('houses/$houseId/soul_merge/$role').remove();
    } catch (e) {
      debugPrint('[SoulMergeService] clearBumps error: $e');
    }
  }

  /// Send a persistent message to the partner during Soul Merge
  Future<void> sendSoulMessage(
    String text, {
    String? imageUrl,
    String? replyTo,
    String? expectedHouseId,
    String? expectedUid,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const UiCopyException('copy_75305b3e544e');
      }

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) {
        throw const UiCopyException('copy_a889cd9f28dd');
      }

      if (_auth.currentUser?.uid != user.uid ||
          (expectedUid != null && expectedUid != user.uid) ||
          (expectedHouseId != null && expectedHouseId != houseId)) {
        throw StateError('Soul Merge scope changed');
      }
      if (replyTo != null && !SoulMessageActions.validId(replyTo)) {
        throw ArgumentError('Invalid reply target');
      }
      final trimmed = text.trim();
      if (trimmed.length > 2000) {
        throw const UiCopyException('copy_44fdfcf1695b');
      }

      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));

      if (_auth.currentUser?.uid != user.uid ||
          await getCurrentHouseId() != houseId ||
          _auth.currentUser?.uid != user.uid) {
        throw StateError('Soul Merge scope changed');
      }
      final ref = _db.ref('houses/$houseId/soul_merge/chat');
      await ref.push().set({
        if (trimmed.isNotEmpty) 'text': trimmed,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'sender': role,
        'senderUid': user.uid,
        'replyTo': ?replyTo,
        'timestamp': ServerValue.timestamp,
      });

      // Body của thông báo push
      final body = trimmed.isNotEmpty
          ? trimmed
          : (imageUrl != null
                ? UiCopy.text('copy_95645c3098ee')
                : UiCopy.text('copy_e3cebc8bff52'));

      // Lấy tên đúng từ house settings theo role của người gửi
      String myName = UiCopy.text('copy_145933221191');
      try {
        final settingsSnap = await _db.ref('houses/$houseId/settings').get();
        if (settingsSnap.exists && settingsSnap.value is Map) {
          final settings = settingsSnap.value as Map<dynamic, dynamic>;
          final nameKey = role == 'user2' ? 'nameU2' : 'nameU1';
          final nameFromSettings = (settings[nameKey] as String?)?.trim();
          if (nameFromSettings != null && nameFromSettings.isNotEmpty) {
            myName = nameFromSettings;
          } else {
            // fallback: displayName của Firebase Auth
            final dn = _auth.currentUser?.displayName?.trim();
            if (dn != null && dn.isNotEmpty) myName = dn;
          }
        }
      } catch (error) {
        debugPrint('[SoulMergeService] Cannot resolve sender name: $error');
      }

      unawaited(
        NotificationService()
            .sendPartnerNotification(
              houseId: houseId,
              title: 'Soul Merge',
              body: body,
              data: {'type': 'soul_merge', 'senderName': myName},
            )
            .catchError((Object error) {
              debugPrint(
                '[SoulMergeService] Notification failed: ${error.runtimeType}',
              );
            }),
      );
    } catch (e) {
      debugPrint('[SoulMergeService] sendSoulMessage error: $e');
      rethrow;
    }
  }

  Future<void> _requireMessageScope(
    String houseId,
    String expectedUid,
    String messageId,
  ) async {
    if (!SoulMessageActions.validId(messageId)) {
      throw ArgumentError('Invalid message id');
    }
    if (houseId.isEmpty ||
        _auth.currentUser?.uid != expectedUid ||
        await getCurrentHouseId() != houseId ||
        _auth.currentUser?.uid != expectedUid) {
      throw StateError('Soul Merge scope changed');
    }
  }

  Future<void> setSoulReaction({
    required String houseId,
    required String expectedUid,
    required String messageId,
    required String reaction,
  }) async {
    if (!SoulMessageActions.validReaction(reaction)) {
      throw ArgumentError('Invalid reaction');
    }
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db
        .ref(
          'houses/$houseId/soul_merge/chat/$messageId/reactions/$expectedUid',
        )
        .set(reaction);
  }

  Future<void> removeSoulReaction({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db
        .ref(
          'houses/$houseId/soul_merge/chat/$messageId/reactions/$expectedUid',
        )
        .remove();
  }

  Future<void> hideSoulMessage({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db
        .ref(
          'houses/$houseId/soul_merge/chat/$messageId/hiddenFor/$expectedUid',
        )
        .set(true);
  }

  /// Rules chỉ cho UID sở hữu xóa tin với cả hai.
  Future<void> deleteSoulMessage({
    required String houseId,
    required String expectedUid,
    required String messageId,
  }) async {
    await _requireMessageScope(houseId, expectedUid, messageId);
    await _db.ref('houses/$houseId/soul_merge/chat/$messageId').remove();
  }

  Stream<Map<String, dynamic>?> watchSoulMessage(
    String houseId,
    String messageId,
  ) {
    if (!SoulMessageActions.validId(messageId)) return const Stream.empty();
    return _db.ref('houses/$houseId/soul_merge/chat/$messageId').onValue.map((
      event,
    ) {
      final raw = event.snapshot.value;
      return raw is Map
          ? <String, dynamic>{
              ...Map<String, dynamic>.from(raw),
              'id': messageId,
            }
          : null;
    });
  }

  /// Watch the latest page of persistent messages in Soul Merge
  Stream<List<Map<String, dynamic>>> watchSoulMessages({String? houseId}) {
    return Stream.fromFuture(
      houseId == null
          ? _houseService.getCurrentHouseId()
          : Future.value(houseId),
    ).asyncExpand<List<Map<String, dynamic>>>((houseId) {
      if (houseId == null || houseId.isEmpty) return const Stream.empty();
      return SoulMessageHistory.page(
        _db.ref('houses/$houseId/soul_merge/chat'),
      ).onValue.map((event) => _readSoulMessages(event.snapshot));
    });
  }

  Future<List<Map<String, dynamic>>> loadOlderSoulMessages({
    required String houseId,
    required SoulMessageCursor before,
  }) async {
    final snapshot = await SoulMessageHistory.page(
      _db.ref('houses/$houseId/soul_merge/chat'),
      before: before,
    ).get();
    return _readSoulMessages(snapshot);
  }

  List<Map<String, dynamic>> _readSoulMessages(DataSnapshot snapshot) {
    final messages = <Map<String, dynamic>>[];
    for (final child in snapshot.children) {
      if (child.value is Map && child.key != null) {
        final message = Map<String, dynamic>.from(child.value as Map);
        if (message['timestamp'] != null && message['timestamp'] is! num) {
          continue;
        }
        message['id'] = child.key;
        message['timestamp'] = (message['timestamp'] as num?)?.toInt() ?? 0;
        messages.add(message);
      }
    }
    return messages..sort(SoulMessageHistory.compareMessages);
  }

  Stream<Map<String, dynamic>> watchSoulBackground(String houseId) => _db
      .ref('houses/$houseId/soul_merge/background')
      .onValue
      .map(
        (event) => event.snapshot.value is Map
            ? Map<String, dynamic>.from(event.snapshot.value as Map)
            : <String, dynamic>{},
      );

  Future<void> saveSoulBackground(
    String houseId, {
    String? url,
    String? storagePath,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null ||
        await getCurrentHouseId() != houseId ||
        _auth.currentUser?.uid != uid) {
      throw StateError('Soul Merge scope changed');
    }
    await _db
        .ref('houses/$houseId/soul_merge/background')
        .set(
          url == null
              ? null
              : {
                  'url': url,
                  'storagePath': storagePath,
                  'updatedAt': ServerValue.timestamp,
                },
        );
  }

  /// Clear all messages under the soul_merge/chat node (No-op now to preserve history)
  Future<void> clearChat() async {}

  /// Cập nhật timestamp tin nhắn đã xem cuối cùng lên Firebase
  Future<void> updateLastSeenTimestamp(int timestamp) async {
    try {
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));
      await _db.ref('houses/$houseId/soul_merge/lastSeen/$role').set(timestamp);
    } catch (e) {
      debugPrint('[SoulMergeService] updateLastSeenTimestamp error: $e');
    }
  }

  /// Lấy timestamp tin nhắn đã xem cuối cùng từ Firebase
  Future<int> getLastSeenTimestamp() async {
    try {
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return 0;
      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));
      final snap = await _db
          .ref('houses/$houseId/soul_merge/lastSeen/$role')
          .get();
      return (snap.value as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[SoulMergeService] getLastSeenTimestamp error: $e');
      return 0;
    }
  }

  /// Send an interactive event (e.g. photo shot or heart tap) to the partner
  Future<void> sendInteractiveEvent({
    required String type,
    String? url,
    double? x,
    double? y,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));

      final oppositeRole = role == 'user1' ? 'user2' : 'user1';
      final presenceSnap = await _db
          .ref('houses/$houseId/presence/$oppositeRole')
          .get();
      final presenceData = presenceSnap.value as Map<dynamic, dynamic>?;

      // Nếu người kia offline, ta không cần gửi event vì đằng nào họ cũng không thấy được (event realtime)
      // Điều này giúp tiết kiệm lượt ghi/đọc (bandwidth) đáng kể cho Firebase.
      if (!PresenceService.isPresenceOnline(presenceData)) {
        return;
      }

      final ref = _db.ref('houses/$houseId/soul_merge/interactive_events');
      await ref.push().set({
        'type': type,
        'url': url ?? '',
        'x': x ?? 0.0,
        'y': y ?? 0.0,
        'sender': role,
        'timestamp': ServerValue.timestamp,
      });

      // Prune old events to keep lightweight
      final snap = await ref.orderByChild('timestamp').get();
      if (snap.exists && snap.value is Map) {
        final events = Map<dynamic, dynamic>.from(snap.value as Map);
        if (events.length > 20) {
          final sortedKeys = events.keys.toList()
            ..sort((a, b) {
              final t1 = events[a]['timestamp'] as int? ?? 0;
              final t2 = events[b]['timestamp'] as int? ?? 0;
              return t1.compareTo(t2);
            });
          final keysToDelete = sortedKeys.sublist(0, sortedKeys.length - 20);
          for (final key in keysToDelete) {
            await ref.child(key.toString()).remove();
          }
        }
      }
    } catch (e) {
      debugPrint('[SoulMergeService] sendInteractiveEvent error: $e');
    }
  }

  /// Watch real-time interactive events
  Stream<Map<String, dynamic>> watchInteractiveEvents() {
    return Stream.fromFuture(
      _houseService.getCurrentHouseId(),
    ).asyncExpand<Map<String, dynamic>>((houseId) {
      if (houseId == null || houseId.isEmpty) return const Stream.empty();

      final now = DateTime.now().millisecondsSinceEpoch;

      return _db
          .ref('houses/$houseId/soul_merge/interactive_events')
          .orderByChild('timestamp')
          .startAt(now)
          .limitToLast(20)
          .onChildAdded
          .map((event) {
            final data = event.snapshot.value;
            if (data is Map) {
              final msg = Map<String, dynamic>.from(data);
              msg['id'] = event.snapshot.key;
              return msg;
            }
            return <String, dynamic>{};
          });
    });
  }

  /// Khởi chạy đồng bộ Widget Soul Merge chủ động
  Future<void> syncSoulMergeWidgetNow() async {
    try {
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final myRole = _normalizeRole(prefs.getString('il_role'));
      final partnerRole = myRole == 'user1' ? 'user2' : 'user1';

      // 1. Get Partner Name
      final profileSnapshots = await Future.wait([
        _db.ref('houses/$houseId/users').get(),
        _db.ref('houses/$houseId/settings').get(),
      ]);
      final users = profileSnapshots[0].value as Map<dynamic, dynamic>?;
      String partnerName = UiCopy.text('copy_145933221191');
      if (users != null && users[partnerRole] != null) {
        final partnerInfo = users[partnerRole] as Map<dynamic, dynamic>;
        partnerName =
            (partnerInfo['name'] as String?)?.trim() ??
            UiCopy.text('copy_145933221191');
        if (partnerName.isEmpty) partnerName = UiCopy.text('copy_145933221191');
      }

      // 2. Get house settings for names
      final settingsData = profileSnapshots[1].value as Map<dynamic, dynamic>?;
      final nameU1 = (settingsData?['nameU1'] as String?)?.trim();
      final nameU2 = (settingsData?['nameU2'] as String?)?.trim();

      // Helper lấy tên theo role
      String nameForRole(String r) {
        if (r == 'user2') {
          return (nameU2 != null && nameU2.isNotEmpty)
              ? nameU2
              : UiCopy.text('copy_145933221191');
        }
        return (nameU1 != null && nameU1.isNotEmpty)
            ? nameU1
            : UiCopy.text('copy_145933221191');
      }

      // 3. Get Latest Message
      final chatSnap = await _db
          .ref('houses/$houseId/soul_merge/chat')
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      String message = UiCopy.text('copy_10b2526771ce');
      String senderName = nameForRole(partnerRole); // default: partner
      if (chatSnap.exists && chatSnap.value is Map) {
        final chatData = chatSnap.value as Map<dynamic, dynamic>;
        if (chatData.isNotEmpty) {
          final msgData = chatData.values.first as Map<dynamic, dynamic>;
          final text = msgData['text'] as String?;
          final imageUrl = msgData['imageUrl'] as String?;
          final sender = (msgData['sender'] as String?)?.trim() ?? partnerRole;
          // Lấy tên đúng của người gửi tin nhắn đó
          senderName = nameForRole(sender);
          if (!SoulMessageActions.visibleTo(
            Map<String, dynamic>.from(msgData),
            _auth.currentUser?.uid,
          )) {
            message = UiCopy.text('copy_10b2526771ce');
          } else if (text != null && text.trim().isNotEmpty) {
            message = text.trim();
          } else if (imageUrl != null && imageUrl.isNotEmpty) {
            message = UiCopy.text('copy_95645c3098ee');
          }
        }
      }

      // 4. Sync to Widget
      await WidgetService.syncSoulMergeWidgetData(
        message: message,
        senderName: senderName,
      );
    } catch (e) {
      debugPrint('[SoulMergeService] syncSoulMergeWidgetNow error: $e');
    }
  }

  String _normalizeRole(String? raw) {
    return raw?.trim() == 'user2' ? 'user2' : 'user1';
  }
}
