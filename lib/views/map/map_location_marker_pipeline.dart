part of 'map_screen.dart';

extension _MapLocationMarkerPipelineExt on _MapScreenState {
  String _buildMemoryMarkerDataSignature(List<_MapMemoryItem> items) {
    if (items.isEmpty) return '';
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.write(_memoryContentKey(item));
      buffer.write('~');
    }
    return buffer.toString();
  }

  String _buildCheckinMarkerDataSignature(List<_MapCheckinItem> items) {
    if (items.isEmpty) return '';
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.write(
        [
          item.id,
          item.lat.toStringAsFixed(5),
          item.lng.toStringAsFixed(5),
          item.ts ?? 0,
          item.title,
          item.note,
          item.imageUrl,
          item.role,
          item.author,
        ].join('|'),
      );
      buffer.write('~');
    }
    return buffer.toString();
  }

  String _buildCheckinPolylineDataSignature(List<_MapCheckinItem> items) {
    if (items.isEmpty) return '';
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.write(
        '${item.id}|${item.lat.toStringAsFixed(5)}|'
        '${item.lng.toStringAsFixed(5)}|${item.ts ?? 0}~',
      );
    }
    return buffer.toString();
  }

  bool _rebuildStaticMarkersCached({
    bool rebuildMemories = true,
    bool rebuildCheckins = true,
  }) {
    final cache = _memoryPipelineState.staticMarkerCache;
    var didUpdateStaticMarkers = false;
    var didUpdateCheckinPolylines = false;

    if (rebuildMemories) {
      final renderedMemories =
          _memories.take(_kMaxRenderedMemoryMarkers).toList(growable: false);
      final memoryMarkerSignature =
          _buildMemoryMarkerDataSignature(renderedMemories);

      if (memoryMarkerSignature != cache.memoryMarkerSignature) {
        final memoryMarkerSpecs = <_MapMarkerSpec>[
          for (final memory in renderedMemories)
            _MapMarkerSpec(
              id: 'memory_${memory.id}',
              point: ll.LatLng(memory.lat, memory.lng),
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF8B5CF6),
              title: memory.title,
              subtitle: memory.note.isEmpty
                  ? L10nService().translate('map_knimbn_288ae0')
                  : memory.note,
              compact: true,
              onTap: () => _showMemoryDialog(memory),
            ),
        ];

        cache.memoryMarkers = memoryMarkerSpecs.isEmpty
            ? const <fm.Marker>[]
            : memoryMarkerSpecs.map(_buildOsmMarker).toList(growable: false);
        cache.memoryMarkerSignature = memoryMarkerSignature;
      }
    }

    if (rebuildCheckins) {
      final renderedCheckins =
          _checkins.take(_kMaxRenderedCheckinMarkers).toList(growable: false);
      final sortedCheckins = List<_MapCheckinItem>.of(renderedCheckins)
        ..sort((a, b) => (a.ts ?? 0).compareTo(b.ts ?? 0));

      final checkinMarkerSignature =
          _buildCheckinMarkerDataSignature(sortedCheckins);
      if (checkinMarkerSignature != cache.checkinMarkerSignature) {
        final checkinMarkerSpecs = <_MapMarkerSpec>[
          for (final checkin in sortedCheckins)
            _MapMarkerSpec(
              id: 'checkin_${checkin.id}',
              point: ll.LatLng(checkin.lat, checkin.lng),
              icon: Icons.favorite_rounded,
              color: _kMapPink,
              title: checkin.title,
              subtitle: checkin.note.isEmpty ? 'Check-in' : checkin.note,
              compact: true,
              onTap: () => _showCheckinDialog(checkin),
            ),
        ];

        cache.checkinMarkers = checkinMarkerSpecs.isEmpty
            ? const <fm.Marker>[]
            : checkinMarkerSpecs.map(_buildOsmMarker).toList(growable: false);
        cache.checkinMarkerSignature = checkinMarkerSignature;
      }

      final checkinPolylineSignature =
          _buildCheckinPolylineDataSignature(sortedCheckins);
      if (checkinPolylineSignature != cache.checkinPolylineSignature) {
        final checkinPoints = <ll.LatLng>[
          for (final checkin in sortedCheckins)
            ll.LatLng(checkin.lat, checkin.lng),
        ];
        final checkinPolylines = <fm.Polyline>[];
        if (checkinPoints.length > 1) {
          final compressedCheckinPoints = _compressLatLngPoints(checkinPoints);
          checkinPolylines.add(
            _buildSharpPolyline(
              points: compressedCheckinPoints,
              color: _kMapPinkDeep,
              gradientColors: const [_kMapPinkSoft, _kMapPinkDeep],
              strokeWidth: 4.6,
              borderStrokeWidth: 1.8,
            ),
          );
        }

        cache.checkinPolylines = checkinPolylines;
        cache.checkinPolylineSignature = checkinPolylineSignature;
        didUpdateCheckinPolylines = true;
      }
    }

    final combinedMarkerSignature =
        '${cache.memoryMarkerSignature}||${cache.checkinMarkerSignature}';
    if (combinedMarkerSignature != cache.combinedMarkerSignature) {
      cache.combinedMarkerSignature = combinedMarkerSignature;
      _setStaticMarkers(<fm.Marker>[
        ...cache.memoryMarkers,
        ...cache.checkinMarkers,
      ]);
      didUpdateStaticMarkers = true;
    }

    if (didUpdateCheckinPolylines) {
      _setCheckinPolylines(cache.checkinPolylines);
    }

    return didUpdateStaticMarkers || didUpdateCheckinPolylines;
  }

  void _rebuildStaticMarkers() {
    final staticMarkerSpecs = <_MapMarkerSpec>[];
    final checkinPoints = <ll.LatLng>[];
    final renderedMemories = _memories.take(_kMaxRenderedMemoryMarkers);
    final renderedCheckins =
        _checkins.take(_kMaxRenderedCheckinMarkers).toList(growable: false);

    for (final memory in renderedMemories) {
      staticMarkerSpecs.add(
        _MapMarkerSpec(
          id: 'memory_${memory.id}',
          point: ll.LatLng(memory.lat, memory.lng),
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF8B5CF6),
          title: memory.title,
          subtitle: memory.note.isEmpty
              ? L10nService().translate('map_knimbn_288ae0')
              : memory.note,
          compact: true,
          onTap: () => _showMemoryDialog(memory),
        ),
      );
    }

    final sortedCheckins = List.of(renderedCheckins)
      ..sort((a, b) => (a.ts ?? 0).compareTo(b.ts ?? 0));

    for (final checkin in sortedCheckins) {
      final point = ll.LatLng(checkin.lat, checkin.lng);
      checkinPoints.add(point);
      staticMarkerSpecs.add(
        _MapMarkerSpec(
          id: 'checkin_${checkin.id}',
          point: point,
          icon: Icons.favorite_rounded,
          color: _kMapPink,
          title: checkin.title,
          subtitle: checkin.note.isEmpty ? 'Check-in' : checkin.note,
          compact: true,
          onTap: () => _showCheckinDialog(checkin),
        ),
      );
    }

    List<fm.Polyline> checkinPolylines = [];
    if (checkinPoints.length > 1) {
      final compressedCheckinPoints = _compressLatLngPoints(checkinPoints);
      if (compressedCheckinPoints.length >= 2) {
        checkinPolylines.add(
          _buildSharpPolyline(
            points: compressedCheckinPoints,
            color: _kMapPinkDeep,
            gradientColors: const [_kMapPinkSoft, _kMapPinkDeep],
            strokeWidth: 4.6,
            borderStrokeWidth: 1.8,
          ),
        );
      }
    }

    if (!mounted) return;
    _setStaticMarkers(
      staticMarkerSpecs.map(_buildOsmMarker).toList(growable: false),
    );
    _setCheckinPolylines(checkinPolylines);
  }
}

