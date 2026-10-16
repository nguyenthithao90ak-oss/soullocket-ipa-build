import 'dart:async';
import '../../../../../models/weather_background.dart';
import '../../../../../widgets/weather_premium_artwork.dart';
import '../../../../../utils/services/widget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../utils/screen_activity_mixin.dart';

/// Nét vẽ và nhịp riêng từng chủ đề; cùng catalog với WidgetThemeBackground Android.
abstract final class WidgetThemeDesign {
  static const keys = [
    'pink',
    'dark',
    'white',
    'blue',
    'orange',
    'purple',
    'green',
    'red',
    'premium',
    'cosmic',
    'weather_premium',
  ];
  static const intervals = {
    'pink': 3200,
    'dark': 4600,
    'white': 5000,
    'blue': 2400,
    'orange': 3800,
    'purple': 2900,
    'green': 4100,
    'red': 3500,
    'premium': 2700,
    'cosmic': 4300,
    'weather_premium': 3200,
  };
  static const palettes = {
    'pink': [Color(0xFFFFF3E5), Color(0xFFFFDDE7), Color(0xFFDAD8FF)],
    'dark': [Color(0xFF202338), Color(0xFF35324F), Color(0xFF2B4754)],
    'white': [Color(0xFFFFFFFF), Color(0xFFF4F0FF), Color(0xFFE2F0F6)],
    'blue': [Color(0xFFF5FBFF), Color(0xFFD8EAFF), Color(0xFFDDDFFA)],
    'orange': [Color(0xFFFFF7DE), Color(0xFFFFDFBF), Color(0xFFF5D3DC)],
    'purple': [Color(0xFFFFF1FA), Color(0xFFE8D8F7), Color(0xFFD7E8FA)],
    'green': [Color(0xFFFFF9DF), Color(0xFFDDF2DF), Color(0xFFC8E8E2)],
    'red': [Color(0xFF60213D), Color(0xFF973D52), Color(0xFFB9676A)],
    'premium': [
      Color(0xFFFF5FA2),
      Color(0xFFFFB86B),
      Color(0xFF67E8F9),
      Color(0xFF7C3AED),
    ],
    'cosmic': [Color(0xFF17142F), Color(0xFF322952), Color(0xFF514563)],
    'weather_premium': [
      Color(0xFFDCE7F1),
      Color(0xFFF7F3FA),
      Color(0xFFDCEDED),
    ],
  };
  static String normalize(String key) => keys.contains(key) ? key : 'pink';

  /// Palette dùng chung cho nền, chữ và các điểm nhấn của mọi mẫu widget.
  ///
  /// Widget đôi và các widget tiện ích phải lấy màu từ cùng catalog này để
  /// đổi theme trong Cài đặt luôn được phản ánh ở toàn bộ preview/native.
  static List<Color> palette(String key) => palettes[normalize(key)]!;

  static bool isDark(String key) => switch (normalize(key)) {
    'dark' || 'red' || 'premium' || 'cosmic' => true,
    _ => false,
  };

  static Color ink(String key) => switch (normalize(key)) {
    'dark' => Colors.white,
    'red' => const Color(0xFFFFF0DC),
    'premium' => Colors.white,
    'cosmic' => const Color(0xFFFFF0BD),
    'blue' => const Color(0xFF0D47A1),
    'orange' => const Color(0xFFE65100),
    'purple' => const Color(0xFF6A1B9A),
    'green' => const Color(0xFF1B5E20),
    'weather_premium' => const Color(0xFF3C4F69),
    _ => const Color(0xFF333333),
  };

  /// Điểm nhấn số ngày/vòng tiến trình, khớp màu đếm ngày của widget đôi.
  static Color accent(String key) => switch (normalize(key)) {
    'white' => const Color(0xFF9B335E),
    'blue' => const Color(0xFF0F52BA),
    'orange' => const Color(0xFFF97316),
    'purple' => const Color(0xFF8B5CF6),
    'green' => const Color(0xFF16A34A),
    'red' => const Color(0xFFFFE1AB),
    'dark' || 'premium' => Colors.white,
    'cosmic' => const Color(0xFFFFE396),
    'weather_premium' => const Color(0xFF7954AA),
    _ => const Color(0xFFFF4D73),
  };

  static Color cardColor(String key) => isDark(key)
      ? Colors.black.withValues(alpha: .22)
      : Colors.white.withValues(alpha: .48);

  static Color avatarColor(String key) => isDark(key)
      ? Colors.white.withValues(alpha: .14)
      : Color.lerp(palette(key).first, Colors.white, .52)!;

  static Color progressTrack(String key) =>
      Color.lerp(accent(key), Colors.white, isDark(key) ? .52 : .72)!;

