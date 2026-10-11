/// Lịch sử của tiện ích đã gỡ vẫn đọc được nhưng không tạo lại dữ liệu của nó.
bool isRetiredListRestore(String module, String restorePath) {
  final moduleKey = module.trim().toLowerCase();
  return moduleKey == 'bucket_list' ||
      moduleKey == 'wishlist' ||
      RegExp(
        r'^houses/[^/]+/(bucket|wishlist)(/|$)',
      ).hasMatch(restorePath.trim());
}
