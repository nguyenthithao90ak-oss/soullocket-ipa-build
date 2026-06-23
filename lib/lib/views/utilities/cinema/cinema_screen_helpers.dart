part of '../cinema_screen.dart';

extension _CinemaScreenStateHelpersPart on _CinemaScreenState {
  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(Map<dynamic, dynamic>.from(raw));
    }
    return <String, dynamic>{};
  }

  String _readTrimmedString(Object? raw) {
    return raw?.toString().trim() ?? '';
  }

  DateTime _parseMemoryTimestamp(Map<String, dynamic> item) {
    final raw = item['ts'] ?? item['timestamp'] ?? item['date'];
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      final asDate = DateTime.tryParse(raw);
      if (asDate != null) {
        return asDate;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _parseDate(Object? raw) {
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) {
        return null;
      }
      final asInt = int.tryParse(value);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      return DateTime.tryParse(value);
    }
    return null;
  }

  String? _resolveMemoryImage(Map<String, dynamic> item) {
    const directKeys = <String>['url', 'thumbUrl', 'imageUrl', 'photoUrl'];
    for (final key in directKeys) {
      final value = _readTrimmedString(item[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }

    final images = item['images'];
    if (images is List) {
      for (final entry in images) {
        if (entry is String && entry.trim().isNotEmpty) {
          return entry.trim();
        }
        if (entry is Map) {
          final nested =
              Map<String, dynamic>.from(Map<dynamic, dynamic>.from(entry));
          final nestedUrl = _readTrimmedString(
            nested['url'] ?? nested['imageUrl'] ?? nested['thumbUrl'],
          );
          if (nestedUrl.isNotEmpty) {
            return nestedUrl;
          }
        }
      }
    }

    return null;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatClock(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatLongDate(DateTime date) {
    final months = <String>[
      L10nService().translate('util_thng1_db2569'),
      L10nService().translate('util_thng2_afb937'),
      L10nService().translate('util_thng3_b426e8'),
      L10nService().translate('util_thng4_a41472'),
      L10nService().translate('util_thng5_421305'),
      L10nService().translate('util_thng6_09ac20'),
      L10nService().translate('util_thng7_736c97'),
      L10nService().translate('util_thng8_7c30f4'),
      L10nService().translate('util_thng9_b91fa1'),
      L10nService().translate('util_thng10_592fc9'),
      L10nService().translate('util_thng11_1bfbf7'),
      L10nService().translate('util_thng12_8dffb8'),
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _formatDurationLabel(int frameCount) {
    final totalSeconds = frameCount * _kCinemaFrameDuration.inSeconds;
    if (totalSeconds < 60) {
      return '$totalSeconds giây';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
