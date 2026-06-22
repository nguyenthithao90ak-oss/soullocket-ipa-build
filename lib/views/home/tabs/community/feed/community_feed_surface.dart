part of '../../community_tab.dart';

extension _CommunityFeedSurface on _CommunityTabState {
  static const String _feedPostItemKeyPrefix = 'community-feed-post-';

  int? _findFeedListChildIndex(
    Key key,
    List<Map<String, dynamic>> posts,
  ) {
    if (key is! ValueKey<String>) {
      return null;
    }
    final value = key.value;
    if (!value.startsWith(_feedPostItemKeyPrefix)) {
      return null;
    }
    final postId = value.substring(_feedPostItemKeyPrefix.length);
    if (postId.isEmpty) {
      return null;
    }
    final postIndex = posts.indexWhere(
      (post) => (post['id'] ?? '').toString() == postId,
    );
    if (postIndex == -1) {
      return null;
    }
    return postIndex + 3;
  }

  Widget _buildFeedBody(
    BuildContext context,
    List<Map<String, dynamic>> posts,
  ) {
    if (_currentFeedType == 'mine' && _houseId != null) {
      return _buildProfileFeedView(context);
    }
    if (_isCommunityPreviewFeed(_currentFeedType)) {
      return _buildTemporarilyClosedFeedBody();
    }
    if (_currentFeedType == 'locket') {
      return _buildLocketFeedView(posts);
    }
    return _buildRegularFeedView(posts);
  }

  Widget _buildTemporarilyClosedFeedBody() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _CommunityHeaderActionStrip(
            state: this,
            includeTopPadding: true,
          ),
        ),
        SliverToBoxAdapter(
          child: _FeedTabSelector(state: this),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _borderColor),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: _isLight ? 0.06 : 0.18),
                    blurRadius: 20,
                    spreadRadius: -14,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD81B60).withValues(alpha: 0.10),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      size: 38,
                      color: Color(0xFFD81B60),
                    ),
                  ),
                  SLSpacing.h20,
                  Text(
                    _ct(
                      context.tr('home_tnhnngangp_4c4164'),
                      'Feature in development',
                    ),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                  SLSpacing.h12,
                  Text(
                    _ctf(
                      'Mục {feed} hiện vẫn đang được hoàn thiện nên tạm thời chỉ giữ lại phần khối hồ sơ phía trên.\n\nKhi hoàn tất, nội dung bên dưới sẽ mở lại đầy đủ.',
                      '{feed} is still being built, so only the profile blocks above are kept for now.\n\nThe content below will reopen once it is ready.',
                      <String, Object?>{'feed': _feedLabel()},
                    ),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 13.6,
                      fontWeight: FontWeight.w700,
                      color: _subTextColor,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildClosedFeedChip(
                        icon: Icons.rocket_launch_outlined,
                        label: _ct(context.tr('home_angphttrin_0830a2'),
                            'In development'),
                      ),
                      _buildClosedFeedChip(
                        icon: Icons.auto_awesome_outlined,
                        label:
                            _ct(context.tr('home_spmli_3acdcb'), 'Coming soon'),
                      ),
                      _buildClosedFeedChip(
                        icon: Icons.view_carousel_outlined,
                        label: _ct(context.tr('home_ginguyn6kh_8880f8'),
                            'Top 6 blocks stay'),
                      ),
                      _buildClosedFeedChip(
                        icon: Icons.hourglass_bottom_rounded,
                        label: _ct(
                            context.tr('home_mlisau_a08e61'), 'Reopens later'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClosedFeedChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _actionBgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFD81B60)),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFeedView(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _CommunityHeaderActionStrip(
            state: this,
            includeTopPadding: true,
          ),
        ),
        SliverToBoxAdapter(
          child: _FeedTabSelector(state: this),
        ),
        SliverFillRemaining(
          hasScrollBody: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 22,
                    spreadRadius: -14,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: VisitorProfileScreen(
                    targetHouseId: _houseId!,
                    showBackButton: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegularFeedView(List<Map<String, dynamic>> posts) {
    final contentCount = _isLoading
        ? 1
        : (posts.isEmpty ? 1 : posts.length + (_isLoadingMoreFeed ? 1 : 0));
    final double feedCacheExtent = (MediaQuery.sizeOf(context).height * 0.9)
        .clamp(320.0, 560.0)
        .toDouble();

    return RefreshIndicator(
      onRefresh: () async => _init(),
      color: const Color(0xFFD81B60),
      child: ListView.builder(
        cacheExtent: feedCacheExtent, controller: _scrollController,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        findChildIndexCallback: (Key key) => _findFeedListChildIndex(
          key,
          posts,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        itemCount: 3 + contentCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CommunityHeaderActionStrip(
              state: this,
              includeTopPadding: true,
            );
          }
          if (index == 1) {
            return _FeedTabSelector(state: this);
          }
          if (index == 2) {
            return _FeedComposer(state: this);
          }

          if (_isLoading) {
            return const _CommunityFeedLoadingState();
          }

          if (posts.isEmpty) {
            return _CommunityFeedEmptyState(
              message: _ct(
                context.tr('home_chacbivitn_a2faa8'),
                'No posts yet.',
              ),
              textColor: _subTextColor,
            );
          }

          if (_isLoadingMoreFeed && index == posts.length + 3) {
            return const _CommunityFeedBottomLoader();
          }

          final post = posts[index - 3];
          final postId = (post['id'] ?? '').toString();
          return _FeedPostCard(
            key: ValueKey<String>('$_feedPostItemKeyPrefix$postId'),
            state: this,
            post: post,
          );
        },
      ),
    );
  }
}
