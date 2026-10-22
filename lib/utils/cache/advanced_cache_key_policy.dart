/// Các key SharedPreferences mà nút "Xóa cache" được phép xóa.
///
/// Danh sách này cố ý hẹp: key chưa được nhận diện có thể là dữ liệu người
/// dùng, cờ xác thực, cài đặt hoặc hàng đợi đang chờ đồng bộ nên phải được giữ.
bool isRecognizedAdvancedCacheKey(String key) {
  final normalized = key.trim();
  if (normalized.isEmpty) return false;

  const exactKeys = <String>{
    'home_startup_media_paths_v1',
    'sys_is_maintenance',
  };
  const prefixes = <String>{'api_cache_'};

  if (exactKeys.contains(normalized)) return true;
  return prefixes.any(normalized.startsWith);
}
