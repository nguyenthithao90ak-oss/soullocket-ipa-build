import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  };
  static String normalize(String key) => keys.contains(key) ? key : 'pink';
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
    this.child,
  });
  final String themeKey;
  final List<Color>? colors;
  final double radius;
  final bool animated, twinkle;
  final double artworkOpacity;
  final bool drawBorder;
  final Widget? child;

  @override
  State<WidgetThemeSurface> createState() => _WidgetThemeSurfaceState();
}

class _WidgetThemeSurfaceState extends State<WidgetThemeSurface> {
  Timer? _timer;
  bool _alternate = false;
  bool _motion = false;

  void _syncMotion() {
    _timer?.cancel();
    _alternate = false;
    _motion = widget.animated && !MediaQuery.disableAnimationsOf(context);
    if (_motion) {
      final key = WidgetThemeDesign.normalize(widget.themeKey);
      _timer = Timer.periodic(
        Duration(milliseconds: WidgetThemeDesign.intervals[key]!),
        (_) {
          if (mounted) setState(() => _alternate = !_alternate);
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(WidgetThemeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final key = WidgetThemeDesign.normalize(widget.themeKey);
    final alternate = widget.twinkle || (_motion && _alternate);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.colors ?? WidgetThemeDesign.palettes[key]!,
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
                  child: SvgPicture.asset(
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
