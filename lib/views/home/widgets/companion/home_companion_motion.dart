import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

enum HomeCompanionPhase {
  idle,
  walking,
  approaching,
  hopping,
  sweeping,
  celebrating,
}

enum HomeCompanionSurfaceShape { ledge, circle, outline }

@immutable
class HomeCompanionSurface {
  const HomeCompanionSurface({
    required this.id,
    required this.bounds,
    required this.shape,
    this.obstacleBounds,
    this.outline,
  });

  final String id;
  final Rect bounds;
  final HomeCompanionSurfaceShape shape;
  final Rect? obstacleBounds;

  /// Các điểm của một đường viền khép kín trong tọa độ Scene, không có lỗ.
  /// Scene cung cấp danh sách bất biến; bộ chuyển động chụp lại khi nhận.
  final List<Offset>? outline;
}

@immutable
class HomeCompanionDust {
  const HomeCompanionDust({
    required this.position,
    required this.remaining,
    required this.seed,
  });

  final Offset position;
  final double remaining;
  final int seed;
}

/// Bộ chuyển động cục bộ: không timer nền, không lưu/gửi vị trí chạm.
/// Widget chỉ gọi [advance] khi Home đang hiển thị và cho phép chuyển động.
class HomeCompanionMotion extends ChangeNotifier {
  HomeCompanionMotion({int? seed}) : _random = math.Random(seed) {
    _dustView = UnmodifiableListView(_dust);
  }

  final math.Random _random;
  List<HomeCompanionSurface> _surfaces = const [];
  List<_Track> _tracks = const [];
  Rect _viewport = Rect.zero;
  _Track? _track;
  double _distance = 0;
  Offset _position = Offset.zero;
  bool _facingRight = true;
  int _walkDirection = 1;
  bool _finishedPatrol = false;
  int _visitSerial = 0;
  final Map<String, int> _lastVisited = {};
  HomeCompanionPhase _phase = HomeCompanionPhase.idle;
  double _elapsed = 0;
  double _phaseTime = 0;
  double _stride = 0;
  double _idleDuration = 2;
  double _nextDustAt = 15;
  double _lastApproachAt = -1;
  double _affectionUntil = -1;
  bool _greetingOnArrival = false;
  int _greetingSerial = 0;
  int _nextDustSeed = 0;
  final List<HomeCompanionDust> _dust = [];
  late final UnmodifiableListView<HomeCompanionDust> _dustView;
  final Map<int, (_Track, double)> _dustTargets = {};
  int? _cleaningSeed;
  double _sweepInitial = 1;
  final Queue<_JourneyLeg> _journey = Queue();
  Offset? _pendingTouch;
  bool _settled = false;
  Offset? _pinnedPosition;

  Offset get position => _position;
  bool get facingRight => _facingRight;
  HomeCompanionPhase get phase => _phase;
  double get elapsedSeconds => _elapsed;
  double get stride => _stride;

  /// Lời chào nhỏ chỉ theo thời gian Home đang hoạt động, không timer nền.
  double get affection => ((_affectionUntil - _elapsed) / 1.8).clamp(0.0, 1.0);

  /// Mỗi lời chào là một sự kiện, không lặp âm thanh theo từng frame.
  int get greetingSerial => _greetingSerial;

  bool isPetting(Offset touch) =>
      hasSurfaces &&
      _finiteOffset(touch) &&
      (touch - (_position - Offset(0, 28 + hopLift))).distance <= 34;
  double get hopProgress {
    if (_journey.isEmpty || _settled || !_isMoving) return 0;
    final leg = _journey.first;
    if (leg.length <= 0) return 0;
    final hops = math.max(1, (leg.length / 64).round());
    return (leg.travelled / leg.length * hops).clamp(0.0, hops.toDouble()) % 1;
  }

  /// Chỉ nâng hình vẽ, chân tiếp xúc vẫn đi theo đường an toàn đã tìm.
  /// Nhún theo từng chặng ngắn, tiếp đất êm ở đầu/cuối hành trình.
  double get hopLift {
    if (!_isMoving || _settled) return 0;
    final wave = math.sin(math.pi * hopProgress);
    final amplitude = _phase == HomeCompanionPhase.hopping ? 14.0 : 4.0;
    final topClearance = math.max(0.0, _position.dy - _viewport.top);
    return math.min(amplitude * wave * wave, topClearance);
  }

