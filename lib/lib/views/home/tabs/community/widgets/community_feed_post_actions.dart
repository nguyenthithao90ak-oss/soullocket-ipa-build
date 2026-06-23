part of '../../community_tab.dart';

class _FeedPostStats extends StatelessWidget {
  final int likes;
  final int commentCount;
  final int shareCount;
  final int views;

  const _FeedPostStats({
    required this.likes,
    required this.commentCount,
    required this.shareCount,
    required this.views,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: const Color(0xFFE91E63).withValues(alpha: 0.82),
                    size: 16,
                  ),
                  SLSpacing.w8,
                  Text(
                    _ctf(
                      '{count} lượt thích',
                      '{count} likes',
                      {'count': likes},
                    ),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              Text(
                _ctf(
                  '{count} bình luận',
                  '{count} comments',
                  {'count': commentCount},
                ),
                style: SLTheme.quicksand(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                _ctf(
                  '{count} chia sẻ',
                  '{count} shares',
                  {'count': shareCount},
                ),
                style: SLTheme.quicksand(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (views > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _ctf(
                '{count} lượt xem',
                '{count} views',
                {'count': views},
              ),
              style: SLTheme.quicksand(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w700,
                fontSize: 11.6,
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedPostActionBar extends StatelessWidget {
  final _CommunityTabState state;
  final Map<String, dynamic> post;
  final bool isLikedByMe;
  final bool isBookmarked;

  const _FeedPostActionBar({
    required this.state,
    required this.post,
    required this.isLikedByMe,
    required this.isBookmarked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (ctx) => _FeedActionButton(
                state: state,
                icon: isLikedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: _ct(context.tr('home_thch_436ce5'), 'Like'),
                active: isLikedByMe,
                disabled: state._isLikePending(post),
                onTap: () {
                  final box = ctx.findRenderObject() as RenderBox?;
                  final pos = box?.localToGlobal(Offset.zero);
                  state._toggleLike(post, position: pos);
                },
              ),
            ),
          ),
          SLSpacing.w8,
          Expanded(
            child: _FeedActionButton(
              state: state,
              icon: Icons.mode_comment_outlined,
              label: _ct(context.tr('home_bnhlun_6412d9'), 'Comment'),
              onTap: () => state._openComments(post),
            ),
          ),
          SLSpacing.w8,
          Expanded(
            child: _FeedActionButton(
              state: state,
              icon: Icons.share_outlined,
              label: _ct(context.tr('home_chias_569031'), 'Share'),
              onTap: () => state._sharePost(post),
            ),
          ),
          SLSpacing.w8,
          _FeedBookmarkButton(
            state: state,
            post: post,
            isBookmarked: isBookmarked,
          ),
        ],
      ),
    );
  }
}

class _FeedBookmarkButton extends StatelessWidget {
  final _CommunityTabState state;
  final Map<String, dynamic> post;
  final bool isBookmarked;

  const _FeedBookmarkButton({
    required this.state,
    required this.post,
    required this.isBookmarked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => state._toggleBookmark(post),
      borderRadius: SLRadius.lgAll,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              isBookmarked ? const Color(0xFF3A2028) : const Color(0xFF3A3B3C),
          borderRadius: SLRadius.lgAll,
        ),
        child: Icon(
          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: isBookmarked ? const Color(0xFFD81B60) : Colors.grey[400],
          size: 22,
        ),
      ),
    );
  }
}

class _FeedPostCommentsLink extends StatelessWidget {
  final _CommunityTabState state;
  final Map<String, dynamic> post;
  final int commentCount;

  const _FeedPostCommentsLink({
    required this.state,
    required this.post,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: InkWell(
        onTap: () => state._openComments(post),
        borderRadius: SLRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            _ctf(
              'Xem tất cả {count} bình luận',
              'View all {count} comments',
              {'count': commentCount},
            ),
            style: SLTheme.quicksand(
              color: Colors.grey[400],
              fontWeight: FontWeight.w800,
              fontSize: 12.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  final _CommunityTabState state;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool disabled;

  const _FeedActionButton({
    required this.state,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFD81B60) : state._subTextColor;
    final foregroundOpacity = disabled ? 0.72 : 1.0;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: SLRadius.lgAll,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: active
              ? (state._isLight
                  ? const Color(0xFFFFE6F0)
                  : const Color(0xFF3A2028))
              : state._actionBgColor,
          borderRadius: SLRadius.lgAll,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: color.withValues(alpha: foregroundOpacity),
            ),
            SLSpacing.w8,
            Text(
              label,
              style: SLTheme.quicksand(
                color: color.withValues(alpha: foregroundOpacity),
                fontSize: 12.6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