  /// Màu số đếm: theo theme như widget đôi, pha nhẹ màu riêng (vd. màu sự kiện)
  /// với cùng tỷ lệ mà widget đôi pha màu tim, nên luôn đọc rõ trên nền tối.
  static Color daysColor(String key, Color tint) =>
      Color.lerp(accent(key), tint, isDark(key) ? .28 : .36)!;
}

/// Một đường clip duy nhất cho nền, hình vẽ, hiệu ứng và nội dung: không ló mép.
class WidgetThemeSurface extends StatefulWidget {
  const WidgetThemeSurface({
    super.key,
    required this.themeKey,
    this.colors,
    this.radius = 24,
    this.animated = false,
    this.twinkle = false,
    this.artworkOpacity = 1,
    this.drawBorder = true,
    this.weather,
    this.child,
  });
  final String themeKey;
  final List<Color>? colors;
  final double radius;
  final bool animated, twinkle;
  final double artworkOpacity;
  final bool drawBorder;
  final Widget? child;
  final WeatherBackgroundSnapshot? weather;

  @override
  State<WidgetThemeSurface> createState() => _WidgetThemeSurfaceState();
}

class _WidgetThemeSurfaceState extends State<WidgetThemeSurface>
    with ScreenActivityMixin {
  Timer? _timer;
  bool _alternate = false;
  bool _motion = false;
  bool _weatherPreviewLoaded = false;

  void _loadWeatherPreview() {
    if (widget.themeKey != WeatherBackgroundAccess.themeKey ||
        widget.weather != null ||
        _weatherPreviewLoaded) {
      return;
    }
    _weatherPreviewLoaded = true;
    unawaited(WidgetService.refreshWeatherBackgroundPreview());
  }

  void _syncMotion() {
    _timer?.cancel();
    _timer = null;
    _alternate = false;
    _motion =
        isScreenActive &&
        widget.animated &&
        !MediaQuery.disableAnimationsOf(context);
    if (_motion) {
      final key = WidgetThemeDesign.normalize(widget.themeKey);
      _timer = Timer.periodic(
        Duration(milliseconds: WidgetThemeDesign.intervals[key]!),
        (_) {
          if (isScreenActive) setState(() => _alternate = !_alternate);
        },
      );
    }
  }

  @override
  void onScreenActivityChanged(bool active) => _syncMotion();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
    _loadWeatherPreview();
  }

  @override
  void didUpdateWidget(WidgetThemeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeKey != widget.themeKey) _weatherPreviewLoaded = false;
    _loadWeatherPreview();
    if (oldWidget.themeKey != widget.themeKey ||
        oldWidget.animated != widget.animated) {
      _syncMotion();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.themeKey == WeatherBackgroundAccess.themeKey &&
        widget.weather == null) {
      return ValueListenableBuilder<WeatherBackgroundSnapshot>(
        valueListenable: WidgetService.weatherBackgroundNotifier,
        builder: (context, weather, _) => _buildSurface(context, weather),
      );
    }
    return _buildSurface(
      context,
      widget.weather ?? const WeatherBackgroundSnapshot(),
    );
  }

  Widget _buildSurface(
    BuildContext context,
    WeatherBackgroundSnapshot weather,
  ) {
    final key = WidgetThemeDesign.normalize(widget.themeKey);
    final alternate = widget.twinkle || (_motion && _alternate);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: key == WeatherBackgroundAccess.themeKey
                ? WeatherBackgroundDesign.colors(weather)
                : widget.colors ?? WidgetThemeDesign.palettes[key]!,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: widget.artworkOpacity,
                child: AnimatedSwitcher(
                  duration: _motion
                      ? const Duration(milliseconds: 420)
                      : Duration.zero,
                  child: key == WeatherBackgroundAccess.themeKey
                      ? WeatherPremiumArtwork(
                          key: ValueKey(('weather-art', weather, alternate)),
                          weather: weather,
                          alternate: alternate,
                        )
                      : SvgPicture.asset(
                          'assets/images/widget_stickers/theme_$key${alternate ? '_twinkle' : ''}.svg',
                          key: ValueKey('theme-art-$key-$alternate'),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.fill,
                        ),
                ),
              ),
            ),
            if (widget.child != null) widget.child!,
            if (widget.drawBorder)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _InsetSurfaceBorder(widget.radius),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsetSurfaceBorder extends CustomPainter {
  const _InsetSurfaceBorder(this.radius);
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.5);
    if (rect.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular((radius - .5).clamp(0, radius)),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_InsetSurfaceBorder oldDelegate) =>
      oldDelegate.radius != radius;
}
