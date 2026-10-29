/// Các bản sao dùng để hiển thị. Ngày sinh chỉ được lưu trong settings riêng.
Map<String, Object?> houseIdentityProjectionUpdates(
  String houseId,
  String field,
  Object? value,
) {
  if (value is! String || value.isEmpty) return const {};
  final roots = switch (field) {
    'nameU1' || 'nameU2' => const ['house_profiles'],
    'houseName' ||
    'startDate' ||
    'dayUnit' => const ['house_profiles', 'houses_public'],
    _ => const <String>[],
  };
  return {
    for (final root in roots) ...{
      '$root/$houseId/$field': value,
      '$root/$houseId/settings/$field': value,
    },
  };
}
