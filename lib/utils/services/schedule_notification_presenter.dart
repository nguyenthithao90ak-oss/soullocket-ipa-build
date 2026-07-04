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

  String get fallbackSource {
    final names = <String>[
      nameU1.trim(),
      nameU2.trim(),
    ].where((item) => item.isNotEmpty).toList(growable: false);

    if (names.length >= 2) {
      return '${names[0]} và ${names[1]}';
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

ScheduleEventPresentation describeScheduleNotification({
  required String notificationId,
  required String fallbackTitle,
  required String fallbackMessage,
  required String eventTitle,
  required ScheduleIdentityContext identity,
  String? eventDate,
}) {
  final normalizedTitle = eventTitle.trim();
  final resolvedTitle = normalizedTitle.isNotEmpty
      ? normalizedTitle
      : _extractEventLabel(fallbackMessage);
  final stage =
      _inferScheduleStage(notificationId, fallbackTitle, fallbackMessage);
  final birthdayPerson = _detectBirthdayPerson(
      resolvedTitle, fallbackTitle, fallbackMessage, eventDate, identity);
  final milestoneDays = _detectLoveDayMilestone(resolvedTitle, notificationId);
  final isAnniversary = birthdayPerson == null &&
      milestoneDays == null &&
      _isAnniversaryEvent(
          resolvedTitle, fallbackTitle, fallbackMessage, eventDate, identity);

  if (birthdayPerson != null) {
    return ScheduleEventPresentation(
      sourceLabel: birthdayPerson,
      title: _birthdayTitle(stage, fallbackTitle),
      message: _birthdayMessage(stage, birthdayPerson),
      eventType: 'birthday',
    );
  }

  if (milestoneDays != null) {
    final coupleLabel = identity.fallbackSource;
    return ScheduleEventPresentation(
      sourceLabel: coupleLabel,
      title: _milestoneTitle(stage, milestoneDays),
      message: _milestoneMessage(stage, coupleLabel, milestoneDays),
      eventType: 'love_day_milestone',
    );
  }

  if (isAnniversary) {
    final coupleLabel = identity.fallbackSource;
    return ScheduleEventPresentation(
      sourceLabel: coupleLabel,
      title: _anniversaryTitle(stage, fallbackTitle),
      message: _anniversaryMessage(stage, coupleLabel),
      eventType: 'anniversary',
    );
  }

  final eventLabel = resolvedTitle.isNotEmpty ? resolvedTitle : 'sự kiện này';
  return ScheduleEventPresentation(
    sourceLabel: identity.fallbackSource,
    title: fallbackTitle.trim().isNotEmpty
        ? fallbackTitle.trim()
        : _genericTitle(stage),
    message: _genericMessage(
      stage,
      eventLabel,
      fallbackMessage: fallbackMessage,
    ),
    eventType: 'generic',
  );
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
        combined.contains('$days ngay yeu')) {
      return days;
    }
  }
  return null;
}

String _birthdayTitle(_ScheduleStage stage, String fallbackTitle) {
  switch (stage) {
    case _ScheduleStage.d3:
      return '🎂 Sắp tới sinh nhật rồi!';
    case _ScheduleStage.d2:
      return '🎂 Còn 2 ngày nữa thôi!';
    case _ScheduleStage.d1:
      return '🎂 Ngày mai là sinh nhật rồi!';
    case _ScheduleStage.d0:
      return '🎂 Hôm nay là sinh nhật!';
    case _ScheduleStage.unknown:
      return fallbackTitle.trim().isNotEmpty
          ? fallbackTitle.trim()
          : '🎂 Nhắc sinh nhật';
  }
}

String _birthdayMessage(_ScheduleStage stage, String personName) {
  switch (stage) {
    case _ScheduleStage.d3:
      return 'Chỉ còn 3 ngày nữa là đến sinh nhật của $personName rồi đó! Chuẩn bị một bất ngờ thật vui nha! 🎁';
    case _ScheduleStage.d2:
      return 'Chỉ còn 2 ngày nữa là đến sinh nhật của $personName thôi nha! 💖';
    case _ScheduleStage.d1:
      return 'Hồi hộp quá! Chỉ còn 1 ngày nữa là đến sinh nhật của $personName rồi đó! 🥰';
    case _ScheduleStage.d0:
      return 'Tèn ten! Hôm nay là sinh nhật của $personName nè! Chúc một ngày thật vui vẻ nhé! 🥳';
    case _ScheduleStage.unknown:
      return 'Hôm nay là dịp đặc biệt của $personName đó!';
  }
}

