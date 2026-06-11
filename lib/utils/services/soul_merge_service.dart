import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'house_service.dart';

class SoulMergeService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();

  /// Report a physical bump event to Firebase using server time
  Future<void> reportBump() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final uid = user.uid;
      
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      await _db.ref('houses/$houseId/soul_merge/$uid').set(ServerValue.timestamp);
    } catch (e) {
      debugPrint('[SoulMergeService] reportBump error: $e');
    }
  }

  /// Listen to the bump times of both partners (resolved by server time)
  Stream<Map<String, int>> watchMergeTimes() async* {
    final user = _auth.currentUser;
    if (user == null) return;

    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    yield* _db.ref('houses/$houseId/soul_merge').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return const <String, int>{};

      final map = <String, int>{};
      data.forEach((key, value) {
        if (value is int) {
          map[key.toString()] = value;
        } else if (value is num) {
          map[key.toString()] = value.toInt();
        }
      });
      return map;
    });
  }

  /// Clear the soul merge bump records for the current user from database
  Future<void> clearBumps() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final uid = user.uid;
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      await _db.ref('houses/$houseId/soul_merge/$uid').remove();
    } catch (e) {
      debugPrint('[SoulMergeService] clearBumps error: $e');
    }
  }
}
