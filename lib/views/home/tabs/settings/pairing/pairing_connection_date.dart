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
