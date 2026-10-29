import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../widgets/couple_default_avatar.dart';
import 'home_display_layout.dart';
import 'home_display_style.dart';

/// Hero riêng cho sáu hướng Home trong bản thiết kế.
///
/// Hero chỉ trình bày dữ liệu đã được Home truyền vào. Nó không tạo listener,
/// timer hay truy vấn mới. `leftAvatar`/`rightAvatar` cho phép Home đưa vào
/// renderer avatar đang dùng (giữ frame, upload và cache ảnh ổn định); khi
/// không truyền, widget dùng ảnh mặc định hoặc cache network tối thiểu.
class HomeDisplayHero extends StatelessWidget {
  const HomeDisplayHero({
    super.key,
    required this.style,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
    required this.isSingle,
    this.dayBadge,
    this.onTap,
    this.footer,
    this.leftAvatar,
    this.rightAvatar,
    this.onTapLeftAvatar,
    this.onTapRightAvatar,
    this.onEditLeftName,
    this.onEditRightName,
  });

  final HomeDisplayStyle style;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final bool isSingle;
  final Widget? dayBadge;
  final VoidCallback? onTap;
  final Widget? footer;
  final Widget? leftAvatar;
  final Widget? rightAvatar;
  final VoidCallback? onTapLeftAvatar;
  final VoidCallback? onTapRightAvatar;
  final VoidCallback? onEditLeftName;
  final VoidCallback? onEditRightName;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    final body = switch (style) {
      HomeDisplayStyle.current => _buildCurrent(context, palette),
      HomeDisplayStyle.nest => _buildNest(context, palette),
      HomeDisplayStyle.portrait => _buildPortrait(context, palette),
      HomeDisplayStyle.scrapbook => _buildScrapbook(context, palette),
      HomeDisplayStyle.cloud => _buildCloud(context, palette),
      HomeDisplayStyle.daily => _buildDaily(context, palette),
      HomeDisplayStyle.minimal => _buildMinimal(context, palette),
    };
    return Semantics(
      container: true,
      label: [
        nameU1,
        if (!isSingle) nameU2,
      ].where((e) => e.trim().isNotEmpty).join(' & '),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 360.0;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: width < 340 ? 218 : 240),
            child: body,
          );
        },
      ),
    );
  }

  /// Kiểu mặc định giữ tinh thần SoulLocket: một chiếc huy hiệu tình yêu
  /// tròn, hai avatar ở giữa và ngày yêu được đặt thành điểm nhấn đầu tiên.
  /// Nó tách hẳn khỏi kiểu Tổ ấm vốn dùng vòm nhà lớn.
  Widget _buildCurrent(BuildContext context, HomeDisplayPalette palette) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _card(
      palette: palette,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _currentIcon(
                  palette,
                  Icons.favorite_rounded,
                  background: palette.accent.withValues(alpha: .12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _names(context, palette, size: 24, center: true),
                ),
                _currentIcon(
                  palette,
                  Icons.auto_awesome_rounded,
                  background: palette.accent.withValues(alpha: .09),
                ),
              ],
            ),
            if (dayBadge != null) ...[
              const SizedBox(height: 8),
              dayBadge!,
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 8),
            SizedBox(
              height: 142,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CurrentPainter(
                        accent: palette.accent,
                        dark: dark,
                      ),
                    ),
                  ),
                  _pairAvatars(context, size: 72, overlap: 8),
                  Positioned(
                    top: 2,
                    left: 8,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: palette.accent.withValues(alpha: .55),
                      size: 18,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 10,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: palette.accent.withValues(alpha: .32),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 4), footer!],
          ],
        ),
      ),
    );
  }

  Widget _currentIcon(
    HomeDisplayPalette palette,
    IconData icon, {
    required Color background,
  }) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: background,
      shape: BoxShape.circle,
      border: Border.all(color: palette.accent.withValues(alpha: .18)),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: 18, color: palette.accent),
  );

  Widget _buildNest(BuildContext context, HomeDisplayPalette palette) {
    return _card(
      palette: palette,
      radius: 25,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _names(context, palette, size: 27),
            const SizedBox(height: 3),
            SizedBox(
              height: 156,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _NestPainter(
                        accent: palette.accent,
                        dark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  ),
                  _pairAvatars(context, size: 78, overlap: 9),
                  Positioned(
                    top: 6,
                    right: 0,
                    child: _Sparkle(color: palette.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (dayBadge != null) ...[dayBadge!],
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, HomeDisplayPalette palette) {
    return _card(
      palette: palette,
      radius: 25,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: SizedBox(
                height: MediaQuery.textScalerOf(
                  context,
                ).scale(335).clamp(335, 560),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PortraitPainter(
                          accent: palette.accent,
                          dark: Theme.of(context).brightness == Brightness.dark,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.topStart,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  // Cho badge dùng hết chiều ngang còn lại để
                                  // ba nhãn lớn không bị bẻ dòng sớm.
                                  maxWidth: double.infinity,
                                ),
                                child: dayBadge ?? const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Center(
                                child: _pairAvatars(
                                  context,
                                  size: 112,
                                  overlap: 13,
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: _HeroBottomText(
                                palette: palette,
                                first: nameU1,
                                second: nameU2,
                                single: isSingle,
                                editFirst: onEditLeftName,
                                editSecond: onEditRightName,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrapbook(BuildContext context, HomeDisplayPalette palette) {
    return _card(
      palette: palette,
      radius: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 15, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _names(context, palette, size: 14, compact: true),
            const SizedBox(height: 6),
            SizedBox(
              height: 231,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = isSingle
                      ? (constraints.maxWidth * .72).clamp(170.0, 235.0)
                      : (constraints.maxWidth * .54).clamp(140.0, 205.0);
                  final cards = <Widget>[
                    Positioned(
                      left: isSingle ? (constraints.maxWidth - width) / 2 : 2,
                      top: isSingle ? 20 : 8,
                      height: 190,
                      width: width,
                      child: _Polaroid(
                        angle: isSingle ? 0 : -.12,
                        palette: palette,
                        avatar: _avatar(context, true, 115),
                        caption: nameU1,
                      ),
                    ),
                    if (!isSingle)
                      Positioned(
                        right: 2,
                        top: 40,
                        height: 190,
                        width: width,
                        child: _Polaroid(
                          angle: .087,
                          palette: palette,
                          avatar: _avatar(context, false, 115),
                          caption: nameU2,
                        ),
                      ),
                  ];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ...cards,
                      Positioned(
                        top: 0,
                        left: constraints.maxWidth * .23,
                        child: Transform.rotate(
                          angle: -.105,
                          child: Container(
                            width: 70,
                            height: 23,
                            color: palette.accent.withValues(alpha: .25),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: 4,
                        start: 6,
                        child: _Stamp(palette: palette),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (dayBadge != null) ...[const SizedBox(height: 6), dayBadge!],
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }

  Widget _buildCloud(BuildContext context, HomeDisplayPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(70)),
          child: SizedBox(
            height: MediaQuery.textScalerOf(context).scale(264).clamp(264, 400),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CloudPainter(
                      accent: palette.accent,
                      dark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 15,
                  start: 0,
                  end: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _names(context, palette, size: 17, center: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 44),
                  child: _pairAvatars(context, size: 82, overlap: 10),
                ),
              ],
            ),
          ),
        ),
        if (dayBadge != null) ...[const SizedBox(height: 8), dayBadge!],
        if (footer != null) ...[const SizedBox(height: 8), footer!],
      ],
    );
  }

  Widget _buildDaily(BuildContext context, HomeDisplayPalette palette) {
    return _card(
      palette: palette,
      radius: 20,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DailyHeroPainter(
                accent: palette.accent,
                dark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _pairAvatars(context, size: 34, overlap: 7),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _names(context, palette, size: 11, compact: true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (dayBadge != null) ...[dayBadge!],
                if (footer != null) ...[const SizedBox(height: 8), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimal(BuildContext context, HomeDisplayPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 9, 17, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _pairAvatars(context, size: 48, overlap: 8)),
          const SizedBox(height: 12),
          Center(child: _names(context, palette, size: 23, center: true)),
          const SizedBox(height: 10),
          if (dayBadge != null) Center(child: dayBadge!),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }

  Widget _card({
    required HomeDisplayPalette palette,
    required double radius,
    required Widget child,
  }) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: palette.accent.withValues(alpha: .16)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _pairAvatars(
    BuildContext context, {
    required double size,
    required double overlap,
  }) {
    final defaultPair =
        leftAvatar == null &&
        rightAvatar == null &&
        avtUser1.trim().isEmpty &&
        (isSingle || avtUser2.trim().isEmpty);
    if (defaultPair) {
      final sceneSize = size < 48 ? 43.0 : size;
      return _DuoScene(
        width: sceneSize * 2.25,
        height: sceneSize * 1.68,
        single: isSingle,
        accent: HomeDisplayPalette.of(context, style).accent,
        onTapLeft: onTapLeftAvatar,
        onTapRight: onTapRightAvatar,
        nameLeft: nameU1,
        nameRight: nameU2,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _avatar(context, true, size),
        if (!isSingle)
          Transform.translate(
            offset: Offset(-overlap, 0),
            child: _avatar(context, false, size),
          ),
      ],
    );
  }

  Widget _avatar(BuildContext context, bool first, double size) {
    final supplied = first ? leftAvatar : rightAvatar;
    final url = first ? avtUser1 : avtUser2;
    final name = first ? nameU1 : nameU2;
    final fallback =
        supplied ?? _FallbackAvatar(url: url, female: !first, name: name);
    final wrapped = SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: supplied == null
            ? fallback
            : FittedBox(fit: BoxFit.cover, child: fallback),
      ),
    );
    final callback = first ? onEditLeftName : onEditRightName;
    final avatarTap = first ? onTapLeftAvatar : onTapRightAvatar;
    return GestureDetector(
      key: ValueKey<String>(
        first ? 'home-display-avatar-left' : 'home-display-avatar-right',
      ),
      behavior: HitTestBehavior.opaque,
      onTap: avatarTap,
      onLongPress: callback,
      child: Semantics(
        button: avatarTap != null || callback != null,
        label: name,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(widthFactor: 1, heightFactor: 1, child: wrapped),
        ),
      ),
    );
  }

  Widget _names(
    BuildContext context,
    HomeDisplayPalette palette, {
    double size = 23,
    bool compact = false,
    bool center = false,
  }) {
    final first = _editableName(
      context,
      nameU1,
      palette,
      size: size,
      callback: onEditLeftName,
      first: true,
    );
    if (isSingle || nameU2.trim().isEmpty) {
      return Align(
        alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
        child: first,
      );
    }
    return Align(
      alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Flexible(child: first),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Icon(
              Icons.favorite_border_rounded,
              color: palette.accent,
              size: (size * .65).clamp(14, 20),
            ),
          ),
          Flexible(
            child: _editableName(
              context,
              nameU2,
              palette,
              size: size,
              callback: onEditRightName,
              first: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableName(
    BuildContext context,
    String text,
    HomeDisplayPalette palette, {
    required double size,
    VoidCallback? callback,
    required bool first,
  }) {
    return Semantics(
      button: callback != null,
      label: text.trim(),
      child: GestureDetector(
        key: ValueKey<String>(
          first ? 'home-display-name-left' : 'home-display-name-right',
        ),
        behavior: HitTestBehavior.opaque,
        onTap: callback,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Text(
              text.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textWidthBasis: TextWidthBasis.longestLine,
              style: _font(
                'lora',
                color: palette.accent,
                size: size,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _font(
    String key, {
    required Color color,
    required double size,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
  }) => SLTheme.textStyleForKey(
    key,
    color: color,
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: 1.2,
  );
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.url,
    required this.female,
    required this.name,
  });
  final String url;
  final bool female;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return CoupleDefaultAvatar(female: female, animate: false);
    }
    return CachedNetworkImage(
      imageUrl: url.trim(),
      fit: BoxFit.cover,
      memCacheWidth: 384,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) =>
          CoupleDefaultAvatar(female: female, animate: false),
      errorWidget: (_, _, _) =>
          CoupleDefaultAvatar(female: female, animate: false),
    );
  }
}

/// Minh họa Thỏ–Gấu dùng khi người dùng chưa đặt ảnh. Hình này nằm trong
/// hero (không phải avatar mặc định tròn) để các concept giữ được tinh thần
/// cảnh đôi trong mockup; mỗi nửa vẫn có vùng chạm đổi ảnh riêng.
class _DuoScene extends StatelessWidget {
  const _DuoScene({
    required this.width,
    required this.height,
    required this.single,
    required this.accent,
    required this.onTapLeft,
    required this.onTapRight,
    required this.nameLeft,
    required this.nameRight,
  });

  final double width;
  final double height;
  final bool single;
  final Color accent;
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;
  final String nameLeft;
  final String nameRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DuoScenePainter(single: single, accent: accent),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: single ? width : width * .52,
            height: height * .88,
            child: Semantics(
              button: onTapLeft != null,
              label: nameLeft,
              child: GestureDetector(
                key: const ValueKey<String>('home-display-avatar-left'),
                behavior: HitTestBehavior.opaque,
                onTap: onTapLeft,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (!single)
            Positioned(
              right: 0,
              bottom: 0,
              width: width * .52,
              height: height * .88,
              child: Semantics(
                button: onTapRight != null,
                label: nameRight,
                child: GestureDetector(
                  key: const ValueKey<String>('home-display-avatar-right'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapRight,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DuoScenePainter extends CustomPainter {
  const _DuoScenePainter({required this.single, required this.accent});
  final bool single;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 170;
    final sy = size.height / 125;
    canvas.save();
    canvas.scale(sx, sy);
    if (single) canvas.translate(47, 0);
    _animal(
      canvas,
      const Offset(0, 0),
      const Color(0xFFFFF9EF),
      const Color(0xFFEBDAC9),
      bunny: true,
    );
    if (!single) {
      _animal(
        canvas,
        const Offset(76, 0),
        const Color(0xFFC5936B),
        const Color(0xFFF0D2AF),
        bunny: false,
      );
    }
    final heart = Path()
      ..moveTo(single ? 47 : 76, 13)
      ..cubicTo(single ? 34 : 63, 0, single ? 40 : 70, -5, single ? 47 : 76, 4)
      ..cubicTo(single ? 54 : 82, -5, single ? 60 : 89, 0, single ? 47 : 76, 13)
      ..close();
    canvas.drawPath(heart, Paint()..color = accent.withValues(alpha: .8));
    canvas.restore();
  }

  void _animal(
    Canvas canvas,
    Offset origin,
    Color fur,
    Color belly, {
    required bool bunny,
  }) {
    final body = Paint()..color = fur;
    final bellyPaint = Paint()..color = belly.withValues(alpha: .65);
    final face = Paint()..color = const Color(0xFF67473B);
    final ox = origin.dx;
    final oy = origin.dy;
    if (bunny) {
      canvas.drawOval(Rect.fromLTWH(ox + 15, oy - 10, 16, 62), body);
      canvas.drawOval(Rect.fromLTWH(ox + 43, oy - 10, 16, 62), body);
    } else {
      canvas.drawCircle(Offset(ox + 17, oy + 28), 11, body);
      canvas.drawCircle(Offset(ox + 57, oy + 28), 11, body);
      canvas.drawCircle(Offset(ox + 17, oy + 28), 5, bellyPaint);
      canvas.drawCircle(Offset(ox + 57, oy + 28), 5, bellyPaint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + 9, oy + 45, 60, 59),
        const Radius.circular(24),
      ),
      body,
    );
    canvas.drawCircle(Offset(ox + 39, oy + 56), 37, body);
    canvas.drawOval(Rect.fromLTWH(ox + 23, oy + 67, 33, 33), bellyPaint);
    canvas.drawCircle(Offset(ox + 27, oy + 55), 2.3, face);
    canvas.drawCircle(Offset(ox + 52, oy + 55), 2.3, face);
    canvas.drawArc(
      Rect.fromLTWH(ox + 33, oy + 58, 12, 9),
      0,
      math.pi,
      false,
      Paint()
        ..color = face.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(
      Offset(ox + 17, oy + 64),
      5,
      Paint()..color = const Color(0xFFDFA19B).withValues(alpha: .58),
    );
    canvas.drawCircle(
      Offset(ox + 60, oy + 64),
      5,
      Paint()..color = const Color(0xFFDFA19B).withValues(alpha: .58),
    );
  }

  @override
  bool shouldRepaint(covariant _DuoScenePainter oldDelegate) =>
      oldDelegate.single != single || oldDelegate.accent != accent;
}

class _HeroBottomText extends StatelessWidget {
  const _HeroBottomText({
    required this.palette,
    required this.first,
    required this.second,
    required this.single,
    this.editFirst,
    this.editSecond,
  });
  final HomeDisplayPalette palette;
  final String first;
  final String second;
  final bool single;
  final VoidCallback? editFirst;
  final VoidCallback? editSecond;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      Widget name(String text, VoidCallback? edit, bool left) =>
          GestureDetector(
            key: ValueKey<String>(
              left
                  ? 'home-display-name-left-portrait'
                  : 'home-display-name-right-portrait',
            ),
            behavior: HitTestBehavior.opaque,
            onTap: edit,
            child: Semantics(
              button: edit != null,
              label: text,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                  maxWidth: constraints.maxWidth,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1,
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textWidthBasis: TextWidthBasis.longestLine,
                    style: SLTheme.textStyleForKey(
                      'lora',
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
      // Tên dài/chữ lớn tự xuống hàng, không thu nhỏ cỡ chữ hệ thống.
      return Wrap(
        spacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          name(first, editFirst, true),
          if (!single && second.trim().isNotEmpty) ...[
            Icon(
              Icons.favorite_border_rounded,
              color: Color.lerp(palette.accent, Colors.white, .6),
              size: 18,
            ),
            name(second, editSecond, false),
          ],
        ],
      );
    },
  );
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.angle,
    required this.palette,
    required this.avatar,
    required this.caption,
  });
  final double angle;
  final HomeDisplayPalette palette;
  final Widget avatar;
  final String caption;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.accent.withValues(alpha: .18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x124A301A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: palette.background,
                child: Center(child: avatar),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (caption.trim().isEmpty)
            Icon(Icons.favorite_border_rounded, color: palette.accent, size: 16)
          else
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.textStyleForKey(
                'lora',
                color: palette.accent,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    ),
  );
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.palette});
  final HomeDisplayPalette palette;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.23,
    child: Container(
      width: 61,
      height: 61,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.accent, style: BorderStyle.solid),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.favorite_border_rounded,
        color: palette.accent,
        size: 24,
      ),
    ),
  );
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Icon(
    Icons.auto_awesome_rounded,
    color: color.withValues(alpha: .5),
    size: 42,
  );
}

class _CurrentPainter extends CustomPainter {
  const _CurrentPainter({required this.accent, required this.dark});
  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .54);
    final outer = math.min(size.width * .58, size.height * .82);
    final halo = Paint()
      ..color = accent.withValues(alpha: dark ? .12 : .07)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outer * .48, halo);

    final ring = Paint()
      ..color = accent.withValues(alpha: dark ? .48 : .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, outer * .46, ring);
    canvas.drawCircle(center, outer * .36, ring..strokeWidth = .8);

    final dot = Paint()..color = accent.withValues(alpha: .55);
    for (var i = 0; i < 8; i++) {
      final angle = (math.pi * 2 * i) / 8;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * outer * .48;
      canvas.drawCircle(point, i.isEven ? 2.8 : 1.8, dot);
    }

    final heart = Path()
      ..moveTo(center.dx, center.dy + outer * .18)
      ..cubicTo(
        center.dx - outer * .30,
        center.dy - outer * .03,
        center.dx - outer * .16,
        center.dy - outer * .25,
        center.dx,
        center.dy - outer * .10,
      )
      ..cubicTo(
        center.dx + outer * .16,
        center.dy - outer * .25,
        center.dx + outer * .30,
        center.dy - outer * .03,
        center.dx,
        center.dy + outer * .18,
      )
      ..close();
    canvas.drawPath(
      heart,
      Paint()..color = accent.withValues(alpha: dark ? .72 : .48),
    );
  }

  @override
  bool shouldRepaint(covariant _CurrentPainter old) =>
      old.accent != accent || old.dark != dark;
}

class _DailyHeroPainter extends CustomPainter {
  const _DailyHeroPainter({required this.accent, required this.dark});
  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = accent.withValues(alpha: dark ? .34 : .18);
    final lineX = size.width * .13;
    final top = size.height * .18;
    final bottom = size.height * .82;
    canvas.drawLine(
      Offset(lineX, top),
      Offset(lineX, bottom),
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.4,
    );
    for (var i = 0; i < 3; i++) {
      final y = top + (bottom - top) * (i / 2);
      canvas.drawCircle(
        Offset(lineX, y),
        i == 1 ? 5 : 3.5,
        Paint()..color = i == 1 ? accent.withValues(alpha: .68) : lineColor,
      );
    }

    final sparkle = Paint()..color = accent.withValues(alpha: .16);
    canvas.drawCircle(Offset(size.width * .86, size.height * .22), 18, sparkle);
    canvas.drawCircle(Offset(size.width * .92, size.height * .72), 9, sparkle);
  }

  @override
  bool shouldRepaint(covariant _DailyHeroPainter old) =>
      old.accent != accent || old.dark != dark;
}

class _NestPainter extends CustomPainter {
  const _NestPainter({required this.accent, required this.dark});
  final Color accent;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final arch = Paint()
      ..color = (dark ? const Color(0xFF65513F) : const Color(0xFFE9D5BC));
    final rect = Rect.fromLTWH(
      size.width * .21,
      8,
      size.width * .58,
      size.height + 15,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(95),
        topRight: const Radius.circular(95),
      ),
      arch,
    );
    canvas.drawCircle(
      Offset(size.width * .75, 36),
      23,
      Paint()..color = dark ? const Color(0xFFA88A54) : const Color(0xFFF3DFAD),
    );
  }

  @override
  bool shouldRepaint(covariant _NestPainter old) =>
      old.accent != accent || old.dark != dark;
}

class _PortraitPainter extends CustomPainter {
  const _PortraitPainter({required this.accent, required this.dark});
  final Color accent;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF75624F) : const Color(0xFFC7B8A0),
    );
    final windowPaint = Paint()
      ..color = dark ? const Color(0xFF6B796C) : const Color(0xFFC7D3C9);
    final framePaint = Paint()
      ..color = dark ? const Color(0xFFC1A584) : const Color(0xFFEDE3D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final window = Rect.fromLTWH(
      size.width * .34,
      34,
      size.width * .72,
      size.height * .95,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        window,
        topLeft: const Radius.circular(130),
        topRight: const Radius.circular(130),
      ),
      windowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        window,
        topLeft: const Radius.circular(130),
        topRight: const Radius.circular(130),
      ),
      framePaint,
    );
    canvas.drawCircle(
      Offset(size.width * .77, 78),
      39,
      Paint()..color = dark ? const Color(0xFFD6B171) : const Color(0xFFF4D69A),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .34 + window.width * .48, 34, 7, size.height),
      Paint()..color = framePaint.color,
    );
    final overlay = Paint()
      ..shader =
          const LinearGradient(
            colors: [Colors.transparent, Color(0xDD3E302E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(0, size.height * .55, size.width, size.height * .45),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .55, size.width, size.height * .45),
      overlay,
    );
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) =>
      old.accent != accent || old.dark != dark;
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter({required this.accent, required this.dark});
  final Color accent;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF263F3B) : const Color(0xFFDCEEE8),
    );
    final cloud = Paint()
      ..color = dark ? const Color(0x5975938C) : const Color(0xC4FFFFFF);
    canvas.drawOval(const Rect.fromLTWH(-28, 28, 90, 30), cloud);
    canvas.drawCircle(const Offset(12, 48), 25, cloud);
    canvas.drawOval(Rect.fromLTWH(size.width - 56, 72, 90, 30), cloud);
    canvas.drawOval(
      Rect.fromLTWH(size.width * .12, size.height - 58, size.width * .76, 78),
      Paint()..color = dark ? const Color(0xFF718A5A) : const Color(0xFFB5C6A0),
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .12, size.height - 39, size.width * .76, 38),
      Paint()..color = dark ? const Color(0xFF807253) : const Color(0xFFC7B998),
    );
    final houseX = size.width * .66;
    final houseY = size.height - 107;
    final houseFill = Paint()
      ..color = dark ? const Color(0xFF5D7567) : const Color(0xFFE8D9B8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(houseX, houseY + 17, 45, 34),
        const Radius.circular(5),
      ),
      houseFill,
    );
    final roof = Path()
      ..moveTo(houseX - 5, houseY + 18)
      ..lineTo(houseX + 22, houseY - 3)
      ..lineTo(houseX + 50, houseY + 18)
      ..close();
    canvas.drawPath(
      roof,
      Paint()..color = dark ? const Color(0xFF8AA58D) : const Color(0xFF6F9277),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(houseX + 19, houseY + 32, 9, 19),
        const Radius.circular(2),
      ),
      Paint()..color = dark ? const Color(0xFF3E5049) : const Color(0xFFA98262),
    );
    canvas.drawRect(
      Rect.fromLTWH(houseX + 7, houseY + 25, 10, 9),
      Paint()..color = dark ? const Color(0xFFB7D9B8) : const Color(0xFFC4DFD3),
    );
    final plant = Paint()
      ..color = dark ? const Color(0xFFA1BD80) : const Color(0xFF6F9A69);
    canvas.drawLine(
      Offset(houseX - 10, houseY + 50),
      Offset(houseX - 11, houseY + 34),
      plant..strokeWidth = 2,
    );
    canvas.drawOval(Rect.fromLTWH(houseX - 20, houseY + 29, 13, 7), plant);
    canvas.drawOval(Rect.fromLTWH(houseX - 8, houseY + 24, 13, 7), plant);
    final star = Paint()
      ..color = dark ? const Color(0xFFEED99B) : const Color(0xFFB9A46D);
    final c = Offset(size.width - 40, 30);
    canvas.drawCircle(c, 3, star);
    canvas.drawLine(
      c + const Offset(-10, 0),
      c + const Offset(10, 0),
      star..strokeWidth = 1,
    );
    canvas.drawLine(c + const Offset(0, -10), c + const Offset(0, 10), star);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) =>
      old.accent != accent || old.dark != dark;
}
