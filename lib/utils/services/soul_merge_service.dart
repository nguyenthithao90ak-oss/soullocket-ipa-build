import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'house_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';
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
    return Stream.fromFuture(
      _houseService.getCurrentHouseId(),
    ).asyncExpand<Map<String, int>>((houseId) {
      if (houseId == null || houseId.isEmpty) return const Stream.empty();
      return _db
          .ref('houses/$houseId/soul_merge')
          .onValue
          .asBroadcastStream()
          .map((event) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data == null) return const <String, int>{};

            final map = <String, int>{};
            data.forEach((key, value) {
              final keyStr = key.toString();
              // Chỉ nhận key hợp lệ là role
              if (keyStr != 'user1' && keyStr != 'user2') return;
              if (value is int) {
                map[keyStr] = value;
              } else if (value is num) {
                map[keyStr] = value.toInt();
              }
            });
            return map;
          });
    }).asBroadcastStream();
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

  /// Send a temporary message to the partner during Soul Merge
  Future<void> sendSoulMessage(String text, {String? imageUrl}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Chưa đăng nhập tài khoản.');
      }

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) {
        throw Exception('Không tìm thấy mã nhà hoặc chưa ghép nối.');
      }

      final trimmed = text.trim();
      if (trimmed.length > 2000) {
        throw Exception('Tin nhắn vượt quá giới hạn 2000 ký tự.');
      }

      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));

      final ref = _db.ref('houses/$houseId/soul_merge/chat');
      await ref.push().set({
        if (trimmed.isNotEmpty) 'text': trimmed,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'sender': role,
        'timestamp': ServerValue.timestamp,
      });

      // Body của thông báo push
      final body = trimmed.isNotEmpty
          ? trimmed
          : (imageUrl != null
                ? 'Đã gửi một ảnh'
                : 'Đã thì thầm với bạn trong Soul Merge 💕');

      // Lấy tên đúng từ house settings theo role của người gửi
      String myName = 'Người ấy';
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

      NotificationService().sendPartnerNotification(
        houseId: houseId,
        title: 'Soul Merge',
        body: body,
        data: {'type': 'soul_merge', 'senderName': myName},
      );

      // Prune chat messages to keep database lightweight
      final snap = await ref.orderByChild('timestamp').get();
      if (snap.exists && snap.value is Map) {
        final messages = Map<dynamic, dynamic>.from(snap.value as Map);
        if (messages.length > 50) {
          final sortedKeys = messages.keys.toList()
            ..sort((a, b) {
              final t1 = messages[a]['timestamp'] as int? ?? 0;
              final t2 = messages[b]['timestamp'] as int? ?? 0;
              return t1.compareTo(t2);
            });
          final keysToDelete = sortedKeys.sublist(0, sortedKeys.length - 50);
          for (final key in keysToDelete) {
            await ref.child(key.toString()).remove();
          }
        }
      }
    } catch (e) {
      debugPrint('[SoulMergeService] sendSoulMessage error: $e');
      rethrow;
    }
  }

  /// Watch real-time temporary messages in Soul Merge
  Stream<List<Map<String, dynamic>>> watchSoulMessages() {
    return Stream.fromFuture(
      _houseService.getCurrentHouseId(),
    ).asyncExpand<List<Map<String, dynamic>>>((houseId) {
      if (houseId == null || houseId.isEmpty) return const Stream.empty();
      return _db
          .ref('houses/$houseId/soul_merge/chat')
          .orderByChild('timestamp')
          .limitToLast(50)
          .onValue
          .asBroadcastStream()
          .map((event) {
            final data = event.snapshot.value;
            final list = <Map<String, dynamic>>[];
            if (data is Map) {
              data.forEach((key, val) {
                if (val is Map) {
                  final msg = Map<String, dynamic>.from(val);
                  msg['id'] = key.toString();
                  list.add(msg);
                }
              });
              list.sort((a, b) {
                final t1 = a['timestamp'] as int? ?? 0;
                final t2 = b['timestamp'] as int? ?? 0;
                return t1.compareTo(t2);
              });
            }
            return list;
          });
    }).asBroadcastStream();
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
          .onChildAdded
          .asBroadcastStream()
          .map((event) {
            final data = event.snapshot.value;
            if (data is Map) {
              final msg = Map<String, dynamic>.from(data);
              msg['id'] = event.snapshot.key;
              return msg;
            }
            return <String, dynamic>{};
          });
    }).asBroadcastStream();
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
      final houseSnap = await _db.ref('houses/$houseId').get();
      if (!houseSnap.exists) return;
      final houseData = houseSnap.value as Map<dynamic, dynamic>?;
      if (houseData == null) return;

      final users = houseData['users'] as Map<dynamic, dynamic>?;
      String partnerName = 'Người ấy';
      if (users != null && users[partnerRole] != null) {
        final partnerInfo = users[partnerRole] as Map<dynamic, dynamic>;
        partnerName = (partnerInfo['name'] as String?)?.trim() ?? 'Người ấy';
        if (partnerName.isEmpty) partnerName = 'Người ấy';
      }

      // 2. Get house settings for names
      final settingsData = houseData['settings'] as Map<dynamic, dynamic>?;
      final nameU1 = (settingsData?['nameU1'] as String?)?.trim();
      final nameU2 = (settingsData?['nameU2'] as String?)?.trim();

      // Helper lấy tên theo role
      String nameForRole(String r) {
        if (r == 'user2') {
          return (nameU2 != null && nameU2.isNotEmpty) ? nameU2 : 'Người ấy';
        }
        return (nameU1 != null && nameU1.isNotEmpty) ? nameU1 : 'Người ấy';
      }

      // 3. Get Latest Message
      final chatSnap = await _db
          .ref('houses/$houseId/soul_merge/chat')
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      String message = 'Hãy vào nhà để trò chuyện...';
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
          if (text != null && text.trim().isNotEmpty) {
            message = text.trim();
          } else if (imageUrl != null && imageUrl.isNotEmpty) {
            message = 'Đã gửi một ảnh';
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
