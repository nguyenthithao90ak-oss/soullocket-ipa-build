import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/features/love_insight_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';
import 'package:soullocket_app/views/home/tabs/widgets/utilities_hub_tile.dart';

/// Lời chào một dòng thay cho thẻ tiêu đề lớn.
class HomeCompactHeader extends StatelessWidget {
  const HomeCompactHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final (String labelKey, IconData icon, Color accent) = hour < 6
        ? (
            'home_time_late_night_title',
            Icons.bedtime_rounded,
            const Color(0xFF6A4FA3),
          )
        : hour < 11
        ? (
            'home_time_morning_title',
            Icons.wb_sunny_rounded,
            const Color(0xFFA0590F),
          )
        : hour < 14
        ? (
            'home_time_noon_title',
            Icons.light_mode_rounded,
            const Color(0xFFB24F2B),
          )
        : hour < 19
        ? (
            'home_time_afternoon_title',
            Icons.auto_awesome_rounded,
            const Color(0xFFB0305A),
          )
        : (
            'home_time_evening_title',
            Icons.nightlight_round,
            const Color(0xFF6A4FA3),
          );
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(now);
    final subtitleText = subtitle?.trim() ?? '';

    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${context.tr(labelKey)} · $dateLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: SLColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitleText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitleText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SLColors.textSecond,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeQuickAction {
  const HomeQuickAction({
    required this.id,
    required this.label,
    required this.stickerId,
    required this.fallbackIcon,
    required this.onTap,
    this.isPinned = false,
  });

  final String id;
  final String label;
  final String stickerId;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool isPinned;
}

/// Một hàng lối vào nhanh: thao tác hằng ngày, tiện ích đã ghim và nút ghim thêm.
/// Không cuộn ngang để không tranh cử chỉ vuốt chuyển tab.
class HomeQuickActionsRow extends StatelessWidget {
  const HomeQuickActionsRow({
    super.key,
    required this.actions,
    required this.onAddPin,
  });

  static const int _perRow = 5;