  bool get _isMoving =>
      _phase == HomeCompanionPhase.walking ||
      _phase == HomeCompanionPhase.approaching ||
      _phase == HomeCompanionPhase.hopping;
  List<HomeCompanionDust> get dust => _dustView;
  bool get hasSurfaces => _pinnedPosition != null || _track != null;
  double get celebration => _phase == HomeCompanionPhase.celebrating
      ? (_phaseTime / 1.1).clamp(0.0, 1.0)
      : 0;

  /// Viewport là vùng tọa độ chân đã trừ kích thước bé và thanh điều hướng.
  void setSurfaces(List<HomeCompanionSurface> surfaces, Rect viewport) {
    final wasPinned = _pinnedPosition != null;
    _pinnedPosition = null;
    final valid = surfaces
        .where(
          (surface) =>
              _validRect(surface.bounds) &&
              (surface.obstacleBounds == null ||
                  _validRect(surface.obstacleBounds!)) &&
              (surface.shape != HomeCompanionSurfaceShape.outline ||
                  _validOutline(surface.outline)),
        )
        .map(
          (surface) => surface.outline == null
              ? surface
              : HomeCompanionSurface(
                  id: surface.id,
                  bounds: surface.bounds,
                  shape: surface.shape,
                  obstacleBounds: surface.obstacleBounds,
                  outline: List.unmodifiable(surface.outline!),
                ),
        )
        .toList();
    if (!wasPinned &&
        _nearRect(_viewport, viewport) &&
        _sameSurfaces(valid, _surfaces)) {
      return;
    }
    final previousId = _track?.surface.id;
    _viewport = viewport;
    _surfaces = List.unmodifiable(valid);
    _tracks = _validRect(viewport)
        ? valid.expand((surface) => _makeTracks(surface, viewport)).toList()
        : const [];
    _journey.clear();
    _dust.clear();
    _dustTargets.clear();
    _cleaningSeed = null;
    _pendingTouch = null;
    _greetingOnArrival = false;
    _affectionUntil = -1;
    _finishedPatrol = false;
    _settled = false;
    _nextDustAt = _elapsed + 15;
    _setPhase(HomeCompanionPhase.idle);
    if (_tracks.isEmpty) {
      _track = null;
      _position = Offset.zero;
      notifyListeners();
      return;
    }
    final previous = _tracks.where((track) => track.surface.id == previousId);
    final candidates = previous.isEmpty ? _tracks : previous.toList();
    if (previousId == null) {
      _track = candidates.first;
      _distance = _track!.length * 0.30;
    } else {
      _track = candidates.reduce(
        (a, b) => a.project(_position).$2 < b.project(_position).$2 ? a : b,
      );
      _distance = _track!.project(_position).$1;
    }
    _position = _track!.at(_distance);
    _lastVisited.removeWhere(
      (id, _) => !_surfaces.any((surface) => surface.id == id),
    );
    _lastVisited.putIfAbsent(_track!.surface.id, () => ++_visitSerial);
    notifyListeners();
  }

  /// Neo vào viewport, không phụ thuộc các ô đang cuộn phía dưới.
  /// Chỉ giữ cử động tại chỗ/lời chào, không tạo hành trình hay bụi trên ô.
  void setPinnedPosition(Offset position, Rect viewport) {
    if (!_validRect(viewport) || !_finiteOffset(position)) {
      setSurfaces(const [], viewport);
      return;
    }
    final pinned = Offset(
      position.dx.clamp(viewport.left, viewport.right),
      position.dy.clamp(viewport.top, viewport.bottom),
    );
    if (_pinnedPosition == pinned && _viewport == viewport) return;
    _viewport = viewport;
    _pinnedPosition = pinned;
    _position = pinned;
    _track = null;
    _tracks = const [];
    _surfaces = const [];
    _journey.clear();
    _dust.clear();
    _dustTargets.clear();
    _cleaningSeed = null;
    _pendingTouch = null;
    _greetingOnArrival = false;
    _affectionUntil = -1;
    _settled = false;
    _setPhase(HomeCompanionPhase.idle);
    notifyListeners();
  }

