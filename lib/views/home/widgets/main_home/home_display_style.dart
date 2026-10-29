/// Kiểu trình bày Home là lựa chọn cá nhân, không đổi dữ liệu của ngôi nhà.
enum HomeDisplayStyle {
  current,
  nest,
  portrait,
  scrapbook,
  cloud,
  daily,
  minimal;

  String get storageKey => name;

  String get titleKey => 'home_display_style_$name';

  String get descriptionKey => '${titleKey}_desc';

  /// App cũ, giá trị hỏng hoặc kiểu chưa hỗ trợ đều giữ Home mặc định.
  static HomeDisplayStyle parse(Object? value) {
    if (value is! String) return HomeDisplayStyle.current;
    final key = value.trim().toLowerCase();
    for (final style in values) {
      if (style.storageKey == key) return style;
    }
    return HomeDisplayStyle.current;
  }
}