enum _MapMemorySourceKind {
  publicHouseBucket,
  publicDirect,
  houseScoped,
}

extension on _MapMemorySourceKind {
  String get prefix {
    switch (this) {
      case _MapMemorySourceKind.publicHouseBucket:
        return 'public_house_bucket';
      case _MapMemorySourceKind.publicDirect:
        return 'public_direct';
      case _MapMemorySourceKind.houseScoped:
        return 'house_scoped';
    }
  }

  int get priority {
    switch (this) {
      case _MapMemorySourceKind.publicHouseBucket:
        return 3;
      case _MapMemorySourceKind.publicDirect:
        return 2;
      case _MapMemorySourceKind.houseScoped:
        return 1;
    }
  }
}

class _MapMemorySourceRecord {
  final String scopedKey;
  final _MapMemorySourceKind kind;
  final String rawKey;
  final String dedupeKey;
  final String contentKey;
  final _MapMemoryItem item;

  const _MapMemorySourceRecord({
    required this.scopedKey,
    required this.kind,
    required this.rawKey,
    required this.dedupeKey,
    required this.contentKey,
    required this.item,
  });

  int get priority => kind.priority;
}

class _MapStaticMarkerCache {
  List<fm.Marker> memoryMarkers = const <fm.Marker>[];
  List<fm.Marker> checkinMarkers = const <fm.Marker>[];
  List<fm.Polyline> checkinPolylines = const <fm.Polyline>[];
  String memoryMarkerSignature = '';
  String checkinMarkerSignature = '';
  String checkinPolylineSignature = '';
  String combinedMarkerSignature = '';
}

class _MapMemoryPipelineState {
  final List<StreamSubscription<DatabaseEvent>> subscriptions =
      <StreamSubscription<DatabaseEvent>>[];
  final Map<String, _MapMemorySourceRecord> recordsByScopedKey =
      <String, _MapMemorySourceRecord>{};
  final Map<String, Set<String>> scopedKeysByDedupKey = <String, Set<String>>{};
  final Map<_MapMemorySourceKind, Set<String>> scopedKeysByKind =
      <_MapMemorySourceKind, Set<String>>{};
  final Map<String, _MapMemorySourceRecord> canonicalByDedupKey =
      <String, _MapMemorySourceRecord>{};
  final List<String> orderedDedupKeys = <String>[];
  final _MapStaticMarkerCache staticMarkerCache = _MapStaticMarkerCache();
  Timer? debounce;
  Timer? houseDebounce;
}
