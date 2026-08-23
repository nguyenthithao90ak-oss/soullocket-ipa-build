import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';

class AudioWaveformBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final Duration? initialDuration;

  const AudioWaveformBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.initialDuration,
  });

  @override
  State<AudioWaveformBubble> createState() => _AudioWaveformBubbleState();
}

class _AudioWaveformBubbleState extends State<AudioWaveformBubble>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  double _playbackSpeed = 1.0;

  // Cố định mẫu sóng âm ngẫu nhiên đẹp mắt theo mã băm của URL
  late final List<double> _waveformSamples;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = widget.initialDuration ?? Duration.zero;
    _waveformSamples = _generateWaveform(widget.audioUrl);

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted && dur > Duration.zero) {
        setState(() => _duration = dur);
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          if (state == PlayerState.playing) {
            _isLoading = false;
          }
          if (state == PlayerState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  List<double> _generateWaveform(String seedStr) {
    final seed = seedStr.hashCode.abs();
    final random = math.Random(seed);
    const int count = 28;
    final samples = <double>[];
    for (int i = 0; i < count; i++) {
      // Dải sóng có hình chuông tự nhiên (thấp ở 2 đầu, cao ở giữa)
      final envelope = math.sin((i + 1) / (count + 1) * math.pi);
      final raw = 0.25 + (random.nextDouble() * 0.75);
      samples.add((raw * envelope).clamp(0.18, 1.0));
    }
    return samples;
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        setState(() => _isLoading = true);
        try {
          final url = widget.audioUrl.trim();
          if (url.startsWith('http://') || url.startsWith('https://')) {
            await _player.play(UrlSource(url));
          } else {
            await _player.play(DeviceFileSource(url));
          }
          await _player.setPlaybackRate(_playbackSpeed);
        } catch (e) {
          debugPrint('[AudioWaveformBubble] Playback error: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    }
  }

  Future<void> _toggleSpeed() async {
    double nextSpeed;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }
    setState(() => _playbackSpeed = nextSpeed);
    if (_isPlaying) {
      await _player.setPlaybackRate(nextSpeed);
    }
  }

  void _seekToFraction(double fraction) {
    if (_duration.inMilliseconds <= 0) return;
    final targetMs = (fraction * _duration.inMilliseconds).toInt();
    final targetDuration = Duration(milliseconds: targetMs);
    _player.seek(targetDuration);
    setState(() => _position = targetDuration);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final primaryColor = isMe ? Colors.white : const Color(0xFF1E293B);
    final secondaryColor =
        isMe ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF94A3B8);
    final activeWaveColor = isMe ? Colors.white : const Color(0xFFD81B60);
    final inactiveWaveColor = isMe
        ? Colors.white.withValues(alpha: 0.3)
        : const Color(0xFFE2E8F0);

    final double progressFraction = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Nút Play / Pause / Loading
              GestureDetector(
                onTap: _isLoading ? null : _togglePlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFFFEBF2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                activeWaveColor,
                              ),
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: isMe ? Colors.white : const Color(0xFFD81B60),
                            size: 24,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Sóng âm tương tác Scrubbing Waveform
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final fraction =
                            (details.localPosition.dx / width).clamp(0.0, 1.0);
                        _seekToFraction(fraction);
                      },
                      onHorizontalDragUpdate: (details) {
                        final fraction =
                            (details.localPosition.dx / width).clamp(0.0, 1.0);
                        _seekToFraction(fraction);
                      },
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(
                            _waveformSamples.length,
                            (index) {
                              final sampleFraction =
                                  index / _waveformSamples.length;
                              final isPlayed =
                                  sampleFraction <= progressFraction;
                              final barHeight =
                                  (_waveformSamples[index] * 28).clamp(5.0, 28.0);

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                width: 2.8,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isPlayed
                                      ? activeWaveColor
                                      : inactiveWaveColor,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Hàng thời gian & Tốc độ phát 1.0x / 1.5x / 2.0x
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isPlaying || _position > Duration.zero
                    ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                    : (_duration > Duration.zero
                        ? _formatDuration(_duration)
                        : 'Voice note'),
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: secondaryColor,
                ),
              ),
              GestureDetector(
                onTap: _toggleSpeed,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.15)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: SLTheme.quicksand(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
