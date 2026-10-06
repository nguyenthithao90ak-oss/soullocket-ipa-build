import 'services/l10n_service.dart';

part 'ui_copy_fallback.dart';

/// Bản sao vi/en chỉ phục vụ bootstrap; giao diện dùng catalog của locale đang chọn.
abstract final class UiCopy {
  static String text(String key, [Map<String, Object?> params = const {}]) {
    final l10n = L10nService();
    final translated = l10n.translate(key);
    final fallback = _uiCopyFallback[key];
    final template = translated != key
        ? translated
        : fallback?[l10n.localeCode == 'vi' ? 'vi' : 'en'] ?? key;
    return _format(template, params);
  }

  static String bilingual(String key, bool isEnglish,
      [Map<String, Object?> params = const {}]) {
    // Giữ hợp đồng các caller cũ truyền isEnglish trước khi locale đã init.
    if (isEnglish && L10nService().localeCode == 'vi') {
      return _format(_uiCopyFallback[key]?['en'] ?? key, params);
    }
    return text(key, params);
  }

  static String canonical(String key, Map<String, Object?> params) =>
      _format(_uiCopyFallback[key]?['vi'] ?? key, params);

  static String _format(String template, Map<String, Object?> params) =>
      template.replaceAllMapped(RegExp(r'\{(\w+)\}'),
          (match) => params.containsKey(match[1]) ? '${params[match[1]] ?? ''}' : match[0]!);
}

/// Giữ nội dung canonical cho logic phân loại lỗi, dịch khi đưa ra giao diện.
class UiCopyException implements Exception {
  const UiCopyException(this.key, [this.params = const {}]);
  final String key;
  final Map<String, Object?> params;
  String get canonicalMessage => UiCopy.canonical(key, params);
  String get message => UiCopy.text(key, params);
  @override
  String toString() => canonicalMessage;
}
