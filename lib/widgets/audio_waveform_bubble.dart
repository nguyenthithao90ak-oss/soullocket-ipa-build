import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/sound_service.dart';

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
  late AudioPlayer _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  bool _startingPlayback = false;
  bool _resettingPlayer = false;
  VoidCallback? _releaseSoundQuiet;
  int _playerGeneration = 0;
  int _playbackRequestId = 0;

  static const _playerOperationTimeout = Duration(seconds: 12);

  void _releaseQuiet() {
    _releaseSoundQuiet?.call();
    _releaseSoundQuiet = null;
  }

  double _playbackSpeed = 1.0;

  // Cố định mẫu sóng âm ngẫu nhiên đẹp mắt theo mã băm của URL
  late List<double> _waveformSamples;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = widget.initialDuration ?? Duration.zero;
    _waveformSamples = _generateWaveform(widget.audioUrl);
    _attachPlayerListeners();
  }

  void _attachPlayerListeners() {
    final generation = ++_playerGeneration;
    final player = _player;
    _posSub = player.onPositionChanged.listen((pos) {
      if (generation != _playerGeneration) return;
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durSub = player.onDurationChanged.listen((dur) {
      if (generation != _playerGeneration) return;
      if (mounted && dur > Duration.zero) {
        setState(() => _duration = dur);
      }
    });

    _stateSub = player.onPlayerStateChanged.listen((state) {
      if (generation != _playerGeneration) return;
      if (state != PlayerState.playing && !_startingPlayback) _releaseQuiet();
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

  List<StreamSubscription> _detachPlayerListeners() {
    final subscriptions = [
      ...?_posSub == null ? null : [_posSub!],
      ...?_durSub == null ? null : [_durSub!],
      ...?_stateSub == null ? null : [_stateSub!],
    ];
    _posSub = null;
    _durSub = null;
    _stateSub = null;
    return subscriptions;
  }

  void _cleanupDetachedPlayer(
    AudioPlayer player,
    List<StreamSubscription> subscriptions,
  ) {
    for (final subscription in subscriptions) {
      unawaited(
        subscription.cancel().catchError((error) {
          debugPrint('[AudioWaveformBubble] Listener cancel error: $error');
        }),
      );
    }
    unawaited(
      player.stop().catchError((error) {
        debugPrint('[AudioWaveformBubble] Detached player stop error: $error');
      }),
    );
    unawaited(
      player.dispose().catchError((error) {
        debugPrint(
          '[AudioWaveformBubble] Detached player dispose error: $error',
        );
      }),
    );
  }

  Future<void> _replacePlayer({required int expectedGeneration}) async {
    if (!mounted ||
        _resettingPlayer ||
        expectedGeneration != _playerGeneration) {
      return;
    }
    _resettingPlayer = true;
    _playerGeneration++;
    final previousPlayer = _player;
    final previousSubscriptions = _detachPlayerListeners();
    _releaseQuiet();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _startingPlayback = false;
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
        _duration = widget.initialDuration ?? Duration.zero;
      });
    }
    _player = AudioPlayer();
    _attachPlayerListeners();
    _resettingPlayer = false;
    if (mounted) {
      setState(() {
        _isLoading = false;
        _startingPlayback = false;
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
        _duration = widget.initialDuration ?? Duration.zero;
      });
    }
    _cleanupDetachedPlayer(previousPlayer, previousSubscriptions);
  }

  @override
  void didUpdateWidget(covariant AudioWaveformBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl == widget.audioUrl) return;
    _playbackRequestId++;
    _waveformSamples = _generateWaveform(widget.audioUrl);
    _releaseQuiet();
    unawaited(_replacePlayer(expectedGeneration: _playerGeneration));
  }

  @override
  void dispose() {
    _releaseQuiet();
    final subscriptions = _detachPlayerListeners();
    _playerGeneration++;
    _cleanupDetachedPlayer(_player, subscriptions);
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

  bool _isCurrentPlayer(AudioPlayer player, int generation) {
    return mounted &&
        generation == _playerGeneration &&
        identical(player, _player);
  }

  Future<void> _togglePlay() async {
    if (_startingPlayback || _resettingPlayer) return;
    final generation = _playerGeneration;
    final player = _player;
    if (_isPlaying) {
      try {
        await player.pause().timeout(_playerOperationTimeout);
        if (_isCurrentPlayer(player, generation)) _releaseQuiet();
      } catch (error) {
        if (!_isCurrentPlayer(player, generation)) return;
        debugPrint('[AudioWaveformBubble] Pause error: $error');
        unawaited(_replacePlayer(expectedGeneration: generation));
      }
    } else {
      final requestId = ++_playbackRequestId;
      bool isCurrentRequest() =>
          requestId == _playbackRequestId &&
          _isCurrentPlayer(player, generation);
      _startingPlayback = true;
      _releaseSoundQuiet ??= SoundService().holdQuiet();
      final deadline = DateTime.now().add(_playerOperationTimeout);
      try {
        if (_playerState == PlayerState.paused) {
          await player.resume().timeout(_remainingOperationTimeout(deadline));
        } else {
          if (mounted) setState(() => _isLoading = true);
          final url = widget.audioUrl.trim();
          if (url.startsWith('http://') || url.startsWith('https://')) {
            await player
                .play(UrlSource(url))
                .timeout(_remainingOperationTimeout(deadline));
          } else {
            await player
                .play(DeviceFileSource(url))
                .timeout(_remainingOperationTimeout(deadline));
          }
          if (!isCurrentRequest()) return;
          await player
              .setPlaybackRate(_playbackSpeed)
              .timeout(_remainingOperationTimeout(deadline));
        }
        if (!isCurrentRequest()) return;
      } on TimeoutException catch (error) {
        if (!isCurrentRequest()) return;
        debugPrint('[AudioWaveformBubble] Playback timed out: $error');
        await _replacePlayer(expectedGeneration: generation);
      } catch (e) {
        if (!isCurrentRequest()) return;
        _releaseQuiet();
        debugPrint('[AudioWaveformBubble] Playback error: $e');
      } finally {
        if (isCurrentRequest()) {
          _startingPlayback = false;
          setState(() => _isLoading = false);
          if (player.state != PlayerState.playing) _releaseQuiet();
        }
      }
    }
  }

  Duration _remainingOperationTimeout(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining <= Duration.zero
        ? const Duration(milliseconds: 1)
        : remaining;
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
      final generation = _playerGeneration;
      final player = _player;
      try {
        await player
            .setPlaybackRate(nextSpeed)
            .timeout(_playerOperationTimeout);
      } catch (error) {
        if (!_isCurrentPlayer(player, generation)) return;
        debugPrint('[AudioWaveformBubble] Playback rate error: $error');
        unawaited(_replacePlayer(expectedGeneration: generation));
      }
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
    final primaryColor = isMe ? Colors.white : SLColors.darkNavy;
    final secondaryColor = isMe
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF94A3B8);
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
                            color: isMe
                                ? Colors.white
                                : const Color(0xFFD81B60),
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
                        final fraction = (details.localPosition.dx / width)
                            .clamp(0.0, 1.0);
                        _seekToFraction(fraction);
                      },
                      onHorizontalDragUpdate: (details) {
                        final fraction = (details.localPosition.dx / width)
                            .clamp(0.0, 1.0);
                        _seekToFraction(fraction);
                      },
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_waveformSamples.length, (
                            index,
                          ) {
                            final sampleFraction =
                                index / _waveformSamples.length;
                            final isPlayed = sampleFraction <= progressFraction;
                            final barHeight = (_waveformSamples[index] * 28)
                                .clamp(5.0, 28.0);

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
                          }),
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
              Expanded(
                child: Text(
                  _isPlaying || _position > Duration.zero
                      ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                      : (_duration > Duration.zero
                            ? _formatDuration(_duration)
                            : context.tr('ui_common_voice_note_ddc07a')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
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
