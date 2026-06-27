part of 'community_tab.dart';

class _CommunityFriendMenuState {
  final bool isFriend;
  final bool blockedByMe;
  final bool blockedByThem;
  final String? sentRequestId;
  final String? receivedRequestId;

  const _CommunityFriendMenuState({
    required this.isFriend,
    required this.blockedByMe,
    required this.blockedByThem,
    this.sentRequestId,
    this.receivedRequestId,
  });
}

extension _CommunityTabInteractions on _CommunityTabState {
  Future<String?> _resolveInteractionHouseId({bool showError = true}) async {
    final fresh = await _houseService.getCurrentHouseId(preferFresh: true);
    final resolved = (fresh?.trim().isNotEmpty ?? false)
        ? fresh!.trim()
        : (_houseId?.trim().isNotEmpty ?? false)
            ? _houseId!.trim()
            : null;

    if (resolved != null && resolved != _houseId) {
      _updateState(() => _houseId = resolved);
    }

    if ((resolved == null || resolved.isEmpty) && showError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _ct(
              context.tr('home_khngtmthyn_a34ffb'),
              'No valid active house was found for this community action.',
            ),
            style: SLTheme.quicksand(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return resolved;
  }

  Future<void> _toggleLike(Map<String, dynamic> post,
      {Offset? position}) async {
    final hid = await _resolveInteractionHouseId();
    if (hid == null || hid.isEmpty) return;

    final postId = (post['id'] ?? '').toString();
    if (postId.isEmpty || _pendingLikePostIds.contains(postId)) return;

    final likedBefore = _hasAuthoritativeLikeMap(post)
        ? _isLikedByMe(post, houseId: hid)
        : await _socialService.hasLiked(postId, hid);
    final shouldLike = !likedBefore;

    _updateState(() {
      _pendingLikePostIds.add(postId);
      _holdLikeSync(postId);
      _applyLocalLikeState(
        post: post,
        houseId: hid,
        isLiked: shouldLike,
      );
    });

    if (shouldLike && position != null) {
      // Create reaction animation specifically at the clicked position
      for (int i = 0; i < 6; i++) {
        final speedX = (math.Random().nextDouble() - 0.5) * 4;
        final speedY = -math.Random().nextDouble() * 5 - 2;

        // Danh sách emoji giống Locket
        final emojis = ['💖', '😍', '🔥', '🥰', '💯'];
        final emoji = emojis[math.Random().nextInt(emojis.length)];

        _reactionAnimations.add(EmojiReactionAnimation(
          x: position.dx,
          y: position.dy,
          speedX: speedX,
          speedY: speedY,
          emoji: emoji,
        ));
      }
      _ensureHeartTickerRunning();
    }

    try {
      await _socialService.toggleLike(postId: postId, myHouseId: hid);

      // Ghi nhận tương tác
      if (shouldLike) {
        RecommendationService().recordInteraction(
          houseId: (post['houseId'] ?? '').toString(),
          mood: (post['moodLabel'] ?? post['mood'] ?? '').toString(),
          weight: 5.0, // Điểm like
        );

        // Kiểm tra mốc thả tim để hiển thị review app
        await _checkAndShowAppReview();
      }
    } catch (e) {
      _updateState(() {
        _clearLikeSyncHold(postId);
        _applyLocalLikeState(
          post: post,
          houseId: hid,
          isLiked: likedBefore,
        );
      });
      if (!mounted) return;
      final errorMessage = _communityActionErrorMessage(
        e,
        viFallback: 'Không thể thả tim lúc này.',
        enFallback: 'Cannot react right now.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: SLTheme.quicksand(fontWeight: FontWeight.w700),
          ),
        ),
      );
    } finally {
      _updateState(() => _pendingLikePostIds.remove(postId));
    }
  }

  Future<void> _checkAndShowAppReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Tăng biến đếm số lần thả tim
      int likeCount = (prefs.getInt('app_review_like_count') ?? 0) + 1;
      await prefs.setInt('app_review_like_count', likeCount);