String _anniversaryTitle(_ScheduleStage stage, String fallbackTitle) {
  switch (stage) {
    case _ScheduleStage.d3:
      return '💞 Sắp tới ngày kỷ niệm rồi!';
    case _ScheduleStage.d2:
      return '💞 Còn 2 ngày nữa thôi!';
    case _ScheduleStage.d1:
      return '💞 Ngày mai là kỷ niệm rồi!';
    case _ScheduleStage.d0:
      return '💞 Hôm nay là ngày kỷ niệm!';
    case _ScheduleStage.unknown:
      return fallbackTitle.trim().isNotEmpty
          ? fallbackTitle.trim()
          : '💞 Nhắc ngày kỷ niệm';
  }
}

String _anniversaryMessage(_ScheduleStage stage, String coupleLabel) {
  switch (stage) {
    case _ScheduleStage.d3:
      return 'Chỉ còn 3 ngày nữa là đến kỷ niệm của $coupleLabel rồi đó! Chuẩn bị một điều thật ngọt ngào nha! 🎁';
    case _ScheduleStage.d2:
      return 'Chỉ còn 2 ngày nữa là đến kỷ niệm của $coupleLabel thôi nha! 💖';
    case _ScheduleStage.d1:
      return 'Hồi hộp quá! Chỉ còn 1 ngày nữa là đến kỷ niệm của $coupleLabel rồi đó! 🥰';
    case _ScheduleStage.d0:
      return 'Tèn ten! Hôm nay là kỷ niệm của $coupleLabel nè! Chúc hai bạn một ngày thật vui nhé! 🥳';
    case _ScheduleStage.unknown:
      return 'Hôm nay là một dịp rất đặc biệt của $coupleLabel đó!';
  }
}

String _milestoneTitle(_ScheduleStage stage, int days) {
  switch (stage) {
    case _ScheduleStage.d3:
      return '💝 Sắp tròn $days ngày yêu rồi!';
    case _ScheduleStage.d2:
      return '💝 Còn 2 ngày nữa là mốc $days ngày!';
    case _ScheduleStage.d1:
      return '💝 Ngày mai tròn $days ngày yêu!';
    case _ScheduleStage.d0:
      return '💝 Hôm nay tròn $days ngày yêu!';
    case _ScheduleStage.unknown:
      return '💝 Nhắc mốc $days ngày yêu';
  }
}

String _milestoneMessage(_ScheduleStage stage, String coupleLabel, int days) {
  switch (stage) {
    case _ScheduleStage.d3:
      return 'Chỉ còn 3 ngày nữa là $coupleLabel chạm mốc $days ngày yêu. Chuẩn bị một điều ngọt ngào nha! 🎁';
    case _ScheduleStage.d2:
      return 'Còn 2 ngày nữa là tròn $days ngày yêu rồi đó. Một bất ngờ nhỏ sẽ rất đáng nhớ 💖';
    case _ScheduleStage.d1:
      return 'Ngày mai là cột mốc $days ngày yêu của $coupleLabel. Lưu lại khoảnh khắc này nha 🥰';
    case _ScheduleStage.d0:
      return 'Tèn ten! Hôm nay $coupleLabel tròn $days ngày yêu. Chúc hai bạn luôn thật hạnh phúc 🥳';
    case _ScheduleStage.unknown:
      return '$coupleLabel đang có một cột mốc $days ngày yêu rất đáng nhớ đó!';
  }
}

