import 'dart:math' as math;
import 'dart:ui';

import 'home_companion_motion.dart';
import 'home_companion_outfit.dart';
import 'home_companion_metrics.dart';

/// Điều phối cả bốn bé trong tọa độ nội dung, độc lập vị trí cuộn màn hình.
/// Chỉ một lượt nhảy vượt; giữ chỗ đáp và bạn được vượt đến khi tiếp đất.
class HomeCompanionTraffic {
  HomeCompanionTraffic(this.motions) {
    for (final entry in motions.entries) {
      entry.value.canMoveTo = (feet, lift) => canOccupy(entry.key, feet, lift);
    }
  }
  final Map<HomeCompanionCharacter, HomeCompanionMotion> motions;
  final _waiting = <HomeCompanionCharacter, double>{};
  HomeCompanionCharacter? _jumper;
  HomeCompanionCharacter? _yielding;
  Rect? _reservation;
  int _turn = 0;
  int passSerial = 0;
  HomeCompanionCharacter lastSpeaker = HomeCompanionCharacter.bunny;
  bool get passing => _jumper != null;

  static Rect body(HomeCompanionCharacter who, Offset feet, double lift) {
    final width = HomeCompanionMetrics.bodyWidth(who);
    return Rect.fromLTRB(
      feet.dx - width / 2,
      feet.dy - lift - 70,
      feet.dx + width / 2,
      feet.dy - lift + 3,
    );
  }

  bool canOccupy(HomeCompanionCharacter who, Offset feet, double lift) {
    final next = body(who, feet, lift);
    final before = body(who, motions[who]!.position, motions[who]!.hopLift);
    // Kiểm tra cả đoạn giữa hai frame, không lọt qua bạn khi frame trễ.
    final swept = before.expandToInclude(next);
    for (final entry in motions.entries) {
      if (entry.key == who || !entry.value.hasSurfaces) continue;
      final other = body(entry.key, entry.value.position, entry.value.hopLift);
      if (swept.overlaps(other)) {
        // Resize có thể dồn hai bé ở mép. Chỉ cho tách dần ra ngoài,
        // không cho đi qua tâm của bạn để đổi sang phía đối diện.
        final oldOverlap = before.intersect(other);
        final newOverlap = next.intersect(other);
        final oldArea =
            math.max(0, oldOverlap.width) * math.max(0, oldOverlap.height);
        final newArea =
            math.max(0, newOverlap.width) * math.max(0, newOverlap.height);
        if (oldArea == 0 ||
            newArea >= oldArea ||
            (feet - entry.value.position).distance <=
                (motions[who]!.position - entry.value.position).distance) {
          return false;
        }
      }
    }
    if (who != _jumper &&
        who != _yielding &&
        _reservation != null &&
        swept.overlaps(_reservation!)) {
      return false;
    }
    return true;
  }

  void advance(
    Duration delta, {
    required bool allowNewPass,
    required double visibleTop,
    HomeCompanionCharacter? waitingForFriend,
  }) {
    if (_jumper != null && !motions[_jumper]!.isPassing) {
      _jumper = null;
      _yielding = null;
      _reservation = null;
    }
    final keys = motions.keys.toList();
    final dt = math.min(delta.inMicroseconds / 1000000, 0.1);
    // Luân phiên ưu tiên để không có một bé luôn chiếm đường của các bạn.
    for (var i = 0; i < keys.length; i++) {
      final who = keys[(i + _turn) % keys.length];
      if (who == _yielding ||
          (who == waitingForFriend && !motions[who]!.isPassing)) {
        continue;
      }
      final motion = motions[who]!;
      motion.advance(delta);
      _waiting[who] = motion.movementBlocked ? (_waiting[who] ?? 0) + dt : 0;
      if (!motion.movementBlocked || passing) continue;
      final others =
          motions.entries
              .where((entry) => entry.key != who && entry.value.hasSurfaces)
              .toList()
            ..sort(
              (a, b) => (a.value.position - motion.position).distance.compareTo(
                (b.value.position - motion.position).distance,
              ),
            );
      if (others.isEmpty) continue;
      final friend = others.first;
      if (allowNewPass &&
          (_waiting[who] ?? 0) > 0.35 &&
          motion.position.dy - visibleTop >= 150) {
        final landing = motion.passingDestination(friend.value);
        if (landing != null &&
            motions.entries.every(
              (entry) =>
                  entry.key == who ||
                  !entry.value.hasSurfaces ||
                  !body(who, landing, 0).overlaps(
                    body(entry.key, entry.value.position, entry.value.hopLift),
                  ),
            )) {
          final corridor = body(
            who,
            motion.position,
            78,
          ).expandToInclude(body(who, landing, 0));
          final clear = motions.entries.every(
            (entry) =>
                entry.key == who ||
                entry.key == friend.key ||
                !entry.value.hasSurfaces ||
                !corridor.overlaps(
                  body(entry.key, entry.value.position, entry.value.hopLift),
                ),
          );
          if (clear && motion.beginPassing(landing)) {
            _jumper = who;
            _yielding = friend.key;
            _reservation = corridor;
            lastSpeaker = who;
            passSerial++;
            continue;
          }
        }
      }
      if ((_waiting[who] ?? 0) > 1.1) {
        motion.fleeFrom(friend.value);
        friend.value.makeRoom();
        _waiting[who] = 0;
      }
    }
    _turn = (_turn + 1) % keys.length;
  }

  void dispose() {
    for (final motion in motions.values) {
      motion.canMoveTo = null;
    }
  }
}
