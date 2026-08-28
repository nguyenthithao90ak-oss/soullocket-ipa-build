part of '../../main_home_tab.dart';

/// Giao diện Home toàn màn hình — giống ảnh mẫu "Bênh Nhauu"
/// Hiển thị khi [UiPrefs.notifier.value.homeLayoutKey] == 'fullscreen'
class _FullscreenHomeBody extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String houseName;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final VoidCallback? onOpenSettings;

  const _FullscreenHomeBody({
    required this.state,
    required this.isSingle,
    required this.houseName,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    final quote = (circleBottomLabel.isNotEmpty &&
            circleBottomLabel.trim().toLowerCase() != 'ngày yêu')
        ? circleBottomLabel
        : 'Cảm ơn vì đã đến bên mình 💕💕';

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Tim rơi animation overlay ---
          const Positioned.fill(
            child: IgnorePointer(
              child: _FullscreenFallingHeartsOverlay(),
            ),
          ),

          // --- Nội dung chính ---
          Positioned.fill(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Khoảng trống bù cho top header
                      SizedBox(height: topPad + 60),

                      // --- CENTER: Trái tim Neon & Số ngày đếm ngược ---
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () => state._showEditStartDateDialog(),
                            onLongPressStart: (details) =>
                                state._handleInteractionLongPressStart(details),
                            onLongPressMoveUpdate: (details) =>
                                state._handleInteractionLongPressMoveUpdate(
                                    details),
                            onLongPressEnd: (details) =>
                                state._handleInteractionLongPressEnd(details),
                            onLongPressCancel: () =>
                                state._handleInteractionLongPressCancel(),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Custom Paint vẽ khung tim sáng
                                CustomPaint(
                                  size: const Size(320, 300),
                                  painter: _NeonHeartPainter(),
                                ),
                                // Nội dung bên trong khung tim
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            state._showEditCountdownLabelDialog(
                                          editTopLabel: true,
                                          currentLabel: circleTopLabel,
                                        ),
                                        child: SizedBox(
                                          width: 260,
                                          child: Text(
                                            circleTopLabel.isNotEmpty
                                                ? circleTopLabel
                                                : 'BỀN NHAUuuuu',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: SLTheme.quicksand(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              shadows: [
                                                const Shadow(
                                                  color: Color(0xFFFF69B4),
                                                  blurRadius: 15,
                                                ),
                                                const Shadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ShaderMask(
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                          colors: [
                                            Color(0xFFFF85A2),
                                            Color(0xFFFF3366),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ).createShader(bounds),
                                        child: Text(
                                          circleValue,
                                          style: SLTheme.quicksand(
                                            fontSize: 110,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            height: 1.0,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black26,
                                                blurRadius: 10,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 1.5,
                                            color: const Color(0xFFFF85A2),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'ngày yêu',
                                            style: SLTheme.quicksand(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFFF85A2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 20,
                                            height: 1.5,
                                            color: const Color(0xFFFF85A2),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Icon(
                                        Icons.favorite_border_rounded,
                                        color: Color(0xFFFF85A2),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- BOTTOM: 2 Avatar tự do ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Avatar User 1 (Nam)
                            _FullscreenAvatarItem(
                              state: state,
                              name: nameU1,
                              avatarUrl: avtUser1,
                              isUser1: true,
                              size: 80,
                            ),

                            // Avatar User 2 (Nữ)
                            _FullscreenAvatarItem(
                              state: state,
                              name: isSingle ? '' : nameU2,
                              avatarUrl: isSingle ? '' : avtUser2,
                              isUser1: false,
                              size: 80,
                              isSinglePlaceholder: isSingle,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Quote chữ nghệ thuật dưới cùng
                      Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: bottomPad + 24,
                        ),
                        child: Text(
                          quote,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Pet Avatar (Góc trên trái) ---
          Positioned(
            top: topPad + 4,
            left: 14,
            child: GestureDetector(
              onTap: () {
                // Future: open pet screen
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFFF85A2),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF85A2).withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(
                    'assets/icons/cute_3d/avatar_puppy_heart.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.pets_rounded,
                      color: Color(0xFFFF85A2),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),


          _MainHomeHeroHeader(
            state: state,
            isSingle: isSingle,
            onOpenSettings: onOpenSettings,
            firstGuideSettingsKey: state.widget.firstGuideSettingsKey,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Vẽ viền Neon Trái tim khổng lồ
// -----------------------------------------------------------
class _NeonHeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Đường path vẽ trái tim cân xứng đẹp hơn
    final Path path = Path();
    path.moveTo(width / 2, height * 0.2);
    path.cubicTo(
      width * 1.0, -height * 0.15, // Control point phải trên
      width * 1.25, height * 0.45, // Control point phải dưới
      width / 2, height * 0.95,    // Đáy tim
    );
    path.cubicTo(
      -width * 0.25, height * 0.45, // Control point trái dưới
      0.0, -height * 0.15,          // Control point trái trên
      width / 2, height * 0.2,      // Quay về đỉnh giữa
    );

    // Vẽ viền nhòe (Glow)
    final Paint glowPaint = Paint()
      ..color = const Color(0xFFFF69B4).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, glowPaint);

    // Vẽ viền lõi trắng (Core)
    final Paint corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, corePaint);

    // Vẽ một vài tim nhỏ lơ lửng quanh viền
    _drawSmallHeart(canvas, Offset(width * 0.8, height * 0.15), 8);
    _drawSmallHeart(canvas, Offset(width * 0.9, height * 0.4), 6);
    _drawSmallHeart(canvas, Offset(width * 0.15, height * 0.5), 7);
  }

  void _drawSmallHeart(Canvas canvas, Offset center, double size) {
    final Path heart = Path();
    heart.moveTo(center.dx, center.dy - size / 2);
    heart.cubicTo(
      center.dx + size, center.dy - size * 1.5,
      center.dx + size * 1.5, center.dy + size / 2,
      center.dx, center.dy + size,
    );
    heart.cubicTo(
      center.dx - size * 1.5, center.dy + size / 2,
      center.dx - size, center.dy - size * 1.5,
      center.dx, center.dy - size / 2,
    );

    final Paint paint = Paint()
      ..color = const Color(0xFFFF85A2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(heart, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------
// Avatar item tròn có viền phát sáng
// -----------------------------------------------------------
class _FullscreenAvatarItem extends StatelessWidget {
  final _MainHomeTabState state;
  final String name;
  final String avatarUrl;
  final bool isUser1;
  final double size;
  final bool isSinglePlaceholder;

  const _FullscreenAvatarItem({
    required this.state,
    required this.name,
    required this.avatarUrl,
    required this.isUser1,
    required this.size,
    this.isSinglePlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: Colors.white,
              width: 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF85A2).withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: state._buildAvatar(
              name,
              avatarUrl,
              isUser1: isUser1,
              size: size,
              isSinglePlaceholder: isSinglePlaceholder,
              onTap: () => state._changeAvatar(isUser1: isUser1),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name.isNotEmpty ? name : (isUser1 ? 'Bạn' : 'Người ấy'),
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFF85A2),
            shadows: const [
              Shadow(
                color: Colors.white,
                blurRadius: 4,
              ),
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Tim rơi overlay (dành cho chế độ Toàn màn hình)
// -----------------------------------------------------------
class _FullscreenFallingHeartsOverlay extends StatefulWidget {
  const _FullscreenFallingHeartsOverlay();

  @override
  State<_FullscreenFallingHeartsOverlay> createState() =>
      _FullscreenFallingHeartsOverlayState();
}

class _FullscreenFallingHeartsOverlayState
    extends State<_FullscreenFallingHeartsOverlay>
    with SingleTickerProviderStateMixin {
  late List<_FullscreenHeartParticle> particles;
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    particles = List.generate(15, (index) => _FullscreenHeartParticle(_random));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        for (var p in particles) {
          p.update();
        }
      });

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _HeartPainter(particles),
        size: Size.infinite,
        isComplex: true,
      ),
    );
  }
}

class _FullscreenHeartParticle {
  double x, y;
  double speed;
  double size;
  double opacity;
  double angle;
  double spinSpeed;
  final Random rnd;

  _FullscreenHeartParticle(this.rnd)
      : x = rnd.nextDouble(),
        y = rnd.nextDouble(),
        speed = 0.001 + rnd.nextDouble() * 0.002,
        size = 8 + rnd.nextDouble() * 12,
        opacity = 0.1 + rnd.nextDouble() * 0.3,
        angle = rnd.nextDouble() * pi * 2,
        spinSpeed = (rnd.nextDouble() - 0.5) * 0.05;

  void update() {
    y += speed;
    angle += spinSpeed;
    if (y > 1.2) {
      y = -0.1;
      x = rnd.nextDouble();
      speed = 0.001 + rnd.nextDouble() * 0.002;
    }
  }
}

class _HeartPainter extends CustomPainter {
  final List<_FullscreenHeartParticle> particles;

  _HeartPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      final dx = p.x * size.width;
      final dy = p.y * size.height;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.angle);

      final path = Path();
      final w = p.size;
      final h = p.size;
      path.moveTo(0, h * 0.25);
      path.cubicTo(w * 0.5, -h * 0.25, w, h * 0.25, 0, h);
      path.cubicTo(-w, h * 0.25, -w * 0.5, -h * 0.25, 0, h * 0.25);

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