String _genericTitle(_ScheduleStage stage) {
  switch (stage) {
    case _ScheduleStage.d3:
      return '🎉 Sắp tới rồi!';
    case _ScheduleStage.d2:
      return '⏳ Còn 2 ngày nữa!';
    case _ScheduleStage.d1:
      return '⏰ Ngày mai là tới rồi!';
    case _ScheduleStage.d0:
      return '🔔 Hôm nay là ngày đặc biệt!';
    case _ScheduleStage.unknown:
      return 'Thông báo mới';
  }
}

String _genericMessage(
  _ScheduleStage stage,
  String eventLabel, {
  required String fallbackMessage,
}) {
  if (eventLabel.trim().isEmpty && fallbackMessage.trim().isNotEmpty) {
    return fallbackMessage.trim();
  }
  switch (stage) {
    case _ScheduleStage.d3:
      return 'Chỉ còn 3 ngày nữa là đến $eventLabel nè! Chuẩn bị điều gì đó thật vui nhé! 🎁';
    case _ScheduleStage.d2:
      return 'Chỉ còn 2 ngày nữa là đến $eventLabel thôi nha! 💖';
    case _ScheduleStage.d1:
      return 'Hồi hộp quá! Chỉ còn 1 ngày nữa là đến $eventLabel rồi đó! 🥰';
    case _ScheduleStage.d0:
      return 'Tèn ten! Hôm nay là $eventLabel nè! Chúc một ngày thật vui vẻ nhé! 🥳';
    case _ScheduleStage.unknown:
      return fallbackMessage.trim().isNotEmpty
          ? fallbackMessage.trim()
          : 'Đừng quên $eventLabel nhé!';
  }
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
  if (_containsAny(combined, const ['3 ngày'])) return _ScheduleStage.d3;
  if (_containsAny(combined, const ['2 ngày'])) return _ScheduleStage.d2;
  if (_containsAny(combined, const ['1 ngày', 'ngày mai'])) {
    return _ScheduleStage.d1;
  }
  if (_containsAny(combined, const ['hôm nay'])) return _ScheduleStage.d0;
  return _ScheduleStage.unknown;
}

String _normalizeText(String value) {
  return value
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('á', 'a')
      .replaceAll('ạ', 'a')
      .replaceAll('ả', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ă', 'a')
      .replaceAll('ằ', 'a')
      .replaceAll('ắ', 'a')
      .replaceAll('ặ', 'a')
      .replaceAll('ẳ', 'a')
      .replaceAll('ẵ', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ầ', 'a')
      .replaceAll('ấ', 'a')
      .replaceAll('ậ', 'a')
      .replaceAll('ẩ', 'a')
      .replaceAll('ẫ', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ẹ', 'e')
      .replaceAll('ẻ', 'e')
      .replaceAll('ẽ', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ề', 'e')
      .replaceAll('ế', 'e')
      .replaceAll('ệ', 'e')
      .replaceAll('ể', 'e')
      .replaceAll('ễ', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('í', 'i')
      .replaceAll('ị', 'i')
      .replaceAll('ỉ', 'i')
      .replaceAll('ĩ', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ó', 'o')
      .replaceAll('ọ', 'o')
      .replaceAll('ỏ', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ồ', 'o')
      .replaceAll('ố', 'o')
      .replaceAll('ộ', 'o')
      .replaceAll('ổ', 'o')
      .replaceAll('ỗ', 'o')
      .replaceAll('ơ', 'o')
      .replaceAll('ờ', 'o')
      .replaceAll('ớ', 'o')
      .replaceAll('ợ', 'o')
      .replaceAll('ở', 'o')
      .replaceAll('ỡ', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('ú', 'u')
      .replaceAll('ụ', 'u')
      .replaceAll('ủ', 'u')
      .replaceAll('ũ', 'u')
      .replaceAll('ư', 'u')
      .replaceAll('ừ', 'u')
      .replaceAll('ứ', 'u')
      .replaceAll('ự', 'u')
      .replaceAll('ử', 'u')
      .replaceAll('ữ', 'u')
      .replaceAll('ỳ', 'y')
      .replaceAll('ý', 'y')
      .replaceAll('ỵ', 'y')
      .replaceAll('ỷ', 'y')
      .replaceAll('ỹ', 'y')
      .replaceAll('đ', 'd');
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
