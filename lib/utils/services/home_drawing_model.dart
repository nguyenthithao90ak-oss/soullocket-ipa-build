import 'dart:convert';

const int homeDrawingMaxStrokes = 80;
const int homeDrawingMaxPoints = 160;
const int homeDrawingMinWidth = 2;
const int homeDrawingMaxWidth = 24;
const int homeDrawingCoordinateMax = 4095;

List<dynamic> homeDrawingListItems(Object? value) {
  if (value is List) return value;
  if (value is! Map) return const <dynamic>[];
  final entries = value.entries.toList()
    ..sort((a, b) => int.tryParse('${a.key}')?.compareTo(
              int.tryParse('${b.key}') ?? 0,
            ) ??
            0);
  return [for (final entry in entries) entry.value];
}

int? _safeInt(Object? value, {int? min, int? max}) {
  final parsed = value is int ? value : int.tryParse('$value');
  if (parsed == null || (min != null && parsed < min) || (max != null && parsed > max)) {
    return null;
  }
  return parsed;
}

class HomeDrawingPoint {
  const HomeDrawingPoint(this.x, this.y);

  final int x;
  final int y;

  factory HomeDrawingPoint.fromRaw(Object? raw) {
    if (raw is! List || raw.length != 2) {
      throw const FormatException('invalid_home_drawing_point');
    }
    final x = _safeInt(raw[0], min: 0, max: homeDrawingCoordinateMax);
    final y = _safeInt(raw[1], min: 0, max: homeDrawingCoordinateMax);
    if (x == null || y == null) {
      throw const FormatException('invalid_home_drawing_point');
    }
    return HomeDrawingPoint(x, y);
  }

  List<int> toJson() => [x, y];

  double get normalizedX => x / homeDrawingCoordinateMax;
  double get normalizedY => y / homeDrawingCoordinateMax;
}

class HomeDrawingStroke {
  const HomeDrawingStroke({
    required this.id,
    required this.color,
    required this.width,
    required this.points,
  });

  final String id;
  final int color;
  final int width;
  final List<HomeDrawingPoint> points;

  factory HomeDrawingStroke.fromRaw(Object? raw) {
    if (raw is! Map) throw const FormatException('invalid_home_drawing_stroke');
    final id = raw['id'];
    final color = _safeInt(raw['color'], min: 0xff000000, max: 0xffffffff);
    final width = _safeInt(
      raw['width'],
      min: homeDrawingMinWidth,
      max: homeDrawingMaxWidth,
    );
    final rawPoints = homeDrawingListItems(raw['points']);
    if (id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id) ||
        color == null ||
        width == null ||
        rawPoints.isEmpty ||
        rawPoints.length > homeDrawingMaxPoints) {
      throw const FormatException('invalid_home_drawing_stroke');
    }
    return HomeDrawingStroke(
      id: id,
      color: color,
      width: width,
      points: List.unmodifiable([
        for (final point in rawPoints) HomeDrawingPoint.fromRaw(point),
      ]),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color,
        'width': width,
        'points': [for (final point in points) point.toJson()],
      };

  HomeDrawingStroke copyWith({
    int? color,
    int? width,
    List<HomeDrawingPoint>? points,
  }) {
    return HomeDrawingStroke(
      id: id,
      color: color ?? this.color,
      width: width ?? this.width,
      points: points ?? this.points,
    );
  }
}

class HomeDrawingBoard {
  const HomeDrawingBoard({
    required this.strokes,
    this.revision = 0,
    this.updatedAt = 0,
    this.updatedBy = '',
    this.requestId = '',
  });

  factory HomeDrawingBoard.empty() => const HomeDrawingBoard(strokes: []);

  final List<HomeDrawingStroke> strokes;
  final int revision;
  final int updatedAt;
  final String updatedBy;
  final String requestId;

  factory HomeDrawingBoard.fromRaw(Object? raw) {
    if (raw == null) return HomeDrawingBoard.empty();
    if (raw is! Map || raw['version'] != 1) {
      throw const FormatException('invalid_home_drawing_board');
    }
    final revision = _safeInt(raw['revision'], min: 0);
    final rawDrawing = raw['drawing'];
    final rawStrokes = rawDrawing is Map
        ? homeDrawingListItems(rawDrawing['strokes'])
        : const <dynamic>[];
    if (revision == null || rawStrokes.length > homeDrawingMaxStrokes) {
      throw const FormatException('invalid_home_drawing_board');
    }
    final strokes = <HomeDrawingStroke>[];
    for (final stroke in rawStrokes) {
      strokes.add(HomeDrawingStroke.fromRaw(stroke));
    }
    return HomeDrawingBoard(
      strokes: List.unmodifiable(strokes),
      revision: revision,
      updatedAt: _safeInt(raw['updatedAt'], min: 0) ?? 0,
      updatedBy: raw['updatedBy'] is String ? raw['updatedBy'] as String : '',
      requestId: raw['requestId'] is String ? raw['requestId'] as String : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'drawing': {
          'version': 1,
          'strokes': [for (final stroke in strokes) stroke.toJson()],
        },
        'revision': revision,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
        'requestId': requestId,
      };

  String get json => jsonEncode(toJson());
}

class HomeDrawingStatus {
  const HomeDrawingStatus({
    required this.available,
    required this.reason,
    required this.serverNow,
    required this.nextCheckAt,
    required this.expiresAt,
    required this.sessionId,
    this.snapshot,
  });

