import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/sl_theme.dart';

const double kCommunitySettingsHeroRadius = 22;
const double kCommunitySettingsSectionRadius = 18;
const double kCommunitySettingsItemRadius = 10;
const double kCommunitySettingsIconRadius = 10;

class CommunitySettingsStatusChipData {
  final IconData icon;
  final String label;
  final bool active;

  const CommunitySettingsStatusChipData({
    required this.icon,
    required this.label,
    required this.active,
  });
}

class CommunitySettingsQuickInfoData {
  final IconData icon;
  final String title;
  final String value;

  const CommunitySettingsQuickInfoData({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class CommunitySettingsSectionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool floating;

  const CommunitySettingsSectionCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.children,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadiusGeometry? sectionRadius = floating
        ? BorderRadius.circular(kCommunitySettingsSectionRadius)
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, floating ? 18 : 20, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: sectionRadius,
        border: floating ? Border.all(color: const Color(0xFFE7ECF4)) : null,
        boxShadow: floating
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(kCommunitySettingsIconRadius),
                ),
                child: Icon(icon, color: accent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        height: 1.45,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class CommunitySettingsInputCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const CommunitySettingsInputCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: SLColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 12.5,
              height: 1.45,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class CommunitySettingsTextFieldCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final String? hintText;
  final String? prefixText;
  final int maxLines;
  final int? maxLength;

  const CommunitySettingsTextFieldCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.controller,
    this.hintText,
    this.prefixText,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return CommunitySettingsInputCard(
      title: title,
      subtitle: subtitle,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w700,
          color: SLColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          prefixText: prefixText,
          prefixStyle: SLTheme.quicksand(
            color: SLColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
          hintStyle: SLTheme.quicksand(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          counterStyle: SLTheme.quicksand(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class CommunitySettingsDropdownCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const CommunitySettingsDropdownCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CommunitySettingsInputCard(
      title: title,
      subtitle: subtitle,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF64748B),
        ),
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w700,
          color: SLColors.textPrimary,
          fontSize: 14,
        ),
        dropdownColor: Colors.white,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }
}

class CommunitySettingsToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const CommunitySettingsToggleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        height: 1.45,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: value,
                activeThumbColor: SLColors.primary,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunitySettingsInfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const CommunitySettingsInfoBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(kCommunitySettingsIconRadius),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SLColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    height: 1.5,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommunitySettingsSubsectionTitle extends StatelessWidget {
  final String title;

  const CommunitySettingsSubsectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        title,
        style: SLTheme.quicksand(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }
}

class CommunitySettingsStatusOverview extends StatelessWidget {
  final List<CommunitySettingsStatusChipData> items;

  const CommunitySettingsStatusOverview({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: item.active
                      ? const Color(0xFFFFE8EF)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 15,
                      color: item.active
                          ? SLColors.primary
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: item.active
                            ? SLColors.primary
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class CommunitySettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const CommunitySettingsActionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(kCommunitySettingsIconRadius),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  height: 1.45,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunitySettingsHeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const CommunitySettingsHeroChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class CommunitySettingsHeroMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const CommunitySettingsHeroMetricChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class CommunitySettingsAvatarPreview extends StatelessWidget {
  final String avatarUrl;
  final String fallbackText;

  const CommunitySettingsAvatarPreview({
    super.key,
    required this.avatarUrl,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFFB0C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: avatarUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorWidget: (_, __, ___) =>
                      _CommunitySettingsAvatarFallback(text: fallbackText),
                )
              : _CommunitySettingsAvatarFallback(text: fallbackText),
        ),
      ),
    );
  }
}

class CommunitySettingsQuickInfoTile extends StatelessWidget {
  final CommunitySettingsQuickInfoData item;

  const CommunitySettingsQuickInfoTile({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(kCommunitySettingsItemRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 18, color: SLColors.primary),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SLColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunitySettingsAvatarFallback extends StatelessWidget {
  final String text;

  const _CommunitySettingsAvatarFallback({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFD2DE), Color(0xFFFF9FBA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: SLTheme.quicksand(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
