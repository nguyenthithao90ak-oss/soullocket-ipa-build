import 'package:firebase_database/firebase_database.dart';

Future<Map<dynamic, dynamic>> loadChatHouseInfo(
  DatabaseReference dbRef,
  String houseId,
) async {
  final merged = <dynamic, dynamic>{};

  Future<void> mergeFromPath(String path) async {
    try {
      final snap = await dbRef.child(path).get();
      if (!snap.exists || snap.value is! Map) {
        return;
      }
      final raw = Map<dynamic, dynamic>.from(snap.value as Map);
      merged.addAll(raw);
      final settings = raw['settings'];
      if (settings is Map) {
        merged.addAll(Map<dynamic, dynamic>.from(settings));
      }
    } catch (_) {}
  }

  await mergeFromPath('houses/$houseId');
  await mergeFromPath('houses_public/$houseId');
  await mergeFromPath('house_profiles/$houseId');
  return merged;
}
