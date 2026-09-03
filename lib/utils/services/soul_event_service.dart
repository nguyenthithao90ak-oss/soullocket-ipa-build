import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:soullocket_app/models/soul_event.dart';
import 'package:soullocket_app/utils/services/local_database_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';

class SoulEventService {
  static final SoulEventService _instance = SoulEventService._internal();
  factory SoulEventService() => _instance;
  SoulEventService._internal();

  final _updateController = StreamController<String>.broadcast();
  final Random _random = Random();

  Stream<List<SoulEvent>> streamEvents(String houseId) async* {
    yield await getEvents(houseId);
    await for (final _
        in _updateController.stream.where((id) => id == houseId)) {
      yield await getEvents(houseId);
    }
  }

  Future<List<SoulEvent>> getEvents(String houseId) async {
    final cacheData = await LocalDatabaseService()
        .getCacheEntry('soul_events_local_$houseId');
    if (cacheData != null) {
      try {
        final raw = jsonDecode(cacheData);
        if (raw is List) {
          final events = raw
              .map((e) => SoulEvent.fromJson(e['id']?.toString() ?? '', e))
              .toList();
          events.sort((a, b) => a.dateMs.compareTo(b.dateMs));
          return events;
        }
      } catch (_) {}
    }
    return [];
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1 << 32).toRadixString(36)}';
  }

  Future<void> saveEvent(String houseId, SoulEvent event) async {
    final id = event.id.isEmpty ? _generateId() : event.id;
    final payload = event.copyWith(id: id);

    final events = await getEvents(houseId);
    final index = events.indexWhere((e) => e.id == id);
    if (index >= 0) {
      events[index] = payload;
    } else {
      events.add(payload);
    }

    await _saveToLocal(houseId, events);
    _updateController.add(houseId);
    await WidgetService.syncSoulEventWidgetData(houseId: houseId);
  }

  Future<void> deleteEvent(String houseId, String eventId) async {
    final events = await getEvents(houseId);
    events.removeWhere((e) => e.id == eventId);

    await _saveToLocal(houseId, events);
    _updateController.add(houseId);
    await WidgetService.syncSoulEventWidgetData(houseId: houseId);
  }

  Future<void> _saveToLocal(String houseId, List<SoulEvent> events) async {
    final cacheJson =
        jsonEncode(events.map((e) => e.toJson()..['id'] = e.id).toList());
    await LocalDatabaseService()
        .setCacheEntry('soul_events_local_$houseId', cacheJson);
  }
}
