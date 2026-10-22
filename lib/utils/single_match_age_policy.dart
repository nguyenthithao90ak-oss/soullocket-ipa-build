/// Lớp kiểm tra ngày sinh tự khai, không thay thế xác minh tuổi ở máy chủ.
abstract final class SingleMatchAgePolicy {
  static int? ageFromDob(String rawDob, {DateTime? now}) {
    final raw = rawDob.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}(?:T.*)?$').hasMatch(raw)) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final parts = raw.substring(0, 10).split('-').map(int.parse).toList();
    final dob = DateTime.utc(parts[0], parts[1], parts[2]);
    if (dob.year != parts[0] || dob.month != parts[1] || dob.day != parts[2]) {
      return null;
    }
    final today = (now ?? DateTime.now()).toUtc();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age >= 0 && age <= 120 ? age : null;
  }

  static bool isAdult(String rawDob, {DateTime? now}) =>
      (ageFromDob(rawDob, now: now) ?? -1) >= 18;
}
