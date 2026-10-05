import 'package:flutter/material.dart';

import 'keepsake_design.dart';

class DeviceManagerStyle {
  static Color statusColor(BuildContext context, String? status) {
    final dark = KeepsakeStyle.dark(context);
    switch (status) {
      case 'approved':
      case 'auto_approved':
        return dark ? const Color(0xFFB6CEAD) : const Color(0xFF526B4E);
      case 'blocked':
      case 'deleted':
        return dark ? const Color(0xFFF0B0A9) : const Color(0xFF994A43);
      case 'pending':
        return dark ? const Color(0xFFE6C48E) : const Color(0xFF86632C);
      default:
        return KeepsakeStyle.muted(context);
    }
  }

  static IconData statusIcon(String? status) {
    switch (status) {
      case 'approved':
      case 'auto_approved':
        return Icons.check_circle_outline_rounded;
      case 'blocked':
      case 'deleted':
        return Icons.block_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'local_only':
        return Icons.smartphone_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class DeviceStatusBadge extends StatelessWidget {
  const DeviceStatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: KeepsakeStyle.dark(context) ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: KeepsakeStyle.text(
              context,
              size: 11,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class DeviceRegistryNotice extends StatelessWidget {
  const DeviceRegistryNotice({
    super.key,
    required this.message,
    this.title,
    this.detail,
    this.syncing = false,
    this.failed = false,
  });

  final String message;
  final String? title;
  final String? detail;
  final bool syncing;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed
        ? DeviceManagerStyle.statusColor(context, 'pending')
        : KeepsakeStyle.muted(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: failed
            ? color.withValues(alpha: 0.08)
            : KeepsakeStyle.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepsakeStyle.line(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              failed ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: KeepsakeStyle.text(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (detail != null) ...[
                  Text(
                    detail!,
                    style: KeepsakeStyle.text(context, size: 12, color: color),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  style: KeepsakeStyle.text(
                    context,
                    size: 12,
                    color: KeepsakeStyle.muted(context),
                  ),
                ),
                if (syncing) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: KeepsakeStyle.accent(context),
                      backgroundColor: KeepsakeStyle.accentSurface(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceInformationRow extends StatelessWidget {
  const DeviceInformationRow({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(icon, size: 16, color: KeepsakeStyle.muted(context)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: KeepsakeStyle.text(
              context,
              size: 12,
              color: KeepsakeStyle.muted(context),
            ),
          ),
        ),
      ],
    ),
  );
}

class DeviceRegistryCard extends StatelessWidget {
  const DeviceRegistryCard({
    super.key,
    required this.deviceId,
    required this.model,
    required this.os,
    required this.platformIcon,
    required this.badges,
    required this.details,
    this.current = false,
  });

  final String deviceId;
  final String model;
  final String os;
  final IconData platformIcon;
  final List<Widget> badges;
  final List<Widget> details;
  final bool current;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: KeepsakeStyle.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: KeepsakeStyle.line(context)),
    ),
    child: Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('device-tile-$deviceId'),
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 7, 10, 7),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: KeepsakeStyle.accent(context),
          collapsedIconColor: KeepsakeStyle.muted(context),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: current
                          ? KeepsakeStyle.accentSurface(context)
                          : KeepsakeStyle.canvas(context),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      platformIcon,
                      size: 23,
                      color: current
                          ? KeepsakeStyle.accent(context)
                          : KeepsakeStyle.muted(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model,
                          style: KeepsakeStyle.text(
                            context,
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (os.trim().isNotEmpty)
                          Text(
                            os,
                            style: KeepsakeStyle.text(
                              context,
                              size: 12,
                              color: KeepsakeStyle.muted(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: badges),
            ],
          ),
          children: [
            Divider(height: 22, color: KeepsakeStyle.line(context)),
            ...details,
          ],
        ),
      ),
    ),
  );
}
