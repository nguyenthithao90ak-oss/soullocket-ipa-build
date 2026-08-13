import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:soullocket_app/utils/services/core/api_cache_manager.dart';

class NominatimPlace {
  final String name;
  final String displayName;
  final LatLng latLng;

  NominatimPlace({
    required this.name,
    required this.displayName,
    required this.latLng,
  });

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    return NominatimPlace(
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? '',
      latLng: LatLng(
        double.parse(json['lat'] ?? '0'),
        double.parse(json['lon'] ?? '0'),
      ),
    );
  }
}

class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  /// Search for a place by name
  static Future<List<NominatimPlace>> search(String query) async {
    if (query.trim().isEmpty) return [];
    
    final cacheKey = 'nominatim_search_${query.trim()}';
    final cachedData = await ApiCacheManager.getCache(cacheKey);
    if (cachedData != null) {
      final List<dynamic> data = cachedData;
      return data.map((json) => NominatimPlace.fromJson(json)).toList();
    }

    try {
      final uri = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=10&addressdetails=1');
      final response = await http.get(uri, headers: {
        'User-Agent': 'SoulLocketApp/1.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await ApiCacheManager.saveCache(cacheKey, data, const Duration(days: 7));
        return data.map((json) => NominatimPlace.fromJson(json)).toList();
      }
    } catch (e) {
      // Ignore errors
    }
    return [];
  }

  /// Reverse geocode coordinates to an address
  static Future<String?> reverseGeocode(LatLng point) async {
    final lat = point.latitude.toStringAsFixed(4);
    final lon = point.longitude.toStringAsFixed(4);
    final cacheKey = 'nominatim_reverse_${lat}_$lon';
    
    final cachedData = await ApiCacheManager.getCache(cacheKey);
    if (cachedData != null) {
      return cachedData as String;
    }

    try {
      final uri = Uri.parse('$_baseUrl/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1');
      final response = await http.get(uri, headers: {
        'User-Agent': 'SoulLocketApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'];
        if (displayName != null) {
          await ApiCacheManager.saveCache(cacheKey, displayName, const Duration(days: 30));
        }
        return displayName;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }
}
