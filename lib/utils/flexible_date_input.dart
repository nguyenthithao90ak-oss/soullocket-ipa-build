import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'services/l10n_service.dart';

/// Thứ tự gõ và hiển thị ngày dạng số theo thói quen từng vùng:
/// Việt Nam/châu Âu `dd/MM/yyyy`, Mỹ/Philippines `MM/dd/yyyy`,
/// Trung/Nhật/Hàn `yyyy/MM/dd`.
enum DateFieldOrder { dmy, mdy, ymd }

class FlexibleDateInputFormatter extends TextInputFormatter {
  const FlexibleDateInputFormatter({this.maxDigits = 8, this.order});

  final int maxDigits;

  /// `null` = theo [DateInputUtils.order] của ngôn ngữ/vùng hiện tại.
  final DateFieldOrder? order;

  DateFieldOrder get _order => order ?? DateInputUtils.order;

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

  List<int> get _segmentLimits =>
      _order == DateFieldOrder.ymd ? const [4, 2, 2] : const [2, 2, 4];

  String _formatRaw(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw
        .replaceAll(RegExp(r'[\s\.\-]+'), '/')
        .replaceAll(RegExp(r'[^0-9/]'), '');
    final limits = _segmentLimits;

    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      final clipped = <String>[];
      for (var i = 0; i < math.min(parts.length, 3); i++) {
        final digits = parts[i].replaceAll(RegExp(r'\D'), '');
        final limit = limits[i];
        var segment = digits.substring(0, math.min(digits.length, limit));
        final shouldPad = i < 2 &&
            limit == 2 &&
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
    return _formatDigits(digits, limits);
  }

  String _formatDigits(String digits, List<int> limits) {
    final first = limits[0];
    final second = limits[1];
    if (digits.length <= first) return digits;

    final head = digits.substring(0, first);
    final rest = digits.substring(first);
    if (rest.length <= second) return '$head/$rest';

    final middle = rest.substring(0, second);
    final tail = rest.substring(second);
    final text = '$head/$middle/$tail';
    return text.substring(0, math.min(text.length, 10));
  }
}

class DateInputUtils {
  const DateInputUtils._();

  /// Thứ tự ngày người dùng đang dùng. App cập nhật qua [configureLocale]
  /// mỗi khi đổi ngôn ngữ hoặc khu vực.
  static DateFieldOrder order = DateFieldOrder.dmy;

  /// Người dùng tiếng Thái hay gõ năm Phật lịch (2567 = 2024).
  static bool acceptBuddhistEra = false;

  static void configureLocale({
    required String languageCode,
    String? countryCode,
  }) {
    order = orderFor(languageCode: languageCode, countryCode: countryCode);
    acceptBuddhistEra = languageCode.toLowerCase() == 'th';
  }

  /// Theo CLDR (định dạng ngày ngắn): Mỹ và Philippines dùng tháng trước,
  /// Trung/Nhật/Hàn dùng năm trước, còn lại ngày trước.
  static DateFieldOrder orderFor({
    required String languageCode,
    String? countryCode,
  }) {
    final language = languageCode.toLowerCase();
    final region = (countryCode ?? '').toUpperCase();
    const ymdLanguages = {'zh', 'ja', 'ko', 'hu', 'lt', 'mn'};
    if (ymdLanguages.contains(language)) return DateFieldOrder.ymd;
    if (language == 'tl' || language == 'fil') return DateFieldOrder.mdy;
    const mdyRegions = {
      'US', 'PH', 'PR', 'GU', 'AS', 'VI', 'MP', 'UM', 'FM', 'MH', 'PW', //
    };
    if ((language == 'en' || language == 'es') && mdyRegions.contains(region)) {
      return DateFieldOrder.mdy;
    }
    if (language == 'en' && region == 'CA') return DateFieldOrder.ymd;
    // Tiếng Anh không rõ khu vực: theo mặc định `en` của CLDR (M/d/y).
    if (language == 'en' && (region.isEmpty || region == 'ALL')) {
      return DateFieldOrder.mdy;
    }
    return DateFieldOrder.dmy;
  }

