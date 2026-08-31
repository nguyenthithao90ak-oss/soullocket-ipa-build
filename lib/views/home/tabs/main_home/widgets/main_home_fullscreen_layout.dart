part of '../../main_home_tab.dart';

/// Giao diện Home toàn màn hình — giống ảnh mẫu "Bênh Nhauu"
/// Hiển thị khi [UiPrefs.notifier.value.homeLayoutKey] == 'fullscreen'
class _FullscreenHomeBody extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String houseName;
  final bool showHouseName;
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
    required this.showHouseName,
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
    final viewSize = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final compactWidth = viewSize.width < 360;
    final compactHeight = viewSize.height < 720;
    final heartWidth = min(
      330.0,
      max(246.0, viewSize.width - (compactWidth ? 24 : 42)),
    );
    final heartHeight = heartWidth * 0.91;
    final avatarSize = compactHeight ? 66.0 : 78.0;
    final topLabel = circleTopLabel.trim().isNotEmpty
        ? circleTopLabel.trim()
        : context.tr('Bên nhau');
    final bottomLabel = circleBottomLabel.trim().isNotEmpty
        ? circleBottomLabel.trim()
        : context.tr('ngày yêu');
    final quote = context.tr('Mỗi ngày bên nhau là một trang đáng nhớ');

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _FullscreenPhotoVignette()),
          const Positioned.fill(
            child: IgnorePointer(child: _FullscreenFallingHeartsOverlay()),
          ),
          Positioned.fill(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compactWidth ? 12 : 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(height: topPad + 62),
                        _FullscreenLoveLetterhead(
                          houseName: houseName,
                          showHouseName: showHouseName,
                          isSingle: isSingle,
                          maxWidth: min(viewSize.width - 76.0, 310.0),
                        ),
                        SizedBox(height: compactHeight ? 6 : 12),
                        Expanded(
                          child: Center(
                            child: Semantics(
                              button: true,
                              label: context.tr('Chỉnh ngày bắt đầu'),
                              child: GestureDetector(
                                onTap: state._showEditStartDateDialog,
                                onLongPressStart:
                                    state._handleInteractionLongPressStart,
                                onLongPressMoveUpdate:
                                    state._handleInteractionLongPressMoveUpdate,
                                onLongPressEnd:
                                    state._handleInteractionLongPressEnd,
                                onLongPressCancel:
                                    state._handleInteractionLongPressCancel,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: heartWidth,
                                    height: heartHeight,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: const _NeonHeartPainter(),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: heartHeight * 0.08,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Semantics(
                                                button: true,
                                                label: context.tr(
                                                  'Chỉnh tiêu đề đếm ngày',
                                                ),
                                                child: GestureDetector(
                                                  onTap: () => state
                                                      ._showEditCountdownLabelDialog(
                                                        editTopLabel: true,
                                                        currentLabel:
                                                            circleTopLabel,
                                                      ),
                                                  child: SizedBox(
                                                    width: heartWidth * 0.70,
                                                    child: Text(
                                                      topLabel,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          GoogleFonts.dancingScript(
                                                            fontSize:
                                                                compactWidth
                                                                ? 27
                                                                : 31,
                                                            height: 1.05,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                            shadows: const [
                                                              Shadow(
                                                                color: Colors
                                                                    .black54,
                                                                blurRadius: 10,
                                                                offset: Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                width: heartWidth * 0.58,
                                                height: heartHeight * 0.34,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: ShaderMask(
                                                    shaderCallback: (bounds) =>
                                                        const LinearGradient(
                                                          colors: [
                                                            Colors.white,
                                                            Color(0xFFFFD7E1),
                                                            Colors.white,
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ).createShader(bounds),
                                                    child: Text(
                                                      circleValue,
                                                      style: SLTheme.quicksand(
                                                        fontSize: 106,
                                                        height: 0.92,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.white,
                                                        shadows: const [
                                                          Shadow(
                                                            color:
                                                                Colors.black38,
                                                            blurRadius: 14,
                                                            offset: Offset(
                                                              0,
                                                              5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 7),
                                              Semantics(
                                                button: true,
                                                label: context.tr(
                                                  'Chỉnh nhãn đếm ngày',
                                                ),
                                                child: GestureDetector(
                                                  onTap: () => state
                                                      ._showEditCountdownLabelDialog(
                                                        editTopLabel: false,
                                                        currentLabel:
                                                            circleBottomLabel,
                                                      ),
                                                  child: Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth:
                                                          heartWidth * 0.62,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 7,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: SLColors.paper
                                                          .withValues(
                                                            alpha: 0.94,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      border: Border.all(
                                                        color: SLColors.thread
                                                            .withValues(
                                                              alpha: 0.32,
                                                            ),
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.14,
                                                              ),
                                                          blurRadius: 12,
                                                          offset: const Offset(
                                                            0,
                                                            5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .favorite_rounded,
                                                          size: 12,
                                                          color:
                                                              SLColors.thread,
                                                        ),
                                                        const SizedBox(
                                                          width: 7,
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            bottomLabel,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                SLTheme.quicksand(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  letterSpacing:
                                                                      0.45,
                                                                  color: SLColors
                                                                      .thread,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
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
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 2 : 8),
                        _FullscreenCoupleRibbon(
                          state: state,
                          isSingle: isSingle,
                          nameU1: nameU1,
                          nameU2: nameU2,
                          avtUser1: avtUser1,
                          avtUser2: avtUser2,
                          avatarSize: avatarSize,
                        ),
                        SizedBox(height: compactHeight ? 6 : 12),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: bottomPad + (compactHeight ? 12 : 22),
                          ),
                          child: Transform.rotate(
                            angle: 0.012,
                            child: SizedBox(
                              width: min(viewSize.width - 44.0, 340.0),
                              child: _HomeScrapbookCard(
                                accentColor: SLColors.thread,
                                color: SLColors.paper.withValues(alpha: 0.94),
                                radius: 18,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.auto_stories_rounded,
                                      size: 16,
                                      color: SLColors.thread,
                                    ),
                                    const SizedBox(width: 9),
                                    Flexible(
                                      child: Text(
                                        quote,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dancingScript(
                                          fontSize: 18,
                                          height: 1.05,
                                          fontWeight: FontWeight.w700,
                                          color: SLColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topPad + 4,
            left: 14,
            child: Transform.rotate(
              angle: -0.07,
              child: Container(
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: SLColors.paper,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: SLColors.thread, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/icons/cute_3d/avatar_puppy_heart.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.pets_rounded,
                    color: SLColors.thread,
                    size: 24,
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

class _FullscreenPhotoVignette extends StatelessWidget {
  const _FullscreenPhotoVignette();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.34, 0.66, 1],
          colors: [
            Colors.black.withValues(alpha: 0.34),
            const Color(0xFF4A1730).withValues(alpha: 0.08),
            Colors.transparent,
            const Color(0xFF140A10).withValues(alpha: 0.76),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.08),
            radius: 0.92,
            colors: [
              SLColors.primary.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenLoveLetterhead extends StatelessWidget {
  final String houseName;
  final bool showHouseName;
  final bool isSingle;
  final double maxWidth;

  const _FullscreenLoveLetterhead({
    required this.houseName,
    required this.showHouseName,
    required this.isSingle,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime.now());
    final visibleHouseName = showHouseName && houseName.trim().isNotEmpty;
    final title = visibleHouseName
        ? houseName.trim()
        : context.tr(isSingle ? 'Nhật ký của mình' : 'Nhật ký tình yêu');

    return Semantics(
      header: true,
      child: Transform.rotate(
        angle: -0.012,
        child: SizedBox(
          width: max(190.0, maxWidth),
          child: _HomeScrapbookCard(
            accentColor: isSingle ? SLColors.secondary : SLColors.thread,
            color: SLColors.paper.withValues(alpha: 0.95),
            adornment: _HomeCardAdornment.washiTape,
            radius: 19,
            padding: const EdgeInsets.fromLTRB(17, 12, 15, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: SLColors.paperBlush,
                    shape: BoxShape.circle,
                    border: Border.all(color: SLColors.borderLight),
                  ),
                  child: Icon(
                    isSingle
                        ? Icons.auto_awesome_rounded
                        : Icons.favorite_rounded,
                    size: 16,
                    color: isSingle ? SLColors.secondary : SLColors.thread,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SOULLOCKET  ·  $dateLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.15,
                          color: SLColors.thread,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dancingScript(
                          fontSize: 22,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenCoupleRibbon extends StatelessWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final double avatarSize;

  const _FullscreenCoupleRibbon({
    required this.state,
    required this.isSingle,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
    required this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: avatarSize + 39,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: avatarSize * 0.74,
            right: avatarSize * 0.74,
            top: avatarSize * 0.34,
            height: 42,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FullscreenCoupleThreadPainter(isSingle: isSingle),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _FullscreenAvatarItem(
                    state: state,
                    name: nameU1,
                    avatarUrl: avtUser1,
                    isUser1: true,
                    size: avatarSize,
                  ),
                ),
              ),
              SizedBox(width: avatarSize * 0.60),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _FullscreenAvatarItem(
                    state: state,
                    name: isSingle ? '' : nameU2,
                    avatarUrl: isSingle ? '' : avtUser2,
                    isUser1: false,
                    size: avatarSize,
                    isSinglePlaceholder: isSingle,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: avatarSize * 0.29,
            child: IgnorePointer(
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: SLColors.paper.withValues(alpha: 0.96),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SLColors.thread.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isSingle
                      ? Icons.auto_awesome_rounded
                      : Icons.favorite_rounded,
                  size: 16,
                  color: isSingle ? SLColors.secondary : SLColors.thread,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenCoupleThreadPainter extends CustomPainter {
  final bool isSingle;

  const _FullscreenCoupleThreadPainter({required this.isSingle});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isSingle ? SLColors.secondary : SLColors.thread;
    final path = Path()
      ..moveTo(0, size.height * 0.46)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.05,
        size.width * 0.68,
        size.height * 0.90,
        size.width,
        size.height * 0.40,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.76)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final metric = path.computeMetrics().first;
    final stitchPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    for (var offset = 8.0; offset < metric.length; offset += 18) {
      final tangent = metric.getTangentForOffset(offset);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 1.7, stitchPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FullscreenCoupleThreadPainter oldDelegate) {
    return oldDelegate.isSingle != isSingle;
  }
}

// -----------------------------------------------------------
// Khung trái tim kiểu mặt dây chuyền, phủ nhẹ trên ảnh nền.
// -----------------------------------------------------------
class _NeonHeartPainter extends CustomPainter {
  const _NeonHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final path = Path()
      ..moveTo(width * 0.50, height * 0.92)
      ..cubicTo(
        width * 0.12,
        height * 0.69,
        width * 0.05,
        height * 0.44,
        width * 0.13,
        height * 0.27,
      )
      ..cubicTo(
        width * 0.22,
        height * 0.08,
        width * 0.41,
        height * 0.11,
        width * 0.50,
        height * 0.29,
      )
      ..cubicTo(
        width * 0.59,
        height * 0.11,
        width * 0.78,
        height * 0.08,
        width * 0.87,
        height * 0.27,
      )
      ..cubicTo(
        width * 0.95,
        height * 0.44,
        width * 0.88,
        height * 0.69,
        width * 0.50,
        height * 0.92,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SLColors.paper.withValues(alpha: 0.21),
            SLColors.primary.withValues(alpha: 0.10),
            SLColors.paperPeach.withValues(alpha: 0.18),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );

    final glowPaint = Paint()
      ..color = SLColors.primary.withValues(alpha: 0.56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(
      path,
      Paint()
        ..color = SLColors.thread.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );

    final metric = path.computeMetrics().first;
    final stitchPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.66)
      ..style = PaintingStyle.fill;
    for (var offset = 10.0; offset < metric.length; offset += 15) {
      final tangent = metric.getTangentForOffset(offset);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 1.35, stitchPaint);
      }
    }

    _drawSmallHeart(canvas, Offset(width * 0.83, height * 0.19), 7);
    _drawSmallHeart(canvas, Offset(width * 0.14, height * 0.55), 5.5);
    canvas.drawCircle(
      Offset(width * 0.79, height * 0.64),
      2.5,
      Paint()
        ..color = SLColors.warningGold.withValues(alpha: 0.88)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawSmallHeart(Canvas canvas, Offset center, double size) {
    final heart = Path()
      ..moveTo(center.dx, center.dy + size * 0.62)
      ..cubicTo(
        center.dx - size * 1.05,
        center.dy - size * 0.08,
        center.dx - size * 0.56,
        center.dy - size * 0.88,
        center.dx,
        center.dy - size * 0.30,
      )
      ..cubicTo(
        center.dx + size * 0.56,
        center.dy - size * 0.88,
        center.dx + size * 1.05,
        center.dy - size * 0.08,
        center.dx,
        center.dy + size * 0.62,
      );
    canvas.drawPath(
      heart,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonHeartPainter oldDelegate) => false;
}

// -----------------------------------------------------------
// Avatar đặt trên dải chỉ đỏ của tấm ảnh kỷ niệm.
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
    return SizedBox(
      width: size + 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SLColors.paper,
              border: Border.all(color: SLColors.paper, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: SLColors.thread.withValues(alpha: 0.42),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: state._buildAvatar(
                name,
                avatarUrl,
                isUser1: isUser1,
                size: size - 6,
                isSinglePlaceholder: isSinglePlaceholder,
                onTap: () => state._changeAvatar(isUser1: isUser1),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            constraints: BoxConstraints(maxWidth: size + 36),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: SLColors.paper.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: SLColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.11),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              name.isNotEmpty ? name : context.tr(isUser1 ? 'Bạn' : 'Người ấy'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: SLColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/*
 * Phần dưới đây giữ nguyên hiệu ứng hạt tim, chỉ cô lập repaint để không làm
 * toàn bộ Home phải dựng lại ở mỗi frame.
 */
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

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..addListener(() {
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
        painter: _HeartPainter(particles, repaint: _controller),
        size: Size.infinite,
        isComplex: true,
        willChange: true,
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

  _HeartPainter(this.particles, {required Listenable repaint})
    : super(repaint: repaint);

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
  bool shouldRepaint(covariant _HeartPainter oldDelegate) {
    return oldDelegate.particles != particles;
  }
}
