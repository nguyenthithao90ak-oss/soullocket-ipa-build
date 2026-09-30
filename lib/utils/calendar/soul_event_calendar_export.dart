import 'dart:convert';
import 'dart:typed_data';

import '../../models/soul_event.dart';

/// Một lần diễn ra, ngày cả ngày theo RFC 5545; lịch đích không tự suy lịch âm.
abstract final class SoulEventCalendarExport {
  static Uint8List create({
    required SoulEvent event,
    required DateTime occurrence,
    required DateTime generatedAt,
  }) {
    final date = DateTime.utc(
      occurrence.year,
      occurrence.month,
      occurrence.day,
    );
    final end = DateTime.utc(date.year, date.month, date.day + 1);
    final stamp = generatedAt.toUtc();
    final token = base64Url.encode(utf8.encode(event.id)).replaceAll('=', '');
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//SoulLocket//Calendar Export//EN',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      'UID:${event.createdAt}-$token-${_date(date)}@soullocket',
      'DTSTAMP:${_date(stamp)}T${_two(stamp.hour)}${_two(stamp.minute)}${_two(stamp.second)}Z',
      'DTSTART;VALUE=DATE:${_date(date)}',
      'DTEND;VALUE=DATE:${_date(end)}',
      'SUMMARY:${_escape(event.title)}',
      'CLASS:PRIVATE',
      'TRANSP:TRANSPARENT',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return Uint8List.fromList(
      utf8.encode('${lines.map(_fold).join('\r\n')}\r\n'),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}${_two(date.month)}${_two(date.day)}';

  static String _escape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '');

  /// Gấp dòng theo byte UTF-8, luôn giữ nguyên một ký tự Unicode.
  static String _fold(String line) {
    final result = StringBuffer();
    var bytes = 0;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final length = utf8.encode(character).length;
      if (bytes + length > 75) {
        result.write('\r\n ');
        bytes = 1;
      }
      result.write(character);
      bytes += length;
    }
    return result.toString();
  }
}
