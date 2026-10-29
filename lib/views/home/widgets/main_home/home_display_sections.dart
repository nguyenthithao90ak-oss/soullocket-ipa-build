import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../utils/services/l10n_service.dart';
import 'home_compact_sections.dart';
import 'home_display_layout.dart';
import 'home_display_style.dart';

/// Phiên bản các thẻ phụ dành cho những concept Home mới.
///
/// Widget chỉ nhận dữ liệu đã được Home chuẩn bị sẵn. Không đọc Firebase,
/// không tự tạo ngày hoặc trạng thái giả; vì vậy khi dữ liệu chưa có, thẻ sẽ
/// nói rõ là đang trống và giữ lối thử lại nếu Home truyền vào.
class HomeDisplayUpcomingSection extends StatelessWidget {
  const HomeDisplayUpcomingSection({
    super.key,
    required this.style,
    required this.items,
    required this.onSeeAll,
    this.statusText,
    this.onRetry,
  });

  final HomeDisplayStyle style;
  final List<HomeUpcomingItem> items;
  final VoidCallback onSeeAll;
  final String? statusText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    final visible = items.take(3).toList(growable: false);
    final title = context.tr('home_compact_upcoming_title');
    return Column(
      key: const ValueKey('home-display-upcoming-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: GoogleFonts.lora(
                    fontSize: style == HomeDisplayStyle.scrapbook ? 21 : 19,
                    fontWeight: FontWeight.w600,
                    color: palette.accent,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('home-display-upcoming-see-all'),
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: palette.accent,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('home_compact_see_all'),
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    textDirection: Directionality.of(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          _DisplayUpcomingEmpty(
            palette: palette,
            statusText: statusText,
            onRetry: onRetry,
          )
        else if (style == HomeDisplayStyle.daily)
          _DisplayUpcomingTimeline(style: style, items: visible)
        else if (style == HomeDisplayStyle.scrapbook)
          _DisplayUpcomingTicket(items: visible, palette: palette)
        else
          _DisplayUpcomingWarmList(
            style: style,
            items: visible,
            palette: palette,
          ),
        if (statusText != null && visible.isNotEmpty && onRetry != null) ...[
          const SizedBox(height: 6),
          _DisplayUpcomingRetry(
            palette: palette,
            message: statusText!,
            onRetry: onRetry!,
          ),
        ],
      ],
    );
  }
}

class _DisplayUpcomingWarmList extends StatelessWidget {
  const _DisplayUpcomingWarmList({
    required this.style,
    required this.items,
    required this.palette,
  });

  final HomeDisplayStyle style;
  final List<HomeUpcomingItem> items;
  final HomeDisplayPalette palette;

