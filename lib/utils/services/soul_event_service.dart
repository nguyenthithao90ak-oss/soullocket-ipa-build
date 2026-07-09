import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';

class SoulEventService {
  static final SoulEventService _instance = SoulEventService._internal();
  factory SoulEventService() => _instance;
  SoulEventService._internal();

  final _db = FirebaseDatabase.instance.ref();

  Stream<List<SoulEvent>> streamEvents(String houseId) {
    return _db.child('houses/$houseId/soul_events').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return [];
      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final events = <SoulEvent>[];
      raw.forEach((key, value) {
        if (value is Map) {
          events.add(SoulEvent.fromJson(key.toString(), value));
        }
      });
      events.sort((a, b) => a.dateMs.compareTo(b.dateMs));
      return events;
    });
  }

  Future<List<SoulEvent>> getEvents(String houseId) async {
    final event = await _db.child('houses/$houseId/soul_events').get();
    if (!event.exists || event.value is! Map) return [];
    final raw = Map<dynamic, dynamic>.from(event.value as Map);
    final events = <SoulEvent>[];
    raw.forEach((key, value) {
      if (value is Map) {
        events.add(SoulEvent.fromJson(key.toString(), value));
      }
    });
    events.sort((a, b) => a.dateMs.compareTo(b.dateMs));
    return events;
  }

  Future<void> saveEvent(String houseId, SoulEvent event) async {
    final id = event.id.isEmpty ? _db.push().key! : event.id;
    await _db.child('houses/$houseId/soul_events/$id').set(event.copyWith(id: id).toJson());
    await WidgetService.syncSoulEventWidgetData(houseId: houseId);
  }

  Future<void> deleteEvent(String houseId, String eventId) async {
    await _db.child('houses/$houseId/soul_events/$eventId').remove();
    await WidgetService.syncSoulEventWidgetData(houseId: houseId);
  }
}
