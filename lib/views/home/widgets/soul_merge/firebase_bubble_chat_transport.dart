import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../../utils/services/soul_merge_service.dart';
import 'bubble_chat_controller.dart';

/// Cầu nối của engine nổi tới cùng service/schema với Soul Merge chính.
class FirebaseSoulBubbleChatTransport implements SoulBubbleChatTransport {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final SoulMergeService _service = SoulMergeService();

  @override
  String? get currentUid => _auth.currentUser?.uid;
  @override
  Stream<String?> get uidChanges =>
      _auth.authStateChanges().map((user) => user?.uid).distinct();
  @override
  Stream<Object?> watchValue(String path) => FirebaseDatabase.instance
      .ref(path)
      .onValue
      .map((event) => event.snapshot.value);
  @override
  Stream<List<Map<String, dynamic>>> watchMessages(String houseId) =>
      _service.watchSoulMessages(houseId: houseId);
  @override
  String newMessageId(String houseId) => _service.newSoulMessageId(houseId);
  @override
  Future<void> send(
    SoulBubbleScope scope,
    String text,
    String id, {
    required bool isRetry,
    String? imageUrl,
  }) => _service.sendSoulMessage(
    text,
    imageUrl: imageUrl,
    expectedUid: scope.uid,
    expectedHouseId: scope.houseId,
    expectedRole: scope.role,
    messageId: id,
    isRetry: isRetry,
  );
}