  const HomeDrawingStatus.locked({
    this.available = false,
    this.reason = 'locked',
    this.serverNow = 0,
    this.nextCheckAt = 0,
    this.expiresAt = 0,
    this.sessionId = '',
  }) : snapshot = null;

  final bool available;
  final String reason;
  final int serverNow;
  final int nextCheckAt;
  final int expiresAt;
  final String sessionId;
  final HomeDrawingBoard? snapshot;

  factory HomeDrawingStatus.fromRaw(Object? raw) {
    if (raw is! Map) throw const FormatException('invalid_home_drawing_status');
    return HomeDrawingStatus(
      available: raw['available'] == true,
      reason: raw['reason'] is String ? raw['reason'] as String : 'locked',
      serverNow: _safeInt(raw['serverNow'], min: 0) ?? 0,
      nextCheckAt: _safeInt(raw['nextCheckAt'], min: 0) ?? 0,
      expiresAt: _safeInt(raw['expiresAt'], min: 0) ?? 0,
      sessionId: raw['sessionId'] is String ? raw['sessionId'] as String : '',
      snapshot: raw['snapshot'] == null
          ? null
          : HomeDrawingBoard.fromRaw(raw['snapshot']),
    );
  }

  bool isActiveAt(int serverNowMs) =>
      available && expiresAt > 0 && expiresAt > serverNowMs;
}

class HomeDrawingLocalState {
  const HomeDrawingLocalState({
    required this.confirmed,
    this.draftStrokes,
    this.baseRevision = 0,
    this.pendingRequestId = '',
  });

  factory HomeDrawingLocalState.empty() =>
      HomeDrawingLocalState(confirmed: HomeDrawingBoard.empty());

  final HomeDrawingBoard confirmed;
  final List<HomeDrawingStroke>? draftStrokes;
  final int baseRevision;
  final String pendingRequestId;

  bool get hasDraft => draftStrokes != null;
  List<HomeDrawingStroke> get visibleStrokes => draftStrokes ?? confirmed.strokes;

  HomeDrawingLocalState copyWith({
    HomeDrawingBoard? confirmed,
    List<HomeDrawingStroke>? draftStrokes,
    bool clearDraft = false,
    int? baseRevision,
    String? pendingRequestId,
  }) {
    return HomeDrawingLocalState(
      confirmed: confirmed ?? this.confirmed,
      draftStrokes: clearDraft ? null : draftStrokes ?? this.draftStrokes,
      baseRevision: baseRevision ?? this.baseRevision,
      pendingRequestId: pendingRequestId ?? this.pendingRequestId,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'confirmed': confirmed.toJson(),
        'draftStrokes': draftStrokes == null
            ? null
            : [for (final stroke in draftStrokes!) stroke.toJson()],
        'baseRevision': baseRevision,
        'pendingRequestId': pendingRequestId,
      };

  factory HomeDrawingLocalState.fromRaw(Object? raw) {
    if (raw is! Map || raw['version'] != 1) {
      return HomeDrawingLocalState.empty();
    }
    final confirmed = HomeDrawingBoard.fromRaw(raw['confirmed']);
    final rawDraft = raw['draftStrokes'];
    List<HomeDrawingStroke>? draft;
    if (rawDraft != null) {
      final items = homeDrawingListItems(rawDraft);
      if (items.length > homeDrawingMaxStrokes) {
        throw const FormatException('invalid_home_drawing_draft');
      }
      draft = List.unmodifiable([
        for (final item in items) HomeDrawingStroke.fromRaw(item),
      ]);
    }
    return HomeDrawingLocalState(
      confirmed: confirmed,
      draftStrokes: draft,
      baseRevision: _safeInt(raw['baseRevision'], min: 0) ?? confirmed.revision,
      pendingRequestId:
          raw['pendingRequestId'] is String ? raw['pendingRequestId'] as String : '',
    );
  }
}
