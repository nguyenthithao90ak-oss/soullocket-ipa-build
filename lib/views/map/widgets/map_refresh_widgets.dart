import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../map_location_access.dart';

const mapRose = Color(0xFFB64F6C);
const mapBlue = Color(0xFF477DAD);
const mapSage = Color(0xFF397963);
const mapLavender = Color(0xFF7866A1);

/// Thanh điều hướng chung: không tạo một khối nền riêng cho từng nút.
class MapNavigationBar extends StatelessWidget {
  const MapNavigationBar({
    super.key,
    required this.onBack,
    required this.onSearch,
    this.helpButton,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final Widget? helpButton;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Material(
      color: palette.surface,
      elevation: 3,
      shadowColor: palette.ink.withValues(alpha: .10),
      shape: StadiumBorder(
        side: BorderSide(color: palette.border.withValues(alpha: .75)),
      ),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: palette.muted,
                backgroundColor: Colors.transparent,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                iconSize: 20,
                shape: const CircleBorder(),
              ),
            ),
            child: Row(
              children: [
                MapToolbarButton(
                  key: const ValueKey('map_back_button'),
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  flat: true,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      context.tr('map_refresh_nav_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ),
                if (helpButton != null)
                  SizedBox(width: 48, height: 48, child: helpButton!),
                MapToolbarButton(
                  key: const ValueKey('map_search_button'),
                  icon: Icons.search_rounded,
                  tooltip: context.tr('map_search_place_tooltip'),
                  onPressed: onSearch,
                  flat: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MapToolbarButton extends StatelessWidget {
  const MapToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = mapSage,
    this.primary = false,
    this.flat = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color accent;
  final bool primary;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: flat
              ? Colors.transparent
              : primary
              ? accent
              : palette.surface,
          foregroundColor: primary && !flat
              ? Colors.white
              : palette.accent(accent),
          disabledBackgroundColor: flat ? Colors.transparent : palette.surface,
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          shape: flat
              ? const CircleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: primary ? accent : palette.border),
                ),
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

/// Thẻ trạng thái nhỏ, nền đặc: không cần blur toàn bộ lớp bản đồ phía sau.
class MapStatusPill extends StatelessWidget {
  const MapStatusPill({
    super.key,
    required this.icon,
    required this.label,
    this.accent = mapSage,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: palette.accent(accent)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapInlineEmptyState extends StatelessWidget {
  const MapInlineEmptyState({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.tint(accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: palette.accent(accent), size: 26),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.5, color: palette.muted),
          ),
          if (onTap != null && actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.accent(accent),
                minimumSize: const Size(48, 48),
                side: BorderSide(color: accent.withValues(alpha: .3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text(actionLabel!, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}

class MapDistanceCard extends StatelessWidget {
  const MapDistanceCard({
    super.key,
    required this.distance,
    required this.live,
    required this.routeDistance,
    required this.eta,
  });

  final String distance;
  final bool live;
  final String routeDistance;
  final String eta;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.tint(mapSage),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 18,
                color: palette.accent(mapRose),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('map_refresh_apart'),
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            distance,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              live
                  ? 'map_refresh_straight_distance'
                  : 'map_refresh_stale_distance',
            ),
            style: TextStyle(fontSize: 11.5, height: 1.4, color: palette.muted),
          ),
          if (eta != '--') ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.border),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _metric(
                    context,
                    Icons.route_outlined,
                    'map_refresh_route',
                    routeDistance,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metric(
                    context,
                    Icons.schedule_rounded,
                    'map_refresh_eta',
                    eta,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final palette = MapPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: palette.accent(mapSage)),
        const SizedBox(height: 5),
        Text(
          context.tr(label),
          style: TextStyle(fontSize: 10.5, color: palette.muted),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
      ],
    );
  }
}

/// Bảng màu riêng của bản đồ; không phụ thuộc nền kem của các màn tiện ích.
class MapPalette {
  const MapPalette(this.dark);

  factory MapPalette.of(BuildContext context) =>
      MapPalette(Theme.of(context).brightness == Brightness.dark);

  final bool dark;

  Color get canvas => dark ? const Color(0xFF15221E) : const Color(0xFFEDF4EF);
  Color get surface => dark ? const Color(0xFF20312A) : const Color(0xFFFCFEFC);
  Color get ink => dark ? const Color(0xFFF0F6F2) : const Color(0xFF253F35);
  Color get muted => dark ? const Color(0xFFB0C5B9) : const Color(0xFF657C70);
  Color get border => dark ? const Color(0xFF354A3F) : const Color(0xFFD9E6DD);

  Color accent(Color color) =>
      dark ? Color.lerp(color, Colors.white, .35)! : color;
  Color tint(Color color) =>
      Color.alphaBlend(color.withValues(alpha: dark ? .16 : .08), surface);
}

class MapSlidingPanel extends StatelessWidget {
  const MapSlidingPanel({
    super.key,
    required this.controller,
    required this.extent,
    required this.single,
    required this.onToggle,
    required this.children,
  });

  final DraggableScrollableController controller;
  final ValueNotifier<double> extent;
  final bool single;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final headingHeight =
        (82 + (MediaQuery.textScalerOf(context).scale(18) - 18) * 4)
            .clamp(82.0, 164.0)
            .toDouble();
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        extent.value = notification.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        controller: controller,
        initialChildSize: .42,
        minChildSize: .20,
        maxChildSize: .84,
        snap: true,
        snapSizes: const [.20, .42, .84],
        builder: (context, scrollController) => Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .10),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: palette.border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Tiêu đề và nút thu bảng vẫn nhìn thấy khi cuộn nội dung.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MapPanelHeadingDelegate(
                        height: headingHeight,
                        child: ColoredBox(
                          color: palette.canvas,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: ValueListenableBuilder<double>(
                              valueListenable: extent,
                              builder: (context, value, _) => MapPanelHeading(
                                single: single,
                                expanded: value > .55,
                                onToggle: onToggle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      sliver: SliverList.list(children: children),
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

class _MapPanelHeadingDelegate extends SliverPersistentHeaderDelegate {
  const _MapPanelHeadingDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_MapPanelHeadingDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

class MapPanelHeading extends StatelessWidget {
  const MapPanelHeading({
    super.key,
    required this.single,
    required this.expanded,
    required this.onToggle,
  });

  final bool single;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.tint(mapSage),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            single ? Icons.explore_outlined : Icons.favorite_outline,
            size: 23,
            color: palette.accent(mapSage),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  single ? 'map_refresh_title_single' : 'map_refresh_title',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr('map_refresh_subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: palette.muted),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('map_panel_toggle'),
          tooltip: context.tr(
            expanded ? 'map_refresh_collapse' : 'map_refresh_expand',
          ),
          onPressed: onToggle,
          style: IconButton.styleFrom(
            foregroundColor: palette.ink,
            backgroundColor: palette.surface,
            minimumSize: const Size(48, 48),
            side: BorderSide(color: palette.border),
          ),
          icon: Icon(
            expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
          ),
        ),
      ],
    );
  }
}

class MapAccessNotice extends StatelessWidget {
  const MapAccessNotice({
    super.key,
    required this.access,
    required this.busy,
    required this.hasLivePosition,
    required this.onAction,
    this.web = false,
    this.syncError = false,
    this.onSettings,
  });

  final MapLocationAccess access;
  final bool busy;
  final bool hasLivePosition;
  final bool web;
  final bool syncError;
  final VoidCallback onAction;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final status = access.status;
    final connected = access.canTrack && hasLivePosition && !syncError;
    final String titleKey;
    final String bodyKey;
    final String actionKey;
    final IconData icon;
    if (busy || status == MapLocationAccessStatus.checking) {
      titleKey = 'map_refresh_checking';
      bodyKey = 'map_refresh_checking_body';
      actionKey = 'map_refresh_retry';
      icon = Icons.gps_not_fixed_rounded;
    } else if (status == MapLocationAccessStatus.serviceDisabled) {
      titleKey = 'map_refresh_service_off';
      bodyKey = 'map_refresh_service_off_body';
      actionKey = 'map_refresh_open_gps';
      icon = Icons.location_disabled_outlined;
    } else if (status == MapLocationAccessStatus.deniedForever) {
      titleKey = 'map_refresh_permission_blocked';
      bodyKey = web
          ? 'map_refresh_browser_body'
          : 'map_refresh_permission_blocked_body';
      actionKey = web ? 'map_refresh_retry' : 'map_refresh_open_settings';
      icon = Icons.lock_outline_rounded;
    } else if (status == MapLocationAccessStatus.permissionRequired) {
      titleKey = 'map_refresh_permission_title';
      bodyKey = web
          ? 'map_refresh_browser_body'
          : 'map_refresh_permission_body';
      actionKey = 'map_refresh_allow_location';
      icon = Icons.location_on_outlined;
    } else if (status == MapLocationAccessStatus.unavailable || syncError) {
      titleKey = 'map_refresh_unavailable';
      bodyKey = 'map_refresh_unavailable_body';
      actionKey = 'map_refresh_retry';
      icon = Icons.cloud_off_outlined;
    } else if (access.approximate) {
      titleKey = 'map_refresh_approximate';
      bodyKey = 'map_refresh_approximate_body';
      actionKey = web ? 'map_refresh_retry' : 'map_refresh_open_settings';
      icon = Icons.location_searching_rounded;
    } else if (connected) {
      titleKey = 'map_refresh_sharing';
      bodyKey = 'map_refresh_sharing_body';
      actionKey = 'map_refresh_open_settings';
      icon = Icons.verified_user_outlined;
    } else {
      titleKey = 'map_refresh_waiting';
      bodyKey = 'map_refresh_waiting_body';
      actionKey = 'map_refresh_retry';
      icon = Icons.gps_not_fixed_rounded;
    }
    final pending = busy || status == MapLocationAccessStatus.checking;
    final waiting = status == MapLocationAccessStatus.ready && !syncError;
    final needsPermission =
        status == MapLocationAccessStatus.permissionRequired ||
        status == MapLocationAccessStatus.deniedForever;
    final baseAccent = connected
        ? mapSage
        : pending || waiting
        ? mapBlue
        : needsPermission
        ? const Color(0xFF956C35)
        : mapRose;
    final accent = palette.accent(baseAccent);
    return Container(
      key: const ValueKey('map_access_notice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.tint(baseAccent),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(titleKey),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(bodyKey),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
              ],
            ],
          ),
          if (!connected &&
              !busy &&
              status != MapLocationAccessStatus.checking) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('map_access_action'),
                style: FilledButton.styleFrom(
                  backgroundColor: baseAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed:
                    actionKey == 'map_refresh_open_settings' &&
                        !web &&
                        onSettings != null
                    ? onSettings
                    : onAction,
                icon: Icon(icon, size: 18),
                label: Text(context.tr(actionKey), textAlign: TextAlign.center),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MapPersonTile extends StatelessWidget {
  const MapPersonTile({
    super.key,
    required this.name,
    required this.isMe,
    required this.role,
    required this.avatarUrl,
    required this.isLive,
    required this.hasPosition,
    required this.address,
    required this.updated,
    this.onFocus,
    this.accuracy,
  });

  final String name;
  final bool isMe;
  final String role;
  final String avatarUrl;
  final bool isLive;
  final bool hasPosition;
  final String address;
  final String updated;
  final VoidCallback? onFocus;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final baseAccent = isMe ? mapBlue : mapRose;
    final accent = palette.accent(baseAccent);
    final active = isLive && hasPosition;
    final status = context.tr(
      active
          ? 'map_refresh_live'
          : hasPosition
          ? 'map_refresh_last_position'
          : 'map_refresh_not_shared',
    );
    final sticker = Image.asset(
      'assets/images/soullocket_stickers/auth_gender_${role == 'user1' ? 'male' : 'female'}_v1.webp',
      fit: BoxFit.contain,
      cacheWidth: 120,
      errorBuilder: (_, _, _) => Icon(Icons.person_outline, color: accent),
    );
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasPosition ? onFocus : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: palette.tint(baseAccent),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: .18),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: avatarUrl.trim().isEmpty
                                ? sticker
                                : CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 120,
                                    maxWidthDiskCache: 240,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, _) => sticker,
                                    errorWidget: (_, _, _) => sticker,
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? mapSage : palette.muted,
                              border: Border.all(
                                color: palette.surface,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe
                              ? L10nService().format('map_refresh_me_name', {
                                  'name': name,
                                })
                              : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? palette.accent(mapSage)
                                : palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasPosition && onFocus != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Icon(
                        Icons.near_me_outlined,
                        size: 20,
                        color: accent,
                      ),
                    ),
                ],
              ),
            ),
            if (hasPosition)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.tint(baseAccent),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          updated,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: palette.muted,
                          ),
                        ),
                        if (accuracy != null && accuracy!.isFinite)
                          Text(
                            L10nService().format('map_refresh_accuracy', {
                              'meters': accuracy!.round().toString(),
                            }),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: palette.muted,
                            ),
                          ),
                      ],
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

class MapDetailsSection extends StatelessWidget {
  const MapDetailsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accent = mapSage,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: palette.border),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: PageStorageKey(title),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: shape,
        collapsedShape: shape,
        backgroundColor: palette.surface,
        collapsedBackgroundColor: palette.surface,
        iconColor: palette.muted,
        collapsedIconColor: palette.muted,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.tint(accent),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: palette.accent(accent), size: 19),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        children: [child],
      ),
    );
  }
}