  @override
  Widget build(BuildContext context) {
    final surface = palette.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(
          style == HomeDisplayStyle.minimal ? 14 : 22,
        ),
        border: Border.all(color: palette.accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: palette.accent.withValues(alpha: .12),
              ),
            _DisplayUpcomingRow(
              item: items[index],
              palette: palette,
              featured: index == 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _DisplayUpcomingTimeline extends StatelessWidget {
  const _DisplayUpcomingTimeline({required this.style, required this.items});

  final HomeDisplayStyle style;
  final List<HomeUpcomingItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withValues(alpha: .18)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++)
              _DisplayTimelineRow(
                item: items[index],
                palette: palette,
                isLast: index == items.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _DisplayTimelineRow extends StatelessWidget {
  const _DisplayTimelineRow({
    required this.item,
    required this.palette,
    required this.isLast,
  });

  final HomeUpcomingItem item;
  final HomeDisplayPalette palette;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}, ${item.when}',
      excludeSemantics: true,
      onTap: item.onTap,
      child: InkWell(
        key: ValueKey('home-display-upcoming-${item.id}'),
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      if (!isLast)
                        Positioned(
                          top: 20,
                          bottom: 0,
                          child: ColoredBox(
                            color: palette.accent.withValues(alpha: .24),
                            child: const SizedBox(width: 2),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.accent.withValues(alpha: .22),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const SizedBox(width: 10, height: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: _DisplayUpcomingCopy(
                      item: item,
                      palette: palette,
                      titleSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Center(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: palette.accent.withValues(alpha: .72),
                    textDirection: Directionality.of(context),
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

class _DisplayUpcomingTicket extends StatelessWidget {
  const _DisplayUpcomingTicket({required this.items, required this.palette});

  final List<HomeUpcomingItem> items;
  final HomeDisplayPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketEdgePainter(color: palette.accent.withValues(alpha: .28)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.accent.withValues(alpha: .18)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(13, 9, 9, 9),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    color: palette.accent.withValues(alpha: .14),
                  ),
                _DisplayUpcomingRow(
                  item: items[index],
                  palette: palette,
                  featured: index == 0,
                  compact: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DisplayUpcomingRow extends StatelessWidget {
  const _DisplayUpcomingRow({
    required this.item,
    required this.palette,
    required this.featured,
    this.compact = false,
  });

  final HomeUpcomingItem item;
  final HomeDisplayPalette palette;
  final bool featured;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}, ${item.when}',
      excludeSemantics: true,
      onTap: item.onTap,
      child: InkWell(
        key: ValueKey('home-display-upcoming-${item.id}'),
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 58 : 64),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              compact ? 2 : 12,
              compact ? 8 : 10,
              2,
              compact ? 8 : 10,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(compact ? 12 : 16),
                  ),
                  child: SizedBox(
                    width: compact ? 40 : 46,
                    height: compact ? 40 : 46,
                    child: Icon(
                      item.fallbackIcon,
                      size: compact ? 20 : 23,
                      color: palette.accent,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 9 : 11),
                Expanded(
                  child: _DisplayUpcomingCopy(
                    item: item,
                    palette: palette,
                    titleSize: featured ? 14.5 : 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: palette.accent.withValues(alpha: .72),
                  textDirection: Directionality.of(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisplayUpcomingCopy extends StatelessWidget {
  const _DisplayUpcomingCopy({
    required this.item,
    required this.palette,
    required this.titleSize,
  });

  final HomeUpcomingItem item;
  final HomeDisplayPalette palette;
  final double titleSize;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.beVietnamPro(
          fontSize: titleSize,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.25,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        item.when,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: palette.accent.withValues(alpha: .84),
          height: 1.2,
        ),
      ),
    ],
  );
}

class _DisplayUpcomingEmpty extends StatelessWidget {
  const _DisplayUpcomingEmpty({
    required this.palette,
    required this.statusText,
    required this.onRetry,
  });

  final HomeDisplayPalette palette;
  final String? statusText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withValues(alpha: .16)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, color: palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                statusText ?? context.tr('home_compact_upcoming_empty'),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(context.tr('core_retry')),
              ),
          ],
        ),
      ),
    );
  }
}

class _DisplayUpcomingRetry extends StatelessWidget {
  const _DisplayUpcomingRetry({
    required this.palette,
    required this.message,
    required this.onRetry,
  });

  final HomeDisplayPalette palette;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: palette.accent.withValues(alpha: .82),
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: palette.accent,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(context.tr('core_retry')),
        ),
      ],
    ),
  );
}

/// Lối vào Trạm Mây gọn cho concept mới. Trạng thái thật và bé đang sở hữu
/// vẫn do màn Trạm Mây xử lý; thẻ này không đọc service hoặc tạo dữ liệu.
class HomeDisplayPetEntry extends StatelessWidget {
  const HomeDisplayPetEntry({
    super.key,
    required this.style,
    required this.onTap,
  });

  final HomeDisplayStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HomeDisplayPalette.of(context, style);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final petNames = [
      context.tr('pet_care_bunny_name'),
      context.tr('pet_care_bear_name'),
    ].join(' · ');
    final petActions = [
      context.tr('pet_care_feed'),
      context.tr('pet_care_bath'),
      context.tr('pet_care_hug'),
    ].join(' · ');
    final icon = style == HomeDisplayStyle.cloud
        ? const Icon(Icons.cloud_rounded)
        : style == HomeDisplayStyle.minimal
        ? Icon(Icons.favorite_rounded, color: palette.accent)
        : CustomPaint(
            size: const Size(50, 42),
            painter: _MiniPetPainter(
              primary: palette.accent,
              secondary: palette.accent.withValues(alpha: .42),
              dark: dark,
            ),
          );
    return Semantics(
      button: true,
      label: '${context.tr('pet_care_room_living')}, $petNames, $petActions',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          style == HomeDisplayStyle.minimal ? 14 : 20,
        ),
        child: InkWell(
          key: const ValueKey('pet-care-entry'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            style == HomeDisplayStyle.minimal ? 14 : 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Ink(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(
                  style == HomeDisplayStyle.minimal ? 14 : 20,
                ),
                border: Border.all(
                  color: palette.accent.withValues(alpha: .17),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 48,
                      child: Center(
                        child: icon is Icon
                            ? Icon(icon.icon, size: 28, color: palette.accent)
                            : icon,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('pet_care_room_living'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            petNames,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            petActions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: palette.accent.withValues(alpha: .78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                      color: palette.accent.withValues(alpha: .76),
                      textDirection: Directionality.of(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketEdgePainter extends CustomPainter {
  const _TicketEdgePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    final double notch = math.min<double>(6, size.height / 10);
    path.moveTo(0, notch);
    path.lineTo(0, size.height - notch);
    for (var x = size.width; x >= 0; x -= 14) {
      path.lineTo(x, size.height - notch);
      path.lineTo(x - 7, size.height);
      path.lineTo(x - 14, size.height - notch);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TicketEdgePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MiniPetPainter extends CustomPainter {
  const _MiniPetPainter({
    required this.primary,
    required this.secondary,
    required this.dark,
  });

  final Color primary;
  final Color secondary;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = dark ? Colors.white : const Color(0xFF4B3E4A);
    final unit = math.min(size.width, size.height) / 5;
    void pet(Offset center, Color color, bool roundEar) {
      final fill = Paint()..color = color;
      final outline = Paint()
        ..color = base.withValues(alpha: .26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final earHeight = roundEar ? unit * 1.2 : unit * 1.65;
      for (final direction in [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: center + Offset(direction * unit * .55, -unit * .72),
            width: unit * .52,
            height: earHeight,
          ),
          fill,
        );
      }
      canvas.drawCircle(center, unit * .82, fill);
      canvas.drawCircle(center, unit * .82, outline);
      for (final direction in [-1.0, 1.0]) {
        canvas.drawCircle(
          center + Offset(direction * unit * .24, -unit * .06),
          unit * .065,
          Paint()..color = base.withValues(alpha: .68),
        );
      }
      canvas.drawCircle(
        center + Offset(0, unit * .18),
        unit * .06,
        Paint()..color = primary,
      );
    }

    pet(Offset(size.width * .38, size.height * .60), secondary, false);
    pet(
      Offset(size.width * .64, size.height * .60),
      primary.withValues(alpha: .72),
      true,
    );
    final heart = Paint()..color = primary;
    canvas.drawCircle(
      Offset(size.width * .51, size.height * .16),
      unit * .12,
      heart,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniPetPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.dark != dark;
}
