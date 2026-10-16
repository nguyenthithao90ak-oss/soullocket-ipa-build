/// Dựng các lượt xóa lịch sử GPS đã quá hạn.
///
/// Luật RTDB chỉ cho chủ vai ghi/xóa từng điểm
/// `gps_history/{houseId}/{role}/{dateKey}/{entryId}`, không cho xóa nguyên
/// ngày, nên mỗi điểm của các ngày quá hạn được xóa bằng đường dẫn riêng.
/// Chia lượt để mỗi lần `update` không quá lớn.
List<Map<String, Object?>> expiredGpsHistoryDeletionBatches({
  required String houseId,
  required String role,
  required Map<String, dynamic> expiredDays,
  int batchSize = 400,
}) {
  final batches = <Map<String, Object?>>[];
  var current = <String, Object?>{};
  for (final day in expiredDays.entries) {
    final points = day.value;
    if (points is! Map) continue;
    for (final entryId in points.keys) {
      current['gps_history/$houseId/$role/${day.key}/$entryId'] = null;
      if (current.length >= batchSize) {
        batches.add(current);
        current = <String, Object?>{};
      }
    }
  }
  if (current.isNotEmpty) batches.add(current);
  return batches;
}
