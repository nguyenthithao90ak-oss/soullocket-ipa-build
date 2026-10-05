import 'l10n_service.dart';

/// Dịch văn bản thông báo lịch hẹn. Mặc định dùng ngôn ngữ đang chọn của
/// người xem, nên Trung tâm thông báo hiển thị đúng ngôn ngữ của từng người
/// dù push được tạo từ máy người kia.
typedef ScheduleTextResolver = String Function(
  String key, [
  Map<String, Object?> params,
]);

String _defaultScheduleText(String key, [Map<String, Object?>? params]) =>
    L10nService().format(key, params ?? const {});

class ScheduleIdentityContext {
  final String houseId;
  final String houseName;
  final String nameU1;
  final String nameU2;
  final String startDate;
  final String dobU1;
  final String dobU2;

  const ScheduleIdentityContext({
    required this.houseId,
    this.houseName = '',
    this.nameU1 = '',
    this.nameU2 = '',
    this.startDate = '',
    this.dobU1 = '',
    this.dobU2 = '',
  });

  String get fallbackSource => fallbackSourceWith(_defaultScheduleText);

  String fallbackSourceWith(ScheduleTextResolver text) {
    final names = <String>[
      nameU1.trim(),
      nameU2.trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);

    if (names.length >= 2) {
      return text('sched_couple_names', {'a': names[0], 'b': names[1]});
    }
    if (names.isNotEmpty) {
      return names.first;
    }
    if (houseName.trim().isNotEmpty) {
      return houseName.trim();
    }
    return houseId.trim();
  }
}

class ScheduleEventPresentation {
  final String sourceLabel;
  final String title;
  final String message;
  final String eventType;

  const ScheduleEventPresentation({
    required this.sourceLabel,
    required this.title,
    required this.message,
    required this.eventType,
  });
}

/// Tiêu đề mặc định theo số ngày còn lại (3, 2, 1, 0).
String scheduleGenericTitle(
  int daysUntil, {
  ScheduleTextResolver text = _defaultScheduleText,
}) =>
    _genericTitle(_stageFromDays(daysUntil), text);

/// Nội dung mặc định theo số ngày còn lại (3, 2, 1, 0).
String scheduleGenericMessage(
  int daysUntil,
  String eventTitle, {
  ScheduleTextResolver text = _defaultScheduleText,
}) {
  final label = eventTitle.trim().isEmpty
      ? text('sched_event_this')
      : eventTitle.trim();
  return _genericMessage(
    _stageFromDays(daysUntil),
    label,
    fallbackMessage: '',
    text: text,
  );
}

