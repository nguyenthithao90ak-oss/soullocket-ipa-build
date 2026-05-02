part of '../pin_pad_setup_modal.dart';

class FloatingBackgroundIcons extends StatefulWidget {
  final List<String> emojis;
  const FloatingBackgroundIcons({super.key, required this.emojis});

  @override
  State<FloatingBackgroundIcons> createState() =>
      _FloatingBackgroundIconsState();
}

class _FloatingBackgroundIconsState extends State<FloatingBackgroundIcons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final int _iconCount = 20;
  final Random _random = Random();
  late List<_FloatingIcon> _icons;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    bool isAndroidOrWeak = defaultTargetPlatform == TargetPlatform.android;

    if (!isAndroidOrWeak) {
      _controller.repeat();
    }

    _icons = List.generate(_iconCount, (index) {
      return _FloatingIcon(
        emoji: widget.emojis[_random.nextInt(widget.emojis.length)],
        startX: _random.nextDouble(),
        startY: _random.nextDouble(),
        speed: 0.1 + _random.nextDouble() * 0.3,
        size: 20 + _random.nextDouble() * 30,
        opacity: 0.1 + _random.nextDouble() * 0.3,
        sinScale: 0.5 + _random.nextDouble() * 1.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _FloatingIconsPainter(
            icons: _icons,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FloatingIcon {
  final String emoji;
  final double startX;
  final double startY;
  final double speed;
  final double size;
  final double opacity;
  final double sinScale;

  _FloatingIcon({
    required this.emoji,
    required this.startX,
    required this.startY,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.sinScale,
  });
}

class _FloatingIconsPainter extends CustomPainter {
  final List<_FloatingIcon> icons;
  final double progress;

  _FloatingIconsPainter({required this.icons, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var icon in icons) {
      double y = (icon.startY - (progress * icon.speed)) % 1.0;
      if (y < 0) y += 1.0;

      double x = icon.startX +
          sin((progress * pi * 2 * icon.sinScale) + icon.startY) * 0.05;
      x = x % 1.0;
      if (x < 0) x += 1.0;

      final TextSpan span = TextSpan(
        text: icon.emoji,
        style: TextStyle(
          fontSize: icon.size,
          color: Colors.white.withOpacity(icon.opacity),
        ),
      );

      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );

      tp.layout();
      tp.paint(
        canvas,
        Offset(x * size.width - tp.width / 2, y * size.height - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingIconsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

enum PinUnlockStatus {
  success,
  invalid,
  blocked,
}

class PinUnlockResult {
  final PinUnlockStatus status;
  final String? message;
  final int remainingAttempts;
  final int remainingLockSeconds;
  final int failedAttempts;
  final bool canRecoverWithEmail;

  const PinUnlockResult({
    required this.status,
    this.message,
    this.remainingAttempts = 0,
    this.remainingLockSeconds = 0,
    this.failedAttempts = 0,
    this.canRecoverWithEmail = false,
  });
}
