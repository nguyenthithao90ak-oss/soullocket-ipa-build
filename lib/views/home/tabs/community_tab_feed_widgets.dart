part of 'community_tab.dart';

class _FeedPostCard extends StatelessWidget {
  final _CommunityTabState state;
  final Map<String, dynamic> post;

  const _FeedPostCard({
    super.key,
    required this.state,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = state._formattedPostDate(post);
    final isAnon =
        (post['isAnon'] == true) || (post['isAnon']?.toString() == 'true');
    final isDeletedAuthor = post['isDeletedAuthor'] == true ||
        (post['isDeletedAuthor']?.toString() == 'true') ||
        (post['houseId'] ?? '').toString().trim().isEmpty;
    final postHouseId = (post['houseId'] ?? '').toString();
    final name = isDeletedAuthor
        ? _ct('Người dùng đã xóa', 'Deleted user')
        : isAnon
            ? _ct('Người lạ ẩn danh', 'Anonymous stranger')
            : (post['houseName']?.toString().trim().isNotEmpty ?? false)
                ? post['houseName'].toString()
                : _ct('Ngôi Nhà', 'Home');
    final avatar = (isAnon || isDeletedAuthor)
        ? ''
        : (post['houseAvt'] ?? post['authorAvt'] ?? '').toString();
    final content = state._sanitizedPostContent(post);
    final likes = state._getLikes(post);
    final isLikedByMe = state._isLikedByMe(post);
    final commentCount = state._getCommentCount(post);
    final shareCount = state._getShareCount(post);
    final views = (post['views'] is int) ? post['views'] as int : 0;
    final isVerified = post['verified'] == true;
    final primaryImageUrl = state._primaryFeedImageUrl(post);
    final videoUrl = (post['videoUrl'] ?? '').toString().trim();
    final privacy =
        (post['privacy'] ?? post['visibility'] ?? 'public').toString();
    final isFriend = !isAnon && !isDeletedAuthor && state._isFriend(postHouseId);
    final isBlocked =
        !isAnon && !isDeletedAuthor && state._blockedUsers[postHouseId] == true;
    final hasSentRequest =
        !isAnon && !isDeletedAuthor &&
        (state._sentFriendRequestIds[postHouseId]?.trim().isNotEmpty ?? false);
    final hasReceivedRequest =
        !isAnon && !isDeletedAuthor &&
        (state._receivedFriendRequestIds[postHouseId]?.trim().isNotEmpty ?? false);

    final privacyIcon = _communityPrivacyIcon(privacy);
    final isBookmarked =
        state._bookmarkedPostIds.contains((post['id'] ?? '').toString());
    final privacyLabel = _communityPrivacyLabel(privacy);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedPostHeader(
            state: state,
            post: post,
            isAnon: isAnon,
            isDeletedAuthor: isDeletedAuthor,
            postHouseId: postHouseId,
            avatar: avatar,
            name: name,
            isVerified: isVerified,
            privacyIcon: privacyIcon,
            privacyLabel: privacyLabel,
            formattedDate: formattedDate,
            isFriend: isFriend,
            isBlocked: isBlocked,
            hasSentRequest: hasSentRequest,
            hasReceivedRequest: hasReceivedRequest,
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: _RichPostText(
                text: content,
                style: SLTheme.quicksand(
                  fontSize: 15,
                  color: const Color(0xFF172033),
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ),
          if (primaryImageUrl.isNotEmpty)
            _FeedImagePreview(
              state: state,
              post: post,
              imageUrl: primaryImageUrl,
            ),
          if (videoUrl.isNotEmpty && primaryImageUrl.isEmpty)
            _FeedVideoPreview(
              state: state,
              post: post,
            ),
          _FeedPostStats(
            likes: likes,
            commentCount: commentCount,
            shareCount: shareCount,
            views: views,
          ),
          _FeedPostActionBar(
            state: state,
            post: post,
            isLikedByMe: isLikedByMe,
            isBookmarked: isBookmarked,
          ),
          if (commentCount > 0)
            _FeedPostCommentsLink(
              state: state,
              post: post,
              commentCount: commentCount,
            ),
        ],
      ),
    );
  }
}
