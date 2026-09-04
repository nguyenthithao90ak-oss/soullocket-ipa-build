import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../resilient_http.dart';

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
    try {
      final uri = Uri.parse(
        '$_baseUrl/search?q=${Uri.encodeQueryComponent(query)}&format=json&limit=10&addressdetails=1',
      );
      final response = await ResilientHttp.get(
        uri,
        headers: {'User-Agent': 'SoulLocketApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => NominatimPlace.fromJson(json)).toList();
      }
    } catch (e) {
      // Ignore errors for now
    }
    return [];
  }

  /// Reverse geocode coordinates to an address
  static Future<String?> reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1',
      );
      final response = await ResilientHttp.get(
        uri,
        headers: {'User-Agent': 'SoulLocketApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'];
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }
}
