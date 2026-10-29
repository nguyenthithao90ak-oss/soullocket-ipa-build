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
  // Chỉ fetch đúng các field cần, không load toàn bộ node
  Future<Map<dynamic, dynamic>> fetchFields(
    String rootPath, {
    bool canonical = false,
  }) async {
    final fields = <dynamic, dynamic>{};
    try {
      final results = await Future.wait(
        _kChatHouseFields.map((field) {
          final settingsField =
              canonical &&
              const {
                'nameU1',
                'nameU2',
                'username',
                'avtUser1',
                'profileAvatarSizePx',
                'relationshipMode',
              }.contains(field);
          return dbRef
              .child('$rootPath/${settingsField ? 'settings/' : ''}$field')
              .get();
        }),
      );
      for (var i = 0; i < _kChatHouseFields.length; i++) {
        final snap = results[i];
        if (snap.exists && snap.value != null) {
          fields[_kChatHouseFields[i]] = snap.value;
        }
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/chat/chat_house_info_loader.dart: $error',
      );
    }
    return fields;
  }

  final sources = await Future.wait([
    fetchFields('houses_public/$houseId'),
    fetchFields('house_profiles/$houseId'),
    fetchFields('houses/$houseId', canonical: true),
  ]);
  // Ưu tiên xác định, không phụ thuộc nguồn nào trả lời mạng sau cùng.
  return {for (final source in sources) ...source};
}