  /// Bỏ qua phần thời gian app bị treo/ra nền, không chạy bù hàng giây.
  void advance(Duration delta) {
    if (!hasSurfaces || delta <= Duration.zero) return;
    final dt = math.min(delta.inMicroseconds / 1000000, 0.10);
    _elapsed += dt;
    _phaseTime += dt;
    if (_pinnedPosition != null) {
      // Thời gian vẫn chạy để bé thở/chớp mắt; chân không dịch chuyển.
      notifyListeners();
      return;
    }
    if (_settled) {
      // Sau pause, đi tiếp đoạn nối đang dở để không nhảy xuyên khối.
      _settled = false;
      if (_journey.isNotEmpty) _setPhase(_journey.first.phase);
    }
    if (_elapsed >= _nextDustAt && _dust.isEmpty) {
      _spawnDust();
      _nextDustAt = _elapsed + 45;
    }
    if (_journey.isNotEmpty) {
      _advanceJourney(dt);
    } else if (_phase == HomeCompanionPhase.sweeping) {
      _advanceSweep();
    } else if (_phase == HomeCompanionPhase.celebrating) {
      if (_phaseTime >= 1.1) {
        _cleaningSeed = null;
        if (!_startCleaning()) _rest();
      }
    } else if (_phaseTime >= _idleDuration) {
      if (!_startCleaning()) _wander();
    }
    notifyListeners();
  }

  void approach(Offset touch) => _approach(touch, newTouch: true);

  void _approach(Offset touch, {required bool newTouch}) {
    if (!hasSurfaces || !_finiteOffset(touch)) {
      return;
    }
    final petting = isPetting(touch);
    if (!_inside(_viewport, touch) && !petting) {
      return;
    }
    if (_elapsed - _lastApproachAt < 0.30) return;
    _lastApproachAt = _elapsed;
    if (newTouch) _greetingSerial++;
    _affectionUntil = _elapsed + 1.8;
    _greetingOnArrival = true;
    // Không đổi hướng giữa một bước nhảy: tiếp đất trước rồi đón điểm chạm mới.
    if (_phase == HomeCompanionPhase.hopping ||
        (_journey.isNotEmpty &&
            _journey.first.phase == HomeCompanionPhase.hopping)) {
      _pendingTouch = touch;
      _cleaningSeed = null;
      notifyListeners();
      return;
    }
    _syncToCurrentLeg();
    _journey.clear();
    _cleaningSeed = null;
    // Chạm gần bé là vuốt ve: bé đứng lại chào thay vì chạy khỏi ngón tay.
    if (petting || _pinnedPosition != null) {
      if ((touch.dx - _position.dx).abs() > 4) {
        _facingRight = touch.dx > _position.dx;
      }
      _greetingOnArrival = false;
      _rest();
      _idleDuration = 1.8;
      notifyListeners();
      return;
    }
    final sorted = [..._tracks]
      ..sort((a, b) => a.project(touch).$2.compareTo(b.project(touch).$2));
    for (final target in sorted) {
      var distance = target.project(touch).$1;
      if ((target.at(distance) - touch).distance < 28) {
        final before = target.normalize(distance - 30);
        final after = target.normalize(distance + 30);
        distance =
            (target.at(before) - touch).distance >
                (target.at(after) - touch).distance
            ? before
            : after;
      }
      if (_travelTo(target, distance, HomeCompanionPhase.approaching)) break;
    }
    notifyListeners();
  }

  void requestCleaning() {
    if (!hasSurfaces || _pinnedPosition != null) return;
    if (_dust.isEmpty) _spawnDust();
    _nextDustAt = _elapsed + 45;
    if (_journey.isEmpty && _phase != HomeCompanionPhase.sweeping) {
      _startCleaning();
    }
    notifyListeners();
  }

  /// Hủy ý định chạm/quét. Đoạn nối giữa khối được giữ để tiếp đất an toàn
  /// nếu widget tiếp tục chạy sau pause, không dịch chuyển tức thời.
  void settle() {
    _pendingTouch = null;
    _greetingOnArrival = false;
    _affectionUntil = -1;
    _cleaningSeed = null;
    if (_journey.isNotEmpty &&
        _journey.first.phase == HomeCompanionPhase.hopping) {
      final landing = _journey.first;
      _journey
        ..clear()
        ..add(landing);
    } else {
      _syncToCurrentLeg();
      _journey.clear();
    }
    _settled = true;
    _rest();
    notifyListeners();
  }

  void _setPhase(HomeCompanionPhase value) {
    _phase = value;
    _phaseTime = 0;
  }

  void _rest() {
    _setPhase(HomeCompanionPhase.idle);
    _idleDuration = 1.8 + _random.nextDouble() * 2.2;
  }

