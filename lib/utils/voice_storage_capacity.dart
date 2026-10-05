/// Dung lượng kho ghi âm của một nhà, tính từ `houses/{houseId}/utilities/voices`.
///
/// Phải khớp `functions/voiceUploadGuards.js`: server là nơi quyết định cuối cùng,
/// client chỉ dùng để báo sớm và giới hạn thời gian ghi.
abstract final class VoiceStorageCapacity {
  static const int capacityMs = 5 * 60 * 1000;
  static const String rejectionReason = 'voice-capacity-exceeded';

  static int _nonNegative(Object? value) {
    final number = switch (value) {
      num() => value.isFinite ? value.toInt() : 0,
      String() => num.tryParse(value.trim())?.toInt() ?? 0,
      _ => 0,
    };
    return number > 0 ? number : 0;
  }

  /// Tổng thời lượng đã lưu; bỏ qua bản ghi hỏng và chấp nhận số dạng chuỗi của dữ liệu cũ.
  static int storedDurationMs(Object? voices) {
    final Iterable<Object?> records = switch (voices) {
      Map() => voices.values,
      List() => voices,
      _ => const <Object?>[],
    };
    var total = 0;
    for (final record in records) {
      if (record is Map) total += _nonNegative(record['duration']);
    }
    return total;
  }

  static int remainingMs(Object? voices) {
    final remaining = capacityMs - storedDurationMs(voices);
    return remaining < 0 ? 0 : remaining;
  }
}
