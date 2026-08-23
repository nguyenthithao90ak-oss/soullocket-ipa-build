import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:soullocket_app/utils/helpers/sensor_helper.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

part 'wave_painters_part.dart';
part 'wave_effects_part.dart';

class AnimatedWaveBackground extends StatefulWidget {
  final String styleKey;
  final bool enableMotion;
  final bool transparentMode;

  const AnimatedWaveBackground({
    super.key,
    required this.styleKey,
    required this.enableMotion,
    this.transparentMode = false,
  });

  static bool hasMotion(String styleKey) {
    return styleKey != 'plain' && styleKey != 'floating_hearts';
  }

  @override
  State<AnimatedWaveBackground> createState() => _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // Shake detection and ripple states
  double _lastX = 0.0;
  double _lastY = 0.0;
  double _lastZ = 0.0;
  bool _isFirstEvent = true;
  double _shakeIntensity = 0.0;
  final List<_TapInteractionEffect> _tapEffects = [];
  // Throttle sensor: chỉ xử lý 1 event mỗi 16ms (~60fps)
  int _lastSensorProcessedMs = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    UiPrefs.notifier.addListener(_onUiPrefsChanged);
  }

  void _initSensor() {
    if (kIsWeb) return;
    try {
      _sensorSubscription?.cancel();
      _isFirstEvent = true;

      double? lastRawX;
      double? lastRawY;
      int staticCount = 0;
      bool isSensorActive = true;

      _sensorSubscription = SensorHelper.accelerometerEvents.listen(
        (event) {
          if (!mounted) return;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastSensorProcessedMs < 16) return;
          _lastSensorProcessedMs = nowMs;

          // Check if sensor is sending changing values (to detect static/emulated sensors)
          if (lastRawX != null && lastRawY != null) {
            if ((event.x - lastRawX!).abs() < 0.0001 &&
                (event.y - lastRawY!).abs() < 0.0001) {
              staticCount++;
              if (staticCount > 10) {
                isSensorActive = false;
              }
            } else {
              staticCount = 0;
              isSensorActive = true;
            }
          }
          lastRawX = event.x;
          lastRawY = event.y;

          if (!isSensorActive) return;

          // Smooth the tilt using low-pass filter (lerp)
          final targetX = -event.x.clamp(-6.0, 6.0) * 3.5;
          final targetY = event.y.clamp(-6.0, 6.0) * 3.5;
          _tiltX = _tiltX * 0.92 + targetX * 0.08;
          _tiltY = _tiltY * 0.92 + targetY * 0.08;

          // Detect shake using acceleration changes
          if (_isFirstEvent) {
            _lastX = event.x;
            _lastY = event.y;
            _lastZ = event.z;
            _isFirstEvent = false;
            return;
          }

          final deltaX = event.x - _lastX;
          final deltaY = event.y - _lastY;
          final deltaZ = event.z - _lastZ;

          _lastX = event.x;
          _lastY = event.y;
          _lastZ = event.z;

          final force =
              sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);
          // Threshold of 3.5 m/s^2 represents a sudden shake
          if (force > 3.5) {
            _shakeIntensity = (_shakeIntensity + 0.45).clamp(0.0, 1.5);

            final now = DateTime.now();
            if (_tapEffects.isEmpty ||
                now.difference(_tapEffects.last.startTime).inMilliseconds >
                    250) {
              if (_tapEffects.length >= 3) {
                _tapEffects.removeAt(0);
              }
              final random = Random();
              _tapEffects.add(
                _TapInteractionEffect(
                  centerOffset: Offset(
                    (random.nextDouble() - 0.5) * 80.0,
                    (random.nextDouble() - 0.5) * 80.0,
                  ),
                  startTime: now,
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState(_shouldAnimateFor());
  }

  @override
  void didUpdateWidget(AnimatedWaveBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.styleKey != widget.styleKey ||
        oldWidget.enableMotion != widget.enableMotion) {
      _syncAnimationState(_shouldAnimateFor());
    }
  }

  @override
  void dispose() {
    UiPrefs.notifier.removeListener(_onUiPrefsChanged);
    _sensorSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onUiPrefsChanged() {
    if (!mounted) return;
    _syncAnimationState(_shouldAnimateFor());
  }

  bool _shouldAnimateFor() {
    if (!AnimatedWaveBackground.hasMotion(widget.styleKey)) return false;
    return widget.enableMotion;
  }

  void _syncAnimationState(bool shouldAnimate) {
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      if (_sensorSubscription == null) {
        _initSensor();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _sensorSubscription?.cancel();
      _sensorSubscription = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AnimatedWaveBackground.hasMotion(widget.styleKey)) {
      return const SizedBox.expand();
    }
    final isBasicStyle = widget.styleKey == 'default' ||
        widget.styleKey == 'plain' ||
        widget.styleKey.isEmpty;
    if (widget.transparentMode && isBasicStyle) {
      return const SizedBox.expand();
    }
    final uiState = UiPrefs.notifier.value;
    final effectProfile = UiPrefs.resolveEffectProfile(
      state: uiState,
      isWeb: kIsWeb,
    );
    final quality = effectProfile.graphicsQualityKey;

    final result = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shouldAnimate = _shouldAnimateFor();

        // Decay shake intensity on every frame
        if (shouldAnimate) {
          if (_shakeIntensity > 0.001) {
            _shakeIntensity *= 0.94;
          } else {
            _shakeIntensity = 0.0;
          }

          // Filter out expired ripples
          final now = DateTime.now();
          _tapEffects.removeWhere((r) => r.getProgress(now) >= 1.0);
        }

        return CustomPaint(
          painter: _WavePainter(
            shouldAnimate ? _controller.value : 0.0,
            widget.styleKey,
            quality: quality,
            tiltX: _tiltX,
            tiltY: _tiltY,
            shakeIntensity: _shakeIntensity,
            tapEffects: List.from(_tapEffects),
          ),
        );
      },
    );

    return RepaintBoundary(
      child: MouseRegion(
        onHover: (event) {
          final localPos = event.localPosition;
          final renderBox = context.findRenderObject();
          if (renderBox is RenderBox && renderBox.hasSize) {
            final size = renderBox.size;
            final centerX = size.width / 2;
            final centerY = size.height / 2;
            if (centerX > 0.0 && centerY > 0.0) {
              _tiltX = (localPos.dx - centerX) / centerX * 12.0;
              _tiltY = (localPos.dy - centerY) / centerY * 12.0;
            }
          }
        },
        onExit: (_) {
          _tiltX = 0.0;
          _tiltY = 0.0;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            final renderBox = context.findRenderObject();
            if (renderBox is RenderBox && renderBox.hasSize) {
              final localPos = event.localPosition;
              final size = renderBox.size;
              final centerX = size.width / 2;
              final centerY = size.height / 2;
              if (centerX > 0.0 && centerY > 0.0) {
                final offset =
                    Offset(localPos.dx - centerX, localPos.dy - centerY);
                _shakeIntensity = (_shakeIntensity + 0.45).clamp(0.0, 1.5);
                if (_tapEffects.length >= 4) {
                  _tapEffects.removeAt(0);
                }
                _tapEffects.add(
                  _TapInteractionEffect(
                    centerOffset: offset,
                    startTime: DateTime.now(),
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              }
            }
          },
          child: result,
        ),
      ),
    );
  }
}
