import 'package:firebase_database/firebase_database.dart';

class SoulMessageCursor {
  const SoulMessageCursor(this.timestamp, this.id);

  factory SoulMessageCursor.fromMessage(Map<String, dynamic> message) {
    return SoulMessageCursor(
      (message['timestamp'] as num?)?.toInt() ?? 0,
      message['id'].toString(),
    );
  }

  final int timestamp;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is SoulMessageCursor &&
      other.timestamp == timestamp &&
      other.id == id;

  @override
  int get hashCode => Object.hash(timestamp, id);
}

class SoulMessageHistory {
  static const pageSize = 20;

  final Map<String, Map<String, dynamic>> _byId = {};
  Set<String> _latestIds = {};
  bool _initialized = false;
  SoulMessageCursor? before;
  bool hasOlder = false;

  List<Map<String, dynamic>> get messages =>
      _byId.values.toList()..sort(compareMessages);

  static int compareMessages(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final timestampComparison = ((first['timestamp'] as num?)?.toInt() ?? 0)
        .compareTo((second['timestamp'] as num?)?.toInt() ?? 0);
    return timestampComparison != 0
        ? timestampComparison
        : first['id'].toString().compareTo(second['id'].toString());
  }

  static Query page(Query reference, {SoulMessageCursor? before}) {
    var query = reference.orderByChild('timestamp');
    if (before != null) {
      query = query.endBefore(before.timestamp, key: before.id);
    }
    return query.limitToLast(pageSize);
  }

  void applyLatest(List<Map<String, dynamic>> page) {
    final ordered = [...page]..sort(compareMessages);
    final incomingIds = ordered
        .map((message) => message['id'].toString())
        .toSet();
    final disconnectedGap =
        _latestIds.isNotEmpty &&
        incomingIds.isNotEmpty &&
        _latestIds.intersection(incomingIds).isEmpty;
    if (!_initialized || disconnectedGap || before == null) {
      before = ordered.isEmpty
          ? null
          : SoulMessageCursor.fromMessage(ordered.first);
      hasOlder = ordered.length == pageSize;
    } else {
      for (final message in ordered) {
        if (message['id']?.toString() == before!.id) {
          before = SoulMessageCursor.fromMessage(message);
          break;
        }
      }
    }
    _initialized = true;
    _latestIds = incomingIds;
    _merge(ordered);
  }

  void applyOlder(
    List<Map<String, dynamic>> page, {
    required SoulMessageCursor requestedBefore,
  }) {
    final ordered = [...page]..sort(compareMessages);
    _merge(ordered);
    if (before != requestedBefore) {
      return;
    }
    if (ordered.isNotEmpty) {
      before = SoulMessageCursor.fromMessage(ordered.first);
    }
    hasOlder = ordered.length == pageSize;
  }

  void _merge(List<Map<String, dynamic>> page) {
    for (final message in page) {
      final id = message['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        _byId[id] = Map<String, dynamic>.from(message);
      }
    }
  }
}
