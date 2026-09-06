import 'package:flutter/foundation.dart';

import 'package:firebase_database/firebase_database.dart';

// Fields cần cho chat display — không load toàn bộ house node
const _kChatHouseFields = [
  'houseName',
  'nameU1',
  'nameU2',
  'username',
  'houseAvatar',
  'avatar',
  'avtUser1',
  'profileAvatarSizePx',
  'relationshipMode',
];

Future<Map<dynamic, dynamic>> loadChatHouseInfo(
  DatabaseReference dbRef,
  String houseId,
) async {
  final merged = <dynamic, dynamic>{};

  // Chỉ fetch đúng các field cần, không load toàn bộ node
  Future<void> fetchFields(String rootPath) async {
    try {
      final results = await Future.wait(
        _kChatHouseFields.map((field) => dbRef.child('$rootPath/$field').get()),
      );
      for (var i = 0; i < _kChatHouseFields.length; i++) {
        final snap = results[i];
        if (snap.exists && snap.value != null) {
          merged[_kChatHouseFields[i]] = snap.value;
        }
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/chat/chat_house_info_loader.dart: $error',
      );
    }
  }

  await Future.wait([
    fetchFields('houses/$houseId'),
    fetchFields('houses_public/$houseId'),
    fetchFields('house_profiles/$houseId'),
  ]);

  return merged;
}
