part of 'community_tab.dart';

extension _CommunityTabLocket on _CommunityTabState {
  Widget _buildLocketFeedView(List<Map<String, dynamic>> allPosts) {
    final imagePosts = allPosts
        .where((p) => (p['imageUrl'] ?? '').toString().isNotEmpty)
        .toList();
    final hasImagePosts = imagePosts.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async => _init(),
      color: const Color(0xFFFFB300),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        itemCount: hasImagePosts ? imagePosts.length + 3 : 4,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CommunityHeaderActionStrip(
              state: this,
              includeTopPadding: true,
            );
          }
          if (index == 1) return _FeedTabSelector(state: this);
          if (index == 2) return _buildLocketCameraPlaceholder();
          if (!hasImagePosts) return _buildLocketEmptyState();

          final post = imagePosts[index - 3];
          return _buildLocketPostCard(post);
        },
      ),
    );
  }

  Widget _buildLocketCameraPlaceholder() {
    return GestureDetector(
      onTap: _openLocketCamera,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 120,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: SLRadius.xlAll,
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: SLSpacing.all16,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 32, color: Colors.black),
            ),
            SLSpacing.w16,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ct('Khoảnh Khắc', 'Moments'),
                  style: SLTheme.quicksand(
                    color: _textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  _ct(
                    'Chạm để gửi ảnh cho bạn bè',
                    'Tap to send a photo to friends',
                  ),
                  style: SLTheme.quicksand(
                    color: _subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocketEmptyState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: _borderColor, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5D6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFE08A)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.photo_camera_back_outlined,
              color: Color(0xFFFFB300),
              size: 28,
            ),
          ),
          SLSpacing.h12,
          Text(
            _ct('Chưa có khoảnh khắc nào', 'No moments yet'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: _textColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _ct(
              'Chạm vào thẻ phía trên để gửi ảnh đầu tiên cho bạn bè.',
              'Tap the card above to send your first photo to friends.',
            ),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: _subTextColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocketActionIcon({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: SLSpacing.all12,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          if (label != '0' && label != '') ...[
            SLSpacing.h8,
            Text(
              label,
              style: SLTheme.quicksand(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                shadows: [const Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocketPostCard(Map<String, dynamic> post) {
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final houseName =
        (post['houseName'] ?? _ct('Người lạ', 'Stranger')).toString();
    final houseAvt = (post['houseAvt'] ?? '').toString();
    final ts = _getTimestamp(post);
    final date = DateTime.fromMillisecondsSinceEpoch(
        ts == 0 ? DateTime.now().millisecondsSinceEpoch : ts);
    final timeAgo = _timeAgo(date);

    return Container(
      key: ValueKey((post['id'] ?? '').toString()),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(48),
        color: const Color(0xFF2A2B2E),
      ),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ManualRetryCachedImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                backgroundColor: Colors.grey.shade800,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 180,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      final postHouseId = (post['houseId'] ?? '').toString();
                      if (postHouseId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VisitorProfileScreen(
                                targetHouseId: postHouseId),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[700],
                              backgroundImage: houseAvt.isNotEmpty
                                  ? CachedNetworkImageProvider(houseAvt)
                                  : null,
                              child: houseAvt.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 20, color: Colors.white)
                                  : null,
                            ),
                          ),
                          SLSpacing.h8,
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                houseName,
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    const Shadow(
                                        color: Colors.black54, blurRadius: 4)
                                  ],
                                ),
                              ),
                              SLSpacing.gapH(2),
                              Text(
                                timeAgo,
                                style: SLTheme.quicksand(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    const Shadow(
                                        color: Colors.black54, blurRadius: 4)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 84,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: SLRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(5, (index) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.star,
                                color: Color(0xFFFFB300), size: 28),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openComments(post),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _ct('Gửi tin nhắn...', 'Send a message...'),
                                  style: SLTheme.quicksand(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              SLSpacing.w8,
                              GestureDetector(
                                onTap: () => _toggleLike(post),
                                child: const Text(
                                  '💛',
                                  style: TextStyle(
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                              SLSpacing.w12,
                              GestureDetector(
                                onTap: () => _toggleLike(post),
                                child: const Text(
                                  '🔥',
                                  style: TextStyle(
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                              SLSpacing.w12,
                              GestureDetector(
                                onTap: () => _toggleLike(post),
                                child: const Text(
                                  '😍',
                                  style: TextStyle(
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                              SLSpacing.w12,
                              GestureDetector(
                                onTap: () => _openComments(post),
                                child: const Icon(
                                  Icons.sentiment_satisfied_alt_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SLSpacing.w12,
                    _buildLocketActionIcon(
                      icon: Icons.more_horiz_rounded,
                      color: Colors.white,
                      label: '',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) {
      return _ctf(
        '{count} ngày trước',
        '{count} days ago',
        {'count': diff.inDays},
      );
    }
    if (diff.inHours > 0) {
      return _ctf(
        '{count} giờ trước',
        '{count} hours ago',
        {'count': diff.inHours},
      );
    }
    if (diff.inMinutes > 0) {
      return _ctf(
        '{count} phút trước',
        '{count} minutes ago',
        {'count': diff.inMinutes},
      );
    }
    return _ct('Vừa xong', 'Just now');
  }

  Future<void> _openLocketCamera() async {
    final imageFile = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(builder: (_) => const LocketCameraScreen()),
    );

    if (imageFile == null) return;
    if (!mounted) return;

    final bytes = await imageFile.readAsBytes();
    if (!mounted) return;

    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: SLSpacing.all16,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18191A),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                child: Image.memory(
                  bytes,
                  height: MediaQuery.sizeOf(context).height * 0.45,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: SLSpacing.all20,
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(_ct('Hủy', 'Cancel'),
                            style: SLTheme.quicksand(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SLSpacing.w16,
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: SLRadius.pillAll),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Icon(Icons.send_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (send == true) {
      _postLocketImage(imageFile);
    }
  }

  Future<void> _postLocketImage(XFile imageFile) async {
    await _submitLocketPost(imageFile);
    if (mounted) {
      unawaited(_init());
    }
  }
}