  static DateTime? parse(
    String raw, {
    int firstYear = 1900,
    int lastYear = 2100,
    bool allowMissingYear = false,
    int? fallbackYear,
    DateFieldOrder? order,
  }) {
    final parts = _readDateParts(
      raw.trim(),
      order: order ?? DateInputUtils.order,
      allowMissingYear: allowMissingYear,
      fallbackYear: fallbackYear,
      firstYear: firstYear,
      lastYear: lastYear,
    );
    if (parts == null) return null;
    return _safeDate(
      year: parts.year,
      month: parts.month,
      day: parts.day,
      firstYear: firstYear,
      lastYear: lastYear,
    );
  }

  static String? validationError(
    String raw, {
    int firstYear = 1900,
    int lastYear = 2100,
    bool allowMissingYear = false,
    int? fallbackYear,
    DateFieldOrder? order,
  }) {
    final effectiveOrder = order ?? DateInputUtils.order;
    final value = raw.trim();
    final formatText = _formatHint(
      allowMissingYear: allowMissingYear,
      order: effectiveOrder,
    );
    if (value.isEmpty) {
      return _t('date_input_err_empty', {'format': formatText});
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    final minDigits = allowMissingYear ? 4 : 6;
    if (digits.length < minDigits) {
      return _t('date_input_err_incomplete', {'format': formatText});
    }

    final parts = _readDateParts(
      value,
      order: effectiveOrder,
      allowMissingYear: allowMissingYear,
      fallbackYear: fallbackYear,
      firstYear: firstYear,
      lastYear: lastYear,
    );
    if (parts == null) {
      return _t('date_input_err_format', {'format': formatText});
    }

    if (parts.day < 1 || parts.day > 31) {
      return _t('date_input_err_day');
    }
    if (parts.month < 1 || parts.month > 12) {
      return _t('date_input_err_month');
    }
    if (parts.year < firstYear || parts.year > lastYear) {
      return _t('date_input_err_year', {'first': firstYear, 'last': lastYear});
    }

    final maxDay = DateTime(parts.year, parts.month + 1, 0).day;
    if (parts.day > maxDay) {
      final month = parts.month.toString().padLeft(2, '0');
      final label = !parts.hasYear
          ? month
          : effectiveOrder == DateFieldOrder.ymd
              ? '${parts.year}/$month'
              : '$month/${parts.year}';
      return _t('date_input_err_max_day', {'month': label, 'days': maxDay});
    }

    return null;
  }

  /// Gợi ý định dạng đã dịch, ví dụ "MM/DD/YYYY" hoặc "ngày/tháng/năm".
  static String formatHint({
    bool allowMissingYear = false,
    DateFieldOrder? order,
  }) =>
      _formatHint(
        allowMissingYear: allowMissingYear,
        order: order ?? DateInputUtils.order,
      );

  static String _formatHint({
    required bool allowMissingYear,
    required DateFieldOrder order,
  }) {
    final full = _t('date_input_pattern_${order.name}');
    if (!allowMissingYear) return full;
    final partial = _t(
      order == DateFieldOrder.dmy
          ? 'date_input_pattern_dm'
          : 'date_input_pattern_md',
    );
    return _t('date_input_or', {'a': partial, 'b': full});
  }

  static String _t(String key, [Map<String, Object?> params = const {}]) =>
      L10nService().format(key, params);

  static _DateParts? _readDateParts(
    String value, {
    required DateFieldOrder order,
    required bool allowMissingYear,
    required int? fallbackYear,
    required int firstYear,
    required int lastYear,
  }) {
    if (value.isEmpty) return null;
    final isoMatch =
        RegExp(r'^(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})$').firstMatch(value);
    if (isoMatch != null) {
      return _DateParts(
        day: int.parse(isoMatch.group(3)!),
        month: int.parse(isoMatch.group(2)!),
        year: _fromEra(int.parse(isoMatch.group(1)!)),
        hasYear: true,
      );
    }

    final defaultYear = fallbackYear ?? DateTime.now().year;
    final localMatch =
        RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?$')
            .firstMatch(value);
    if (localMatch != null) {
      final yearText = localMatch.group(3);
      if (yearText == null && !allowMissingYear) return null;
      final year = yearText == null
          ? defaultYear
          : _resolveYear(yearText, firstYear, lastYear);
      return _pickDayMonth(
        int.parse(localMatch.group(1)!),
        int.parse(localMatch.group(2)!),
        year: year,
        hasYear: yearText != null,
        dayFirst: order == DateFieldOrder.dmy,
      );
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      _DateParts yearFirst() => _DateParts(
            year: _fromEra(int.parse(digits.substring(0, 4))),
            month: int.parse(digits.substring(4, 6)),
            day: int.parse(digits.substring(6, 8)),
            hasYear: true,
          );
      _DateParts yearLast() => _pickDayMonth(
            int.parse(digits.substring(0, 2)),
            int.parse(digits.substring(2, 4)),
            year: _fromEra(int.parse(digits.substring(4, 8))),
            hasYear: true,
            dayFirst: order == DateFieldOrder.dmy,
          );
      final candidates = order == DateFieldOrder.ymd
          ? [yearFirst(), yearLast()]
          : [yearLast(), yearFirst()];
      return candidates.firstWhere(
        (parts) => parts.isValid(firstYear, lastYear),
        orElse: () => candidates.first,
      );
    }

    if (digits.length == 6) {
      if (order == DateFieldOrder.ymd) {
        return _DateParts(
          year: _resolveYear(digits.substring(0, 2), firstYear, lastYear),
          month: int.parse(digits.substring(2, 4)),
          day: int.parse(digits.substring(4, 6)),
          hasYear: true,
        );
      }
      return _pickDayMonth(
        int.parse(digits.substring(0, 2)),
        int.parse(digits.substring(2, 4)),
        year: _resolveYear(digits.substring(4, 6), firstYear, lastYear),
        hasYear: true,
        dayFirst: order == DateFieldOrder.dmy,
      );
    }

    if (allowMissingYear && digits.length == 4) {
      return _pickDayMonth(
        int.parse(digits.substring(0, 2)),
        int.parse(digits.substring(2, 4)),
        year: defaultYear,
        hasYear: false,
        dayFirst: order == DateFieldOrder.dmy,
      );
    }

    return null;
  }

  /// Chọn cách hiểu theo thứ tự ưu tiên; chỉ đảo ngày/tháng khi cách hiểu
  /// ưu tiên chắc chắn sai (vd. "14/03" với người dùng Mỹ).
  static _DateParts _pickDayMonth(
    int first,
    int second, {
    required int year,
    required bool hasYear,
    required bool dayFirst,
  }) {
    final preferred = dayFirst
        ? _DateParts(day: first, month: second, year: year, hasYear: hasYear)
        : _DateParts(day: second, month: first, year: year, hasYear: hasYear);
    if (preferred.month <= 12) return preferred;
    final swapped = dayFirst
        ? _DateParts(day: second, month: first, year: year, hasYear: hasYear)
        : _DateParts(day: first, month: second, year: year, hasYear: hasYear);
    return swapped.month <= 12 && swapped.day <= 31 ? swapped : preferred;
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

  /// Ngày hiển thị/nhập theo thứ tự của người dùng. Không dùng để lưu.
  static String formatDisplayDate(DateTime date, {DateFieldOrder? order}) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    switch (order ?? DateInputUtils.order) {
      case DateFieldOrder.dmy:
        return '$day/$month/$year';
      case DateFieldOrder.mdy:
        return '$month/$day/$year';
      case DateFieldOrder.ymd:
        return '$year/$month/$day';
    }
  }

  static String formatDayMonth(DateTime date, {DateFieldOrder? order}) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return (order ?? DateInputUtils.order) == DateFieldOrder.dmy
        ? '$day/$month'
        : '$month/$day';
  }

