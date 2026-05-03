import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/story_service.dart';
import '../../../core/sl_theme.dart';

class StoryBar extends StatefulWidget {
  final String houseId;
  final String myName;

  const StoryBar({super.key, required this.houseId, required this.myName});

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  final StoryService _service = StoryService();
  late Stream<List<Map<String, dynamic>>> _storiesStream;
  bool _didPromptPendingStoryRetry = false;

  @override
  void initState() {
    super.initState();
    _storiesStream = _service.streamStories(widget.houseId);
    unawaited(_promptPendingStoryRetryIfNeeded());
  }

  @override
  void didUpdateWidget(covariant StoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _storiesStream = _service.streamStories(widget.houseId);
    }
  }

  Future<void> _promptPendingStoryRetryIfNeeded() async {
    if (_didPromptPendingStoryRetry || !mounted) {
      return;
    }
    final hasPending = await _service.hasPendingStoryUpload(widget.houseId);
    if (!hasPending || !mounted) {
      return;
    }
    _didPromptPendingStoryRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lần upload Story trước đã bị gián đoạn.'),
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(
                _service.retryPendingStoryUpload(widget.houseId, widget.myName),
              );
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final StoryService service = _service;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _storiesStream,
      builder: (context, snapshot) {
        final stories = snapshot.data ?? [];

        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: 1 + stories.length, // Initial 'upload' button
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return _buildAddStory(ctx, service);
              }
              final story = stories[i - 1];
              return _buildStoryItem(ctx, story);
            },
          ),
        );
      },
    );
  }

  Widget _buildAddStory(BuildContext ctx, StoryService service) {
    return GestureDetector(
      onTap: () => service.uploadStory(widget.houseId, widget.myName),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: const Center(
                      child: Icon(Icons.add_a_photo,
                          color: Colors.white, size: 28)),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.blueAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              ],
            ),
            SLSpacing.h8,
            Text('Thêm Story',
                style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(BuildContext context, Map<String, dynamic> story) {
    return GestureDetector(
      onTap: () => _showStoryViewer(context, story),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Colors.purple, Colors.orange, Colors.yellow]),
              ),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: DecorationImage(
                      image: CachedNetworkImageProvider(story['url']),
                      fit: BoxFit.cover),
                ),
              ),
            ),
            SLSpacing.h8,
            Text(story['author'] ?? 'Ai đó',
                style: SLTheme.quicksand(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _showStoryViewer(BuildContext context, Map<String, dynamic> story) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.black.withOpacity(0.95))),
          Container(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 800),
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: CachedNetworkImageProvider(story['url']),
                  fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: Row(children: [
              const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white70)),
              SLSpacing.w8,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(story['author'] ?? 'Người yêu',
                    style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                        fontSize: 13)),
                Text('Vừa mới đăng',
                    style: SLTheme.quicksand(
                        color: Colors.white70,
                        fontSize: 10,
                        decoration: TextDecoration.none)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