  void _wander() {
    final track = _track!;
    final alternatives = _tracks
        .where((candidate) => candidate.surface.id != track.surface.id)
        .toList();
    // Ưu tiên khối chưa ghé hoặc đã lâu chưa ghé, không chọn ngẫu nhiên mãi
    // giữa hai khối gần nhất. Khối không có hành lang an toàn được bỏ qua.
    if (alternatives.isNotEmpty && _finishedPatrol) {
      alternatives.sort(
        (a, b) => (_lastVisited[a.surface.id] ?? -1).compareTo(
          _lastVisited[b.surface.id] ?? -1,
        ),
      );
      for (final candidate in alternatives) {
        final destination =
            candidate.length * (0.15 + _random.nextDouble() * 0.70);
        if (_travelTo(candidate, destination, HomeCompanionPhase.walking)) {
          return;
        }
      }
    }
    // Đi trọn một vòng trước khi ghé khối khác, tránh chỉ quanh quẩn gần
    // các cổng nối ngắn nhất. Mép bị cắt bởi viewport được đi tới cả hai đầu.
    // Một hành trình liền mạch không bị việc dọn bụi đổi hướng giữa chừng;
    // chạm tay hoặc pause vẫn có thể ngắt ngay và lần sau bắt đầu tại chân.
    _finishedPatrol = false;
    _journey
      ..clear()
      ..add(
        _JourneyLeg(
          track.patrolFrom(_distance, _walkDirection),
          HomeCompanionPhase.walking,
          track,
          _distance,
          completesPatrol: true,
        ),
      );
    _setPhase(HomeCompanionPhase.walking);
  }

  bool _travelTo(_Track target, double distance, HomeCompanionPhase phase) {
    final current = _track!;
    final legs = <_JourneyLeg>[];
    if (target == current) {
      legs.add(
        _JourneyLeg(
          current.pathBetween(_distance, distance),
          phase,
          current,
          distance,
        ),
      );
    } else {
      final connector = _findConnector(current, target, distance);
      if (connector == null) return false;
      legs.add(
        _JourneyLeg(
          current.pathBetween(_distance, connector.departure),
          phase,
          current,
          connector.departure,
        ),
      );
      legs.add(
        _JourneyLeg(
          connector.points,
          HomeCompanionPhase.hopping,
          target,
          connector.landing,
        ),
      );
      legs.add(
        _JourneyLeg(
          target.pathBetween(connector.landing, distance),
          phase,
          target,
          distance,
        ),
      );
    }
    _journey
      ..clear()
      ..addAll(legs.where((leg) => leg.points.length > 1));
    if (_journey.isEmpty) {
      _track = target;
      _distance = distance;
      _position = target.at(distance);
      _arrived();
    } else {
      _setPhase(_journey.first.phase);
    }
    return true;
  }

  _Connector? _findConnector(
    _Track current,
    _Track target,
    double destination,
  ) {
    final departures = current.ports();
    final landings = target.ports();
    final nodes = <Offset>[
      for (final port in departures) current.at(port),
      for (final port in landings) target.at(port),
      _viewport.topLeft,
      _viewport.topRight,
      _viewport.bottomLeft,
      _viewport.bottomRight,
      // Các góc thật của thẻ cho phép vòng qua hành lang rất hẹp. Không
      // dùng biên đường đi đã inset làm vật cản vì sẽ cắt xuyên nội dung.
      for (final surface in _surfaces)
        if (surface.shape == HomeCompanionSurfaceShape.ledge)
          ...(surface.obstacleBounds ?? surface.bounds).corners
        else if (surface.shape == HomeCompanionSurfaceShape.outline)
          ...surface.bounds.corners,
    ];
    final costs = List.filled(nodes.length, double.infinity);
    final previous = List.filled(nodes.length, -1);
    final visited = List.filled(nodes.length, false);
    for (var i = 0; i < departures.length; i++) {
      costs[i] = _length(current.pathBetween(_distance, departures[i]));
    }
    var bestCost = double.infinity;
    var bestLanding = -1;
    // Dijkstra đa nguồn chỉ chạy khi đổi đích, không chạy theo khung hình.
    // Mỗi cạnh được kiểm tra đoạn thẳng với tất cả thẻ/vòng đếm ngày.
    for (var iteration = 0; iteration < nodes.length; iteration++) {
      var next = -1;
      for (var i = 0; i < nodes.length; i++) {
        if (!visited[i] && (next == -1 || costs[i] < costs[next])) next = i;
      }
      if (next == -1 || !costs[next].isFinite || costs[next] > bestCost) break;
      visited[next] = true;
      final landingIndex = next - departures.length;
      if (landingIndex >= 0 && landingIndex < landings.length) {
        final total =
            costs[next] +
            _length(target.pathBetween(landings[landingIndex], destination));
        if (total < bestCost) {
          bestCost = total;
          bestLanding = next;
        }
      }
      for (var i = 0; i < nodes.length; i++) {
        if (visited[i]) continue;
        final cost = costs[next] + (nodes[i] - nodes[next]).distance;
        if (cost >= costs[i] || !_connectorSafe([nodes[next], nodes[i]])) {
          continue;
        }
        costs[i] = cost;
        previous[i] = next;
      }
    }
    if (bestLanding < 0) return null;
    final reversePath = <Offset>[];
    var node = bestLanding;
    while (previous[node] >= 0) {
      reversePath.add(nodes[node]);
      node = previous[node];
    }
    reversePath.add(nodes[node]);
    return _Connector(
      _deduplicate(reversePath.reversed.toList()),
      departures[node],
      landings[bestLanding - departures.length],
    );
  }

