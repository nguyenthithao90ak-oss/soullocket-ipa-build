import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'intimacy_service.dart';

class HeartBurstEvent {
  final String id;
  final String senderRole;
  final String emoji;
  final int count;
  final int timestamp;

  const HeartBurstEvent({
    required this.id,
    required this.senderRole,
    required this.emoji,
    required this.count,
    required this.timestamp,
  });
}

class HeartBurstService {
  static final HeartBurstService _instance = HeartBurstService._internal();
  factory HeartBurstService() => _instance;
  HeartBurstService._internal();

  static HeartBurstService get instance => _instance;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  int _lastHandledTs = DateTime.now().millisecondsSinceEpoch - 5000;

  Future<void> sendHeartBurst({
    required String houseId,
    required String senderRole,
    String emoji = '💖',
    int count = 5,
  }) async {
    if (houseId.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final burstRef = _dbRef.child('houses/$houseId/heart_bursts').push();

    await burstRef.set({
      'senderRole': senderRole,
      'emoji': emoji,
      'count': count,
      'timestamp': now,
    });

    // Thưởng EXP thân mật
    unawaited(
      IntimacyService.instance.addExp(
        houseId: houseId,
        action: 'heart_burst',
        exp: 5,
        description: 'Bắn tim tương tác yêu thương (+5 EXP)',
      ),
    );
  }

  Stream<HeartBurstEvent?> streamPartnerBursts({
    required String houseId,
    required String myRole,
  }) {
    if (houseId.isEmpty) return const Stream.empty();

    return _dbRef
        .child('houses/$houseId/heart_bursts')
        .orderByChild('timestamp')
        .startAt(_lastHandledTs)
        .limitToLast(1)
        .onChildAdded
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      final map = event.snapshot.value as Map;
      final senderRole = map['senderRole']?.toString() ?? '';
      final ts = (map['timestamp'] as num?)?.toInt() ?? 0;

      // Only trigger if sent by partner and is recent
      if (senderRole != myRole && ts > _lastHandledTs) {
        _lastHandledTs = ts;
        return HeartBurstEvent(
          id: event.snapshot.key ?? '',
          senderRole: senderRole,
          emoji: map['emoji']?.toString() ?? '💖',
          count: (map['count'] as num?)?.toInt() ?? 5,
          timestamp: ts,
        );
      }
      return null;
    });
  }
}
