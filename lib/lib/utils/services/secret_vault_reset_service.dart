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
        throw 'Máy chủ trả về dữ liệu reset Kho ảnh mật không hợp lệ.';
      }
      final data = Map<String, dynamic>.from(rawData);
      return SecretVaultResetRequestInfo.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      switch (error.code) {
        case 'already-exists':
          throw error.message ??
              'Đã có yêu cầu reset Kho ảnh mật đang chờ xử lý.';
        case 'permission-denied':
          throw 'Mã OTP không đúng. Vui lòng kiểm tra lại.';
        case 'deadline-exceeded':
          throw 'Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.';
        case 'failed-precondition':
          throw error.message ??
              'Email xác nhận không khớp email chính của tài khoản hiện tại.';
        case 'resource-exhausted':
          throw error.message ??
              'Bạn đã nhập sai OTP quá nhiều lần. Vui lòng thử lại sau.';
        case 'unauthenticated':
          throw 'Bạn cần đăng nhập lại trước khi xác nhận reset Kho ảnh mật.';
        default:
          throw error.message ??
              'Không thể tạo yêu cầu reset Kho ảnh mật lúc này.';
      }
    } catch (error) {
      if (error is String) rethrow;
      throw 'Không thể tạo yêu cầu reset Kho ảnh mật lúc này.';
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
          throw 'Không tìm thấy yêu cầu reset Kho ảnh mật đang chờ.';
        case 'failed-precondition':
          throw error.message ??
              'Yêu cầu reset Kho ảnh mật không còn ở trạng thái chờ.';
        case 'unauthenticated':
          throw 'Bạn cần đăng nhập lại trước khi thu hồi yêu cầu reset.';
        default:
          throw error.message ??
              'Không thể thu hồi yêu cầu reset Kho ảnh mật lúc này.';
      }
    } catch (error) {
      if (error is String) rethrow;
      throw 'Không thể thu hồi yêu cầu reset Kho ảnh mật lúc này.';
    }
  }
}