  void _advanceJourney(double dt) {
    final leg = _journey.first;
    final speed = leg.phase == HomeCompanionPhase.walking ? 37.0 : 76.0;
    var remaining = dt * speed;
    while (remaining > 0 && leg.segment < leg.points.length - 1) {
      final end = leg.points[leg.segment + 1];
      final offset = end - _position;
      final distance = offset.distance;
      final travel = math.min(remaining, distance);
      if (distance > 0.001) {
        final next = _position + offset / distance * travel;
        if ((next.dx - _position.dx).abs() > 0.01) {
          _facingRight = next.dx > _position.dx;
        }
        _position = next;
        _stride = (_stride + travel / 24) % 1;
      }
      remaining -= travel;
      leg.travelled += travel;
      if (distance <= travel + 0.001) {
        _position = end;
        leg.segment++;
      } else {
        break;
      }
    }
    if (leg.segment >= leg.points.length - 1) {
      if (_track?.surface.id != leg.target.surface.id) {
        _finishedPatrol = false;
        _lastVisited[leg.target.surface.id] = ++_visitSerial;
      }
      if (leg.completesPatrol) {
        _finishedPatrol = true;
        _walkDirection *= -1;
      }
      _track = leg.target;
      _distance = leg.distance;
      _journey.removeFirst();
      if (leg.phase == HomeCompanionPhase.hopping && _pendingTouch != null) {
        final touch = _pendingTouch!;
        _pendingTouch = null;
        _journey.clear();
        _setPhase(HomeCompanionPhase.idle);
        _lastApproachAt = -1;
        _approach(touch, newTouch: false);
      } else if (_journey.isNotEmpty) {
        _setPhase(_journey.first.phase);
      } else {
        _arrived();
      }
    }
  }

  void _syncToCurrentLeg() {
    if (_journey.isEmpty) return;
    final leg = _journey.first;
    if (leg.phase != HomeCompanionPhase.hopping) {
      _track = leg.target;
      _distance = _track!.project(_position).$1;
    }
  }

  void _arrived() {
    if (_greetingOnArrival) {
      _greetingOnArrival = false;
      _affectionUntil = _elapsed + 1.8;
      _greetingSerial++;
    }
    final index = _dust.indexWhere((spot) => spot.seed == _cleaningSeed);
    if (index >= 0 && (_dust[index].position - _position).distance < 1) {
      _position = _dust[index].position;
      _sweepInitial = _dust[index].remaining;
      _setPhase(HomeCompanionPhase.sweeping);
    } else {
      _rest();
    }
  }

  void _spawnDust() {
    final track = _track;
    if (track == null || track.length < 45 || _dust.isNotEmpty) return;
    final count = track.length < 140 ? 2 : 3;
    final start = _random.nextDouble() * 0.15;
    for (var i = 0; i < count; i++) {
      final distance = track.length * (0.12 + start + i * 0.25);
      final seed = _nextDustSeed++;
      _dust.add(
        HomeCompanionDust(
          position: track.at(distance),
          remaining: 1,
          seed: seed,
        ),
      );
      _dustTargets[seed] = (track, distance);
    }
  }

  bool _startCleaning() {
    if (_dust.isEmpty) return false;
    final sorted = [..._dust]
      ..sort(
        (a, b) => (a.position - _position).distance.compareTo(
          (b.position - _position).distance,
        ),
      );
    for (final spot in sorted) {
      final target = _dustTargets[spot.seed];
      if (target == null) continue;
      _cleaningSeed = spot.seed;
      if (_travelTo(target.$1, target.$2, HomeCompanionPhase.walking)) {
        return true;
      }
    }
    _cleaningSeed = null;
    return false;
  }