  final List<HomeQuickAction> actions;
  final VoidCallback onAddPin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 560 ? 7 : _perRow;
        final itemWidth = constraints.maxWidth / perRow;
        return Wrap(
          runSpacing: 10,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _QuickActionTile(action: action),
              ),
            SizedBox(
              width: itemWidth,
              child: _AddPinTile(onTap: onAddPin),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final HomeQuickAction action;

  @override
  Widget build(BuildContext context) {
    final label = action.isPinned
        ? '${action.label}, ${context.tr('home_ghim_4be667')}'
        : action.label;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('home-quick-${action.id}'),
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: SLColors.paper,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF522C49,
                            ).withValues(alpha: 0.07),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: UtilityStickerImage(
                        stickerId: action.stickerId,
                        size: 42,
                        fallbackIcon: action.fallbackIcon,
                      ),
                    ),
                    if (action.isPinned)
                      const PositionedDirectional(
                        top: -4,
                        end: -4,
                        child: UtilitiesPinBadge(size: 19),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                    height: 1.25,
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

class _AddPinTile extends StatelessWidget {
  const _AddPinTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('home_compact_add_pin');
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('home-quick-add-pin'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 58,
                  height: 58,
                  child: CustomPaint(
                    painter: _DashedRoundedRectPainter(
                      color: Color(0xFFD9C4B8),
                      radius: 20,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 24,
                        color: SLColors.textSecond,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textMedium,
                    height: 1.25,
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

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(1),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class HomeUpcomingItem {
  const HomeUpcomingItem({
    required this.id,
    required this.title,
    required this.when,
    required this.stickerId,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String id;
  final String title;
  final String when;
  final String stickerId;
  final IconData fallbackIcon;
  final VoidCallback onTap;
}

/// Sự kiện gần nhất nổi bật, tối đa hai sự kiện kế tiếp dạng dòng gọn.
class HomeUpcomingCard extends StatelessWidget {
  const HomeUpcomingCard({
    super.key,
    required this.items,
    required this.onSeeAll,
    this.statusText,
    this.onRetry,
  });

  final List<HomeUpcomingItem> items;
  final VoidCallback onSeeAll;
  final String? statusText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  context.tr('home_compact_upcoming_title'),
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFA82E48),
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('home_compact_see_all'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFA82E48),
                    ),
                  ),
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
        const SizedBox(height: 4),
        Material(
          color: SLColors.paper,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: visible.isEmpty
              ? _UpcomingEmpty(statusText: statusText, onRetry: onRetry)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _UpcomingFeature(item: visible.first),
                    for (final item in visible.skip(1)) ...[
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 16, end: 16),
                        child: Divider(height: 1, color: SLColors.borderLight),
                      ),
                      _UpcomingRow(item: item),
                    ],
                    if (statusText != null && onRetry != null)
                      _UpcomingRetry(
                        statusText: statusText!,
                        onRetry: onRetry!,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _UpcomingFeature extends StatelessWidget {
  const _UpcomingFeature({required this.item});

  final HomeUpcomingItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}, ${item.when}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('home-upcoming-${item.id}'),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: SLColors.paperBlush,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: UtilityStickerImage(
                  stickerId: item.stickerId,
                  size: 44,
                  fallbackIcon: item.fallbackIcon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SLColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SLColors.textSecond,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: SLColors.textSecond,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});

  final HomeUpcomingItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}, ${item.when}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('home-upcoming-${item.id}'),
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: SLColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.when,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFA82E48),
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

class _UpcomingEmpty extends StatelessWidget {
  const _UpcomingEmpty({this.statusText, this.onRetry});

  final String? statusText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 22,
            color: SLColors.textSecond,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText ?? context.tr('home_compact_upcoming_empty'),
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SLColors.textSecond,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFA82E48),
                minimumSize: const Size(48, 44),
              ),
              child: Text(context.tr('core_retry')),
            ),
        ],
      ),
    );
  }
}

class _UpcomingRetry extends StatelessWidget {
  const _UpcomingRetry({required this.statusText, required this.onRetry});

  final String statusText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              statusText,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SLColors.textSecond,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA82E48),
              minimumSize: const Size(48, 44),
            ),
            child: Text(context.tr('core_retry')),
          ),
        ],
      ),
    );
  }
}

/// Thẻ bản đồ thu nhỏ; chạm để mở bản đồ đầy đủ.
class HomeMapMiniCard extends StatelessWidget {
  const HomeMapMiniCard({
    super.key,
    required this.title,
    required this.distanceText,
    required this.onTap,
    this.detailText,
  });

  final String title;
  final String distanceText;
  final String? detailText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = detailText?.trim() ?? '';
    return Semantics(
      button: true,
      label: [title, distanceText, if (detail.isNotEmpty) detail].join(', '),
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('home-map-mini'),
        color: SLColors.paper,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: const SizedBox(
                    height: 84,
                    child: CustomPaint(painter: _MiniMapPainter()),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E6A86),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distanceText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SLColors.textSecond,
                          ),
                        ),
                      ],
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

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFDDEFF4),
    );

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-8, h * 0.72)
        ..cubicTo(w * 0.2, h * 0.55, w * 0.38, h * 0.82, w * 0.6, h * 0.6)
        ..cubicTo(w * 0.75, h * 0.45, w * 0.9, h * 0.38, w + 8, h * 0.46),
      road..strokeWidth = 7,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.27, -8)
        ..cubicTo(w * 0.31, h * 0.35, w * 0.25, h * 0.7, w * 0.35, h + 8),
      road..strokeWidth = 5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.72, -8)
        ..cubicTo(w * 0.67, h * 0.3, w * 0.77, h * 0.62, w * 0.69, h + 8),
      road..strokeWidth = 5,
    );

    final start = Offset(w * 0.23, h * 0.34);
    final end = Offset(w * 0.79, h * 0.6);
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(w * 0.4, h * 0.1, w * 0.63, h * 0.84, end.dx, end.dy);
    final dash = Paint()
      ..color = SLColors.primaryActive
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final metric in route.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), dash);
        distance += 9;
      }
    }

    void pin(Offset center, Color color) {
      canvas.drawCircle(center, 9, Paint()..color = Colors.white);
      canvas.drawCircle(center, 6.5, Paint()..color = color);
    }

    pin(start, SLColors.primary);
    pin(end, SLColors.accentPurpleDark);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => false;
}

