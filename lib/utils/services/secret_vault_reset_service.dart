import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

class SecretVaultResetRequestInfo {
  final String requestId;
  final String houseId;
  final String status;
  final String requestedBy;
  final String requestedByName;
  final String requestedByEmail;
  final int requestedAt;
  final int scheduledAt;
  final bool canCancel;

  const SecretVaultResetRequestInfo({
    required this.requestId,
    required this.houseId,
    required this.status,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedByEmail,
    required this.requestedAt,
    required this.scheduledAt,
    required this.canCancel,
  });

  bool get isPending => status.trim().toLowerCase() == 'pending';

  factory SecretVaultResetRequestInfo.fromMap(Map<String, dynamic> map) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return SecretVaultResetRequestInfo(
      requestId: (map['requestId'] ?? '').toString(),
      houseId: (map['houseId'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      requestedBy: (map['requestedBy'] ?? '').toString(),
      requestedByName: (map['requestedByName'] ?? '').toString(),
      requestedByEmail: (map['requestedByEmail'] ?? '').toString(),
      requestedAt: readInt(map['requestedAt']),
      scheduledAt: readInt(map['scheduledAt']),
      canCancel: map['canCancel'] == true,
    );
  }
}

class SecretVaultResetService {
  SecretVaultResetService({
    FirebaseFunctions? functions,
    DatabaseReference? dbRef,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _dbRef = dbRef ?? FirebaseDatabase.instance.ref();

  final FirebaseFunctions _functions;
  final DatabaseReference _dbRef;

  Stream<SecretVaultResetRequestInfo?> watchResetRequest(String houseId) {
    return _dbRef
        .child('houses/$houseId/private_secure_meta/resetRequest')
        .onValue
        .map(
      (event) {
        final rawValue = event.snapshot.value;
        if (rawValue is! Map) {
          return null;
        }
        final map = rawValue.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final info = SecretVaultResetRequestInfo.fromMap(map);
        return info.isPending ? info : null;
      },
    );
  }

  Future<SecretVaultResetRequestInfo> requestReset({
    required String houseId,
    required String email,
    required String otp,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestSecretVaultReset');
      final response = await callable.call(<String, dynamic>{
        'houseId': houseId.trim(),
        'email': email.trim(),
        'otp': otp.trim(),
      });
      final rawData = response.data;
      if (rawData is! Map) {
        throw UiCopy.text('copy_fbe89bc54f16');
      }
      final data = Map<String, dynamic>.from(rawData);
      return SecretVaultResetRequestInfo.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      switch (error.code) {
        case 'already-exists':
          throw error.message ??
              UiCopy.text('copy_d04740d36848');
        case 'permission-denied':
          throw UiCopy.text('copy_8d9f3b1f9ea4');
        case 'deadline-exceeded':
          throw UiCopy.text('copy_ce8b53085ba9');
        case 'failed-precondition':
          throw error.message ??
              UiCopy.text('copy_1218113d2af5');
        case 'resource-exhausted':
          throw error.message ??
              UiCopy.text('copy_3fc83e0151c2');
        case 'unauthenticated':
          throw UiCopy.text('copy_9a64ce2f9715');
        default:
          throw error.message ??
              UiCopy.text('copy_e8429394853e');
      }
    } catch (error) {
      if (error is String) rethrow;
      throw UiCopy.text('copy_e8429394853e');
    }
  }

  Future<void> cancelReset({required String houseId}) async {
    try {
      final callable = _functions.httpsCallable('cancelSecretVaultReset');
      await callable.call(<String, dynamic>{
        'houseId': houseId.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      switch (error.code) {
        case 'not-found':
          throw UiCopy.text('copy_2444640f81c6');
        case 'failed-precondition':
          throw error.message ??
              UiCopy.text('copy_8dbe12cb3aaf');
        case 'unauthenticated':
          throw UiCopy.text('copy_0448e3d20bec');
        default:
          throw error.message ??
              UiCopy.text('copy_b09462abbd5a');
      }
    } catch (error) {
      if (error is String) rethrow;
      throw UiCopy.text('copy_b09462abbd5a');
    }
  }
}
