class AppIconService {
  AppIconService._();

  static const String defaultIconKey = 'default';

  static bool get isSupported => false;

  static String normalizeIconKey(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == defaultIconKey) {
      return normalized;
    }
    return defaultIconKey;
  }

  static List<String> get supportedIconKeys => const <String>[defaultIconKey];

  static String labelFor(String key) {
    switch (normalizeIconKey(key)) {
      case defaultIconKey:
      default:
        return 'Mặc định';
    }
  }

  static Future<String> getCurrentIconKey() async {
    return defaultIconKey;
  }

  static Future<bool> setCurrentIconKey(String key) async {
    return normalizeIconKey(key) == defaultIconKey;
  }
}
