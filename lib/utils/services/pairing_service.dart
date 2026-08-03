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
    final rawExpiresAt = data['expiresAt'];
    final expiresAt = rawExpiresAt is num ? rawExpiresAt.toInt() : 0;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      throw Exception('Mã ghép nối đã hết hạn.');
    }

    final houseId = data['houseId']?.toString();
    if (houseId == null) {
      throw Exception('Mã ghép nối bị lỗi (không tìm thấy houseId).');
    }

    final myHouseId = await HouseService().getCurrentHouseId();
    if (myHouseId != null && houseId == myHouseId) {
      throw Exception('Bạn không thể nhập mã của chính mình.');
    }

    // Get current user's profile info
    final guestName = user.displayName ?? 'Khách';
    final guestAvatar = user.photoURL ?? '';
    final guestEmail = user.email ?? '';

    await _dbRef.child('pairing_requests/${user.uid}').set({
      'houseId': houseId,
      'guestUid': user.uid,
      'guestName': guestName,
      'guestAvatar': guestAvatar,
      'guestEmail': guestEmail,
      'timestamp': ServerValue.timestamp,
      'status': 'pending',
    });
  }

  /// Listens to the status of a request sent by the current user.
  /// Lắng nghe toàn bộ node để detect khi node bị xóa (host từ chối và remove).
  /// Khi node không tồn tại → trả về 'rejected' thay vì 'pending'.
  Stream<String> listenToMyRequestStatus() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _dbRef.child('pairing_requests/${user.uid}').onValue.map((event) {
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
    await _dbRef
        .child('houses/$houseId/settings/relationshipMode')
        .set('couple');

    // Tắt tính năng Single Match cho nhà mới vì đã ghép đôi
    try {
      await _dbRef.child('single_match_active_pool/$houseId').remove();
      await _dbRef
          .child('houses/$houseId/settings/singleMatch/enabled')
          .set(false);
    } catch (_) {}

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

  /// Reject a request — xóa luôn để tránh rác dữ liệu trong stream
  Future<void> rejectRequest(String requestId) async {
    await _dbRef.child('pairing_requests/$requestId').remove();
  }

  /// Retrieves the active pairing code for a given houseId
  Future<Map<String, dynamic>?> getActivePairingCode(String houseId) async {
    final snap = await _dbRef
        .child('pairing_codes')
        .orderByChild('houseId')
        .equalTo(houseId)
        .get();

    if (snap.exists && snap.value is Map) {
      final map = snap.value as Map<dynamic, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in map.entries) {
        final data = entry.value as Map<dynamic, dynamic>;
        final expiresAt = data['expiresAt'] as int? ?? 0;
        if (expiresAt > now) {
          return {
            'code': entry.key.toString(),
            'houseId': data['houseId']?.toString(),
            'creatorUid': data['creatorUid']?.toString(),
            'createdAt': data['createdAt'] as int? ?? 0,
            'expiresAt': expiresAt,
          };
        }
      }
    }
    return null;
  }

  /// Delete a code
  Future<void> deleteCode(String code) async {
    await _dbRef.child('pairing_codes/$code').remove();
  }
}