ScheduleEventPresentation describeScheduleNotification({
  required String notificationId,
  required String fallbackTitle,
  required String fallbackMessage,
  required String eventTitle,
  required ScheduleIdentityContext identity,
  String? eventDate,
  String? eventKey,
  ScheduleTextResolver text = _defaultScheduleText,
}) {
  final normalizedTitle = eventTitle.trim();
  final resolvedTitle = normalizedTitle.isNotEmpty
      ? normalizedTitle
      : _extractEventLabel(fallbackMessage);
  final stage =
      _inferScheduleStage(notificationId, fallbackTitle, fallbackMessage);
  final key = (eventKey ?? '').trim();
  final coupleLabel = identity.fallbackSourceWith(text);

  // Sự kiện hệ thống có eventKey có cấu trúc: không cần đoán từ câu chữ, nên
  // hoạt động với mọi ngôn ngữ.
  if (key.startsWith('sys:birthday:')) {
    final role = key.split(':').length > 2 ? key.split(':')[2] : '';
    final rawName =
        role == 'user2' ? identity.nameU2.trim() : identity.nameU1.trim();
    final personName =
        rawName.isNotEmpty ? rawName : text('sched_partner_default');
    if (key.contains(':pre7')) {
      return ScheduleEventPresentation(
        sourceLabel: personName,
        title: text('sched_birthday_week_title', {'name': personName}),
        message: text('sched_birthday_week_msg', {
          'name': personName,
          'gift': scheduleGiftSuggestion(scheduleGiftSeed(key), text: text),
        }),
        eventType: 'birthday_reminder',
      );
    }
    return ScheduleEventPresentation(
      sourceLabel: personName,
      title: _birthdayTitle(stage, fallbackTitle, text),
      message: _birthdayMessage(stage, personName, text),
      eventType: 'birthday',
    );
  }
  if (key.startsWith('sys:milestone:')) {
    final days = int.tryParse(key.split(':').length > 2 ? key.split(':')[2] : '');
    if (days != null) {
      return ScheduleEventPresentation(
        sourceLabel: coupleLabel,
        title: _milestoneTitle(stage, days, text),
        message: _milestoneMessage(stage, coupleLabel, days, text),
        eventType: 'love_day_milestone',
      );
    }
  }
  if (key.startsWith('sys:anniversary:')) {
    return ScheduleEventPresentation(
      sourceLabel: coupleLabel,
      title: _anniversaryTitle(stage, fallbackTitle, text),
      message: _anniversaryMessage(stage, coupleLabel, text),
      eventType: 'anniversary',
    );
  }
  final isUserEvent = key.startsWith('cust:') || key.startsWith('cal:');

  // Thông báo cũ chưa có eventKey: đoán theo nội dung (tiếng Việt/Anh).
  final birthdayPerson = isUserEvent
      ? null
      : _detectBirthdayPerson(
          resolvedTitle, fallbackTitle, fallbackMessage, eventDate, identity);
  final milestoneDays =
      isUserEvent ? null : _detectLoveDayMilestone(resolvedTitle, notificationId);
  final isAnniversary = !isUserEvent &&
      birthdayPerson == null &&
      milestoneDays == null &&
      _isAnniversaryEvent(
          resolvedTitle, fallbackTitle, fallbackMessage, eventDate, identity);

  if (birthdayPerson != null) {
    return ScheduleEventPresentation(
      sourceLabel: birthdayPerson,
      title: _birthdayTitle(stage, fallbackTitle, text),
      message: _birthdayMessage(stage, birthdayPerson, text),
      eventType: 'birthday',
    );
  }

  if (milestoneDays != null) {
    return ScheduleEventPresentation(
      sourceLabel: coupleLabel,
      title: _milestoneTitle(stage, milestoneDays, text),
      message: _milestoneMessage(stage, coupleLabel, milestoneDays, text),
      eventType: 'love_day_milestone',
    );
  }

  if (isAnniversary) {
    return ScheduleEventPresentation(
      sourceLabel: coupleLabel,
      title: _anniversaryTitle(stage, fallbackTitle, text),
      message: _anniversaryMessage(stage, coupleLabel, text),
      eventType: 'anniversary',
    );
  }

  final eventLabel =
      resolvedTitle.isNotEmpty ? resolvedTitle : text('sched_event_this');
  return ScheduleEventPresentation(
    sourceLabel: coupleLabel,
    // Tiêu đề lưu sẵn có thể ở ngôn ngữ của máy gửi; dựng lại theo người xem
    // khi biết giai đoạn.
    title: stage != _ScheduleStage.unknown || fallbackTitle.trim().isEmpty
        ? _genericTitle(stage, text)
        : fallbackTitle.trim(),
    message: _genericMessage(
      stage,
      eventLabel,
      fallbackMessage: fallbackMessage,
      text: text,
    ),
    eventType: 'generic',
  );
}

const scheduleGiftSuggestionCount = 20;

/// Gợi ý quà sinh nhật (đã dịch), chọn ổn định theo [seed].
String scheduleGiftSuggestion(
  int seed, {
  ScheduleTextResolver text = _defaultScheduleText,
}) {
  final index = seed.abs() % scheduleGiftSuggestionCount + 1;
  return text('sched_gift_$index');
}

int scheduleGiftSeed(String eventKey) {
  // eventKey dạng sys:birthday:user1:pre7:YYYY-MM-DD → dùng tháng + ngày.
  final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(eventKey);
  if (match == null) return eventKey.length;
  return int.parse(match.group(2)!) + int.parse(match.group(3)!) + 7;
}

