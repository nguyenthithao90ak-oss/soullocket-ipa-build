/// Trạng thái nền PRO từ snapshot thời tiết hiện có, không đọc mạng.
enum WeatherBackgroundState {
  unknown,
  sunny,
  cloudy,
  rain,
  lightning,
  cold;

  String get labelKey => 'weather_background_$name';

  static WeatherBackgroundState normalize(String? raw) =>
      values.firstWhere((state) => state.name == raw, orElse: () => unknown);

  static WeatherBackgroundState fromWeather(Map<String, dynamic>? weather) {
    if (weather == null || weather.isEmpty) return unknown;
    final rawCode = _finiteNumber(weather['code']);
    final code = rawCode != null && rawCode == rawCode.truncateToDouble()
        ? rawCode.toInt()
        : -1;
    final temp = _finiteNumber(weather['temp']);
    if (const {95, 96, 99}.contains(code)) return lightning;
    if (_flag(weather['isRain']) ||
        (code >= 51 && code <= 67) ||
        (code >= 80 && code <= 82)) {
      return rain;
    }
    if (_flag(weather['isCold']) ||
        (temp != null && temp < 18) ||
        (code >= 71 && code <= 77) ||
        code == 85 ||
        code == 86) {
      return cold;
    }
    if (const {2, 3, 45, 48}.contains(code)) return cloudy;
    if (code == 0 || code == 1) return sunny;
    return unknown;
  }

  static double? _finiteNumber(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static bool _flag(dynamic value) {
    if (value is bool) return value;
    return const {
      'true',
      '1',
      'yes',
    }.contains(value?.toString().trim().toLowerCase());
  }
}

class WeatherBackgroundSnapshot {
  final WeatherBackgroundState left;
  final WeatherBackgroundState right;
  const WeatherBackgroundSnapshot({
    this.left = WeatherBackgroundState.unknown,
    this.right = WeatherBackgroundState.unknown,
  });

  factory WeatherBackgroundSnapshot.fromPresence({
    Map<String, dynamic>? left,
    Map<String, dynamic>? right,
  }) => WeatherBackgroundSnapshot(
    left: WeatherBackgroundState.fromWeather(left),
    right: WeatherBackgroundState.fromWeather(right),
  );

  @override
  bool operator ==(Object other) =>
      other is WeatherBackgroundSnapshot &&
      other.left == left &&
      other.right == right;
  @override
  int get hashCode => Object.hash(left, right);
}

abstract final class WeatherBackgroundAccess {
  static const themeKey = 'weather_premium';

  static String resolveTheme(String theme, {required bool isPro}) =>
      theme == themeKey && !isPro ? 'pink' : theme;

  static bool needsWeather({
    required bool showWeather,
    required String homeBackground,
    required String widgetBackground,
  }) =>
      showWeather || homeBackground == themeKey || widgetBackground == themeKey;
}
