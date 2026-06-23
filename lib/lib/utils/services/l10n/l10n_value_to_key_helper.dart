part of '../l10n_service.dart';

abstract final class _L10nValueToKeyHelper {
  static Map<String, String> buildFromSources(
    Iterable<Map<String, String>> sources,
  ) {
    final lookup = <String, String>{};
    for (final entries in sources) {
      for (final entry in entries.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        lookup.putIfAbsent(value, () => entry.key);
      }
    }
    return lookup;
  }
}
