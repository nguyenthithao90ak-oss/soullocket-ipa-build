import 'widget_sleep_event_preview.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/sl_theme.dart';
import 'widget_theme_surface.dart';
import '../../../../../models/widget_appearance.dart';

class WidgetStickerArtwork extends StatelessWidget {
  const WidgetStickerArtwork({
    super.key,
    required this.stickerKey,
    this.twinkle = false,
  });
  final String stickerKey;
  final bool twinkle;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/widget_stickers/$stickerKey${twinkle ? '_twinkle' : ''}.svg',
    fit: BoxFit.contain,
  );
}

/// Tỉ lệ thiết kế giống ba RemoteViews Android, không phóng chữ theo kích thước màn hình.
class WidgetCouplePreview extends StatelessWidget {
  const WidgetCouplePreview({
    super.key,
    required this.sizeKey,
    required this.colors,
    required this.textColor,
    required this.daysColor,
    required this.heading,
    required this.days,
    required this.unit,
    required this.name1,
    required this.name2,
    required this.avatar1,
    required this.avatar2,
    required this.center,
    this.countdown = false,
    this.loveDate = '',
    this.dark = false,
    this.backgroundOverlay,
    this.themeKey = 'pink',
    this.themeAnimated = false,
    this.footer,
  });
  final String sizeKey,
      heading,
      days,
      unit,
      name1,
      name2,
      avatar1,
      avatar2,
      loveDate;
  final List<Color> colors;
  final Color textColor, daysColor;
  final Widget center;
  final bool countdown, dark;
  final Widget? backgroundOverlay, footer;
  final String themeKey;
  final bool themeAnimated;

