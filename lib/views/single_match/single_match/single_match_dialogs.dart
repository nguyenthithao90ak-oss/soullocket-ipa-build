part of '../single_match_hub_screen.dart';

class _MatchReadySheet extends StatelessWidget {
  const _MatchReadySheet({
    required this.scored,
    required this.goalLabel,
    required this.voiceLabel,
    required this.onOpenProfile,
    required this.onAudioCall,
    required this.onVideoCall,
  });

  final _ScoredCandidate scored;
  final String goalLabel;
  final String voiceLabel;
  final VoidCallback onOpenProfile;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;

  @override
  Widget build(BuildContext context) {
    final candidate = scored.candidate;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF201928),
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFFFFE0EC),
              backgroundImage: candidate.avatarUrl.trim().isEmpty
                  ? null
                  : CachedNetworkImageProvider(candidate.avatarUrl),
              child: candidate.avatarUrl.trim().isEmpty
                  ? Text(
                      candidate.displayName.isEmpty
                          ? '?'
                          : candidate.displayName[0].toUpperCase(),
                      style: SLTheme.quicksand(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6E5A82),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              candidate.displayName,
              style: SLTheme.quicksand(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${scored.score.toStringAsFixed(0)}% match • $goalLabel • $voiceLabel',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              candidate.intro.trim().isNotEmpty
                  ? candidate.intro
                  : (candidate.bio.trim().isEmpty
                      ? 'Bạn có thể mở hồ sơ hoặc gọi ngay để bắt đầu cuộc trò chuyện đầu tiên.'
                      : candidate.bio),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.88),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenProfile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.24)),
                    ),
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text(
                      'Mở hồ sơ',
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
                      backgroundColor: const Color(0xFFFF4F87),
                    ),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text(
                      'Thoại',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onVideoCall,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C61FF),
                ),
                icon: const Icon(Icons.videocam_rounded),
                label: const Text(
                  'Gọi video ngay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
