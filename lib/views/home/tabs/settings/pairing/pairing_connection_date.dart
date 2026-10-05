/// Chỉ đọc thời điểm ghép nối do máy chủ lưu, không suy từ ngày tạo nhà/ngày yêu.
DateTime? parsePairingConnectionDate(Object? value) {
  final timestamp = value is num
      ? value
      : value is String
      ? num.tryParse(value.trim())
      : null;
  if (timestamp == null ||
      !timestamp.isFinite ||
      timestamp <= 0 ||
      timestamp > 8640000000000000) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
}

class PairingConnectionDetails {
  const PairingConnectionDetails({
    required this.date,
    this.fromMembership = false,
  });

  final DateTime date;
  final bool fromMembership;

  int daysTogether(DateTime now) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.difference(start).inDays.clamp(0, 365000000) + 1;
  }
}

PairingConnectionDetails? resolvePairingConnectionDetails({
  required Object? connectedAt,
  required Map members,
  required DateTime now,
}) {
  DateTime? validDate(Object? value) {
    final date = parsePairingConnectionDate(value);
    return date != null && !date.isAfter(now.add(const Duration(minutes: 1)))
        ? date
        : null;
  }

  final serverDate = validDate(connectedAt);
  if (serverDate != null) return PairingConnectionDetails(date: serverDate);
  if (members.length != 2) return null;
  final joined = <String, DateTime>{};
  for (final entry in members.entries) {
    final member = entry.value;
    if (member is! Map || entry.key.toString().trim().isEmpty) return null;
    final uid = member['uid'];
    if (uid != null && uid != entry.key) return null;
    final role = member['role'];
    if (role != 'user1' && role != 'user2') return null;
    final date = validDate(member['joinedAt']);
    if (date == null || joined.containsKey(role)) return null;
    joined[role as String] = date;
  }
  final first = joined['user1'];
  final second = joined['user2'];
  if (first == null || second == null) return null;
  return PairingConnectionDetails(
    date: first.isAfter(second) ? first : second,
    fromMembership: true,
  );
}