  @override
  Widget build(BuildContext context) {
    final compact = sizeKey == 'small';
    final large = sizeKey == 'large';
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final width = ios
        ? (compact ? 155.0 : 329.0)
        : compact
        ? 140.0
        : large
        ? 320.0
        : 220.0;
    final height = ios
        ? (large ? 345.0 : 155.0)
        : compact
        ? 120.0
        : large
        ? 240.0
        : 160.0;
    final centerSize = compact
        ? 28.0
        : large
        ? 72.0
        : 44.0;
    final counterHeight = ios
        ? (compact
              ? 28.0
              : large
              ? 46.0
              : 28.0)
        : compact
        ? 36.0
        : large
        ? 56.0
        : 40.0;
    final nameHeight = ios
        ? (countdown
              ? 0.0
              : large
              ? 18.0
              : 14.0)
        : compact
        ? 15.0
        : large
        ? 23.0
        : 18.0;
    final headingHeight = !ios && !countdown && large ? 17.0 : 0.0;
    final dateHeight = countdown && (!compact || ios) && loveDate.isNotEmpty
        ? (ios ? (large ? 16.0 : 12.0) : 19.0)
        : 0.0;
    // Avatar gấp đôi mẫu cũ; chỉ co lại nếu ô nhỏ không đủ bề rộng/chiều cao.
    final avatarSize = ios
        ? math.min(
            compact
                ? 64.0
                : large
                ? 132.0
                : 96.0,
            math.min(
              (width -
                      (large ? 24 : 16) -
                      centerSize -
                      (large
                          ? 16
                          : compact
                          ? 12
                          : 8)) /
                  2,
              height -
                  (large ? 24 : 16) -
                  counterHeight -
                  nameHeight -
                  (countdown ? 0 : 3) -
                  (large
                      ? 32
                      : compact
                      ? 12
                      : 8) -
                  (dateHeight > 0
                      ? (large
                            ? 8
                            : compact
                            ? 6
                            : 4)
                      : 0) -
                  dateHeight -
                  (large ? 92 : 0),
            ),
          )
        : math.min(
            compact
                ? 64.0
                : large
                ? 116.0
                : 80.0,
            math.min(
              (width - 16 - centerSize) / 2,
              height -
                  12 -
                  counterHeight -
                  (countdown ? dateHeight : nameHeight + headingHeight + 7),
            ),
          );
    Widget fitted(String value, double sp, Color color) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        value,
        maxLines: 1,
        style: SLTheme.quicksand(
          fontSize: sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
    Widget avatar(String url, bool warm) => Container(
      key: ValueKey(warm ? 'couple-avatar-1' : 'couple-avatar-2'),
      width: avatarSize,
      height: avatarSize,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .65),
        border: Border.all(color: Colors.white),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? SvgPicture.asset(
                "assets/images/widget_stickers/avatar_${warm ? 'warm' : 'cream'}.svg",
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => SvgPicture.asset(
                  "assets/images/widget_stickers/avatar_${warm ? 'warm' : 'cream'}.svg",
                ),
              ),
      ),
    );
    Widget person(String url, String name, bool warm) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar(url, warm),
          SizedBox(height: ios ? 3 : 2),
          SizedBox(
            height: nameHeight,
            child: fitted(
              name,
              compact
                  ? 10
                  : large
                  ? 14
                  : 12,
              textColor,
            ),
          ),
        ],
      ),
    );
    final visual = SizedBox(
      key: const ValueKey('couple-center-artwork'),
      width: centerSize,
      height: centerSize,
      child: center,
    );
    final counter = Container(
      height: counterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: (dark ? Colors.black : Colors.white).withValues(alpha: .42),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: fitted(
                days,
                compact
                    ? 26
                    : large
                    ? 42
                    : 32,
                daysColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: fitted(
                unit,
                compact
                    ? 10
                    : large
                    ? 14
                    : 12,
                daysColor,
              ),
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : width;
        final displayWidth = math.min(
          available,
          compact
              ? 180.0
              : large
              ? 420.0
              : 340.0,
        );
        return SizedBox(
          width: displayWidth,
          height: displayWidth * height / width,
          child: FittedBox(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: SizedBox(
                width: width,
                height: height,
                child: WidgetThemeSurface(
                  themeKey: themeKey,
                  colors: colors,
                  animated: themeAnimated,
                  child: Stack(
                    children: [
                      Padding(
                        padding: ios
                            ? EdgeInsets.all(large ? 12 : 8)
                            : const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                        child: Column(
                          mainAxisAlignment: ios
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            if (!ios && !countdown && large) ...[
                              SizedBox(
                                height: 15,
                                child: fitted(heading, 10, textColor),
                              ),
                              const SizedBox(height: 2),
                            ],
                            if (ios || !countdown) counter,
                            if (ios || !countdown)
                              SizedBox(
                                height: ios
                                    ? (large
                                          ? 8
                                          : compact
                                          ? 6
                                          : 4)
                                    : 5,
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: countdown
                                  ? [
                                      Expanded(
                                        child: Center(
                                          child: avatar(avatar1, true),
                                        ),
                                      ),
                                      visual,
                                      Expanded(
                                        child: Center(
                                          child: avatar(avatar2, false),
                                        ),
                                      ),
                                    ]
                                  : [
                                      person(avatar1, name1, true),
                                      visual,
                                      person(avatar2, name2, false),
                                    ],
                            ),
                            if (countdown && !ios) counter,
                            if (countdown &&
                                (!compact || ios) &&
                                loveDate.isNotEmpty) ...[
                              SizedBox(
                                height: ios
                                    ? (large
                                          ? 8
                                          : compact
                                          ? 6
                                          : 4)
                                    : 2,
                              ),
                              SizedBox(
                                height: ios ? dateHeight : 17,
                                child: fitted(loveDate, 11, textColor),
                              ),
                            ],
                            if (ios && large) ...[
                              const Spacer(),
                              SizedBox(height: 92, child: footer),
                            ],
                            if (ios) const Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cùng đường cong với diaryFramePath của Android.
class WidgetHeartPhotoClipper extends CustomClipper<Path> {
  const WidgetHeartPhotoClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .5, s.height * .23)
    ..cubicTo(
      -s.width * .08,
      -s.height * .22,
      -s.width * .16,
      s.height * .48,
      s.width * .5,
      s.height * .97,
    )
    ..cubicTo(
      s.width * 1.16,
      s.height * .48,
      s.width * 1.08,
      -s.height * .22,
      s.width * .5,
      s.height * .23,
    )
    ..close();
  @override
  bool shouldReclip(WidgetHeartPhotoClipper oldClipper) => false;
}

class WidgetHeartArtwork extends StatelessWidget {
  const WidgetHeartArtwork({
    super.key,
    required this.styleKey,
    this.animated = false,
    this.phase = 0,
  });
  final String styleKey;
  final bool animated;
  final int phase;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = math.min(constraints.maxWidth, constraints.maxHeight);
      final motion = animated && !MediaQuery.disableAnimationsOf(context);
      final scale = motion && phase.isOdd ? 1.04 : 1.0;
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: SizedBox.square(
                dimension: size * .82,
                child: SvgPicture.asset(
                  'assets/images/widget_stickers/heart_${WidgetAppearance.heartArtworkKey(styleKey)}.svg',
                  key: ValueKey('heart-art-$styleKey'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class WidgetVisualChoiceTile extends StatelessWidget {
  const WidgetVisualChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.artwork,
    this.showLabel = true,
  });
  final String label;
  final bool selected, showLabel;
  final VoidCallback onTap;
  final Widget artwork;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? const Color(0xFFFFF0F4) : const Color(0xFFFAF8FB),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC44B74)
                  : const Color(0xFFEDE7EE),
              width: 1.6,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: showLabel ? 64 : 40, child: artwork),
                    if (showLabel) ...[
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? const Color(0xFF9C3359)
                              : const Color(0xFF655B70),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 5,
                  right: 5,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFFC44B74),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Tỷ lệ tham khảo iPhone; kích thước cuối cùng do WidgetKit cấp.
class WidgetIOSEventPreview extends StatelessWidget {
  const WidgetIOSEventPreview({
    super.key,
    required this.sizeKey,
    required this.heading,
    required this.title,
    required this.days,
    required this.label,
    required this.date,
    required this.accent,
    this.themeKey = 'pink',
    this.animated = false,
  });
  final String sizeKey, heading, title, days, label, date;
  final Color accent;
  final String themeKey;
  final bool animated;
  @override
  Widget build(BuildContext context) {
    return WidgetSleepEventPreview(
      sizeKey: sizeKey,
      heading: heading,
      title: title,
      days: days,
      label: label,
      date: date,
      accent: accent,
      themeKey: themeKey,
      animated: animated,
      hasEvent: date != '--/--/----',
    );
  }
}
