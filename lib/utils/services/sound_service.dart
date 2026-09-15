import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

import 'audio/ui_sound_controller.dart';
import 'music_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal() : this.forTesting(controller: UiSoundController());

  @visibleForTesting
  SoundService.forTesting({
    required UiSoundController controller,
    ValueListenable<UiPrefsState>? preferences,
    ValueListenable<bool>? musicPlaying,
    ValueListenable<bool>? captureActive,
  }) : _controller = controller,
       _preferences = preferences ?? UiPrefs.notifier,
       _musicPlaying = musicPlaying ?? MusicService().isPlayingNotifier,
       _captureActive = captureActive ?? UiPrefs.captureModeNotifier;

  final UiSoundController _controller;
  final ValueListenable<UiPrefsState> _preferences;
  final ValueListenable<bool> _musicPlaying;
  final ValueListenable<bool> _captureActive;
  final ValueNotifier<bool> _companionSuppressed = ValueNotifier(false);
  ValueListenable<bool> get companionSuppressed => _companionSuppressed;
  final Set<Object> _quietLeases = {};
  bool _foreground = true;
  bool _initialized = false;
  bool _disposed = false;

  Future<void> init() async {
    if (_disposed || _initialized) return;
    _initialized = true;
    _preferences.addListener(_sync);
    _musicPlaying.addListener(_sync);
    _captureActive.addListener(_sync);
    _controller.busy.addListener(_syncCompanion);
    _sync();
  }

  bool get _externalQuiet =>
      !_foreground ||
      _musicPlaying.value ||
      _captureActive.value ||
      _quietLeases.isNotEmpty;

  void _sync() {
    if (_disposed) return;
    _controller.setEnabled(_preferences.value.touchSound && !_externalQuiet);
    _syncCompanion();
  }

  void _syncCompanion() {
    if (_disposed) return;
    // touchSound chỉ tắt UI; thỏ vẫn có công tắc riêng của nó.
    _companionSuppressed.value = _externalQuiet || _controller.busy.value;
  }

  void unlockFromGesture() {
    if (_disposed) return;
    unawaited(init());
    _controller.unlockFromGesture();
  }

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    _sync();
  }

  /// Mỗi media/ghi âm/cuộc gọi sở hữu một lease riêng và trả lại đúng một lần.
  VoidCallback holdQuiet() {
    if (_disposed) return () {};
    final lease = Object();
    _quietLeases.add(lease);
    _sync();
    return () {
      if (_disposed || !_quietLeases.remove(lease)) return;
      _sync();
    };
  }

  Future<void> _play(UiSoundCue cue) async {
    if (_disposed) return;
    // Đánh giá cờ tắt âm ngay khi nhận sự kiện, không để âm bị chặn
    // lọt qua nếu một lease được thả ở microtask kế tiếp.
    unawaited(init());
    if (!_disposed) await _controller.play(cue);
  }

  Future<void> playClick() => _play(UiSoundCue.click);
  Future<void> playSuccess() => _play(UiSoundCue.success);
  Future<void> playSaved() => _play(UiSoundCue.saved);
  Future<void> playPaired() => _play(UiSoundCue.paired);
  Future<void> playSent() => _play(UiSoundCue.sent);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_initialized) {
      _preferences.removeListener(_sync);
      _musicPlaying.removeListener(_sync);
      _captureActive.removeListener(_sync);
      _controller.busy.removeListener(_syncCompanion);
    }
    _quietLeases.clear();
    _controller.dispose();
    _companionSuppressed.dispose();
  }
}