      // Các mốc hiển thị: 10, 500, 1000, 2000
      if (likeCount == 10 ||
          likeCount == 500 ||
          likeCount == 1000 ||
          likeCount == 2000) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          // Hiện popup 5 sao của Google/Apple
          await inAppReview.requestReview();
        }
      }
    } catch (e) {
      final resolvedError = AppErrorMapper.resolve(
        e,
        fallbackMessage: _ct(
          'Không thể hiển thị đánh giá lúc này.',
          'Cannot show the app review prompt right now.',
        ),
      );
      debugPrint('Error showing app review: ${resolvedError.message}');
    }
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('community_bookmarks_v1') ?? [];
    if (!mounted) return;
    if (!mounted) return;
    _updateState(() => _bookmarkedPostIds = ids.toSet());
  }

  Future<void> _toggleBookmark(Map<String, dynamic> post) async {
    final postId = (post['id'] ?? '').toString();
    if (postId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final next = _bookmarkedPostIds.toSet();
    final added = !next.remove(postId);
    if (added) {
      next.add(postId);
    }
    await prefs.setStringList('community_bookmarks_v1', next.toList());
    if (!mounted) return;
    if (!mounted) return;
    _updateState(() => _bookmarkedPostIds = next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? _ct(
                  context.tr('home_lubivitxem_751733'),
                  'Post saved to view later',
                )
              : _ct(
                  context.tr('home_blubivit_c5db66'),
                  'Post removed from saved items',
                ),
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _loadHiddenPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_communityHiddenPostsPrefsKey) ?? [];
    if (!mounted) return;
    _updateState(() {
      _hiddenPostIds = ids.toSet();
      _hiddenPostsRevision++;
      _invalidateFilteredPostsCache();
    });
  }

  Future<void> _persistHiddenPosts(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _communityHiddenPostsPrefsKey,
      ids.take(400).toList(),
    );
  }

  Future<void> _hidePostFromFeed(Map<String, dynamic> post) async {
    final postId = (post['id'] ?? '').toString();
    if (postId.isEmpty) return;

    final next = _hiddenPostIds.toSet()..add(postId);
    await _persistHiddenPosts(next);
    if (!mounted) return;
    _updateState(() {
      _hiddenPostIds = next;
      _hiddenPostsRevision++;
      _invalidateFilteredPostsCache();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _ct(
            context.tr('home_bivitnyscn_ac7239'),
            'This post will be hidden from your feed.',
          ),
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
        action: SnackBarAction(
          label: _ct(context.tr('home_hontc_96ce27'), 'Undo'),
          onPressed: () {
            unawaited(_unhidePostById(postId));
          },
        ),
      ),
    );
  }

  Future<void> _unhidePostById(String postId) async {
    if (postId.trim().isEmpty || !_hiddenPostIds.contains(postId)) {
      return;
    }
    final next = _hiddenPostIds.toSet()..remove(postId);
    await _persistHiddenPosts(next);
    if (!mounted) return;
    _updateState(() {
      _hiddenPostIds = next;
      _hiddenPostsRevision++;
      _invalidateFilteredPostsCache();
    });
  }

  Future<_CommunityFriendMenuState> _resolveFriendMenuState({
    required String myHouseId,
    required String targetHouseId,
  }) async {
    if (myHouseId.isEmpty ||
        targetHouseId.isEmpty ||
        myHouseId == targetHouseId) {
      return const _CommunityFriendMenuState(
        isFriend: false,
        blockedByMe: false,
        blockedByThem: false,
      );
    }

    final requests =
        await _friendsService.streamFriendRequests(myHouseId).first;
    final blockedByThemSnap = await _dbRef
        .child('houses/$targetHouseId/blocked_users/$myHouseId')
        .get();

    return _CommunityFriendMenuState(
      isFriend: _isFriend(targetHouseId),
      blockedByMe: _blockedUsers[targetHouseId] == true,
      blockedByThem: blockedByThemSnap.value == true,
      sentRequestId: requests.sent[targetHouseId],
      receivedRequestId: requests.received[targetHouseId],
    );
  }

  Future<void> _openPostOwnerProfile(String targetHouseId) async {
    if (targetHouseId.trim().isEmpty || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitorProfileScreen(targetHouseId: targetHouseId),
      ),
    );
  }

  Future<void> _sendFriendRequestFromPost(String targetHouseId) async {
    final myHouseId = await _resolveInteractionHouseId();
    if (myHouseId == null || myHouseId.isEmpty || targetHouseId.isEmpty) {
      return;
    }

    final result = await _friendsService.sendFriendRequest(
      fromHouseId: myHouseId,
      fromHouseName:
          _houseName.trim().isNotEmpty ? _houseName.trim() : _defaultHouseName,
      toHouseId: targetHouseId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _acceptFriendRequestFromPost({
    required String requestId,
    required String fromHouseId,
  }) async {
    final myHouseId = await _resolveInteractionHouseId();
    if (myHouseId == null || myHouseId.isEmpty) return;

    final ok = await _friendsService.acceptFriendRequest(
      requestId: requestId,
      currentHouseId: myHouseId,
      fromHouseId: fromHouseId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? _ct(context.tr('home_chpnhnlimi_a049b6'), 'Friend request accepted.')
              : _ct(
                  context.tr('home_khngthchpn_6169c1'),
                  'Cannot accept this request right now.',
                ),
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _cancelSentFriendRequestFromPost(String requestId) async {
    final myHouseId = await _resolveInteractionHouseId();
    if (myHouseId == null || myHouseId.isEmpty) return;

    await _friendsService.cancelSentFriendRequest(requestId, myHouseId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _ct(context.tr('home_hylimiktbn_0b5181'), 'Friend request cancelled.'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final recordShareErrorFallback = context.tr('home_khngthghin_24a493');
    final hid = await _resolveInteractionHouseId();
    if (hid == null || hid.isEmpty) return;

    final postId = (post['id'] ?? '').toString();
    if (postId.isEmpty) return;
    final content = (post['content'] ?? '').toString().trim();
    final location = (post['location'] ?? '').toString().trim();
    final mood = (post['mood'] ?? '').toString().trim();
    final moodEmoji = (post['moodEmoji'] ?? '').toString().trim();
    final imageUrl = (post['imageUrl'] ?? '').toString().trim();
    final videoUrl = (post['videoUrl'] ?? '').toString().trim();
    final shareText = [
      if (content.isNotEmpty) content,
      if (location.isNotEmpty) 'Vi tri: $location',
      if (mood.isNotEmpty)
        moodEmoji.isEmpty ? 'Tam trang: $mood' : '$moodEmoji $mood',
      if (videoUrl.isNotEmpty) videoUrl,
    ].join('\n');

    String? trackingErrorMessage;
    try {
      await FirebaseFirestore.instance
          .collection('social_posts')
          .doc(postId)
          .update({'shareCount': FieldValue.increment(1)});

      RecommendationService().recordInteraction(
        houseId: (post['houseId'] ?? '').toString(),
        mood: (post['moodLabel'] ?? post['mood'] ?? '').toString(),
        weight: 15.0,
      );
    } catch (e) {
      trackingErrorMessage = _communityActionErrorMessage(
        e,
        viFallback: recordShareErrorFallback,
        enFallback: 'Cannot record this share right now.',
      );
    }

    if (!mounted) return;

    ShareBottomSheet.show(
      context: context,
      myHouseId: hid,
      contentToShare: shareText,
      shareUrl: imageUrl.isNotEmpty ? imageUrl : '',
      sourceType: 'community_post',
      sourceId: postId,
    );

    if (trackingErrorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trackingErrorMessage,
            style: SLTheme.quicksand(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDeletePostFromCommunity() async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _ct(context.tr('home_xcnhnxabiv_05a787'), 'Confirm post deletion'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          _ct(
            context.tr('home_bivitnysbg_136371'),
            'This post will be removed from the community feed and cannot be undone.',
          ),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_ct(context.tr('home_hy_1e4050'), 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _ct(context.tr('home_xabivit_2c7199'), 'Delete post'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _removePostFromFeedLocally(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return;
    final nextPosts = List<Map<String, dynamic>>.from(_allPosts)
      ..removeWhere(
        (item) => (item['id'] ?? '').toString() == normalizedPostId,
      );
    if (nextPosts.length == _allPosts.length) return;

    _updateState(() {
      _replaceAllPosts(nextPosts);
      _oldestLoadedTs =
          nextPosts.isEmpty ? null : _getTimestamp(nextPosts.last);
    });
    _persistFeedCache();
  }

  Future<void> _openMoreActions(Map<String, dynamic> post) async {
    final deletedUserMsg = context.tr('home_ngidngxa_fdbd7c');
    final anonStrangerMsg = context.tr('home_ngilndanh_d63da2');
    final homeMsg = context.tr('home_nginh_731d70');

    final postId = (post['id'] ?? '').toString();
    final targetHouseId = (post['houseId'] ?? '').toString().trim();
    final legacyOwnerHouseId = (post['uid'] ?? '').toString().trim();
    final postAuthorUid =
        (post['author_uid'] ?? post['authorUid'] ?? '').toString().trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final myHouseId =
        (await _resolveInteractionHouseId(showError: false) ?? _houseId ?? '')
            .trim();
    final isMine = (myHouseId.isNotEmpty &&
            (targetHouseId == myHouseId || legacyOwnerHouseId == myHouseId)) ||
        (postAuthorUid.isNotEmpty && postAuthorUid == currentUid);
    final isAnon =
        (post['isAnon'] == true) || (post['isAnon']?.toString() == 'true');
    final isDeletedAuthor = post['isDeletedAuthor'] == true ||
        (post['isDeletedAuthor']?.toString() == 'true') ||
        targetHouseId.isEmpty;
    final postHouseName = (post['houseName'] ?? '').toString().trim();
    final postOwnerName = isDeletedAuthor
        ? _ct(deletedUserMsg, 'Deleted user')
        : isAnon
            ? _ct(anonStrangerMsg, 'Anonymous stranger')
            : postHouseName.isNotEmpty
                ? postHouseName
                : _ct(homeMsg, 'Home');
    final content = (post['content'] ?? '').toString().trim();
    final isBookmarked =
        postId.isNotEmpty && _bookmarkedPostIds.contains(postId);
    final canOpenProfile = !isMine && !isAnon && !isDeletedAuthor;
    final canManageFriend =
        canOpenProfile && myHouseId.isNotEmpty && targetHouseId.isNotEmpty;
    final friendState = canManageFriend
        ? await _resolveFriendMenuState(
            myHouseId: myHouseId,
            targetHouseId: targetHouseId,
          )
        : const _CommunityFriendMenuState(
            isFriend: false,
            blockedByMe: false,
            blockedByThem: false,
          );

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F5F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget actionTile({
          required IconData icon,
          required String title,
          String? subtitle,
          Color? iconColor,
          Color? textColor,
          bool enabled = true,
          Future<void> Function()? onTap,
        }) {
          final resolvedTextColor =
              textColor ?? (enabled ? const Color(0xFF2F2731) : Colors.grey);
          return ListTile(
            enabled: enabled,
            minLeadingWidth: 24,
            leading: Icon(
              icon,
              color: iconColor ?? resolvedTextColor,
            ),
            title: Text(
              title,
              style: SLTheme.quicksand(
                color: resolvedTextColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      color: resolvedTextColor.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
            onTap: !enabled || onTap == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await onTap();
                  },
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              postOwnerName,
                              maxLines: 2,
                              overflow: TextOverflow.fade,
                              style: SLTheme.quicksand(
                                color: const Color(0xFF2F2731),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _ct(
                                context.tr('home_tychnchobi_afaeb3'),
                                'Actions for this post',
                              ),
                              style: SLTheme.quicksand(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canOpenProfile)
                  actionTile(
                    icon: Icons.person_outline_rounded,
                    title: _ct(context.tr('home_xemtrangcn_9c72bc'), 'View profile'),
                    subtitle: _ct(
                      context.tr('home_mhscanhny_9ba6c2'),
                      'Open this house profile',
                    ),
                    onTap: () => _openPostOwnerProfile(targetHouseId),
                  ),
                if (canManageFriend)
                  if (friendState.blockedByMe)
                    actionTile(
                      icon: Icons.block_rounded,
                      title: _ct(
                        context.tr('home_bnchnnhny_d99719'),
                        'You have blocked this house',
                      ),
                      subtitle: _ct(
                        context.tr('home_vodanhschc_6c94fa'),
                        'Open your block list if you want to restore interaction',
                      ),
                      enabled: false,
                    )
                  else if (friendState.blockedByThem)
                    actionTile(
                      icon: Icons.block_flipped,
                      title: _ct(
                        context.tr('home_nhnyangchn_ea05cb'),
                        'This house blocked interactions',
                      ),
                      subtitle: _ct(
                        context.tr('home_bnchathktb_9f9c39'),
                        'You cannot add or interact further right now',
                      ),
                      enabled: false,
                    )
                  else if (friendState.isFriend)
                    actionTile(
                      icon: Icons.people_alt_rounded,
                      title: _ct(context.tr('home_lbnb_4ee8d3'), 'Already friends'),
                      subtitle: _ct(
                        context.tr('home_hainhktbnv_9aa402'),
                        'Your houses are already connected as friends',
                      ),
                      enabled: false,
                    )
                  else if ((friendState.receivedRequestId ?? '').isNotEmpty)
                    actionTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: _ct(
                        context.tr('home_chpnhnlimi_d4d19b'),
                        'Accept friend request',
                      ),
                      subtitle: _ct(
                        context.tr('home_nhnyangchb_e18657'),
                        'This house is waiting for your approval',
                      ),
                      onTap: () => _acceptFriendRequestFromPost(
                        requestId: friendState.receivedRequestId!,
                        fromHouseId: targetHouseId,
                      ),
                    )
                  else if ((friendState.sentRequestId ?? '').isNotEmpty)
                    actionTile(
                      icon: Icons.person_remove_alt_1_rounded,
                      title: _ct(
                        context.tr('home_hylimigi_7797c1'),
                        'Cancel sent request',
                      ),
                      subtitle: _ct(
                        context.tr('home_thuhilimik_b85d08'),
                        'Withdraw the friend request sent to this house',
                      ),
                      onTap: () => _cancelSentFriendRequestFromPost(
                        friendState.sentRequestId!,
                      ),
                    )
                  else
                    actionTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: _ct(context.tr('home_ktbn_b7f525'), 'Add friend'),
                      subtitle: _ct(
                        context.tr('home_gilimiktbn_e643bf'),
                        'Send a friend request to this house',
                      ),
                      onTap: () => _sendFriendRequestFromPost(targetHouseId),
                    ),
                actionTile(
                  icon: Icons.repeat_rounded,
                  title: _ct(context.tr('home_nglichias_248e7e'), 'Repost / share'),
                  subtitle: _ct(
                    context.tr('home_chiasbinyr_0b2130'),
                    'Share this post outside or send it to friends',
                  ),
                  onTap: () => _sharePost(post),
                ),
                if (postId.isNotEmpty)
                  actionTile(
                    icon: isBookmarked
                        ? Icons.bookmark_remove_rounded
                        : Icons.bookmark_add_rounded,
                    title: isBookmarked
                        ? _ct(context.tr('home_blubivit_28e9ff'), 'Remove saved post')
                        : _ct(context.tr('home_lubivit_c98a48'), 'Save post'),
                    subtitle: isBookmarked
                        ? _ct(
                            context.tr('home_xakhidanhs_6f3415'),
                            'Remove it from your saved items',
                          )
                        : _ct(
                            context.tr('home_lulixemsau_2ac0fd'),
                            'Keep it for later',
                          ),
                    onTap: () => _toggleBookmark(post),
                  ),
                if (content.isNotEmpty)
                  actionTile(
                    icon: Icons.copy_rounded,
                    title: _ct(context.tr('home_saochpnidu_93932d'), 'Copy content'),
                    subtitle: _ct(
                      context.tr('home_saochpphnc_b9e267'),
                      'Copy the text from this post',
                    ),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _ct(context.tr('home_saochpnidu_66725a'), 'Content copied'),
                          ),
                        ),
                      );
                    },
                  ),
                if (!isMine)
                  actionTile(
                    icon: Icons.visibility_off_outlined,
                    title: _ct(
                      context.tr('home_khngquantm_953df9'),
                      'Not interested in this post',
                    ),
                    subtitle: _ct(
                      context.tr('home_nbinykhibn_17be53'),
                      'Hide this post from your feed',
                    ),
                    onTap: () => _hidePostFromFeed(post),
                  ),
                const Divider(height: 16),
                if (isMine)
                  actionTile(
                    icon: Icons.delete_outline,
                    iconColor: Colors.red,
                    textColor: Colors.red,
                    title: _ct(context.tr('home_xabivit_2c7199'), 'Delete post'),
                    subtitle: _ct(
                      context.tr('home_gbivitnykh_1a7d6b'),
                      'Remove this post from the community feed',
                    ),
                    onTap: () async {
                      if (postId.isEmpty) {
                        return;
                      }
                      final confirmed = await _confirmDeletePostFromCommunity();
                      if (!confirmed) return;
                      try {
                        await _socialService.deletePost(
                          postId: postId,
                          requestingHouseId: myHouseId,
                        );
                        _removePostFromFeedLocally(postId);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _ct(context.tr('home_xabivit_92d4ec'), 'Post deleted'),
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        final errorMessage = _communityActionErrorMessage(
                          e,
                          viFallback: context.tr('home_khngthxabi_cfbf88'),
                          enFallback: 'Cannot delete this post right now.',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              errorMessage,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  )
                else ...[
                  actionTile(
                    icon: Icons.flag_outlined,
                    iconColor: Colors.orange,
                    title: _ct(context.tr('home_bocobivit_08313a'), 'Report post'),
                    subtitle: _ct(
                      context.tr('home_gibocotiqu_e68d16'),
                      'Send a report to the moderators',
                    ),
                    onTap: () async {
                      final reporter = myHouseId;
                      if (postId.isEmpty || reporter.isEmpty) {
                        return;
                      }
                      await _socialService.reportPost(
                        postId: postId,
                        reporterHouseId: reporter,
                        reason: 'reported_by_user',
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _ct(
                              context.tr('home_gibocotiqu_fd2301'),
                              'Report sent to the moderators',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  actionTile(
                    icon: Icons.block_rounded,
                    iconColor: Colors.red,
                    textColor: Colors.red,
                    title: _ct(context.tr('home_chnngidngn_27d0c8'), 'Block this user'),
                    subtitle: _ct(
                      context.tr('home_ngnnhnyxem_ce0910'),
                      'Prevent this house from viewing and interacting with yours',
                    ),
                    onTap: () async {
                      if (targetHouseId.isEmpty || myHouseId.isEmpty) return;

                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            _ct(context.tr('home_xcnhnchn_ae00a6'), 'Confirm block'),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          content: Text(
                            _ct(
                              'Bạn có chắc muốn chặn người này không?\nHọ sẽ không thể xem nhà bạn nữa.',
                              'Are you sure you want to block this user?\nThey will no longer be able to view your house.',
                            ),
                            style: SLTheme.quicksand(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(_ct(context.tr('home_hy_1e4050'), 'Cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                _ct(context.tr('home_chn_483b6f'), 'Block'),
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;

                      await _dbRef
                          .child(
                              'houses/$myHouseId/blocked_users/$targetHouseId')
                          .set(true);
                      await _dbRef
                          .child('friends/$myHouseId/$targetHouseId')
                          .remove();
                      await _dbRef
                          .child('friends/$targetHouseId/$myHouseId')
                          .remove();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _ct(
                              context.tr('home_chnngidngn_adcaff'),
                              'This user has been blocked.',
                            ),
                          ),
                        ),
                      );
                      _init();
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    final postId = (post['id'] ?? '').toString();
    final hid = await _resolveInteractionHouseId();
    if (postId.isEmpty || hid == null || hid.isEmpty) return;
    final commentsEnabled = post['commentsEnabled'] != false;
    final isMine = (post['houseId'] ?? '').toString() == hid;

    // Check if friends (if we want to respect friend-only comments, but the setting is usually enforced per post or per profile. For now, if commentsEnabled is true, anyone can comment unless we fetch their profile settings. To keep it simple, we just use commentsEnabled).

    // Ghi nhận tương tác
    if (!isMine) {
      RecommendationService().recordInteraction(
        houseId: (post['houseId'] ?? '').toString(),
        mood: (post['moodLabel'] ?? post['mood'] ?? '').toString(),
        weight: 10.0, // Điểm comment / mở bình luận
      );
    }

    if (!commentsEnabled && !isMine) {
      if (!mounted) return;
      LegacyWebUi.showNotice(
        context,
        message: _ct(
          'Bài viết này đang tắt bình luận nên bạn chưa thể trả lời.',
          'Comments are disabled on this post, so you cannot reply yet.',
        ),
        success: false,
        title: _ct(context.tr('home_bnhlunangb_aad36a'), 'Comments are locked'),
        icon: Icons.comments_disabled_outlined,
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18191A),
      builder: (ctx) {
        return _CommentsSheet(
          postId: postId,
          currentHouseId: hid,
          currentHouseName: _houseName,
          currentHouseAvatar: _houseAvatar,
          dbRef: _dbRef,
          blockedUsers: _blockedUsers,
        );
      },
    );
  }
}
