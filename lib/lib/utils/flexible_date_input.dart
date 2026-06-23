import 'dart:math' as math;

import 'package:flutter/services.dart';

class FlexibleDateInputFormatter extends TextInputFormatter {
  const FlexibleDateInputFormatter({this.maxDigits = 8});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatRaw(newValue.text);
    final selectionEnd = newValue.selection.end.clamp(0, newValue.text.length);
    final formattedPrefix =
        _formatRaw(newValue.text.substring(0, selectionEnd));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: math.min(formattedPrefix.length, formatted.length),
      ),
      composing: TextRange.empty,
    );
  }

  String _formatRaw(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw
        .replaceAll(RegExp(r'[\s\.\-]+'), '/')
        .replaceAll(RegExp(r'[^0-9/]'), '');

    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      final clipped = <String>[];
      for (var i = 0; i < math.min(parts.length, 3); i++) {
        final digits = parts[i].replaceAll(RegExp(r'\D'), '');
        final limit = i == 2 ? 4 : 2;
        var segment = digits.substring(0, math.min(digits.length, limit));
        final shouldPad = i < 2 &&
            segment.length == 1 &&
            (i < parts.length - 1 || normalized.endsWith('/'));
        if (shouldPad) {
          segment = segment.padLeft(2, '0');
        }
        clipped.add(segment);
      }

      final hasTrailingSlash = normalized.endsWith('/');
      while (clipped.length > 1 && clipped.last.isEmpty && !hasTrailingSlash) {
        clipped.removeLast();
      }

      var text = clipped.join('/');
      if (hasTrailingSlash && clipped.length < 3 && !text.endsWith('/')) {
        text = '$text/';
      }
      return text.substring(0, math.min(text.length, 10));
    }

    final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');
    final digits =
        digitsOnly.substring(0, math.min(digitsOnly.length, maxDigits));
    return _formatDigits(digits);
  }

  String _formatDigits(String digits) {
    if (digits.length <= 1) return digits;
    if (digits.length <= 2) return digits;

    final day = digits.substring(0, 2);
    final rest = digits.substring(2);
    if (rest.length <= 2) return '$day/$rest';

    final month = rest.substring(0, 2);
    final year = rest.substring(2);
    return '$day/$month/$year'.substring(
      0,
      math.min('$day/$month/$year'.length, 10),
    );
  }
}

class DateInputUtils {
  const DateInputUtils._();

  static DateTime? parse(
    String raw, {
    int firstYear = 1900,
    int lastYear = 2100,
    bool allowMissingYear = false,
    int? fallbackYear,
  }) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final isoMatch =
        RegExp(r'^(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})$').firstMatch(value);
    if (isoMatch != null) {
      return _safeDate(
        year: int.parse(isoMatch.group(1)!),
        month: int.parse(isoMatch.group(2)!),
        day: int.parse(isoMatch.group(3)!),
        firstYear: firstYear,
        lastYear: lastYear,
      );
    }

    final localMatch =
        RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?$')
            .firstMatch(value);
    if (localMatch != null) {
      final yearText = localMatch.group(3);
      if (yearText == null && !allowMissingYear) return null;
      final year = yearText == null
          ? (fallbackYear ?? DateTime.now().year)
          : _resolveYear(yearText, firstYear, lastYear);
      return _safeDate(
        year: year,
        month: int.parse(localMatch.group(2)!),
        day: int.parse(localMatch.group(1)!),
        firstYear: firstYear,
        lastYear: lastYear,
      );
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      final asLocal = _safeDate(
        year: int.parse(digits.substring(4, 8)),
        month: int.parse(digits.substring(2, 4)),
        day: int.parse(digits.substring(0, 2)),
        firstYear: firstYear,
        lastYear: lastYear,
      );
      if (asLocal != null) return asLocal;
      return _safeDate(
        year: int.parse(digits.substring(0, 4)),
        month: int.parse(digits.substring(4, 6)),
        day: int.parse(digits.substring(6, 8)),
        firstYear: firstYear,
        lastYear: lastYear,
      );
    }

