import 'package:soullocket_app/utils/services/l10n_service.dart';

class DateHighlightHelper {
  static Map<String, Map<String, String>> get _holidayMap => {
    '01-01': {'icon': '🎉', 'text': L10nService().translate('holiday_new_year')},
    '02-14': {'icon': '💖', 'text': L10nService().translate('holiday_valentine')},
    '03-08': {'icon': '💐', 'text': L10nService().translate('holiday_womens_day')},
    '04-30': {'icon': '🇻🇳', 'text': L10nService().translate('holiday_liberation_day')},
    '05-01': {'icon': '🛠️', 'text': L10nService().translate('holiday_labor_day')},
    '06-01': {'icon': '🧸', 'text': L10nService().translate('holiday_children_day')},
    '09-02': {'icon': '🇻🇳', 'text': L10nService().translate('holiday_national_day')},
    '10-20': {'icon': '🌹', 'text': L10nService().translate('holiday_vn_womens_day')},
    '11-20': {'icon': '👩‍🏫', 'text': L10nService().translate('holiday_teachers_day')},
    '12-24': {'icon': '🎄', 'text': L10nService().translate('holiday_christmas')},
    '12-25': {'icon': '🎅', 'text': L10nService().translate('holiday_christmas')},
    '12-31': {'icon': '🎆', 'text': L10nService().translate('holiday_new_year_eve')},
  };

  static List<Map<String, String>> getDateHighlights(
    int timestamp, {
    DateTime? anniversaryDate,
    bool includeSpecialDays = true,
  }) {
    if (!includeSpecialDays) return const <Map<String, String>>[];

    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final mmdd =
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final tags = <Map<String, String>>[];

    if (_holidayMap.containsKey(mmdd)) {
      tags.add(_holidayMap[mmdd]!);
    }

    if (anniversaryDate != null &&
        d.month == anniversaryDate.month &&
        d.day == anniversaryDate.day) {
      if (d.year == anniversaryDate.year) {
        tags.add({'icon': '💕', 'text': L10nService().translate('holiday_anniversary_start')});
      } else if (d.year > anniversaryDate.year) {
        final years = d.year - anniversaryDate.year;
        tags.add({'icon': '💕', 'text': L10nService().translate('holiday_anniversary_years').replaceAll('{years}', years.toString())});
      }
    }

    return tags.take(3).toList();
  }
}
