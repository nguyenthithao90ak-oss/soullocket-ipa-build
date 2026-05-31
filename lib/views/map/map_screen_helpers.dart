part of 'map_screen.dart';

extension _MapScreenHelpers on _MapScreenState {
  String _buildMemorySummaryLabel(int total) {
    if (total <= 0) return L10nService().translate('map_chacghimkn_c6823f');
    final visible = math.min(total, _kMaxRenderedMemoryMarkers);
    if (total <= _kMaxRenderedMemoryMarkers) {
      return '$total ghim kỷ niệm trên bản đồ';
    }
    return '$total ghim • đang hiển thị $visible mới nhất';
  }

  String _buildCheckinSummaryLabel(int total) {
    if (total <= 0) return L10nService().translate('map_chacchecki_51b108');
    final visible = math.min(total, _kMaxRenderedCheckinMarkers);
    if (total <= _kMaxRenderedCheckinMarkers) {
      return '$total check-in gần đây';
    }
    return '$total check-in • đang hiển thị $visible mới nhất';
  }

  String _formatFullDate(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${_prettyDayFormat.format(date)} • ${_timeFormat.format(date)}';
  }

  String _buildCoordinateCacheKey(
    double lat,
    double lng, {
    int precision = 4,
  }) {
    return '${lat.toStringAsFixed(precision)}_${lng.toStringAsFixed(precision)}';
  }

  String _buildRouteCacheLookupKey(ll.LatLng start, ll.LatLng end) {
    return '${_buildCoordinateCacheKey(
      start.latitude,
      start.longitude,
      precision: 4,
    )}|${_buildCoordinateCacheKey(
      end.latitude,
      end.longitude,
      precision: 4,
    )}';
  }

  bool _isCacheEntryFresh(
    Map<String, int> timestamps,
    String key,
    Duration ttl,
  ) {
    final cachedAt = timestamps[key];
    if (cachedAt == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch - cachedAt <=
        ttl.inMilliseconds;
  }

  void _trimRouteCache() {
    _trimTimedCacheEntries(
      timestamps: _routeCacheTs,
      ttl: _kMapRouteCacheTtl,
      maxEntries: _kMapRouteCacheMaxEntries,
      onEvict: (key) => _routeCache.remove(key),
    );
  }

  void _trimReverseGeocodeCache() {
    _trimTimedCacheEntries(
      timestamps: _reverseGeocodeCacheTs,
      ttl: _kMapReverseGeocodeCacheTtl,
      maxEntries: _kMapReverseGeocodeCacheMaxEntries,
      onEvict: (key) => _reverseGeocodeCache.remove(key),
    );
  }

  void _trimTimedCacheEntries({
    required Map<String, int> timestamps,
    required Duration ttl,
    required int maxEntries,
    required void Function(String key) onEvict,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredKeys = <String>[
      for (final entry in timestamps.entries)
        if (now - entry.value > ttl.inMilliseconds) entry.key,
    ];
    for (final key in expiredKeys) {
      timestamps.remove(key);
      onEvict(key);
    }

    if (timestamps.length <= maxEntries) {
      return;
    }

    final sortedEntries = timestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final overflowCount = timestamps.length - maxEntries;
    for (final entry in sortedEntries.take(overflowCount)) {
      timestamps.remove(entry.key);
      onEvict(entry.key);
    }
  }
}