    if (digits.length == 6) {
      return _safeDate(
        year: _resolveYear(digits.substring(4, 6), firstYear, lastYear),
        month: int.parse(digits.substring(2, 4)),
        day: int.parse(digits.substring(0, 2)),
        firstYear: firstYear,
        lastYear: lastYear,
      );
    }

    if (allowMissingYear && digits.length == 4) {
      return _safeDate(
        year: fallbackYear ?? DateTime.now().year,
        month: int.parse(digits.substring(2, 4)),
        day: int.parse(digits.substring(0, 2)),
        firstYear: firstYear,
        lastYear: lastYear,
      );
    }

    return null;
  }

  static String? validationError(
    String raw, {
    int firstYear = 1900,
    int lastYear = 2100,
    bool allowMissingYear = false,
    int? fallbackYear,
  }) {
    final value = raw.trim();
    final formatText =
        allowMissingYear ? 'ngày/tháng hoặc ngày/tháng/năm' : 'ngày/tháng/năm';
    if (value.isEmpty) {
      return 'Nhập ngày theo định dạng $formatText.';
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    final minDigits = allowMissingYear ? 4 : 6;
    if (digits.length < minDigits) {
      return 'Nhập đủ $formatText.';
    }

    final parts = _readDateParts(
      value,
      allowMissingYear: allowMissingYear,
      fallbackYear: fallbackYear,
      firstYear: firstYear,
      lastYear: lastYear,
    );
    if (parts == null) {
      return 'Định dạng chưa đúng. Hãy nhập theo $formatText.';
    }

    if (parts.day < 1 || parts.day > 31) {
      return 'Ngày phải từ 01 đến 31.';
    }
    if (parts.month < 1 || parts.month > 12) {
      return 'Tháng phải từ 01 đến 12.';
    }
    if (parts.year < firstYear || parts.year > lastYear) {
      return 'Năm phải từ $firstYear đến $lastYear.';
    }

    final maxDay = DateTime(parts.year, parts.month + 1, 0).day;
    if (parts.day > maxDay) {
      final month = parts.month.toString().padLeft(2, '0');
      final yearSuffix = parts.hasYear ? '/${parts.year}' : '';
      return 'Tháng $month$yearSuffix chỉ có $maxDay ngày.';
    }

    return null;
  }

  static _DateParts? _readDateParts(
    String value, {
    required bool allowMissingYear,
    required int? fallbackYear,
    required int firstYear,
    required int lastYear,
  }) {
    final isoMatch =
        RegExp(r'^(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})$').firstMatch(value);
    if (isoMatch != null) {
      return _DateParts(
        day: int.parse(isoMatch.group(3)!),
        month: int.parse(isoMatch.group(2)!),
        year: int.parse(isoMatch.group(1)!),
        hasYear: true,
      );
    }

    final localMatch =
        RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?$')
            .firstMatch(value);
    if (localMatch != null) {
      final yearText = localMatch.group(3);
      if (yearText == null && !allowMissingYear) return null;
      return _DateParts(
        day: int.parse(localMatch.group(1)!),
        month: int.parse(localMatch.group(2)!),
        year: yearText == null
            ? (fallbackYear ?? DateTime.now().year)
            : _resolveYear(yearText, firstYear, lastYear),
        hasYear: yearText != null,
      );
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      return _DateParts(
        day: int.parse(digits.substring(0, 2)),
        month: int.parse(digits.substring(2, 4)),
        year: int.parse(digits.substring(4, 8)),
        hasYear: true,
      );
    }
    if (digits.length == 6) {
      return _DateParts(
        day: int.parse(digits.substring(0, 2)),
        month: int.parse(digits.substring(2, 4)),
        year: _resolveYear(digits.substring(4, 6), firstYear, lastYear),
        hasYear: true,
      );
    }
    if (allowMissingYear && digits.length == 4) {
      return _DateParts(
        day: int.parse(digits.substring(0, 2)),
        month: int.parse(digits.substring(2, 4)),
        year: fallbackYear ?? DateTime.now().year,
        hasYear: false,
      );
    }
    return null;
  }

  static String? normalizeToIsoDate(
    String raw, {
    int firstYear = 1900,
    int lastYear = 2100,
    bool allowMissingYear = false,
    int? fallbackYear,
  }) {
    final parsed = parse(
      raw,
      firstYear: firstYear,
      lastYear: lastYear,
      allowMissingYear: allowMissingYear,
      fallbackYear: fallbackYear,
    );
    return parsed == null ? null : formatIsoDate(parsed);
  }

  static String normalizeForDisplay(
    String raw, {
    int firstYear = 1900,
    int lastYear = 2100,
    bool allowMissingYear = false,
    int? fallbackYear,
  }) {
    final parsed = parse(
      raw,
      firstYear: firstYear,
      lastYear: lastYear,
      allowMissingYear: allowMissingYear,
      fallbackYear: fallbackYear,
    );
    if (parsed != null) {
      return allowMissingYear && !_hasYear(raw)
          ? formatDayMonth(parsed)
          : formatDisplayDate(parsed);
    }
    return normalizePartialDayMonth(raw) ?? raw.trim();
  }

  static String formatIsoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String formatDisplayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().padLeft(4, '0')}';
  }

  static String formatDayMonth(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  static String? normalizePartialDayMonth(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})$').firstMatch(value);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final parsed = _safeDate(
        year: 2024,
        month: month,
        day: day,
        firstYear: 1900,
        lastYear: 2100,
      );
      if (parsed == null) return null;
      return formatDayMonth(parsed);
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 4) {
      final parsed = _safeDate(
        year: 2024,
        month: int.parse(digits.substring(2, 4)),
        day: int.parse(digits.substring(0, 2)),
        firstYear: 1900,
        lastYear: 2100,
      );
      if (parsed == null) return null;
      return formatDayMonth(parsed);
    }
    return null;
  }

  static String canonicalRecoveryAnswer(String raw) {
    final parsed = parse(raw, firstYear: 1900, lastYear: 2100);
    if (parsed != null) return formatIsoDate(parsed).toLowerCase();
    final partial = normalizePartialDayMonth(raw);
    if (partial != null) return partial.toLowerCase();
    return raw.trim().toLowerCase();
  }

  static Set<String> recoveryAnswerCandidates(String raw) {
    final value = raw.trim().toLowerCase();
    final candidates = <String>{if (value.isNotEmpty) value};
    final parsed = parse(raw, firstYear: 1900, lastYear: 2100);
    if (parsed != null) {
      candidates
        ..add(formatIsoDate(parsed).toLowerCase())
        ..add(formatDisplayDate(parsed).toLowerCase());
    }
    final partial = normalizePartialDayMonth(raw);
    if (partial != null) {
      candidates.add(partial.toLowerCase());
    }
    return candidates;
  }

  static bool looksLikeBirthQuestion(String question) {
    return question.trim().toLowerCase().contains('sinh');
  }

  static bool _hasYear(String raw) {
    final parts = raw.trim().split(RegExp(r'[\/\-.]'));
    if (parts.length >= 3 &&
        parts.last.replaceAll(RegExp(r'\D'), '').isNotEmpty) {
      return true;
    }
    return raw.replaceAll(RegExp(r'\D'), '').length >= 6;
  }

  static int _resolveYear(String raw, int firstYear, int lastYear) {
    if (raw.length != 2) return int.parse(raw);
    final yy = int.parse(raw);
    final candidates = [2000 + yy, 1900 + yy, 2100 + yy];
    return candidates.firstWhere(
      (year) => year >= firstYear && year <= lastYear,
      orElse: () => 2000 + yy,
    );
  }

  static DateTime? _safeDate({
    required int year,
    required int month,
    required int day,
    required int firstYear,
    required int lastYear,
  }) {
    if (year < firstYear || year > lastYear) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}

class _DateParts {
  const _DateParts({
    required this.day,
    required this.month,
    required this.year,
    required this.hasYear,
  });

  final int day;
  final int month;
  final int year;
  final bool hasYear;
}