  static String? normalizePartialDayMonth(String raw) {
    final parsed = _parsePartialDayMonth(raw, DateInputUtils.order);
    return parsed == null ? null : formatDayMonth(parsed);
  }

  static DateTime? _parsePartialDayMonth(String raw, DateFieldOrder order) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})$').firstMatch(value);
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final List<int>? pair = match != null
        ? [int.parse(match.group(1)!), int.parse(match.group(2)!)]
        : digits.length == 4
            ? [int.parse(digits.substring(0, 2)), int.parse(digits.substring(2, 4))]
            : null;
    if (pair == null) return null;
    final parts = _pickDayMonth(
      pair[0],
      pair[1],
      year: 2024,
      hasYear: false,
      dayFirst: order == DateFieldOrder.dmy,
    );
    return _safeDate(
      year: 2024,
      month: parts.month,
      day: parts.day,
      firstYear: 1900,
      lastYear: 2100,
    );
  }

  /// Dạng chuẩn để băm câu trả lời bảo mật: ISO cho ngày đủ năm, "dd/MM"
  /// cho ngày/tháng. Không phụ thuộc ngôn ngữ để đổi ngôn ngữ vẫn khôi phục
  /// được tài khoản.
  static String canonicalRecoveryAnswer(String raw) {
    final parsed = parse(raw, firstYear: 1900, lastYear: 2100);
    if (parsed != null) return formatIsoDate(parsed).toLowerCase();
    final partial = _parsePartialDayMonth(raw, DateInputUtils.order);
    if (partial != null) {
      return formatDayMonth(partial, order: DateFieldOrder.dmy).toLowerCase();
    }
    return raw.trim().toLowerCase();
  }

  /// Mọi cách hiểu hợp lệ của câu trả lời (cả thứ tự ngày cũ dd/MM/yyyy),
  /// để người dùng đã đổi ngôn ngữ/khu vực vẫn khôi phục được.
  static Set<String> recoveryAnswerCandidates(String raw) {
    final value = raw.trim().toLowerCase();
    final candidates = <String>{if (value.isNotEmpty) value};
    for (final fieldOrder in DateFieldOrder.values) {
      final parsed = parse(
        raw,
        firstYear: 1900,
        lastYear: 2100,
        order: fieldOrder,
      );
      if (parsed != null) {
        candidates
          ..add(formatIsoDate(parsed).toLowerCase())
          ..add(
            formatDisplayDate(parsed, order: DateFieldOrder.dmy).toLowerCase(),
          );
      }
      final partial = _parsePartialDayMonth(raw, fieldOrder);
      if (partial != null) {
        candidates.add(
          formatDayMonth(partial, order: DateFieldOrder.dmy).toLowerCase(),
        );
      }
    }
    return candidates;
  }

  /// Câu hỏi bảo mật được lưu bằng ngôn ngữ lúc tạo; nhận diện câu hỏi ngày
  /// sinh ở mọi ngôn ngữ app hỗ trợ.
  static bool looksLikeBirthQuestion(String question) {
    final normalized = question.trim().toLowerCase();
    const keywords = [
      'sinh', 'birth', 'geburt', 'naissance', 'nacimiento', 'nascimento', //
      'nascita', 'рожден', 'lahir', 'doğum', 'ميلاد', 'जन्म', 'เกิด', //
      '生年月日', '出生', '生日', '생년월일', '생일', 'kapanganakan', //
      'geboorte', 'urodzenia', //
    ];
    return keywords.any(normalized.contains);
  }

  static bool _hasYear(String raw) {
    final parts = raw.trim().split(RegExp(r'[\/\-.]'));
    if (parts.length >= 3 &&
        parts.last.replaceAll(RegExp(r'\D'), '').isNotEmpty) {
      return true;
    }
    return raw.replaceAll(RegExp(r'\D'), '').length >= 6;
  }

  static int _fromEra(int year) =>
      acceptBuddhistEra && year >= 2400 ? year - 543 : year;

  static int _resolveYear(String raw, int firstYear, int lastYear) {
    if (raw.length != 2) return _fromEra(int.parse(raw));
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

  bool isValid(int firstYear, int lastYear) =>
      DateInputUtils._safeDate(
        year: year,
        month: month,
        day: day,
        firstYear: firstYear,
        lastYear: lastYear,
      ) !=
      null;
}
