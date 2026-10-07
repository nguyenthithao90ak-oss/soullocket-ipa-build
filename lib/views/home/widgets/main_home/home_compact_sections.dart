import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/home_image_policy.dart';
import 'package:soullocket_app/widgets/couple_default_avatar.dart';
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
    final subtitleText = subtitle?.trim() ?? '';

    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    this.myPoint,
    this.partnerPoint,
    this.myAvatarUrl = '',
    this.partnerAvatarUrl = '',
    this.myFemale = false,
    this.partnerFemale = true,
    this.tileProvider,
  });

  final String title;
  final String distanceText;
  final String? detailText;
  final Map<String, dynamic>? myPoint;
  final Map<String, dynamic>? partnerPoint;
  final String myAvatarUrl;
  final String partnerAvatarUrl;
  final bool myFemale;
  final bool partnerFemale;
  final fm.TileProvider? tileProvider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = detailText?.trim() ?? '';
    final mine = _MiniMapPoint.fromMap(myPoint);
    final partner = _MiniMapPoint.fromMap(partnerPoint);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF5E7EE) : SLColors.ink;
    final muted = dark ? const Color(0xFFC6B9C1) : SLColors.textSecond;
    return Semantics(
      button: true,
      label: [title, distanceText, if (detail.isNotEmpty) detail].join(', '),
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('home-map-mini'),
        color: dark ? const Color(0xFF302C34) : SLColors.paper,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 190),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 84,
                      child: mine == null && partner == null
                          ? ColoredBox(
                              key: const ValueKey('home-map-no-location'),
                              color: dark
                                  ? const Color(0xFF38434A)
                                  : const Color(0xFFE4F2EF),
                              child: Center(
                                child: Icon(
                                  Icons.explore_rounded,
                                  size: 36,
                                  color: dark
                                      ? const Color(0xFFA8C7C1)
                                      : const Color(0xFF7FA9A0),
                                ),
                              ),
                            )
                          : _HomeMiniMapPreview(
                              myPoint: mine,
                              partnerPoint: partner,
                              myAvatarUrl: myAvatarUrl,
                              partnerAvatarUrl: partnerAvatarUrl,
                              myFemale: myFemale,
                              partnerFemale: partnerFemale,
                              tileProvider: tileProvider,
                            ),
                    ),
                  ),
                  if (mine != null || partner != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Text(
                        context.tr('home_compact_map_attribution'),
                        textAlign: TextAlign.end,
                        textScaler: TextScaler.noScaling,
                        style: SLTheme.quicksand(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: muted,
                          height: 1.1,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: dark
                                  ? const Color(0xFFF5A1B6)
                                  : const Color(0xFFD65D7C),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: _miniCardText(
                                title,
                                color: dark
                                    ? const Color(0xFFAAD2C7)
                                    : const Color(0xFF3B796D),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _miniCardText(distanceText, color: ink, fontSize: 14),
                        if (detail.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          _miniCardText(
                            detail,
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

Widget _miniCardText(
  String text, {
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.w700,
  int maxLines = 2,
  Key? key,
}) => Text(
  text,
  key: key,
  maxLines: maxLines,
  overflow: TextOverflow.ellipsis,
  style: SLTheme.quicksand(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: 1.2,
  ),
);

class _MiniMapPoint {
  const _MiniMapPoint({required this.coordinate, required this.isLive});
  final ll.LatLng coordinate;
  final bool isLive;

  static _MiniMapPoint? fromMap(Map<String, dynamic>? data) {
    double? parse(Object? value) => value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value.trim())
        : null;
    final latitude = parse(data?['lt'] ?? data?['lat']);
    final longitude = parse(data?['lg'] ?? data?['lng']);
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return _MiniMapPoint(
      coordinate: ll.LatLng(latitude, longitude),
      isLive: data?['isLive'] == true,
    );
  }
}

class _HomeMiniMapPreview extends StatefulWidget {
  const _HomeMiniMapPreview({
    required this.myPoint,
    required this.partnerPoint,
    required this.myAvatarUrl,
    required this.partnerAvatarUrl,
    required this.myFemale,
    required this.partnerFemale,
    required this.tileProvider,
  });
  final _MiniMapPoint? myPoint;
  final _MiniMapPoint? partnerPoint;
  final String myAvatarUrl;
  final String partnerAvatarUrl;
  final bool myFemale;
  final bool partnerFemale;
  final fm.TileProvider? tileProvider;

  @override
  State<_HomeMiniMapPreview> createState() => _HomeMiniMapPreviewState();
}

class _HomeMiniMapPreviewState extends State<_HomeMiniMapPreview> {
  final _controller = fm.MapController();
  fm.TileProvider? _tileProvider;
  ScrollPosition? _scrollPosition;
  bool _visible = false;
  bool _visibilityCheckPending = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = position;
      _scrollPosition?.addListener(_scheduleVisibilityCheck);
    }
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckPending) return;
    _visibilityCheckPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckPending = false;
      if (!mounted) return;
      final surface = context.findRenderObject();
      if (surface is! RenderBox || !surface.hasSize) return;
      final Object? viewport = RenderAbstractViewport.maybeOf(surface);
      final surfaceRect = surface.localToGlobal(Offset.zero) & surface.size;
      final viewportRect = viewport is RenderBox && viewport.hasSize
          ? viewport.localToGlobal(Offset.zero) & viewport.size
          : Offset.zero & MediaQuery.sizeOf(context);
      final visible =
          TickerMode.valuesOf(context).enabled &&
          surfaceRect.overlaps(viewportRect);
      if (visible != _visible) {
        setState(() {
          _visible = visible;
          if (!visible) _tileProvider = null;
        });
      }
    });
  }

  List<ll.LatLng> get _coordinates => [
    if (widget.myPoint != null) widget.myPoint!.coordinate,
    if (widget.partnerPoint != null) widget.partnerPoint!.coordinate,
  ];
  fm.CameraFit get _cameraFit => fm.CameraFit.bounds(
    bounds: fm.LatLngBounds.fromPoints(_coordinates),
    padding: const EdgeInsets.fromLTRB(36, 38, 36, 10),
    maxZoom: 14.5,
  );

  @override
  void didUpdateWidget(covariant _HomeMiniMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myPoint?.coordinate != widget.myPoint?.coordinate ||
        oldWidget.partnerPoint?.coordinate != widget.partnerPoint?.coordinate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready) _controller.fitCamera(_cameraFit);
      });
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.myPoint;
    final partner = widget.partnerPoint;
    final together =
        mine != null &&
        partner != null &&
        const ll.Distance().as(
              ll.LengthUnit.Meter,
              mine.coordinate,
              partner.coordinate,
            ) <
            200;
    final mineOnLeft =
        mine != null &&
        partner != null &&
        mine.coordinate.longitude <= partner.coordinate.longitude;
    return RepaintBoundary(
      child: Stack(
        children: [
          IgnorePointer(
            child: fm.FlutterMap(
              mapController: _controller,
              options: fm.MapOptions(
                initialCameraFit: _cameraFit,
                minZoom: 0,
                maxZoom: 15,
                backgroundColor: const Color(0xFFE4F2EF),
                interactionOptions: const fm.InteractionOptions(
                  flags: fm.InteractiveFlag.none,
                ),
                onMapReady: () => _ready = true,
              ),
              children: [
                if (_visible)
                  fm.TileLayer(
                    urlTemplate: const String.fromEnvironment(
                      'HOME_MAP_OSM_TILE_URL',
                      defaultValue:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    userAgentPackageName: AppConfig.androidPackageName,
                    tileProvider: _tileProvider ??=
                        widget.tileProvider ??
                        fm.NetworkTileProvider(silenceExceptions: true),
                    maxNativeZoom: 19,
                    panBuffer: 0,
                    keepBuffer: 0,
                    retinaMode: false,
                  ),
                fm.MarkerLayer(
                  markers: [
                    if (mine != null)
                      fm.Marker(
                        point: mine.coordinate,
                        width: 40,
                        height: 38,
                        alignment: together
                            ? (mineOnLeft
                                  ? Alignment.topRight
                                  : Alignment.topLeft)
                            : Alignment.topCenter,
                        child: _MiniMapAvatarPin(
                          key: const ValueKey('home-map-my-avatar'),
                          imageUrl: widget.myAvatarUrl,
                          female: widget.myFemale,
                          live: mine.isLive,
                          color: const Color(0xFFE87998),
                        ),
                      ),
                    if (partner != null)
                      fm.Marker(
                        point: partner.coordinate,
                        width: 40,
                        height: 38,
                        alignment: together
                            ? (mineOnLeft
                                  ? Alignment.topLeft
                                  : Alignment.topRight)
                            : Alignment.topCenter,
                        child: _MiniMapAvatarPin(
                          key: const ValueKey('home-map-partner-avatar'),
                          imageUrl: widget.partnerAvatarUrl,
                          female: widget.partnerFemale,
                          live: partner.isLive,
                          color: const Color(0xFF9778C9),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapAvatarPin extends StatelessWidget {
  const _MiniMapAvatarPin({
    super.key,
    required this.imageUrl,
    required this.female,
    required this.live,
    required this.color,
  });
  final String imageUrl;
  final bool female;
  final bool live;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    Widget fallback() => CoupleDefaultAvatar(female: female, animate: false);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: url.isEmpty
                ? fallback()
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    memCacheWidth: HomeImagePolicy.avatarPixels,
                    memCacheHeight: HomeImagePolicy.avatarPixels,
                    maxWidthDiskCache: HomeImagePolicy.avatarPixels,
                    maxHeightDiskCache: HomeImagePolicy.avatarPixels,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, imageUrl) => fallback(),
                    errorWidget: (context, imageUrl, error) => fallback(),
                  ),
          ),
        ),
        Positioned(
          bottom: 0,
          child: Icon(Icons.favorite_rounded, size: 11, color: color),
        ),
        if (live)
          PositionedDirectional(
            end: 2,
            top: 1,
            child: Container(
              key: const ValueKey('home-map-live-dot'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF459479),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final insight = data;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFD0B5F2) : const Color(0xFF7955A4);
    final ink = dark ? const Color(0xFFF1E9FB) : const Color(0xFF463057);
    final muted = dark ? const Color(0xFFC6B6D8) : const Color(0xFF786486);
    final scoreLabel = context.tr(
      isSingle ? 'home_chshotng_328c7a' : 'home_chshnhphc_7c8e85',
    );
    final score = insight?.loveScore.clamp(0, 100) ?? 0;
    final memories = insight?.memoryThisMonth ?? 0;
    final numberFormat = MaterialLocalizations.of(context).formatDecimal;
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: dark
                  ? const [Color(0xFF3E344A), Color(0xFF332D3D)]
                  : const [Color(0xFFF4EDFF), Color(0xFFEDE4F8)],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: _miniCardText(
                            context.tr('home_compact_this_month'),
                            color: accent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (insight == null) ...[
                      const SizedBox(height: 12),
                      Icon(Icons.auto_awesome_rounded, size: 26, color: accent),
                      const SizedBox(height: 8),
                      _miniCardText(
                        context.tr('home_anggomthmc_0715ce'),
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        maxLines: 4,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _miniCardText(
                                  numberFormat(memories),
                                  key: const ValueKey('home-month-memories'),
                                  color: ink,
                                  fontSize: 34,
                                  maxLines: 1,
                                ),
                                _miniCardText(
                                  context.tr('home_compact_memories_unit'),
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Transform.rotate(
                            angle: -0.12,
                            child: Container(
                              width: 32,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF55435E)
                                    : const Color(0xFFFFFAFF),
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.photo_library_rounded,
                                size: 21,
                                color: Color(0xFFD880A2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _miniCardText(
                              scoreLabel,
                              color: muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _miniCardText(
                            numberFormat(score),
                            key: const ValueKey('home-month-score'),
                            color: ink,
                            fontSize: 12,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          minHeight: 6,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: dark ? 0.08 : 0.65,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wb_sunny_rounded,
                              size: 13,
                              color: Color(0xFFD99C62),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: _miniCardText(
                                L10nService().translateActiveDays(
                                  insight.activeDays,
                                ),
                                key: const ValueKey('home-month-active-days'),
                                color: muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
