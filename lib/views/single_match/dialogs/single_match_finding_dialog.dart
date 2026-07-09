import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';

class SingleMatchFindingDialog extends StatefulWidget {
  final String currentHouseId;
  final Set<String> excludeHouseIds;
  final bool isVideo;
  final bool isChat;

  const SingleMatchFindingDialog({
    super.key,
    required this.currentHouseId,
    required this.excludeHouseIds,
    this.isVideo = false,
    this.isChat = false,
  });

  @override
  State<SingleMatchFindingDialog> createState() =>
      _SingleMatchFindingDialogState();
}

class _SingleMatchFindingDialogState extends State<SingleMatchFindingDialog>
    with SingleTickerProviderStateMixin {
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
    _doSearch();
  }

  Future<void> _doSearch() async {
    final start = DateTime.now();
    final pick = await SingleMatchService.instance.pickScoredMatch(
      currentHouseId: widget.currentHouseId,
      excludeHouseIds: widget.excludeHouseIds,
      goal: '',
      voiceStyle: '',
      myTags: const [],
      needAudio: widget.isChat ? false : !widget.isVideo,
      needVideo: widget.isChat ? false : widget.isVideo,
    );

    final diff = DateTime.now().difference(start);
    if (diff.inSeconds < 3) {
      await Future.delayed(Duration(seconds: 3 - diff.inSeconds));
    }

    if (mounted) {
      Navigator.pop(context, pick);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isChat
        ? const Color(0xFFFF4F87)
        : (widget.isVideo ? const Color(0xFF7C61FF) : const Color(0xFFFF4F87));

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, child) {
                        return Container(
                          width: 100 + (_animCtrl.value * 60),
                          height: 100 + (_animCtrl.value * 60),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(
                                alpha: 0.15 - (_animCtrl.value * 0.15)),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isChat
                            ? Icons.chat_rounded
                            : (widget.isVideo
                                ? Icons.videocam_rounded
                                : Icons.call_rounded),
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tìm kiếm...',
                style: SLTheme.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF32203B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hệ thống đang quét những người phù hợp với bạn',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A798E),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '00:${_seconds.toString().padLeft(2, '0')}',
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF5A495E),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, 'cancelled');
                },
                child: Text(
                  'Hủy tìm kiếm',
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
