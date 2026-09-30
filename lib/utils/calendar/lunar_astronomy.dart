// Adapted from astronomia (MIT), moonphase.js and solar.js.
// Copyright (c) 2013 Sonia Keys; Copyright (c) 2016 Commenthol.
// Full license: third_party/astronomia-LICENSE.txt.
import 'dart:math' as math;

/// Phép tính thiên văn cho lịch dân sự, UTC+7 (Việt Nam) hoặc UTC+8.
abstract final class LunarAstronomy {
  static double _sin(double degrees) => math.sin(degrees * math.pi / 180);
  static double _poly(double t, List<double> c) {
    var value = c.last;
    for (var i = c.length - 2; i >= 0; i--) {
      value = value * t + c[i];
    }
    return value;
  }

  static double newMoon(int lunation) {
    final k = lunation.toDouble();
    final t = k / 1236.85;
    final e = _poly(t, [1, -0.002516, -0.0000074]);
    final m = _poly(t, [2.5534, 29.1053567 * 1236.85, -0.0000014, -0.00000011]);
    final moon = _poly(t, [
      201.5643,
      385.81693528 * 1236.85,
      0.0107582,
      0.00001238,
      -0.000000058,
    ]);
    final f = _poly(t, [
      160.7108,
      390.67050284 * 1236.85,
      -0.0016118,
      -0.00000227,
      0.000000011,
    ]);
    final node = _poly(t, [
      124.7746,
      -1.56375588 * 1236.85,
      0.0020672,
      0.00000215,
    ]);
    final angles = [
      moon,
      m,
      2 * moon,
      2 * f,
      moon - m,
      moon + m,
      2 * m,
      moon - 2 * f,
      moon + 2 * f,
      2 * moon + m,
      3 * moon,
      m + 2 * f,
      m - 2 * f,
      2 * moon - m,
      node,
      moon + 2 * m,
      2 * (moon - f),
      3 * m,
      moon + m - 2 * f,
      2 * (moon + f),
      moon + m + 2 * f,
      moon - m + 2 * f,
      moon - m - 2 * f,
      3 * moon + m,
      4 * moon,
    ];
    const coefficients = [
      -0.4072,
      0.17241,
      0.01608,
      0.01039,
      0.00739,
      -0.00514,
      0.00208,
      -0.00111,
      -0.00057,
      0.00056,
      -0.00042,
      0.00042,
      0.00038,
      -0.00024,
      -0.00017,
      -0.00007,
      0.00004,
      0.00004,
      0.00003,
      0.00003,
      -0.00003,
      0.00003,
      -0.00002,
      -0.00002,
      0.00002,
    ];
    var correction = 0.0;
    for (var i = 0; i < coefficients.length; i++) {
      final factor = i == 6
          ? e * e
          : const [1, 4, 5, 9, 11, 12, 13].contains(i)
          ? e
          : 1.0;
      correction += coefficients[i] * _sin(angles[i]) * factor;
    }
    const extra = [
      (0.000325, 299.7, 0.107408),
      (0.000165, 251.88, 0.016321),
      (0.000164, 251.83, 26.651886),
      (0.000126, 349.42, 36.412478),
      (0.000110, 84.66, 18.206239),
      (0.000062, 141.74, 53.303771),
      (0.000060, 207.17, 2.453732),
      (0.000056, 154.84, 7.30686),
      (0.000047, 34.52, 27.261239),
      (0.000042, 207.19, 0.121824),
      (0.000040, 291.34, 1.844379),
      (0.000037, 161.72, 24.198154),
      (0.000035, 239.56, 25.513099),
      (0.000023, 331.55, 3.592518),
    ];
    for (var i = 0; i < extra.length; i++) {
      final term = extra[i];
      final radians =
          (term.$2 + term.$3 * k) * math.pi / 180 -
          (i == 0 ? 0.009173 * t * t : 0);
      correction += term.$1 * math.sin(radians);
    }
    final jde =
        _poly(t, [
          2451550.09766,
          29.530588861 * 1236.85,
          0.00015437,
          -0.00000015,
          0.00000000073,
        ]) +
        correction;
    final year = 2000 + k / 12.3685;
    // NASA/Espenak–Meeus: TT−UT approximation over the supported period.
    final u = year - 2000;
    final deltaT = year < 2005
        ? _poly(u, [
            63.86,
            0.3345,
            -0.060374,
            0.0017275,
            0.000651814,
            0.00002373599,
          ])
        : 62.92 + 0.32217 * u + 0.005589 * u * u;
    return jde - deltaT / 86400;
  }

  static double solarLongitude(double jd) {
    final t = (jd - 2451545) / 36525;
    final mean = _poly(t, [280.46646, 36000.76983, 0.0003032]);
    final anomaly = _poly(t, [357.52911, 35999.05029, -0.0001537]);
    final center =
        _poly(t, [1.914602, -0.004817, -0.000014]) * _sin(anomaly) +
        (0.019993 - 0.000101 * t) * _sin(2 * anomaly) +
        0.000289 * _sin(3 * anomaly);
    return (mean + center - 0.00569 - 0.00478 * _sin(125.04 - 1934.136 * t)) %
        360;
  }

  static double julianDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch /
          Duration.millisecondsPerDay +
      2440587.5;

  static int civilDay(double jd, int offsetHours) =>
      (jd + 0.5 + offsetHours / 24).floor();

  static DateTime dateFromDay(int day) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      ((day - 2440588) * Duration.millisecondsPerDay),
      isUtc: true,
    );
    return DateTime(utc.year, utc.month, utc.day);
  }
}
