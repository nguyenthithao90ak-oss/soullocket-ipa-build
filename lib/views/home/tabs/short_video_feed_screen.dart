// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

import '../../../models/social_post.dart';
import '../../../services/social_service.dart';
import '../../ui_prefs.dart';
import '../../visitors/visitor_profile_screen.dart';
import '../../../services/l10n_service.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/sl_notice.dart';
import '../../../utils/app_error_mapper.dart';

part 'short_video_feed_post_card.dart';
part 'short_video_feed_comment_sheet.dart';
part 'short_video_feed_effects.dart';

/// ============================================================
///  ShortVideoFeedScreen — Feed cuộn dọc cho ảnh và video
///  Hiển thị bài đăng full screen, vuốt lên/xuống chuyển
/// ============================================================
class ShortVideoFeedScreen extends StatefulWidget {
  final String houseId; // The ID of the currently logged in house (viewer)
  final String?
      targetHouseId; // The ID of the house to fetch feed for (if filterType == 'house')
  final String
      filterType; // 'global' | 'friends' | 'tophot' | 'house' | 'liked'
  final int initialIndex;
  final List<SocialPost>? initialPosts;

  const ShortVideoFeedScreen({
    super.key,
    required this.houseId,
    this.targetHouseId,
    this.filterType = 'global',
    this.initialIndex = 0,
    this.initialPosts,
  });

  @override
  State<ShortVideoFeedScreen> createState() => _ShortVideoFeedScreenState();
}

class _ShortVideoFeedScreenState extends State<ShortVideoFeedScreen> {
  late final PageController _pageCtrl;
  final SocialService _socialService = SocialService();
  late int _currentIndex;

  final List<_FlyingHeart> _flyingHearts = [];
  List<SocialPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Map<String, dynamic> _blockedUsers = {};
  StreamSubscription? _blockedSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);

    if (widget.initialPosts != null) {
      _posts = widget.initialPosts!;
      _isLoading = false;
      _hasMore = false;
    } else {
      _loadInitialFeed();
    }

    // Listen to blocked users to filter feed
    _blockedSub = FirebaseDatabase.instance
        .ref('houses/${widget.houseId}/blocked_users')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final v = event.snapshot.value;
      final next = <String, dynamic>{};
      if (v is Map) {
        v.forEach((k, val) => next[k.toString()] = val);
      }
      setState(() => _blockedUsers = next);
    });
  }

  Future<void> _loadInitialFeed() async {
    setState(() => _isLoading = true);
    final posts = await _fetchPage(null);
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
        _hasMore = posts.length >= 10;
      });
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_isLoadingMore || !_hasMore || _posts.isEmpty) return;
    setState(() => _isLoadingMore = true);
    final oldestTs = _posts.last.timestamp.millisecondsSinceEpoch;
    final olderPosts = await _fetchPage(oldestTs);

    if (mounted) {
      setState(() {
        if (olderPosts.isEmpty) {
          _hasMore = false;
        } else {
          _posts.addAll(olderPosts);
          _hasMore = olderPosts.length >= 10;
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<List<SocialPost>> _fetchPage(int? endBeforeTs) async {
    if (widget.filterType == 'house' && widget.targetHouseId != null) {
      return _socialService.fetchHouseFeedPage(widget.targetHouseId!,
          endBeforeTs: endBeforeTs);
    } else if (widget.filterType == 'liked' && widget.targetHouseId != null) {
      return _socialService.fetchLikedFeedPage(widget.targetHouseId!,
          endBeforeTs: endBeforeTs);
    } else if (widget.filterType == 'repost' && widget.targetHouseId != null) {
      return _socialService.fetchRepostFeedPage(widget.targetHouseId!,
          endBeforeTs: endBeforeTs);
    } else if (widget.filterType == 'private' && widget.targetHouseId != null) {
      return _socialService.fetchPrivateFeedPage(widget.targetHouseId!,
          endBeforeTs: endBeforeTs);
    } else if (widget.filterType == 'locket_profile' &&
        widget.targetHouseId != null) {
      return _socialService.fetchLocketFeedPage(widget.targetHouseId!,
          endBeforeTs: endBeforeTs);
    } else {
      return _socialService.fetchFeedByTypePage(
        feedType: widget.filterType,
        houseId: widget.targetHouseId,
        endBeforeTs: endBeforeTs,
      );
    }
  }

  void _triggerHeartEffect(Offset position) {
    for (int i = 0; i < 6; i++) {
      setState(() {
        _flyingHearts.add(_FlyingHeart(
          id: DateTime.now().millisecondsSinceEpoch + i,
          position: position,
        ));
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _blockedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          L10nService().translate('community_title'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
          else if (_posts.isEmpty)
            _buildEmpty()
          else
            Builder(builder: (context) {
              final viewerId = widget.houseId;
              final isMe = viewerId == widget.targetHouseId;
              final mediaPosts = _posts.where((p) {
                if (p.imageUrl.isEmpty && p.videoUrl.isEmpty) {
                  return false;
                }
                if (_blockedUsers.containsKey(p.houseId) &&
                    _blockedUsers[p.houseId] == true) {
                  return false;
                }
                if (isMe) {
                  return true;
                }
                if (p.privacy == 'private') {
                  return false;
                }
                return true;
              }).toList();

              if (mediaPosts.isEmpty) return _buildEmpty();

              return PageView.builder(
                controller: _pageCtrl,
                scrollDirection: Axis.vertical,
                itemCount: mediaPosts.length + (_hasMore ? 1 : 0),
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                  if (i >= mediaPosts.length - 2) {
                    _loadMoreFeed();
                  }
                },
                itemBuilder: (context, index) {
                  if (index >= mediaPosts.length) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFE91E8C)),
                    );
                  }
                  final post = mediaPosts[index];
                  return _ShortVideoFeedPostCard(
                    key: ValueKey('${post.id}_${post.videoUrl}_${post.imageUrl}'),
                    post: post,
                    houseId: widget.houseId,
                    blockedUsers: _blockedUsers,
                    isActive: index == _currentIndex,
                    onDoubleTap: (pos) => _triggerHeartEffect(pos),
                  );
                },
              );
            }),
              ..._flyingHearts.map((h) => _HeartAnimation(
                key: ValueKey(h.id),
                heart: h,
                onComplete: () {
                  setState(() =>
                      _flyingHearts.removeWhere((item) => item.id == h.id));
                },
              )),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 64, color: Colors.white24),
            SLSpacing.h16,
            Text(
              L10nService()
                  .translate('Chưa có bài đăng ảnh\nHãy là người đầu tiên!'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
}
