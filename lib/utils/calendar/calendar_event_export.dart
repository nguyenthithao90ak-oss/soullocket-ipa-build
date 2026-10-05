import 'dart:convert';
import 'dart:typed_data';

import 'calendar_timed_event.dart';

/// Một occurrence theo RFC 5545: DATE cả ngày hoặc thời điểm UTC có giờ.
/// Không xuất RRULE dương cho sự kiện âm lịch/bảng năm.
abstract final class CalendarEventExport {
  static Uint8List create({required String identity, required String title,
    required DateTime occurrence, required DateTime generatedAt, CalendarTimedEvent? timing}) {
    final date = DateTime.utc(occurrence.year, occurrence.month, occurrence.day);
    final end = DateTime.utc(date.year, date.month, date.day + 1);
    final token = base64Url.encode(utf8.encode(identity)).replaceAll('=', '');
    final lines = [
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//SoulLocket//Calendar Export//EN',
      'CALSCALE:GREGORIAN', 'BEGIN:VEVENT', 'UID:$token-${_date(date)}@soullocket',
      'DTSTAMP:${_instant(generatedAt)}',
      if (timing == null) ...['DTSTART;VALUE=DATE:${_date(date)}', 'DTEND;VALUE=DATE:${_date(end)}']
      else ...[
        'DTSTART:${_instant(DateTime.fromMillisecondsSinceEpoch(timing.startUtcMs, isUtc: true))}',
        'DTEND:${_instant(DateTime.fromMillisecondsSinceEpoch(timing.endUtcMs, isUtc: true))}',
      ],
      'SUMMARY:${_escape(title)}', 'CLASS:PRIVATE', 'TRANSP:${timing == null ? 'TRANSPARENT' : 'OPAQUE'}',
      'END:VEVENT', 'END:VCALENDAR',
    ];
    return Uint8List.fromList(utf8.encode('${lines.map(_fold).join('\r\n')}\r\n'));
  }
  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _date(DateTime date) => '${date.year.toString().padLeft(4, '0')}${_two(date.month)}${_two(date.day)}';
  static String _instant(DateTime date) {
    final utc = date.toUtc();
    return '${_date(utc)}T${_two(utc.hour)}${_two(utc.minute)}${_two(utc.second)}Z';
  }
  static String _escape(String text) => text.replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\n', r'\n')
      .replaceAll(',', r'\,').replaceAll(';', r'\;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '');
  static String _fold(String line) {
    final result = StringBuffer();
    var bytes = 0;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final length = utf8.encode(character).length;
      if (bytes + length > 75) { result.write('\r\n '); bytes = 1; }
      result.write(character);
      bytes += length;
    }
    return result.toString();
  }
}
