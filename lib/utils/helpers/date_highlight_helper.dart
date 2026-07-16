class DateHighlightHelper {
  static const Map<String, Map<String, String>> _holidayMap = {
    '01-01': {'icon': '🎉', 'text': 'Năm mới'},
    '02-14': {'icon': '💖', 'text': 'Valentine'},
    '03-08': {'icon': '💐', 'text': 'Quốc tế Phụ nữ'},
    '04-30': {'icon': '🇻🇳', 'text': 'Giải phóng miền Nam'},
    '05-01': {'icon': '🛠️', 'text': 'Quốc tế Lao động'},
    '06-01': {'icon': '🧸', 'text': 'Quốc tế Thiếu nhi'},
    '09-02': {'icon': '🇻🇳', 'text': 'Quốc khánh'},
    '10-20': {'icon': '🌹', 'text': 'Phụ nữ Việt Nam'},
    '11-20': {'icon': '👩‍🏫', 'text': 'Nhà giáo Việt Nam'},
    '12-24': {'icon': '🎄', 'text': 'Giáng sinh'},
    '12-25': {'icon': '🎅', 'text': 'Giáng sinh'},
    '12-31': {'icon': '🎆', 'text': 'Giao thừa'},
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
        tags.add({'icon': '💕', 'text': 'Ngày bắt đầu yêu'});
      } else if (d.year > anniversaryDate.year) {
        final years = d.year - anniversaryDate.year;
        tags.add({'icon': '💕', 'text': 'Kỷ niệm $years năm yêu nhau'});
      }
    }

    return tags.take(3).toList();
  }
}

