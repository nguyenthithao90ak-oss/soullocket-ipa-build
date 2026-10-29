import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../utils/services/l10n_service.dart';
import 'home_display_style.dart';

/// Sắp xếp các bề mặt của từng kiểu; không sở hữu dữ liệu hoặc listener.
class HomeDisplayLayout extends StatelessWidget {
  const HomeDisplayLayout({
    super.key,
    required this.style,
    required this.heading,
    required this.note,
    required this.checklist,
    required this.profile,
    required this.countdown,
    required this.compactCountdown,
    required this.reminder,
    required this.pet,
    required this.upcoming,
    required this.bento,
    this.details,
  });

  final HomeDisplayStyle style;
  final Widget heading;
  final Widget note;
  final Widget checklist;
  final Widget profile;
  final Widget countdown;
  final Widget compactCountdown;
  final Widget reminder;
  final Widget pet;
  final Widget upcoming;
  final Widget bento;
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    Widget slot(String id, Widget child) =>
        KeyedSubtree(key: ValueKey('home-style-$id'), child: child);

    final profileSlot = slot('profile', profile);
    final noteSlot = slot('note', note);
    final countdownSlot = slot('countdown', countdown);
    final summarySlot = slot('countdown', compactCountdown);
    final petSlot = slot('pet', pet);
    final upcomingSlot = slot('upcoming', upcoming);
    final bentoSlot = slot('bento', bento);
    final sections = switch (style) {
      HomeDisplayStyle.current => <Widget>[
        noteSlot,
        countdownSlot,
        profileSlot,
        petSlot,
        upcomingSlot,
        bentoSlot,
      ],
      HomeDisplayStyle.nest => <Widget>[
        profileSlot,
        summarySlot,
        noteSlot,
        upcomingSlot,
        bentoSlot,
        petSlot,
      ],
      HomeDisplayStyle.portrait => <Widget>[
        profileSlot,
        noteSlot,
        summarySlot,
        petSlot,
        upcomingSlot,
        bentoSlot,
      ],
      HomeDisplayStyle.scrapbook => <Widget>[
        profileSlot,
        summarySlot,
        noteSlot,
        upcomingSlot,
        petSlot,
        bentoSlot,
      ],
      HomeDisplayStyle.cloud => <Widget>[
        profileSlot,
        summarySlot,
        petSlot,
        noteSlot,
        upcomingSlot,
        bentoSlot,
      ],
      HomeDisplayStyle.daily => <Widget>[
        profileSlot,
        noteSlot,
        upcomingSlot,
        summarySlot,
        bentoSlot,
        petSlot,
      ],
      HomeDisplayStyle.minimal => <Widget>[
        profileSlot,
        summarySlot,
        noteSlot,
        upcomingSlot,
        bentoSlot,
        petSlot,
      ],
    };
    return Column(
      key: ValueKey('home-display-${style.storageKey}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        checklist,
        ..._spaced(sections, style == HomeDisplayStyle.minimal ? 12 : 18),
        if (details != null) ...[
          const SizedBox(height: 16),
          HomeDisplayProfileDetails(child: details!),
        ],
        reminder,
      ],
    );
  }

  List<Widget> _spaced(List<Widget> children, double gap) {
    // Khối đã tắt bằng SizedBox.shrink không để lại hai khoảng cách rỗng.
    final visible = children.where((widget) {
      final child = widget is KeyedSubtree ? widget.child : widget;
      return child is! SizedBox ||
          child.child != null ||
          child.width != 0 ||
          child.height != 0;
    }).toList();
    return [
      for (var i = 0; i < visible.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        visible[i],
      ],
    ];
  }
}

class HomeDisplayPalette {
  const HomeDisplayPalette(this.background, this.surface, this.accent);

  final Color background;
  final Color surface;
  final Color accent;

