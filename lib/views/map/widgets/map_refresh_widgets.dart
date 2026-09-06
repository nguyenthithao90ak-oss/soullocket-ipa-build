import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../map_location_access.dart';

const mapRose = Color(0xFFB64F6C);
const mapBlue = Color(0xFF477DAD);

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
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: mapRose.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            single ? Icons.explore_outlined : Icons.favorite_outline,
            size: 23,
            color: mapRose,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr('map_refresh_subtitle'),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
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
    final colors = Theme.of(context).colorScheme;
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
    final accent = connected ? const Color(0xFF337C68) : mapRose;
    return Container(
      key: const ValueKey('map_access_notice'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: .07), colors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 21, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(titleKey),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
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
          const SizedBox(height: 7),
          Text(
            context.tr(bodyKey),
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
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
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: access.approximate && !web && onSettings != null
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
    final colors = Theme.of(context).colorScheme;
    final accent = isMe ? mapBlue : mapRose;
    final active = isLive && hasPosition;
    final status = context.tr(
      active
          ? 'map_refresh_live'
          : hasPosition
          ? 'map_refresh_last_position'
          : 'map_refresh_not_shared',
    );
    final sticker = Image.asset(
      'assets/images/soullocket_stickers/auth_gender_${role == 'user1' ? 'male' : 'female'}_v1.png',
      fit: BoxFit.contain,
      cacheWidth: 120,
      errorBuilder: (_, _, _) => Icon(Icons.person_outline, color: accent),
    );
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasPosition ? onFocus : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarUrl.trim().isEmpty
                    ? sticker
                    : Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        errorBuilder: (_, _, _) => sticker,
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
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          active ? Icons.circle : Icons.radio_button_unchecked,
                          size: 8,
                          color: active
                              ? const Color(0xFF337C68)
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              color: active
                                  ? const Color(0xFF337C68)
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasPosition) ...[
                      const SizedBox(height: 8),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        updated,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (accuracy != null && accuracy!.isFinite) ...[
                        const SizedBox(height: 4),
                        Text(
                          L10nService().format('map_refresh_accuracy', {
                            'meters': accuracy!.round().toString(),
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (hasPosition && onFocus != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 3),
                  child: Icon(Icons.near_me_outlined, size: 18, color: accent),
                ),
            ],
          ),
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
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: colors.onSurfaceVariant,
      leading: Icon(icon, color: mapRose, size: 21),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      children: [child],
    );
  }
}