/// Tóm tắt "Hành trình" thu nhỏ; chạm để mở trang thống kê đầy đủ.
class HomeInsightMiniCard extends StatelessWidget {
  const HomeInsightMiniCard({
    super.key,
    required this.data,
    required this.isSingle,
    required this.onTap,
  });

  final LoveInsightData? data;
  final bool isSingle;
  final VoidCallback onTap;

  static const Color _surface = Color(0xFFF0EAFB);
  static const Color _accent = Color(0xFF5B3E99);
  static const Color _ink = Color(0xFF2E1F4D);
  static const Color _body = Color(0xFF5A4A78);

  @override
  Widget build(BuildContext context) {
    final insight = data;
    final scoreLabel = context.tr(
      isSingle ? 'home_chshotng_328c7a' : 'home_chshnhphc_7c8e85',
    );
    final score = insight?.loveScore.clamp(0, 100) ?? 0;
    final memories = insight?.memoryThisMonth ?? 0;
    final semanticLabel = insight == null
        ? context.tr('home_anggomthmc_0715ce')
        : [
            context.tr('home_compact_this_month'),
            '$memories ${context.tr('home_compact_memories_unit')}',
            '$scoreLabel $score/100',
            L10nService().translateActiveDays(insight.activeDays),
          ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('home-insight-mini'),
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: insight == null
                ? Text(
                    context.tr('home_anggomthmc_0715ce'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _body,
                      height: 1.4,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr('home_compact_this_month'),
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 6,
                            children: [
                              Text(
                                '$memories',
                                style: SLTheme.quicksand(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                  height: 1.0,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  context.tr('home_compact_memories_unit'),
                                  style: SLTheme.quicksand(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  scoreLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLTheme.quicksand(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _body,
                                  ),
                                ),
                              ),
                              Text(
                                '$score',
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: score / 100,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFDCCFF3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                SLColors.accentPurpleDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            L10nService().translateActiveDays(
                              insight.activeDays,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _body,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Danh sách tiện ích để ghim/bỏ ghim lên trang Nhà.
class HomePinPickerSheet extends StatelessWidget {
  const HomePinPickerSheet({
    super.key,
    required this.apps,
    required this.pinnedIds,
    required this.onToggle,
  });

  final List<UtilityApp> apps;
  final Set<String> pinnedIds;
  final ValueChanged<UtilityApp> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            context.tr('home_compact_pin_sheet_title'),
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SLColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            context.tr('home_compact_pin_sheet_hint'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SLColors.textSecond,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final pinned = pinnedIds.contains(app.id);
              return Semantics(
                toggled: pinned,
                button: true,
                label: app.localizedTitle,
                excludeSemantics: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ValueKey('home-pin-${app.id}'),
                    onTap: () => onToggle(app),
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 60),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            UtilityHubSticker(app: app, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                app.localizedTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: SLColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: pinned
                                    ? SLColors.primaryActive
                                    : SLColors.bgSubtle,
                                shape: BoxShape.circle,
                                border: pinned
                                    ? null
                                    : Border.all(color: SLColors.border),
                              ),
                              child: Icon(
                                pinned
                                    ? Icons.push_pin_rounded
                                    : Icons.push_pin_outlined,
                                size: 18,
                                color: pinned
                                    ? Colors.white
                                    : SLColors.textSecond,
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
          ),
        ),
      ],
    );
  }
}
