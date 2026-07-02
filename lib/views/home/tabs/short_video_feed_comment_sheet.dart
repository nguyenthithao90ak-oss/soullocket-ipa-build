part of 'short_video_feed_screen.dart';

class _CommentSheet extends StatefulWidget {
  final String postId;
  final String houseId;
  final Map<String, dynamic> blockedUsers;

  const _CommentSheet({
    required this.postId,
    required this.houseId,
    required this.blockedUsers,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SocialService _socialService = SocialService();

  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  bool _loading = true;
  StreamSubscription? _commentsSub;

  @override
  void initState() {
    super.initState();
    _listenToComments();
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _listenToComments() {
    _commentsSub?.cancel();
    _commentsSub = FirebaseFirestore.instance
        .collection('social_posts')
        .doc(widget.postId)
        .collection('comments')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final loaded = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final item = doc.data();
        if (item['isHidden'] == true) continue;

        final authorId = (item['houseId'] ?? item['uid'] ?? '').toString();
        if (authorId.isNotEmpty && widget.blockedUsers[authorId] == true) {
          continue;
        }

        loaded.add(<String, dynamic>{
          'id': doc.id,
          'content':
              (item['content'] ?? item['c'] ?? item['text'] ?? '').toString(),
          'author_name': (item['authorName'] ??
                  item['author_name'] ??
                  item['author'] ??
                  item['name'] ??
                  item['u'] ??
                  context.tr('home_ngidng_3bf886'))
              .toString(),
          'author_id': authorId,
          'author_avt': (item['authorAvt'] ??
                  item['avt'] ??
                  item['avatar'] ??
                  item['houseAvt'] ??
                  '')
              .toString(),
          'created_at': item['ts'] ?? 0,
        });
      }

      loaded.sort((a, b) {
        final left = (a['created_at'] as num?)?.toInt() ?? 0;
        final right = (b['created_at'] as num?)?.toInt() ?? 0;
        return right.compareTo(left);
      });

      setState(() {
        _comments = loaded;
        _loading = false;
      });
    });
  }

  Future<void> _postComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final validationError =
        _socialService.validateCommunityText(text, isComment: true);
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    final hasViolations = _socialService.containsBlockedCommunityTerms(text);
    final msgViolation = context.tr('home_bnhlunchat_482499');
    final msgError = context.tr('home_chathgibnh_095854');
    _ctrl.clear();