  void _advanceSweep() {
    final index = _dust.indexWhere((spot) => spot.seed == _cleaningSeed);
    if (index < 0) {
      _rest();
      return;
    }
    final spot = _dust[index];
    final remaining = _sweepInitial * (1 - _phaseTime / 2.8).clamp(0.0, 1.0);
    _dust[index] = HomeCompanionDust(
      position: spot.position,
      remaining: remaining,
      seed: spot.seed,
    );
    if (remaining <= 0) {
      _dust.removeAt(index);
      _dustTargets.remove(spot.seed);
      // Sau khi dọn xong vẫn dành thời gian đi thăm khối khác, không tạo
      // bụi lại ngay nếu hành trình dọn trước đó kéo dài hơn 45 giây.
      if (_dust.isEmpty) _nextDustAt = _elapsed + 45;
      _setPhase(HomeCompanionPhase.celebrating);
    }
  }

  bool _connectorSafe(List<Offset> points) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (!_inside(_viewport, a) || !_inside(_viewport, b)) return false;
      // Kiểm tra toàn đoạn nối với thẻ và ellipse, không chỉ các điểm đầu/cuối.
      for (final surface in _surfaces) {
        if (surface.shape == HomeCompanionSurfaceShape.outline) {
          if (_segmentEntersPolygon(a, b, surface.outline!)) return false;
          continue;
        }
        // Đường chân hình tròn đã inset vào vành trang trí. Chừa đúng sai số
        // dây cung lấy mẫu, không cho cạnh nối cắt tắt vài pixel qua mặt vòng.
        final rect = surface.shape == HomeCompanionSurfaceShape.circle
            ? surface.bounds.deflate(
                math.max(surface.bounds.width, surface.bounds.height) /
                        2 *
                        (1 - math.cos(math.pi / 192)) +
                    0.005,
              )
            : (surface.obstacleBounds ?? surface.bounds).deflate(0.75);
        if (surface.shape == HomeCompanionSurfaceShape.ledge) {
          if (_clipSegment(a, b, rect) != null) return false;
        } else {
          final center = rect.center;
          final ra = Offset(
            (a.dx - center.dx) / (rect.width / 2),
            (a.dy - center.dy) / (rect.height / 2),
          );
          final rb = Offset(
            (b.dx - center.dx) / (rect.width / 2),
            (b.dy - center.dy) / (rect.height / 2),
          );
          if (_projectSegment(Offset.zero, ra, rb).$2 < 1) return false;
        }
      }
    }
    return true;
  }
}

class _Connector {
  const _Connector(this.points, this.departure, this.landing);
  final List<Offset> points;
  final double departure;
  final double landing;
}

extension on Rect {
  List<Offset> get corners => [topLeft, topRight, bottomLeft, bottomRight];
}

class _JourneyLeg {
  _JourneyLeg(
    this.points,
    this.phase,
    this.target,
    this.distance, {
    this.completesPatrol = false,
  }) : length = _length(points);
  final List<Offset> points;
  final HomeCompanionPhase phase;
  final _Track target;
  final double distance;
  final bool completesPatrol;
  final double length;
  double travelled = 0;
  int segment = 0;
}

class _Track {
  _Track(this.surface, this.points, this.closed) {
    distances = [0];
    for (var i = 1; i < points.length; i++) {
      distances.add(distances.last + (points[i] - points[i - 1]).distance);
    }
  }
  final HomeCompanionSurface surface;
  final List<Offset> points;
  final bool closed;
  late final List<double> distances;
  double get length => distances.last;

  double normalize(double distance) =>
      closed ? distance % length : distance.clamp(0.0, length);

  Offset at(double distance) {
    distance = distance.clamp(0.0, length);
    for (var i = 1; i < distances.length; i++) {
      if (distances[i] >= distance) {
        final span = distances[i] - distances[i - 1];
        return Offset.lerp(
          points[i - 1],
          points[i],
          span == 0 ? 0 : (distance - distances[i - 1]) / span,
        )!;
      }
    }
    return points.last;
  }

