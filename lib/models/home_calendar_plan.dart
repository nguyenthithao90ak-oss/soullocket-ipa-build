import '../utils/calendar/calendar_civil_date.dart';
import '../utils/calendar/calendar_timed_event.dart';

enum HomeCalendarLoadState { loading, ready, failed }

/// Bản xem trước chỉ giữ danh tính, tiêu đề, ngày và giờ của kế hoạch.
class HomeCalendarPlan {
  const HomeCalendarPlan({
    required this.id,
    required this.dateKey,
    required this.title,
    this.timing,
  });

  final String id;
  final String dateKey;
  final String title;
  final CalendarTimedEvent? timing;

  String get identity => '$dateKey/$id';

  static List<HomeCalendarPlan> upcoming(
    Iterable<Map<String, dynamic>> metadata, {
    required DateTime now,
  }) {
    final plans = <HomeCalendarPlan>[];
    final identities = <String>{};
    for (final row in metadata) {
      final id = row['id']?.toString().trim() ?? '';
      final key = row['dateKey']?.toString() ?? '';
      final date = CalendarCivilDate.parse(key);
      final title = row['title']?.toString().trim() ?? '';
      if (id.isEmpty || date == null || title.isEmpty) continue;
      final days = CalendarCivilDate.daysBetween(now, date);
      if (days < 0 || days > 30) continue;
      final timing = CalendarTimedEvent.fromJson(row['timing'], dateKey: key);
      // Không biến thời gian sai schema thành một kế hoạch cả ngày.
      if (row['timing'] != null && timing == null) continue;
      if (timing != null && timing.endUtcMs <= now.millisecondsSinceEpoch) {
        continue;
      }
      final plan = HomeCalendarPlan(
        id: id,
        dateKey: key,
        title: title,
        timing: timing,
      );
      if (identities.add(plan.identity)) plans.add(plan);
    }
    plans.sort((a, b) {
      final dateOrder = a.dateKey.compareTo(b.dateKey);
      if (dateOrder != 0) return dateOrder;
      final timeOrder = (a.timing?.startUtcMs ?? 0).compareTo(
        b.timing?.startUtcMs ?? 0,
      );
      return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
    });
    return List.unmodifiable(plans.take(3));
  }
}