    try {
      await _socialService.postComment(
        postId: widget.postId,
        houseId: widget.houseId,
        content: text,
      );
      if (hasViolations) {
        _showSnack(msgViolation);
      }
    } catch (e) {
      _showSnack(msgError);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bình luận (${_comments.length})',
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('home_chacbnhlun_8fff46'),
                              style: SLTheme.quicksand(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _comments.length,
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            itemBuilder: (context, index) {
                              return _buildCommentItem(_comments[index]);
                            },
                          ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
                  left: 12,
                  right: 12,
                  top: 8,
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    SLSpacing.w12,
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        style: SLTheme.quicksand(fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _postComment(),
                        decoration: InputDecoration(
                          hintText: context.tr('home_thmbnhlun_7cc7c1'),
                          hintStyle: SLTheme.quicksand(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: SLRadius.xlAll,
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    SLSpacing.w8,
                    IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFFD81B60),
                      ),
                      onPressed: _postComment,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> c) {
    final authorId = c['author_id']?.toString() ?? '';
    final authorAvt = c['author_avt']?.toString() ?? '';
    final authorName = c['author_name']?.toString() ?? context.tr('home_ngidng_3bf886');

    return InkWell(
      onLongPress: () => _showCommentOptions(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (authorId.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VisitorProfileScreen(targetHouseId: authorId),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: authorAvt.isNotEmpty
                    ? CachedNetworkImageProvider(authorAvt)
                    : null,
                child: authorAvt.isEmpty
                    ? Text(
                        authorName.isNotEmpty
                            ? authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD81B60),
                        ),
                      )
                    : null,
              ),
            ),
            SLSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (authorId.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VisitorProfileScreen(targetHouseId: authorId),
                        ),
                      );
                    },
                    child: Text(
                      authorName,
                      style: SLTheme.quicksand(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  SLSpacing.h4,
                  Text(
                    c['content']?.toString() ?? '',
                    style:
                        SLTheme.quicksand(fontSize: 14, color: Colors.black87),
                  ),
                  SLSpacing.h8,
                  Row(
                    children: [
                      Text(
                        _formatTime(c['created_at']),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      SLSpacing.w16,
                      GestureDetector(
                        onTap: () {
                          _focusNode.requestFocus();
                          _ctrl.text = '@$authorName ';
                          _ctrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: _ctrl.text.length),
                          );
                        },
                        child: Text(
                          context.tr('home_trli_4c5df0'),
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.favorite_border, size: 16, color: Colors.grey[500]),
                SLSpacing.gapH(2),
                Text(
                  '0',
                  style:
                      SLTheme.quicksand(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return context.tr('home_vaxong_e92d16');
    try {
      final dateTime = ts is int
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.parse(ts.toString());
      final diff = DateTime.now().difference(dateTime);
      if (diff.inDays > 0) return '${diff.inDays} ngày trước';
      if (diff.inHours > 0) return '${diff.inHours} giờ trước';
      if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
      return context.tr('home_vaxong_e92d16');
    } catch (_) {
      return context.tr('home_vaxong_e92d16');
    }
  }

  void _showCommentOptions(Map<String, dynamic> c) {
    final authorName = c['author_name']?.toString() ?? context.tr('home_ngidng_3bf886');
    final authorId = c['author_id']?.toString() ?? '';
    final isMyComment = authorId == widget.houseId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: Text(context.tr('home_trli_4c5df0'), style: SLTheme.quicksand()),
                onTap: () {
                  Navigator.pop(context);
                  _focusNode.requestFocus();
                  _ctrl.text = '@$authorName ';
                  _ctrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _ctrl.text.length),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(context.tr('home_saochp_cbfba9'), style: SLTheme.quicksand()),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(
                    ClipboardData(text: c['content']?.toString() ?? ''),
                  );
                  _showSnack(context.tr('home_saochpbnhl_be6ed7'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: Colors.orange),
                title: Text(context.tr('home_bocobnhlun_7e340e'), style: SLTheme.quicksand()),
                onTap: () async {
                  Navigator.pop(context);
                  final msgReportOk = context.tr('home_gibocobnhl_48e423');
                  final msgReportErr = context.tr('home_chathgiboc_05046c');
                  final reason = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final rCtrl = TextEditingController();
                      return AlertDialog(
                        title: Text(
                          context.tr('home_bocobnhlun_7e340e'),
                          style: SLTheme.quicksand(fontWeight: FontWeight.bold),
                        ),
                        content: TextField(
                          controller: rCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: context.tr('home_ldoboco_1a5afa'),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(context.tr('home_hy_1e4050')),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, rCtrl.text.trim()),
                            child: Text(context.tr('home_gi_377294')),
                          ),
                        ],
                      );
                    },
                  );
                  if (reason == null || reason.isEmpty) return;

                  try {
                    await _socialService.reportComment(
                      postId: widget.postId,
                      commentId: c['id'].toString(),
                      reporterHouseId: widget.houseId,
                      reason: reason,
                    );
                    _showSnack(msgReportOk);
                  } catch (e) {
                    _showSnack(msgReportErr);
                  }
                },
              ),
              if (!isMyComment)
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.red),
                  title: Text(
                    context.tr('home_chnngidngn_27d0c8'),
                    style: SLTheme.quicksand(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (authorId.isEmpty) return;
                    final msgBlockOk = context.tr('home_chnngidng_1c851c');
                    final msgBlockErr = context.tr('home_chathchnng_81d840');

                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          context.tr('home_xcnhnchn_ae00a6'),
                          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                        ),
                        content: Text(
                          'Bạn có chắc muốn chặn người này không?\nHọ sẽ không thể xem nhà bạn nữa.',
                          style: SLTheme.quicksand(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(context.tr('home_hy_1e4050')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              context.tr('home_chn_483b6f'),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    try {
                      await _socialService.blockHouse(
                        sourceHouseId: widget.houseId,
                        targetHouseId: authorId,
                      );
                      _showSnack(msgBlockOk);
                    } catch (e) {
                      _showSnack(msgBlockErr);
                    }
                  },
                ),
              if (isMyComment)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: Text(
                    context.tr('home_xa_4ed187'),
                    style: SLTheme.quicksand(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final msgDeleteErr = context.tr('home_chathxabnh_44e3be');
                    try {
                      await _socialService.deleteComment(
                        commentId: c['id'].toString(),
                        postId: widget.postId,
                        requestingHouseId: widget.houseId,
                      );
                    } catch (e) {
                      _showSnack(msgDeleteErr);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
