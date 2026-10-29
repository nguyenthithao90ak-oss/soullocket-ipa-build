import 'package:flutter/foundation.dart';

/// Tách lỗi nền bản đồ khỏi lỗi quyền/GPS; không tự tải lại hay đổi nhà cung cấp.
class MapTileHealth extends ValueNotifier<bool> {
  MapTileHealth() : super(false);

  final Set<Object> _failed = {};
  bool loadedOnce = false;
  bool _timedOut = false;

  void record(Object key, {required bool failed}) {
    if (failed) {
      // Không giữ vô hạn khóa tile nếu người dùng cuộn xa khi mất mạng.
      if (_failed.length < 256) _failed.add(key);
    } else {
      loadedOnce = true;
      _timedOut = false;
      _failed.remove(key);
    }
    value = _timedOut || _failed.isNotEmpty;
  }

  void timeout() {
    if (loadedOnce) return;
    _timedOut = true;
    value = true;
  }

  void reset() {
    _failed.clear();
    loadedOnce = false;
    _timedOut = false;
    value = false;
  }
}
