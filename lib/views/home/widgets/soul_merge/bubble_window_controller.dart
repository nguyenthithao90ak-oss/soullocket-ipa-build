import 'dart:async';
import 'dart:ui';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

enum SoulBubbleWindowMode { bubble, preview, chat }

abstract interface class SoulBubbleWindowPort {
  Future<OverlayPosition> position();
  Future<void> resize(int width, int height, bool draggable);
  Future<void> move(OverlayPosition position);
  Future<void> focus(bool enabled);
}

class AndroidSoulBubbleWindow implements SoulBubbleWindowPort {
  static const _deadline = Duration(seconds: 3);

  @override
  Future<OverlayPosition> position() =>
      FlutterOverlayWindow.getOverlayPosition().timeout(_deadline);
  @override
  Future<void> resize(int width, int height, bool draggable) async {
    if (await FlutterOverlayWindow.resizeOverlay(
          width,
          height,
          draggable,
        ).timeout(_deadline) ==
        false) {
      throw StateError('Overlay is no longer active');
    }
  }

  @override
  Future<void> move(OverlayPosition position) async {
    if (await FlutterOverlayWindow.moveOverlay(position).timeout(_deadline) ==
        false) {
      throw StateError('Overlay is no longer active');
    }
  }

  @override
  Future<void> focus(bool enabled) async {
    if (await FlutterOverlayWindow.updateFlag(
          enabled ? OverlayFlag.focusPointer : OverlayFlag.defaultFlag,
        ).timeout(_deadline) ==
        false) {
      throw StateError('Overlay is no longer active');
    }
  }
}

/// WindowManager giữ tọa độ cũ khi resize. Tuần tự hóa resize/move/focus và
/// đưa cửa sổ chat về gốc; chỉ khôi phục điểm neo khi thu lại thành bong bóng.
class SoulBubbleWindowController {
  SoulBubbleWindowController(this.port);

  final SoulBubbleWindowPort port;
  SoulBubbleWindowMode mode = SoulBubbleWindowMode.bubble;
  bool bubbleOnLeft = false;
  OverlayPosition? _bubblePosition;
  Future<void> _queue = Future.value();
  int _revision = 0;
  bool _disposed = false;

  Future<bool> show(SoulBubbleWindowMode target, Size displaySize) {
    final revision = ++_revision;
    final result = Completer<bool>();
    _queue = _queue.then((_) async {
      if (_disposed || revision != _revision) {
        result.complete(false);
        return;
      }
      try {
        if (mode == SoulBubbleWindowMode.bubble && _bubblePosition == null) {
          _bubblePosition = await port.position();
        } else if (mode == SoulBubbleWindowMode.bubble &&
            target != SoulBubbleWindowMode.bubble) {
          _bubblePosition = await port.position();
        }
        bubbleOnLeft = (_bubblePosition?.x ?? 0) > (displaySize.width - 80) / 2;
        if (_disposed || revision != _revision) {
          result.complete(false);
          return;
        }
        // Height sentinel -1 của plugin 1.0.1 bị đổi qua dpToPx; dùng chiều
        // cao display thật để tránh LayoutParams âm trên máy density > 1.
        final expanded = target == SoulBubbleWindowMode.chat;
        final width = expanded
            ? WindowSize.matchParent
            : target == SoulBubbleWindowMode.preview
            ? 240
            : 80;
        await port.focus(false);
        await port.resize(
          width,
          expanded ? displaySize.height.ceil() : 80,
          !expanded,
        );
        final anchor = _bubblePosition ?? const OverlayPosition(0, 0);
        final maxX =
            (displaySize.width - (expanded ? displaySize.width : width)).clamp(
              0.0,
              double.infinity,
            );
        final maxY = ((displaySize.height - 80) / 2 - 24).clamp(
          0.0,
          double.infinity,
        );
        await port.move(
          expanded
              ? const OverlayPosition(0, 0)
              : OverlayPosition(
                  anchor.x.clamp(0.0, maxX),
                  anchor.y.clamp(-maxY, maxY),
                ),
        );
        await port.focus(expanded);
        mode = target;
        result.complete(!_disposed && revision == _revision);
      } catch (error, stack) {
        // Resize có thể đã thành công trước khi move/focus lỗi. Khôi phục
        // một cửa sổ nhỏ để người dùng vẫn kéo/đóng được sau lỗi native.
        try {
          await port.focus(false);
          await port.resize(80, 80, true);
          await port.move(_bubblePosition ?? const OverlayPosition(0, 0));
          mode = SoulBubbleWindowMode.bubble;
        } catch (_) {
          // Giữ lỗi ban đầu để giao diện có thể báo và thử lại.
        }
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  void dispose() {
    _disposed = true;
    _revision++;
  }
}
