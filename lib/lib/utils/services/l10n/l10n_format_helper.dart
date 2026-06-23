part of '../l10n_service.dart';

class _L10nFormatHelper {
  const _L10nFormatHelper();

  String format(String value, Map<String, Object?> params) {
    var resolved = value;
    params.forEach((name, replacement) {
      resolved = resolved.replaceAll('{$name}', '${replacement ?? ''}');
    });
    return resolved;
  }
}
