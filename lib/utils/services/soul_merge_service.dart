import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'house_service.dart';

class SoulMergeService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();

  /// Report a physical bump event to Firebase
  Future<void> reportBump() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final uid = user.uid;
      
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.ref('houses/$houseId/soul_merge/$uid').set(now);
    } catch (e) {
      debugPrint('[SoulMergeService] reportBump error: $e');
    }
  }

  /// Listen to the partner's bump events
  Stream<DateTime?> watchPartnerBump() async* {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) return;

    yield* _db.ref('houses/$houseId/soul_merge').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;

      // Find the partner's timestamp
      for (final key in data.keys) {
        if (key.toString() != uid) {
          final timestamp = data[key] as int?;
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        }
      }
      return null;
    });
  }
}
