import '../services/holiday_service.dart';
import '../services/l10n_service.dart';

class DateHighlightHelper {
  static const _holidayMap =
      <String, ({String icon, String key, bool vietnamOnly})>{
        '01-01': (icon: '🎉', key: 'holiday_new_year', vietnamOnly: false),
        '02-14': (icon: '💖', key: 'holiday_valentine', vietnamOnly: false),
        '03-08': (icon: '💐', key: 'holiday_womens_day', vietnamOnly: false),
        '04-30': (
          icon: '🇻🇳',
          key: 'holiday_liberation_day',
          vietnamOnly: true,
        ),
        '05-01': (icon: '🛠️', key: 'holiday_labor_day', vietnamOnly: false),
        '06-01': (icon: '🧸', key: 'holiday_children_day', vietnamOnly: false),
        '09-02': (icon: '🇻🇳', key: 'holiday_national_day', vietnamOnly: true),
        '10-20': (icon: '🌹', key: 'holiday_vn_womens_day', vietnamOnly: true),
        '11-20': (
          icon: '👩‍🏫',
          key: 'holiday_teachers_day',
          vietnamOnly: true,
        ),
        '12-24': (icon: '🎄', key: 'holiday_christmas_eve', vietnamOnly: false),
        '12-25': (icon: '🎅', key: 'holiday_christmas', vietnamOnly: false),
        '12-31': (icon: '🎆', key: 'holiday_new_year_eve', vietnamOnly: false),
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

    final holiday = _holidayMap[mmdd];
    if (holiday != null &&
        (!holiday.vietnamOnly || HolidayService.isVietnamUser())) {
      tags.add({
        'icon': holiday.icon,
        'text': L10nService().translate(holiday.key),
      });
    }

    if (anniversaryDate != null &&
        d.month == anniversaryDate.month &&
        d.day == anniversaryDate.day) {
      if (d.year == anniversaryDate.year) {
        tags.add({
          'icon': '💕',
          'text': L10nService().translate('holiday_anniversary_start'),
        });
      } else if (d.year > anniversaryDate.year) {
        final years = d.year - anniversaryDate.year;
        tags.add({
          'icon': '💕',
          'text': L10nService().format('holiday_anniversary_years', {
            'years': years,
          }),
        });
      }
    }

    return tags.take(3).toList();
  }
}