  static HomeDisplayPalette of(BuildContext context, HomeDisplayStyle style) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (
      background,
      surface,
      accent,
      darkBg,
      darkSurface,
      darkAccent,
    ) = switch (style) {
      HomeDisplayStyle.nest => (
        0xFFFCF8F1,
        0xFFFFFDF9,
        0xFFA35059,
        0xFF211E1C,
        0xFF2D2825,
        0xFFEFB1B2,
      ),
      HomeDisplayStyle.portrait => (
        0xFFEEE5DC,
        0xFFFFFAF4,
        0xFF734A4B,
        0xFF272221,
        0xFF302824,
        0xFFEAB7B9,
      ),
      HomeDisplayStyle.scrapbook => (
        0xFFF3EDDF,
        0xFFFFFDF5,
        0xFF985A49,
        0xFF29251F,
        0xFF373127,
        0xFFE9B49E,
      ),
      HomeDisplayStyle.cloud => (
        0xFFF3F8F5,
        0xFFFFFFFF,
        0xFF527666,
        0xFF1B2625,
        0xFF283632,
        0xFFB7D9B8,
      ),
      HomeDisplayStyle.daily => (
        0xFFF9F5F0,
        0xFFFFFFFF,
        0xFF866078,
        0xFF251F24,
        0xFF342C34,
        0xFFDDBAD0,
      ),
      HomeDisplayStyle.minimal => (
        0xFFFDFCF9,
        0xFFFDFCF9,
        0xFF6A765A,
        0xFF1F2021,
        0xFF1F2021,
        0xFFC8D5B4,
      ),
      HomeDisplayStyle.current => (
        0xFFFFF5F7,
        0xFFFFFBFC,
        0xFFB96070,
        0xFF19191F,
        0xFF292831,
        0xFFEFB1B2,
      ),
    };
    return HomeDisplayPalette(
      Color(dark ? darkBg : background),
      Color(dark ? darkSurface : surface),
      Color(dark ? darkAccent : accent),
    );
  }
}

class HomeDisplayBackdrop extends StatelessWidget {
  const HomeDisplayBackdrop({
    super.key,
    required this.style,
    required this.hasCustomBackground,
  });

  final HomeDisplayStyle style;
  final bool hasCustomBackground;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: hasCustomBackground
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.background,
                    palette.surface,
                    palette.background,
                  ],
                ),
        ),
        child: CustomPaint(
          painter: _DisplayMotifPainter(
            style,
            palette.accent.withValues(alpha: hasCustomBackground ? .055 : .09),
          ),
        ),
      ),
    );
  }
}

class HomeDisplayHeading extends StatelessWidget {
  const HomeDisplayHeading({
    super.key,
    required this.style,
    this.houseName,
    this.title,
  });