String _extractEventLabel(String fallbackMessage) {
  final raw = fallbackMessage.trim();
  if (raw.isEmpty) return '';
  final patterns = <RegExp>[
    RegExp(r'đến\s+(.+?)(?:\s+(?:nè|rùi đó|rồi đó|thôi nha|nha|đó)|[!?.]|$)',
        caseSensitive: false),
    RegExp(r'là\s+(.+?)(?:\s+(?:nè|đó)|[!?.]|$)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(raw);
    if (match != null) {
      return (match.group(1) ?? '').trim();
    }
  }
  return '';
}

String? _detectBirthdayPerson(
  String eventTitle,
  String fallbackTitle,
  String fallbackMessage,
  String? eventDate,
  ScheduleIdentityContext identity,
) {
  final combined = '$eventTitle $fallbackTitle $fallbackMessage';
  final hasBirthdayKeyword =
      _containsAny(combined, const ['sinh nhật', 'sinh nhat', 'birthday']);
  final matchesDobU1 = _sameMonthDay(identity.dobU1, eventDate);
  final matchesDobU2 = _sameMonthDay(identity.dobU2, eventDate);
  final normalizedCombined = _normalizeText(combined);
  final normalizedNameU1 = _normalizeText(identity.nameU1);
  final normalizedNameU2 = _normalizeText(identity.nameU2);

  if (identity.nameU1.trim().isNotEmpty &&
      normalizedNameU1.isNotEmpty &&
      normalizedCombined.contains(normalizedNameU1) &&
      (hasBirthdayKeyword || matchesDobU1)) {
    return identity.nameU1.trim();
  }
  if (identity.nameU2.trim().isNotEmpty &&
      normalizedNameU2.isNotEmpty &&
      normalizedCombined.contains(normalizedNameU2) &&
      (hasBirthdayKeyword || matchesDobU2)) {
    return identity.nameU2.trim();
  }
  if (hasBirthdayKeyword && matchesDobU1 && !matchesDobU2) {
    return identity.nameU1.trim().isNotEmpty ? identity.nameU1.trim() : null;
  }
  if (hasBirthdayKeyword && matchesDobU2 && !matchesDobU1) {
    return identity.nameU2.trim().isNotEmpty ? identity.nameU2.trim() : null;
  }
  return null;
}

bool _isAnniversaryEvent(
  String eventTitle,
  String fallbackTitle,
  String fallbackMessage,
  String? eventDate,
  ScheduleIdentityContext identity,
) {
  final combined = '$eventTitle $fallbackTitle $fallbackMessage';
  final hasAnniversaryKeyword = _containsAny(
    combined,
    const ['kỷ niệm', 'kỉ niệm', 'anniversary', 'ngày yêu', 'ngay yeu'],
  );
  if (hasAnniversaryKeyword) return true;
  return _sameMonthDay(identity.startDate, eventDate);
}

int? _detectLoveDayMilestone(String eventTitle, String notificationId) {
  final combined = _normalizeText('$eventTitle $notificationId');
  for (final days in const [30, 100, 365]) {
    if (combined.contains('milestone:$days') ||
        combined.contains('ky niem $days ngay yeu') ||
        combined.contains('$days ngay yeu') ||
        combined.contains('$days-day') ||
        combined.contains('$days days')) {
      return days;
    }
  }
  return null;
}

String _stageKey(_ScheduleStage stage) {
  switch (stage) {
    case _ScheduleStage.d3:
      return 'd3';
    case _ScheduleStage.d2:
      return 'd2';
    case _ScheduleStage.d1:
      return 'd1';
    case _ScheduleStage.d0:
      return 'd0';
    case _ScheduleStage.unknown:
      return 'any';
  }
}

String _birthdayTitle(
  _ScheduleStage stage,
  String fallbackTitle,
  ScheduleTextResolver text,
) {
  if (stage == _ScheduleStage.unknown && fallbackTitle.trim().isNotEmpty) {
    return fallbackTitle.trim();
  }
  return text('sched_birthday_title_${_stageKey(stage)}');
}

String _birthdayMessage(
  _ScheduleStage stage,
  String personName,
  ScheduleTextResolver text,
) =>
    text('sched_birthday_msg_${_stageKey(stage)}', {'name': personName});

String _anniversaryTitle(
  _ScheduleStage stage,
  String fallbackTitle,
  ScheduleTextResolver text,
) {
  if (stage == _ScheduleStage.unknown && fallbackTitle.trim().isNotEmpty) {
    return fallbackTitle.trim();
  }
  return text('sched_anniv_title_${_stageKey(stage)}');
}

String _anniversaryMessage(
  _ScheduleStage stage,
  String coupleLabel,
  ScheduleTextResolver text,
) =>
    text('sched_anniv_msg_${_stageKey(stage)}', {'couple': coupleLabel});

String _milestoneTitle(
  _ScheduleStage stage,
  int days,
  ScheduleTextResolver text,
) =>
    text('sched_milestone_title_${_stageKey(stage)}', {'days': days});

String _milestoneMessage(
  _ScheduleStage stage,
  String coupleLabel,
  int days,
  ScheduleTextResolver text,
) =>
    text('sched_milestone_msg_${_stageKey(stage)}', {
      'couple': coupleLabel,
      'days': days,
    });

String _genericTitle(_ScheduleStage stage, ScheduleTextResolver text) =>
    text('sched_title_${_stageKey(stage)}');

String _genericMessage(
  _ScheduleStage stage,
  String eventLabel, {
  required String fallbackMessage,
  required ScheduleTextResolver text,
}) {
  if (eventLabel.trim().isEmpty && fallbackMessage.trim().isNotEmpty) {
    return fallbackMessage.trim();
  }
  if (stage == _ScheduleStage.unknown && fallbackMessage.trim().isNotEmpty) {
    return fallbackMessage.trim();
  }
  return text('sched_msg_${_stageKey(stage)}', {'event': eventLabel});
}

bool _containsAny(String value, List<String> patterns) {
  final normalized = _normalizeText(value);
  for (final pattern in patterns) {
    if (normalized.contains(_normalizeText(pattern))) {
      return true;
    }
  }
  return false;
}

bool _sameMonthDay(String leftIso, String? rightIso) {
  final left = _parseIsoParts(leftIso);
  final right = _parseIsoParts(rightIso ?? '');
  if (left == null || right == null) return false;
  return left.month == right.month && left.day == right.day;
}

_DateParts? _parseIsoParts(String raw) {
  final value = raw.trim();
  if (value.length < 10) return null;
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return _DateParts(year: year, month: month, day: day);
}

_ScheduleStage _stageFromDays(int daysUntil) {
  switch (daysUntil) {
    case 3:
      return _ScheduleStage.d3;
    case 2:
      return _ScheduleStage.d2;
    case 1:
      return _ScheduleStage.d1;
    case 0:
      return _ScheduleStage.d0;
    default:
      return _ScheduleStage.unknown;
  }
}

_ScheduleStage _inferScheduleStage(
  String notificationId,
  String fallbackTitle,
  String fallbackMessage,
) {
  if (notificationId.startsWith('sched_d3_')) return _ScheduleStage.d3;
  if (notificationId.startsWith('sched_d2_')) return _ScheduleStage.d2;
  if (notificationId.startsWith('sched_d1_')) return _ScheduleStage.d1;
  if (notificationId.startsWith('sched_d0_')) return _ScheduleStage.d0;

  final combined = '$fallbackTitle $fallbackMessage';
  if (_containsAny(combined, const ['3 ngày', '3 days'])) {
    return _ScheduleStage.d3;
  }
  if (_containsAny(combined, const ['2 ngày', '2 days'])) {
    return _ScheduleStage.d2;
  }
  if (_containsAny(combined, const ['1 ngày', 'ngày mai', 'tomorrow'])) {
    return _ScheduleStage.d1;
  }
  if (_containsAny(combined, const ['hôm nay', 'today'])) {
    return _ScheduleStage.d0;
  }
  return _ScheduleStage.unknown;
}

const _vietnameseFolding = <String, String>{
  'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a', //
  'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a', //
  'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a', //
  'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e', //
  'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e', //
  'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i', //
  'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o', //
  'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o', //
  'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o', //
  'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u', //
  'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u', //
  'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y', //
  'đ': 'd',
};

String _normalizeText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_vietnameseFolding[char] ?? char);
  }
  return buffer.toString();
}

enum _ScheduleStage { d3, d2, d1, d0, unknown }

class _DateParts {
  final int year;
  final int month;
  final int day;

  const _DateParts({
    required this.year,
    required this.month,
    required this.day,
  });
}
