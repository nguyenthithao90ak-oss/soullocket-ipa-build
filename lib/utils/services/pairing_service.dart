import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/utils/services/house_service.dart';

class PairingRequest {
  final String requestId; // The guest's uid
  final String guestName;
  final String guestAvatar;
  final int timestamp;
  final String status; // 'pending', 'accepted', 'rejected', 'merged'

  PairingRequest({
    required this.requestId,
    required this.guestName,
    required this.guestAvatar,
    required this.timestamp,
    required this.status,
  });

  factory PairingRequest.fromMap(String id, Map<dynamic, dynamic> map) {
    return PairingRequest(
      requestId: id,
      guestName: map['guestName']?.toString() ?? 'Khách',
      guestAvatar: map['guestAvatar']?.toString() ?? '',
      timestamp: map['timestamp'] as int? ?? 0,
      status: map['status']?.toString() ?? 'pending',
    );
  }
}

class PairingService {
  static final PairingService instance = PairingService._();
  PairingService._();

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generate12DigitCode() {
    final rand = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 12; i++) {
      buffer.write(rand.nextInt(10));
    }
    return buffer.toString();
  }

  /// Creates a new pairing code with a given duration in minutes
  Future<String> createPairingCode(int durationMinutes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');

    final houseId = await HouseService().getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) throw Exception('Chưa có nhà');

    final code = _generate12DigitCode();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + (durationMinutes * 60 * 1000);

    await _dbRef.child('pairing_codes/$code').set({
      'houseId': houseId,
      'creatorUid': user.uid,
      'createdAt': now,
      'expiresAt': expiresAt,
    });

    return code;
  }

  /// Sends a pairing request using a 12-digit code
  Future<void> sendPairingRequest(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');

    final codeSnap = await _dbRef.child('pairing_codes/$code').get();
    if (!codeSnap.exists) {
      throw Exception('Mã ghép nối không tồn tại hoặc đã hết hạn.');
    }

    final data = codeSnap.value as Map<dynamic, dynamic>;
    final expiresAt = data['expiresAt'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      throw Exception('Mã ghép nối đã hết hạn.');
    }

    final houseId = data['houseId']?.toString();
    if (houseId == null) throw Exception('Mã ghép nối bị lỗi (không tìm thấy houseId).');

    final myHouseId = await HouseService().getCurrentHouseId();
    if (myHouseId != null && houseId == myHouseId) {
      throw Exception('Bạn không thể nhập mã của chính mình.');
    }

    // Get current user's profile info
    final guestName = user.displayName ?? 'Khách';
    final guestAvatar = user.photoURL ?? '';

    await _dbRef.child('pairing_requests/${user.uid}').set({
      'houseId': houseId,
      'guestUid': user.uid,
      'guestName': guestName,
      'guestAvatar': guestAvatar,
      'timestamp': ServerValue.timestamp,
      'status': 'pending',
    });
  }

  /// Listens to the status of a request sent by the current user
  Stream<String> listenToMyRequestStatus() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _dbRef.child('pairing_requests/${user.uid}/status').onValue.map((event) {
      final val = event.snapshot.value?.toString();
      return val ?? 'pending';
    });
  }

  /// Retrieves the current pending or accepted request for the current user
  Future<Map<String, dynamic>?> getMyPendingOrAcceptedRequest() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _dbRef.child('pairing_requests/${user.uid}').get();
    if (snap.exists) {
      final data = snap.value as Map<dynamic, dynamic>;
      final status = data['status']?.toString();
      if (status == 'pending' || status == 'accepted') {
        return {
          'houseId': data['houseId']?.toString(),
          'status': status,
        };
      }
    }
    return null;
  }

  /// Called by the requester after 'accepted' to finalize the merge
  Future<void> finalizeMerge({String? code, String? targetHouseId}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? houseId = targetHouseId;
    if (houseId == null && code != null) {
      final codeSnap = await _dbRef.child('pairing_codes/$code').get();
      if (codeSnap.exists) {
        final data = codeSnap.value as Map<dynamic, dynamic>;
        houseId = data['houseId']?.toString();
      }
    }
    
    if (houseId == null) return;

    await HouseService().joinHouseWithCoupleCode(houseId);
    
    // Bắt buộc phải refresh token để Cloud Functions cấp quyền ghi vào houseId mới trước khi đánh cờ isPaired
    await user.getIdToken(true);

    await _dbRef.child('houses/$houseId/settings/isPaired').set(true);
    
    // Xoá dữ liệu rác sau khi ghép nối thành công
    await _dbRef.child('pairing_requests/${user.uid}').remove();
    if (code != null) {
      await _dbRef.child('pairing_codes/$code').remove();
    }
  }

  /// Guest cancels their own pending request
  Future<void> cancelMyRequest() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _dbRef.child('pairing_requests/${user.uid}').remove();
  }

  /// Listens to incoming requests for my house
  Stream<List<PairingRequest>> listenToIncomingRequests(String myHouseId) {
    return _dbRef
        .child('pairing_requests')
        .orderByChild('houseId')
        .equalTo(myHouseId)
        .onValue
        .map((event) {
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
    await _dbRef.child('pairing_requests/$requestId/status').set('accepted');
  }

  /// Reject a request
  Future<void> rejectRequest(String requestId) async {
    await _dbRef.child('pairing_requests/$requestId/status').set('rejected');
  }

  /// Delete a code
  Future<void> deleteCode(String code) async {
    await _dbRef.child('pairing_codes/$code').remove();
  }
}
