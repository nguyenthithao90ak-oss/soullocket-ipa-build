import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'house_service.dart';

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

      await _db.ref('houses/$houseId/soul_merge/$role').set(ServerValue.timestamp);
    } catch (e) {
      debugPrint('[SoulMergeService] reportBump error: $e');
    }
  }

  /// Listen to the bump times of both partners (resolved by server time).
  /// Key trong map là role ('user1'/'user2').
  Stream<Map<String, int>> watchMergeTimes() {
    return Stream.fromFuture(_houseService.getCurrentHouseId()).asyncExpand<Map<String, int>>((houseId) {
      if (houseId == null || houseId.isEmpty) return const Stream.empty();
      return _db.ref('houses/$houseId/soul_merge').onValue.asBroadcastStream().map((event) {
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
      if (user == null) return;

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));

      final ref = _db.ref('houses/$houseId/soul_merge/chat');
      await ref.push().set({
        if (text.isNotEmpty) 'text': text.trim(),
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'sender': role,
        'timestamp': ServerValue.timestamp,
      });

      // Prune chat messages to keep database lightweight
      final snap = await ref.orderByChild('timestamp').get();
      if (snap.exists && snap.value is Map) {
        final messages = Map<dynamic, dynamic>.from(snap.value as Map);
        if (messages.length > 20) {
          final sortedKeys = messages.keys.toList()
            ..sort((a, b) {
              final t1 = messages[a]['timestamp'] as int? ?? 0;
              final t2 = messages[b]['timestamp'] as int? ?? 0;
              return t1.compareTo(t2);
            });
          final keysToDelete = sortedKeys.sublist(0, sortedKeys.length - 20);
          for (final key in keysToDelete) {
            await ref.child(key.toString()).remove();
          }
        }
      }
    } catch (e) {
      debugPrint('[SoulMergeService] sendSoulMessage error: $e');
    }
  }

  /// Watch real-time temporary messages in Soul Merge
  Stream<List<Map<String, dynamic>>> watchSoulMessages() {
    return Stream.fromFuture(_houseService.getCurrentHouseId()).asyncExpand<List<Map<String, dynamic>>>((houseId) {
      if (houseId == null || houseId.isEmpty) return const Stream.empty();
      return _db
          .ref('houses/$houseId/soul_merge/chat')
          .orderByChild('timestamp')
          .limitToLast(20)
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
      final snap = await _db.ref('houses/$houseId/soul_merge/lastSeen/$role').get();
      return (snap.value as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[SoulMergeService] getLastSeenTimestamp error: $e');
      return 0;
    }
  }

  /// Send an interactive event (e.g. photo shot or heart tap) to the partner
  Future<void> sendInteractiveEvent({required String type, String? url, double? x, double? y}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final role = _normalizeRole(prefs.getString('il_role'));

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
    return Stream.fromFuture(_houseService.getCurrentHouseId()).asyncExpand<Map<String, dynamic>>((houseId) {
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

  String _normalizeRole(String? raw) {
    return raw?.trim() == 'user2' ? 'user2' : 'user1';
  }
}
