import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Buffer native của một video, có tuổi tính từ lần cấp URL ban đầu.
class DiaryVideoBuffer {
  DiaryVideoBuffer(
    this.controller, {
    this.validFor = const Duration(minutes: 2),
  });

  final VideoPlayerController controller;
  final Duration validFor;
  final _age = Stopwatch()..start();

  Duration get remaining {
    final value = validFor - _age.elapsed;
    return value > Duration.zero ? value : Duration.zero;
  }
}

/// Giữ tối đa một player đã dừng trong 20 giây để mở lại không mất buffer.
/// Không lưu file video hoặc URL xuống đĩa; dọn ngay khi đổi phiên/xuống nền.
class DiaryVideoBufferCache with WidgetsBindingObserver {
  DiaryVideoBufferCache({this.keepAlive = const Duration(seconds: 20)}) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Duration keepAlive;
  DiaryVideoBuffer? _buffer;
  Object? _key;
  Timer? _expiry;
  StreamSubscription<String?>? _auth;
  String? _uid;
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;
  final _releasing = <VideoPlayerController, Future<void>>{};

  /// Giữ hàng rào tới khi native thật sự nhả decoder, kể cả sau timeout UI.
  Future<void> release(VideoPlayerController controller) {
    final pending = _releasing[controller];
    if (pending != null) return pending;
    final work = Future<void>.sync(
      controller.dispose,
    ).catchError((Object _) {});
    _releasing[controller] = work;
    unawaited(
      work.then((_) {
        if (identical(_releasing[controller], work)) {
          _releasing.remove(controller);
        }
      }),
    );
    return work;
  }

  final _releaseTransitions = <Future<void>>{};

  void trackRelease(Future<void> work) {
    _releaseTransitions.add(work);
    unawaited(work.then((_) => _releaseTransitions.remove(work)));
  }

  Future<void> waitForReleases() async {
    while (_releaseTransitions.isNotEmpty || _releasing.isNotEmpty) {
      await Future.wait([..._releaseTransitions, ..._releasing.values]);
    }
  }

  int get generation => _generation;

  void bindSession(String? uid, Stream<String?> authChanges) {
    if (_disposed || (_uid == uid && _auth != null)) return;
    clear();
    unawaited(_auth?.cancel());
    _uid = uid;
    _auth = authChanges.listen((next) {
      if (next != _uid) clear();
    }, onError: (Object _) => clear());
  }

  DiaryVideoBuffer? take(Object key) {
    final buffer = _buffer;
    if (buffer == null || _key != key) return null;
    _buffer = null;
    _key = null;
    _expiry?.cancel();
    if (_disposed ||
        !_foreground ||
        buffer.remaining == Duration.zero ||
        buffer.controller.value.hasError ||
        !buffer.controller.value.isInitialized) {
      unawaited(release(buffer.controller));
      return null;
    }
    return buffer;
  }

  void store(Object key, DiaryVideoBuffer buffer, {required int generation}) {
    if (_disposed ||
        !_foreground ||
        generation != _generation ||
        buffer.remaining == Duration.zero ||
        buffer.controller.value.isPlaying ||
        buffer.controller.value.hasError ||
        !buffer.controller.value.isInitialized) {
      unawaited(release(buffer.controller));
      return;
    }
    clear();
    _buffer = buffer;
    _key = key;
    final remaining = buffer.remaining;
    _expiry = Timer(remaining < keepAlive ? remaining : keepAlive, clear);
  }

  void clear() {
    _generation++;
    _expiry?.cancel();
    final buffer = _buffer;
    _buffer = null;
    _key = null;
    if (buffer != null) unawaited(release(buffer.controller));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mất focus tạm thời không làm mất buffer; app thật sự xuống nền thì dọn.
    if (state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) clear();
  }

  void dispose() {
    _disposed = true;
    clear();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
  }
}
