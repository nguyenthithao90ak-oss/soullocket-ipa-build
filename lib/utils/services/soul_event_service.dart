import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/utils/services/local_database_service.dart';
import 'package:soullocket_app/utils/services/connectivity_service.dart';

class SoulEventService {
  static final SoulEventService _instance = SoulEventService._internal();
  factory SoulEventService() => _instance;
  SoulEventService._internal();

  final _db = FirebaseDatabase.instance.ref();

  Stream<List<SoulEvent>> streamEvents(String houseId) async* {
    final cacheData =
        await LocalDatabaseService().getCacheEntry('soul_events_$houseId');
    if (cacheData != null) {
      try {
        final raw = jsonDecode(cacheData);
        if (raw is List) {
          yield raw
              .map((e) => SoulEvent.fromJson(e['id']?.toString() ?? '', e))
              .toList();
        }
      } catch (_) {}
    }

    yield* _db.child('houses/$houseId/soul_events').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map)
        return <SoulEvent>[];
      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final events = <SoulEvent>[];
      raw.forEach((key, value) {
        if (value is Map) {
          events.add(SoulEvent.fromJson(key.toString(), value));
        }
      });
      events.sort((a, b) => a.dateMs.compareTo(b.dateMs));

      // Save to cache
      final cacheJson =
          jsonEncode(events.map((e) => e.toJson()..['id'] = e.id).toList());
      LocalDatabaseService().setCacheEntry('soul_events_$houseId', cacheJson);

      return events;
    });
  }

  Future<List<SoulEvent>> getEvents(String houseId) async {
    if (!ConnectivityService().isOnline) {
      final cacheData =
          await LocalDatabaseService().getCacheEntry('soul_events_$houseId');
      if (cacheData != null) {
        try {
          final raw = jsonDecode(cacheData);
          if (raw is List) {
            return raw
                .map((e) => SoulEvent.fromJson(e['id']?.toString() ?? '', e))
                .toList();
          }
        } catch (_) {}
      }
      return [];
    }

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

    // Save to cache
    final cacheJson =
        jsonEncode(events.map((e) => e.toJson()..['id'] = e.id).toList());
    LocalDatabaseService().setCacheEntry('soul_events_$houseId', cacheJson);

    return events;
  }

  Future<void> saveEvent(String houseId, SoulEvent event) async {
    final id = event.id.isEmpty ? _db.push().key! : event.id;
    final payload = event.copyWith(id: id).toJson();
    final path = 'houses/$houseId/soul_events/$id';

    if (!ConnectivityService().isOnline) {
      await ConnectivityService().enqueueOfflineData(path, 'set', payload);
    } else {
      await _db.child(path).set(payload);
    }
    await WidgetService.syncSoulEventWidgetData(houseId: houseId);
  }

  Future<void> deleteEvent(String houseId, String eventId) async {
    final path = 'houses/$houseId/soul_events/$eventId';
    if (!ConnectivityService().isOnline) {
      await ConnectivityService().enqueueOfflineData(path, 'remove', {});
    } else {
      await _db.child(path).remove();
    }
    await WidgetService.syncSoulEventWidgetData(houseId: houseId);
  }
}
