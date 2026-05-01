part of '../cinema_screen.dart';

class _CinemaMemoryRecord {
  final String id;
  final String imageUrl;
  final String thumbnailUrl;
  final String authorName;
  final DateTime timestamp;

  const _CinemaMemoryRecord({
    required this.id,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.authorName,
    required this.timestamp,
  });

  String get displayUrl => thumbnailUrl.isEmpty ? imageUrl : thumbnailUrl;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'authorName': authorName,
      'timestampMs': timestamp.millisecondsSinceEpoch,
    };
  }

  static _CinemaMemoryRecord? fromRaw(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    final id = data['id']?.toString().trim() ?? '';
    final imageUrl = data['imageUrl']?.toString().trim() ?? '';
    if (id.isEmpty || imageUrl.isEmpty) {
      return null;
    }
    final timestampMs = (data['timestampMs'] as num?)?.toInt() ?? 0;
    return _CinemaMemoryRecord(
      id: id,
      imageUrl: imageUrl,
      thumbnailUrl: data['thumbnailUrl']?.toString().trim() ?? '',
      authorName: data['authorName']?.toString().trim() ?? '',
      timestamp: timestampMs <= 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
    );
  }
}

class _CinemaReelBadge {
  final IconData icon;
  final String label;
  final Color accent;

  const _CinemaReelBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });
}

class _CinemaDailyReel {
  final String dateKey;
  final String title;
  final String subtitle;
  final int accentValue;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<_CinemaMemoryRecord> items;

  const _CinemaDailyReel({
    required this.dateKey,
    required this.title,
    required this.subtitle,
    required this.accentValue,
    required this.createdAt,
    required this.expiresAt,
    required this.items,
  });

  bool isActiveAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _dateKeyFor(today);
    return dateKey == todayKey && expiresAt.isAfter(now);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'dateKey': dateKey,
      'title': title,
      'subtitle': subtitle,
      'accentValue': accentValue,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'expiresAtMs': expiresAt.millisecondsSinceEpoch,
      'items': items.map((item) => item.toMap()).toList(growable: false),
    };
  }

  static _CinemaDailyReel? fromRaw(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    final dateKey = data['dateKey']?.toString().trim() ?? '';
    final title = data['title']?.toString().trim() ?? '';
    final subtitle = data['subtitle']?.toString().trim() ?? '';
    final accentValue =
        (data['accentValue'] as num?)?.toInt() ?? const Color(0xFFFF6FA5).value;
    final createdAtMs = (data['createdAtMs'] as num?)?.toInt() ?? 0;
    final expiresAtMs = (data['expiresAtMs'] as num?)?.toInt() ?? 0;
    final items = _itemsFromRaw(data['items']);
    if (dateKey.isEmpty || items.isEmpty || expiresAtMs <= 0) {
      return null;
    }

    return _CinemaDailyReel(
      dateKey: dateKey,
      title: title.isEmpty ? 'Video kỷ niệm trong ngày' : title,
      subtitle: subtitle,
      accentValue: accentValue,
      createdAt: createdAtMs <= 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      items: items,
    );
  }

  static List<_CinemaMemoryRecord> _itemsFromRaw(Object? raw) {
    final items = <_CinemaMemoryRecord>[];
    if (raw is List) {
      for (final entry in raw) {
        final item = _CinemaMemoryRecord.fromRaw(entry);
        if (item != null) {
          items.add(item);
        }
      }
      return items;
    }

    if (raw is Map) {
      final entries = Map<dynamic, dynamic>.from(raw).entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      for (final entry in entries) {
        final item = _CinemaMemoryRecord.fromRaw(entry.value);
        if (item != null) {
          items.add(item);
        }
      }
    }
    return items;
  }

  static String _dateKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
