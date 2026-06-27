part of 'community_tab.dart';

/// A specialized modal for rendering comments, supporting nested replies and likes.
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String currentHouseId;
  final String currentHouseName;
  final String currentHouseAvatar;
  final DatabaseReference dbRef;
  final Map<String, dynamic> blockedUsers;

  const _CommentsSheet({
    required this.postId,
    required this.currentHouseId,
    required this.currentHouseName,
    required this.currentHouseAvatar,
    required this.dbRef,
    required this.blockedUsers,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final ScrollController _scrollController = ScrollController();
  final HouseService _houseService = HouseService();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int? _oldestTs;
  StreamSubscription? _newCommentsSub;
  String? _activeHouseId;

  @override
  void initState() {
    super.initState();
    _activeHouseId = widget.currentHouseId;
    _loadInitialComments();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadInitialComments() async {
    setState(() => _isLoading = true);
    final page = await _fetchCommentsPage(null);
    if (!mounted) return;
    setState(() {
      _comments.addAll(page);
      _isLoading = false;
      if (page.isNotEmpty) {
        _oldestTs = _readTimestamp(page.last['ts']);
        _hasMore = page.length >= 20;
      } else {
        _hasMore = false;
      }
    });
    _listenForNewComments();
  }

  Future<List<Map<String, dynamic>>> _fetchCommentsPage(
      int? endBeforeTs) async {
    try {
      var query = FirebaseFirestore.instance
          .collection('social_posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('ts', descending: true)
          .limit(20);
      if (endBeforeTs != null) {
        query = query.where('ts', isLessThan: endBeforeTs);
      }
      final snap = await query.get();
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _listenForNewComments() {
    _newCommentsSub?.cancel();
    final startTs = _comments.isNotEmpty
        ? _readTimestamp(_comments.first['ts'])
        : DateTime.now().millisecondsSinceEpoch;
    final query = FirebaseFirestore.instance
        .collection('social_posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('ts', descending: false)
        .startAfter([startTs]);
    _newCommentsSub = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          if (_comments.any((c) => c['id'] == doc.id)) continue;
          final item = doc.data() ?? {};
          item['id'] = doc.id;
          setState(() {
            _comments.insert(0, item);
            _comments.sort((a, b) =>
                _readTimestamp(b['ts']).compareTo(_readTimestamp(a['ts'])));
          });
        }
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore || _oldestTs == null) return;
    setState(() => _isLoadingMore = true);
    final page = await _fetchCommentsPage(_oldestTs);
    if (!mounted) return;
    setState(() {
      _isLoadingMore = false;
      if (page.isEmpty) {
        _hasMore = false;
      } else {
        _comments.addAll(page);
        _oldestTs = _readTimestamp(page.last['ts']);
        _hasMore = page.length >= 20;
      }
    });
  }

  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _replyingToCommentId;
  String? _replyingToAuthorName;

  @override
  void dispose() {
    _newCommentsSub?.cancel();
    _scrollController.dispose();
    _commentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    SLNotice.showError(context, message);
  }

  String get _resolvedHouseId {
    final active = _activeHouseId?.trim() ?? '';
    if (active.isNotEmpty) {
      return active;
    }
    return widget.currentHouseId.trim();
  }

  Future<String?> _resolveCurrentHouseId({bool showError = true}) async {
    final noHouseFoundMsg = context.tr('home_khngtmthyn_a34ffb');
    final fresh = await _houseService.getCurrentHouseId(preferFresh: true);
    final resolved =
        (fresh?.trim().isNotEmpty ?? false) ? fresh!.trim() : _resolvedHouseId;

    if (resolved.isNotEmpty && resolved != _activeHouseId) {
      if (mounted) {
        setState(() => _activeHouseId = resolved);
      } else {
        _activeHouseId = resolved;
      }
      return resolved;
    }

    if (resolved.isNotEmpty) {
      return resolved;
    }

    if (showError) {
      _showMessage(
        _ct(
          noHouseFoundMsg,
          'No valid active house was found for this community action.',
        ),
      );
    }
    return null;
  }

  void _onReplyTap(String commentId, String authorName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToAuthorName = authorName;
    });
    _focusNode.requestFocus();
  }

  void _onCancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToAuthorName = null;
    });
  }

  int _readTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> _readLikeMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _readAuthor(Map<String, dynamic> item) {
    return (item['author'] ??
            item['name'] ??
            item['u'] ??
            _ct(context.tr('home_ngidng_3bf886'), 'User'))
        .toString()
        .trim();
  }

  String _readText(Map<String, dynamic> item) {
    return (item['text'] ?? item['c'] ?? '').toString().trim();
  }

  String _readAvatar(Map<String, dynamic> item) {
    return (item['avt'] ?? item['avatar'] ?? item['houseAvt'] ?? '')
        .toString()
        .trim();
  }

  Future<String?> _promptReportReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_ct(context.tr('home_bocobnhlun_7e340e'), 'Report comment')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _ct(context.tr('home_ldoboco_1a5afa'), 'Reason for the report...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_ct(context.tr('home_hy_1e4050'), 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_ct(context.tr('home_gi_377294'), 'Send')),
          ),
        ],
      ),
    );
  }

  Future<void> _reportComment(String commentId) async {
    final msgOk = context.tr('home_gibocobnhl_94a6fb');
    final msgFail = context.tr('home_khnggicboc_998a39');
    final reason = await _promptReportReason();
    if (reason == null) return;
    final reporterHouseId = await _resolveCurrentHouseId();
    if (reporterHouseId == null) return;

    try {
      await SocialService().reportComment(
        postId: widget.postId,
        commentId: commentId,
        reporterHouseId: reporterHouseId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ct(msgOk, 'Comment report sent')),
        ),
      );
    } catch (e) {
      _showMessage(_communityActionErrorMessage(
        e,
        viFallback: msgFail,
        enFallback: 'Cannot send this report right now.',
      ));
    }
  }

  Future<void> _sendComment() async {
    final msgCannotInteract = context.tr('home_khngthgibn_11fcfb');
    final msgViolation = context.tr('home_bnhlunchat_5a7645');
    final msgCannotSend = context.tr('home_khnggicbnh_b6207c');

    final text = _commentCtrl.text.trim();
    final validationError = _validateCommunityText(text, isComment: true);
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    if (!await SecurityService()
        .guardAction(context, 'community_comment', content: text)) {
      return;
    }

    final myHouseId = await _resolveCurrentHouseId();
    if (myHouseId == null) return;

    try {
      await SocialService().assertCanInteractWithPost(
        myHouseId: myHouseId,
        postId: widget.postId,
      );
    } catch (e) {
      _showMessage(_communityActionErrorMessage(
        e,
        viFallback: msgCannotInteract,
        enFallback: 'Cannot send this comment right now.',
      ));
      return;
    }

    var hasViolations = false;
    if (text.isNotEmpty && _containsBannedWords(text)) {
      hasViolations = true;
    }

    final author = widget.currentHouseName.trim().isEmpty
        ? _ct('Nha', 'Home')
        : widget.currentHouseName.trim();

    try {
      await SocialService().postComment(
        postId: widget.postId,
        houseId: myHouseId,
        content: text,
        authorName: author,
        authorAvt: widget.currentHouseAvatar.trim(),
        replyTo: _replyingToCommentId,
        replyToName: _replyingToAuthorName,
      );

      _commentCtrl.clear();
      _focusNode.unfocus();
      _onCancelReply();
      if (hasViolations) {
        _showMessage(
          _ct(
            msgViolation,
            'This comment contains blocked words and has been hidden.',
          ),
        );
      }
    } catch (e) {
      _showMessage(_communityActionErrorMessage(
        e,
        viFallback: msgCannotSend,
        enFallback: 'Cannot send this comment right now.',
      ));
    }
  }

  Future<void> _toggleLikeComment(
      String commentId, Map<String, dynamic> likeMap) async {
    final msgFail = context.tr('home_khngcpnhtc_0b73c2');
    final myHouseId = await _resolveCurrentHouseId();
    if (myHouseId == null) return;

    try {
      await SocialService().toggleLikeComment(
        postId: widget.postId,
        commentId: commentId,
        myHouseId: myHouseId,
      );
    } catch (e) {
      _showMessage(_communityActionErrorMessage(
        e,
        viFallback: msgFail,
        enFallback: 'Cannot update this reaction right now.',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          height: media.size.height * 0.82,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCFE),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              SLSpacing.h12,
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: SLRadius.pillAll,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ct(context.tr('home_bnhluncngn_cc44c2'), 'Community comments'),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: const Color(0xFFD81B60),
                            ),
                          ),
                          SLSpacing.h4,
                          Text(
                            _ct(
                              context.tr('home_khuvctrchu_d54a4b'),
                              'Public conversation area.',
                            ),
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: SLRadius.lgAll,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: SLRadius.lgAll,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFD81B60)));
                    }

                    final comments = <Map<String, dynamic>>[];
                    for (final item in _comments) {
                      if (item['isHidden'] == true) {
                        continue; // Filter out hidden comments
                      }
                      // Lọc bình luận từ người dùng đã bị chặn
                      final authorHouseId =
                          (item['houseId'] ?? item['uid'] ?? '').toString();
                      if (widget.blockedUsers.containsKey(authorHouseId) &&
                          widget.blockedUsers[authorHouseId] == true) {
                        continue;
                      }
                      comments.add(item);
                    }

                    int tsOf(Map<String, dynamic> m) => _readTimestamp(m['ts']);

                    comments.sort((a, b) => tsOf(a).compareTo(tsOf(b)));

                    final commentsById = <String, Map<String, dynamic>>{
                      for (final item in comments) item['id'].toString(): item,
                    };
                    final repliesByParent =
                        <String, List<Map<String, dynamic>>>{};

                    for (final item in comments) {
                      final replyTo = (item['replyTo'] ?? '').toString().trim();
                      if (replyTo.isEmpty ||
                          !commentsById.containsKey(replyTo)) {
                        continue;
                      }
                      repliesByParent
                          .putIfAbsent(replyTo, () => <Map<String, dynamic>>[])
                          .add(item);
                    }

                    final rootComments = comments.where((item) {
                      final replyTo = (item['replyTo'] ?? '').toString().trim();
                      return replyTo.isEmpty ||
                          !commentsById.containsKey(replyTo);
                    }).toList();

                    for (final replies in repliesByParent.values) {
                      replies.sort((a, b) => tsOf(a).compareTo(tsOf(b)));
                    }

                    rootComments.sort((a, b) => tsOf(b).compareTo(tsOf(a)));

                    if (rootComments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.forum_outlined,
                                size: 44,
                                color: Color(0xFFCBD5E1),
                              ),
                              SLSpacing.h12,
                              Text(
                                _ct(
                                  context.tr('home_no_comments_kind_start'),
                                  'No comments yet.\nBe the first to start with a kind note.',
                                ),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      itemCount: rootComments.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= rootComments.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFD81B60))),
                          );
                        }
                        return _buildCommentThread(
                          rootComments[index],
                          repliesByParent,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentThread(
    Map<String, dynamic> item,
    Map<String, List<Map<String, dynamic>>> repliesByParent, {
    int depth = 0,
  }) {
    final commentId = item['id'].toString();
    final author = _readAuthor(item);
    final text = _readText(item);
    final avatarUrl = _readAvatar(item);
    final ts = _readTimestamp(item['ts']);
    final likesMap = _readLikeMap(item['likes_map']);
    final likeCount = likesMap.length;
    final isLikedByMe = likesMap.containsKey(_resolvedHouseId);
    final replies =
        repliesByParent[commentId] ?? const <Map<String, dynamic>>[];
    final leftPadding = math.min(depth * 24.0, 72.0);

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentRow(
            author: author,
            text: text,
            avatarUrl: avatarUrl,
            ts: ts,
            likeCount: likeCount,
            isLiked: isLikedByMe,
            onLike: () => _toggleLikeComment(commentId, likesMap),
            onReply: () => _onReplyTap(commentId, author),
            onReport: () => _reportComment(commentId),
            isReply: depth > 0,
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replies
                    .map((reply) => _buildCommentThread(
                          reply,
                          repliesByParent,
                          depth: depth + 1,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentRow({
    required String author,
    required String text,
    required String avatarUrl,
    required int ts,
    required int likeCount,
    required bool isLiked,
    required VoidCallback onLike,
    required VoidCallback onReply,
    required VoidCallback onReport,
    required bool isReply,
  }) {
    String getRelativeTime(int tsMs) {
      final tsFixed = tsMs == 0 ? DateTime.now().millisecondsSinceEpoch : tsMs;
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = ((now - tsFixed) / 1000).floor();
      if (diff < 10) return _ct(context.tr('home_vaxong_e92d16'), 'Just now');
      if (diff < 60) {
        return _ctf(
          context.tr('home_seconds_ago'),
          '{count} seconds ago',
          {'count': diff},
        );
      }
      if (diff < 3600) {
        return _ctf(
          context.tr('home_minutes_ago'),
          '{count} minutes ago',
          {'count': (diff / 60).floor()},
        );
      }
      if (diff < 86400) {
        return _ctf(
          context.tr('home_hours_ago'),
          '{count} hours ago',
          {'count': (diff / 3600).floor()},
        );
      }
      final days = (diff / 86400).floor();
      if (days < 7) {
        return _ctf(
          context.tr('home_days_ago'),
          '{count} days ago',
          {'count': days},
        );
      }
      if (days < 14) return _ct(context.tr('home_1tuntrc_ed1eec'), '1 week ago');
      if (days < 21) return _ct(context.tr('home_2tuntrc_d6d1af'), '2 weeks ago');
      if (days < 28) return _ct(context.tr('home_3tuntrc_22d4b4'), '3 weeks ago');
      if (days < 31) return _ct(context.tr('home_4tuntrc_186dd2'), '4 weeks ago');
      final d = DateTime.fromMillisecondsSinceEpoch(tsFixed);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    final timeStr = getRelativeTime(ts);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isReply)
            Positioned(
              left: -12,
              top: 15,
              child: Container(
                  width: 12, height: 2, color: const Color(0xFFE4E6EB)),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        author.isNotEmpty ? author[0].toUpperCase() : '?',
                        style: TextStyle(
                            fontSize: isReply ? 10 : 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD81B60)),
                      )
                    : null,
              ),
              SLSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: SLRadius.lgAll,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            author,
                            maxLines: 2,
                            overflow: TextOverflow.fade,
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                          SLSpacing.gapH(2),
                          Text(
                            text,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              color: const Color(0xFF050505),
                              height: 1.3,
                            ),
                          ),
                          if (likeCount > 0 || isLiked)
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: onLike,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 13,
                                        color: isLiked
                                            ? const Color(0xFFE91E63)
                                            : const Color(0xFF888888),
                                      ),
                                      SLSpacing.w4,
                                      Text(
                                        '$likeCount',
                                        style: SLTheme.quicksand(
                                          fontSize: 11,
                                          color: const Color(0xFF888888),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SLSpacing.h4,
                    Row(
                      children: [
                        SLSpacing.w8,
                        Text(
                          timeStr,
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            color: const Color(0xFF65676B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SLSpacing.w12,
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            _ct(context.tr('home_trli_4c5df0'), 'Reply'),
                            style: SLTheme.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF65676B),
                            ),
                          ),
                        ),
                        SLSpacing.w12,
                        GestureDetector(
                          onTap: onReport,
                          child: Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: Colors.red[300],
                          ),
                        ),
                        if (likeCount == 0 && !isLiked) ...[
                          SLSpacing.w12,
                          GestureDetector(
                            onTap: onLike,
                            child: Text(
                              _ct(context.tr('home_thch_436ce5'), 'Like'),
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF65676B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_replyingToAuthorName != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F5),
              borderRadius: SLRadius.lgAll,
              border: Border.all(color: const Color(0xFFF8BBD0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _ctf(
                      'Đang trả lời: {name}',
                      'Replying to: {name}',
                      {'name': _replyingToAuthorName},
                    ),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _onCancelReply,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFFD81B60),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  focusNode: _focusNode,
                  maxLength: _communityCommentMaxLength,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                  decoration: InputDecoration(
                    hintText: _replyingToAuthorName != null
                        ? _ct(context.tr('home_vitcutrli_15710b'), 'Write a reply...')
                        : _ct(context.tr('home_vitbnhlun_7ec6cd'), 'Write a comment...'),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: SLRadius.xlAll,
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: SLRadius.xlAll,
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: SLRadius.xlAll,
                      borderSide: const BorderSide(color: Color(0xFFD81B60)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              SLSpacing.w8,
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFFFF6F91),
                      Color(0xFFD81B60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: SLRadius.lgAll,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _sendComment,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