  (double, double) project(Offset point) {
    var bestDistance = double.infinity;
    var along = 0.0;
    for (var i = 1; i < points.length; i++) {
      final projection = _projectSegment(point, points[i - 1], points[i]);
      if (projection.$2 < bestDistance) {
        bestDistance = projection.$2;
        along =
            distances[i - 1] +
            (distances[i] - distances[i - 1]) * projection.$1;
      }
    }
    return (along, bestDistance);
  }

  List<double> ports() => [
    0,
    if (points.length > 2)
      for (var i = 1; i < 16; i++) length * i / 16,
    length,
  ];

  List<Offset> patrolFrom(double from, int direction) {
    final forward = closed
        ? [..._forward(from, length), ..._forward(0, from)]
        : [..._forward(from, length), ...points.reversed, ..._forward(0, from)];
    return _deduplicate(direction >= 0 ? forward : forward.reversed.toList());
  }

  List<Offset> pathBetween(double from, double to) {
    if ((from - to).abs() < 0.001) return [at(from)];
    final direct = (from - to).abs();
    if (closed && direct > length / 2) {
      if (to < from) {
        return _deduplicate([..._forward(from, length), ..._forward(0, to)]);
      }
      return _deduplicate([
        ..._forward(0, from).reversed,
        ..._forward(to, length).reversed,
      ]);
    }
    return from <= to
        ? _forward(from, to)
        : _forward(to, from).reversed.toList();
  }

  List<Offset> _forward(double from, double to) => _deduplicate([
    at(from),
    for (var i = 1; i < points.length - 1; i++)
      if (distances[i] > from && distances[i] < to) points[i],
    at(to),
  ]);
}

List<_Track> _makeTracks(HomeCompanionSurface surface, Rect viewport) {
  final bounds = surface.bounds;
  if (surface.shape == HomeCompanionSurfaceShape.ledge) {
    final segment = _clipSegment(bounds.topLeft, bounds.topRight, viewport);
    if (segment == null || (segment.$2 - segment.$1).distance < 24) return [];
    return [
      _Track(surface, [segment.$1, segment.$2], false),
    ];
  }
  const count = 192;
  final points = surface.shape == HomeCompanionSurfaceShape.outline
      ? _deduplicate([...surface.outline!, surface.outline!.first])
      : List.generate(count + 1, (i) {
          final angle = -math.pi / 2 + math.pi * 2 * i / count;
          return bounds.center +
              Offset(
                math.cos(angle) * bounds.width / 2,
                math.sin(angle) * bounds.height / 2,
              );
        });
  if (points.every((point) => _inside(viewport, point))) {
    return [_Track(surface, points, true)];
  }
  final runs = <List<Offset>>[];
  List<Offset>? run;
  for (var i = 1; i < points.length; i++) {
    final segment = _clipSegment(points[i - 1], points[i], viewport);
    if (segment == null) {
      run = null;
      continue;
    }
    if (run == null || (run.last - segment.$1).distance > 0.01) {
      run = [segment.$1];
      runs.add(run);
    }
    run.add(segment.$2);
  }
  // Hai mảnh ở đầu/cuối bảng góc thực tế là cùng một cung liên tục.
  if (runs.length > 1 && (runs.last.last - runs.first.first).distance < 0.01) {
    runs.first = [...runs.removeLast(), ...runs.first.skip(1)];
  }
  return runs
      .map((points) => _Track(surface, _deduplicate(points), false))
      .where((track) => track.length >= 24)
      .toList();
}

bool _validRect(Rect rect) =>
    rect.left.isFinite &&
    rect.top.isFinite &&
    rect.right.isFinite &&
    rect.bottom.isFinite &&
    rect.width > 1 &&
    rect.height > 1;
bool _finiteOffset(Offset point) => point.dx.isFinite && point.dy.isFinite;

bool _validOutline(List<Offset>? points) {
  if (points == null || points.length < 3 || !points.every(_finiteOffset)) {
    return false;
  }
  var twiceArea = 0.0;
  for (var i = 0; i < points.length; i++) {
    twiceArea += _cross(points[i], points[(i + 1) % points.length]);
  }
  return twiceArea.abs() > 1;
}

double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

