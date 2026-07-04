part of '../../love_card_screen.dart';

final Expando<
    ({
      String houseId,
      Stream<List<Map<dynamic, dynamic>>> stream,
    })> _loveCardCardsStreamCache = Expando<
    ({
      String houseId,
      Stream<List<Map<dynamic, dynamic>>> stream,
    })>('love_card_cards_stream');

extension _LoveCardSharedCardsStream on _LoveCardScreenState {
  Stream<List<Map<dynamic, dynamic>>> get _cardsStream {
    final normalizedHouseId = widget.houseId.trim();
    final cached = _loveCardCardsStreamCache[this];
    if (cached != null && cached.houseId == normalizedHouseId) {
      return cached.stream;
    }

    final stream = _svc.listenToCards(normalizedHouseId).asBroadcastStream();
    _loveCardCardsStreamCache[this] = (
      houseId: normalizedHouseId,
      stream: stream,
    );
    return stream;
  }
}

class _LoveCardScreenBody extends StatelessWidget {
  final _LoveCardScreenState state;

  const _LoveCardScreenBody({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = state._themeOf(state._selectedTheme);
    final colors = state._themeColors(theme.key);
    final bottomColor = colors.last;

    return Scaffold(
      backgroundColor: bottomColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -90,
              right: -40,
              child: _LoveCardBackgroundOrb(
                size: 240,
                opacity: 0.10,
                type: _LoveCardOrbType.cloud,
              ),
            ),
            const Positioned(
              left: -70,
              bottom: -110,
              child: _LoveCardBackgroundOrb(
                size: 280,
                opacity: 0.06,
                type: _LoveCardOrbType.heart,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _LoveCardThemeBackdrop(
                    theme: theme,
                    colors: colors,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: state._hideTopChrome
                          ? const SizedBox.shrink()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _LoveCardHeaderSection(
                                  state: state,
                                  theme: theme,
                                  colors: colors,
                                ),
                                _LoveCardTabSwitcher(
                                  state: state,
                                  theme: theme,
                                ),
                              ],
                            ),
                    ),
                  ),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: state._handleScrollNotification,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: KeyedSubtree(
                          key: ValueKey(state._currentIndex),
                          child: state._currentIndex == 0
                              ? _LoveCardCreateView(state: state)
                              : _LoveCardHistoryView(state: state),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoveCardHeaderSection extends StatelessWidget {
  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Love Card (Thẻ tình yêu)',
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tính năng:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Bộ sưu tập thẻ bài tương tác vui nhộn dùng để "phạt" hoặc "thưởng" người ấy.\n- Bao gồm nhiều cấp độ hiếm (Common, Rare, Epic, Legendary).'),
              SizedBox(height: 12),
              Text('Cách sử dụng:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  '- Bốc thẻ hàng ngày để sưu tập.\n- Chọn một thẻ và bấm Dùng để bắt người ấy thực hiện một hành động (ví dụ: Massage 10 phút, Cấm giận dỗi 1 ngày).\n- Thẻ đã dùng sẽ vào lịch sử và bị tiêu hao.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu',
                style: TextStyle(color: SLColors.primary)),
          ),
        ],
      ),
    );
  }

  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardHeaderSection({
    required this.state,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          _LoveCardRoundButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          _LoveCardRoundButton(
            icon: Icons.info_outline_rounded,
            onTap: () => _showInfoDialog(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Text(
                  context.tr('util_thiptnhyu_4d90ec'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('util_tophnchias_649b8a'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.34),
                  Colors.white.withValues(alpha: 0.14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Icon(theme.icon, color: colors.first, size: 20),
          ),
        ],
      ),
    );
  }
}

class _LoveCardTabSwitcher extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;

  const _LoveCardTabSwitcher({
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTextColor = Color(theme.colors.first);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LoveCardTabButton(
              label: context.tr('util_tothip_b2b416'),
              isActive: state._currentIndex == 0,
              activeTextColor: selectedTextColor,
              onTap: state._showCreateTab,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<dynamic, dynamic>>>(
              stream: state._cardsStream,
              initialData: const <Map<dynamic, dynamic>>[],
              builder: (context, snapshot) {
                final unreadCount =
                    snapshot.hasData ? state._unreadCount(snapshot.data!) : 0;

                return _LoveCardTabButton(
                  label: context.tr('util_lchs_3061f5'),
                  isActive: state._currentIndex == 1,
                  activeTextColor: selectedTextColor,
                  unreadCount: unreadCount,
                  onTap: state._showHistoryTab,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardTabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeTextColor;
  final VoidCallback onTap;
  final int unreadCount;

  const _LoveCardTabButton({
    required this.label,
    required this.isActive,
    required this.activeTextColor,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    color: isActive ? activeTextColor : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? activeTextColor : Colors.redAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _LoveCardOrbType { circle, heart, cloud }

class _CuteHeartPainter extends CustomPainter {
  final Color color;
  const _CuteHeartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.5, h * 0.28);
    path.cubicTo(w * 0.2, h * -0.08, w * -0.12, h * 0.36, w * 0.5, h * 0.9);
    path.cubicTo(w * 1.12, h * 0.36, w * 0.8, h * -0.08, w * 0.5, h * 0.28);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CuteCloudPainter extends CustomPainter {
  final Color color;
  const _CuteCloudPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.25, h * 0.75);
    path.cubicTo(w * 0.05, h * 0.75, w * 0.05, h * 0.45, w * 0.2, h * 0.4);
    path.cubicTo(w * 0.2, h * 0.15, w * 0.55, h * 0.1, w * 0.65, h * 0.3);
    path.cubicTo(w * 0.85, h * 0.25, w * 0.95, h * 0.45, w * 0.85, h * 0.65);
    path.cubicTo(w * 0.9, h * 0.8, w * 0.7, h * 0.8, w * 0.6, h * 0.75);
    path.cubicTo(w * 0.5, h * 0.85, w * 0.35, h * 0.85, w * 0.25, h * 0.75);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CuteSparklePainter extends CustomPainter {
  final Color color;
  const _CuteSparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    path.moveTo(cx, 0);
    path.quadraticBezierTo(cx, cy, w, cy);
    path.quadraticBezierTo(cx, cy, cx, h);
    path.quadraticBezierTo(cx, cy, 0, cy);
    path.quadraticBezierTo(cx, cy, cx, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoveCardBackgroundOrb extends StatelessWidget {
  final double size;
  final double opacity;
  final _LoveCardOrbType type;

  const _LoveCardBackgroundOrb({
    required this.size,
    required this.opacity,
    this.type = _LoveCardOrbType.circle,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: opacity);
    switch (type) {
      case _LoveCardOrbType.heart:
        return CustomPaint(
          size: Size(size, size),
          painter: _CuteHeartPainter(color),
        );
      case _LoveCardOrbType.cloud:
        return CustomPaint(
          size: Size(size, size),
          painter: _CuteCloudPainter(color),
        );
      case _LoveCardOrbType.circle:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        );
    }
  }
}

class _LoveCardBackdropHeartDoodle extends StatelessWidget {
  final double size;
  final Color color;
  final double rotation;

  const _LoveCardBackdropHeartDoodle({
    required this.size,
    required this.color,
    this.rotation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CuteHeartPainter(color),
      ),
    );
  }
}

class _LoveCardBackdropSparkleDoodle extends StatelessWidget {
  final double size;
  final Color color;
  final double rotation;

  const _LoveCardBackdropSparkleDoodle({
    required this.size,
    required this.color,
    this.rotation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CuteSparklePainter(color),
      ),
    );
  }
}

class _LoveCardBackdropCloudDoodle extends StatelessWidget {
  final double size;
  final Color color;
  final double rotation;

  const _LoveCardBackdropCloudDoodle({
    required this.size,
    required this.color,
    this.rotation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CuteCloudPainter(color),
      ),
    );
  }
}

class _LoveCardThemeBackdrop extends StatelessWidget {
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardThemeBackdrop({
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final cutoutColor =
        Color.lerp(colors.last, Colors.black, 0.18) ?? colors.last;

    switch (theme.key) {
      case 'birthday':
        return Stack(
          children: [
            Positioned(
              top: 98,
              right: 26,
              child: _LoveCardBackdropBalloonPair(
                leftColor: Colors.white.withValues(alpha: 0.18),
                rightColor: colors.first.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              top: 244,
              left: 18,
              child: _LoveCardBackdropConfettiCluster(
                color: Colors.white.withValues(alpha: 0.16),
                accent: colors.first.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              bottom: 184,
              right: 28,
              child: _LoveCardBackdropConfettiCluster(
                color: Colors.white.withValues(alpha: 0.10),
                accent: colors.last.withValues(alpha: 0.18),
                mirrored: true,
              ),
            ),
            Positioned(
              top: 180,
              right: 80,
              child: _LoveCardBackdropSparkleDoodle(
                size: 20,
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
          ],
        );
      case 'anniversary':
        return Stack(
          children: [
            Positioned(
              top: 108,
              right: 24,
              child: _LoveCardBackdropRingHalo(
                size: 112,
                color: Colors.white.withValues(alpha: 0.18),
                accent: const Color(0xFFFFD98B).withValues(alpha: 0.34),
              ),
            ),
            Positioned(
              top: 224,
              left: 24,
              child: _LoveCardBackdropSparkleDoodle(
                size: 32,
                color: Colors.white.withValues(alpha: 0.22),
                rotation: 0.1,
              ),
            ),
            Positioned(
              bottom: 160,
              right: 36,
              child: _LoveCardBackdropSparkleDoodle(
                size: 24,
                color: const Color(0xFFFFE3A2).withValues(alpha: 0.4),
                rotation: -0.15,
              ),
            ),
            Positioned(
              bottom: 230,
              left: 36,
              child: _LoveCardBackdropCloudDoodle(
                size: 40,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ],
        );
      case 'miss':
        return Stack(
          children: [
            Positioned(
              top: 86,
              right: 20,
              child: _LoveCardBackdropMoon(
                size: 88,
                color: Colors.white.withValues(alpha: 0.20),
                cutoutColor: cutoutColor,
              ),
            ),
            Positioned(
              top: 218,
              left: 22,
              child: _LoveCardBackdropSparkleDoodle(
                size: 24,
                color: Colors.white.withValues(alpha: 0.22),
                rotation: -0.12,
              ),
            ),
            Positioned(
              bottom: 176,
              right: 34,
              child: _LoveCardBackdropCloudDoodle(
                size: 52,
                color: Colors.white.withValues(alpha: 0.16),
                rotation: 0.16,
              ),
            ),
          ],
        );
      default:
        return Stack(
          children: [
            Positioned(
              top: 92,
              left: 20,
              child: _LoveCardBackdropHeartDoodle(
                size: 36,
                color: Colors.white.withValues(alpha: 0.24),
                rotation: -0.18,
              ),
            ),
            Positioned(
              top: 150,
              right: 26,
              child: _LoveCardBackdropSparkleDoodle(
                size: 28,
                color: Colors.white.withValues(alpha: 0.22),
                rotation: 0.18,
              ),
            ),
            Positioned(
              bottom: 168,
              left: 32,
              child: _LoveCardBackdropHeartDoodle(
                size: 32,
                color: colors.first.withValues(alpha: 0.3),
                rotation: 0.14,
              ),
            ),
            Positioned(
              bottom: 220,
              right: 40,
              child: _LoveCardBackdropSparkleDoodle(
                size: 20,
                color: Colors.white.withValues(alpha: 0.18),
                rotation: -0.1,
              ),
            ),
          ],
        );
    }
  }
}

class _LoveCardBackdropBalloonPair extends StatelessWidget {
  final Color leftColor;
  final Color rightColor;

  const _LoveCardBackdropBalloonPair({
    required this.leftColor,
    required this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 98,
      height: 132,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 12,
            child: _LoveCardBackdropBalloon(
              width: 40,
              height: 50,
              tailHeight: 48,
              color: leftColor,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _LoveCardBackdropBalloon(
              width: 46,
              height: 58,
              tailHeight: 56,
              color: rightColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardBackdropBalloon extends StatelessWidget {
  final double width;
  final double height;
  final double tailHeight;
  final Color color;

  const _LoveCardBackdropBalloon({
    required this.width,
    required this.height,
    required this.tailHeight,
    this.color = const Color(0x33FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: _CuteHeartPainter(color),
        ),
        const SizedBox(height: 2),
        Container(
          width: 1.6,
          height: tailHeight,
          color: color.withValues(alpha: 0.72),
        ),
      ],
    );
  }
}

class _LoveCardBackdropConfettiCluster extends StatelessWidget {
  final Color color;
  final Color accent;
  final bool mirrored;

  const _LoveCardBackdropConfettiCluster({
    required this.color,
    required this.accent,
    this.mirrored = false,
  });

  @override
  Widget build(BuildContext context) {
    final rotation = mirrored ? -1.0 : 1.0;

    return SizedBox(
      width: 112,
      height: 72,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 20,
            child: Transform.rotate(
              angle: 0.34 * rotation,
              child: _LoveCardBackdropConfettiBar(
                width: 20,
                height: 6,
                color: color,
              ),
            ),
          ),
          Positioned(
            left: 34,
            top: 4,
            child: Transform.rotate(
              angle: -0.42 * rotation,
              child: _LoveCardBackdropConfettiBar(
                width: 12,
                height: 12,
                color: accent,
                isRound: true,
              ),
            ),
          ),
          Positioned(
            left: 58,
            top: 24,
            child: Transform.rotate(
              angle: 0.24 * rotation,
              child: _LoveCardBackdropConfettiBar(
                width: 22,
                height: 5,
                color: accent,
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 10,
            child: Transform.rotate(
              angle: -0.64 * rotation,
              child: _LoveCardBackdropConfettiBar(
                width: 10,
                height: 10,
                color: color,
                isRound: true,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 10,
            child: Transform.rotate(
              angle: 0.54 * rotation,
              child: _LoveCardBackdropConfettiBar(
                width: 18,
                height: 5,
                color: color,
              ),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.22 * rotation,
              child: _LoveCardBackdropConfettiBar(
                width: 26,
                height: 6,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardBackdropConfettiBar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final bool isRound;

  const _LoveCardBackdropConfettiBar({
    required this.width,
    required this.height,
    required this.color,
    this.isRound = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isRound ? width : 999),
      ),
    );
  }
}

class _LoveCardBackdropRingHalo extends StatelessWidget {
  final double size;
  final Color color;
  final Color accent;

  const _LoveCardBackdropRingHalo({
    required this.size,
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1.6),
            ),
          ),
          Icon(
            Icons.auto_awesome_rounded,
            color: accent,
            size: size * 0.22,
          ),
        ],
      ),
    );
  }
}

class _LoveCardBackdropMoon extends StatelessWidget {
  final double size;
  final Color color;
  final Color cutoutColor;

  const _LoveCardBackdropMoon({
    required this.size,
    required this.color,
    required this.cutoutColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          Positioned(
            right: size * 0.06,
            top: size * 0.08,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cutoutColor,
              ),
            ),
          ),
          Positioned(
            bottom: -4,
            left: -8,
            child: CustomPaint(
              size: Size(size * 0.8, size * 0.5),
              painter: _CuteCloudPainter(Colors.white.withValues(alpha: 0.28)),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Icon(
              Icons.star_rounded,
              size: size * 0.16,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _LoveCardRoundButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _LoveCardGlassIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _LoveCardGlassIcon({
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}

class _LoveCardStatusPill extends StatelessWidget {
  final String label;
  final Color background;

  const _LoveCardStatusPill({
    required this.label,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoveCardHistoryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _LoveCardHistoryMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
