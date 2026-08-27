part of '../single_match_hub_screen.dart';

class _SingleMatchFeaturedCard extends StatelessWidget {
  const _SingleMatchFeaturedCard({
    required this.scored,
    required this.totalPool,
    required this.seenCount,
    required this.callingThisCard,
    required this.goalLabel,
    required this.voiceLabel,
    required this.onSpin,
    required this.onOpenProfile,
    required this.onAudioCall,
    required this.onVideoCall,
  });

  final _ScoredCandidate scored;
  final int totalPool;
  final int seenCount;
  final bool callingThisCard;
  final String goalLabel;
  final String voiceLabel;
  final VoidCallback onSpin;
  final VoidCallback onOpenProfile;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;

  @override
  Widget build(BuildContext context) {
    final candidate = scored.candidate;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF25152C),
            Color(0xFF452F64),
            Color(0xFF7B5BFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.tr('match_topmatchhm_627788'),
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$totalPool hồ sơ • đã xem $seenCount',
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SingleMatchAvatarVisual(
                avatarUrl: candidate.avatarUrl,
                radius: 32,
                fallback: candidate.displayName,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            candidate.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            '${scored.score.toStringAsFixed(0)}%',
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (candidate.age != null) '${candidate.age} tuổi',
                        goalLabel,
                        voiceLabel,
                      ].join(' • '),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scored.previewText.isNotEmpty
                          ? scored.previewText
                          : context.tr('match_hsnychavit_4cf5c5'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (scored.reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: scored.reasons
                  .map(
                    (reason) => _SingleMatchAdaptiveTagPill(
                      label: reason,
                      background: Colors.white.withValues(alpha: 0.12),
                      foreground: Colors.white,
                      maxLines: 2,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: callingThisCard ? null : onSpin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: Text(
                    context.tr('match_ghpngunhin_1ee82f'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAudioCall,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3B2355),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: callingThisCard
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.call_rounded),
                  label: Text(
                    callingThisCard
                        ? context.tr('match_anggi_fc34f1')
                        : context.tr('match_githoi_ad3e35'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  onPressed: onOpenProfile,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.person_search_rounded),
                  label: Text(
                    context.tr('match_xemhs_586b32'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onVideoCall,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text(
                    'Video call',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleMatchStatStrip extends StatelessWidget {
  const _SingleMatchStatStrip({
    required this.totalCandidates,
    required this.callCount,
    required this.skipCount,
    required this.avgScore,
  });

  final int totalCandidates;
  final int callCount;
  final int skipCount;
  final double avgScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            label: 'Pool live',
            value: '$totalCandidates',
            icon: Icons.flash_on_rounded,
            color: const Color(0xFFFF5E8C),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: context.tr('match_gi_4f3cf0'),
            value: '$callCount',
            icon: Icons.call_rounded,
            color: const Color(0xFF5B8DEF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: context.tr('match_ltqua_a653f5'),
            value: '$skipCount',
            icon: Icons.swipe_left_rounded,
            color: const Color(0xFF18B67A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: context.tr('match_imtb_74dd5d'),
            value: avgScore <= 0 ? '--' : avgScore.toStringAsFixed(0),
            icon: Icons.insights_rounded,
            color: const Color(0xFF8A61FF),
          ),
        ),
      ],
    );
  }
}

class _SingleMatchCandidateCard extends StatelessWidget {
  const _SingleMatchCandidateCard({
    required this.scored,
    required this.callingThisCard,
    required this.goalLabel,
    required this.voiceLabel,
    required this.onSkip,
    required this.onOpenProfile,
    required this.onAudioCall,
  });

  final _ScoredCandidate scored;
  final bool callingThisCard;
  final String goalLabel;
  final String voiceLabel;
  final VoidCallback onSkip;
  final VoidCallback onOpenProfile;
  final VoidCallback? onAudioCall;

  @override
  Widget build(BuildContext context) {
    final candidate = scored.candidate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SingleMatchAvatarVisual(
                  avatarUrl: candidate.avatarUrl,
                  radius: 28,
                  fallback: candidate.displayName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              candidate.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF32203B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF2F5),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFFFD6E0)),
                            ),
                            child: Text(
                              '${scored.score.toStringAsFixed(0)}%',
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFF5E7E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (candidate.age != null) '${candidate.age} tuổi',
                          goalLabel,
                          voiceLabel,
                        ].join(' • '),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8A798E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        candidate.intro.trim().isNotEmpty
                            ? candidate.intro
                            : (candidate.bio.trim().isEmpty
                                ? context.tr('match_hschacintr_ecc784')
                                : candidate.bio),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF53435A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (candidate.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: candidate.tags
                      .take(4)
                      .map(
                        (tag) => _SingleMatchAdaptiveTagPill(
                          label: tag,
                          background: const Color(0xFFF6F2FF),
                          foreground: const Color(0xFF6C55CB),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            if (scored.reasons.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  scored.reasons.join(' • '),
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8A798E),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: callingThisCard ? null : onSkip,
                    icon: const Icon(Icons.swipe_left_rounded, size: 18),
                    label: Text(
                      context.tr('match_bqua_a3b533'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenProfile,
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                    label: Text(
                      context.tr('match_hs_be0945'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAudioCall,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5E7E),
                    ),
                    icon: callingThisCard
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.call_rounded, size: 18),
                    label: Text(
                      context.tr('match_gi_7c0807'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF30203B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8A798E),
            ),
          ),
        ],
      ),
    );
  }
}
