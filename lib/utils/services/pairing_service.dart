import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';
import 'package:soullocket_app/utils/services/house_service.dart';

class PairingRequest {
  final String requestId; // The guest's uid
  final String guestName;
  final String guestAvatar;
  final int timestamp;
  final String status; // 'pending', 'accepted', 'rejected', 'merged'
  final String guestEmail;

  PairingRequest({
    required this.requestId,
    required this.guestName,
    required this.guestAvatar,
    required this.timestamp,
    required this.status,
    required this.guestEmail,
  });

  factory PairingRequest.fromMap(String id, Map<dynamic, dynamic> map) {
    final rawTs = map['timestamp'];
    int timestampVal = 0;
    if (rawTs is num) {
      timestampVal = rawTs.toInt();
    } else if (rawTs is String) {
      timestampVal =
          double.tryParse(rawTs)?.toInt() ?? int.tryParse(rawTs) ?? 0;
    }
    return PairingRequest(
      requestId: id,
      guestName: map['guestName']?.toString() ?? 'Khách',
      guestAvatar: map['guestAvatar']?.toString() ?? '',
      timestamp: timestampVal,
      status: map['status']?.toString() ?? 'pending',
      guestEmail: map['guestEmail']?.toString() ?? '',
    );
  }
}

class PairingService {
  static final PairingService instance = PairingService._();
  PairingService._();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) return const <String, dynamic>{};
    return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
  }

  /// Creates a new pairing code with a given duration in minutes
  Future<String> createPairingCode(int durationMinutes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');

    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      'createPairingInvite',
      payload: <String, dynamic>{'durationMinutes': durationMinutes},
      fallbackErrorMessage: 'Không thể tạo mã ghép nối lúc này.',
    );
    final code = _asMap(response.data)['code']?.toString().trim() ?? '';
    if (code.isEmpty) throw Exception('Máy chủ không trả về mã ghép nối.');
    return code;
  }

  /// Sends a pairing request using a 12-digit code
  Future<void> sendPairingRequest(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');
    await CloudFunctionsHelper.callSecure<dynamic>(
      'requestPairingInvite',
      payload: <String, dynamic>{'code': code},
      fallbackErrorMessage: 'Mã ghép nối không hợp lệ hoặc đã hết hạn.',
    );
  }

  /// Listens to the status of a request sent by the current user.
  /// Lắng nghe toàn bộ node để detect khi node bị xóa (host từ chối và remove).
  /// Khi node không tồn tại → trả về 'rejected' thay vì 'pending'.
  Stream<String> listenToMyRequestStatus() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _dbRef.child('pairing_secure/guest_views/${user.uid}').onValue.map((
      event,
    ) {
      final snap = event.snapshot;
      // Node bị xóa → coi như bị từ chối
      if (!snap.exists || snap.value == null) return 'rejected';
      final data = snap.value as Map<dynamic, dynamic>? ?? {};
      return data['status']?.toString() ?? 'pending';
    });
  }

  /// Retrieves the current pending or accepted request for the current user
  Future<Map<String, dynamic>?> getMyPendingOrAcceptedRequest() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _dbRef
        .child('pairing_secure/guest_views/${user.uid}')
        .get();
    if (snap.exists) {
      final data = snap.value as Map<dynamic, dynamic>;
      final status = data['status']?.toString();
      if (status == 'pending' || status == 'accepted') {
        return {'houseId': data['houseId']?.toString(), 'status': status};
      }
    }
    return null;
  }

  /// Called by the requester after 'accepted' to finalize the merge
  Future<void> finalizeMerge({String? code, String? targetHouseId}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await HouseService().joinHouseByAcceptedInvite();

    // Refresh token để các rules nhận house mới ngay sau khi server hoàn tất.
    await user.getIdToken(true);
  }

  /// Guest cancels their own pending request
  Future<void> cancelMyRequest() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await CloudFunctionsHelper.callSecure<dynamic>(
      'cancelPairingRequest',
      payload: const <String, dynamic>{},
      fallbackErrorMessage: 'Không thể hủy yêu cầu ghép nối.',
    );
  }

  /// Listens to incoming requests for my house
  Stream<List<PairingRequest>> listenToIncomingRequests(String myHouseId) {
    return _dbRef.child('pairing_secure/house_requests/$myHouseId').onValue.map((
      event,
    ) {
      final val = event.snapshot.value;
      if (val == null) return [];

      final map = val as Map<dynamic, dynamic>;
      final requests = <PairingRequest>[];
      map.forEach((key, value) {
        final reqData = value as Map<dynamic, dynamic>;
        // Only show pending or accepted (to allow host to see it's merged eventually)
        requests.add(PairingRequest.fromMap(key.toString(), reqData));
      });

      // Sort by timestamp descending
      requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return requests;
    });
  }

  /// Accept a request
  Future<void> acceptRequest(String requestId) async {
    await CloudFunctionsHelper.callSecure<dynamic>(
      'respondPairingRequest',
      payload: <String, dynamic>{'requestId': requestId, 'accept': true},
      fallbackErrorMessage: 'Không thể chấp nhận yêu cầu ghép nối.',
    );
  }

  /// Reject a request — xóa luôn để tránh rác dữ liệu trong stream
  Future<void> rejectRequest(String requestId) async {
    await CloudFunctionsHelper.callSecure<dynamic>(
      'respondPairingRequest',
      payload: <String, dynamic>{'requestId': requestId, 'accept': false},
      fallbackErrorMessage: 'Không thể từ chối yêu cầu ghép nối.',
    );
  }

  /// Retrieves the active pairing code for a given houseId
  Future<Map<String, dynamic>?> getActivePairingCode(String houseId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _dbRef
        .child('pairing_secure/creator_views/${user.uid}')
        .get();
    if (!snap.exists || snap.value is! Map) return null;
    final data = _asMap(snap.value);
    final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
    if (data['houseId']?.toString() == houseId &&
        data['status']?.toString() == 'active' &&
        expiresAt > DateTime.now().millisecondsSinceEpoch) {
      return {
        'code': data['code']?.toString(),
        'houseId': data['houseId']?.toString(),
        'createdAt': (data['createdAt'] as num?)?.toInt() ?? 0,
        'expiresAt': expiresAt,
      };
    }
    return null;
  }

  /// Delete a code
  Future<void> deleteCode(String code) async {
    await CloudFunctionsHelper.callSecure<dynamic>(
      'revokePairingInvite',
      payload: <String, dynamic>{'code': code},
      fallbackErrorMessage: 'Không thể hủy mã ghép nối.',
    );
  }
}
