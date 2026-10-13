import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_config.dart';
import '../app_error_mapper.dart';
import 'l10n_service.dart';

enum MapPlaceCategory { restaurant, cafe }

class MapPlace {
  const MapPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.point,
    this.openingHours = '',
  });

  final String id;
  final String name;
  final String address;
  final LatLng point;
  final String openingHours;

  static MapPlace? parse(dynamic raw) {
    if (raw is! Map) return null;
    final lat = double.tryParse('${raw['lat']}');
    final lng = double.tryParse('${raw['lon']}');
    if (lat == null || lng == null || !_validPoint(LatLng(lat, lng))) {
      return null;
    }
    final address = '${raw['display_name'] ?? ''}'.trim();
    final name = '${raw['name'] ?? ''}'.trim();
    if (address.isEmpty && name.isEmpty) return null;
    final tags = raw['extratags'];
    return MapPlace(
      id: '${raw['osm_type'] ?? 'place'}:${raw['osm_id'] ?? raw['place_id'] ?? '$lat,$lng'}',
      name: name.isEmpty ? address.split(',').first.trim() : name,
      address: address,
      point: LatLng(lat, lng),
      openingHours: tags is Map ? '${tags['opening_hours'] ?? ''}' : '',
    );
  }
}

class MapPlaceSearchQuery {
  const MapPlaceSearchQuery({
    required this.text,
    required this.language,
    this.center,
    this.category,
  });

  final String text;
  final String language;
  final LatLng? center;
  final MapPlaceCategory? category;

  Uri uri(Uri endpoint) {
    final parameters = <String, String>{
      'format': 'jsonv2',
      'limit': '15',
      'addressdetails': '1',
      'extratags': '1',
      'accept-language': language,
    };
    final trimmed = text.trim();
    parameters['q'] = category == null
        ? trimmed
        : trimmed.isEmpty
        ? '[${category!.name}]'
        : '$trimmed [${category!.name}]';
    final focus = center;
    if (focus != null && _validPoint(focus)) {
      // Khoảng 5 km mỗi hướng; tránh quét danh mục trên một vùng quá rộng.
      final deltaLng = 0.045 /
          math.cos(focus.latitude * math.pi / 180).abs().clamp(0.1, 1.0);
      parameters['viewbox'] = [
        (focus.longitude - deltaLng).clamp(-180.0, 180.0),
        (focus.latitude + 0.045).clamp(-90.0, 90.0),
        (focus.longitude + deltaLng).clamp(-180.0, 180.0),
        (focus.latitude - 0.045).clamp(-90.0, 90.0),
      ].map((value) => value.toStringAsFixed(5)).join(',');
      if (category != null && trimmed.isEmpty) parameters['bounded'] = '1';
    }
    return endpoint.replace(queryParameters: {
      ...endpoint.queryParameters,
      ...parameters,
    });
  }
}

/// Tìm kiếm chủ động bằng dữ liệu OSM; không gọi Mapbox Search có tính phí riêng.
/// Endpoint công cộng chỉ phù hợp pilot nhỏ. Khi mở rộng phải dùng proxy/provider
/// có hạn mức theo toàn app (throttle trên máy không thay thế giới hạn máy chủ).
class MapPlaceSearchService {
  MapPlaceSearchService({
    Uri? endpoint,
    http.Client Function()? clientFactory,
    Duration minimumInterval = const Duration(milliseconds: 1200),
  }) : _endpoint = endpoint ?? Uri.parse(AppConfig.nominatimSearchUrl),
       _clientFactory = clientFactory ?? http.Client.new,
       _minimumInterval = minimumInterval;

  final Uri _endpoint;
  final http.Client Function() _clientFactory;
  final Duration _minimumInterval;
  final _cache = LinkedHashMap<String, (DateTime, List<MapPlace>)>();
  Future<void> _tail = Future.value();
  DateTime? _lastRequest;
  int _generation = 0;

  void clear() {
    _generation++;
    _cache.clear();
  }

  Future<List<MapPlace>> search(
    MapPlaceSearchQuery query, {
    required bool Function() isAllowed,
    Future<void>? cancelled,
  }) async {
    final generation = _generation;
    bool permitted() => generation == _generation && isAllowed();
    if (!permitted()) throw _denied();
    if (query.text.trim().isEmpty && query.category == null) return const [];
    if (query.category != null && query.text.trim().isEmpty &&
        (query.center == null || !_validPoint(query.center!))) {
      throw AppErrorInfo(
        kind: AppErrorKind.user,
        message: L10nService().translate('map_pro_search_need_center'),
      );
    }
    final uri = query.uri(_endpoint);
    final key = uri.toString();
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 10)) {
      return cached.$2;
    }
    final previous = _tail;
    final complete = Completer<void>();
    _tail = complete.future;
    try {
      await previous;
      if (!permitted()) throw _denied();
      final latest = _cache[key];
      if (latest != null &&
          DateTime.now().difference(latest.$1) < const Duration(minutes: 10)) {
        return latest.$2;
      }
      final last = _lastRequest;
      if (last != null) {
        final delay = _minimumInterval - DateTime.now().difference(last);
        if (delay > Duration.zero) await Future<void>.delayed(delay);
      }
      if (!permitted()) throw _denied();
      final client = _clientFactory();
      var finished = false;
      cancelled?.then((_) {
        if (!finished) client.close();
      });
      _lastRequest = DateTime.now();
      try {
        final response = await client.get(uri, headers: const {
          'User-Agent': 'SoulLocket/4.0 (https://soullocket.pro.vn; support@soullocket.pro.vn)',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 12));
        if (!permitted()) throw _denied();
        if (response.statusCode != 200) {
          throw StateError('Place search HTTP ${response.statusCode}');
        }
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is! List) throw const FormatException('Expected places');
        final seen = <String>{};
        final places = <MapPlace>[];
        for (final raw in data) {
          final place = MapPlace.parse(raw);
          if (place != null && seen.add(place.id)) places.add(place);
        }
        final focus = query.center;
        if (focus != null && _validPoint(focus)) {
          const distance = Distance();
          places.sort((a, b) => distance(focus, a.point)
              .compareTo(distance(focus, b.point)));
        }
        final result = List<MapPlace>.unmodifiable(places);
        _cache[key] = (DateTime.now(), result);
        while (_cache.length > 64) _cache.remove(_cache.keys.first);
        return result;
      } finally {
        finished = true;
        client.close();
      }
    } catch (error) {
      throw permitted()
          ? AppErrorMapper.resolve(error,
              fallbackMessage: L10nService().translate('p9_map_search_error'))
          : _denied();
    } finally {
      complete.complete();
    }
  }

  AppErrorInfo _denied() => AppErrorInfo(
    kind: AppErrorKind.user,
    message: L10nService().translate('map_pro_required'),
  );
}

bool _validPoint(LatLng point) => point.latitude.isFinite &&
    point.longitude.isFinite && point.latitude >= -90 &&
    point.latitude <= 90 && point.longitude >= -180 && point.longitude <= 180;
