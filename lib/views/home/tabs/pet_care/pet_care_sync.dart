import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../../../../core/constants/app_firebase_paths.dart';
import 'pet_care_progress.dart';

/// Bản Trạm Mây chung của nhà trên Realtime Database.
///
/// Tiết kiệm chi phí máy chủ: một nút nhỏ `houses/{houseId}/pet_care`
/// (~2 KB), không Cloud Functions; chỉ ghi khi có thao tác (chỉ số tụt theo
/// thời gian mỗi máy tự tính từ `lastEvaluatedAt`), chỉ nghe khi đang mở
/// Trạm Mây, Home đọc một lần. Luật máy chủ chỉ cho hai thành viên của nhà
/// đọc/ghi, `rev` phải tăng đúng 1 và `by` phải là chính người ghi.
class PetCareFirebaseRemote implements PetCareRemote {
  PetCareFirebaseRemote({required String houseId, FirebaseDatabase? database})
    : _ref = (database ?? FirebaseDatabase.instance).ref(
        AppFirebasePaths.housePetCare(houseId),
      );

  final DatabaseReference _ref;

  @override
  Future<PetCareRemoteDoc?> fetch() async =>
      PetCareRemoteDoc.fromValue((await _ref.get()).value);

  @override
  Stream<PetCareRemoteDoc?> watch() => _ref.onValue.map(
    (event) => PetCareRemoteDoc.fromValue(event.snapshot.value),
  );

  @override
  Future<PetCareRemoteDoc?> commit(
    PetCareRemoteDoc? Function(PetCareRemoteDoc? current) apply,
  ) async {
    final result = await _ref.runTransaction((value) {
      final next = apply(PetCareRemoteDoc.fromValue(value));
      return next == null
          ? Transaction.abort()
          : Transaction.success(next.toValue());
    }, applyLocally: false);
    return PetCareRemoteDoc.fromValue(result.snapshot.value);
  }
}
