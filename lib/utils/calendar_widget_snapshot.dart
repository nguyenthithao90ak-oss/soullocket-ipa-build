typedef CalendarWidgetPageLoader =
    Future<Map<String, dynamic>> Function(String? afterKey, int limit);

class CalendarWidgetSnapshot {
  const CalendarWidgetSnapshot({required this.date, required this.titles});

  static const int pageSize = 8;

  final DateTime date;
  final List<String> titles;

  static CalendarWidgetSnapshot? fromCalendar(Object? raw, DateTime now) {
    if (raw is! Map) return null;
    final today = DateTime(now.year, now.month, now.day);
    CalendarWidgetSnapshot? nearest;
    for (final dayEntry in raw.entries) {
      final dateKey = dayEntry.key.toString();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateKey)) continue;
      final parsed = DateTime.tryParse(dateKey);
      if (parsed == null ||
          dateKeyFor(parsed) != dateKey ||
          parsed.isBefore(today) ||
          dayEntry.value is! Map) {
        continue;
      }
      final events = (dayEntry.value as Map).entries
          .where((entry) => entry.value is Map)
          .toList();
      events.sort((first, second) {
        final firstTimestamp = (first.value as Map)['ts'];
        final secondTimestamp = (second.value as Map)['ts'];
        final order = (firstTimestamp is num ? firstTimestamp : 0).compareTo(
          secondTimestamp is num ? secondTimestamp : 0,
        );
        return order != 0
            ? order
            : first.key.toString().compareTo(second.key.toString());
      });
      final titles = events
          .map(
            (entry) => (entry.value as Map)['title']?.toString().trim() ?? '',
          )
          .where((title) => title.isNotEmpty)
          .toList(growable: false);
      if (titles.isNotEmpty &&
          (nearest == null || parsed.isBefore(nearest.date))) {
        nearest = CalendarWidgetSnapshot(
          date: parsed,
          titles: List.unmodifiable(titles),
        );
      }
    }
    return nearest;
  }

  static Future<CalendarWidgetSnapshot?> resolve({
    required DateTime now,
    Object? calendarData,
    required CalendarWidgetPageLoader loadPage,
  }) async {
    final supplied = fromCalendar(calendarData, now);
    if (supplied != null) return supplied;
    String? afterKey;
    while (true) {
      final page = await loadPage(afterKey, pageSize);
      final keys = page.keys.toList()..sort();
      if (keys.isEmpty) return null;
      if (afterKey != null && keys.first.compareTo(afterKey) <= 0) {
        throw StateError('Calendar widget page did not advance');
      }
      final nearest = fromCalendar(page, now);
      if (nearest != null) return nearest;
      if (keys.length < pageSize) return null;
      afterKey = keys.last;
    }
  }

  static String dateKeyFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
