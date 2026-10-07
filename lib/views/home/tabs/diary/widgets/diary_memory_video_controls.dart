import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../../utils/services/l10n_service.dart';

/// Định dạng thời lượng video: `m:ss`, hoặc `h:mm:ss` khi dài từ 1 giờ.
String formatMemoryVideoClock(Duration value) {
  final seconds = math.max(0, value.inSeconds);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}

/// Thanh điều khiển video kỷ niệm: nút phát/tạm dừng, thanh tua (kèm phần đã tải) và
/// thời gian. Đặt ở lớp giao diện của màn xem (không nằm trong vùng phóng to) để không
/// bị lớp tối ở chân màn hình che hoặc phóng to theo video.
class DiaryMemoryVideoControls extends StatefulWidget {
  const DiaryMemoryVideoControls({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  State<DiaryMemoryVideoControls> createState() =>
      _DiaryMemoryVideoControlsState();
}

class _DiaryMemoryVideoControlsState extends State<DiaryMemoryVideoControls> {
  // Vị trí đang kéo; null khi không kéo (hiển thị theo vị trí phát thật).
  Duration? _dragPosition;
  bool _resumeAfterDrag = false;

  @override
  void didUpdateWidget(covariant DiaryMemoryVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _dragPosition = null;
      _resumeAfterDrag = false;
    }
  }

  Duration _fromSlider(double value) => Duration(milliseconds: value.round());

  void _togglePlayback() {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else {
      // Phát lại từ đầu khi đã tới cuối (video kỷ niệm thường lặp, đây là phòng hờ).
      final value = controller.value;
      if (value.duration > Duration.zero && value.position >= value.duration) {
        unawaited(controller.seekTo(Duration.zero));
      }
      unawaited(controller.play());
    }
  }

  void _startDrag(double value) {
    final controller = widget.controller;
    _resumeAfterDrag = controller.value.isPlaying;
    // Tạm dừng trong lúc kéo để hình không giật theo từng lần tua.
    if (_resumeAfterDrag) unawaited(controller.pause());
    setState(() => _dragPosition = _fromSlider(value));
  }

  Future<void> _endDrag(double value) async {
    final controller = widget.controller;
    final target = _fromSlider(value);
    setState(() => _dragPosition = target);
    try {
      await controller.seekTo(target);
      if (_resumeAfterDrag &&
          mounted &&
          identical(controller, widget.controller)) {
        await controller.play();
      }
    } catch (_) {
      /* Controller đã được giải phóng (đổi ảnh/đóng màn): bỏ qua lượt tua. */
    } finally {
      if (mounted && identical(controller, widget.controller)) {
        setState(() => _dragPosition = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        if (!value.isInitialized || value.hasError) {
          return const SizedBox.shrink();
        }
        final totalMs = value.duration.inMilliseconds;
        final canSeek = totalMs > 0;
        final position = _dragPosition ?? value.position;
        final current = canSeek
            ? position.inMilliseconds.clamp(0, totalMs).toDouble()
            : 0.0;
        final bufferedMs = value.buffered.fold<int>(
          0,
          (end, range) => math.max(end, range.end.inMilliseconds),
        );
        final buffered = canSeek
            ? bufferedMs.clamp(0, totalMs).toDouble()
            : 0.0;
        final playing =
            value.isPlaying || (_dragPosition != null && _resumeAfterDrag);
        final clock =
            '${formatMemoryVideoClock(position)} / ${formatMemoryVideoClock(value.duration)}';

        return GestureDetector(
          // Chạm vào khoảng trống của thanh không lọt xuống video/màn xem phía dưới.
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 14, 2),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('memory-video-play-toggle'),
                    tooltip: l10n.translate(
                      playing ? 'memory_video_pause' : 'memory_video_play',
                    ),
                    onPressed: _togglePlayback,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Semantics(
                      label: l10n.translate('memory_video_seek'),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.22,
                          ),
                          secondaryActiveTrackColor: Colors.white.withValues(
                            alpha: 0.45,
                          ),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.18),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 18,
                          ),
                        ),
                        child: Slider(
                          key: const ValueKey('memory-video-seek'),
                          value: current,
                          max: canSeek ? totalMs.toDouble() : 1,
                          secondaryTrackValue: canSeek ? buffered : null,
                          onChangeStart: canSeek ? _startDrag : null,
                          onChanged: canSeek
                              ? (next) => setState(
                                  () => _dragPosition = _fromSlider(next),
                                )
                              : null,
                          onChangeEnd: canSeek
                              ? (next) => unawaited(_endDrag(next))
                              : null,
                          semanticFormatterCallback: (next) =>
                              l10n.format('memory_video_position', {
                                'position': formatMemoryVideoClock(
                                  _fromSlider(next),
                                ),
                                'duration': formatMemoryVideoClock(
                                  value.duration,
                                ),
                              }),
                        ),
                      ),
                    ),
                  ),
                  // Nhãn thời gian giới hạn cỡ chữ và tự co lại (video dài, màn 320px)
                  // để thanh tua luôn còn đủ chỗ kéo.
                  Flexible(
                    flex: 2,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          clock,
                          key: const ValueKey('memory-video-clock'),
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
