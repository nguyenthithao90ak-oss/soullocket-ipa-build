part of '../single_match_hub_screen.dart';

class _SingleMatchWarningCard extends StatelessWidget {
  const _SingleMatchWarningCard({
    required this.enabled,
    required this.issues,
  });

  final bool enabled;
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty && enabled) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD9E5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFF4F87),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  !enabled
                      ? context.tr('match_bnangnkhip_3e5325')
                      : context.tr('match_hscnthiuvi_279a59'),
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF3B263E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  !enabled
                      ? context.tr('match_btlixuthin_f3af41')
                      : L10nService().format('match_current_issues', {
                          'issues': issues.join(', '),
                        }),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7E6C80),
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

class _SingleMatchActiveFiltersCard extends StatelessWidget {
  const _SingleMatchActiveFiltersCard({
    required this.current,
    required this.activeTags,
    required this.hasEnabledCallMode,
    required this.goalLabel,
    required this.voiceLabel,
    required this.callModesLabel,
  });

  final SingleMatchPreferences current;
  final List<String> activeTags;
  final bool hasEnabledCallMode;
  final String goalLabel;
  final String voiceLabel;
  final String callModesLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E7F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr('match_blcangpdng_69b445'),
            style: SLTheme.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF32203B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('match_singlematc_5ed97d'),
            style: SLTheme.quicksand(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7E6C80),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _SingleMatchFilterChip(
                icon: Icons.cake_outlined,
                label:
                    '${current.preferredAgeMin}-${current.preferredAgeMax} tuổi',
                foreground: const Color(0xFF7B4D92),
                background: const Color(0xFFF7EDFF),
              ),
              _SingleMatchFilterChip(
                icon: Icons.favorite_border_rounded,
                label: goalLabel,
                foreground: const Color(0xFFFF4F87),
                background: const Color(0xFFFFEEF4),
              ),
              _SingleMatchFilterChip(
                icon: Icons.record_voice_over_rounded,
                label: voiceLabel,
                foreground: const Color(0xFF4E7BF2),
                background: const Color(0xFFEFF4FF),
              ),
              _SingleMatchFilterChip(
                icon: current.allowVideoCalls
                    ? Icons.videocam_rounded
                    : Icons.call_rounded,
                label: hasEnabledCallMode
                    ? callModesLabel
                    : context.tr('match_chabtmodec_6c2e8e'),
                foreground: const Color(0xFF18B67A),
                background: const Color(0xFFEAFBF4),
              ),
              ...activeTags.take(4).map(
                    (tag) => _SingleMatchFilterChip(
                      icon: Icons.sell_rounded,
                      label: tag,
                      foreground: const Color(0xFF6C55CB),
                      background: const Color(0xFFF3F0FF),
                    ),
                  ),
            ],
          ),
          if (activeTags.isEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              context.tr('match_thm24tagst_3c9090'),
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF8A798E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SingleMatchFilterChip extends StatelessWidget {
  const _SingleMatchFilterChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxChipWidth = (screenWidth - 84).clamp(140.0, 320.0).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleMatchAdaptiveTagPill extends StatelessWidget {
  const _SingleMatchAdaptiveTagPill({
    required this.label,
    required this.background,
    required this.foreground,
    this.maxLines = 1,
  });

  final String label;
  final Color background;
  final Color foreground;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxChipWidth = (screenWidth - 84).clamp(140.0, 320.0).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _SingleMatchEmptyPoolCard extends StatelessWidget {
  const _SingleMatchEmptyPoolCard({
    required this.onEditProfile,
    required this.onOpenFilters,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFFFFD9E8),
                  Color(0xFFE4E1FF),
                ],
              ),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              size: 42,
              color: Color(0xFF7C61FF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('match_poolghpnia_bddb2a'),
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF32203B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('match_hinchachss_0c1fd9'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A7990),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.tune_rounded),
                label: Text(context.tr('match_sahscngkha_ee9e83')),
              ),
              FilledButton.icon(
                onPressed: onOpenFilters,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4F87),
                ),
                icon: const Icon(Icons.settings_rounded),
                label: Text(context.tr('match_niblc_d4b897')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleMatchSettingsSection extends StatelessWidget {
  const _SingleMatchSettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF32203B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A798E),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SingleMatchAvatarVisual extends StatelessWidget {
  const _SingleMatchAvatarVisual({
    required this.avatarUrl,
    required this.radius,
    required this.fallback,
  });

  final String avatarUrl;
  final double radius;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFFFFC3D6),
            Color(0xFFE5E2FF),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: ClipOval(
          child: avatarUrl.trim().isEmpty
              ? Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Text(
                    fallback.trim().isEmpty
                        ? '?'
                        : fallback.trim()[0].toUpperCase(),
                    style: SLTheme.quicksand(
                      fontSize: radius * 0.72,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF6E5A82),
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
                  maxWidthDiskCache: 720,
                  filterQuality: FilterQuality.medium,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_rounded,
                      size: radius,
                      color: const Color(0xFF6E5A82),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
