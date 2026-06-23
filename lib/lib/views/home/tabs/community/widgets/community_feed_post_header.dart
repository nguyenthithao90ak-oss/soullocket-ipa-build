part of '../../community_tab.dart';

class _FeedPostHeader extends StatelessWidget {
  final _CommunityTabState state;
  final Map<String, dynamic> post;
  final bool isAnon;
  final bool isDeletedAuthor;
  final String postHouseId;
  final String avatar;
  final String name;
  final bool isVerified;
  final IconData privacyIcon;
  final String privacyLabel;
  final String formattedDate;
  final bool isFriend;
  final bool isBlocked;
  final bool hasSentRequest;
  final bool hasReceivedRequest;

  const _FeedPostHeader({
    required this.state,
    required this.post,
    required this.isAnon,
    required this.isDeletedAuthor,
    required this.postHouseId,
    required this.avatar,
    required this.name,
    required this.isVerified,
    required this.privacyIcon,
    required this.privacyLabel,
    required this.formattedDate,
    required this.isFriend,
    required this.isBlocked,
    required this.hasSentRequest,
    required this.hasReceivedRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isAnon || isDeletedAuthor || postHouseId.isEmpty) {
                  if (!state.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isDeletedAuthor
                            ? _ct(
                                context.tr('home_tikhonnybx_58cc38'),
                                'This account has been deleted.',
                              )
                            : _ct(
                                context.tr('home_ngidngnych_cd2f2f'),
                                'This user chose to stay anonymous.',
                              ),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VisitorProfileScreen(
                      targetHouseId: postHouseId,
                    ),
                  ),
                );

                if (state._houseId != null && postHouseId != state._houseId) {
                  RecommendationService().recordInteraction(
                    houseId: postHouseId,
                    mood: (post['moodLabel'] ?? post['mood'] ?? '').toString(),
                    weight: 2.0,
                  );
                }
              },
              child: Row(
                children: [
                  state._buildCommunityAuthorAvatar(
                    avatarUrl: avatar,
                    isAnon: isAnon,
                    disableThemedBorder: isDeletedAuthor,
                  ),
                  SLSpacing.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF172033),
                                ),
                              ),
                            ),
                            if (isVerified) ...[
                              SLSpacing.w4,
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF3B82F6),
                                size: 13.5,
                              ),
                            ],
                          ],
                        ),
                        SLSpacing.gapH(1.5),
                        Row(
                          children: [
                            Icon(
                              privacyIcon,
                              size: 10.5,
                              color: const Color(0xFF5B667A),
                            ),
                            SLSpacing.w4,
                            Expanded(
                              child: Text(
                                '$privacyLabel • $formattedDate',
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  color: const Color(0xFF5B667A),
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isBlocked ||
                            hasReceivedRequest ||
                            hasSentRequest ||
                            isFriend) ...[
                          SLSpacing.gapH(6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (isBlocked)
                                _FeedRelationshipBadge(
                                  label: _ct(context.tr('home_chn_7c554a'), 'Blocked'),
                                  icon: Icons.block_rounded,
                                  backgroundColor: const Color(0xFFFEE2E2),
                                  foregroundColor: const Color(0xFFB91C1C),
                                )
                              else if (hasReceivedRequest)
                                _FeedRelationshipBadge(
                                  label: _ct(context.tr('home_chbnduyt_112763'), 'Waiting for you'),
                                  icon: Icons.mark_email_unread_rounded,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  foregroundColor: const Color(0xFF1D4ED8),
                                )
                              else if (hasSentRequest)
                                _FeedRelationshipBadge(
                                  label: _ct(context.tr('home_gilimi_707fc7'), 'Invite sent'),
                                  icon: Icons.schedule_send_rounded,
                                  backgroundColor: const Color(0xFFEDE9FE),
                                  foregroundColor: const Color(0xFF6D28D9),
                                )
                              else if (isFriend)
                                _FeedRelationshipBadge(
                                  label: _ct(context.tr('home_bnb_411da0'), 'Friends'),
                                  icon: Icons.people_alt_rounded,
                                  backgroundColor: const Color(0xFFDCFCE7),
                                  foregroundColor: const Color(0xFF15803D),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SLSpacing.w8,
          InkWell(
            onTap: () => state._openMoreActions(post),
            borderRadius: SLRadius.mdAll,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: SLRadius.mdAll,
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF5B667A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedRelationshipBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _FeedRelationshipBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foregroundColor),
          SLSpacing.w4,
          Text(
            label,
            style: SLTheme.quicksand(
              color: foregroundColor,
              fontSize: 10.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