/// Chia đoạn tại mọi giao điểm rồi thử từng khoảng: xử lý được đường viền
/// lõm (tim, ngôi sao), thay vì chỉ thử trung điểm hoặc hộp chữ nhật bao ngoài.
/// Cho phép đi đúng trên mép, không cho phép cắt đường tắt qua nội thất.
bool _segmentEntersPolygon(Offset a, Offset b, List<Offset> points) {
  final vector = b - a;
  if (vector.distanceSquared < 0.000001) {
    return _strictlyInsidePolygon(a, points);
  }
  final cuts = <double>[0, 1];
  for (var i = 0; i < points.length; i++) {
    final edgeStart = points[i];
    final edgeEnd = points[(i + 1) % points.length];
    final edge = edgeEnd - edgeStart;
    final relative = edgeStart - a;
    final denominator = _cross(vector, edge);
    if (denominator.abs() < 0.000001) {
      if (_cross(relative, vector).abs() < 0.000001) {
        cuts
          ..add(_projectSegment(edgeStart, a, b).$1)
          ..add(_projectSegment(edgeEnd, a, b).$1);
      }
      continue;
    }
    final along = _cross(relative, edge) / denominator;
    final onEdge = _cross(relative, vector) / denominator;
    if (along >= 0 && along <= 1 && onEdge >= 0 && onEdge <= 1) {
      cuts.add(along);
    }
  }
  cuts.sort();
  for (var i = 1; i < cuts.length; i++) {
    if (cuts[i] - cuts[i - 1] < 0.000001) continue;
    final middle = a + vector * ((cuts[i] + cuts[i - 1]) / 2);
    if (_strictlyInsidePolygon(middle, points)) return true;
  }
  return false;
}

bool _strictlyInsidePolygon(Offset point, List<Offset> points) {
  var inside = false;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    if (_projectSegment(point, a, b).$2 < 0.005) return false;
    if ((a.dy > point.dy) != (b.dy > point.dy) &&
        point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

bool _inside(Rect rect, Offset point) =>
    point.dx >= rect.left - 0.001 &&
    point.dx <= rect.right + 0.001 &&
    point.dy >= rect.top - 0.001 &&
    point.dy <= rect.bottom + 0.001;
bool _sameSurfaces(List<HomeCompanionSurface> a, List<HomeCompanionSurface> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        !_nearRect(a[i].bounds, b[i].bounds) ||
        a[i].shape != b[i].shape ||
        !_nearRect(a[i].obstacleBounds, b[i].obstacleBounds) ||
        !_nearOutline(a[i].outline, b[i].outline)) {
      return false;
    }
  }
  return true;
}

// Đổi qua lại giữa tọa độ cuộn và nội dung có sai số số thực rất nhỏ.
// Không được xóa hành trình/bụi chỉ vì sai số dưới một phần nghìn pixel.
bool _nearRect(Rect? a, Rect? b) =>
    identical(a, b) ||
    (a != null &&
        b != null &&
        (a.topLeft - b.topLeft).distance < 0.001 &&
        (a.bottomRight - b.bottomRight).distance < 0.001);

bool _nearOutline(List<Offset>? a, List<Offset>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).distance >= 0.001) return false;
  }
  return true;
}

List<Offset> _deduplicate(List<Offset> points) {
  final result = <Offset>[];
  for (final point in points) {
    if (result.isEmpty || (result.last - point).distance > 0.001) {
      result.add(point);
    }
  }
  return result;
}

double _length(List<Offset> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += (points[i] - points[i - 1]).distance;
  }
  return total;
}

(double, double) _projectSegment(Offset point, Offset a, Offset b) {
  final vector = b - a;
  final lengthSquared = vector.distanceSquared;
  final t = lengthSquared == 0
      ? 0.0
      : (((point.dx - a.dx) * vector.dx + (point.dy - a.dy) * vector.dy) /
                lengthSquared)
            .clamp(0.0, 1.0);
  return (t, (a + vector * t - point).distance);
}

/// Liang–Barsky giữ đúng điểm cắt; không nối tắt qua phần cung ngoài viewport.
(Offset, Offset)? _clipSegment(Offset a, Offset b, Rect rect) {
  var start = 0.0;
  var end = 1.0;
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final p = [-dx, dx, -dy, dy];
  final q = [
    a.dx - rect.left,
    rect.right - a.dx,
    a.dy - rect.top,
    rect.bottom - a.dy,
  ];
  for (var i = 0; i < 4; i++) {
    if (p[i].abs() < 0.000001) {
      if (q[i] < 0) return null;
    } else {
      final ratio = q[i] / p[i];
      if (p[i] < 0) {
        start = math.max(start, ratio);
      } else {
        end = math.min(end, ratio);
      }
      if (start > end) return null;
    }
  }
  return (Offset.lerp(a, b, start)!, Offset.lerp(a, b, end)!);
}