  final HomeDisplayStyle style;
  final String? houseName;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            houseName?.trim().isNotEmpty == true
                ? houseName!.trim()
                : context.tr(style.titleKey),
            style: GoogleFonts.beVietnamPro(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title ??
                context.tr(
                  style == HomeDisplayStyle.current
                      ? style.titleKey
                      : 'home_display_${style.storageKey}_heading',
                ),
            style: GoogleFonts.lora(
              fontSize: style == HomeDisplayStyle.scrapbook ? 29 : 25,
              fontWeight: FontWeight.w500,
              fontStyle: style == HomeDisplayStyle.scrapbook
                  ? FontStyle.italic
                  : FontStyle.normal,
              height: 1.25,
              letterSpacing: -.7,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Các thao tác chi tiết cũ luôn còn lối vào, không lặp thẻ lớn trên hero.
class HomeDisplayProfileDetails extends StatelessWidget {
  const HomeDisplayProfileDetails({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    // ExpansionTile lưu bool; cần ô riêng để không đọc nhầm offset double
    // của trang Home, kể cả offset cũ còn trong PageStorage của phiên hiện tại.
    key: const PageStorageKey<String>('home-display-profile-details'),
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    childrenPadding: const EdgeInsets.only(top: 8, bottom: 12),
    shape: const Border(),
    collapsedShape: const Border(),
    title: Text(
      context.tr('home_display_profile_details'),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    children: [child],
  );
}

class HomeDisplayNoteSurface extends StatelessWidget {
  const HomeDisplayNoteSurface({
    super.key,
    required this.style,
    required this.child,
  });
  final HomeDisplayStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style == HomeDisplayStyle.minimal ? null : palette.surface,
        borderRadius: style == HomeDisplayStyle.minimal
            ? null
            : style == HomeDisplayStyle.scrapbook
            ? const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(22),
              )
            : BorderRadius.circular(20),
        border: style == HomeDisplayStyle.minimal
            ? Border(
                bottom: BorderSide(
                  color: palette.accent.withValues(alpha: .18),
                ),
              )
            : Border.all(color: palette.accent.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 16,
                color: palette.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('home_note_edit_title'),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.edit_outlined, size: 14, color: palette.accent),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Dạng gọn chỉ nhận con số/nhãn thật từ cùng view data của vòng đếm.
/// Mọi vùng sửa giữ callback hiện hữu, không tạo bộ đếm hoặc timer mới.
class HomeDisplayDaySummary extends StatelessWidget {
  const HomeDisplayDaySummary({
    super.key,
    required this.style,
    required this.value,
    required this.topLabel,
    required this.bottomLabel,
    this.onEditValue,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.onCustomize,
  });

  final HomeDisplayStyle style;
  final String value;
  final String topLabel;
  final String bottomLabel;
  final VoidCallback? onEditValue;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    final scheme = Theme.of(context).colorScheme;
    final numberSize = switch (style) {
      HomeDisplayStyle.current => 38.0,
      HomeDisplayStyle.scrapbook => 36.0,
      HomeDisplayStyle.minimal => 34.0,
      _ => 36.0,
    };
    final labelSize = style == HomeDisplayStyle.minimal ? 13.0 : 14.0;
    final radius = switch (style) {
      HomeDisplayStyle.current => 28.0,
      HomeDisplayStyle.nest => 20.0,
      HomeDisplayStyle.portrait => 18.0,
      HomeDisplayStyle.scrapbook => 8.0,
      HomeDisplayStyle.cloud => 30.0,
      HomeDisplayStyle.daily => 16.0,
      HomeDisplayStyle.minimal => 12.0,
    };
    final tintedSurface = Color.alphaBlend(
      palette.accent.withValues(alpha: .06),
      palette.surface,
    );
    final gradient = switch (style) {
      HomeDisplayStyle.current => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.surface, tintedSurface],
      ),
      HomeDisplayStyle.cloud => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.surface, tintedSurface],
      ),
      _ => null,
    };
    Widget label(String text, VoidCallback? callback, {bool number = false}) =>
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: callback,
            onLongPress: onCustomize,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: number ? numberSize : labelSize,
                    fontWeight: number ? FontWeight.w800 : FontWeight.w700,
                    height: number ? 1.05 : 1.25,
                    letterSpacing: number ? -.7 : .1,
                    color: number
                        ? palette.accent
                        : scheme.onSurface.withValues(alpha: .9),
                  ),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gradient == null ? palette.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.accent.withValues(alpha: .22)),
        boxShadow: style == HomeDisplayStyle.current
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: .10),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Nhãn tùy chỉnh dài hoặc chữ hệ thống lớn được xếp dọc đầy đủ.
          final wideLabels = topLabel.length + bottomLabel.length > 32;
          final stacked =
              constraints.maxWidth < 240 ||
              MediaQuery.textScalerOf(context).scale(14) > 20 ||
              wideLabels;
          final children = [
            label(topLabel, onEditTopLabel),
            Semantics(
              button: onEditValue != null,
              label: context.tr('home_countdown_start_date'),
              child: label(value, onEditValue, number: true),
            ),
            label(bottomLabel, onEditBottomLabel),
          ];
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                )
              : Row(
                  children: [
                    for (final child in children) Expanded(child: child),
                  ],
                );
        },
      ),
    );
  }
}

/// Giấy kẻ riêng cho Sổ kỷ niệm; các kiểu còn lại để nền yên và thoáng.
class _DisplayMotifPainter extends CustomPainter {
  const _DisplayMotifPainter(this.style, this.color);
  final HomeDisplayStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (style != HomeDisplayStyle.scrapbook) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (var y = 28.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DisplayMotifPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.color != color;
}
