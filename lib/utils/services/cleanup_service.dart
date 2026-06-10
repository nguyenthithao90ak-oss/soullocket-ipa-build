import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/core/constants/app_firebase_paths.dart';

class CleanupService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Tự động xoá tin nhắn cũ sau X ngày.
  Future<void> cleanupOldMessages(String houseId, {int days = 3}) async {
    final roomIds = await _getRoomIds(houseId);
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    for (final roomId in roomIds) {
      final messagesRef = _dbRef.child('chats/$roomId/messages');
      final snapshot = await messagesRef.orderByChild('ts').endAt(cutoff).get();

      if (!snapshot.exists) continue;
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final updates = <String, dynamic>{};
      for (final key in data.keys) {
        final messageId = key.toString().trim();
        if (messageId.isEmpty) continue;
        updates['chats/$roomId/messages/$messageId'] = null;
      }
      if (updates.isNotEmpty) {
        await _dbRef.update(updates);
      }
    }
  }

  Future<List<String>> _getRoomIds(String houseId) async {
    final roomIds = <String>{};

    final roomIndexSnapshot =
        await _dbRef.child(AppFirebasePaths.houseChatRooms(houseId)).get();
    if (roomIndexSnapshot.exists) {
      final data = Map<dynamic, dynamic>.from(roomIndexSnapshot.value as Map);
      for (final key in data.keys) {
        final roomId = key.toString().trim();
        if (roomId.isNotEmpty) {
          roomIds.add(roomId);
        }
      }
    }

    // Legacy fallback: derive deterministic room IDs from friend IDs instead
    // of downloading the entire chats tree.
    final friendsSnapshot =
        await _dbRef.child(AppFirebasePaths.friendsForHouse(houseId)).get();
    if (friendsSnapshot.exists) {
      final data = Map<dynamic, dynamic>.from(friendsSnapshot.value as Map);
      for (final key in data.keys) {
        final friendHouseId = key.toString().trim();
        if (friendHouseId.isEmpty) continue;
        final ids = [houseId, friendHouseId]..sort();
        roomIds.add('${ids[0]}_${ids[1]}');
      }
    }

    return roomIds.toList(growable: false);
  }
}
