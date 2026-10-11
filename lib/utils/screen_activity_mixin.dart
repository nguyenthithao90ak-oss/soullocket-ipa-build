import 'package:flutter/material.dart';

/// Chỉ chạy công việc của màn hình khi app ở foreground, route hiện hành
/// và tab cho phép hoạt động. Không điều khiển các service nền của ứng dụng.
mixin ScreenActivityMixin<T extends StatefulWidget> on State<T> {
  late final AppLifecycleListener _screenLifecycle;
  bool _screenForeground = false;
  bool _screenRouteCurrent = false;
  bool _screenTickerEnabled = false;
  bool _screenActive = false;

  bool get isScreenActive => mounted && _screenActive;
  bool get isScreenForeground => _screenForeground;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _screenForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _screenLifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _screenForeground = state == AppLifecycleState.resumed;
        _updateScreenActivity();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenRouteCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _screenTickerEnabled = TickerMode.valuesOf(context).enabled;
    _updateScreenActivity();
  }

  void _updateScreenActivity() {
    final active =
        mounted &&
        _screenForeground &&
        _screenRouteCurrent &&
        _screenTickerEnabled;
    if (_screenActive == active) return;
    _screenActive = active;
    onScreenActivityChanged(active);
  }

  /// Lần gọi đầu tiên nằm trong didChangeDependencies, sau initState của State.
  /// Callback có thể chạy trong lúc build; việc đổi notifier phải chờ hết frame.
  @protected
  void onScreenActivityChanged(bool active) {}

  @override
  void dispose() {
    _screenActive = false;
    _screenLifecycle.dispose();
    super.dispose();
  }
}
