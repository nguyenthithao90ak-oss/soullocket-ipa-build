import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../utils/screen_activity_mixin.dart';
import '../../../utils/services/l10n_service.dart';

class CinemaTeaserPlayer extends StatefulWidget {
  const CinemaTeaserPlayer({
    super.key,
    required this.photoCount,
    required this.photoBuilder,
  }) : assert(photoCount > 0);

  final int photoCount;
  final IndexedWidgetBuilder photoBuilder;

  @override
  State<CinemaTeaserPlayer> createState() => _CinemaTeaserPlayerState();
}

class _CinemaTeaserPlayerState extends State<CinemaTeaserPlayer>
    with ScreenActivityMixin {
  Timer? _timer;
  int _index = 0;
  bool _playing = true;
  bool _finished = false;
  bool _reduceMotion = false;

  int get _count => math.min(widget.photoCount, 3);

  @override
  void didChangeDependencies() {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _playing = false;
    super.didChangeDependencies();
    _scheduleFrame();
  }

  @override
  void onScreenActivityChanged(bool active) => _scheduleFrame();

  void _scheduleFrame() {
    _timer?.cancel();
    if (!isScreenActive || !_playing || _reduceMotion || _finished) return;
    _timer = Timer(const Duration(seconds: 3), () {
      if (!isScreenActive) return;
      if (_index == _count - 1) {
        setState(() {
          _finished = true;
          _playing = false;
        });
      } else {
        setState(() => _index++);
        _scheduleFrame();
      }
    });
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _finished = false;
    });
    _scheduleFrame();
  }

  void _toggle() {
    setState(() {
      if (_finished) {
        _index = 0;
        _finished = false;
        _playing = true;
      } else {
        _playing = !_playing;
      }
    });
    _scheduleFrame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFFFFF9F4),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('cinema_teaser_action'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF443548),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('close'),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: AnimatedSwitcher(
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 500),
                  child: SizedBox.expand(
                    key: ValueKey('cinema-teaser-frame-$_index'),
                    child: widget.photoBuilder(context, _index),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  key: const Key('cinema-teaser-previous'),
                  tooltip: context.tr('p8_cinema_previous_frame'),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _index == 0 ? null : () => _select(_index - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_index + 1}/$_count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF443548),
                    ),
                  ),
                ),
                if (!_reduceMotion)
                  IconButton(
                    key: const Key('cinema-teaser-play-pause'),
                    tooltip: context.tr(
                      _finished
                          ? 'retry'
                          : (_playing
                                ? 'memory_video_pause'
                                : 'memory_video_play'),
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _toggle,
                    icon: Icon(
                      _finished
                          ? Icons.replay_rounded
                          : (_playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                    ),
                  ),
                IconButton(
                  key: const Key('cinema-teaser-next'),
                  tooltip: context.tr('p8_cinema_next_frame'),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _index == _count - 1
                      ? null
                      : () => _select(_index + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('cinema_teaser_body'),
              style: const TextStyle(
                color: Color(0xFF786B7D),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
