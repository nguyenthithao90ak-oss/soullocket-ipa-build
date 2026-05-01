import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================
///  TravelPlannerService — Gra (Logic/Data)
///  Bản Đồ Hành Trình Tình Yêu (Phase 21)
///
///  Chức năng:
///  1. Thêm / Xóa địa điểm du lịch (Travel Pin) lên bản đồ.
///  2. Stream danh sách địa điểm đã đến.
///  3. Đánh dấu đã thăm / chưa thăm.
///  4. Thống kê số quốc gia & thành phố unique.
/// ============================================================
class TravelPlannerService {
  static final TravelPlannerService _instance =
      TravelPlannerService._internal();
  factory TravelPlannerService() => _instance;
  TravelPlannerService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  /// Thêm địa điểm du lịch mới lên bản đồ
  Future<String?> addTravelPin({
    required String houseId,
    required double lat,
    required double lng,
    required String city,
    String? country,
    String? note,
    String? imageUrl,
    bool visited = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final ref = _db.ref('houses/$houseId/travel_pins').push();
    await ref.set({
      'lat': lat,
      'lng': lng,
      'city': city,
      'country': country ?? '',
      'note': note ?? '',
      'imageUrl': imageUrl ?? '',
      'visited': visited,
      'addedBy': uid,
      'ts': ServerValue.timestamp,
    });
    return ref.key;
  }

  /// Xóa địa điểm du lịch
  Future<void> removeTravelPin(String houseId, String pinId) async {
    await _db.ref('houses/$houseId/travel_pins/$pinId').remove();
  }

  /// Đánh dấu đã thăm / chưa thăm địa điểm
  Future<void> toggleVisited(String houseId, String pinId, bool visited) async {
    await _db
        .ref('houses/$houseId/travel_pins/$pinId')
        .update({'visited': visited});
  }

  /// Cập nhật ghi chú và ảnh kỷ niệm cho địa điểm
  Future<void> updatePinMemory({
    required String houseId,
    required String pinId,
    String? note,
    String? imageUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (note != null) updates['note'] = note;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (updates.isNotEmpty) {
      await _db.ref('houses/$houseId/travel_pins/$pinId').update(updates);
    }
  }

  /// Stream danh sách tất cả địa điểm (để vẽ markers trên bản đồ)
  Stream<List<TravelPin>> streamTravelPins(String houseId) {
    return _db
        .ref('houses/$houseId/travel_pins')
        .orderByChild('ts')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <TravelPin>[];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((e) {
        final map = Map<String, dynamic>.from(e.value as Map);
        map['id'] = e.key.toString();
        return TravelPin.fromMap(map);
      }).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
    });
  }

  /// Lấy một lần (không realtime) danh sách địa điểm
  Future<List<TravelPin>> getTravelPins(String houseId) async {
    final snap =
        await _db.ref('houses/$houseId/travel_pins').orderByChild('ts').get();
    if (!snap.exists) return [];
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    return data.entries.map((e) {
      final map = Map<String, dynamic>.from(e.value as Map);
      map['id'] = e.key.toString();
      return TravelPin.fromMap(map);
    }).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
  }

  /// Thống kê số quốc gia và thành phố unique đã thăm
  Future<TravelStats> getStats(String houseId) async {
    final pins = await getTravelPins(houseId);
    final visitedPins = pins.where((p) => p.visited).toList();
    final countries =
        visitedPins.map((p) => p.country).where((c) => c.isNotEmpty).toSet();
    final cities =
        visitedPins.map((p) => p.city).where((c) => c.isNotEmpty).toSet();
    return TravelStats(
      totalPins: pins.length,
      visitedPins: visitedPins.length,
      uniqueCountries: countries.length,
      uniqueCities: cities.length,
    );
  }
}

// ─── Models ─────────────────────────────────────────────────────────────────

class TravelPin {
  final String id;
  final double lat;
  final double lng;
  final String city;
  final String country;
  final String note;
  final String imageUrl;
  final bool visited;
  final String addedBy;
  final int ts;

  TravelPin({
    required this.id,
    required this.lat,
    required this.lng,
    required this.city,
    required this.country,
    required this.note,
    required this.imageUrl,
    required this.visited,
    required this.addedBy,
    required this.ts,
  });

  factory TravelPin.fromMap(Map<String, dynamic> map) {
    return TravelPin(
      id: map['id']?.toString() ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      city: map['city']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      visited: map['visited'] == true,
      addedBy: map['addedBy']?.toString() ?? '',
      ts: (map['ts'] as num?)?.toInt() ?? 0,
    );
  }
}

class TravelStats {
  final int totalPins;
  final int visitedPins;
  final int uniqueCountries;
  final int uniqueCities;

  TravelStats({
    required this.totalPins,
    required this.visitedPins,
    required this.uniqueCountries,
    required this.uniqueCities,
  });
}
